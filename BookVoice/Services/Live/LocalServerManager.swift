//
//  LocalServerManager.swift
//  BookVoice
//
//  Manages local Python TTS and RVC servers.
//  Handles Python installation check, pip dependencies, and server lifecycle.
//

import Foundation

actor LocalServerManager {

    static let shared = LocalServerManager()

    // MARK: - App Termination Cleanup

    /// All ports that BookVoice servers may occupy.
    private static let allServerPorts = [
        8100, 8102, 8104, 8106, 8108,  // TTS
        8101,                            // RVC
        8200, 8202, 8204, 8206, 8208,  // LLM
    ]

    /// Synchronous cleanup called from `applicationWillTerminate`.
    /// Kills every Python server process on known ports so nothing lingers after quit.
    /// This is `nonisolated` and `static` — safe to call from any thread without `await`.
    nonisolated static func terminateAllServers() {
        print("[Server] App terminating — killing all server processes")

        for port in allServerPorts {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/lsof")
            proc.arguments = ["-ti", "tcp:\(port)"]
            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = FileHandle.nullDevice

            do {
                try proc.run()
                proc.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                guard let output = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                      !output.isEmpty else { continue }

                let pids = output.components(separatedBy: .newlines)
                    .compactMap { Int32($0.trimmingCharacters(in: .whitespaces)) }
                for pid in pids {
                    kill(pid, SIGTERM)
                }
            } catch {
                // Best effort — continue with remaining ports
            }
        }
    }

    // MARK: - Server Configuration

    enum ServerType: String, Sendable {
        case tts
        case rvc
        case llm
    }

    struct ServerConfig: Sendable {
        let type: ServerType
        let port: Int
        let provider: String?  // For TTS: "silero", "kokoro", "qwen"
    }

    // MARK: - State

    private var runningServers: [ServerType: Process] = [:]
    private var serverPorts: [ServerType: Int] = [:]
    private var serverProviders: [ServerType: String] = [:]
    private var venvReady = false

    private let ttsDefaultPort = 8100
    private let rvcDefaultPort = 8101
    private let llmDefaultPort = 8200

    /// Path to the venv directory inside Application Support
    private nonisolated var venvDirectory: URL {
        AppConstants.appSupportDirectory.appendingPathComponent("venv")
    }

    /// Python executable inside the venv
    private nonisolated var venvPython: String {
        venvDirectory.appendingPathComponent("bin/python3").path
    }

    // MARK: - Script files to manage

    private static let scriptFiles = [
        "tts_server.py",
        "rvc_server.py",
        "llm_server.py",
        "requirements.txt",
        "requirements_silero.txt",
        "requirements_kokoro.txt",
        "requirements_qwen.txt",
        "requirements_rvc.txt",
        "requirements_llm.txt",
    ]

    // MARK: - Python Environment

    /// Check if Python 3 is available on the system
    func isPythonAvailable() -> Bool {
        findPythonPath() != nil
    }

    /// Find the Python 3 executable path.
    /// Prefers specific torch-compatible versions (3.11, 3.12, 3.13) over
    /// the generic ``python3`` symlink, which may point to an unsupported
    /// release (e.g. 3.14) where PyTorch is not yet available.
    nonisolated func findPythonPath() -> String? {
        // Preferred: specific torch-compatible versions (newest first)
        let versionedCandidates = [
            "/opt/homebrew/bin/python3.12",
            "/opt/homebrew/bin/python3.11",
            "/opt/homebrew/bin/python3.13",
            "/usr/local/bin/python3.12",
            "/usr/local/bin/python3.11",
            "/usr/local/bin/python3.13",
        ]

        for path in versionedCandidates {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }

        // Fallback: generic python3
        let genericCandidates = [
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3",
            "/usr/bin/python3",
            "/opt/local/bin/python3",
        ]

        for path in genericCandidates {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }

        // Last resort: `which python3`
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["python3"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !path.isEmpty {
                    return path
                }
            }
        } catch {}

        return nil
    }

    // MARK: - Virtual Environment

    /// Ensure a venv exists. Creates one from the system Python if needed.
    func ensureVenv() async throws {
        if venvReady && FileManager.default.fileExists(atPath: venvPython) {
            return
        }

        if FileManager.default.fileExists(atPath: venvPython) {
            venvReady = true
            return
        }

        guard let systemPython = findPythonPath() else {
            throw LocalServerError.pythonNotFound
        }

        try FileManager.default.createDirectory(
            at: venvDirectory.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let process = Process()
        process.executableURL = URL(fileURLWithPath: systemPython)
        process.arguments = ["-m", "venv", venvDirectory.path]
        process.standardOutput = FileHandle.nullDevice
        let errorPipe = Pipe()
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw LocalServerError.dependencyInstallFailed("Не удалось создать venv: \(error.localizedDescription)")
        }

        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let msg = String(data: errorData, encoding: .utf8) ?? "неизвестная ошибка"
            throw LocalServerError.dependencyInstallFailed("Не удалось создать venv: \(msg)")
        }

        // Upgrade pip inside the venv
        let pipUpgrade = Process()
        pipUpgrade.executableURL = URL(fileURLWithPath: venvPython)
        pipUpgrade.arguments = ["-m", "pip", "install", "--upgrade", "pip", "--quiet"]
        pipUpgrade.standardOutput = FileHandle.nullDevice
        pipUpgrade.standardError = FileHandle.nullDevice
        try? pipUpgrade.run()
        pipUpgrade.waitUntilExit()

        venvReady = true
    }

    /// Install pip dependencies for a specific provider
    func installDependencies(for provider: String) async throws {
        try await ensureVenv()

        let scriptsDir = try getScriptsDirectory()

        // Install base requirements
        try await runPip(pythonPath: venvPython, requirementsFile: scriptsDir.appendingPathComponent("requirements.txt"))

        // Install provider-specific requirements
        let providerReqs = scriptsDir.appendingPathComponent("requirements_\(provider).txt")
        if FileManager.default.fileExists(atPath: providerReqs.path) {
            do {
                try await runPip(pythonPath: venvPython, requirementsFile: providerReqs)
            } catch {
                if provider == "rvc" {
                    throw LocalServerError.dependencyInstallFailed(
                        "Библиотека RVC (rvc-python) несовместима с текущей версией Python. "
                        + "Изменение тембра голоса временно недоступно. "
                        + "Вы можете пропустить этот шаг и экспортировать аудио без изменения тембра."
                    )
                }
                throw error
            }
        }
    }

    /// Check if dependencies are installed for a provider
    func areDependenciesInstalled(for provider: String) async -> Bool {
        guard FileManager.default.fileExists(atPath: venvPython) else { return false }

        // Check if core packages are importable
        let packages: [String]
        switch provider {
        case "silero":
            packages = ["fastapi", "uvicorn", "torch", "torchaudio", "omegaconf"]
        case "kokoro":
            packages = ["fastapi", "uvicorn", "kokoro"]
        case "qwen":
            packages = ["fastapi", "uvicorn", "torch", "qwen_tts"]
        case "rvc":
            packages = ["fastapi", "uvicorn", "rvc_python"]
        case "llm":
            packages = ["fastapi", "uvicorn", "llama_cpp", "requests"]
        default:
            packages = ["fastapi", "uvicorn"]
        }

        for pkg in packages {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: venvPython)
            process.arguments = ["-c", "import \(pkg)"]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice

            do {
                try process.run()
                process.waitUntilExit()
                if process.terminationStatus != 0 {
                    return false
                }
            } catch {
                return false
            }
        }

        return true
    }

    // MARK: - Server Lifecycle

    /// Start a local server. Returns the port it's running on.
    func startServer(_ config: ServerConfig) async throws -> Int {
        // If already running, return existing port
        if let existingProcess = runningServers[config.type], existingProcess.isRunning {
            return serverPorts[config.type] ?? config.port
        }

        // Kill any stale process on this port from a previous app session
        killProcessOnPort(config.port)

        // Pre-check: verify port is actually available via socket bind test
        if !isPortAvailable(config.port) {
            print("[Server] Port \(config.port) is not available (socket bind test failed after kill)")
            throw LocalServerError.serverStartFailed(
                "Порт \(config.port) занят. Попробуйте завершить другие приложения, использующие этот порт."
            )
        }

        // Ensure venv exists
        try await ensureVenv()

        guard FileManager.default.fileExists(atPath: venvPython) else {
            throw LocalServerError.pythonNotFound
        }

        let scriptsDir = try getScriptsDirectory()
        let scriptName: String
        var args: [String] = []

        switch config.type {
        case .tts:
            scriptName = "tts_server.py"
            let provider = config.provider ?? "silero"
            args = [
                "--provider", provider,
                "--port", String(config.port),
                "--models-dir", AppConstants.modelsDirectory.path,
            ]

        case .rvc:
            scriptName = "rvc_server.py"
            args = [
                "--port", String(config.port),
                "--models-dir", AppConstants.modelsDirectory.path,
            ]

        case .llm:
            scriptName = "llm_server.py"
            args = [
                "--port", String(config.port),
                "--models-dir", AppConstants.llmModelsDirectory.path,
            ]
        }

        let scriptPath = scriptsDir.appendingPathComponent(scriptName)
        guard FileManager.default.fileExists(atPath: scriptPath.path) else {
            throw LocalServerError.scriptNotFound(scriptName)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: venvPython)
        process.arguments = [scriptPath.path] + args

        // Capture both stdout and stderr — server logs go to stdout
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        // Log server output asynchronously for debugging
        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty, let line = String(data: data, encoding: .utf8) {
                print("[Server/\(config.type.rawValue)] \(line)", terminator: "")
            }
        }
        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty, let line = String(data: data, encoding: .utf8) {
                print("[Server/\(config.type.rawValue)/err] \(line)", terminator: "")
            }
        }

        // Set up environment — use the venv
        var env = ProcessInfo.processInfo.environment
        env["PYTHONUNBUFFERED"] = "1"
        env["VIRTUAL_ENV"] = venvDirectory.path
        // Include Homebrew bin so that SoX and other tools are discoverable
        let homebrewBin = "/opt/homebrew/bin"
        let venvBin = venvDirectory.appendingPathComponent("bin").path
        env["PATH"] = venvBin + ":" + homebrewBin + ":" + (env["PATH"] ?? "")
        // Force PyTorch to fall back to CPU for unsupported MPS ops
        env["PYTORCH_ENABLE_MPS_FALLBACK"] = "1"
        process.environment = env

        do {
            try process.run()
        } catch {
            throw LocalServerError.serverStartFailed(error.localizedDescription)
        }

        runningServers[config.type] = process
        serverPorts[config.type] = config.port
        serverProviders[config.type] = config.provider

        // Wait for server to become available.
        // Qwen TTS imports torch + transformers which is slow; other providers are faster.
        let timeout: TimeInterval
        switch (config.type, config.provider) {
        case (.tts, "qwen"):
            timeout = 180  // 3 min — torch + transformers imports are heavy
        case (.tts, _):
            timeout = 60
        case (.rvc, _):
            timeout = 30
        case (.llm, _):
            timeout = 120  // 2 min — loading LLM model can be slow
        }
        let baseURL = "http://127.0.0.1:\(config.port)/api/health"
        let ready = await waitForServer(url: baseURL, timeout: timeout, process: process)

        if !ready {
            let processAlive = process.isRunning

            // Stop readability handlers before reading remaining data
            outputPipe.fileHandleForReading.readabilityHandler = nil
            errorPipe.fileHandleForReading.readabilityHandler = nil

            process.terminate()

            // Only clean up state if our process is still the registered one
            // (another concurrent call may have replaced it during await)
            if runningServers[config.type] === process {
                runningServers[config.type] = nil
                serverPorts[config.type] = nil
                serverProviders[config.type] = nil
            }

            // Read remaining stderr for diagnostics
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let stderr = String(data: errorData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let detail: String
            if !processAlive {
                // Process crashed — show stderr
                let lines = stderr.components(separatedBy: .newlines)
                    .filter { !$0.isEmpty }
                    .suffix(8)
                detail = lines.isEmpty
                    ? "Процесс сервера завершился аварийно"
                    : "Сервер завершился с ошибкой:\n" + lines.joined(separator: "\n")
            } else if stderr.isEmpty {
                detail = "Сервер не ответил в течение \(Int(timeout)) секунд. "
                    + "Проверьте, что все зависимости установлены корректно."
            } else {
                let lines = stderr.components(separatedBy: .newlines)
                    .filter { !$0.isEmpty }
                    .suffix(5)
                detail = lines.joined(separator: "\n")
            }
            throw LocalServerError.serverStartFailed(detail)
        }

        return config.port
    }

    /// Stop a running server
    func stopServer(_ type: ServerType) {
        if let process = runningServers[type], process.isRunning {
            process.terminate()
        }
        if let port = serverPorts[type] {
            killProcessOnPort(port)
        }
        runningServers[type] = nil
        serverPorts[type] = nil
        serverProviders[type] = nil
    }

    /// Stop all running servers
    func stopAll() {
        for (type, process) in runningServers {
            if process.isRunning {
                process.terminate()
            }
            if let port = serverPorts[type] {
                killProcessOnPort(port)
            }
        }
        runningServers.removeAll()
        serverPorts.removeAll()
        serverProviders.removeAll()
    }

    /// Check if a server is running
    func isServerRunning(_ type: ServerType) -> Bool {
        runningServers[type]?.isRunning ?? false
    }

    /// Probe a port with an HTTP health check. Returns true if a healthy server responds.
    private nonisolated func probeHealthEndpoint(port: Int, path: String = "/api/health") async -> Bool {
        guard let url = URL(string: "http://127.0.0.1:\(port)\(path)") else { return false }
        var request = URLRequest(url: url)
        request.timeoutInterval = 3
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                return true
            }
        } catch {
            // Not responding
        }
        return false
    }

    /// Get the port of a running server (including adopted orphan servers).
    func getPort(for type: ServerType) -> Int? {
        serverPorts[type]
    }

    /// Ensure a TTS server is running for the given provider.
    /// Auto-installs dependencies if they are not yet available (same as ``ensureRVCServer``).
    /// Tries alternative ports if the default one is occupied.
    func ensureTTSServer(provider: String) async throws -> Int {
        if isServerRunning(.tts) {
            // If the same provider is already running, reuse it
            if serverProviders[.tts] == provider {
                return serverPorts[.tts] ?? ttsDefaultPort
            }
            // Provider changed — stop old server before starting new one
            print("[Server] Provider changed from \(serverProviders[.tts] ?? "?") to \(provider), restarting TTS server")
            stopServer(.tts)
            // Wait for the OS to fully release the socket
            try? await Task.sleep(for: .seconds(2))
        }

        // Fast path: check previously adopted orphan port first
        if let adoptedPort = serverPorts[.tts],
           await probeHealthEndpoint(port: adoptedPort) {
            serverProviders[.tts] = provider
            return adoptedPort
        }

        // Probe for orphaned TTS server from a previous app session
        for portOffset in stride(from: 0, through: 8, by: 2) {
            let port = ttsDefaultPort + portOffset
            if await probeHealthEndpoint(port: port) {
                print("[Server] Found existing TTS server on port \(port), reusing")
                serverPorts[.tts] = port
                serverProviders[.tts] = provider
                return port
            }
        }

        // Kill any orphaned processes on TTS ports before starting fresh
        for portOffset in stride(from: 0, through: 8, by: 2) {
            let port = ttsDefaultPort + portOffset
            if !isPortAvailable(port) {
                print("[Server] Killing orphaned process on TTS port \(port)")
                killProcessOnPort(port)
            }
        }
        try? await Task.sleep(for: .seconds(1))

        // Auto-install TTS dependencies if missing
        let hasDeps = await areDependenciesInstalled(for: provider)
        if !hasDeps {
            try await installDependencies(for: provider)
        }

        // Try the default port, then alternatives if occupied
        var lastError: Error?
        for portOffset in stride(from: 0, through: 8, by: 2) {
            let port = ttsDefaultPort + portOffset
            do {
                return try await startServer(ServerConfig(type: .tts, port: port, provider: provider))
            } catch {
                lastError = error
                print("[Server] Port \(port) failed, trying next: \(error.localizedDescription)")
            }
        }

        throw lastError ?? LocalServerError.serverStartFailed(
            "Не удалось запустить сервер: все порты 8100–8108 заняты"
        )
    }

    /// Ensure the RVC server is running
    func ensureRVCServer() async throws -> Int {
        let port = rvcDefaultPort
        if isServerRunning(.rvc) {
            return serverPorts[.rvc] ?? port
        }

        // Auto-install RVC dependencies if they are not yet available
        let hasRVCDeps = await areDependenciesInstalled(for: "rvc")
        if !hasRVCDeps {
            try await installDependencies(for: "rvc")
        }

        return try await startServer(ServerConfig(type: .rvc, port: port, provider: nil))
    }

    /// Ensure the LLM server is running.
    /// Auto-installs dependencies if needed. Tries alternative ports if default is occupied.
    func ensureLLMServer() async throws -> Int {
        if isServerRunning(.llm) {
            return serverPorts[.llm] ?? llmDefaultPort
        }

        // Fast path: check previously adopted orphan port first
        if let adoptedPort = serverPorts[.llm],
           await probeHealthEndpoint(port: adoptedPort, path: "/api/health") {
            return adoptedPort
        }

        // Probe for orphaned LLM server from a previous app session
        for portOffset in stride(from: 0, through: 8, by: 2) {
            let port = llmDefaultPort + portOffset
            if await probeHealthEndpoint(port: port, path: "/api/health") {
                print("[Server] Found existing LLM server on port \(port), reusing")
                serverPorts[.llm] = port
                return port
            }
        }

        // Kill any orphaned processes on LLM ports before starting fresh
        for portOffset in stride(from: 0, through: 8, by: 2) {
            let port = llmDefaultPort + portOffset
            if !isPortAvailable(port) {
                print("[Server] Killing orphaned process on LLM port \(port)")
                killProcessOnPort(port)
            }
        }
        // Wait for OS to release sockets
        try? await Task.sleep(for: .seconds(1))

        // Auto-install LLM dependencies if missing
        let hasLLMDeps = await areDependenciesInstalled(for: "llm")
        if !hasLLMDeps {
            try await installDependencies(for: "llm")
        }

        // Ensure the LLM models directory exists
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: AppConstants.llmModelsDirectory.path),
            withIntermediateDirectories: true
        )

        // Try the default port, then alternatives if occupied
        var lastError: Error?
        for portOffset in stride(from: 0, through: 8, by: 2) {
            let port = llmDefaultPort + portOffset
            do {
                return try await startServer(ServerConfig(type: .llm, port: port, provider: nil))
            } catch {
                lastError = error
                print("[Server] LLM port \(port) failed, trying next: \(error.localizedDescription)")
            }
        }

        throw lastError ?? LocalServerError.serverStartFailed(
            "Не удалось запустить LLM-сервер: все порты 8200–8208 заняты"
        )
    }

    // MARK: - Scripts Management

    /// Ensure scripts are available in the app support directory.
    /// Always overwrites with the latest versions from the bundle so that
    /// updated requirements files and server scripts take effect.
    private func ensureScriptsInAppSupport() throws -> URL {
        let destDir = AppConstants.appSupportDirectory.appendingPathComponent("Scripts")

        // Create destination directory
        try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)

        // Always copy/overwrite each script from bundle to keep them up-to-date
        for fileName in Self.scriptFiles {
            let ext = (fileName as NSString).pathExtension
            let name = (fileName as NSString).deletingPathExtension

            if let sourceURL = findBundleResource(name: name, ext: ext) {
                let destURL = destDir.appendingPathComponent(fileName)
                // Remove old version if exists, then copy fresh from bundle
                if FileManager.default.fileExists(atPath: destURL.path) {
                    try FileManager.default.removeItem(at: destURL)
                }
                try FileManager.default.copyItem(at: sourceURL, to: destURL)
            }
        }

        return destDir
    }

    /// Search for a resource in the app bundle using multiple strategies
    private nonisolated func findBundleResource(name: String, ext: String) -> URL? {
        // Strategy 1: Direct subdirectory "Scripts"
        if let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Scripts") {
            return url
        }

        // Strategy 2: Nested "Resources/Scripts" (Xcode 16 file system sync)
        if let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Resources/Scripts") {
            return url
        }

        // Strategy 3: Top-level resources (flat bundle layout)
        if let url = Bundle.main.url(forResource: name, withExtension: ext) {
            return url
        }

        // Strategy 4: Manual search in bundle
        if let resourcePath = Bundle.main.resourcePath {
            let targetName = "\(name).\(ext)"
            let fm = FileManager.default
            if let enumerator = fm.enumerator(atPath: resourcePath) {
                while let file = enumerator.nextObject() as? String {
                    if (file as NSString).lastPathComponent == targetName {
                        return URL(fileURLWithPath: resourcePath).appendingPathComponent(file)
                    }
                }
            }
        }

        return nil
    }

    // MARK: - Private Helpers

    /// Check if a given TCP port is available by attempting an actual socket bind.
    /// More reliable than lsof — catches TIME_WAIT and other OS-level port states
    /// that lsof may not report.
    private nonisolated func isPortAvailable(_ port: Int) -> Bool {
        let sock = socket(AF_INET, SOCK_STREAM, 0)
        guard sock >= 0 else { return false }
        defer { Darwin.close(sock) }

        var reuseAddr: Int32 = 1
        setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &reuseAddr, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(port).bigEndian
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")

        let result = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { ptr in
                Darwin.bind(sock, ptr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        return result == 0
    }

    /// Kill any process listening on the given port (stale server from a previous session).
    /// Verifies the port is actually freed before returning.
    private nonisolated func killProcessOnPort(_ port: Int) {
        // Find PIDs on this port
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/lsof")
        proc.arguments = ["-ti", "tcp:\(port)"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice

        do {
            try proc.run()
            proc.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !output.isEmpty {
                let pids = output.components(separatedBy: .newlines)
                    .compactMap { Int32($0.trimmingCharacters(in: .whitespaces)) }

                // First try SIGTERM (graceful)
                for pid in pids {
                    print("[Server] Killing stale process \(pid) on port \(port)")
                    kill(pid, SIGTERM)
                }
                Thread.sleep(forTimeInterval: 1.0)

                // If still alive, force kill with SIGKILL
                for pid in pids {
                    if kill(pid, 0) == 0 {
                        print("[Server] Force-killing process \(pid) on port \(port)")
                        kill(pid, SIGKILL)
                    }
                }
            }
        } catch {
            // Not critical — just continue
        }

        // Wait until the port is actually free (up to 5 seconds)
        for attempt in 1...10 {
            if isPortAvailable(port) {
                return
            }
            print("[Server] Port \(port) still in use, waiting… (attempt \(attempt)/10)")
            Thread.sleep(forTimeInterval: 0.5)
        }
        print("[Server] WARNING: Port \(port) is still in use after all kill attempts")
    }

    private func getScriptsDirectory() throws -> URL {
        // 1. Always sync scripts from bundle → app support (so updated requirements etc. take effect)
        if let dir = try? ensureScriptsInAppSupport() {
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent("tts_server.py").path) {
                return dir
            }
        }

        // 2. Fallback: app support directory (if sync failed but old files remain)
        let appSupportScripts = AppConstants.appSupportDirectory.appendingPathComponent("Scripts")
        if FileManager.default.fileExists(atPath: appSupportScripts.appendingPathComponent("tts_server.py").path) {
            return appSupportScripts
        }

        // 3. Direct bundle search — "Scripts" subdirectory
        if let bundlePath = Bundle.main.resourceURL?.appendingPathComponent("Scripts"),
           FileManager.default.fileExists(atPath: bundlePath.appendingPathComponent("tts_server.py").path) {
            return bundlePath
        }

        // 4. Xcode 16 file system sync nested path
        if let bundlePath = Bundle.main.resourceURL?.appendingPathComponent("Resources/Scripts"),
           FileManager.default.fileExists(atPath: bundlePath.appendingPathComponent("tts_server.py").path) {
            return bundlePath
        }

        // 5. Find script anywhere in bundle
        if let scriptURL = findBundleResource(name: "tts_server", ext: "py") {
            return scriptURL.deletingLastPathComponent()
        }

        #if DEBUG
        // 6. Development: check source project directory
        let sourceDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // Live/
            .deletingLastPathComponent()  // Services/
            .deletingLastPathComponent()  // BookVoice/
            .appendingPathComponent("Resources/Scripts")
        if FileManager.default.fileExists(atPath: sourceDir.appendingPathComponent("tts_server.py").path) {
            return sourceDir
        }
        #endif

        throw LocalServerError.scriptNotFound("tts_server.py")
    }

    private func runPip(pythonPath: String, requirementsFile: URL) async throws {
        guard FileManager.default.fileExists(atPath: requirementsFile.path) else {
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: pythonPath)
        process.arguments = ["-m", "pip", "install", "-r", requirementsFile.path, "--quiet"]

        let errorPipe = Pipe()
        process.standardOutput = FileHandle.nullDevice
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw LocalServerError.dependencyInstallFailed(error.localizedDescription)
        }

        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMsg = String(data: errorData, encoding: .utf8) ?? "Неизвестная ошибка pip"
            throw LocalServerError.dependencyInstallFailed(errorMsg)
        }
    }

    private func waitForServer(url: String, timeout: TimeInterval, process: Process? = nil) async -> Bool {
        guard let healthURL = URL(string: url) else { return false }

        let deadline = Date().addingTimeInterval(timeout)

        // Short per-request timeout so we can retry many times within the overall deadline.
        // Without this, a single URLSession.data() call could block for 60s (default),
        // exhausting the entire deadline on ONE attempt.
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 3
        config.timeoutIntervalForResource = 3
        let session = URLSession(configuration: config)

        while Date() < deadline {
            // Early exit if server process crashed
            if let process, !process.isRunning {
                return false
            }

            do {
                let (_, response) = try await session.data(from: healthURL)
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    session.invalidateAndCancel()
                    return true
                }
            } catch {
                // Server not ready yet — retry after a short delay
            }
            try? await Task.sleep(for: .milliseconds(500))
        }

        session.invalidateAndCancel()
        return false
    }
}

// MARK: - Errors

enum LocalServerError: LocalizedError {
    case pythonNotFound
    case scriptNotFound(String)
    case serverStartFailed(String)
    case dependencyInstallFailed(String)

    var errorDescription: String? {
        switch self {
        case .pythonNotFound:
            "Python 3 не найден. Установите Python 3 с сайта python.org или через Homebrew."
        case .scriptNotFound(let name):
            "Не удалось найти файл \(name). Попробуйте переустановить приложение."
        case .serverStartFailed(let reason):
            "Не удалось запустить локальный сервер: \(reason)"
        case .dependencyInstallFailed(let reason):
            "Ошибка установки библиотек: \(reason)"
        }
    }
}

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

    // MARK: - Server Configuration

    enum ServerType: String, Sendable {
        case tts
        case rvc
    }

    struct ServerConfig: Sendable {
        let type: ServerType
        let port: Int
        let provider: String?  // For TTS: "silero", "kokoro"
    }

    // MARK: - State

    private var runningServers: [ServerType: Process] = [:]
    private var serverPorts: [ServerType: Int] = [:]

    private let ttsDefaultPort = 8100
    private let rvcDefaultPort = 8101

    // MARK: - Script files to manage

    private static let scriptFiles = [
        "tts_server.py",
        "rvc_server.py",
        "requirements.txt",
        "requirements_silero.txt",
        "requirements_kokoro.txt",
        "requirements_rvc.txt",
    ]

    // MARK: - Python Environment

    /// Check if Python 3 is available on the system
    func isPythonAvailable() -> Bool {
        findPythonPath() != nil
    }

    /// Find the Python 3 executable path
    nonisolated func findPythonPath() -> String? {
        let candidates = [
            "/usr/bin/python3",
            "/usr/local/bin/python3",
            "/opt/homebrew/bin/python3",
            "/opt/local/bin/python3",
        ]

        for path in candidates {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }

        // Try `which python3`
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

    /// Install pip dependencies for a specific provider
    func installDependencies(for provider: String) async throws {
        guard let pythonPath = findPythonPath() else {
            throw LocalServerError.pythonNotFound
        }

        let scriptsDir = try getScriptsDirectory()

        // Install base requirements
        try await runPip(pythonPath: pythonPath, requirementsFile: scriptsDir.appendingPathComponent("requirements.txt"))

        // Install provider-specific requirements
        let providerReqs = scriptsDir.appendingPathComponent("requirements_\(provider).txt")
        if FileManager.default.fileExists(atPath: providerReqs.path) {
            try await runPip(pythonPath: pythonPath, requirementsFile: providerReqs)
        }
    }

    /// Check if dependencies are installed for a provider
    func areDependenciesInstalled(for provider: String) async -> Bool {
        guard let pythonPath = findPythonPath() else { return false }

        // Check if core packages are importable
        let packages: [String]
        switch provider {
        case "silero":
            packages = ["fastapi", "uvicorn", "torch"]
        case "kokoro":
            packages = ["fastapi", "uvicorn", "kokoro"]
        case "rvc":
            packages = ["fastapi", "uvicorn", "rvc_python"]
        default:
            packages = ["fastapi", "uvicorn"]
        }

        for pkg in packages {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: pythonPath)
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

        guard let pythonPath = findPythonPath() else {
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
        }

        let scriptPath = scriptsDir.appendingPathComponent(scriptName)
        guard FileManager.default.fileExists(atPath: scriptPath.path) else {
            throw LocalServerError.scriptNotFound(scriptName)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: pythonPath)
        process.arguments = [scriptPath.path] + args
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        // Set up environment
        var env = ProcessInfo.processInfo.environment
        env["PYTHONUNBUFFERED"] = "1"
        process.environment = env

        do {
            try process.run()
        } catch {
            throw LocalServerError.serverStartFailed(error.localizedDescription)
        }

        runningServers[config.type] = process
        serverPorts[config.type] = config.port

        // Wait for server to become available
        let baseURL = "http://127.0.0.1:\(config.port)/api/health"
        let ready = await waitForServer(url: baseURL, timeout: 30)

        if !ready {
            process.terminate()
            runningServers[config.type] = nil
            serverPorts[config.type] = nil
            throw LocalServerError.serverStartFailed("Сервер не ответил в течение 30 секунд")
        }

        return config.port
    }

    /// Stop a running server
    func stopServer(_ type: ServerType) {
        if let process = runningServers[type], process.isRunning {
            process.terminate()
        }
        runningServers[type] = nil
        serverPorts[type] = nil
    }

    /// Stop all running servers
    func stopAll() {
        for (_, process) in runningServers {
            if process.isRunning {
                process.terminate()
            }
        }
        runningServers.removeAll()
        serverPorts.removeAll()
    }

    /// Check if a server is running
    func isServerRunning(_ type: ServerType) -> Bool {
        runningServers[type]?.isRunning ?? false
    }

    /// Get the port of a running server
    func getPort(for type: ServerType) -> Int? {
        guard isServerRunning(type) else { return nil }
        return serverPorts[type]
    }

    /// Ensure a TTS server is running for the given provider
    func ensureTTSServer(provider: String) async throws -> Int {
        let port = ttsDefaultPort
        if isServerRunning(.tts) {
            return serverPorts[.tts] ?? port
        }

        return try await startServer(ServerConfig(type: .tts, port: port, provider: provider))
    }

    /// Ensure the RVC server is running
    func ensureRVCServer() async throws -> Int {
        let port = rvcDefaultPort
        if isServerRunning(.rvc) {
            return serverPorts[.rvc] ?? port
        }

        return try await startServer(ServerConfig(type: .rvc, port: port, provider: nil))
    }

    // MARK: - Scripts Management

    /// Ensure scripts are available in the app support directory.
    /// Copies from bundle if needed.
    private func ensureScriptsInAppSupport() throws -> URL {
        let destDir = AppConstants.appSupportDirectory.appendingPathComponent("Scripts")

        // Check if main script already exists
        if FileManager.default.fileExists(atPath: destDir.appendingPathComponent("tts_server.py").path) {
            return destDir
        }

        // Create destination directory
        try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)

        // Copy each script from bundle
        for fileName in Self.scriptFiles {
            let ext = (fileName as NSString).pathExtension
            let name = (fileName as NSString).deletingPathExtension

            if let sourceURL = findBundleResource(name: name, ext: ext) {
                let destURL = destDir.appendingPathComponent(fileName)
                if !FileManager.default.fileExists(atPath: destURL.path) {
                    try FileManager.default.copyItem(at: sourceURL, to: destURL)
                }
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

    private func getScriptsDirectory() throws -> URL {
        // 1. App support directory (preferred — we copy scripts here)
        let appSupportScripts = AppConstants.appSupportDirectory.appendingPathComponent("Scripts")
        if FileManager.default.fileExists(atPath: appSupportScripts.appendingPathComponent("tts_server.py").path) {
            return appSupportScripts
        }

        // 2. Try to find in bundle and copy to app support
        if let dir = try? ensureScriptsInAppSupport() {
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent("tts_server.py").path) {
                return dir
            }
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

    private func waitForServer(url: String, timeout: TimeInterval) async -> Bool {
        guard let healthURL = URL(string: url) else { return false }

        let deadline = Date().addingTimeInterval(timeout)
        let session = URLSession(configuration: .ephemeral)

        while Date() < deadline {
            do {
                let (_, response) = try await session.data(from: healthURL)
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    return true
                }
            } catch {
                // Server not ready yet
            }
            try? await Task.sleep(for: .milliseconds(500))
        }

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

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

        let scriptsDir = getScriptsDirectory()

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

        let scriptsDir = getScriptsDirectory()
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
            throw LocalServerError.serverStartFailed("Server did not become ready within timeout")
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
        for (type, process) in runningServers {
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

    // MARK: - Private Helpers

    private func getScriptsDirectory() -> URL {
        // Look for scripts in the app bundle first
        if let bundlePath = Bundle.main.resourceURL?.appendingPathComponent("Scripts") {
            if FileManager.default.fileExists(atPath: bundlePath.path) {
                return bundlePath
            }
        }

        // Fallback to app support directory
        let appSupportScripts = AppConstants.appSupportDirectory.appendingPathComponent("Scripts")
        if FileManager.default.fileExists(atPath: appSupportScripts.path) {
            return appSupportScripts
        }

        // Last resort: copy from bundle or create
        return appSupportScripts
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
            let errorMsg = String(data: errorData, encoding: .utf8) ?? "Unknown pip error"
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
            "Python 3 not found. Install Python 3 from python.org or via Homebrew."
        case .scriptNotFound(let name):
            "Server script not found: \(name)"
        case .serverStartFailed(let reason):
            "Failed to start local server: \(reason)"
        case .dependencyInstallFailed(let reason):
            "Failed to install dependencies: \(reason)"
        }
    }
}

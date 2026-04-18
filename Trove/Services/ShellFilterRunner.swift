import Foundation

#if !APP_STORE_BUILD
enum ShellFilterRunner {
    static let timeout: TimeInterval = 5

    static func run(script: String, input: String) throws -> String {
        let process = Process()
        let stdin  = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", script]
        process.standardInput  = stdin
        process.standardOutput = stdout
        process.standardError  = stderr

        // Minimal, sandboxed-ish environment
        process.environment = [
            "PATH": "/usr/bin:/bin",
            "HOME": NSHomeDirectory(),
            "LANG": "en_US.UTF-8",
        ]

        try process.run()

        stdin.fileHandleForWriting.write(Data(input.utf8))
        stdin.fileHandleForWriting.closeFile()

        // Enforce timeout
        let deadline = DispatchTime.now() + timeout
        let group = DispatchGroup()
        group.enter()
        process.terminationHandler = { _ in group.leave() }
        if group.wait(timeout: deadline) == .timedOut {
            process.terminate()
            throw ShellFilterError.timeout
        }

        let outputData = stdout.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: outputData, encoding: .utf8) else {
            throw ShellFilterError.invalidOutput
        }
        guard process.terminationStatus == 0 else {
            let errData = stderr.fileHandleForReading.readDataToEndOfFile()
            let errMsg = String(data: errData, encoding: .utf8) ?? "unknown error"
            throw ShellFilterError.nonZeroExit(Int(process.terminationStatus), errMsg)
        }
        return output
    }
}

enum ShellFilterError: LocalizedError {
    case timeout
    case invalidOutput
    case nonZeroExit(Int, String)

    var errorDescription: String? {
        switch self {
        case .timeout: return "Script timed out after 5 seconds."
        case .invalidOutput: return "Script produced non-UTF8 output."
        case .nonZeroExit(let code, let msg): return "Script exited with code \(code): \(msg)"
        }
    }
}
#endif

import Foundation

public struct SubprocessResult: Equatable, Sendable {
    public let status: Int32
    public let standardOutput: String
    public let standardError: String

    public init(status: Int32, standardOutput: String, standardError: String) {
        self.status = status
        self.standardOutput = standardOutput
        self.standardError = standardError
    }
}

public enum SubprocessError: LocalizedError, Sendable {
    case launchFailed(String)
    case nonzeroExit(SubprocessResult)

    public var errorDescription: String? {
        switch self {
        case let .launchFailed(message):
            return "Could not launch the probe: \(message)"
        case let .nonzeroExit(result):
            let details = result.standardError.trimmingCharacters(in: .whitespacesAndNewlines)
            return details.isEmpty
                ? "The probe exited with status \(result.status)."
                : "The probe exited with status \(result.status): \(details)"
        }
    }
}

public struct SubprocessRunner: Sendable {
    public init() {}

    @discardableResult
    public func run(executable: URL, arguments: [String]) throws -> SubprocessResult {
        let process = Process()
        let standardOutput = Pipe()
        let standardError = Pipe()

        process.executableURL = executable
        process.arguments = arguments
        process.standardOutput = standardOutput
        process.standardError = standardError

        do {
            try process.run()
        } catch {
            throw SubprocessError.launchFailed(error.localizedDescription)
        }

        let outputData = standardOutput.fileHandleForReading.readDataToEndOfFile()
        let errorData = standardError.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        let result = SubprocessResult(
            status: process.terminationStatus,
            standardOutput: String(decoding: outputData, as: UTF8.self),
            standardError: String(decoding: errorData, as: UTF8.self)
        )

        guard result.status == 0 else {
            throw SubprocessError.nonzeroExit(result)
        }
        return result
    }
}

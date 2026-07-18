import AswasCore
import AswasFinderPoCCore
import Darwin
import Foundation

@main
struct AswasFinderPoC {
    private static let runner = SubprocessRunner()
    private static let finderURL = URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app")
    private static let osascriptURL = URL(fileURLWithPath: "/usr/bin/osascript")
    private static let sdefURL = URL(fileURLWithPath: "/usr/bin/sdef")

    static func main() async {
        do {
            let arguments = Array(CommandLine.arguments.dropFirst())
            guard let command = arguments.first else {
                printUsage()
                return
            }

            switch command {
            case "capture":
                try printJSON(runScript(named: "finder-capture"))
            case "capture-native":
                let integration = FinderAppleScriptIntegration()
                try await printEncodable(integration.captureCurrentState())
            case "capabilities-native":
                let integration = FinderAppleScriptIntegration()
                try await printEncodable(integration.checkCapabilities())
            case "accessibility":
                try printJSON(runScript(named: "finder-accessibility-probe"))
            case "dictionary":
                try printEncodable(inspectDictionary())
            case "all":
                try runReadOnlySuite()
            case "lifecycle":
                try runLifecycle(arguments: Array(arguments.dropFirst()))
            case "restore-native":
                try await runNativeRestore(arguments: Array(arguments.dropFirst()))
            case "help", "--help", "-h":
                printUsage()
            default:
                throw CLIError.invalidCommand(command)
            }
        } catch {
            FileHandle.standardError.write(Data("error: \(error.localizedDescription)\n".utf8))
            exit(EXIT_FAILURE)
        }
    }

    private static func runReadOnlySuite() throws {
        let dictionary = try encodeJSONObject(inspectDictionary())
        let capture = try runScript(named: "finder-capture")
        let accessibility = try runScript(named: "finder-accessibility-probe")

        try printJSON([
            "dictionary": dictionary,
            "capture": capture,
            "accessibility": accessibility
        ])
    }

    private static func runLifecycle(arguments: [String]) throws {
        guard arguments.contains("--allow-window-mutation") else {
            throw CLIError.lifecycleRequiresConsent
        }
        guard let path = arguments.first(where: { !$0.hasPrefix("--") }) else {
            throw CLIError.lifecycleRequiresPath
        }

        try printJSON(runScript(named: "finder-window-lifecycle", arguments: [path]))
    }

    private static func runNativeRestore(arguments: [String]) async throws {
        guard arguments.contains("--allow-window-mutation") else {
            throw CLIError.lifecycleRequiresConsent
        }
        guard let path = arguments.first(where: { !$0.hasPrefix("--") }) else {
            throw CLIError.lifecycleRequiresPath
        }

        let integration = FinderAppleScriptIntegration()
        let state = FinderWorkspaceState(
            windows: [
                FinderWindowState(
                    tabs: [FinderTabState(path: PathNormalizer.normalize(path))],
                    selectedTabIndex: 0,
                    frame: CodableRect(x: 160, y: 160, width: 800, height: 600),
                    normalizedFrame: nil,
                    display: nil,
                    viewMode: .list
                )
            ]
        )
        let restore = try await integration.restore(state, mode: .open)
        let cleanup = try await integration.closeManagedWindows(restore.createdWindows)
        try printJSON([
            "restore": try encodeJSONObject(restore),
            "cleanup": try encodeJSONObject(cleanup)
        ])
    }

    private static func inspectDictionary() throws -> FinderDictionaryCapabilities {
        let result = try runner.run(
            executable: sdefURL,
            arguments: [finderURL.path]
        )
        return FinderDictionaryInspector.inspect(result.standardOutput)
    }

    private static func runScript(named name: String, arguments: [String] = []) throws -> Any {
        guard let scriptURL = Bundle.module.url(
            forResource: name,
            withExtension: "applescript"
        ) else {
            throw CLIError.missingResource(name)
        }

        let result = try runner.run(
            executable: osascriptURL,
            arguments: [scriptURL.path] + arguments
        )
        let data = Data(result.standardOutput.utf8)
        return try JSONSerialization.jsonObject(with: data)
    }

    private static func printEncodable<T: Encodable>(_ value: T) throws {
        try printJSON(encodeJSONObject(value))
    }

    private static func encodeJSONObject<T: Encodable>(_ value: T) throws -> Any {
        let data = try JSONEncoder().encode(value)
        return try JSONSerialization.jsonObject(with: data)
    }

    private static func printJSON(_ object: Any) throws {
        let data = try JSONSerialization.data(
            withJSONObject: object,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        print(String(decoding: data, as: UTF8.self))
    }

    private static func printUsage() {
        print(
            """
            AswasFinderPoC — Finder automation capability probe

            Read-only commands:
              AswasFinderPoC dictionary
              AswasFinderPoC capture
              AswasFinderPoC capture-native
              AswasFinderPoC capabilities-native
              AswasFinderPoC accessibility
              AswasFinderPoC all

            Reversible mutation test:
              AswasFinderPoC lifecycle <folder> --allow-window-mutation
              AswasFinderPoC restore-native <folder> --allow-window-mutation

            The lifecycle command creates, moves, inspects, and closes only the Finder
            window that it created. It never closes pre-existing Finder windows.
            """
        )
    }
}

private enum CLIError: LocalizedError {
    case invalidCommand(String)
    case lifecycleRequiresConsent
    case lifecycleRequiresPath
    case missingResource(String)

    var errorDescription: String? {
        switch self {
        case let .invalidCommand(command):
            return "Unknown command '\(command)'. Run with --help for usage."
        case .lifecycleRequiresConsent:
            return "The lifecycle probe requires --allow-window-mutation."
        case .lifecycleRequiresPath:
            return "The lifecycle probe requires an existing folder path."
        case let .missingResource(name):
            return "Missing bundled AppleScript resource '\(name)'."
        }
    }
}

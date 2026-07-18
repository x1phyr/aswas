import AppKit
import Carbon
import Foundation

public struct AppleScriptFailure: Error, Equatable, Sendable {
    public var number: Int?
    public var message: String

    public init(number: Int?, message: String) {
        self.number = number
        self.message = message
    }
}

/// Serializes script loading and executes `NSAppleScript` on the main actor.
public actor AppleScriptRunner {
    public init() {}

    public func runBundledScript(named name: String) async throws -> String {
        try await loadAndExecute(named: name, handler: nil, arguments: [])
    }

    public func runBundledScript(
        named name: String,
        handler: String,
        arguments: [String]
    ) async throws -> String {
        try await loadAndExecute(named: name, handler: handler, arguments: arguments)
    }

    private func loadAndExecute(
        named name: String,
        handler: String?,
        arguments: [String]
    ) async throws -> String {
        let scriptURL = Bundle.main.url(
            forResource: name,
            withExtension: "applescript",
            subdirectory: "Scripts"
        ) ?? Bundle.module.url(
            forResource: name,
            withExtension: "applescript"
        )
        guard let scriptURL else {
            throw AppleScriptFailure(number: nil, message: "Missing script resource: \(name)")
        }

        let source: String
        do {
            source = try String(contentsOf: scriptURL, encoding: .utf8)
        } catch {
            throw AppleScriptFailure(number: nil, message: error.localizedDescription)
        }

        return try await Self.execute(
            source: source,
            handler: handler,
            arguments: arguments
        )
    }

    @MainActor
    private static func execute(
        source: String,
        handler: String?,
        arguments: [String]
    ) throws -> String {
        guard let script = NSAppleScript(source: source) else {
            throw AppleScriptFailure(number: nil, message: "The script could not be compiled.")
        }

        var errorInfo: NSDictionary?
        let result: NSAppleEventDescriptor
        if let handler {
            let event = NSAppleEventDescriptor(
                eventClass: AEEventClass(kASAppleScriptSuite),
                eventID: AEEventID(kASSubroutineEvent),
                targetDescriptor: nil,
                returnID: AEReturnID(kAutoGenerateReturnID),
                transactionID: AETransactionID(kAnyTransactionID)
            )
            event.setParam(
                NSAppleEventDescriptor(string: handler),
                forKeyword: AEKeyword(keyASSubroutineName)
            )
            let argumentList = NSAppleEventDescriptor.list()
            for (offset, argument) in arguments.enumerated() {
                argumentList.insert(
                    NSAppleEventDescriptor(string: argument),
                    at: offset + 1
                )
            }
            event.setParam(argumentList, forKeyword: AEKeyword(keyDirectObject))
            result = script.executeAppleEvent(event, error: &errorInfo)
        } else {
            result = script.executeAndReturnError(&errorInfo)
        }
        if let errorInfo {
            let number = (errorInfo[NSAppleScript.errorNumber] as? NSNumber)?.intValue
            let message = (errorInfo[NSAppleScript.errorMessage] as? String)
                ?? "AppleScript execution failed."
            throw AppleScriptFailure(number: number, message: message)
        }

        guard let output = result.stringValue else {
            throw AppleScriptFailure(number: nil, message: "The script returned no text result.")
        }
        return output
    }
}

import Foundation

/// Finder features explicitly exposed by the installed Finder scripting dictionary.
public struct FinderDictionaryCapabilities: Codable, Equatable, Sendable {
    public let listWindows: Bool
    public let readTarget: Bool
    public let readAndSetBounds: Bool
    public let readAndSetViewMode: Bool
    public let createWindow: Bool
    public let closeWindow: Bool
    public let hasPublicTabModel: Bool

    public init(
        listWindows: Bool,
        readTarget: Bool,
        readAndSetBounds: Bool,
        readAndSetViewMode: Bool,
        createWindow: Bool,
        closeWindow: Bool,
        hasPublicTabModel: Bool
    ) {
        self.listWindows = listWindows
        self.readTarget = readTarget
        self.readAndSetBounds = readAndSetBounds
        self.readAndSetViewMode = readAndSetViewMode
        self.createWindow = createWindow
        self.closeWindow = closeWindow
        self.hasPublicTabModel = hasPublicTabModel
    }
}

public enum FinderDictionaryInspector {
    /// Inspects the raw `sdef` XML without assuming undocumented Finder terminology.
    public static func inspect(_ source: String) -> FinderDictionaryCapabilities {
        FinderDictionaryCapabilities(
            listWindows: source.contains("<element type=\"Finder window\"/>"),
            readTarget: source.contains("<property name=\"target\""),
            readAndSetBounds: source.contains("<property name=\"bounds\""),
            readAndSetViewMode: source.contains("<property name=\"current view\""),
            createWindow: source.contains("<command name=\"make\""),
            closeWindow: source.contains("<command name=\"close\""),
            hasPublicTabModel: containsPublicTabModel(in: source)
        )
    }

    private static func containsPublicTabModel(in source: String) -> Bool {
        source.contains("<class name=\"tab\"")
            || source.contains("<property name=\"tabs\"")
            || source.contains("<element type=\"tab\"")
    }
}

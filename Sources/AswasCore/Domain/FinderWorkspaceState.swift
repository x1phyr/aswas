import Foundation

public struct FinderWorkspaceState: Codable, Equatable, Sendable {
    public var windows: [FinderWindowState]

    public init(windows: [FinderWindowState]) {
        self.windows = windows
    }

    public var tabCount: Int {
        windows.reduce(0) { $0 + $1.tabs.count }
    }
}

public struct FinderWindowState: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var tabs: [FinderTabState]
    public var selectedTabIndex: Int
    public var frame: CodableRect?
    public var normalizedFrame: CodableRect?
    public var display: DisplayDescriptor?
    public var viewMode: FinderViewMode?

    public init(
        id: UUID = UUID(),
        tabs: [FinderTabState],
        selectedTabIndex: Int,
        frame: CodableRect?,
        normalizedFrame: CodableRect?,
        display: DisplayDescriptor?,
        viewMode: FinderViewMode?
    ) {
        self.id = id
        self.tabs = tabs
        self.selectedTabIndex = selectedTabIndex
        self.frame = frame
        self.normalizedFrame = normalizedFrame
        self.display = display
        self.viewMode = viewMode
    }

    public var selectedTab: FinderTabState? {
        guard tabs.indices.contains(selectedTabIndex) else { return nil }
        return tabs[selectedTabIndex]
    }
}

public struct FinderTabState: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var path: String
    public var displayName: String?

    public init(id: UUID = UUID(), path: String, displayName: String? = nil) {
        self.id = id
        self.path = path
        self.displayName = displayName
    }
}

public enum FinderViewMode: String, Codable, CaseIterable, Equatable, Sendable {
    case icon
    case list
    case column
    case gallery
    case unknown
}

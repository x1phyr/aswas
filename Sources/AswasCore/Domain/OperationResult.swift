import Foundation

public enum WorkspaceWarningCode: String, Codable, Equatable, Sendable {
    case windowUnreadable
    case tabsUnavailable
    case pathUnavailable
    case displayUnavailable
    case viewModeUnavailable
    case partialRestore
}

public struct WorkspaceWarning: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var code: WorkspaceWarningCode
    public var message: String
    public var path: String?

    public init(
        id: UUID = UUID(),
        code: WorkspaceWarningCode,
        message: String,
        path: String? = nil
    ) {
        self.id = id
        self.code = code
        self.message = message
        self.path = path
    }
}

public enum WorkspaceErrorCode: String, Codable, Equatable, Sendable {
    case permissionDenied
    case finderUnavailable
    case scriptExecutionFailed
    case accessibilityUnavailable
    case invalidWorkspaceData
    case pathUnavailable
    case displayUnavailable
    case windowCreationFailed
    case tabCreationFailed
    case persistenceFailed
    case unknown
}

public struct WorkspaceOperationError: Codable, Error, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var code: WorkspaceErrorCode
    public var message: String

    public init(id: UUID = UUID(), code: WorkspaceErrorCode, message: String) {
        self.id = id
        self.code = code
        self.message = message
    }
}

public enum RestoreMode: String, Codable, CaseIterable, Sendable {
    case open
    case replace
}

public struct FinderWindowReference: Codable, Equatable, Hashable, Sendable {
    public let windowID: Int

    public init(windowID: Int) {
        self.windowID = windowID
    }
}

public struct FinderCaptureResult: Codable, Equatable, Sendable {
    public var state: FinderWorkspaceState
    public var managedWindows: [FinderWindowReference]
    public var warnings: [WorkspaceWarning]

    public init(
        state: FinderWorkspaceState,
        managedWindows: [FinderWindowReference],
        warnings: [WorkspaceWarning]
    ) {
        self.state = state
        self.managedWindows = managedWindows
        self.warnings = warnings
    }
}

public struct WorkspaceCaptureResult: Equatable, Sendable {
    public var workspace: WorkspaceSnapshot
    public var managedWindows: [FinderWindowReference]
    public var warnings: [WorkspaceWarning]

    public init(
        workspace: WorkspaceSnapshot,
        managedWindows: [FinderWindowReference],
        warnings: [WorkspaceWarning]
    ) {
        self.workspace = workspace
        self.managedWindows = managedWindows
        self.warnings = warnings
    }
}

public struct FinderRestoreResult: Codable, Equatable, Sendable {
    public var restoredWindowCount: Int
    public var restoredTabCount: Int
    public var createdWindows: [FinderWindowReference]
    public var skippedPaths: [String]
    public var warnings: [WorkspaceWarning]
    public var errors: [WorkspaceOperationError]

    public init(
        restoredWindowCount: Int = 0,
        restoredTabCount: Int = 0,
        createdWindows: [FinderWindowReference] = [],
        skippedPaths: [String] = [],
        warnings: [WorkspaceWarning] = [],
        errors: [WorkspaceOperationError] = []
    ) {
        self.restoredWindowCount = restoredWindowCount
        self.restoredTabCount = restoredTabCount
        self.createdWindows = createdWindows
        self.skippedPaths = skippedPaths
        self.warnings = warnings
        self.errors = errors
    }
}

public struct FinderCloseResult: Codable, Equatable, Sendable {
    public var closedWindowCount: Int
    public var missingWindows: [FinderWindowReference]
    public var failedWindows: [FinderWindowReference]
    public var errors: [WorkspaceOperationError]

    public init(
        closedWindowCount: Int = 0,
        missingWindows: [FinderWindowReference] = [],
        failedWindows: [FinderWindowReference] = [],
        errors: [WorkspaceOperationError] = []
    ) {
        self.closedWindowCount = closedWindowCount
        self.missingWindows = missingWindows
        self.failedWindows = failedWindows
        self.errors = errors
    }
}

public struct SaveAndCloseResult: Equatable, Sendable {
    public var workspace: WorkspaceSnapshot
    public var closedWindowCount: Int
    public var windowsLeftOpen: [FinderWindowReference]
    public var warnings: [WorkspaceWarning]
    public var errors: [WorkspaceOperationError]

    public init(
        workspace: WorkspaceSnapshot,
        closedWindowCount: Int,
        windowsLeftOpen: [FinderWindowReference],
        warnings: [WorkspaceWarning],
        errors: [WorkspaceOperationError]
    ) {
        self.workspace = workspace
        self.closedWindowCount = closedWindowCount
        self.windowsLeftOpen = windowsLeftOpen
        self.warnings = warnings
        self.errors = errors
    }
}

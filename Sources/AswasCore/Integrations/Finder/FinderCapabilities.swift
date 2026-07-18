import Foundation

public enum AutomationPermissionStatus: Codable, Equatable, Sendable {
    case granted
    case notDetermined
    case denied
    case finderUnavailable
    case unknown(Int32)
}

public enum AccessibilityPermissionStatus: String, Codable, Equatable, Sendable {
    case notRequired
    case required
    case granted
}

public struct FinderCapabilities: Codable, Equatable, Sendable {
    public var automationPermission: AutomationPermissionStatus
    public var accessibilityPermission: AccessibilityPermissionStatus
    public var canCaptureWindows: Bool
    public var canRestoreWindows: Bool
    public var canCaptureTabs: Bool
    public var canRestoreTabs: Bool

    public init(
        automationPermission: AutomationPermissionStatus,
        accessibilityPermission: AccessibilityPermissionStatus,
        canCaptureWindows: Bool,
        canRestoreWindows: Bool,
        canCaptureTabs: Bool,
        canRestoreTabs: Bool
    ) {
        self.automationPermission = automationPermission
        self.accessibilityPermission = accessibilityPermission
        self.canCaptureWindows = canCaptureWindows
        self.canRestoreWindows = canRestoreWindows
        self.canCaptureTabs = canCaptureTabs
        self.canRestoreTabs = canRestoreTabs
    }
}

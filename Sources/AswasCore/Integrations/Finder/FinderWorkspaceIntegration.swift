import Foundation

public protocol FinderWorkspaceIntegration: Sendable {
    func checkCapabilities() async -> FinderCapabilities
    func requestAutomationPermission() async -> AutomationPermissionStatus
    func captureCurrentState() async throws -> FinderCaptureResult
    func restore(
        _ state: FinderWorkspaceState,
        mode: RestoreMode
    ) async throws -> FinderRestoreResult
    func closeManagedWindows(
        _ windows: [FinderWindowReference]
    ) async throws -> FinderCloseResult
}

public enum FinderIntegrationError: LocalizedError, Equatable, Sendable {
    case permissionDenied
    case accessibilityPermissionRequired
    case tabOrderUnavailable
    case finderUnavailable
    case scriptExecutionFailed(code: Int?, message: String)
    case malformedResponse
    case noReadableWindows
    case operationInProgress

    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return AswasLocalization.string("error.permission_denied")
        case .accessibilityPermissionRequired:
            return AswasLocalization.string("error.accessibility_required")
        case .tabOrderUnavailable:
            return AswasLocalization.string("error.tab_order_unavailable")
        case .finderUnavailable:
            return AswasLocalization.string("error.finder_unavailable")
        case .scriptExecutionFailed:
            return AswasLocalization.string("error.script_failed")
        case .malformedResponse:
            return AswasLocalization.string("error.malformed_response")
        case .noReadableWindows:
            return AswasLocalization.string("error.empty_workspace")
        case .operationInProgress:
            return AswasLocalization.string("error.operation_progress")
        }
    }
}

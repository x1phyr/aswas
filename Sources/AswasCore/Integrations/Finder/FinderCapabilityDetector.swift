import ApplicationServices
import Foundation

public struct FinderCapabilityDetector: Sendable {
    public init() {}

    public func check(askUserIfNeeded: Bool) -> FinderCapabilities {
        let permission = automationPermission(askUserIfNeeded: askUserIfNeeded)
        let automationGranted = permission == .granted

        return FinderCapabilities(
            automationPermission: permission,
            accessibilityPermission: AXIsProcessTrusted() ? .granted : .notRequired,
            canCaptureWindows: automationGranted,
            canRestoreWindows: automationGranted,
            canCaptureTabs: false,
            canRestoreTabs: false
        )
    }

    public func automationPermission(askUserIfNeeded: Bool) -> AutomationPermissionStatus {
        let target = NSAppleEventDescriptor(bundleIdentifier: "com.apple.finder")
        guard let descriptor = target.aeDesc else {
            return .finderUnavailable
        }

        let status = AEDeterminePermissionToAutomateTarget(
            descriptor,
            typeWildCard,
            typeWildCard,
            askUserIfNeeded
        )

        switch status {
        case noErr:
            return .granted
        case OSStatus(errAEEventWouldRequireUserConsent):
            return .notDetermined
        case OSStatus(errAEEventNotPermitted):
            return .denied
        case OSStatus(procNotFound):
            return .finderUnavailable
        default:
            return .unknown(status)
        }
    }
}

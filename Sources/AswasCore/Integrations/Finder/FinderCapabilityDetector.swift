import ApplicationServices
import Foundation

public struct FinderCapabilityDetector: Sendable {
    public init() {}

    public func check(askUserIfNeeded: Bool) -> FinderCapabilities {
        let permission = automationPermission(askUserIfNeeded: askUserIfNeeded)
        let automationGranted = permission == .granted

        return FinderCapabilities(
            automationPermission: permission,
            accessibilityPermission: AXIsProcessTrusted() ? .granted : .required,
            canCaptureWindows: automationGranted,
            canRestoreWindows: automationGranted,
            canCaptureTabs: automationGranted && AXIsProcessTrusted(),
            canRestoreTabs: automationGranted && AXIsProcessTrusted()
        )
    }

    public func requestAccessibilityPermission() -> AccessibilityPermissionStatus {
        let options = [
            "AXTrustedCheckOptionPrompt": true
        ] as CFDictionary
        return AXIsProcessTrustedWithOptions(options) ? .granted : .required
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

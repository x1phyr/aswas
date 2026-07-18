import AppKit
import Foundation

public struct DisplaySnapshot: Equatable, Sendable {
    public var displays: [DisplayDescriptor]
    public var mainDisplayID: UInt32?

    public init(displays: [DisplayDescriptor], mainDisplayID: UInt32?) {
        self.displays = displays
        self.mainDisplayID = mainDisplayID
    }

    public var mainDisplay: DisplayDescriptor? {
        displays.first { $0.displayID == mainDisplayID } ?? displays.first
    }
}

public protocol DisplaySnapshotProviding: Sendable {
    @MainActor func snapshot() -> DisplaySnapshot
}

public struct SystemDisplayProvider: DisplaySnapshotProviding, Sendable {
    public init() {}

    @MainActor
    public func snapshot() -> DisplaySnapshot {
        let screens = NSScreen.screens
        guard let mainScreen = NSScreen.main ?? screens.first else {
            return DisplaySnapshot(displays: [], mainDisplayID: nil)
        }
        let mainTop = mainScreen.frame.maxY
        let displays = screens.map { screen in
            DisplayDescriptor(
                displayID: Self.displayID(for: screen),
                localizedName: screen.localizedName,
                frame: Self.finderRect(from: screen.frame, mainTop: mainTop),
                visibleFrame: Self.finderRect(from: screen.visibleFrame, mainTop: mainTop),
                scaleFactor: screen.backingScaleFactor
            )
        }
        return DisplaySnapshot(
            displays: displays,
            mainDisplayID: Self.displayID(for: mainScreen)
        )
    }

    private static func displayID(for screen: NSScreen) -> UInt32? {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?
            .uint32Value
    }

    static func finderRect(from appKitRect: NSRect, mainTop: CGFloat) -> CodableRect {
        CodableRect(
            x: appKitRect.minX,
            y: mainTop - appKitRect.maxY,
            width: appKitRect.width,
            height: appKitRect.height
        )
    }
}

import Foundation

public struct CapturedWindowPlacement: Equatable, Sendable {
    public var display: DisplayDescriptor?
    public var normalizedFrame: CodableRect?

    public init(display: DisplayDescriptor?, normalizedFrame: CodableRect?) {
        self.display = display
        self.normalizedFrame = normalizedFrame
    }
}

public struct RestoredWindowPlacement: Equatable, Sendable {
    public var frame: CodableRect
    public var display: DisplayDescriptor
    public var usedFallbackDisplay: Bool

    public init(
        frame: CodableRect,
        display: DisplayDescriptor,
        usedFallbackDisplay: Bool
    ) {
        self.frame = frame
        self.display = display
        self.usedFallbackDisplay = usedFallbackDisplay
    }
}

public enum WindowPlacement {
    public static func capture(
        frame: CodableRect,
        displays: DisplaySnapshot
    ) -> CapturedWindowPlacement {
        guard let display = bestContainingDisplay(for: frame, in: displays.displays) else {
            return CapturedWindowPlacement(display: nil, normalizedFrame: nil)
        }
        return CapturedWindowPlacement(
            display: display,
            normalizedFrame: normalize(frame, in: display.visibleFrame)
        )
    }

    public static func restore(
        window: FinderWindowState,
        displays: DisplaySnapshot,
        minimumWidth: Double = 360,
        minimumHeight: Double = 240
    ) -> RestoredWindowPlacement? {
        guard let target = matchedDisplay(saved: window.display, current: displays) else {
            return nil
        }
        let exactIDMatch = window.display?.displayID != nil
            && window.display?.displayID == target.displayID
        let sameDisplayGeometry = window.display.map {
            approximatelyEqual($0.visibleFrame.width, target.visibleFrame.width)
                && approximatelyEqual($0.visibleFrame.height, target.visibleFrame.height)
        } ?? false

        let candidate: CodableRect
        if exactIDMatch, sameDisplayGeometry, let absolute = window.frame {
            candidate = absolute
        } else if let normalized = window.normalizedFrame {
            candidate = denormalize(normalized, in: target.visibleFrame)
        } else if let absolute = window.frame {
            candidate = absolute
        } else {
            candidate = CodableRect(
                x: target.visibleFrame.x + 40,
                y: target.visibleFrame.y + 40,
                width: min(900, target.visibleFrame.width),
                height: min(700, target.visibleFrame.height)
            )
        }

        return RestoredWindowPlacement(
            frame: clamp(
                candidate,
                to: target.visibleFrame,
                minimumWidth: minimumWidth,
                minimumHeight: minimumHeight
            ),
            display: target,
            usedFallbackDisplay: !exactIDMatch && window.display != nil
        )
    }

    static func normalize(_ frame: CodableRect, in visibleFrame: CodableRect) -> CodableRect {
        CodableRect(
            x: (frame.x - visibleFrame.x) / visibleFrame.width,
            y: (frame.y - visibleFrame.y) / visibleFrame.height,
            width: frame.width / visibleFrame.width,
            height: frame.height / visibleFrame.height
        )
    }

    static func denormalize(_ frame: CodableRect, in visibleFrame: CodableRect) -> CodableRect {
        CodableRect(
            x: visibleFrame.x + frame.x * visibleFrame.width,
            y: visibleFrame.y + frame.y * visibleFrame.height,
            width: frame.width * visibleFrame.width,
            height: frame.height * visibleFrame.height
        )
    }

    static func clamp(
        _ frame: CodableRect,
        to visibleFrame: CodableRect,
        minimumWidth: Double,
        minimumHeight: Double
    ) -> CodableRect {
        let effectiveMinimumWidth = min(minimumWidth, visibleFrame.width)
        let effectiveMinimumHeight = min(minimumHeight, visibleFrame.height)
        let width = min(max(frame.width, effectiveMinimumWidth), visibleFrame.width)
        let height = min(max(frame.height, effectiveMinimumHeight), visibleFrame.height)
        let maximumX = visibleFrame.x + visibleFrame.width - width
        let maximumY = visibleFrame.y + visibleFrame.height - height

        return CodableRect(
            x: min(max(frame.x, visibleFrame.x), maximumX),
            y: min(max(frame.y, visibleFrame.y), maximumY),
            width: width,
            height: height
        )
    }

    private static func matchedDisplay(
        saved: DisplayDescriptor?,
        current: DisplaySnapshot
    ) -> DisplayDescriptor? {
        guard let saved else { return current.mainDisplay }
        if let id = saved.displayID,
           let match = current.displays.first(where: { $0.displayID == id }) {
            return match
        }
        if let name = saved.localizedName,
           let match = current.displays.first(where: { $0.localizedName == name }) {
            return match
        }
        if let match = current.displays.first(where: {
            approximatelyEqual($0.frame.width, saved.frame.width)
                && approximatelyEqual($0.frame.height, saved.frame.height)
                && approximatelyEqual($0.scaleFactor, saved.scaleFactor, tolerance: 0.01)
        }) {
            return match
        }
        if let match = current.displays.first(where: {
            approximatelyEqual($0.frame.width, saved.frame.width)
                && approximatelyEqual($0.frame.height, saved.frame.height)
        }) {
            return match
        }
        return current.mainDisplay
    }

    private static func bestContainingDisplay(
        for frame: CodableRect,
        in displays: [DisplayDescriptor]
    ) -> DisplayDescriptor? {
        guard let match = displays.max(by: { lhs, rhs in
            intersectionArea(frame, lhs.visibleFrame) < intersectionArea(frame, rhs.visibleFrame)
        }) else { return nil }
        return intersectionArea(frame, match.visibleFrame) > 0 ? match : nil
    }

    private static func intersectionArea(_ lhs: CodableRect, _ rhs: CodableRect) -> Double {
        let width = max(0, min(lhs.x + lhs.width, rhs.x + rhs.width) - max(lhs.x, rhs.x))
        let height = max(0, min(lhs.y + lhs.height, rhs.y + rhs.height) - max(lhs.y, rhs.y))
        return width * height
    }

    private static func approximatelyEqual(
        _ lhs: Double,
        _ rhs: Double,
        tolerance: Double = 1
    ) -> Bool {
        abs(lhs - rhs) <= tolerance
    }
}

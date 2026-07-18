import AppKit
import Testing
@testable import AswasCore

struct WindowPlacementTests {
    @Test
    func convertsAppKitCoordinatesToFinderTopLeftCoordinates() {
        let converted = SystemDisplayProvider.finderRect(
            from: NSRect(x: -1920, y: 0, width: 1920, height: 1080),
            mainTop: 982
        )

        #expect(converted == CodableRect(x: -1920, y: -98, width: 1920, height: 1080))
    }

    @Test
    func capturesWindowOnLeftDisplayWithNegativeCoordinate() {
        let main = display(id: 1, name: "Main", x: 0, y: 0, width: 1512, height: 950)
        let left = display(id: 2, name: "Left", x: -1920, y: -98, width: 1920, height: 1080)
        let snapshot = DisplaySnapshot(displays: [main, left], mainDisplayID: 1)
        let frame = CodableRect(x: -1800, y: 20, width: 900, height: 700)

        let placement = WindowPlacement.capture(frame: frame, displays: snapshot)

        #expect(placement.display?.displayID == 2)
        #expect(placement.normalizedFrame != nil)
    }

    @Test
    func capturesWindowOnDisplayAboveMain() {
        let main = display(id: 1, name: "Main", x: 0, y: 0, width: 1512, height: 950)
        let above = display(id: 3, name: "Above", x: 100, y: -900, width: 1440, height: 900)
        let snapshot = DisplaySnapshot(displays: [main, above], mainDisplayID: 1)

        let placement = WindowPlacement.capture(
            frame: CodableRect(x: 200, y: -800, width: 800, height: 600),
            displays: snapshot
        )

        #expect(placement.display?.displayID == 3)
    }

    @Test
    func mapsNormalizedFrameToMainWhenSavedDisplayIsRemoved() {
        let oldDisplay = display(id: 2, name: "External", x: 1512, y: 0, width: 1920, height: 1080)
        let main = display(id: 1, name: "Main", x: 0, y: 0, width: 1512, height: 950)
        var window = makeWorkspace().finder.windows[0]
        window.display = oldDisplay
        window.frame = CodableRect(x: 1700, y: 100, width: 1000, height: 700)
        window.normalizedFrame = CodableRect(x: 0.1, y: 0.1, width: 0.6, height: 0.7)

        let restored = WindowPlacement.restore(
            window: window,
            displays: DisplaySnapshot(displays: [main], mainDisplayID: 1)
        )

        #expect(restored?.display.displayID == 1)
        #expect(restored?.usedFallbackDisplay == true)
        #expect(abs((restored?.frame.x ?? 0) - 151.2) < 0.001)
        #expect(abs((restored?.frame.y ?? 0) - 95) < 0.001)
        #expect(abs((restored?.frame.width ?? 0) - 907.2) < 0.001)
    }

    @Test
    func remapsNormalizedFrameAfterResolutionChange() {
        let saved = display(id: 1, name: "Main", x: 0, y: 0, width: 1512, height: 950, scale: 2)
        let current = display(id: 1, name: "Main", x: 0, y: 0, width: 1920, height: 1040, scale: 1)
        var window = makeWorkspace().finder.windows[0]
        window.display = saved
        window.frame = CodableRect(x: 151, y: 95, width: 900, height: 650)
        window.normalizedFrame = CodableRect(x: 0.1, y: 0.1, width: 0.6, height: 0.7)

        let restored = WindowPlacement.restore(
            window: window,
            displays: DisplaySnapshot(displays: [current], mainDisplayID: 1)
        )

        #expect(restored?.frame.x == 192)
        #expect(restored?.frame.y == 104)
        #expect(restored?.frame.width == 1152)
        #expect(restored?.frame.height == 728)
    }

    @Test
    func clampsOffscreenAndUndersizedWindow() {
        let main = display(id: 1, name: "Main", x: 0, y: 25, width: 1280, height: 700)
        var window = makeWorkspace().finder.windows[0]
        window.display = main
        window.frame = CodableRect(x: 5000, y: -300, width: 10, height: 20)
        window.normalizedFrame = nil

        let restored = WindowPlacement.restore(
            window: window,
            displays: DisplaySnapshot(displays: [main], mainDisplayID: 1)
        )

        #expect(restored?.frame == CodableRect(x: 920, y: 25, width: 360, height: 240))
    }
}

private func display(
    id: UInt32,
    name: String,
    x: Double,
    y: Double,
    width: Double,
    height: Double,
    scale: Double = 2
) -> DisplayDescriptor {
    DisplayDescriptor(
        displayID: id,
        localizedName: name,
        frame: CodableRect(x: x, y: y, width: width, height: height),
        visibleFrame: CodableRect(x: x, y: y, width: width, height: height),
        scaleFactor: scale
    )
}

import AppKit
import ApplicationServices
import Foundation

struct FinderCapturedTabSnapshot: Equatable, Sendable {
    var windowIDs: [Int]
    var tabs: [FinderTabState]
    var selectedTabIndex: Int
}

struct FinderTabRestoreOutcome: Equatable, Sendable {
    var restoredAdditionalTabs: Int
    var failedPaths: [String]
    var selectedTabRestored: Bool
}

/// Adds Finder tab fidelity through the public macOS Accessibility API.
///
/// Finder exposes each tab as an AppleScript window. The controller reads the tab strip
/// without changing it, then uses its titles, order, and selected value to regroup those
/// AppleScript entries into physical Finder windows.
/// All callers are serialized by `FinderAppleScriptIntegration`.
final class FinderAccessibilityTabController: @unchecked Sendable {
    typealias FrontWindowTargetSetter = @Sendable (String) async throws -> Bool

    private let finderBundleIdentifier = "com.apple.finder"
    private let tabChangeDelayNanoseconds: UInt64 = 300_000_000

    func captureTabs(
        for windows: [FinderCapturedWindowPayload]
    ) -> [FinderCapturedTabSnapshot] {
        guard AXIsProcessTrusted(), let context = finderContext() else { return [] }

        var snapshots: [FinderCapturedTabSnapshot] = []
        var availableAXWindows = context.windows

        for group in FinderCapturedWindowGrouper.group(windows) {
            guard let representative = group.first,
                  let matchIndex = bestWindowMatch(for: representative, in: availableAXWindows) else {
                continue
            }
            let axWindow = availableAXWindows.remove(at: matchIndex)
            guard let tabGroup = firstDescendant(of: axWindow, matchingRole: kAXTabGroupRole as String) else {
                continue
            }

            let tabButtons = descendants(of: tabGroup).filter(isTabButton)
            guard !tabButtons.isEmpty else { continue }

            let selectedIndex = tabButtons.firstIndex(where: isSelected) ?? 0
            let titles = tabButtons.compactMap { button -> String? in
                attribute(button, kAXTitleAttribute as String)
            }
            let orderedWindows = order(group, usingTabTitles: titles)
            if orderedWindows.count == tabButtons.count {
                snapshots.append(
                    FinderCapturedTabSnapshot(
                    windowIDs: group.map(\.id),
                    tabs: orderedWindows.map(tabState),
                    selectedTabIndex: selectedIndex
                )
                )
            }
        }

        return snapshots
    }

    func restoreAdditionalTabs(
        paths: [String],
        selectedTabIndex: Int,
        expectedWindowFrame: CodableRect?,
        setFrontWindowTarget: @escaping FrontWindowTargetSetter
    ) async -> FinderTabRestoreOutcome {
        guard AXIsProcessTrusted(), let context = finderContext() else {
            return FinderTabRestoreOutcome(
                restoredAdditionalTabs: 0,
                failedPaths: paths,
                selectedTabRestored: selectedTabIndex == 0
            )
        }

        // AppleScript can create the window while aswas is still the active app.
        // Explicitly focus the just-created Finder window before sending Command-T;
        // otherwise the shortcut may be delivered to aswas and no tab is created.
        if let targetWindow = restoreTargetWindow(
            expectedFrame: expectedWindowFrame,
            in: context.windows
        ) {
            focus(window: targetWindow)
        }
        context.application.activate(options: [])
        await waitForFinderTabChange()

        var restoredCount = 0
        var failedPaths: [String] = []

        for path in paths {
            guard postCommandKey(virtualKey: 17) else {
                failedPaths.append(path)
                continue
            }
            await waitForFinderTabChange()
            do {
                if try await setFrontWindowTarget(path) {
                    restoredCount += 1
                } else {
                    failedPaths.append(path)
                    _ = postCommandKey(virtualKey: 13) // Command-W closes only the failed new tab.
                    await waitForFinderTabChange()
                }
            } catch {
                failedPaths.append(path)
                _ = postCommandKey(virtualKey: 13)
                await waitForFinderTabChange()
            }
        }

        let selectedRestored = selectTab(at: selectedTabIndex, in: context.element)
        if selectedRestored {
            await waitForFinderTabChange()
        }
        return FinderTabRestoreOutcome(
            restoredAdditionalTabs: restoredCount,
            failedPaths: failedPaths,
            selectedTabRestored: selectedRestored
        )
    }

    private func order(
        _ windows: [FinderCapturedWindowPayload],
        usingTabTitles titles: [String]
    ) -> [FinderCapturedWindowPayload] {
        guard titles.count == windows.count else {
            return windows.sorted(by: { $0.index < $1.index })
        }
        var remaining = windows.sorted(by: { $0.index < $1.index })
        var ordered: [FinderCapturedWindowPayload] = []
        for title in titles {
            if let match = remaining.firstIndex(where: { $0.name == title }) {
                ordered.append(remaining.remove(at: match))
            } else if !remaining.isEmpty {
                ordered.append(remaining.removeFirst())
            }
        }
        return ordered + remaining
    }

    private func tabState(from window: FinderCapturedWindowPayload) -> FinderTabState {
        FinderTabState(
            path: PathNormalizer.normalize(window.path),
            displayName: window.name.isEmpty ? nil : window.name
        )
    }

    private func finderContext() -> FinderContext? {
        guard let application = NSRunningApplication.runningApplications(
            withBundleIdentifier: finderBundleIdentifier
        ).first else {
            return nil
        }
        let element = AXUIElementCreateApplication(application.processIdentifier)
        guard let windows: [AXUIElement] = attribute(element, kAXWindowsAttribute as String) else {
            return nil
        }
        return FinderContext(application: application, element: element, windows: windows)
    }

    private func bestWindowMatch(
        for window: FinderCapturedWindowPayload,
        in candidates: [AXUIElement]
    ) -> Int? {
        guard window.bounds.count == 4 else { return nil }
        let expectedPosition = CGPoint(x: window.bounds[0], y: window.bounds[1])
        let expectedSize = CGSize(
            width: window.bounds[2] - window.bounds[0],
            height: window.bounds[3] - window.bounds[1]
        )

        return candidates.indices.min { lhs, rhs in
            windowMatchScore(
                candidates[lhs],
                expectedTitle: window.name,
                expectedPosition: expectedPosition,
                expectedSize: expectedSize
            ) < windowMatchScore(
                candidates[rhs],
                expectedTitle: window.name,
                expectedPosition: expectedPosition,
                expectedSize: expectedSize
            )
        }.flatMap { index in
            windowMatchScore(
                candidates[index],
                expectedTitle: window.name,
                expectedPosition: expectedPosition,
                expectedSize: expectedSize
            ) <= 240
                ? index
                : nil
        }
    }

    private func windowMatchScore(
        _ window: AXUIElement,
        expectedTitle: String,
        expectedPosition: CGPoint,
        expectedSize: CGSize
    ) -> CGFloat {
        let geometry = windowDistance(
            window,
            expectedPosition: expectedPosition,
            expectedSize: expectedSize
        )
        guard geometry.isFinite else { return geometry }
        let title: String? = attribute(window, kAXTitleAttribute as String)
        if expectedTitle.isEmpty || title == expectedTitle { return geometry }
        return geometry + 120
    }

    private func windowDistance(
        _ window: AXUIElement,
        expectedPosition: CGPoint,
        expectedSize: CGSize
    ) -> CGFloat {
        guard let position = pointAttribute(window, kAXPositionAttribute as String),
              let size = sizeAttribute(window, kAXSizeAttribute as String) else {
            return .greatestFiniteMagnitude
        }
        return abs(position.x - expectedPosition.x)
            + abs(position.y - expectedPosition.y)
            + abs(size.width - expectedSize.width)
            + abs(size.height - expectedSize.height)
    }

    private func selectTab(at index: Int, in applicationElement: AXUIElement) -> Bool {
        guard let focusedWindow: AXUIElement = attribute(
            applicationElement,
            kAXFocusedWindowAttribute as String
        ), let tabGroup = firstDescendant(
            of: focusedWindow,
            matchingRole: kAXTabGroupRole as String
        ) else {
            return index == 0
        }
        let buttons = descendants(of: tabGroup).filter(isTabButton)
        guard buttons.indices.contains(index) else { return false }
        return select(tab: buttons[index])
    }

    private func restoreTargetWindow(
        expectedFrame: CodableRect?,
        in windows: [AXUIElement]
    ) -> AXUIElement? {
        guard let expectedFrame else { return windows.first }
        let expectedPosition = CGPoint(x: expectedFrame.x, y: expectedFrame.y)
        let expectedSize = CGSize(width: expectedFrame.width, height: expectedFrame.height)
        return windows.min { lhs, rhs in
            windowDistance(
                lhs,
                expectedPosition: expectedPosition,
                expectedSize: expectedSize
            ) < windowDistance(
                rhs,
                expectedPosition: expectedPosition,
                expectedSize: expectedSize
            )
        }
    }

    private func focus(window: AXUIElement) {
        _ = AXUIElementSetAttributeValue(
            window,
            kAXMainAttribute as CFString,
            kCFBooleanTrue
        )
        _ = AXUIElementSetAttributeValue(
            window,
            kAXFocusedAttribute as CFString,
            kCFBooleanTrue
        )
        _ = AXUIElementPerformAction(window, kAXRaiseAction as CFString)
    }

    private func select(tab: AXUIElement) -> Bool {
        if AXUIElementPerformAction(tab, kAXPressAction as CFString) == .success {
            return true
        }
        return AXUIElementSetAttributeValue(
            tab,
            kAXValueAttribute as CFString,
            kCFBooleanTrue
        ) == .success
    }

    private func firstDescendant(of root: AXUIElement, matchingRole role: String) -> AXUIElement? {
        descendants(of: root).first { elementRole($0) == role }
    }

    private func descendants(of root: AXUIElement) -> [AXUIElement] {
        var result: [AXUIElement] = []
        var queue: [AXUIElement] = [root]
        var cursor = 0
        while cursor < queue.count, result.count < 2_000 {
            let element = queue[cursor]
            cursor += 1
            guard let children: [AXUIElement] = attribute(element, kAXChildrenAttribute as String) else {
                continue
            }
            result.append(contentsOf: children)
            queue.append(contentsOf: children)
        }
        return result
    }

    private func isTabButton(_ element: AXUIElement) -> Bool {
        let role = elementRole(element)
        let subrole: String? = attribute(element, kAXSubroleAttribute as String)
        return role == (kAXRadioButtonRole as String)
            || role == "AXTabButton"
            || subrole == "AXTabButton"
    }

    private func isSelected(_ element: AXUIElement) -> Bool {
        guard let value: AnyObject = rawAttribute(element, kAXValueAttribute as String) else {
            return false
        }
        if let number = value as? NSNumber { return number.boolValue }
        if let string = value as? String {
            return ["1", "true", "on", "selected"].contains(string.lowercased())
        }
        return false
    }

    private func elementRole(_ element: AXUIElement) -> String? {
        attribute(element, kAXRoleAttribute as String)
    }

    private func attribute<T>(_ element: AXUIElement, _ name: String) -> T? {
        rawAttribute(element, name) as? T
    }

    private func rawAttribute(_ element: AXUIElement, _ name: String) -> AnyObject? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else {
            return nil
        }
        return value
    }

    private func pointAttribute(_ element: AXUIElement, _ name: String) -> CGPoint? {
        guard let raw = rawAttribute(element, name), CFGetTypeID(raw) == AXValueGetTypeID() else {
            return nil
        }
        var point = CGPoint.zero
        guard AXValueGetValue(raw as! AXValue, .cgPoint, &point) else { return nil }
        return point
    }

    private func sizeAttribute(_ element: AXUIElement, _ name: String) -> CGSize? {
        guard let raw = rawAttribute(element, name), CFGetTypeID(raw) == AXValueGetTypeID() else {
            return nil
        }
        var size = CGSize.zero
        guard AXValueGetValue(raw as! AXValue, .cgSize, &size) else { return nil }
        return size
    }

    private func postCommandKey(virtualKey: CGKeyCode) -> Bool {
        guard let source = CGEventSource(stateID: .hidSystemState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: false) else {
            return false
        }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return true
    }

    private func waitForFinderTabChange() async {
        try? await Task.sleep(nanoseconds: tabChangeDelayNanoseconds)
    }
}

private struct FinderContext {
    var application: NSRunningApplication
    var element: AXUIElement
    var windows: [AXUIElement]
}

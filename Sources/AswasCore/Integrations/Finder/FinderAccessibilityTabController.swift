import AppKit
import ApplicationServices
import Foundation

struct FinderCapturedTabSnapshot: Equatable, Sendable {
    var windowIDs: [Int]
    var tabs: [FinderTabState]
    var selectedTabIndex: Int
}

struct FinderAccessibilityWindowDescriptor: Equatable, Sendable {
    var frame: CodableRect?
    var tabTitles: [String]
    var selectedTabIndex: Int
}

/// Matches Finder's physical Accessibility windows to the window-like entries
/// returned for individual tabs by AppleScript.
enum FinderCapturedTabMatcher {
    private static let maximumAnchorDistance = 240.0

    static func match(
        windows: [FinderCapturedWindowPayload],
        descriptors: [FinderAccessibilityWindowDescriptor]
    ) -> [FinderCapturedTabSnapshot] {
        var remaining = Dictionary(uniqueKeysWithValues: windows.map { ($0.id, $0) })
        var snapshots: [FinderCapturedTabSnapshot] = []

        for descriptor in descriptors {
            guard !descriptor.tabTitles.isEmpty,
                  descriptor.tabTitles.indices.contains(descriptor.selectedTabIndex) else {
                continue
            }

            let selectedTitle = descriptor.tabTitles[descriptor.selectedTabIndex]
            guard let anchor = bestAnchor(
                titled: selectedTitle,
                expectedFrame: descriptor.frame,
                candidates: Array(remaining.values)
            ) else {
                continue
            }

            // Work on a copy so an ambiguous tab does not consume entries needed by
            // another physical Finder window.
            var candidateRemaining = remaining
            candidateRemaining.removeValue(forKey: anchor.id)
            var orderedWindows: [FinderCapturedWindowPayload?] = Array(
                repeating: nil,
                count: descriptor.tabTitles.count
            )
            orderedWindows[descriptor.selectedTabIndex] = anchor

            var complete = true
            for index in descriptor.tabTitles.indices where index != descriptor.selectedTabIndex {
                guard let match = matchInactiveTab(
                    titled: descriptor.tabTitles[index],
                    anchor: anchor,
                    candidates: Array(candidateRemaining.values)
                ) else {
                    complete = false
                    break
                }
                orderedWindows[index] = match
                candidateRemaining.removeValue(forKey: match.id)
            }

            guard complete else { continue }
            let resolved = orderedWindows.compactMap { $0 }
            guard resolved.count == descriptor.tabTitles.count else { continue }

            remaining = candidateRemaining
            snapshots.append(
                FinderCapturedTabSnapshot(
                    windowIDs: resolved.map(\.id),
                    tabs: resolved.map(tabState),
                    selectedTabIndex: descriptor.selectedTabIndex
                )
            )
        }

        return snapshots
    }

    private static func bestAnchor(
        titled title: String,
        expectedFrame: CodableRect?,
        candidates: [FinderCapturedWindowPayload]
    ) -> FinderCapturedWindowPayload? {
        let titledCandidates = candidates.filter { $0.name == title }
        guard !titledCandidates.isEmpty else { return nil }
        guard let expectedFrame else {
            return titledCandidates.count == 1 ? titledCandidates[0] : nil
        }

        let ranked = titledCandidates
            .map { ($0, frameDistance($0, expectedFrame)) }
            .sorted { $0.1 < $1.1 }
        guard let best = ranked.first, best.1 <= maximumAnchorDistance else { return nil }
        if ranked.count > 1, ranked[1].1 == best.1 { return nil }
        return best.0
    }

    private static func matchInactiveTab(
        titled title: String,
        anchor: FinderCapturedWindowPayload,
        candidates: [FinderCapturedWindowPayload]
    ) -> FinderCapturedWindowPayload? {
        let titledCandidates = candidates.filter { $0.name == title }
        if titledCandidates.count == 1 { return titledCandidates[0] }

        // Bounds are only a duplicate-title tie breaker. Finder may leave inactive
        // tabs at a stale frame after their physical window moves.
        let matchingAnchorBounds = titledCandidates.filter {
            FinderCapturedWindowGrouper.haveMatchingBounds($0, anchor)
        }
        return matchingAnchorBounds.count == 1 ? matchingAnchorBounds[0] : nil
    }

    private static func frameDistance(
        _ window: FinderCapturedWindowPayload,
        _ frame: CodableRect
    ) -> Double {
        guard window.bounds.count == 4 else { return .greatestFiniteMagnitude }
        return abs(window.bounds[0] - frame.x)
            + abs(window.bounds[1] - frame.y)
            + abs((window.bounds[2] - window.bounds[0]) - frame.width)
            + abs((window.bounds[3] - window.bounds[1]) - frame.height)
    }

    private static func tabState(from window: FinderCapturedWindowPayload) -> FinderTabState {
        FinderTabState(
            path: PathNormalizer.normalize(window.path),
            displayName: window.name.isEmpty ? nil : window.name
        )
    }
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
        let descriptors = context.windows.compactMap(windowDescriptor)
        return FinderCapturedTabMatcher.match(windows: windows, descriptors: descriptors)
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

    private func windowDescriptor(_ window: AXUIElement) -> FinderAccessibilityWindowDescriptor? {
        let frame = windowFrame(window)
        if let tabGroup = firstDescendant(
            of: window,
            matchingRole: kAXTabGroupRole as String
        ) {
            let tabElements = tabs(in: tabGroup)
            let titles: [String] = tabElements.compactMap {
                attribute($0, kAXTitleAttribute as String)
            }
            guard !tabElements.isEmpty, titles.count == tabElements.count else { return nil }
            return FinderAccessibilityWindowDescriptor(
                frame: frame,
                tabTitles: titles,
                selectedTabIndex: tabElements.firstIndex(where: isSelected) ?? 0
            )
        }

        guard let title: String = attribute(window, kAXTitleAttribute as String),
              !title.isEmpty else {
            return nil
        }
        return FinderAccessibilityWindowDescriptor(
            frame: frame,
            tabTitles: [title],
            selectedTabIndex: 0
        )
    }

    private func windowFrame(_ window: AXUIElement) -> CodableRect? {
        guard let position = pointAttribute(window, kAXPositionAttribute as String),
              let size = sizeAttribute(window, kAXSizeAttribute as String) else {
            return nil
        }
        return CodableRect(
            x: position.x,
            y: position.y,
            width: size.width,
            height: size.height
        )
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
        let buttons = tabs(in: tabGroup)
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

    private func tabs(in tabGroup: AXUIElement) -> [AXUIElement] {
        let explicitTabs: [AXUIElement]? = attribute(
            tabGroup,
            kAXTabsAttribute as String
        )
        return explicitTabs ?? descendants(of: tabGroup).filter(isTabButton)
    }

    private func isSelected(_ element: AXUIElement) -> Bool {
        if let selected: NSNumber = attribute(element, kAXSelectedAttribute as String) {
            return selected.boolValue
        }
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

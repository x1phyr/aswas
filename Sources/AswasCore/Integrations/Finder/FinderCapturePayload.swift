import Foundation

struct FinderCapturePayload: Decodable, Sendable {
    var schemaVersion: Int
    var windows: [FinderCapturedWindowPayload]
    var warnings: [FinderCaptureWarningPayload]
}

struct FinderCapturedWindowPayload: Decodable, Sendable {
    var id: Int
    var index: Int
    var name: String
    var path: String
    var bounds: [Double]
    var viewMode: String
}

struct FinderCaptureWarningPayload: Decodable, Sendable {
    var code: String
    var errorNumber: Int?
    var message: String
}

enum FinderCapturedWindowGrouper {
    private static let boundsTolerance = 2.0

    static func group(
        _ windows: [FinderCapturedWindowPayload]
    ) -> [[FinderCapturedWindowPayload]] {
        var groups: [[FinderCapturedWindowPayload]] = []
        for window in windows.sorted(by: { $0.index < $1.index }) {
            if let index = groups.firstIndex(where: { group in
                guard let first = group.first else { return false }
                return haveMatchingBounds(first, window)
            }) {
                groups[index].append(window)
            } else {
                groups.append([window])
            }
        }
        return groups
    }

    static func haveMatchingBounds(
        _ lhs: FinderCapturedWindowPayload,
        _ rhs: FinderCapturedWindowPayload
    ) -> Bool {
        guard lhs.bounds.count == 4, rhs.bounds.count == 4 else { return false }
        return zip(lhs.bounds, rhs.bounds).allSatisfy {
            abs($0 - $1) <= boundsTolerance
        }
    }
}

enum FinderCapturePayloadMapper {
    static func map(
        _ payload: FinderCapturePayload,
        displays: DisplaySnapshot? = nil,
        tabSnapshots: [FinderCapturedTabSnapshot] = []
    ) throws -> FinderCaptureResult {
        guard payload.schemaVersion == 1 else {
            throw FinderIntegrationError.malformedResponse
        }

        var windows: [FinderWindowState] = []
        var references: [FinderWindowReference] = []
        var warnings = payload.warnings.map {
            WorkspaceWarning(code: .windowUnreadable, message: $0.message)
        }

        let groupedCaptures = captureGroups(
            windows: payload.windows,
            tabSnapshots: tabSnapshots
        )
        var groupsMissingTabMetadata = 0

        for captureGroup in groupedCaptures {
            let rawGroup = captureGroup.windows
            let capturedTabs = captureGroup.snapshot
            guard let rawWindow = selectedRawWindow(
                from: rawGroup,
                snapshot: capturedTabs
            ) else { continue }
            guard rawWindow.bounds.count == 4 else {
                warnings.append(
                    WorkspaceWarning(
                        code: .windowUnreadable,
                        message: AswasLocalization.string("warning.window_invalid_position")
                    )
                )
                continue
            }

            let left = rawWindow.bounds[0]
            let top = rawWindow.bounds[1]
            let right = rawWindow.bounds[2]
            let bottom = rawWindow.bounds[3]
            let frame = CodableRect(
                x: left,
                y: top,
                width: right - left,
                height: bottom - top
            )
            guard frame.isFiniteAndPositive else {
                warnings.append(
                    WorkspaceWarning(
                        code: .windowUnreadable,
                        message: AswasLocalization.string("warning.window_invalid_dimensions")
                    )
                )
                continue
            }

            let placement = displays.map {
                WindowPlacement.capture(frame: frame, displays: $0)
            }
            let tabs = capturedTabs?.tabs ?? rawGroup
                .sorted(by: { $0.index < $1.index })
                .map {
                    FinderTabState(
                        path: PathNormalizer.normalize($0.path),
                        displayName: $0.name.isEmpty ? nil : $0.name
                    )
                }
            if rawGroup.count > 1, capturedTabs == nil {
                groupsMissingTabMetadata += 1
            }
            windows.append(
                FinderWindowState(
                    tabs: tabs,
                    selectedTabIndex: capturedTabs?.selectedTabIndex ?? 0,
                    frame: frame,
                    normalizedFrame: placement?.normalizedFrame,
                    display: placement?.display,
                    viewMode: FinderViewMode(rawValue: rawWindow.viewMode) ?? .unknown
                )
            )
            references.append(contentsOf: rawGroup.map { FinderWindowReference(windowID: $0.id) })
        }

        guard !windows.isEmpty else {
            throw FinderIntegrationError.noReadableWindows
        }

        if groupsMissingTabMetadata > 0 {
            warnings.append(
                WorkspaceWarning(
                    code: .tabsUnavailable,
                    message: AswasLocalization.string("warning.tabs_unavailable_capture")
                )
            )
        }
        if displays?.displays.isEmpty == true {
            warnings.append(
                WorkspaceWarning(
                    code: .displayUnavailable,
                    message: AswasLocalization.string("warning.display_capture")
                )
            )
        }

        return FinderCaptureResult(
            state: FinderWorkspaceState(windows: windows),
            managedWindows: references,
            warnings: warnings
        )
    }

    private struct CaptureGroup {
        var windows: [FinderCapturedWindowPayload]
        var snapshot: FinderCapturedTabSnapshot?
    }

    private static func captureGroups(
        windows: [FinderCapturedWindowPayload],
        tabSnapshots: [FinderCapturedTabSnapshot]
    ) -> [CaptureGroup] {
        let windowsByID = Dictionary(uniqueKeysWithValues: windows.map { ($0.id, $0) })
        var consumedWindowIDs: Set<Int> = []
        var groups: [CaptureGroup] = []

        for snapshot in tabSnapshots {
            let uniqueIDs = Set(snapshot.windowIDs)
            guard uniqueIDs.count == snapshot.windowIDs.count,
                  snapshot.tabs.count == snapshot.windowIDs.count,
                  uniqueIDs.isDisjoint(with: consumedWindowIDs) else {
                continue
            }
            let resolved = snapshot.windowIDs.compactMap { windowsByID[$0] }
            guard resolved.count == snapshot.windowIDs.count else { continue }
            groups.append(CaptureGroup(windows: resolved, snapshot: snapshot))
            consumedWindowIDs.formUnion(uniqueIDs)
        }

        let unmatched = windows.filter { !consumedWindowIDs.contains($0.id) }
        groups.append(contentsOf: FinderCapturedWindowGrouper.group(unmatched).map {
            CaptureGroup(windows: $0, snapshot: nil)
        })
        return groups
    }

    private static func selectedRawWindow(
        from windows: [FinderCapturedWindowPayload],
        snapshot: FinderCapturedTabSnapshot?
    ) -> FinderCapturedWindowPayload? {
        guard let snapshot,
              snapshot.windowIDs.indices.contains(snapshot.selectedTabIndex) else {
            return windows.first
        }
        let selectedID = snapshot.windowIDs[snapshot.selectedTabIndex]
        return windows.first { $0.id == selectedID } ?? windows.first
    }
}

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

    private static func haveMatchingBounds(
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

        var snapshotsByWindowID: [Int: FinderCapturedTabSnapshot] = [:]
        for snapshot in tabSnapshots {
            for windowID in snapshot.windowIDs {
                snapshotsByWindowID[windowID] = snapshot
            }
        }
        let rawGroups = FinderCapturedWindowGrouper.group(payload.windows)
        var groupsMissingTabMetadata = 0

        for rawGroup in rawGroups {
            guard let rawWindow = rawGroup.first else { continue }
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
            let capturedTabs = snapshotsByWindowID[rawWindow.id].flatMap { snapshot in
                Set(snapshot.windowIDs) == Set(rawGroup.map(\.id)) ? snapshot : nil
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
}

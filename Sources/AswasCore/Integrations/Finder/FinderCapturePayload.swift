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

enum FinderCapturePayloadMapper {
    static func map(
        _ payload: FinderCapturePayload,
        displays: DisplaySnapshot? = nil
    ) throws -> FinderCaptureResult {
        guard payload.schemaVersion == 1 else {
            throw FinderIntegrationError.malformedResponse
        }

        var windows: [FinderWindowState] = []
        var references: [FinderWindowReference] = []
        var warnings = payload.warnings.map {
            WorkspaceWarning(code: .windowUnreadable, message: $0.message)
        }

        for rawWindow in payload.windows.sorted(by: { $0.index < $1.index }) {
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

            let normalizedPath = PathNormalizer.normalize(rawWindow.path)
            let placement = displays.map {
                WindowPlacement.capture(frame: frame, displays: $0)
            }
            let tab = FinderTabState(
                path: normalizedPath,
                displayName: rawWindow.name.isEmpty ? nil : rawWindow.name
            )
            windows.append(
                FinderWindowState(
                    tabs: [tab],
                    selectedTabIndex: 0,
                    frame: frame,
                    normalizedFrame: placement?.normalizedFrame,
                    display: placement?.display,
                    viewMode: FinderViewMode(rawValue: rawWindow.viewMode) ?? .unknown
                )
            )
            references.append(FinderWindowReference(windowID: rawWindow.id))
        }

        guard !windows.isEmpty else {
            throw FinderIntegrationError.noReadableWindows
        }

        warnings.append(
            WorkspaceWarning(
                code: .tabsUnavailable,
                message: AswasLocalization.string("warning.tabs_unavailable_capture")
            )
        )
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

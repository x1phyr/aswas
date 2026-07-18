import Foundation

public actor WorkspaceRestoreService {
    private let integration: any FinderWorkspaceIntegration
    private let repository: any WorkspaceRepository
    private let pathChecker: any PathAvailabilityChecking
    private let displayProvider: any DisplaySnapshotProviding
    private var isRestoring = false

    public init(
        integration: any FinderWorkspaceIntegration,
        repository: any WorkspaceRepository,
        pathChecker: any PathAvailabilityChecking = FileSystemPathAvailabilityChecker(),
        displayProvider: any DisplaySnapshotProviding = SystemDisplayProvider()
    ) {
        self.integration = integration
        self.repository = repository
        self.pathChecker = pathChecker
        self.displayProvider = displayProvider
    }

    public func previewReplace() async throws -> FinderCaptureResult {
        try await integration.captureCurrentState()
    }

    public func restore(id: UUID, mode: RestoreMode) async throws -> FinderRestoreResult {
        guard !isRestoring else {
            throw FinderIntegrationError.operationInProgress
        }
        isRestoring = true
        defer { isRestoring = false }
        AswasLog.restore.info("Starting \(mode.rawValue, privacy: .public) restore for workspace \(id.uuidString, privacy: .public)")

        let workspace = try await repository.load(id: id)
        try WorkspaceValidator.validate(workspace)
        let prepared = await prepareForRestore(workspace.finder)
        var result = try await integration.restore(prepared.state, mode: mode)
        result.skippedPaths.append(contentsOf: prepared.skippedPaths)
        result.warnings.insert(contentsOf: prepared.warnings, at: 0)
        AswasLog.restore.info("Restore completed with \(result.restoredWindowCount) windows and \(result.skippedPaths.count) skipped paths")
        return result
    }

    private func prepareForRestore(
        _ state: FinderWorkspaceState
    ) async -> PreparedRestoreState {
        let displaySnapshot = await displayProvider.snapshot()
        var preparedWindows: [FinderWindowState] = []
        var skippedPaths: [String] = []
        var warnings: [WorkspaceWarning] = []

        for originalWindow in state.windows {
            var window = originalWindow
            let selectedTabID = window.selectedTab?.id
            var availableTabs: [FinderTabState] = []
            for tab in window.tabs {
                if await pathChecker.isAccessibleDirectory(tab.path) {
                    availableTabs.append(tab)
                } else {
                    skippedPaths.append(tab.path)
                    warnings.append(
                        WorkspaceWarning(
                            code: .pathUnavailable,
                            message: AswasLocalization.string("warning.path_skipped"),
                            path: tab.path
                        )
                    )
                }
            }
            guard !availableTabs.isEmpty else { continue }
            window.tabs = availableTabs
            window.selectedTabIndex = selectedTabID.flatMap { selectedID in
                availableTabs.firstIndex { $0.id == selectedID }
            } ?? 0

            if let placement = WindowPlacement.restore(window: window, displays: displaySnapshot) {
                window.frame = placement.frame
                window.display = placement.display
                if placement.usedFallbackDisplay {
                    warnings.append(
                        WorkspaceWarning(
                            code: .displayUnavailable,
                            message: AswasLocalization.string("warning.display_fallback")
                        )
                    )
                }
            } else {
                window.frame = nil
                warnings.append(
                    WorkspaceWarning(
                        code: .displayUnavailable,
                        message: AswasLocalization.string("warning.display_missing")
                    )
                )
            }
            preparedWindows.append(window)
        }

        return PreparedRestoreState(
            state: FinderWorkspaceState(windows: preparedWindows),
            skippedPaths: skippedPaths,
            warnings: warnings
        )
    }
}

private struct PreparedRestoreState: Sendable {
    var state: FinderWorkspaceState
    var skippedPaths: [String]
    var warnings: [WorkspaceWarning]
}

import Foundation
import Testing
@testable import AswasCore

private struct RestorePathCheckerStub: PathAvailabilityChecking {
    let available: Set<String>

    func isAccessibleDirectory(_ path: String) async -> Bool {
        available.contains(path)
    }
}

private struct RestoreDisplayProviderStub: DisplaySnapshotProviding {
    let value: DisplaySnapshot

    @MainActor
    func snapshot() -> DisplaySnapshot { value }
}

private actor RestoreIntegrationStub: FinderWorkspaceIntegration {
    private(set) var restoredState: FinderWorkspaceState?

    func checkCapabilities() async -> FinderCapabilities {
        FinderCapabilities(
            automationPermission: .granted,
            accessibilityPermission: .notRequired,
            canCaptureWindows: true,
            canRestoreWindows: true,
            canCaptureTabs: false,
            canRestoreTabs: false
        )
    }

    func requestAutomationPermission() async -> AutomationPermissionStatus { .granted }

    func captureCurrentState() async throws -> FinderCaptureResult {
        FinderCaptureResult(state: .init(windows: []), managedWindows: [], warnings: [])
    }

    func restore(
        _ state: FinderWorkspaceState,
        mode: RestoreMode
    ) async throws -> FinderRestoreResult {
        restoredState = state
        return FinderRestoreResult(
            restoredWindowCount: state.windows.count,
            restoredTabCount: state.tabCount
        )
    }

    func closeManagedWindows(
        _ windows: [FinderWindowReference]
    ) async throws -> FinderCloseResult {
        FinderCloseResult(closedWindowCount: windows.count)
    }
}

struct WorkspaceRestoreServiceTests {
    @Test
    func skipsUnavailablePathsWithoutFailingWholeRestore() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = JSONWorkspaceRepository(rootDirectory: directory)
        var workspace = makeWorkspace()
        workspace.finder.windows.append(
            FinderWindowState(
                tabs: [FinderTabState(path: "/missing")],
                selectedTabIndex: 0,
                frame: CodableRect(x: 50, y: 50, width: 800, height: 600),
                normalizedFrame: nil,
                display: nil,
                viewMode: .icon
            )
        )
        try await repository.save(workspace)
        let integration = RestoreIntegrationStub()
        let main = DisplayDescriptor(
            displayID: 1,
            localizedName: "Main",
            frame: CodableRect(x: 0, y: 0, width: 1512, height: 950),
            visibleFrame: CodableRect(x: 0, y: 0, width: 1512, height: 950),
            scaleFactor: 2
        )
        let service = WorkspaceRestoreService(
            integration: integration,
            repository: repository,
            pathChecker: RestorePathCheckerStub(available: ["/Users/test/RoyalMerge"]),
            displayProvider: RestoreDisplayProviderStub(
                value: DisplaySnapshot(displays: [main], mainDisplayID: 1)
            )
        )

        let result = try await service.restore(id: workspace.id, mode: .open)

        #expect(result.restoredWindowCount == 1)
        #expect(result.skippedPaths == ["/missing"])
        #expect(result.warnings.contains { $0.code == .pathUnavailable })
        #expect(await integration.restoredState?.windows.count == 1)
    }

    @Test
    func rejectsASecondRestoreWhileOneIsRunning() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = JSONWorkspaceRepository(rootDirectory: directory)
        let workspace = makeWorkspace()
        try await repository.save(workspace)
        let integration = SuspendingRestoreIntegrationStub()
        let main = DisplayDescriptor(
            displayID: 1,
            localizedName: "Main",
            frame: CodableRect(x: 0, y: 0, width: 1512, height: 950),
            visibleFrame: CodableRect(x: 0, y: 0, width: 1512, height: 950),
            scaleFactor: 2
        )
        let service = WorkspaceRestoreService(
            integration: integration,
            repository: repository,
            pathChecker: RestorePathCheckerStub(available: ["/Users/test/RoyalMerge"]),
            displayProvider: RestoreDisplayProviderStub(
                value: DisplaySnapshot(displays: [main], mainDisplayID: 1)
            )
        )

        let firstRestore = Task {
            try await service.restore(id: workspace.id, mode: .open)
        }
        await integration.waitUntilRestoreStarts()

        do {
            _ = try await service.restore(id: workspace.id, mode: .open)
            Issue.record("A concurrent restore should have been rejected.")
        } catch let error as FinderIntegrationError {
            #expect(error == .operationInProgress)
        }

        await integration.releaseRestore()
        _ = try await firstRestore.value
    }

    @Test
    func restoresOnlyTheSelectedWindowAndAllOfItsAvailableTabs() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = JSONWorkspaceRepository(rootDirectory: directory)
        let integration = RestoreIntegrationStub()
        let selectedWindow = FinderWindowState(
            tabs: [
                FinderTabState(path: "/Projects/One"),
                FinderTabState(path: "/Projects/Two")
            ],
            selectedTabIndex: 1,
            frame: nil,
            normalizedFrame: nil,
            display: nil,
            viewMode: .list
        )
        let service = WorkspaceRestoreService(
            integration: integration,
            repository: repository,
            pathChecker: RestorePathCheckerStub(
                available: ["/Projects/One", "/Projects/Two"]
            ),
            displayProvider: RestoreDisplayProviderStub(
                value: DisplaySnapshot(displays: [], mainDisplayID: nil)
            )
        )

        let result = try await service.restore(window: selectedWindow)

        let restored = await integration.restoredState
        #expect(result.restoredWindowCount == 1)
        #expect(result.restoredTabCount == 2)
        #expect(restored?.windows == [selectedWindow])
    }
}

private actor SuspendingRestoreIntegrationStub: FinderWorkspaceIntegration {
    private var didStart = false
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseContinuation: CheckedContinuation<Void, Never>?

    func checkCapabilities() async -> FinderCapabilities {
        FinderCapabilities(
            automationPermission: .granted,
            accessibilityPermission: .notRequired,
            canCaptureWindows: true,
            canRestoreWindows: true,
            canCaptureTabs: false,
            canRestoreTabs: false
        )
    }

    func requestAutomationPermission() async -> AutomationPermissionStatus { .granted }

    func captureCurrentState() async throws -> FinderCaptureResult {
        FinderCaptureResult(state: .init(windows: []), managedWindows: [], warnings: [])
    }

    func restore(
        _ state: FinderWorkspaceState,
        mode: RestoreMode
    ) async throws -> FinderRestoreResult {
        didStart = true
        let waiters = startWaiters
        startWaiters.removeAll()
        waiters.forEach { $0.resume() }
        await withCheckedContinuation { continuation in
            releaseContinuation = continuation
        }
        return FinderRestoreResult(restoredWindowCount: state.windows.count)
    }

    func closeManagedWindows(
        _ windows: [FinderWindowReference]
    ) async throws -> FinderCloseResult {
        FinderCloseResult(closedWindowCount: windows.count)
    }

    func waitUntilRestoreStarts() async {
        if didStart { return }
        await withCheckedContinuation { continuation in
            startWaiters.append(continuation)
        }
    }

    func releaseRestore() {
        releaseContinuation?.resume()
        releaseContinuation = nil
    }
}

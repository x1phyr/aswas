import Foundation
import Testing
@testable import AswasCore

struct FinderCaptureTests {
    @Test
    func mapsWindowCaptureWithoutClaimingTabSupport() throws {
        let payload = FinderCapturePayload(
            schemaVersion: 1,
            windows: [
                FinderCapturedWindowPayload(
                    id: 42,
                    index: 1,
                    name: "项目 资源",
                    path: "/Users/test/项目 资源/",
                    bounds: [10, 20, 810, 620],
                    viewMode: "list"
                )
            ],
            warnings: []
        )

        let result = try FinderCapturePayloadMapper.map(payload)

        #expect(result.state.windows.count == 1)
        #expect(result.state.windows[0].frame == CodableRect(x: 10, y: 20, width: 800, height: 600))
        #expect(result.state.windows[0].tabs.map(\.path) == ["/Users/test/项目 资源"])
        #expect(result.state.windows[0].viewMode == .list)
        #expect(result.managedWindows == [FinderWindowReference(windowID: 42)])
        #expect(!result.warnings.contains { $0.code == .tabsUnavailable })
    }

    @Test
    func mapsAccessibilityTabSnapshotWithOrderAndSelection() throws {
        let payload = FinderCapturePayload(
            schemaVersion: 1,
            windows: [
                FinderCapturedWindowPayload(
                    id: 40,
                    index: 1,
                    name: "first",
                    path: "/Users/test/first",
                    bounds: [10, 20, 810, 620],
                    viewMode: "list"
                ),
                FinderCapturedWindowPayload(
                    id: 41,
                    index: 2,
                    name: "当前标签",
                    path: "/Users/test/current",
                    bounds: [10, 20, 810, 620],
                    viewMode: "list"
                ),
                FinderCapturedWindowPayload(
                    id: 42,
                    index: 3,
                    name: "last",
                    path: "/Users/test/last",
                    bounds: [10, 20, 810, 620],
                    viewMode: "list"
                )
            ],
            warnings: []
        )
        let snapshots = [
            FinderCapturedTabSnapshot(
                windowIDs: [40, 41, 42],
                tabs: [
                    FinderTabState(path: "/Users/test/first", displayName: "first"),
                    FinderTabState(path: "/Users/test/current", displayName: "current"),
                    FinderTabState(path: "/Users/test/last", displayName: "last")
                ],
                selectedTabIndex: 1
            )
        ]

        let result = try FinderCapturePayloadMapper.map(payload, tabSnapshots: snapshots)

        #expect(result.state.windows[0].tabs.map(\.path) == [
            "/Users/test/first",
            "/Users/test/current",
            "/Users/test/last"
        ])
        #expect(result.state.windows[0].selectedTabIndex == 1)
        #expect(result.managedWindows.map(\.windowID) == [40, 41, 42])
        #expect(!result.warnings.contains { $0.code == .tabsUnavailable })
    }

    @Test
    func groupsFinderTabWindowsBySharedBoundsWithoutAccessibility() throws {
        let payload = FinderCapturePayload(
            schemaVersion: 1,
            windows: [
                FinderCapturedWindowPayload(
                    id: 1,
                    index: 1,
                    name: "A",
                    path: "/a",
                    bounds: [34, 219, 1315, 1045],
                    viewMode: "list"
                ),
                FinderCapturedWindowPayload(
                    id: 2,
                    index: 4,
                    name: "B",
                    path: "/b",
                    bounds: [34, 219, 1315, 1045],
                    viewMode: "list"
                ),
                FinderCapturedWindowPayload(
                    id: 3,
                    index: 7,
                    name: "C",
                    path: "/c",
                    bounds: [34, 219, 1315, 1045],
                    viewMode: "list"
                ),
                FinderCapturedWindowPayload(
                    id: 4,
                    index: 2,
                    name: "Separate",
                    path: "/separate",
                    bounds: [33, 30, 1324, 804],
                    viewMode: "icon"
                )
            ],
            warnings: []
        )

        let result = try FinderCapturePayloadMapper.map(payload)

        #expect(result.state.windows.count == 2)
        #expect(result.state.windows[0].tabs.map(\.path) == ["/a", "/b", "/c"])
        #expect(result.state.windows[1].tabs.map(\.path) == ["/separate"])
        #expect(result.warnings.contains { $0.code == .tabsUnavailable })
        #expect(result.managedWindows.map(\.windowID) == [1, 2, 3, 4])
    }

    @Test
    func skipsInvalidWindowBoundsAndKeepsReadableWindows() throws {
        let payload = FinderCapturePayload(
            schemaVersion: 1,
            windows: [
                FinderCapturedWindowPayload(
                    id: 1,
                    index: 1,
                    name: "Broken",
                    path: "/broken",
                    bounds: [0, 0, 0, 0],
                    viewMode: "unknown"
                ),
                FinderCapturedWindowPayload(
                    id: 2,
                    index: 2,
                    name: "Good",
                    path: "/good",
                    bounds: [0, 0, 400, 300],
                    viewMode: "icon"
                )
            ],
            warnings: []
        )

        let result = try FinderCapturePayloadMapper.map(payload)

        #expect(result.state.windows.count == 1)
        #expect(result.managedWindows == [FinderWindowReference(windowID: 2)])
        #expect(result.warnings.contains { $0.code == .windowUnreadable })
    }
}

private actor CaptureIntegrationStub: FinderWorkspaceIntegration {
    let result: FinderCaptureResult

    init(result: FinderCaptureResult) {
        self.result = result
    }

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

    func captureCurrentState() async throws -> FinderCaptureResult { result }

    func restore(
        _ state: FinderWorkspaceState,
        mode: RestoreMode
    ) async throws -> FinderRestoreResult {
        FinderRestoreResult(
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

struct WorkspaceCaptureServiceTests {
    @Test
    func savesOnlyAfterSuccessfulCapture() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = JSONWorkspaceRepository(rootDirectory: directory)
        let state = makeWorkspace().finder
        let integration = CaptureIntegrationStub(
            result: FinderCaptureResult(
                state: state,
                managedWindows: [FinderWindowReference(windowID: 7)],
                warnings: []
            )
        )
        let service = WorkspaceCaptureService(
            integration: integration,
            repository: repository
        )

        let result = try await service.createWorkspace(named: "  RoyalMerge  ")

        #expect(result.workspace.name == "RoyalMerge")
        #expect(result.managedWindows == [FinderWindowReference(windowID: 7)])
        #expect(try await repository.list().map(\.id) == [result.workspace.id])
    }
}

import Foundation
import Testing
@testable import AswasCore

private enum SaveAndCloseTestError: Error {
    case saveFailed
}

private actor FailingWorkspaceRepository: WorkspaceRepository {
    func list() async throws -> [WorkspaceSnapshot] { [] }
    func load(id: UUID) async throws -> WorkspaceSnapshot { throw SaveAndCloseTestError.saveFailed }
    func save(_ workspace: WorkspaceSnapshot) async throws { throw SaveAndCloseTestError.saveFailed }
    func delete(id: UUID) async throws {}
}

private actor RecordingSaveAndCloseIntegration: FinderWorkspaceIntegration {
    private(set) var closedReferences: [FinderWindowReference] = []
    let captureResult: FinderCaptureResult

    init(captureResult: FinderCaptureResult) {
        self.captureResult = captureResult
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
    func captureCurrentState() async throws -> FinderCaptureResult { captureResult }

    func restore(
        _ state: FinderWorkspaceState,
        mode: RestoreMode
    ) async throws -> FinderRestoreResult {
        FinderRestoreResult()
    }

    func closeManagedWindows(
        _ windows: [FinderWindowReference]
    ) async throws -> FinderCloseResult {
        closedReferences.append(contentsOf: windows)
        return FinderCloseResult(closedWindowCount: windows.count)
    }
}

struct SaveAndCloseServiceTests {
    @Test
    func neverClosesWindowsWhenPersistenceFails() async throws {
        let references = [FinderWindowReference(windowID: 10)]
        let integration = RecordingSaveAndCloseIntegration(
            captureResult: FinderCaptureResult(
                state: makeWorkspace().finder,
                managedWindows: references,
                warnings: []
            )
        )
        let captureService = WorkspaceCaptureService(
            integration: integration,
            repository: FailingWorkspaceRepository()
        )
        let service = SaveAndCloseService(
            captureService: captureService,
            integration: integration
        )

        do {
            _ = try await service.createWorkspaceAndClose(named: "Will Fail")
            Issue.record("The save should have failed.")
        } catch {
            // Expected. The key assertion is that close was never called.
        }

        #expect(await integration.closedReferences.isEmpty)
    }

    @Test
    func closesExactlyCapturedWindowsAfterSuccessfulSave() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let references = [
            FinderWindowReference(windowID: 10),
            FinderWindowReference(windowID: 20)
        ]
        let integration = RecordingSaveAndCloseIntegration(
            captureResult: FinderCaptureResult(
                state: makeWorkspace().finder,
                managedWindows: references,
                warnings: [
                    WorkspaceWarning(code: .tabsUnavailable, message: "Tabs are best effort.")
                ]
            )
        )
        let repository = JSONWorkspaceRepository(rootDirectory: directory)
        let captureService = WorkspaceCaptureService(
            integration: integration,
            repository: repository
        )
        let service = SaveAndCloseService(
            captureService: captureService,
            integration: integration
        )

        let result = try await service.createWorkspaceAndClose(named: "Saved")

        #expect(result.closedWindowCount == 2)
        #expect(result.windowsLeftOpen.isEmpty)
        #expect(await integration.closedReferences == references)
        #expect(try await repository.list().map(\.id) == [result.workspace.id])
    }
}

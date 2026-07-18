import Foundation

public actor SaveAndCloseService {
    private let captureService: WorkspaceCaptureService
    private let integration: any FinderWorkspaceIntegration
    private var isRunning = false

    public init(
        captureService: WorkspaceCaptureService,
        integration: any FinderWorkspaceIntegration
    ) {
        self.captureService = captureService
        self.integration = integration
    }

    public func createWorkspaceAndClose(named name: String) async throws -> SaveAndCloseResult {
        try await perform {
            try await self.captureService.createWorkspace(named: name)
        }
    }

    public func updateWorkspaceAndClose(id: UUID) async throws -> SaveAndCloseResult {
        try await perform {
            try await self.captureService.updateWorkspace(id: id)
        }
    }

    private func perform(
        capture: () async throws -> WorkspaceCaptureResult
    ) async throws -> SaveAndCloseResult {
        guard !isRunning else {
            throw FinderIntegrationError.operationInProgress
        }
        isRunning = true
        defer { isRunning = false }

        // The capture service persists and verifies the workspace before this returns.
        // If capture or persistence throws, no close operation is ever attempted.
        let saved = try await capture()
        AswasLog.workspace.info("Workspace persisted; beginning precise Finder window close")
        let closeResult = try await integration.closeManagedWindows(saved.managedWindows)
        return SaveAndCloseResult(
            workspace: saved.workspace,
            closedWindowCount: closeResult.closedWindowCount,
            windowsLeftOpen: closeResult.failedWindows,
            warnings: saved.warnings,
            errors: closeResult.errors
        )
    }
}

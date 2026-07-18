import Foundation

public actor WorkspaceCaptureService {
    private let integration: any FinderWorkspaceIntegration
    private let repository: any WorkspaceRepository

    public init(
        integration: any FinderWorkspaceIntegration,
        repository: any WorkspaceRepository
    ) {
        self.integration = integration
        self.repository = repository
    }

    public func createWorkspace(named name: String) async throws -> WorkspaceCaptureResult {
        let capture = try await integration.captureCurrentState()
        let now = Date()
        let workspace = WorkspaceSnapshot(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: now,
            updatedAt: now,
            finder: capture.state
        )
        try WorkspaceValidator.validate(workspace)
        try await repository.save(workspace)
        AswasLog.workspace.info("Created workspace \(workspace.id.uuidString, privacy: .public)")

        return WorkspaceCaptureResult(
            workspace: workspace,
            managedWindows: capture.managedWindows,
            warnings: capture.warnings
        )
    }

    public func updateWorkspace(id: UUID) async throws -> WorkspaceCaptureResult {
        let existing = try await repository.load(id: id)
        let capture = try await integration.captureCurrentState()
        var updated = existing
        updated.finder = capture.state
        updated.updatedAt = Date()
        try WorkspaceValidator.validate(updated)
        try await repository.save(updated)
        AswasLog.workspace.info("Updated workspace \(updated.id.uuidString, privacy: .public)")

        return WorkspaceCaptureResult(
            workspace: updated,
            managedWindows: capture.managedWindows,
            warnings: capture.warnings
        )
    }
}

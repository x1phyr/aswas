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
        try requireReliableTabOrder(capture)
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
        try requireReliableTabOrder(capture)
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

    private func requireReliableTabOrder(_ capture: FinderCaptureResult) throws {
        guard !capture.warnings.contains(where: { $0.code == .tabsUnavailable }) else {
            // The window grouping and paths are useful for previews, but persisting them
            // would make an arbitrary Finder script order look authoritative. Refuse the
            // save so a later restore cannot silently shuffle the user's tabs.
            throw FinderIntegrationError.tabOrderUnavailable
        }
    }
}

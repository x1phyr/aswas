import Foundation

public actor WorkspaceLibraryService {
    private let repository: any WorkspaceRepository

    public init(repository: any WorkspaceRepository) {
        self.repository = repository
    }

    public func list() async throws -> [WorkspaceSnapshot] {
        try await repository.list()
    }

    public func rename(id: UUID, to newName: String) async throws -> WorkspaceSnapshot {
        var workspace = try await repository.load(id: id)
        workspace.name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        workspace.updatedAt = Date()
        try WorkspaceValidator.validate(workspace)
        try await repository.save(workspace)
        return workspace
    }

    public func delete(id: UUID) async throws {
        try await repository.delete(id: id)
    }
}

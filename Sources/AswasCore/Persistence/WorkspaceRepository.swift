import Foundation

public protocol WorkspaceRepository: Sendable {
    func list() async throws -> [WorkspaceSnapshot]
    func load(id: UUID) async throws -> WorkspaceSnapshot
    func save(_ workspace: WorkspaceSnapshot) async throws
    func delete(id: UUID) async throws
}

public enum WorkspaceRepositoryError: LocalizedError, Equatable, Sendable {
    case notFound(UUID)
    case cannotPrepareStorage(String)
    case cannotRead(String)
    case cannotWrite(String)
    case cannotDelete(String)

    public var errorDescription: String? {
        switch self {
        case .notFound:
            return AswasLocalization.string("error.not_found")
        case .cannotPrepareStorage:
            return AswasLocalization.string("error.storage_prepare")
        case .cannotRead:
            return AswasLocalization.string("error.storage_read")
        case .cannotWrite:
            return AswasLocalization.string("error.storage_write")
        case .cannotDelete:
            return AswasLocalization.string("error.storage_delete")
        }
    }
}

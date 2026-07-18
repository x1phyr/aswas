import Foundation

public enum WorkspaceSchema {
    public static let currentVersion = 1
}

public struct WorkspaceSnapshot: Codable, Equatable, Identifiable, Sendable {
    public let schemaVersion: Int
    public let id: UUID
    public var name: String
    public var createdAt: Date
    public var updatedAt: Date
    public var finder: FinderWorkspaceState

    public init(
        schemaVersion: Int = WorkspaceSchema.currentVersion,
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        finder: FinderWorkspaceState
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.finder = finder
    }
}

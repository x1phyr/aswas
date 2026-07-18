import Foundation
import Testing
@testable import AswasCore

struct JSONWorkspaceRepositoryTests {
    @Test
    func savesListsLoadsAndDeletesWorkspace() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = JSONWorkspaceRepository(rootDirectory: directory)
        let workspace = makeWorkspace()

        try await repository.save(workspace)
        let listed = try await repository.list()
        let loaded = try await repository.load(id: workspace.id)

        #expect(listed == [workspace])
        #expect(loaded == workspace)

        try await repository.delete(id: workspace.id)
        #expect(try await repository.list().isEmpty)
    }

    @Test
    func overwriteCreatesBackupAndKeepsLatestData() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = JSONWorkspaceRepository(rootDirectory: directory)
        let id = UUID()

        try await repository.save(makeWorkspace(id: id, name: "Before"))
        try await repository.save(makeWorkspace(id: id, name: "After"))

        #expect(try await repository.load(id: id).name == "After")
        let backups = try FileManager.default.contentsOfDirectory(
            at: directory.appendingPathComponent("backups"),
            includingPropertiesForKeys: nil
        )
        #expect(backups.count == 1)
    }

    @Test
    func corruptFileIsIsolatedWithoutBreakingList() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = JSONWorkspaceRepository(rootDirectory: directory)
        let valid = makeWorkspace()
        try await repository.save(valid)

        let corruptURL = directory
            .appendingPathComponent("workspaces", isDirectory: true)
            .appendingPathComponent("broken.json")
        try Data("not-json".utf8).write(to: corruptURL)

        #expect(try await repository.list() == [valid])
        #expect(!FileManager.default.fileExists(atPath: corruptURL.path))
        let isolated = try FileManager.default.contentsOfDirectory(
            at: directory.appendingPathComponent("corrupt"),
            includingPropertiesForKeys: nil
        )
        #expect(isolated.count == 1)
    }

    @Test
    func concurrentWritesAreSerializedByActor() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = JSONWorkspaceRepository(rootDirectory: directory)
        let id = UUID()

        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0..<8 {
                group.addTask {
                    try await repository.save(
                        makeWorkspace(
                            id: id,
                            name: "Version \(index)",
                            updatedAt: Date(timeIntervalSince1970: Double(index))
                        )
                    )
                }
            }
            try await group.waitForAll()
        }

        let loaded = try await repository.load(id: id)
        #expect(loaded.name.hasPrefix("Version "))
        #expect(try await repository.list().count == 1)
    }
}

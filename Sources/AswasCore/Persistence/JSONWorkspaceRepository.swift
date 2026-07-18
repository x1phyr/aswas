import Foundation

public actor JSONWorkspaceRepository: WorkspaceRepository {
    public let rootDirectory: URL

    private let workspacesDirectory: URL
    private let backupsDirectory: URL
    private let corruptDirectory: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(rootDirectory: URL, fileManager: FileManager = .default) {
        self.rootDirectory = rootDirectory
        self.workspacesDirectory = rootDirectory.appendingPathComponent("workspaces", isDirectory: true)
        self.backupsDirectory = rootDirectory.appendingPathComponent("backups", isDirectory: true)
        self.corruptDirectory = rootDirectory.appendingPathComponent("corrupt", isDirectory: true)
        self.fileManager = fileManager

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    public static func defaultRootDirectory(
        fileManager: FileManager = .default
    ) throws -> URL {
        let applicationSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return applicationSupport.appendingPathComponent("aswas", isDirectory: true)
    }

    public func list() async throws -> [WorkspaceSnapshot] {
        try prepareStorage()

        let urls: [URL]
        do {
            urls = try fileManager.contentsOfDirectory(
                at: workspacesDirectory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ).filter { $0.pathExtension.lowercased() == "json" }
        } catch {
            throw WorkspaceRepositoryError.cannotRead(error.localizedDescription)
        }

        var workspaces: [WorkspaceSnapshot] = []
        for url in urls {
            do {
                workspaces.append(try decodeWorkspace(at: url))
            } catch {
                AswasLog.persistence.error("Isolating a damaged workspace file: \(url.lastPathComponent, privacy: .private(mask: .hash))")
                isolateCorruptFile(at: url)
            }
        }

        return workspaces.sorted { lhs, rhs in
            if lhs.updatedAt == rhs.updatedAt {
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    public func load(id: UUID) async throws -> WorkspaceSnapshot {
        try prepareStorage()
        let url = workspaceURL(for: id)
        guard fileManager.fileExists(atPath: url.path) else {
            throw WorkspaceRepositoryError.notFound(id)
        }

        do {
            return try decodeWorkspace(at: url)
        } catch {
            throw WorkspaceRepositoryError.cannotRead(error.localizedDescription)
        }
    }

    public func save(_ workspace: WorkspaceSnapshot) async throws {
        try WorkspaceValidator.validate(workspace)
        try prepareStorage()

        let destination = workspaceURL(for: workspace.id)
        let temporary = workspacesDirectory
            .appendingPathComponent(".\(workspace.id.uuidString.lowercased()).\(UUID().uuidString).tmp")

        do {
            let data = try encoder.encode(workspace)
            try data.write(to: temporary)
            try synchronizeFile(at: temporary)

            if fileManager.fileExists(atPath: destination.path) {
                try createBackup(of: destination, workspaceID: workspace.id)
                _ = try fileManager.replaceItemAt(
                    destination,
                    withItemAt: temporary,
                    backupItemName: nil,
                    options: [.usingNewMetadataOnly]
                )
            } else {
                try fileManager.moveItem(at: temporary, to: destination)
            }
            AswasLog.persistence.info("Saved workspace \(workspace.id.uuidString, privacy: .public)")
        } catch {
            try? fileManager.removeItem(at: temporary)
            throw WorkspaceRepositoryError.cannotWrite(error.localizedDescription)
        }
    }

    public func delete(id: UUID) async throws {
        try prepareStorage()
        let url = workspaceURL(for: id)
        guard fileManager.fileExists(atPath: url.path) else {
            throw WorkspaceRepositoryError.notFound(id)
        }

        do {
            try createBackup(of: url, workspaceID: id)
            try fileManager.removeItem(at: url)
            AswasLog.persistence.info("Deleted workspace \(id.uuidString, privacy: .public) after backup")
        } catch {
            throw WorkspaceRepositoryError.cannotDelete(error.localizedDescription)
        }
    }

    private func prepareStorage() throws {
        do {
            for directory in [rootDirectory, workspacesDirectory, backupsDirectory, corruptDirectory] {
                try fileManager.createDirectory(
                    at: directory,
                    withIntermediateDirectories: true
                )
            }
        } catch {
            throw WorkspaceRepositoryError.cannotPrepareStorage(error.localizedDescription)
        }
    }

    private func decodeWorkspace(at url: URL) throws -> WorkspaceSnapshot {
        let data = try Data(contentsOf: url)
        return try WorkspaceMigration.decode(data, using: decoder)
    }

    private func workspaceURL(for id: UUID) -> URL {
        workspacesDirectory.appendingPathComponent(id.uuidString.lowercased() + ".json")
    }

    private func createBackup(of source: URL, workspaceID: UUID) throws {
        let timestamp = String(Int(Date().timeIntervalSince1970 * 1_000))
        let destination = backupsDirectory.appendingPathComponent(
            "\(workspaceID.uuidString.lowercased())-\(timestamp)-\(UUID().uuidString.lowercased()).json"
        )
        try fileManager.copyItem(at: source, to: destination)
    }

    private func isolateCorruptFile(at source: URL) {
        let timestamp = String(Int(Date().timeIntervalSince1970 * 1_000))
        let destination = corruptDirectory.appendingPathComponent(
            "\(source.deletingPathExtension().lastPathComponent)-\(timestamp)-\(UUID().uuidString.lowercased()).json"
        )
        try? fileManager.moveItem(at: source, to: destination)
    }

    private func synchronizeFile(at url: URL) throws {
        let handle = try FileHandle(forWritingTo: url)
        try handle.synchronize()
        try handle.close()
    }
}

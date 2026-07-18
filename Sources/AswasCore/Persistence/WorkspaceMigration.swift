import Foundation

public enum WorkspaceMigrationError: LocalizedError, Equatable, Sendable {
    case invalidEnvelope
    case unsupportedVersion(Int)
    case decodingFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidEnvelope:
            return AswasLocalization.string("error.invalid_envelope")
        case let .unsupportedVersion(version):
            return AswasLocalization.string("error.schema_unsupported", version)
        case .decodingFailed:
            return AswasLocalization.string("error.decoding_failed")
        }
    }
}

public enum WorkspaceMigration {
    public static func decode(_ data: Data, using decoder: JSONDecoder) throws -> WorkspaceSnapshot {
        let envelope: Any
        do {
            envelope = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw WorkspaceMigrationError.invalidEnvelope
        }

        guard
            let object = envelope as? [String: Any],
            let version = object["schemaVersion"] as? Int
        else {
            throw WorkspaceMigrationError.invalidEnvelope
        }

        guard version == WorkspaceSchema.currentVersion else {
            throw WorkspaceMigrationError.unsupportedVersion(version)
        }

        do {
            let workspace = try decoder.decode(WorkspaceSnapshot.self, from: data)
            try WorkspaceValidator.validate(workspace)
            return workspace
        } catch let error as WorkspaceValidationError {
            throw error
        } catch {
            throw WorkspaceMigrationError.decodingFailed(error.localizedDescription)
        }
    }
}

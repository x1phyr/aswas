import Foundation

public enum WorkspaceValidationError: LocalizedError, Equatable, Sendable {
    case unsupportedSchemaVersion(Int)
    case emptyName
    case emptyWorkspace
    case emptyWindow(UUID)
    case invalidSelectedTabIndex(UUID, Int)
    case nonAbsolutePath(String)
    case invalidFrame(UUID)
    case invalidNormalizedFrame(UUID)

    public var errorDescription: String? {
        switch self {
        case let .unsupportedSchemaVersion(version):
            return AswasLocalization.string("error.schema_unsupported", version)
        case .emptyName:
            return AswasLocalization.string("error.empty_name")
        case .emptyWorkspace:
            return AswasLocalization.string("error.empty_workspace")
        case .emptyWindow:
            return AswasLocalization.string("error.empty_window")
        case let .invalidSelectedTabIndex(_, index):
            return AswasLocalization.string("error.invalid_tab_index", index)
        case let .nonAbsolutePath(path):
            return AswasLocalization.string("error.non_absolute_path", path)
        case .invalidFrame:
            return AswasLocalization.string("error.invalid_frame")
        case .invalidNormalizedFrame:
            return AswasLocalization.string("error.invalid_normalized_frame")
        }
    }
}

public enum WorkspaceValidator {
    public static func validate(_ workspace: WorkspaceSnapshot) throws {
        guard workspace.schemaVersion == WorkspaceSchema.currentVersion else {
            throw WorkspaceValidationError.unsupportedSchemaVersion(workspace.schemaVersion)
        }
        guard !workspace.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw WorkspaceValidationError.emptyName
        }
        guard !workspace.finder.windows.isEmpty else {
            throw WorkspaceValidationError.emptyWorkspace
        }

        for window in workspace.finder.windows {
            guard !window.tabs.isEmpty else {
                throw WorkspaceValidationError.emptyWindow(window.id)
            }
            guard window.tabs.indices.contains(window.selectedTabIndex) else {
                throw WorkspaceValidationError.invalidSelectedTabIndex(
                    window.id,
                    window.selectedTabIndex
                )
            }
            for tab in window.tabs where !tab.path.hasPrefix("/") {
                throw WorkspaceValidationError.nonAbsolutePath(tab.path)
            }
            if let frame = window.frame, !frame.isFiniteAndPositive {
                throw WorkspaceValidationError.invalidFrame(window.id)
            }
            if let frame = window.normalizedFrame, !frame.isFiniteAndPositive {
                throw WorkspaceValidationError.invalidNormalizedFrame(window.id)
            }
        }
    }
}

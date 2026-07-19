import AppKit
import AswasCore
import SwiftUI

struct WorkspaceDetailView: View {
    let workspace: WorkspaceSnapshot
    @Bindable var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workspace.name).font(.title2.bold())
                    Text(
                        L10n.text(
                            "workspace.detail_summary",
                            workspace.finder.windows.count,
                            workspace.finder.tabCount
                        )
                    )
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(L10n.text("common.done")) { dismiss() }
            }
            .padding()

            Divider()
            List {
                ForEach(Array(workspace.finder.windows.enumerated()), id: \.element.id) { index, window in
                    Section(L10n.text("common.window_number", index + 1)) {
                        ForEach(window.tabs) { tab in
                            HStack(spacing: 8) {
                                Image(systemName: FileManager.default.fileExists(atPath: tab.path)
                                    ? "folder"
                                    : "exclamationmark.triangle")
                                    .foregroundStyle(FileManager.default.fileExists(atPath: tab.path)
                                        ? Color.accentColor
                                        : Color.orange)
                                Text(PathNormalizer.abbreviateHome(tab.path))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .help(tab.path)
                                Spacer()
                                Button {
                                    NSWorkspace.shared.open(URL(fileURLWithPath: tab.path))
                                } label: {
                                    Label(
                                        L10n.text("workspace.open_finder_short"),
                                        systemImage: "arrow.up.forward.square"
                                    )
                                }
                                .help(L10n.text("workspace.open_finder"))
                                .accessibilityLabel(L10n.text("workspace.open_finder"))
                            }
                        }
                    }
                }
            }

            Divider()
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.text("workspace.detail_update_group"))
                            .font(.subheadline.weight(.semibold))
                        Text(L10n.text("workspace.detail_update_description"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 16)
                    Button(L10n.text("workspace.detail_update")) {
                        Task { await appState.updateWorkspace(workspace) }
                    }
                    .help(L10n.text("workspace.detail_update_help"))
                    Button(L10n.text("workspace.detail_update_close")) {
                        dismiss()
                        Task { await appState.updateWorkspaceAndClose(workspace) }
                    }
                    .help(L10n.text("workspace.detail_update_close_help"))
                }

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.text("workspace.detail_restore_group"))
                            .font(.subheadline.weight(.semibold))
                        Text(L10n.text("workspace.detail_restore_description"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 16)
                    Button(L10n.text("workspace.detail_restore_open")) {
                        Task { await appState.requestRestore(workspace, mode: .open) }
                    }
                    .buttonStyle(.borderedProminent)
                    .help(L10n.text("workspace.detail_restore_open_help"))
                    Button(L10n.text("workspace.detail_restore_replace")) {
                        dismiss()
                        Task { await appState.requestRestore(workspace, mode: .replace) }
                    }
                    .help(L10n.text("workspace.detail_restore_replace_help"))
                }
            }
            .disabled(appState.isOperating)
            .padding()
        }
        .frame(minWidth: 680, minHeight: 500)
    }
}

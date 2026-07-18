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
                                    Image(systemName: "arrow.forward.circle")
                                }
                                .buttonStyle(.plain)
                                .help(L10n.text("workspace.open_finder"))
                            }
                        }
                    }
                }
            }

            Divider()
            HStack {
                Button(L10n.text("workspace.update")) {
                    Task { await appState.updateWorkspace(workspace) }
                }
                Button(L10n.text("workspace.update_close")) {
                    dismiss()
                    Task { await appState.updateWorkspaceAndClose(workspace) }
                }
                Spacer()
                Button(L10n.text("workspace.restore_open")) {
                    Task { await appState.requestRestore(workspace, mode: .open) }
                }
                Button(L10n.text("workspace.restore_replace")) {
                    dismiss()
                    Task { await appState.requestRestore(workspace, mode: .replace) }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(minWidth: 580, minHeight: 460)
    }
}

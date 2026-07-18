import AswasCore
import SwiftUI

struct WorkspaceListView: View {
    @Bindable var appState: AppState
    @AppStorage("defaultRestoreMode") private var defaultRestoreMode = RestoreMode.open.rawValue
    @State private var selectedWorkspace: WorkspaceSnapshot?
    @State private var promptMode: NamePromptMode?
    @State private var draftName = ""

    private var restoreMode: RestoreMode {
        RestoreMode(rawValue: defaultRestoreMode) ?? .open
    }

    var body: some View {
        NavigationStack {
            Group {
                if appState.workspaces.isEmpty {
                    ContentUnavailableView {
                        Label(L10n.text("empty.title"), systemImage: "folder.badge.plus")
                    } description: {
                        Text(L10n.text("empty.description"))
                    } actions: {
                        Button(L10n.text("save.current_workspace")) { beginSave(closeAfterSave: false) }
                    }
                } else {
                    List(appState.workspaces) { workspace in
                        WorkspaceRow(
                            workspace: workspace,
                            isOperating: appState.isOperating,
                            restore: {
                                Task { await appState.requestRestore(workspace, mode: restoreMode) }
                            }
                        )
                        .contentShape(Rectangle())
                        .onTapGesture { selectedWorkspace = workspace }
                        .contextMenu {
                            Button(L10n.text("workspace.restore_open")) {
                                Task { await appState.requestRestore(workspace, mode: .open) }
                            }
                            Button(L10n.text("workspace.restore_replace")) {
                                Task { await appState.requestRestore(workspace, mode: .replace) }
                            }
                            Divider()
                            Button(L10n.text("workspace.update")) {
                                Task { await appState.updateWorkspace(workspace) }
                            }
                            Button(L10n.text("workspace.update_close")) {
                                Task { await appState.updateWorkspaceAndClose(workspace) }
                            }
                            Button(L10n.text("workspace.rename")) {
                                draftName = workspace.name
                                promptMode = .rename(workspace)
                            }
                            Divider()
                            Button(L10n.text("workspace.delete"), role: .destructive) {
                                appState.pendingDelete = workspace
                            }
                        }
                    }
                    .listStyle(.inset)
                }
            }
            .navigationTitle("aswas")
            .toolbar {
                ToolbarItemGroup {
                    if appState.isOperating {
                        ProgressView().controlSize(.small)
                    }
                    Menu {
                        Button(L10n.text("menu.save_current")) { beginSave(closeAfterSave: false) }
                        Button(L10n.text("menu.save_close")) { beginSave(closeAfterSave: true) }
                    } label: {
                        Label(L10n.text("save.workspace_button"), systemImage: "plus")
                    }
                    .disabled(appState.isOperating)
                }
            }
        }
        .sheet(item: $selectedWorkspace) { workspace in
            WorkspaceDetailView(workspace: workspace, appState: appState)
        }
        .alert(promptTitle, isPresented: promptBinding) {
            TextField(L10n.text("common.workspace_name"), text: $draftName)
            Button(L10n.text("common.cancel"), role: .cancel) { promptMode = nil }
            Button(promptActionTitle) { submitPrompt() }
                .disabled(draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text(promptMessage)
        }
        .alert(item: $appState.notice) { notice in
            Alert(
                title: Text(notice.title),
                message: Text(notice.message),
                dismissButton: .default(Text(L10n.text("common.ok")))
            )
        }
        .confirmationDialog(
            L10n.text("replace.title"),
            isPresented: replaceBinding,
            titleVisibility: .visible
        ) {
            Button(L10n.text("replace.confirm"), role: .destructive) {
                Task { await appState.confirmReplace() }
            }
            Button(L10n.text("common.cancel"), role: .cancel) { appState.cancelReplace() }
        } message: {
            Text(replaceMessage)
        }
        .confirmationDialog(
            L10n.text("workspace.delete_title"),
            isPresented: deleteBinding,
            titleVisibility: .visible
        ) {
            Button(L10n.text("common.delete"), role: .destructive) {
                Task { await appState.deletePendingWorkspace() }
            }
            Button(L10n.text("common.cancel"), role: .cancel) { appState.pendingDelete = nil }
        } message: {
            Text(L10n.text("workspace.delete_message"))
        }
    }

    private var promptBinding: Binding<Bool> {
        Binding(
            get: { promptMode != nil },
            set: { if !$0 { promptMode = nil } }
        )
    }

    private var replaceBinding: Binding<Bool> {
        Binding(
            get: { appState.pendingReplace != nil },
            set: { if !$0 { appState.cancelReplace() } }
        )
    }

    private var deleteBinding: Binding<Bool> {
        Binding(
            get: { appState.pendingDelete != nil },
            set: { if !$0 { appState.pendingDelete = nil } }
        )
    }

    private var replaceMessage: String {
        guard let pending = appState.pendingReplace else { return "" }
        let paths = pending.preview.state.windows.compactMap { $0.selectedTab?.path }
        let preview = paths.prefix(4).map { PathNormalizer.abbreviateHome($0) }.joined(separator: "\n")
        let suffix = paths.count > 4
            ? L10n.text("replace.more", paths.count - 4)
            : ""
        return L10n.text(
            "replace.preview",
            paths.count,
            pending.workspace.name,
            preview,
            suffix
        )
    }

    private var promptTitle: String {
        switch promptMode {
        case .save(false): L10n.text("save.title")
        case .save(true): L10n.text("save.close_title")
        case .rename: L10n.text("workspace.rename_title")
        case nil: L10n.text("common.workspace_name")
        }
    }

    private var promptActionTitle: String {
        switch promptMode {
        case .save(false): L10n.text("common.save")
        case .save(true): L10n.text("save.close_title")
        case .rename: L10n.text("common.rename")
        case nil: L10n.text("common.ok")
        }
    }

    private var promptMessage: String {
        switch promptMode {
        case .save(true): L10n.text("save.close_message")
        case .save(false): L10n.text("save.only_readable")
        case .rename: L10n.text("workspace.rename_message")
        case nil: ""
        }
    }

    private func beginSave(closeAfterSave: Bool) {
        draftName = L10n.text(
            "save.default_name",
            Date().formatted(date: .abbreviated, time: .shortened)
        )
        promptMode = .save(closeAfterSave)
    }

    private func submitPrompt() {
        let mode = promptMode
        promptMode = nil
        switch mode {
        case let .save(closeAfterSave):
            Task { await appState.saveWorkspace(named: draftName, closeAfterSave: closeAfterSave) }
        case let .rename(workspace):
            Task { await appState.renameWorkspace(workspace, to: draftName) }
        case nil:
            break
        }
    }
}

private enum NamePromptMode: Identifiable {
    case save(Bool)
    case rename(WorkspaceSnapshot)

    var id: String {
        switch self {
        case let .save(close): "save-\(close)"
        case let .rename(workspace): "rename-\(workspace.id)"
        }
    }
}

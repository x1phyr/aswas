import AppKit
import AswasCore
import SwiftUI

struct WorkspaceListView: View {
    @Bindable var appState: AppState
    @Environment(\.openSettings) private var openSettings
    @State private var selectedWorkspaceID: UUID?
    @State private var searchText = ""
    @State private var promptMode: NamePromptMode?
    @State private var draftName = ""

    var body: some View {
        NavigationSplitView {
            workspaceLibrary
                .navigationSplitViewColumnWidth(min: 260, ideal: 320, max: 400)
        } detail: {
            if let workspace = selectedWorkspace {
                WorkspacePreviewView(
                    workspace: workspace,
                    appState: appState,
                    rename: { beginRename(workspace) },
                    delete: { appState.pendingDelete = workspace }
                )
                .id(workspace.id)
            } else {
                ContentUnavailableView {
                    Label(L10n.text("workspace.select_title"), systemImage: "square.stack.3d.up")
                } description: {
                    Text(L10n.text("workspace.select_description"))
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                saveMenu
            }
        }
        .onChange(of: appState.workspaces.map(\.id), initial: true) { _, workspaceIDs in
            if selectedWorkspaceID == nil || !workspaceIDs.contains(selectedWorkspaceID!) {
                selectedWorkspaceID = workspaceIDs.first
            }
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
            titleVisibility: .visible,
            presenting: appState.pendingReplace
        ) { pending in
            Button(L10n.text("replace.confirm"), role: .destructive) {
                Task { await appState.confirmReplace(pending) }
            }
            Button(L10n.text("common.cancel"), role: .cancel) { appState.cancelReplace() }
        } message: { _ in
            Text(replaceMessage)
        }
        .confirmationDialog(
            L10n.text("workspace.delete_title"),
            isPresented: deleteBinding,
            titleVisibility: .visible,
            presenting: appState.pendingDelete
        ) { workspace in
            Button(L10n.text("common.delete"), role: .destructive) {
                Task { await appState.deleteWorkspace(workspace) }
            }
            Button(L10n.text("common.cancel"), role: .cancel) { appState.pendingDelete = nil }
        } message: { _ in
            Text(L10n.text("workspace.delete_message"))
        }
    }

    private var workspaceLibrary: some View {
        VStack(spacing: 0) {
            Group {
                if appState.workspaces.isEmpty {
                    ContentUnavailableView {
                        Label(L10n.text("empty.title"), systemImage: "folder.badge.plus")
                    } description: {
                        Text(L10n.text("empty.description"))
                    } actions: {
                        Button(L10n.text("save.current_workspace")) {
                            beginSave(closeAfterSave: false)
                        }
                    }
                } else {
                    List(filteredWorkspaces, selection: $selectedWorkspaceID) { workspace in
                        WorkspaceRow(workspace: workspace)
                            .tag(workspace.id)
                            .contextMenu { workspaceMenu(for: workspace) }
                    }
                    .listStyle(.sidebar)
                    .searchable(
                        text: $searchText,
                        placement: .sidebar,
                        prompt: L10n.text("workspace.search_prompt")
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            permissionFooter
        }
        .navigationTitle(L10n.text("workspace.library_title"))
    }

    private var saveMenu: some View {
        Menu {
            Button(L10n.text("menu.save_current")) { beginSave(closeAfterSave: false) }
            Button(L10n.text("menu.save_close")) { beginSave(closeAfterSave: true) }
        } label: {
            Text(L10n.text("save.current_workspace"))
        }
        .help(L10n.text("save.current_workspace"))
        .disabled(appState.isOperating)
    }

    private var permissionFooter: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 8) {
                Image(systemName: permissionsReady ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundStyle(permissionsReady ? Color.green : Color.orange)
                VStack(alignment: .leading, spacing: 1) {
                    Text(L10n.text(permissionsReady
                        ? "workspace.permissions_ready"
                        : "workspace.permissions_attention"))
                        .font(.caption.weight(.medium))
                    Text(L10n.text("workspace.permissions_description"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 4)
                Button(L10n.text("workspace.manage_permissions")) {
                    NSApp.activate(ignoringOtherApps: true)
                    openSettings()
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.bar)
        }
    }

    @ViewBuilder
    private func workspaceMenu(for workspace: WorkspaceSnapshot) -> some View {
        Button(L10n.text("workspace.detail_restore_open")) {
            Task { await appState.requestRestore(workspace, mode: .open) }
        }
        Button(L10n.text("workspace.detail_restore_replace")) {
            Task { await appState.requestRestore(workspace, mode: .replace) }
        }
        Divider()
        Button(L10n.text("workspace.detail_update")) {
            Task { await appState.updateWorkspace(workspace) }
        }
        Button(L10n.text("workspace.detail_update_close")) {
            Task { await appState.updateWorkspaceAndClose(workspace) }
        }
        Button(L10n.text("workspace.rename")) { beginRename(workspace) }
        Divider()
        Button(L10n.text("workspace.delete"), role: .destructive) {
            appState.pendingDelete = workspace
        }
    }

    private var selectedWorkspace: WorkspaceSnapshot? {
        guard let selectedWorkspaceID else { return nil }
        return appState.workspaces.first { $0.id == selectedWorkspaceID }
    }

    private var filteredWorkspaces: [WorkspaceSnapshot] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return appState.workspaces }
        return appState.workspaces.filter { workspace in
            workspace.name.localizedCaseInsensitiveContains(query)
                || workspace.finder.windows.flatMap(\.tabs).contains { tab in
                    tab.path.localizedCaseInsensitiveContains(query)
                }
        }
    }

    private var permissionsReady: Bool {
        appState.capabilities.automationPermission == .granted
            && appState.capabilities.accessibilityPermission == .granted
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

    private func beginRename(_ workspace: WorkspaceSnapshot) {
        draftName = workspace.name
        promptMode = .rename(workspace)
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

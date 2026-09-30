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
    @State private var isSidebarVisible = true

    var body: some View {
        HStack(spacing: 0) {
            if isSidebarVisible {
                workspaceLibrary
                    .frame(width: 320)
                    .background(SidebarMaterialBackground())
                    .overlay(alignment: .trailing) {
                        SidebarHairline()
                    }
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }

            detailContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isSidebarVisible.toggle()
                    }
                } label: {
                    Image(systemName: "sidebar.leading")
                }
                .help(L10n.text(isSidebarVisible
                    ? "workspace.hide_sidebar"
                    : "workspace.show_sidebar"))
            }

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

    @ViewBuilder
    private var detailContent: some View {
        if let workspace = selectedWorkspace {
            WorkspacePreviewView(
                workspace: workspace,
                appState: appState,
                rename: { beginRename(workspace) },
                delete: { appState.pendingDelete = workspace }
            )
            .id(workspace.id)
        } else if appState.workspaces.isEmpty {
            WorkspaceWelcomeView {
                beginSave(closeAfterSave: false)
            }
        } else {
            WorkspaceSelectionPlaceholder()
        }
    }

    private var workspaceLibrary: some View {
        VStack(spacing: 0) {
            libraryHeader

            Group {
                if appState.workspaces.isEmpty {
                    WorkspaceLibraryEmptyState()
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
    }

    private var libraryHeader: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.text("workspace.library_title"))
                    .font(.title3.weight(.semibold))
                Text(appState.workspaces.isEmpty
                    ? L10n.text("workspace.library_empty_count")
                    : L10n.text("workspace.library_count", appState.workspaces.count))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Button {
                beginSave(closeAfterSave: false)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 28, height: 26)
                    .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.borderless)
            .help(L10n.text("save.current_workspace"))
            .disabled(appState.isOperating)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            SidebarHairline(axis: .horizontal)
        }
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
            SidebarHairline(axis: .horizontal)
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
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
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

private struct SidebarMaterialBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .sidebar
        view.blendingMode = .behindWindow
        view.state = .followsWindowActiveState
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

private struct SidebarHairline: View {
    enum Axis {
        case horizontal
        case vertical
    }

    var axis: Axis = .vertical

    var body: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor).opacity(0.32))
            .frame(
                width: axis == .vertical ? 0.5 : nil,
                height: axis == .horizontal ? 0.5 : nil
            )
            .accessibilityHidden(true)
    }
}

private struct WorkspaceLibraryEmptyState: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "folder")
                .font(.system(size: 25, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .frame(width: 58, height: 58)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 15))

            VStack(spacing: 6) {
                Text(L10n.text("empty.title"))
                    .font(.headline)
                Text(L10n.text("empty.sidebar_description"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: 230)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

private struct WorkspaceWelcomeView: View {
    let save: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "folder.badge.plus")
                    .symbolRenderingMode(.hierarchical)
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 96, height: 96)
                    .background(Color.accentColor.opacity(0.11), in: RoundedRectangle(cornerRadius: 24))
                    .overlay {
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.accentColor.opacity(0.18), lineWidth: 1)
                    }

                VStack(spacing: 9) {
                    Text(L10n.text("empty.welcome_title"))
                        .font(.system(size: 28, weight: .bold))
                        .multilineTextAlignment(.center)
                    Text(L10n.text("empty.welcome_description"))
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: 510)

                Button(action: save) {
                    Label(L10n.text("save.current_workspace"), systemImage: "plus")
                        .font(.body.weight(.semibold))
                        .padding(.horizontal, 6)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut("s", modifiers: [.command])

                HStack(alignment: .top, spacing: 12) {
                    featureCards
                }
                .frame(maxWidth: 570)
            }
            .padding(.horizontal, 36)
            .padding(.vertical, 54)
            .frame(maxWidth: .infinity, minHeight: 600)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private var featureCards: some View {
        WorkspaceFeatureCard(
            icon: "macwindow.on.rectangle",
            titleKey: "empty.feature_windows_title",
            descriptionKey: "empty.feature_windows_description"
        )
        WorkspaceFeatureCard(
            icon: "square.stack.3d.up",
            titleKey: "empty.feature_tabs_title",
            descriptionKey: "empty.feature_tabs_description"
        )
        WorkspaceFeatureCard(
            icon: "arrow.clockwise",
            titleKey: "empty.feature_restore_title",
            descriptionKey: "empty.feature_restore_description"
        )
    }
}

private struct WorkspaceFeatureCard: View {
    let icon: String
    let titleKey: String
    let descriptionKey: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 34, height: 34)
                .background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 9))

            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.text(titleKey))
                    .font(.subheadline.weight(.semibold))
                Text(L10n.text(descriptionKey))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(minWidth: 130, maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .padding(16)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.primary.opacity(0.07), lineWidth: 1)
        }
    }
}

private struct WorkspaceSelectionPlaceholder: View {
    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "square.stack.3d.up")
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .frame(width: 78, height: 78)
                .background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 20))

            VStack(spacing: 7) {
                Text(L10n.text("workspace.select_title"))
                    .font(.title2.weight(.semibold))
                Text(L10n.text("workspace.select_description"))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
            .frame(maxWidth: 440)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .accessibilityElement(children: .combine)
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

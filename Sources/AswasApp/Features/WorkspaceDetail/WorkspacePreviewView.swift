import AppKit
import AswasCore
import SwiftUI

struct WorkspacePreviewView: View {
    let workspace: WorkspaceSnapshot
    @Bindable var appState: AppState
    let rename: () -> Void
    let delete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    windowPreview
                }
                .padding(28)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            actionBar
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 18) {
            Image(systemName: "folder")
                .font(.system(size: 38, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .frame(width: 84, height: 84)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 6) {
                Text(workspace.name)
                    .font(.title2.bold())
                    .lineLimit(2)
                Text(
                    L10n.text(
                        "workspace.detail_summary",
                        workspace.finder.windows.count,
                        workspace.finder.tabCount
                    )
                )
                .font(.headline)
                .foregroundStyle(.secondary)
                WorkspaceSavedTimeText(date: workspace.updatedAt)
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                Label(
                    L10n.text(restoreReady
                        ? "workspace.safe_restore"
                        : "workspace.restore_needs_permission"),
                    systemImage: restoreReady ? "checkmark.circle" : "exclamationmark.circle"
                )
                    .font(.caption.weight(.medium))
                    .foregroundStyle(restoreReady ? Color.green : Color.orange)
                    .padding(.top, 2)
            }

            Spacer(minLength: 12)
            workspaceActions
        }
    }

    private var windowPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.text("workspace.window_preview"))
                    .font(.headline)
                Spacer()
                Text(L10n.text("workspace.tab_order_hint"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            LazyVStack(spacing: 10) {
                ForEach(Array(workspace.finder.windows.enumerated()), id: \.element.id) { index, window in
                    WindowPreviewSection(index: index, window: window)
                }
            }
        }
    }

    private var workspaceActions: some View {
        Menu {
            Button(L10n.text("workspace.detail_update")) {
                Task { await appState.updateWorkspace(workspace) }
            }
            Button(L10n.text("workspace.detail_update_close")) {
                Task { await appState.updateWorkspaceAndClose(workspace) }
            }
            Button(L10n.text("workspace.rename"), action: rename)
            Divider()
            Button(L10n.text("workspace.delete"), role: .destructive, action: delete)
        } label: {
            Image(systemName: "ellipsis")
                .frame(width: 28, height: 24)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .help(L10n.text("workspace.more_actions"))
        .disabled(appState.isOperating)
    }

    private var restoreReady: Bool {
        guard appState.capabilities.automationPermission == .granted else { return false }
        let needsTabPermission = workspace.finder.tabCount > workspace.finder.windows.count
        return !needsTabPermission || appState.capabilities.accessibilityPermission == .granted
    }

    private var actionBar: some View {
        HStack(spacing: 12) {
            if appState.isOperating {
                ProgressView()
                    .controlSize(.small)
                Text(L10n.text("notice.operation_message"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(L10n.text("workspace.detail_restore_replace")) {
                Task { await appState.requestRestore(workspace, mode: .replace) }
            }
            Button(L10n.text("workspace.detail_restore_open")) {
                Task { await appState.requestRestore(workspace, mode: .open) }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
        .disabled(appState.isOperating)
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.bar)
    }
}

private struct WindowPreviewSection: View {
    let index: Int
    let window: FinderWindowState
    @State private var isExpanded = true

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(spacing: 0) {
                ForEach(Array(window.tabs.enumerated()), id: \.element.id) { tabIndex, tab in
                    Divider()
                    tabRow(tab, isSelected: tabIndex == window.selectedTabIndex)
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "macwindow")
                    .foregroundStyle(Color.accentColor)
                Text(L10n.text("common.window_number", index + 1))
                    .font(.subheadline.weight(.semibold))
                Text(L10n.text("workspace.tab_count", window.tabs.count))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if let selectedTab = window.selectedTab {
                    Text(PathNormalizer.abbreviateHome(selectedTab.path))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: 260, alignment: .trailing)
                }
            }
            .padding(.vertical, 3)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 10))
    }

    private func tabRow(_ tab: FinderTabState, isSelected: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: FileManager.default.fileExists(atPath: tab.path)
                ? "folder"
                : "exclamationmark.triangle")
                .foregroundStyle(FileManager.default.fileExists(atPath: tab.path)
                    ? Color.accentColor
                    : Color.orange)
            Text(PathNormalizer.abbreviateHome(tab.path))
                .font(.subheadline)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(tab.path)
            if isSelected {
                Label(L10n.text("workspace.selected_tab"), systemImage: "checkmark.circle.fill")
                    .labelStyle(.iconOnly)
                    .foregroundStyle(Color.accentColor)
                    .help(L10n.text("workspace.selected_tab"))
            }
            Spacer(minLength: 10)
            Button {
                NSWorkspace.shared.open(URL(fileURLWithPath: tab.path))
            } label: {
                Image(systemName: "arrow.up.forward.square")
            }
            .buttonStyle(.borderless)
            .help(L10n.text("workspace.open_finder"))
            .accessibilityLabel(L10n.text("workspace.open_finder"))
        }
        .padding(.leading, 24)
        .padding(.vertical, 8)
    }
}

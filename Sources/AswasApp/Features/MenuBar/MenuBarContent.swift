import AswasCore
import SwiftUI

struct MenuBarContent: View {
    @Bindable var appState: AppState
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    @AppStorage("defaultRestoreMode") private var defaultRestoreMode = RestoreMode.open.rawValue
    @State private var showingSavePrompt = false
    @State private var showingSaveAndClosePrompt = false
    @State private var workspaceName = ""

    private var restoreMode: RestoreMode {
        RestoreMode(rawValue: defaultRestoreMode) ?? .open
    }

    var body: some View {
        if let last = appState.workspaces.first {
            Button(L10n.text("menu.restore_last")) {
                Task { await appState.requestRestore(last, mode: restoreMode) }
            }
            Divider()
        }

        if appState.workspaces.isEmpty {
            Text(L10n.text("menu.no_workspaces"))
        } else {
            Menu(L10n.text("menu.workspaces")) {
                ForEach(appState.workspaces) { workspace in
                    Button(workspace.name) {
                        Task { await appState.requestRestore(workspace, mode: restoreMode) }
                    }
                }
            }
        }

        Divider()
        Button(L10n.text("menu.save_current")) {
            workspaceName = suggestedName()
            showingSavePrompt = true
        }
        Button(L10n.text("menu.save_close")) {
            workspaceName = suggestedName()
            showingSaveAndClosePrompt = true
        }
        .disabled(appState.isOperating)

        Divider()
        Button(L10n.text("menu.open_app")) {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "main")
        }
        Button(L10n.text("menu.settings")) {
            NSApp.activate(ignoringOtherApps: true)
            openSettings()
        }
        Button(L10n.text("menu.quit")) { NSApp.terminate(nil) }

        promptAlerts
    }

    @ViewBuilder
    private var promptAlerts: some View {
        EmptyView()
            .alert(L10n.text("save.title"), isPresented: $showingSavePrompt) {
                TextField(L10n.text("common.workspace_name"), text: $workspaceName)
                Button(L10n.text("common.cancel"), role: .cancel) {}
                Button(L10n.text("common.save")) {
                    Task { await appState.saveWorkspace(named: workspaceName, closeAfterSave: false) }
                }
                .disabled(workspaceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } message: {
                Text(L10n.text("save.message"))
            }
            .alert(L10n.text("save.close_title"), isPresented: $showingSaveAndClosePrompt) {
                TextField(L10n.text("common.workspace_name"), text: $workspaceName)
                Button(L10n.text("common.cancel"), role: .cancel) {}
                Button(L10n.text("save.close_title")) {
                    Task { await appState.saveWorkspace(named: workspaceName, closeAfterSave: true) }
                }
                .disabled(workspaceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } message: {
                Text(L10n.text("save.close_message"))
            }
    }

    private func suggestedName() -> String {
        L10n.text(
            "save.default_name",
            Date().formatted(date: .abbreviated, time: .shortened)
        )
    }
}

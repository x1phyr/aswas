import AswasCore
import SwiftUI

struct MenuBarContent: View {
    @Bindable var appState: AppState
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    @AppStorage("defaultRestoreMode") private var defaultRestoreMode = RestoreMode.open.rawValue

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
            presentSave(closeAfterSave: false)
        }
        .disabled(appState.isOperating)
        Button(L10n.text("menu.save_close")) {
            presentSave(closeAfterSave: true)
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
    }

    private func presentSave(closeAfterSave: Bool) {
        appState.notice = nil
        appState.pendingMenuSave = PendingMenuSave(
            closeAfterSave: closeAfterSave,
            suggestedName: suggestedName()
        )
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: "menu-save")
    }

    private func suggestedName() -> String {
        L10n.text(
            "save.default_name",
            Date().formatted(date: .abbreviated, time: .shortened)
        )
    }
}

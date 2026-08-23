import AswasCore
import SwiftUI

@main
struct AswasApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appState = AppState()
    @AppStorage(AswasLocalization.languageDefaultsKey)
    private var appLanguage = AswasLanguage.system.rawValue

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent(appState: appState)
                .id(appLanguage)
        } label: {
            Label("aswas", systemImage: "folder.badge.gearshape")
        }
        .menuBarExtraStyle(.menu)

        Window("aswas", id: "main") {
            WorkspaceListView(appState: appState)
                .id(appLanguage)
                .frame(minWidth: 860, minHeight: 560)
                .task { await appState.refresh() }
        }
        .defaultSize(width: 1120, height: 720)

        Window(L10n.text("save.title"), id: "menu-save") {
            MenuBarSaveView(appState: appState)
                .id(appLanguage)
        }
        .windowResizability(.contentSize)

        Settings {
            SettingsView(appState: appState)
                .id(appLanguage)
                .frame(width: 520, height: 360)
        }
    }
}

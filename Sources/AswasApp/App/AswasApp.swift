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
            MenuBarStatusLabel()
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

private struct MenuBarStatusLabel: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Label("aswas", systemImage: "folder.badge.gearshape")
            .task {
                guard AppDelegate.consumeInitialMainWindowRequest() else { return }
                AppDelegate.prepareToShowMainWindow()
                openWindow(id: "main")
            }
            .onReceive(NotificationCenter.default.publisher(for: .aswasShowMainWindow)) { _ in
                AppDelegate.prepareToShowMainWindow()
                openWindow(id: "main")
            }
    }
}

import AppKit
import AswasCore
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @Bindable var appState: AppState
    @AppStorage("defaultRestoreMode") private var defaultRestoreMode = RestoreMode.open.rawValue
    @AppStorage("confirmBeforeReplace") private var confirmBeforeReplace = true
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @AppStorage(AswasLocalization.languageDefaultsKey)
    private var appLanguage = AswasLanguage.system.rawValue

    var body: some View {
        TabView {
            Form {
                Picker(L10n.text("settings.language"), selection: $appLanguage) {
                    Text(L10n.text("language.system")).tag(AswasLanguage.system.rawValue)
                    Text(L10n.text("language.english")).tag(AswasLanguage.english.rawValue)
                    Text(L10n.text("language.simplified_chinese"))
                        .tag(AswasLanguage.simplifiedChinese.rawValue)
                }
                Toggle(L10n.text("settings.launch_login"), isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        appState.setLaunchAtLogin(enabled)
                    }
                Picker(L10n.text("settings.default_restore"), selection: $defaultRestoreMode) {
                    Text(L10n.text("settings.restore_open")).tag(RestoreMode.open.rawValue)
                    Text(L10n.text("settings.restore_replace")).tag(RestoreMode.replace.rawValue)
                }
                Toggle(L10n.text("settings.confirm_replace"), isOn: $confirmBeforeReplace)
                    .disabled(true)
                Text(L10n.text("settings.confirm_required"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
            .tabItem { Label(L10n.text("settings.general"), systemImage: "gearshape") }

            Form {
                LabeledContent(L10n.text("settings.finder_automation")) {
                    Text(automationStatus)
                        .foregroundStyle(appState.capabilities.automationPermission == .granted ? .green : .orange)
                }
                LabeledContent(L10n.text("settings.accessibility")) {
                    Text(accessibilityStatus)
                        .foregroundStyle(appState.capabilities.accessibilityPermission == .granted ? .green : .orange)
                }
                HStack {
                    Button(L10n.text("settings.request_permission")) {
                        Task { await appState.requestAutomationPermission() }
                    }
                    Button(L10n.text("settings.request_accessibility")) {
                        Task { await appState.requestAccessibilityPermission() }
                    }
                    Button(L10n.text("settings.check_again")) {
                        Task { await appState.refresh() }
                    }
                }
                Text(L10n.text("settings.accessibility_explanation"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
            .tabItem { Label(L10n.text("settings.permissions"), systemImage: "lock.shield") }

            Form {
                Button(L10n.text("settings.open_data")) {
                    appState.openWorkspaceDataFolder()
                }
                Text(appState.workspaceDataDirectory.path)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            .padding(20)
            .tabItem { Label(L10n.text("settings.advanced"), systemImage: "wrench.and.screwdriver") }
        }
    }

    private var automationStatus: String {
        switch appState.capabilities.automationPermission {
        case .granted: L10n.text("status.granted")
        case .notDetermined: L10n.text("status.not_requested")
        case .denied: L10n.text("status.denied")
        case .finderUnavailable: L10n.text("status.finder_unavailable")
        case .unknown: L10n.text("status.unknown")
        }
    }

    private var accessibilityStatus: String {
        switch appState.capabilities.accessibilityPermission {
        case .notRequired: L10n.text("status.not_required")
        case .required: L10n.text("status.required")
        case .granted: L10n.text("status.granted")
        }
    }
}

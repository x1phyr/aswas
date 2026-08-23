import SwiftUI

struct MenuBarSaveView: View {
    @Bindable var appState: AppState
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var workspaceName = ""
    @State private var resultNotice: UserFacingNotice?

    private var request: PendingMenuSave? {
        appState.pendingMenuSave
    }

    var body: some View {
        Group {
            if request == nil {
                Color.clear
                    .frame(width: 1, height: 1)
                    .onAppear { dismissWindow(id: "menu-save") }
            } else {
                VStack(alignment: .leading, spacing: 18) {
                    if let resultNotice {
                        resultView(resultNotice)
                    } else {
                        promptView
                    }
                }
                .padding(22)
                .frame(width: 420)
            }
        }
        .onChange(of: request?.id, initial: true) { _, _ in
            workspaceName = request?.suggestedName ?? ""
            resultNotice = nil
        }
        .onDisappear {
            appState.pendingMenuSave = nil
        }
    }

    private var promptView: some View {
        Group {
            VStack(alignment: .leading, spacing: 6) {
                Text(request?.closeAfterSave == true
                    ? L10n.text("save.close_title")
                    : L10n.text("save.title"))
                    .font(.title3.bold())
                Text(request?.closeAfterSave == true
                    ? L10n.text("save.close_message")
                    : L10n.text("save.message"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            TextField(L10n.text("common.workspace_name"), text: $workspaceName)
                .textFieldStyle(.roundedBorder)
                .onSubmit(submit)

            HStack {
                if appState.isOperating {
                    ProgressView()
                        .controlSize(.small)
                    Text(L10n.text("notice.operation_message"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(L10n.text("common.cancel"), role: .cancel) {
                    close()
                }
                Button(actionTitle, action: submit)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(isSubmitDisabled)
            }
        }
    }

    private func resultView(_ notice: UserFacingNotice) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(notice.title)
                .font(.title3.bold())
            Text(notice.message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button(L10n.text("common.ok")) {
                    close()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    private var actionTitle: String {
        request?.closeAfterSave == true
            ? L10n.text("save.close_title")
            : L10n.text("common.save")
    }

    private var isSubmitDisabled: Bool {
        request == nil
            || appState.isOperating
            || workspaceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submit() {
        guard let request, !isSubmitDisabled else { return }
        Task {
            await appState.saveWorkspace(
                named: workspaceName,
                closeAfterSave: request.closeAfterSave
            )
            resultNotice = appState.notice
            appState.notice = nil
        }
    }

    private func close() {
        appState.pendingMenuSave = nil
        resultNotice = nil
        dismissWindow(id: "menu-save")
    }
}

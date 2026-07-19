import AppKit
import AswasCore
import Foundation
import Observation
import ServiceManagement

struct UserFacingNotice: Identifiable, Equatable {
    let id = UUID()
    var title: String
    var message: String
}

struct PendingReplace: Equatable {
    var workspace: WorkspaceSnapshot
    var preview: FinderCaptureResult
}

@MainActor
@Observable
final class AppState {
    var workspaces: [WorkspaceSnapshot] = []
    var isOperating = false
    var notice: UserFacingNotice?
    var pendingReplace: PendingReplace?
    var pendingDelete: WorkspaceSnapshot?
    var capabilities = FinderCapabilities(
        automationPermission: .notDetermined,
        accessibilityPermission: .required,
        canCaptureWindows: false,
        canRestoreWindows: false,
        canCaptureTabs: false,
        canRestoreTabs: false
    )

    @ObservationIgnored private let integration: FinderAppleScriptIntegration
    @ObservationIgnored private let libraryService: WorkspaceLibraryService
    @ObservationIgnored private let captureService: WorkspaceCaptureService
    @ObservationIgnored private let restoreService: WorkspaceRestoreService
    @ObservationIgnored private let saveAndCloseService: SaveAndCloseService
    @ObservationIgnored let workspaceDataDirectory: URL

    init() {
        let rootDirectory = (try? JSONWorkspaceRepository.defaultRootDirectory())
            ?? FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support/aswas", isDirectory: true)
        let repository = JSONWorkspaceRepository(rootDirectory: rootDirectory)
        let integration = FinderAppleScriptIntegration()
        let captureService = WorkspaceCaptureService(
            integration: integration,
            repository: repository
        )

        self.workspaceDataDirectory = rootDirectory
        self.integration = integration
        self.libraryService = WorkspaceLibraryService(repository: repository)
        self.captureService = captureService
        self.restoreService = WorkspaceRestoreService(
            integration: integration,
            repository: repository
        )
        self.saveAndCloseService = SaveAndCloseService(
            captureService: captureService,
            integration: integration
        )
    }

    func refresh() async {
        do {
            workspaces = try await libraryService.list()
            capabilities = await integration.checkCapabilities()
        } catch {
            showError(error)
        }
    }

    func requestAutomationPermission() async {
        isOperating = true
        let status = await integration.requestAutomationPermission()
        isOperating = false
        capabilities = await integration.checkCapabilities()
        if status != .granted {
            notice = UserFacingNotice(
                title: L10n.text("notice.permission_title"),
                message: L10n.text("notice.permission_message")
            )
        }
    }

    func requestAccessibilityPermission() async {
        isOperating = true
        let status = await integration.requestAccessibilityPermission()
        isOperating = false
        capabilities = await integration.checkCapabilities()
        if status != .granted {
            notice = UserFacingNotice(
                title: L10n.text("notice.accessibility_title"),
                message: L10n.text("notice.accessibility_message")
            )
        }
    }

    func saveWorkspace(named name: String, closeAfterSave: Bool) async {
        guard beginOperation() else { return }
        defer { endOperation() }
        do {
            if closeAfterSave {
                let result = try await saveAndCloseService.createWorkspaceAndClose(named: name)
                await refreshAfterOperation()
                notice = UserFacingNotice(
                    title: L10n.text("notice.saved_close_title", result.workspace.name),
                    message: L10n.text(
                        "notice.saved_close_message",
                        result.workspace.finder.windows.count,
                        result.closedWindowCount,
                        warningSuffix(result.warnings, errors: result.errors)
                    )
                )
            } else {
                let result = try await captureService.createWorkspace(named: name)
                await refreshAfterOperation()
                notice = UserFacingNotice(
                    title: L10n.text("notice.saved_title", result.workspace.name),
                    message: L10n.text(
                        "notice.saved_message",
                        result.workspace.finder.windows.count,
                        result.workspace.finder.tabCount,
                        warningSuffix(result.warnings, errors: [])
                    )
                )
            }
        } catch {
            showError(error)
        }
    }

    func updateWorkspace(_ workspace: WorkspaceSnapshot) async {
        guard beginOperation() else { return }
        defer { endOperation() }
        do {
            let result = try await captureService.updateWorkspace(id: workspace.id)
            await refreshAfterOperation()
            notice = UserFacingNotice(
                title: L10n.text("notice.updated_title", result.workspace.name),
                message: L10n.text(
                    "notice.updated_message",
                    result.workspace.finder.windows.count,
                    warningSuffix(result.warnings, errors: [])
                )
            )
        } catch {
            showError(error)
        }
    }

    func updateWorkspaceAndClose(_ workspace: WorkspaceSnapshot) async {
        guard beginOperation() else { return }
        defer { endOperation() }
        do {
            let result = try await saveAndCloseService.updateWorkspaceAndClose(id: workspace.id)
            await refreshAfterOperation()
            notice = UserFacingNotice(
                title: L10n.text("notice.updated_close_title", result.workspace.name),
                message: L10n.text(
                    "notice.updated_close_message",
                    result.closedWindowCount,
                    warningSuffix(result.warnings, errors: result.errors)
                )
            )
        } catch {
            showError(error)
        }
    }

    func renameWorkspace(_ workspace: WorkspaceSnapshot, to name: String) async {
        guard beginOperation() else { return }
        defer { endOperation() }
        do {
            _ = try await libraryService.rename(id: workspace.id, to: name)
            await refreshAfterOperation()
        } catch {
            showError(error)
        }
    }

    func deleteWorkspace(_ workspace: WorkspaceSnapshot) async {
        guard beginOperation() else { return }
        pendingDelete = nil
        defer { endOperation() }
        do {
            try await libraryService.delete(id: workspace.id)
            await refreshAfterOperation()
        } catch {
            showError(error)
        }
    }

    func requestRestore(_ workspace: WorkspaceSnapshot, mode: RestoreMode) async {
        guard await prepareTabRestoreIfNeeded(for: workspace) else { return }

        if mode == .replace {
            guard beginOperation() else { return }
            defer { endOperation() }
            do {
                let preview = try await restoreService.previewReplace()
                pendingReplace = PendingReplace(workspace: workspace, preview: preview)
            } catch FinderIntegrationError.noReadableWindows {
                endOperation()
                await performRestore(workspace, mode: .open)
            } catch {
                showError(error)
            }
        } else {
            await performRestore(workspace, mode: .open)
        }
    }

    func confirmReplace(_ pending: PendingReplace) async {
        pendingReplace = nil
        await performRestore(pending.workspace, mode: .replace)
    }

    func cancelReplace() {
        pendingReplace = nil
    }

    func openWorkspaceDataFolder() {
        NSWorkspace.shared.open(workspaceDataDirectory)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            showError(error)
        }
    }

    private func performRestore(_ workspace: WorkspaceSnapshot, mode: RestoreMode) async {
        guard beginOperation() else { return }
        defer { endOperation() }
        do {
            let result = try await restoreService.restore(id: workspace.id, mode: mode)
            notice = UserFacingNotice(
                title: L10n.text("notice.restored_title", workspace.name),
                message: L10n.text(
                    "notice.restored_message",
                    result.restoredWindowCount,
                    result.restoredTabCount,
                    warningSuffix(result.warnings, errors: result.errors)
                )
            )
        } catch {
            showError(error)
        }
    }

    private func prepareTabRestoreIfNeeded(for workspace: WorkspaceSnapshot) async -> Bool {
        guard workspace.finder.windows.contains(where: { $0.tabs.count > 1 }) else {
            return true
        }

        capabilities = await integration.checkCapabilities()
        guard !capabilities.canRestoreTabs else { return true }

        _ = await integration.requestAccessibilityPermission()
        capabilities = await integration.checkCapabilities()
        guard capabilities.canRestoreTabs else {
            notice = UserFacingNotice(
                title: L10n.text("notice.accessibility_restore_title"),
                message: L10n.text("notice.accessibility_restore_message")
            )
            return false
        }
        return true
    }

    private func beginOperation() -> Bool {
        guard !isOperating else {
            notice = UserFacingNotice(
                title: L10n.text("notice.operation_title"),
                message: L10n.text("notice.operation_message")
            )
            return false
        }
        isOperating = true
        return true
    }

    private func endOperation() {
        isOperating = false
    }

    private func refreshAfterOperation() async {
        do {
            workspaces = try await libraryService.list()
        } catch {
            showError(error)
        }
    }

    private func warningSuffix(
        _ warnings: [WorkspaceWarning],
        errors: [WorkspaceOperationError]
    ) -> String {
        let issueCount = warnings.count + errors.count
        guard issueCount > 0 else { return "" }
        let messages = warnings.map(\.message) + errors.map(\.message)
        var uniqueMessages: [String] = []
        for message in messages where !uniqueMessages.contains(message) {
            uniqueMessages.append(message)
        }
        let details = uniqueMessages.prefix(3).map { "• \($0)" }.joined(separator: "\n")
        return L10n.text("common.attention_count", issueCount)
            + (details.isEmpty ? "" : "\n\(details)")
    }

    private func showError(_ error: Error) {
        notice = UserFacingNotice(
            title: L10n.text("notice.error_title"),
            message: (error as? LocalizedError)?.errorDescription
                ?? L10n.text("notice.unknown_error")
        )
    }
}

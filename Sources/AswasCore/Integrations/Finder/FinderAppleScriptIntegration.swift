import ApplicationServices
import Foundation

public actor FinderAppleScriptIntegration: FinderWorkspaceIntegration {
    private let scriptRunner: AppleScriptRunner
    private let capabilityDetector: FinderCapabilityDetector
    private let displayProvider: any DisplaySnapshotProviding
    private let tabController: FinderAccessibilityTabController
    private let decoder: JSONDecoder

    public init(
        scriptRunner: AppleScriptRunner = AppleScriptRunner(),
        capabilityDetector: FinderCapabilityDetector = FinderCapabilityDetector(),
        displayProvider: any DisplaySnapshotProviding = SystemDisplayProvider()
    ) {
        self.scriptRunner = scriptRunner
        self.capabilityDetector = capabilityDetector
        self.displayProvider = displayProvider
        self.tabController = FinderAccessibilityTabController()
        self.decoder = JSONDecoder()
    }

    public func checkCapabilities() async -> FinderCapabilities {
        let capabilities = capabilityDetector.check(askUserIfNeeded: false)
        AswasLog.permissions.debug("Finder Automation status checked")
        return capabilities
    }

    public func requestAutomationPermission() async -> AutomationPermissionStatus {
        capabilityDetector.automationPermission(askUserIfNeeded: true)
    }

    public func requestAccessibilityPermission() async -> AccessibilityPermissionStatus {
        capabilityDetector.requestAccessibilityPermission()
    }

    public func captureCurrentState() async throws -> FinderCaptureResult {
        do {
            let output = try await scriptRunner.runBundledScript(named: "finder-capture")
            guard let data = output.data(using: .utf8) else {
                throw FinderIntegrationError.malformedResponse
            }
            let payload = try decoder.decode(FinderCapturePayload.self, from: data)
            let tabSnapshots = tabController.captureTabs(for: payload.windows)
            AswasLog.capture.info(
                "Captured complete tab groups for \(tabSnapshots.count) of \(payload.windows.count) Finder windows"
            )
            let displays = await displayProvider.snapshot()
            let result = try FinderCapturePayloadMapper.map(
                payload,
                displays: displays,
                tabSnapshots: tabSnapshots
            )
            AswasLog.capture.info("Captured \(result.state.windows.count) Finder windows")
            return result
        } catch let error as FinderIntegrationError {
            throw error
        } catch let error as AppleScriptFailure {
            AswasLog.automation.error("Capture AppleScript failed with code \(error.number ?? 0)")
            switch error.number {
            case -1743:
                throw FinderIntegrationError.permissionDenied
            case -600:
                throw FinderIntegrationError.finderUnavailable
            default:
                throw FinderIntegrationError.scriptExecutionFailed(
                    code: error.number,
                    message: error.message
                )
            }
        } catch {
            throw FinderIntegrationError.malformedResponse
        }
    }

    public func restore(
        _ state: FinderWorkspaceState,
        mode: RestoreMode
    ) async throws -> FinderRestoreResult {
        // Opening additional tabs requires Accessibility-driven keyboard events.
        // Never silently flatten a multi-tab workspace into one folder per window.
        guard !state.windows.contains(where: { $0.tabs.count > 1 }) || AXIsProcessTrusted() else {
            throw FinderIntegrationError.accessibilityPermissionRequired
        }

        var result = FinderRestoreResult()

        if mode == .replace {
            do {
                let current = try await captureCurrentState()
                let closeResult = try await closeManagedWindows(current.managedWindows)
                result.errors.append(contentsOf: closeResult.errors)
            } catch FinderIntegrationError.noReadableWindows {
                // No ordinary Finder windows are open, so Replace can proceed as Open.
            }
        }

        for window in state.windows {
            guard let firstTab = window.tabs.first else {
                result.errors.append(
                    WorkspaceOperationError(
                        code: .invalidWorkspaceData,
                        message: AswasLocalization.string("warning.window_no_folder")
                    )
                )
                continue
            }

            let frameArguments: [String]
            if let frame = window.frame {
                frameArguments = [
                    String(Int(frame.x.rounded())),
                    String(Int(frame.y.rounded())),
                    String(Int((frame.x + frame.width).rounded())),
                    String(Int((frame.y + frame.height).rounded()))
                ]
            } else {
                frameArguments = ["", "", "", ""]
            }

            do {
                let output = try await scriptRunner.runBundledScript(
                    named: "finder-restore",
                    handler: "restoreWindow",
                    arguments: [firstTab.path] + frameArguments + [window.viewMode?.rawValue ?? "unknown"]
                )
                guard let data = output.data(using: .utf8) else {
                    throw FinderIntegrationError.malformedResponse
                }
                let payload = try decoder.decode(FinderRestoreWindowPayload.self, from: data)
                guard payload.success, let windowID = payload.windowID else {
                    result.errors.append(
                        WorkspaceOperationError(
                            code: .windowCreationFailed,
                            message: AswasLocalization.string("warning.window_create")
                        )
                    )
                    continue
                }

                result.restoredWindowCount += 1
                result.restoredTabCount += 1
                result.createdWindows.append(FinderWindowReference(windowID: windowID))
                if payload.frameRestored == false {
                    result.warnings.append(
                        WorkspaceWarning(
                            code: .displayUnavailable,
                            message: AswasLocalization.string("warning.frame_restore")
                        )
                    )
                }
                if payload.viewModeRestored == false {
                    result.warnings.append(
                        WorkspaceWarning(
                            code: .viewModeUnavailable,
                            message: AswasLocalization.string("warning.view_restore")
                        )
                    )
                }
                if window.tabs.count > 1, AXIsProcessTrusted() {
                    let additionalPaths = window.tabs.dropFirst().map(\.path)
                    let tabOutcome = await tabController.restoreAdditionalTabs(
                        paths: additionalPaths,
                        selectedTabIndex: window.selectedTabIndex,
                        expectedWindowFrame: window.frame,
                        setFrontWindowTarget: { [scriptRunner] path in
                            let output = try await scriptRunner.runBundledScript(
                                named: "finder-front-window",
                                handler: "setFrontWindowTarget",
                                arguments: [path]
                            )
                            guard let data = output.data(using: .utf8) else {
                                throw FinderIntegrationError.malformedResponse
                            }
                            return try JSONDecoder().decode(FinderSetTargetPayload.self, from: data).success
                        }
                    )
                    result.restoredTabCount += tabOutcome.restoredAdditionalTabs
                    for path in tabOutcome.failedPaths {
                        result.errors.append(
                            WorkspaceOperationError(
                                code: .tabCreationFailed,
                                message: AswasLocalization.string("warning.tab_create", path)
                            )
                        )
                    }
                    if !tabOutcome.selectedTabRestored {
                        result.warnings.append(
                            WorkspaceWarning(
                                code: .partialRestore,
                                message: AswasLocalization.string("warning.tab_selection")
                            )
                        )
                    }
                } else if window.tabs.count > 1 {
                    result.warnings.append(
                        WorkspaceWarning(
                            code: .tabsUnavailable,
                            message: AswasLocalization.string("warning.extra_tabs", window.tabs.count - 1)
                        )
                    )
                }
            } catch let error as AppleScriptFailure {
                result.errors.append(
                    WorkspaceOperationError(
                        code: error.number == -1743 ? .permissionDenied : .windowCreationFailed,
                        message: error.number == -1743
                            ? AswasLocalization.string("warning.restore_permission")
                            : AswasLocalization.string("warning.window_create")
                    )
                )
            } catch {
                result.errors.append(
                    WorkspaceOperationError(
                        code: .windowCreationFailed,
                        message: AswasLocalization.string("warning.window_create")
                    )
                )
            }
        }

        AswasLog.restore.info("Restored \(result.restoredWindowCount) Finder windows with \(result.errors.count) errors")
        return result
    }

    public func closeManagedWindows(
        _ windows: [FinderWindowReference]
    ) async throws -> FinderCloseResult {
        var result = FinderCloseResult()
        for window in windows {
            do {
                let output = try await scriptRunner.runBundledScript(
                    named: "finder-close",
                    handler: "closeWindowByID",
                    arguments: [String(window.windowID)]
                )
                guard let data = output.data(using: .utf8) else {
                    throw FinderIntegrationError.malformedResponse
                }
                let payload = try decoder.decode(FinderCloseWindowPayload.self, from: data)
                if payload.success {
                    result.closedWindowCount += 1
                } else if !payload.found {
                    result.missingWindows.append(window)
                } else {
                    result.failedWindows.append(window)
                    result.errors.append(
                        WorkspaceOperationError(
                            code: .scriptExecutionFailed,
                            message: AswasLocalization.string("warning.close_failed")
                        )
                    )
                }
            } catch {
                result.failedWindows.append(window)
                result.errors.append(
                    WorkspaceOperationError(
                        code: .scriptExecutionFailed,
                        message: AswasLocalization.string("warning.close_failed")
                    )
                )
            }
        }
        AswasLog.finder.info("Closed \(result.closedWindowCount) precisely tracked Finder windows")
        return result
    }
}

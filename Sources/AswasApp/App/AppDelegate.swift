import AppKit
import AswasCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static var initialMainWindowRequested = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.prepareToShowMainWindow()
        observeMainWindowLifecycle()
        AswasLog.app.info("aswas launched")
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        Self.prepareToShowMainWindow()
        NotificationCenter.default.post(name: .aswasShowMainWindow, object: nil)
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        NotificationCenter.default.removeObserver(self)
    }

    static func prepareToShowMainWindow() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    static func consumeInitialMainWindowRequest() -> Bool {
        guard !initialMainWindowRequested else { return false }
        initialMainWindowRequested = true
        return true
    }

    private func observeMainWindowLifecycle() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(mainWindowDidBecomeKey(_:)),
            name: NSWindow.didBecomeKeyNotification,
            object: nil,
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(mainWindowWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: nil,
        )
    }

    @objc private func mainWindowDidBecomeKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              Self.isMainWindow(window) else { return }
        Self.prepareToShowMainWindow()
    }

    @objc private func mainWindowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              Self.isMainWindow(window) else { return }
        Task { @MainActor in
            await Task.yield()
            let hasVisibleMainWindow = NSApp.windows.contains {
                Self.isMainWindow($0) && $0.isVisible
            }
            if !hasVisibleMainWindow {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }

    private static func isMainWindow(_ window: NSWindow) -> Bool {
        window.title == "aswas"
    }
}

extension Notification.Name {
    static let aswasShowMainWindow = Notification.Name("aswas.show-main-window")
}

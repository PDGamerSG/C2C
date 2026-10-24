import AppKit
import C2CCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var store: FileClipStore!
    private var service: ClipboardService!
    private var monitor: ClipboardMonitor!
    private var hotKey: HotKeyManager!
    private var pasteCoordinator: PasteCoordinator!
    private var panel: HistoryPanelController!
    private var statusItem: StatusItemController!
    private var settingsWindow: SettingsWindowController?
    private let login = LaunchAtLogin()
    private var settings = AppSettings()
    private var settingsURL: URL!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("C2C", isDirectory: true)
        settingsURL = support.appendingPathComponent("settings.json")
        let storeURL = support.appendingPathComponent("clipboard.json")
        if let data = try? Data(contentsOf: settingsURL), let loaded = try? JSONDecoder().decode(AppSettings.self, from: data) { settings = loaded }
        store = FileClipStore(url: storeURL, retentionLimit: settings.retentionLimit)
        service = ClipboardService(store: store, settings: settings)
        pasteCoordinator = PasteCoordinator()
        monitor = ClipboardMonitor(service: service) { NSWorkspace.shared.frontmostApplication?.bundleIdentifier }
        pasteCoordinator.beforePaste = { [weak self] in self?.monitor.ignoreNextChange() }
        panel = HistoryPanelController(store: store, pasteCoordinator: pasteCoordinator) { [weak self] in self?.showSettings() }
        statusItem = StatusItemController(onShow: { [weak self] in self?.panel.show() }, onSettings: { [weak self] in self?.showSettings() }, onQuit: { NSApp.terminate(nil) })
        hotKey = HotKeyManager(keyCode: settings.hotKeyKeyCode, modifiers: NSEvent.ModifierFlags(rawValue: settings.hotKeyModifiers))
        hotKey.onPress = { [weak self] in self?.panel.toggle() }
        hotKey.start()
        monitor.start()
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
        hotKey.stop()
        store.flush()
    }

    private func showSettings() {
        if settingsWindow == nil { settingsWindow = SettingsWindowController(settingsURL: settingsURL, settings: settings, store: store, launchAtLogin: login) { [weak self] updated in
                self?.settings = updated
                self?.service.update(settings: updated)
                self?.hotKey.update(keyCode: updated.hotKeyKeyCode, modifiers: NSEvent.ModifierFlags(rawValue: updated.hotKeyModifiers))
            } }
        settingsWindow?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

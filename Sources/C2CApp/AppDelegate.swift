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
    private var retentionTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("C2C", isDirectory: true)
        settingsURL = support.appendingPathComponent("settings.json")
        let storeURL = support.appendingPathComponent("clipboard.json")
        if let data = try? Data(contentsOf: settingsURL), let loaded = try? JSONDecoder().decode(AppSettings.self, from: data) { settings = loaded }
        HistoryAppearance.apply(settings.appearance)
        store = FileClipStore(url: storeURL, retentionLimit: settings.retentionLimit)
        service = ClipboardService(store: store, settings: settings)
        pasteCoordinator = PasteCoordinator()
        monitor = ClipboardMonitor(service: service) { NSWorkspace.shared.frontmostApplication?.bundleIdentifier }
        pasteCoordinator.beforePaste = { [weak self] in self?.monitor.ignoreNextChange() }
        panel = HistoryPanelController(store: store, pasteCoordinator: pasteCoordinator) { [weak self] in self?.showSettings() }
        statusItem = StatusItemController(onShow: { [weak self] in self?.panel.show() }, onSettings: { [weak self] in self?.showSettings() }, onQuit: { NSApp.terminate(nil) })
        hotKey = HotKeyManager(keyCode: settings.hotKeyKeyCode, modifiers: NSEvent.ModifierFlags(rawValue: settings.hotKeyModifiers))
        hotKey.onPress = { [weak self] in self?.panel.toggle() }
        let shortcutRegistered = hotKey.start()
        monitor.start()
        monitor.onChange = { [weak self] in self?.panel.reloadIfVisible() }
        let timer = Timer(timeInterval: 60, target: self, selector: #selector(cleanUpHistory), userInfo: nil, repeats: true)
        timer.tolerance = 5
        retentionTimer = timer
        RunLoop.main.add(timer, forMode: .common)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(cleanUpHistory), name: NSWorkspace.didWakeNotification, object: nil)
        NSApp.setActivationPolicy(.accessory)
        if !shortcutRegistered {
            showSettings()
            settingsWindow?.showError(hotKey.registrationError ?? "Choose an available shortcut.")
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
        hotKey.stop()
        retentionTimer?.invalidate()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        store.removeExpired()
        store.flush()
    }

    @objc private func cleanUpHistory() {
        if store.removeExpired() > 0 { panel.reloadIfVisible() }
    }

    private func showSettings() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindowController(settings: settings, store: store, onRecordingChange: { [weak self] recording in
                self?.hotKey.setRecording(recording)
            }, onAppearanceChange: { [weak self] appearance in
                try self?.saveAppearance(appearance)
            }, onSave: { [weak self] updated in
                try self?.saveSettings(updated)
            })
        }
        settingsWindow?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func saveAppearance(_ appearance: AppAppearance) throws {
        var updated = settings
        updated.appearance = appearance
        try FileManager.default.createDirectory(at: settingsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(updated).write(to: settingsURL, options: .atomic)
        settings = updated
        HistoryAppearance.apply(appearance)
        panel.reloadIfVisible()
    }

    private func saveSettings(_ updated: AppSettings) throws {
        guard hotKey.update(keyCode: updated.hotKeyKeyCode, modifiers: NSEvent.ModifierFlags(rawValue: updated.hotKeyModifiers)) else {
            throw NSError(domain: "C2C.Shortcut", code: 1, userInfo: [NSLocalizedDescriptionKey: hotKey.registrationError ?? "Shortcut registration failed."])
        }
        do {
            try FileManager.default.createDirectory(at: settingsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(updated).write(to: settingsURL, options: .atomic)
        } catch {
            hotKey.update(keyCode: settings.hotKeyKeyCode, modifiers: NSEvent.ModifierFlags(rawValue: settings.hotKeyModifiers))
            throw error
        }
        if updated.launchAtLogin != settings.launchAtLogin { login.setEnabled(updated.launchAtLogin) }
        settings = updated
        service.update(settings: updated)
        HistoryAppearance.apply(updated.appearance)
        panel.reloadIfVisible()
    }
}

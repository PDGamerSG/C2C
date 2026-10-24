import AppKit

@MainActor
final class StatusItemController: NSObject {
    let statusItem: NSStatusItem
    private let onShow: () -> Void
    private let onSettings: () -> Void
    private let onQuit: () -> Void

    init(onShow: @escaping () -> Void, onSettings: @escaping () -> Void, onQuit: @escaping () -> Void) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.onShow = onShow
        self.onSettings = onSettings
        self.onQuit = onQuit
        super.init()
        statusItem.button?.image = NSImage(systemSymbolName: "rectangle.on.rectangle", accessibilityDescription: "C2C Clipboard")
        statusItem.button?.toolTip = "C2C Clipboard"
        let menu = NSMenu()
        menu.addItem(withTitle: "Show Clipboard", action: #selector(showClipboard), keyEquivalent: "v")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        menu.addItem(withTitle: "Quit C2C", action: #selector(quit), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }
        statusItem.menu = menu
    }

    @objc private func showClipboard() { onShow() }
    @objc private func showSettings() { onSettings() }
    @objc private func quit() { onQuit() }
}

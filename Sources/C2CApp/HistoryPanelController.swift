import AppKit
import C2CCore

@MainActor
final class HistoryPanelController: NSObject, NSWindowDelegate {
    private let store: ClipStoreProtocol
    private let pasteCoordinator: PasteCoordinator
    private let onSettings: () -> Void
    private var panel: NSPanel?
    private var content: HistoryViewController?

    init(store: ClipStoreProtocol, pasteCoordinator: PasteCoordinator, onSettings: @escaping () -> Void) {
        self.store = store
        self.pasteCoordinator = pasteCoordinator
        self.onSettings = onSettings
    }

    func toggle() {
        if let panel, panel.isVisible { panel.orderOut(nil) }
        else { show() }
    }

    func show() {
        if panel == nil {
            let viewController = HistoryViewController(store: store, pasteCoordinator: pasteCoordinator, onSettings: onSettings)
            let panel = NSPanel(contentViewController: viewController)
            panel.styleMask = [.titled, .closable, .resizable, .nonactivatingPanel]
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.hidesOnDeactivate = false
            panel.title = "C2C Clipboard"
            panel.delegate = self
            panel.setContentSize(NSSize(width: 820, height: 540))
            self.panel = panel
            self.content = viewController
        }
        content?.reload()
        guard let panel else { return }
        if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            let size = panel.frame.size
            panel.setFrameOrigin(NSPoint(x: frame.maxX - size.width - 24, y: frame.maxY - size.height - 24))
        }
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }
}

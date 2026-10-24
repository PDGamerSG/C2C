import AppKit
import C2CCore

@MainActor
final class HistoryPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        orderOut(nil)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.keyCode == 53 {
            orderOut(nil)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}

@MainActor
final class HistoryPanelController: NSObject, NSWindowDelegate {
    private let store: ClipStoreProtocol
    private let pasteCoordinator: PasteCoordinator
    private let onSettings: () -> Void
    private var panel: HistoryPanel?
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
            let panel = HistoryPanel(contentViewController: viewController)
            panel.styleMask = [.borderless, .nonactivatingPanel]
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.hidesOnDeactivate = false
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = true
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.delegate = self
            panel.setContentSize(NSSize(width: 440, height: 470))
            self.panel = panel
            self.content = viewController
        }
        content?.reload()
        guard let panel else { return }
        if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            let size = panel.frame.size
            panel.setFrameOrigin(NSPoint(x: frame.maxX - size.width - 16, y: frame.maxY - size.height - 16))
        }
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        content?.focusSearch()
    }
}

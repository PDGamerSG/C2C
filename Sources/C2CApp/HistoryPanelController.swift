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
    private var outsideClickMonitor: Any?

    init(store: ClipStoreProtocol, pasteCoordinator: PasteCoordinator, onSettings: @escaping () -> Void) {
        self.store = store
        self.pasteCoordinator = pasteCoordinator
        self.onSettings = onSettings
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidResignActive), name: NSApplication.didResignActiveNotification, object: NSApp)
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            self?.panel?.orderOut(nil)
        }
    }

    func toggle() {
        if let panel, panel.isVisible { panel.orderOut(nil) }
        else { show() }
    }

    func reloadIfVisible() {
        if panel?.isVisible == true { content?.reload(selection: .keepScrollPosition) }
    }

    func windowDidResignKey(_ notification: Notification) {
        panel?.orderOut(nil)
    }

    @objc private func applicationDidResignActive() {
        panel?.orderOut(nil)
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
            panel.setContentSize(NSSize(width: 400, height: 340))
            self.panel = panel
            self.content = viewController
        }
        guard let panel else { return }
        if panel.isVisible { content?.reload(selection: .keepScrollPosition) }
        else { content?.prepareForOpening() }
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main {
            let frame = screen.visibleFrame
            let size = panel.frame.size
            panel.setFrameOrigin(NSPoint(x: frame.midX - size.width / 2, y: frame.midY - size.height / 2))
        }
        // A nonactivating panel can take keyboard focus without switching apps.
        // Activating here races with key-window changes and can dismiss an opening panel.
        panel.makeKeyAndOrderFront(nil)
        content?.focusSearch()
    }
}

import AppKit

@MainActor
final class HotKeyManager {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    var onPress: (() -> Void)?

    func start() {
        let handler: (NSEvent) -> NSEvent? = { [weak self] event in
            guard event.type == .keyDown, event.keyCode == 9, event.modifierFlags.contains([.command, .shift]) else { return event }
            self?.onPress?()
            return nil
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 9, event.modifierFlags.contains([.command, .shift]) else { return }
            self?.onPress?()
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: handler)
    }

    func stop() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
    }

}

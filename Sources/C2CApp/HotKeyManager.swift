import AppKit

@MainActor
final class HotKeyManager {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private(set) var keyCode: UInt16
    private(set) var modifiers: NSEvent.ModifierFlags
    var onPress: (() -> Void)?

    init(keyCode: UInt16 = 9, modifiers: NSEvent.ModifierFlags = [.command, .shift]) {
        self.keyCode = keyCode
        self.modifiers = modifiers.intersection(Self.relevantModifiers)
    }

    private static let relevantModifiers: NSEvent.ModifierFlags = [.command, .option, .control, .shift]

    func update(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        self.modifiers = modifiers.intersection(Self.relevantModifiers)
        stop()
        start()
    }

    func start() {
        stop()
        let handler: (NSEvent) -> NSEvent? = { [weak self] event in
            guard let self else { return event }
            if event.window?.firstResponder is ShortcutRecorderField { return event }
            guard self.matches(event) else { return event }
            self.onPress?()
            return nil
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.matches(event) else { return }
            self.onPress?()
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: handler)
    }

    func stop() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
    }

    private func matches(_ event: NSEvent) -> Bool {
        event.keyCode == keyCode && event.modifierFlags.intersection(Self.relevantModifiers) == modifiers
    }
}

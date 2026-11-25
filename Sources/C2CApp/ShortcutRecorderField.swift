import AppKit

@MainActor
final class ShortcutRecorderField: NSTextField {
    var onShortcut: ((UInt16, NSEvent.ModifierFlags, String) -> Void)?
    var onRecordingChange: ((Bool) -> Void)?
    private var savedDisplay = ""

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        isEditable = false
        isSelectable = false
        focusRingType = .exterior
        toolTip = "Click, then press a shortcut. Save to apply."
        setAccessibilityLabel("Open clipboard shortcut")
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) { window?.makeFirstResponder(self) }

    override func becomeFirstResponder() -> Bool {
        savedDisplay = stringValue
        stringValue = "Press a shortcut…"
        onRecordingChange?(true)
        return true
    }

    override func resignFirstResponder() -> Bool {
        stringValue = savedDisplay
        onRecordingChange?(false)
        return true
    }

    override func keyDown(with event: NSEvent) {
        guard window?.firstResponder === self else { return }
        if event.keyCode == 53 { window?.makeFirstResponder(nil); return }
        if event.keyCode == 48 { window?.selectNextKeyView(self); return }
        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        guard !modifiers.intersection([.command, .option, .control]).isEmpty, !event.isARepeat else {
            NSSound.beep()
            return
        }
        let description = Self.displayString(for: event, modifiers: modifiers)
        savedDisplay = description
        stringValue = description
        onShortcut?(event.keyCode, modifiers, description)
        window?.makeFirstResponder(nil)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard window?.firstResponder === self else { return false }
        keyDown(with: event)
        return true
    }

    static func displayString(for event: NSEvent, modifiers: NSEvent.ModifierFlags? = nil) -> String {
        let flags = (modifiers ?? event.modifierFlags).intersection([.command, .option, .control, .shift])
        var value = ""
        if flags.contains(.control) { value += "⌃" }
        if flags.contains(.option) { value += "⌥" }
        if flags.contains(.shift) { value += "⇧" }
        if flags.contains(.command) { value += "⌘" }
        let specialKeys: [UInt16: String] = [36: "Return", 49: "Space", 51: "Delete", 76: "Enter", 117: "Forward Delete", 123: "←", 124: "→", 125: "↓", 126: "↑"]
        let key = specialKeys[event.keyCode] ?? event.charactersIgnoringModifiers?.uppercased().first.map(String.init) ?? "Key \(event.keyCode)"
        return value + key
    }
}

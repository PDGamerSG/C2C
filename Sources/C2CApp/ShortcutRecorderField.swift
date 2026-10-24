import AppKit

@MainActor
final class ShortcutRecorderField: NSTextField {
    var onShortcut: ((UInt16, NSEvent.ModifierFlags, String) -> Void)?

    override func keyDown(with event: NSEvent) {
        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        guard !modifiers.isEmpty else {
            NSSound.beep()
            return
        }
        let description = Self.displayString(for: event, modifiers: modifiers)
        stringValue = description
        onShortcut?(event.keyCode, modifiers, description)
        window?.makeFirstResponder(nil)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
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
        let key = event.charactersIgnoringModifiers?.uppercased().first.map(String.init) ?? "Key (event.keyCode)"
        return value + key
    }
}

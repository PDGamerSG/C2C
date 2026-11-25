import AppKit
import Carbon

@MainActor
final class HotKeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var suspended = false
    private var isHeld = false
    private let identifier = EventHotKeyID(signature: 0x43324348, id: UInt32.random(in: 1...UInt32.max))
    private(set) var keyCode: UInt16
    private(set) var modifiers: NSEvent.ModifierFlags
    private(set) var registrationError: String?
    var onPress: (() -> Void)?

    init(keyCode: UInt16 = 9, modifiers: NSEvent.ModifierFlags = [.command, .shift]) {
        self.keyCode = keyCode
        self.modifiers = modifiers.intersection(Self.relevantModifiers)
    }

    private static let relevantModifiers: NSEvent.ModifierFlags = [.command, .option, .control, .shift]

    @discardableResult
    func update(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> Bool {
        let normalized = modifiers.intersection(Self.relevantModifiers)
        guard !normalized.intersection([.command, .option, .control]).isEmpty else {
            registrationError = "Include Control, Option, or Command in the shortcut."
            return false
        }
        if hotKeyRef != nil && self.keyCode == keyCode && self.modifiers == normalized {
            registrationError = nil
            return true
        }
        guard installHandler() else { return false }
        var carbonModifiers: UInt32 = 0
        if normalized.contains(.command) { carbonModifiers |= UInt32(cmdKey) }
        if normalized.contains(.option) { carbonModifiers |= UInt32(optionKey) }
        if normalized.contains(.control) { carbonModifiers |= UInt32(controlKey) }
        if normalized.contains(.shift) { carbonModifiers |= UInt32(shiftKey) }
        var replacement: EventHotKeyRef?
        let status = RegisterEventHotKey(UInt32(keyCode), carbonModifiers, identifier, GetApplicationEventTarget(), OptionBits(kEventHotKeyExclusive), &replacement)
        guard status == noErr else {
            registrationError = status == eventHotKeyExistsErr ?
                "That shortcut is already in use. Choose another combination, or release it in the other app." :
                "macOS could not register this shortcut (error \(status)). Choose another combination."
            return false
        }
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        hotKeyRef = replacement
        self.keyCode = keyCode
        self.modifiers = normalized
        isHeld = false
        registrationError = nil
        return true
    }

    @discardableResult
    func start() -> Bool { update(keyCode: keyCode, modifiers: modifiers) }

    func stop() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
        hotKeyRef = nil
        handlerRef = nil
        isHeld = false
    }

    func setRecording(_ recording: Bool) {
        suspended = recording
        if recording { stop() }
        else { start() }
    }

    private func installHandler() -> Bool {
        if handlerRef != nil { return true }
        let events = [EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
                      EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))]
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            return MainActor.assumeIsolated {
                let manager = Unmanaged<HotKeyManager>.fromOpaque(context).takeUnretainedValue()
                var eventID = EventHotKeyID()
                let result = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &eventID)
                guard result == noErr, eventID.signature == manager.identifier.signature, eventID.id == manager.identifier.id else { return OSStatus(eventNotHandledErr) }
                if GetEventKind(event) == UInt32(kEventHotKeyReleased) {
                    manager.isHeld = false
                } else if !manager.suspended && !manager.isHeld {
                    manager.isHeld = true
                    manager.onPress?()
                }
                return noErr
            }
        }, events.count, events, Unmanaged.passUnretained(self).toOpaque(), &handlerRef)
        if status != noErr { registrationError = "Unable to listen for the shortcut (error \(status))." }
        return status == noErr
    }
}

import AppKit
import C2CCore
import CoreGraphics

@MainActor
final class PasteCoordinator {
    private let pasteboard: NSPasteboard
    var beforePaste: (() -> Void)?

    init(pasteboard: NSPasteboard = .general) { self.pasteboard = pasteboard }

    func paste(clip: Clip, plainText: Bool = false) {
        beforePaste?()
        pasteboard.clearContents()
        if plainText, let text = clip.contentText {
            pasteboard.setString(text, forType: .string)
        } else {
            for payload in clip.payloads {
                switch payload.kind {
                case .text: pasteboard.setData(payload.data, forType: NSPasteboard.PasteboardType("public.utf8-plain-text"))
                case .html: pasteboard.setData(payload.data, forType: .html)
                case .richText: pasteboard.setData(payload.data, forType: .rtf)
                case .image: pasteboard.setData(payload.data, forType: .png)
                case .file: _ = pasteboard.writeObjects(payload.fileURLs as [NSURL])
                case .custom: pasteboard.setData(payload.data, forType: NSPasteboard.PasteboardType(payload.uti))
                }
            }
        }
        sendPasteKeystroke()
    }

    private func sendPasteKeystroke() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}

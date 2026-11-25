import AppKit
import C2CCore

@MainActor
final class ClipboardMonitor: NSObject {
    private let pasteboard: NSPasteboard
    private let service: ClipboardService
    private let sourceBundleID: () -> String?
    private var timer: Timer?
    private var lastChangeCount: Int
    private var shouldIgnoreNextChange = false
    var onChange: (() -> Void)?

    init(pasteboard: NSPasteboard = .general, service: ClipboardService, sourceBundleID: @escaping () -> String?) {
        self.pasteboard = pasteboard
        self.service = service
        self.sourceBundleID = sourceBundleID
        self.lastChangeCount = pasteboard.changeCount
        super.init()
    }

    func start() {
        timer?.invalidate()
        let timer = Timer(timeInterval: 0.25, target: self, selector: #selector(pollTimer), userInfo: nil, repeats: true)
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func stop() { timer?.invalidate(); timer = nil }

    func ignoreNextChange() { shouldIgnoreNextChange = true }

    @objc private func pollTimer() { poll() }

    private func poll() {
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount
        if shouldIgnoreNextChange {
            shouldIgnoreNextChange = false
            return
        }
        let payloads = readPayloads()
        if service.ingest(payloads: payloads, sourceBundleID: sourceBundleID()) != nil { onChange?() }
    }

    private func readPayloads() -> [ClipPayload] {
        var payloads: [ClipPayload] = []
        let types = Set(pasteboard.types ?? [])
        if types.contains(.string), let text = pasteboard.string(forType: .string), !text.isEmpty {
            payloads.append(.text(text))
        }
        if types.contains(.html), let html = pasteboard.data(forType: .html) {
            payloads.append(ClipPayload(kind: .html, uti: NSPasteboard.PasteboardType.html.rawValue, data: html))
        }
        if types.contains(.rtf), let rtf = pasteboard.data(forType: .rtf) {
            payloads.append(ClipPayload(kind: .richText, uti: NSPasteboard.PasteboardType.rtf.rawValue, data: rtf))
        }
        for type in [NSPasteboard.PasteboardType.png, .tiff, .init("public.jpeg"), .init("public.heic")] where types.contains(type) {
            guard let data = pasteboard.data(forType: type) else { continue }
            let png = type == .png && NSImage(data: data) != nil ? data : Self.pngData(from: data)
            if let png {
                payloads.append(ClipPayload(kind: .image, uti: "public.png", data: png))
                break
            }
        }
        if types.contains(.fileURL), let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], !urls.isEmpty {
            payloads.append(.file(urls: urls))
        }
        return payloads
    }

    private static func pngData(from data: Data) -> Data? {
        guard let image = NSImage(data: data), let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}

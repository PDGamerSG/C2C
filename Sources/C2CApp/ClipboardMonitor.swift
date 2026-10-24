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
        _ = service.ingest(payloads: payloads, sourceBundleID: sourceBundleID())
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
        if types.contains(.tiff), let image = pasteboard.data(forType: .tiff), let png = Self.pngData(fromTIFF: image) {
            payloads.append(ClipPayload(kind: .image, uti: "public.png", data: png))
        }
        if types.contains(.fileURL), let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], !urls.isEmpty {
            payloads.append(.file(urls: urls))
        }
        return payloads
    }

    private static func pngData(fromTIFF data: Data) -> Data? {
        guard let image = NSImage(data: data), let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}

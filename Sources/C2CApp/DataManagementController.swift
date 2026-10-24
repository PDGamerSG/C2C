import AppKit
import C2CCore

@MainActor
final class DataManagementController {
    private let store: ClipStoreProtocol

    init(store: ClipStoreProtocol) { self.store = store }

    func export(from window: NSWindow?) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "C2C-clipboard.json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? ClipArchive.export(clips: store.list()).write(to: url, options: .atomic)
    }

    func `import`(from window: NSWindow?) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url, let data = try? Data(contentsOf: url), let clips = try? ClipArchive.import(data: data) else { return }
        clips.forEach(store.upsert)
    }
}

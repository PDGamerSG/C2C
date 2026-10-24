import Foundation
import C2CCore

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError("SMOKE FAILED: \(message)") }
}

let store = InMemoryClipStore(retentionLimit: 2)
let service = ClipboardService(store: store, settings: AppSettings(retentionLimit: 2))
let first = service.ingest(payloads: [.text("first")])!
store.setPinned(first.id, pinned: true)
_ = service.ingest(payloads: [.text("second")])
_ = service.ingest(payloads: [.text("third")])
check(store.list().count == 2, "retention limit")
check(store.list().contains(where: { $0.contentText == "first" && $0.isPinned }), "pinned retention")
check(store.search("THIRD", groupName: nil).count == 1, "case-insensitive search")
let archive = try ClipArchive.export(clips: store.list())
let imported = try ClipArchive.import(data: archive)
check(imported == store.list(), "archive round trip")
let url = FileManager.default.temporaryDirectory.appendingPathComponent("c2c-smoke-\(UUID().uuidString).json")
let fileStore = FileClipStore(url: url)
fileStore.upsert(Clip(payloads: [.text("persisted")]))
check(FileClipStore(url: url).list().first?.contentText == "persisted", "file persistence")
try? FileManager.default.removeItem(at: url)
print("C2C smoke checks passed")

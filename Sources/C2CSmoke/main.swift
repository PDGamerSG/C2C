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
let benchmarkStore = InMemoryClipStore(retentionLimit: 500)
let benchmarkStart = DispatchTime.now().uptimeNanoseconds
for index in 0..<2_000 { benchmarkStore.upsert(Clip(payloads: [.text("benchmark-\(index)")])) }
let benchmarkMilliseconds = Double(DispatchTime.now().uptimeNanoseconds - benchmarkStart) / 1_000_000
check(benchmarkStore.list().count == 500, "benchmark retention")
print(String(format: "Indexed store benchmark: %.1f ms for 2,000 inserts", benchmarkMilliseconds))
let url = FileManager.default.temporaryDirectory.appendingPathComponent("c2c-smoke-\(UUID().uuidString).json")
let fileStore = FileClipStore(url: url)
fileStore.upsert(Clip(payloads: [.text("persisted")]))
fileStore.flush()
check(FileClipStore(url: url).list().first?.contentText == "persisted", "file persistence")
try? FileManager.default.removeItem(at: url)
let customSettings = AppSettings(hotKeyKeyCode: 0, hotKeyModifiers: 1_048_576, hotKeyDescription: "⌘A")
let encodedSettings = try JSONEncoder().encode(customSettings)
let decodedSettings = try JSONDecoder().decode(AppSettings.self, from: encodedSettings)
check(decodedSettings == customSettings, "shortcut settings round trip")
let legacySettings = Data("{\"retentionLimit\":25}".utf8)
let decodedLegacy = try JSONDecoder().decode(AppSettings.self, from: legacySettings)
check(decodedLegacy.hotKeyDescription == "⌘⇧V", "legacy shortcut defaults")
print("C2C smoke checks passed")

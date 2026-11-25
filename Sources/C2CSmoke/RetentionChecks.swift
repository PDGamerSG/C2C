import Foundation
import C2CCore

private final class RetentionClock {
    var date = Date(timeIntervalSince1970: 1_800_000_000)
}

func runRetentionChecks() throws {
    let now = Date()
    let day: TimeInterval = 86_400
    let pinned = Clip(createdAt: now.addingTimeInterval(-90 * day), isPinned: true, payloads: [.text("keep forever")])
    let expired = Clip(createdAt: now.addingTimeInterval(-31 * day), updatedAt: now, payloads: [.text("expired despite recent use")])
    let recent = Clip(createdAt: now.addingTimeInterval(-29 * day), payloads: [.text("still recent")])
    let store = InMemoryClipStore(clips: [pinned, expired, recent])

    store.delete(pinned.id)
    check(store.list().contains { $0.id == pinned.id }, "pinned messages cannot be deleted")
    check(!store.list().contains { $0.id == expired.id }, "30-day expiry uses original creation date")
    check(store.list().contains { $0.id == recent.id }, "recent messages survive cleanup")
    check(store.search("expired").isEmpty, "expired messages disappear from search")
    check(store.stats().storedClips == 2, "cleanup updates stored count")

    store.upsert(Clip(payloads: pinned.payloads))
    check(store.list().first?.id == pinned.id && store.list().first?.isPinned == true, "copying a pinned message preserves its identity and pin")
    store.retentionLimit = 1
    check(store.list().map(\.id) == [pinned.id], "count limits preserve old pins")
    store.clear()
    check(store.list().map(\.id) == [pinned.id], "clearing history preserves pins")
    store.setPinned(pinned.id, pinned: false)
    check(store.list().isEmpty, "unpinning an expired message makes it eligible for cleanup")

    let deletable = Clip(payloads: [.text("unpin before deleting")])
    store.upsert(deletable)
    store.setPinned(deletable.id, pinned: true)
    store.setPinned(deletable.id, pinned: false)
    store.delete(deletable.id)
    check(store.list().isEmpty, "unpinned messages can be deleted")

    let clock = RetentionClock()
    let boundary = Clip(createdAt: clock.date.addingTimeInterval(-30 * day + 1), payloads: [.text("boundary")])
    let timedStore = InMemoryClipStore(clips: [boundary, pinned], now: { clock.date })
    check(timedStore.list().contains { $0.id == boundary.id }, "message survives one second before expiry")
    clock.date.addTimeInterval(1)
    check(timedStore.removeExpired() == 1, "message expires at exactly 30 days without a new copy")
    check(timedStore.removeExpired() == 0, "repeated cleanup is idempotent")
    check(timedStore.clip(matchingContentIdentity: boundary.contentIdentity) == nil, "cleanup removes the deduplication index")
    let recopied = Clip(createdAt: clock.date, payloads: boundary.payloads)
    timedStore.upsert(recopied)
    check(timedStore.list().contains { $0.id == recopied.id }, "expired content can be captured again")

    let importStore = InMemoryClipStore(clips: [recent])
    var importedPin = recent
    importedPin.isPinned = true
    importStore.upsert(importedPin)
    check(importStore.list().first?.isPinned == true, "importing a pin protects an existing duplicate")

    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("c2c-retention-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("clipboard.json")
    // Match the existing version-1 file format to exercise upgrades without a migration.
    struct LegacySnapshot: Codable {
        var version = 1
        var clips: [Clip]
        var totalCopies = 7
        var totalPastes = 3
    }
    try JSONEncoder().encode(LegacySnapshot(clips: [pinned, expired, recent])).write(to: url)
    let restored = FileClipStore(url: url)
    restored.flush()
    let persisted = try JSONDecoder().decode(LegacySnapshot.self, from: Data(contentsOf: url))
    check(Set(persisted.clips.map(\.id)) == [pinned.id, recent.id], "startup cleanup removes expired payloads from disk")
    check(restored.stats().totalCopies == 7 && restored.stats().totalPastes == 3, "cleanup preserves lifetime statistics")
    restored.delete(pinned.id)
    restored.setPinned(recent.id, pinned: true)
    restored.clear()
    restored.flush()
    check(FileClipStore(url: url).list().allSatisfy(\.isPinned), "pins persist through restart and clear")
    check(FileClipStore(url: url).list().count == 2, "protected delete retains the saved pin")

    let timedURL = directory.appendingPathComponent("timed.json")
    let timedFile = FileClipStore(url: timedURL, now: { clock.date })
    timedFile.upsert(Clip(createdAt: clock.date, payloads: [.text("expire while running")]))
    timedFile.upsert(Clip(createdAt: clock.date, isPinned: true, payloads: [.text("persist while running")]))
    clock.date.addTimeInterval(31 * day)
    check(timedFile.removeExpired() == 1, "running file store expires history")
    timedFile.flush()
    let timedSnapshot = try JSONDecoder().decode(LegacySnapshot.self, from: Data(contentsOf: timedURL))
    check(timedSnapshot.clips.map(\.contentText) == ["persist while running"], "periodic cleanup persists only the pin")
    print("Pin protection and 30-day retention checks passed")
}

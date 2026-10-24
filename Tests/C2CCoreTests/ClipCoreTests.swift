import XCTest
@testable import C2CCore

final class ClipCoreTests: XCTestCase {
    func testSamePayloadProducesSameIdentity() throws {
        let payload = ClipPayload(kind: .text, uti: "public.utf8-plain-text", data: Data("hello".utf8))
        let first = Clip(payloads: [payload], sourceBundleID: "com.example.editor")
        let second = Clip(payloads: [payload], sourceBundleID: "com.example.editor")
        XCTAssertEqual(first.contentIdentity, second.contentIdentity)
    }

    func testSearchMatchesDescriptionAndPayloadTextCaseInsensitively() throws {
        let clip = Clip(payloads: [ClipPayload(kind: .text, uti: "public.utf8-plain-text", data: Data("Release checklist".utf8))], description: "Deploy notes")
        XCTAssertTrue(ClipSearch.matches("CHECKLIST", clip: clip))
        XCTAssertTrue(ClipSearch.matches("deploy", clip: clip))
        XCTAssertFalse(ClipSearch.matches("missing", clip: clip))
    }

    func testStoreDeduplicatesAndRetainsPinnedItemsWhenCapping() throws {
        let store = InMemoryClipStore(retentionLimit: 2)
        let first = Clip(payloads: [ClipPayload.text("first")])
        let duplicate = Clip(id: UUID(), createdAt: first.createdAt.addingTimeInterval(1), payloads: first.payloads)
        let second = Clip(payloads: [ClipPayload.text("second")])
        let third = Clip(payloads: [ClipPayload.text("third")])
        store.upsert(first)
        store.setPinned(first.id, pinned: true)
        store.upsert(duplicate)
        store.upsert(second)
        store.upsert(third)
        let clips = store.list()
        XCTAssertEqual(clips.count, 2)
        XCTAssertTrue(clips.contains { $0.id == first.id && $0.isPinned })
        XCTAssertTrue(clips.contains { $0.contentText == "third" })
    }

    func testArchiveRoundTripPreservesClipMetadataAndPayload() throws {
        let original = Clip(payloads: [ClipPayload.text("archive me")], description: "A note", isPinned: true, groupName: "Work")
        let data = try ClipArchive.export(clips: [original])
        let imported = try ClipArchive.import(data: data)
        XCTAssertEqual(imported, [original])
    }
}

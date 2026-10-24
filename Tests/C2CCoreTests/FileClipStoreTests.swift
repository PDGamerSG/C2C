import XCTest
@testable import C2CCore

final class FileClipStoreTests: XCTestCase {
    func testFileStoreRoundTrip() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = FileClipStore(url: url)
        store.upsert(Clip(payloads: [.text("persisted")]))
        XCTAssertEqual(FileClipStore(url: url).list().first?.contentText, "persisted")
    }

    func testExcludedSourceDoesNotIngest() {
        let store = InMemoryClipStore()
        let service = ClipboardService(store: store, settings: AppSettings(excludedBundleIDs: ["com.secret.app"]))
        XCTAssertNil(service.ingest(payloads: [.text("secret")], sourceBundleID: "com.secret.app"))
        XCTAssertTrue(store.list().isEmpty)
    }
}

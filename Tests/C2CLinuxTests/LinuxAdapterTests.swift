import Foundation
import XCTest
import C2CCore
@testable import C2CLinuxSupport

final class LinuxAdapterTests: XCTestCase {
    func testSettingsRoundTripUsesXDGConfigDirectory() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = LinuxSettingsStore(configHome: root)
        var settings = AppSettings(retentionLimit: 37, plainTextPasteByDefault: true, appearance: .dark)
        settings.excludedBundleIDs = ["org.example.Secret"]
        try store.save(settings)

        XCTAssertEqual(store.load(), settings)
        XCTAssertEqual(store.url.path, root.appendingPathComponent("c2c/settings.json").path)
    }

    func testMissingClipboardHelpersAreReportedWithoutThrowing() {
        let adapter = LinuxClipboardAdapter(
            environment: [:],
            executableLookup: { _ in nil }
        )

        XCTAssertNil(adapter.backend)
        XCTAssertEqual(adapter.readPayloads(), [])
    }

    func testWaylandPNGClipboardBecomesImagePayload() {
        let png = Data([0x89, 0x50, 0x4e, 0x47])
        let adapter = LinuxClipboardAdapter(
            environment: ["WAYLAND_DISPLAY": "wayland-1"],
            executableLookup: { _ in "/usr/bin/fake" },
            commandRunner: { _, arguments in
                arguments.contains("image/png") ? png : Data("captured".utf8)
            }
        )

        let payloads = adapter.readPayloads()
        XCTAssertTrue(payloads.contains { $0.kind == .image && $0.uti == "image/png" && $0.data == png })
    }
}

import Foundation
import C2CCore
import C2CLinuxSupport
import C2CLinuxGTK

public final class LinuxApplication {
    public struct SettingsPatch: Decodable {
        public let retentionLimit: Int?
        public let appearance: AppAppearance?
    }
    private let store: FileClipStore
    private let archiveURL: URL
    private let service: ClipboardService
    private let clipboard: LinuxClipboardAdapter
    private let paste: LinuxPasteAdapter
    private let settingsStore: LinuxSettingsStore
    private var settings: AppSettings
    private var lastIdentity: String?
    private var pollTimer: DispatchSourceTimer?

    public init(dataHome: URL? = nil, configHome: URL? = nil) {
        let dataRoot = dataHome ?? Self.defaultDataHome()
        settingsStore = LinuxSettingsStore(configHome: configHome)
        settings = settingsStore.load()
        let directory = dataRoot.appendingPathComponent("c2c", isDirectory: true)
        archiveURL = directory.appendingPathComponent("archive.json")
        store = FileClipStore(url: directory.appendingPathComponent("clipboard.json"), retentionLimit: settings.retentionLimit)
        service = ClipboardService(store: store, settings: settings)
        clipboard = LinuxClipboardAdapter()
        paste = LinuxPasteAdapter(clipboard: clipboard)
    }

    public func start() {
        pollTimer = DispatchSource.makeTimerSource(queue: .main)
        pollTimer?.schedule(deadline: .now(), repeating: .milliseconds(250))
        pollTimer?.setEventHandler { [weak self] in self?.pollClipboard() }
        pollTimer?.resume()
        refresh(query: "")
    }

    public func stop() {
        pollTimer?.cancel()
        pollTimer = nil
        store.flush()
    }

    public func refresh(query: String) {
        let rows = store.search(query, groupName: nil).map { clip in
            let title = clip.displayTitle.replacingOccurrences(of: "\t", with: " ").replacingOccurrences(of: "\n", with: " ")
            return "\(clip.id.uuidString)\t\(clip.isPinned ? "1" : "0")\t\(title)"
        }.joined(separator: "\n")
        c2c_linux_set_rows(rows)
        c2c_linux_set_status("\(store.list().count) clipboard items")
    }

    public func handleSearch(_ query: String) { refresh(query: query) }

    public func activate(id: String) {
        guard let clip = clip(id: id) else { return }
        do {
            try paste.write(clip.payloads)
            try paste.sendPaste()
            store.recordPaste(clip.id)
            refresh(query: "")
        } catch {
            c2c_linux_set_status(error.localizedDescription)
        }
    }

    public func togglePin(id: String) {
        guard let clip = clip(id: id) else { return }
        store.setPinned(clip.id, pinned: !clip.isPinned)
        refresh(query: "")
    }

    public func delete(id: String) {
        guard let uuid = UUID(uuidString: id) else { return }
        store.delete(uuid)
        refresh(query: "")
    }

    public func clear() {
        store.clear()
        refresh(query: "")
    }

    public func save(settings updated: AppSettings) {
        settings = updated
        service.update(settings: updated)
        do {
            try settingsStore.save(updated)
            c2c_linux_set_status("Settings saved")
        } catch {
            c2c_linux_set_status(error.localizedDescription)
        }
    }

    public func updateSettings(_ patch: SettingsPatch) {
        var updated = settings
        if let retentionLimit = patch.retentionLimit { updated.retentionLimit = max(1, retentionLimit) }
        if let appearance = patch.appearance { updated.appearance = appearance }
        save(settings: updated)
    }

    public func exportArchive() {
        do {
            let data = try ClipArchive.export(clips: store.list())
            try FileManager.default.createDirectory(at: archiveURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: archiveURL, options: .atomic)
            c2c_linux_set_status("Archive exported to \(archiveURL.path)")
        } catch {
            c2c_linux_set_status(error.localizedDescription)
        }
    }

    public func importArchive() {
        do {
            let clips = try ClipArchive.import(data: Data(contentsOf: archiveURL))
            clips.forEach(store.upsert)
            store.flush()
            refresh(query: "")
            c2c_linux_set_status("Archive imported from \(archiveURL.path)")
        } catch {
            c2c_linux_set_status("Import unavailable at \(archiveURL.path)")
        }
    }

    public func selfTest() throws {
        let testStore = InMemoryClipStore(retentionLimit: 2)
        let testService = ClipboardService(store: testStore, settings: AppSettings(retentionLimit: 2))
        let first = testService.ingest(payloads: [.text("first")])!
        testStore.setPinned(first.id, pinned: true)
        _ = testService.ingest(payloads: [.text("second")])
        _ = testService.ingest(payloads: [.text("third")])
        guard testStore.list().count == 2, testStore.list().contains(where: { $0.isPinned }) else {
            throw NSError(domain: "C2CLinux", code: 1, userInfo: [NSLocalizedDescriptionKey: "Linux core self-test failed"])
        }
        let archive = try ClipArchive.export(clips: testStore.list())
        guard try ClipArchive.import(data: archive) == testStore.list() else {
            throw NSError(domain: "C2CLinux", code: 2, userInfo: [NSLocalizedDescriptionKey: "Linux archive self-test failed"])
        }
    }

    private func pollClipboard() {
        _ = store.removeExpired()
        let payloads = clipboard.readPayloads()
        guard !payloads.isEmpty else { return }
        let identity = Clip(payloads: payloads).contentIdentity
        guard identity != lastIdentity else { return }
        lastIdentity = identity
        _ = service.ingest(payloads: payloads)
        refresh(query: "")
    }

    private func clip(id: String) -> Clip? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        return store.list().first(where: { $0.id == uuid })
    }

    private static func defaultDataHome() -> URL {
        if let configured = ProcessInfo.processInfo.environment["XDG_DATA_HOME"], !configured.isEmpty {
            return URL(fileURLWithPath: configured, isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".local/share", isDirectory: true)
    }
}

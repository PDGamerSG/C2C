import Foundation

public final class FileClipStore: ClipStoreProtocol {
    private struct Snapshot: Codable {
        let version: Int
        let clips: [Clip]
        let totalCopies: Int
        let totalPastes: Int
    }

    private let fileURL: URL
    private let memory: InMemoryClipStore
    private var totalCopies = 0
    private var totalPastes = 0

    public var retentionLimit: Int {
        get { memory.retentionLimit }
        set { memory.retentionLimit = newValue; persist() }
    }

    public init(url: URL, retentionLimit: Int = 500) {
        self.fileURL = url
        let snapshot: Snapshot?
        if let data = try? Data(contentsOf: url) {
            snapshot = try? JSONDecoder().decode(Snapshot.self, from: data)
        } else {
            snapshot = nil
        }
        self.memory = InMemoryClipStore(clips: snapshot?.clips ?? [], retentionLimit: max(1, retentionLimit))
        self.totalCopies = snapshot?.totalCopies ?? 0
        self.totalPastes = snapshot?.totalPastes ?? 0
    }

    public func list() -> [Clip] { memory.list() }
    public func search(_ query: String, groupName: String? = nil) -> [Clip] { memory.search(query, groupName: groupName) }
    public func upsert(_ clip: Clip) { memory.upsert(clip); totalCopies += 1; persist() }
    public func delete(_ id: UUID) { memory.delete(id); persist() }
    public func setPinned(_ id: UUID, pinned: Bool) { memory.setPinned(id, pinned: pinned); persist() }
    public func setGroup(_ id: UUID, groupName: String?) { memory.setGroup(id, groupName: groupName); persist() }
    public func recordPaste(_ id: UUID) { memory.recordPaste(id); totalPastes += 1; persist() }
    public func clear(includePinned: Bool = false) { memory.clear(includePinned: includePinned); persist() }
    public func stats() -> ClipStats {
        var value = memory.stats()
        value.totalCopies = totalCopies
        value.totalPastes = totalPastes
        return value
    }

    private func persist() {
        let snapshot = Snapshot(version: 1, clips: memory.list(), totalCopies: totalCopies, totalPastes: totalPastes)
        do {
            let data = try JSONEncoder().encode(snapshot)
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let temporaryURL = fileURL.appendingPathExtension("tmp")
            try data.write(to: temporaryURL, options: .atomic)
            if FileManager.default.fileExists(atPath: fileURL.path) { try FileManager.default.removeItem(at: fileURL) }
            try FileManager.default.moveItem(at: temporaryURL, to: fileURL)
        } catch {
            // Persistence errors are isolated from clipboard capture; a later mutation retries.
        }
    }
}

import Foundation

public final class FileClipStore: ClipStoreProtocol, @unchecked Sendable {
    private struct Snapshot: Codable {
        let version: Int
        let clips: [Clip]
        let totalCopies: Int
        let totalPastes: Int
    }

    private let fileURL: URL
    private let memory: InMemoryClipStore
    private let persistenceQueue = DispatchQueue(label: "com.c2c.clipboard.persistence", qos: .utility)
    private let persistenceLock = NSLock()
    private var pendingSnapshot: Snapshot?
    private var writeScheduled = false
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

    public func clip(matchingContentIdentity identity: String) -> Clip? { memory.clip(matchingContentIdentity: identity) }
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

    /// Waits for the latest queued snapshot to reach disk. Call during orderly shutdown or tests.
    public func flush() {
        persistenceQueue.sync { flushPendingSnapshots() }
    }

    private func persist() {
        let snapshot = Snapshot(version: 1, clips: memory.list(), totalCopies: totalCopies, totalPastes: totalPastes)
        var shouldSchedule = false
        persistenceLock.lock()
        pendingSnapshot = snapshot
        if !writeScheduled {
            writeScheduled = true
            shouldSchedule = true
        }
        persistenceLock.unlock()
        if shouldSchedule { persistenceQueue.async { [weak self] in self?.flushPendingSnapshots() } }
    }

    private func flushPendingSnapshots() {
        while true {
            persistenceLock.lock()
            let snapshot = pendingSnapshot
            pendingSnapshot = nil
            if snapshot == nil { writeScheduled = false }
            persistenceLock.unlock()
            guard let snapshot else { return }
            write(snapshot)
        }
    }

    private func write(_ snapshot: Snapshot) {
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

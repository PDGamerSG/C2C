import Foundation

public struct ClipStats: Codable, Equatable, Sendable {
    public var totalCopies: Int
    public var totalPastes: Int
    public var storedClips: Int
    public var pinnedClips: Int

    public init(totalCopies: Int = 0, totalPastes: Int = 0, storedClips: Int = 0, pinnedClips: Int = 0) {
        self.totalCopies = totalCopies
        self.totalPastes = totalPastes
        self.storedClips = storedClips
        self.pinnedClips = pinnedClips
    }
}

public protocol ClipStoreProtocol: AnyObject {
    var retentionLimit: Int { get set }
    func list() -> [Clip]
    func search(_ query: String, groupName: String?) -> [Clip]
    func upsert(_ clip: Clip)
    func delete(_ id: UUID)
    func setPinned(_ id: UUID, pinned: Bool)
    func setGroup(_ id: UUID, groupName: String?)
    func recordPaste(_ id: UUID)
    func clear(includePinned: Bool)
    func stats() -> ClipStats
}

public final class InMemoryClipStore: ClipStoreProtocol {
    private var clipsByID: [UUID: Clip]
    private var copies = 0
    private var pastes = 0
    public var retentionLimit: Int { didSet { enforceRetention() } }

    public init(clips: [Clip] = [], retentionLimit: Int = 500) {
        self.clipsByID = Dictionary(uniqueKeysWithValues: clips.map { ($0.id, $0) })
        self.retentionLimit = max(1, retentionLimit)
        enforceRetention()
    }

    public func list() -> [Clip] {
        clipsByID.values.sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned }
            return $0.updatedAt > $1.updatedAt
        }
    }

    public func search(_ query: String, groupName: String? = nil) -> [Clip] {
        list().filter { clip in
            (groupName == nil || clip.groupName == groupName) && ClipSearch.matches(query, clip: clip)
        }
    }

    public func upsert(_ clip: Clip) {
        copies += 1
        if let existing = clipsByID.values.first(where: { $0.contentIdentity == clip.contentIdentity }) {
            var merged = clip
            merged = Clip(id: existing.id, createdAt: existing.createdAt, updatedAt: Date(), pasteCount: existing.pasteCount, isPinned: existing.isPinned, groupName: existing.groupName, sourceBundleID: clip.sourceBundleID ?? existing.sourceBundleID, payloads: clip.payloads, description: clip.description ?? existing.description)
            clipsByID[existing.id] = merged
        } else {
            clipsByID[clip.id] = clip
        }
        enforceRetention()
    }

    public func delete(_ id: UUID) { clipsByID.removeValue(forKey: id) }

    public func setPinned(_ id: UUID, pinned: Bool) {
        guard var clip = clipsByID[id] else { return }
        clip.isPinned = pinned
        clip.updatedAt = Date()
        clipsByID[id] = clip
        enforceRetention()
    }

    public func setGroup(_ id: UUID, groupName: String?) {
        guard var clip = clipsByID[id] else { return }
        clip.groupName = groupName
        clip.updatedAt = Date()
        clipsByID[id] = clip
    }

    public func recordPaste(_ id: UUID) {
        guard var clip = clipsByID[id] else { return }
        clip.pasteCount += 1
        clip.updatedAt = Date()
        clipsByID[id] = clip
        pastes += 1
    }

    public func clear(includePinned: Bool = false) {
        if includePinned { clipsByID.removeAll() }
        else { clipsByID = clipsByID.filter { $0.value.isPinned } }
    }

    public func stats() -> ClipStats {
        ClipStats(totalCopies: copies, totalPastes: pastes, storedClips: clipsByID.count, pinnedClips: clipsByID.values.filter(\.isPinned).count)
    }

    private func enforceRetention() {
        let pinned = clipsByID.values.filter(\.isPinned)
        let unpinned = clipsByID.values.filter { !$0.isPinned }.sorted { $0.updatedAt > $1.updatedAt }
        let keepUnpinned = max(0, retentionLimit - pinned.count)
        let keepIDs = Set(pinned.map(\.id) + unpinned.prefix(keepUnpinned).map(\.id))
        clipsByID = clipsByID.filter { keepIDs.contains($0.key) }
    }
}

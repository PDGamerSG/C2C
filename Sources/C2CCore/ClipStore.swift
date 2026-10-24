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

public extension ClipStoreProtocol {
    func clip(matchingContentIdentity identity: String) -> Clip? {
        list().first { $0.contentIdentity == identity }
    }
}

public final class InMemoryClipStore: ClipStoreProtocol {
    private var clipsByID: [UUID: Clip]
    private var idByContentIdentity: [String: UUID]
    private var sortedCache: [Clip]?
    private var copies = 0
    private var pastes = 0
    public var retentionLimit: Int {
        didSet {
            let normalized = max(1, retentionLimit)
            if retentionLimit != normalized { retentionLimit = normalized; return }
            enforceRetention()
        }
    }

    public init(clips: [Clip] = [], retentionLimit: Int = 500) {
        self.clipsByID = Dictionary(uniqueKeysWithValues: clips.map { ($0.id, $0) })
        self.idByContentIdentity = Dictionary(uniqueKeysWithValues: clips.map { ($0.contentIdentity, $0.id) })
        self.sortedCache = nil
        self.retentionLimit = max(1, retentionLimit)
        enforceRetention()
    }

    public func clip(matchingContentIdentity identity: String) -> Clip? {
        guard let id = idByContentIdentity[identity] else { return nil }
        return clipsByID[id]
    }

    public func list() -> [Clip] {
        if let sortedCache { return sortedCache }
        let sorted = clipsByID.values.sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned }
            return $0.updatedAt > $1.updatedAt
        }
        sortedCache = sorted
        return sorted
    }

    public func search(_ query: String, groupName: String? = nil) -> [Clip] {
        list().filter { clip in
            (groupName == nil || clip.groupName == groupName) && ClipSearch.matches(query, clip: clip)
        }
    }

    public func upsert(_ clip: Clip) {
        copies += 1
        if let existingID = idByContentIdentity[clip.contentIdentity], let existing = clipsByID[existingID] {
            let merged = Clip(
                id: existing.id,
                createdAt: existing.createdAt,
                updatedAt: Date(),
                pasteCount: existing.pasteCount,
                isPinned: existing.isPinned,
                groupName: existing.groupName,
                sourceBundleID: clip.sourceBundleID ?? existing.sourceBundleID,
                payloads: clip.payloads,
                description: clip.description ?? existing.description
            )
            clipsByID[existingID] = merged
        } else {
            clipsByID[clip.id] = clip
            idByContentIdentity[clip.contentIdentity] = clip.id
        }
        invalidateSortedCache()
        enforceRetention()
    }

    public func delete(_ id: UUID) {
        guard let clip = clipsByID.removeValue(forKey: id) else { return }
        idByContentIdentity.removeValue(forKey: clip.contentIdentity)
        invalidateSortedCache()
    }

    public func setPinned(_ id: UUID, pinned: Bool) {
        guard var clip = clipsByID[id], clip.isPinned != pinned else { return }
        clip.isPinned = pinned
        clip.updatedAt = Date()
        clipsByID[id] = clip
        invalidateSortedCache()
        enforceRetention()
    }

    public func setGroup(_ id: UUID, groupName: String?) {
        guard var clip = clipsByID[id], clip.groupName != groupName else { return }
        clip.groupName = groupName
        clip.updatedAt = Date()
        clipsByID[id] = clip
        invalidateSortedCache()
    }

    public func recordPaste(_ id: UUID) {
        guard var clip = clipsByID[id] else { return }
        clip.pasteCount += 1
        clip.updatedAt = Date()
        clipsByID[id] = clip
        pastes += 1
        invalidateSortedCache()
    }

    public func clear(includePinned: Bool = false) {
        if includePinned {
            clipsByID.removeAll(keepingCapacity: true)
            idByContentIdentity.removeAll(keepingCapacity: true)
        } else {
            let retained = clipsByID.values.filter(\.isPinned)
            clipsByID = Dictionary(uniqueKeysWithValues: retained.map { ($0.id, $0) })
            idByContentIdentity = Dictionary(uniqueKeysWithValues: retained.map { ($0.contentIdentity, $0.id) })
        }
        invalidateSortedCache()
    }

    public func stats() -> ClipStats {
        ClipStats(totalCopies: copies, totalPastes: pastes, storedClips: clipsByID.count, pinnedClips: clipsByID.values.reduce(into: 0) { $0 += $1.isPinned ? 1 : 0 })
    }

    private func enforceRetention() {
        guard clipsByID.count > retentionLimit else { return }
        var removedAny = false
        while clipsByID.count > retentionLimit {
            guard let oldestUnpinned = clipsByID.values.filter({ !$0.isPinned }).min(by: { $0.updatedAt < $1.updatedAt }) else { break }
            clipsByID.removeValue(forKey: oldestUnpinned.id)
            idByContentIdentity.removeValue(forKey: oldestUnpinned.contentIdentity)
            removedAny = true
        }
        if removedAny { invalidateSortedCache() }
    }

    private func invalidateSortedCache() { sortedCache = nil }
}

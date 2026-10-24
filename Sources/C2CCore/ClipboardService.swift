import Foundation

public final class ClipboardService {
    private let store: ClipStoreProtocol
    private var settings: AppSettings

    public init(store: ClipStoreProtocol, settings: AppSettings = AppSettings()) {
        self.store = store
        self.settings = settings
        store.retentionLimit = settings.retentionLimit
    }

    public func update(settings: AppSettings) {
        self.settings = settings
        store.retentionLimit = settings.retentionLimit
    }

    @discardableResult
    public func ingest(payloads: [ClipPayload], sourceBundleID: String? = nil, description: String? = nil) -> Clip? {
        guard !payloads.isEmpty, !settings.isExcluded(bundleID: sourceBundleID) else { return nil }
        let clip = Clip(sourceBundleID: sourceBundleID, payloads: payloads, description: description)
        store.upsert(clip)
        return store.list().first { $0.contentIdentity == clip.contentIdentity }
    }
}

import Foundation

public struct AppSettings: Codable, Equatable, Sendable {
    public var retentionLimit: Int
    public var excludedBundleIDs: Set<String>
    public var plainTextPasteByDefault: Bool
    public var launchAtLogin: Bool
    public var hotKeyDescription: String

    public init(
        retentionLimit: Int = 500,
        excludedBundleIDs: Set<String> = [],
        plainTextPasteByDefault: Bool = false,
        launchAtLogin: Bool = false,
        hotKeyDescription: String = "⌘⇧V"
    ) {
        self.retentionLimit = max(1, retentionLimit)
        self.excludedBundleIDs = excludedBundleIDs
        self.plainTextPasteByDefault = plainTextPasteByDefault
        self.launchAtLogin = launchAtLogin
        self.hotKeyDescription = hotKeyDescription
    }

    public func isExcluded(bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return excludedBundleIDs.contains(bundleID)
    }
}

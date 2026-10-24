import Foundation

public struct AppSettings: Codable, Equatable, Sendable {
    public var retentionLimit: Int
    public var excludedBundleIDs: Set<String>
    public var plainTextPasteByDefault: Bool
    public var launchAtLogin: Bool
    public var hotKeyKeyCode: UInt16
    public var hotKeyModifiers: UInt
    public var hotKeyDescription: String

    public static let defaultHotKeyKeyCode: UInt16 = 9 // V
    public static let defaultHotKeyModifiers: UInt = 1_179_648 // command + shift

    public init(
        retentionLimit: Int = 500,
        excludedBundleIDs: Set<String> = [],
        plainTextPasteByDefault: Bool = false,
        launchAtLogin: Bool = false,
        hotKeyKeyCode: UInt16 = AppSettings.defaultHotKeyKeyCode,
        hotKeyModifiers: UInt = AppSettings.defaultHotKeyModifiers,
        hotKeyDescription: String = "⌘⇧V"
    ) {
        self.retentionLimit = max(1, retentionLimit)
        self.excludedBundleIDs = excludedBundleIDs
        self.plainTextPasteByDefault = plainTextPasteByDefault
        self.launchAtLogin = launchAtLogin
        self.hotKeyKeyCode = hotKeyKeyCode
        self.hotKeyModifiers = hotKeyModifiers
        self.hotKeyDescription = hotKeyDescription
    }

    public func isExcluded(bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return excludedBundleIDs.contains(bundleID)
    }

    private enum CodingKeys: String, CodingKey {
        case retentionLimit, excludedBundleIDs, plainTextPasteByDefault, launchAtLogin
        case hotKeyKeyCode, hotKeyModifiers, hotKeyDescription
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            retentionLimit: try values.decodeIfPresent(Int.self, forKey: .retentionLimit) ?? 500,
            excludedBundleIDs: try values.decodeIfPresent(Set<String>.self, forKey: .excludedBundleIDs) ?? [],
            plainTextPasteByDefault: try values.decodeIfPresent(Bool.self, forKey: .plainTextPasteByDefault) ?? false,
            launchAtLogin: try values.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false,
            hotKeyKeyCode: try values.decodeIfPresent(UInt16.self, forKey: .hotKeyKeyCode) ?? Self.defaultHotKeyKeyCode,
            hotKeyModifiers: try values.decodeIfPresent(UInt.self, forKey: .hotKeyModifiers) ?? Self.defaultHotKeyModifiers,
            hotKeyDescription: try values.decodeIfPresent(String.self, forKey: .hotKeyDescription) ?? "⌘⇧V"
        )
    }
}

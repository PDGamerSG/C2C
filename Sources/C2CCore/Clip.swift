import Foundation

public struct Clip: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let createdAt: Date
    public var updatedAt: Date
    public var pasteCount: Int
    public var isPinned: Bool
    public var groupName: String?
    public let sourceBundleID: String?
    public let payloads: [ClipPayload]
    public var description: String?

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        updatedAt: Date? = nil,
        pasteCount: Int = 0,
        isPinned: Bool = false,
        groupName: String? = nil,
        sourceBundleID: String? = nil,
        payloads: [ClipPayload],
        description: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.pasteCount = pasteCount
        self.isPinned = isPinned
        self.groupName = groupName
        self.sourceBundleID = sourceBundleID
        self.payloads = payloads
        self.description = description
    }

    public var contentIdentity: String {
        var bytes = [UInt8]()
        for payload in payloads {
            bytes.append(contentsOf: payload.kind.rawValue.utf8)
            bytes.append(0)
            bytes.append(contentsOf: payload.uti.utf8)
            bytes.append(0)
            bytes.append(contentsOf: payload.data)
            for url in payload.fileURLs {
                bytes.append(contentsOf: url.absoluteString.utf8)
                bytes.append(0)
            }
        }
        return StableHasher.hex(bytes)
    }

    public var contentText: String? {
        payloads.compactMap(\.textValue).first
    }

    public var displayTitle: String {
        if let description, !description.isEmpty { return description }
        if let contentText, !contentText.isEmpty { return contentText.replacingOccurrences(of: "\n", with: " ") }
        if payloads.contains(where: { $0.kind == .image }) { return "Image" }
        if payloads.contains(where: { $0.kind == .file }) { return "Files" }
        return "Clipboard item"
    }
}

private enum StableHasher {
    static func hex(_ bytes: [UInt8]) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in bytes {
            hash ^= UInt64(byte)
            hash = hash &* 1_099_511_628_211
        }
        return String(format: "%016llx", hash)
    }
}

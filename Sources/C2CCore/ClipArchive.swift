import Foundation

public enum ClipArchiveError: Error, Equatable {
    case unsupportedVersion(Int)
}

public enum ClipArchive {
    private struct Envelope: Codable {
        let version: Int
        let exportedAt: Date
        let clips: [Clip]
    }

    public static func export(clips: [Clip]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(Envelope(version: 1, exportedAt: Date(), clips: clips))
    }

    public static func `import`(data: Data) throws -> [Clip] {
        let decoder = JSONDecoder()
        let envelope = try decoder.decode(Envelope.self, from: data)
        guard envelope.version == 1 else { throw ClipArchiveError.unsupportedVersion(envelope.version) }
        return envelope.clips
    }
}

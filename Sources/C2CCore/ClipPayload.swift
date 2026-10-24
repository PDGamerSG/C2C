import Foundation

public enum ClipKind: String, Codable, Hashable, Sendable {
    case text
    case richText
    case html
    case image
    case file
    case custom
}

public struct ClipPayload: Codable, Hashable, Sendable {
    public let kind: ClipKind
    public let uti: String
    public let data: Data
    public let fileURLs: [URL]

    public init(kind: ClipKind, uti: String, data: Data = Data(), fileURLs: [URL] = []) {
        self.kind = kind
        self.uti = uti
        self.data = data
        self.fileURLs = fileURLs
    }

    public static func text(_ value: String) -> ClipPayload {
        ClipPayload(kind: .text, uti: "public.utf8-plain-text", data: Data(value.utf8))
    }

    public static func html(_ value: String) -> ClipPayload {
        ClipPayload(kind: .html, uti: "public.html", data: Data(value.utf8))
    }

    public static func file(urls: [URL]) -> ClipPayload {
        ClipPayload(kind: .file, uti: "public.file-url", fileURLs: urls)
    }

    public var textValue: String? {
        guard kind == .text || kind == .richText || kind == .html else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

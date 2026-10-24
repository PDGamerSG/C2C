import Foundation

public enum ClipSearch {
    public static func matches(_ query: String, clip: Clip) -> Bool {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return true }
        let haystack = ([clip.description, clip.contentText, clip.groupName].compactMap { $0 } + clip.payloads.map(\.uti)).joined(separator: " ")
        return haystack.localizedCaseInsensitiveContains(normalized)
    }
}

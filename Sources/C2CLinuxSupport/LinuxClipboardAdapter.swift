import Foundation
import C2CCore

public enum LinuxClipboardBackend: String, Sendable {
    case wayland
    case x11
}

public enum LinuxClipboardError: Error, LocalizedError, Equatable {
    case helperUnavailable(String)
    case commandFailed(String, Int32, String)

    public var errorDescription: String? {
        switch self {
        case .helperUnavailable(let helper): return "Clipboard helper is unavailable: \(helper)"
        case .commandFailed(let command, let status, let output): return "\(command) failed (\(status)): \(output)"
        }
    }
}

public final class LinuxClipboardAdapter {
    public typealias ExecutableLookup = (String) -> String?
    public typealias CommandRunner = (_ executable: String, _ arguments: [String]) throws -> Data

    public let backend: LinuxClipboardBackend?
    private let readExecutable: String?
    private let run: CommandRunner

    public init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        executableLookup: @escaping ExecutableLookup = LinuxClipboardAdapter.defaultLookup,
        commandRunner: @escaping CommandRunner = LinuxClipboardAdapter.runCommand
    ) {
        self.run = commandRunner
        if environment["WAYLAND_DISPLAY"] != nil, let executable = executableLookup("wl-paste") {
            backend = .wayland
            readExecutable = executable
        } else if environment["DISPLAY"] != nil, let executable = executableLookup("xclip") {
            backend = .x11
            readExecutable = executable
        } else {
            backend = nil
            readExecutable = nil
        }
    }

    public func readPayloads() -> [ClipPayload] {
        guard let backend else { return [] }
        var payloads: [ClipPayload] = []
        let textTarget = backend == .x11 ? "UTF8_STRING" : "text/plain"
        if let text = readOptional(type: textTarget, backend: backend), !text.isEmpty {
            payloads.append(.text(text))
        }
        if let html = readOptional(type: "text/html", backend: backend), !html.isEmpty {
            payloads.append(.html(html))
        }
        if let rtf = readData(type: "text/rtf", backend: backend), !rtf.isEmpty {
            payloads.append(ClipPayload(kind: .richText, uti: "text/rtf", data: rtf))
        }
        if let uriList = readOptional(type: "text/uri-list", backend: backend), !uriList.isEmpty {
            let urls = uriList
                .split(whereSeparator: { $0 == "\n" || $0 == "\r" })
                .compactMap { URL(string: String($0)) }
                .filter { $0.isFileURL }
            if !urls.isEmpty { payloads.append(.file(urls: urls)) }
        }
        if let image = readData(type: "image/png", backend: backend), !image.isEmpty {
            payloads.append(ClipPayload(kind: .image, uti: "image/png", data: image))
        }
        return payloads
    }

    private func readOptional(type: String, backend: LinuxClipboardBackend) -> String? {
        readData(type: type, backend: backend).flatMap { String(data: $0, encoding: .utf8) }
    }

    private func readData(type: String, backend: LinuxClipboardBackend) -> Data? {
        guard let readExecutable else { return nil }
        switch backend {
        case .wayland: return try? run(readExecutable, ["--no-newline", "--type", type])
        case .x11: return try? run(readExecutable, ["-selection", "clipboard", "-o", "-t", type])
        }
    }

    public static func defaultLookup(_ executable: String) -> String? {
        let path = ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin"
        return path.split(separator: ":")
            .map { URL(fileURLWithPath: String($0), isDirectory: true).appendingPathComponent(executable).path }
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    public static func runCommand(_ executable: String, _ arguments: [String]) throws -> Data {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw LinuxClipboardError.commandFailed(executable, process.terminationStatus, "")
        }
        return data
    }
}

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
    private let lookup: ExecutableLookup
    private let run: CommandRunner

    public init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        executableLookup: @escaping ExecutableLookup = LinuxClipboardAdapter.defaultLookup,
        commandRunner: @escaping CommandRunner = LinuxClipboardAdapter.runCommand
    ) {
        self.lookup = executableLookup
        self.run = commandRunner
        if environment["WAYLAND_DISPLAY"] != nil && executableLookup("wl-paste") != nil {
            backend = .wayland
        } else if executableLookup("xclip") != nil {
            backend = .x11
        } else {
            backend = nil
        }
    }

    public func readPayloads() -> [ClipPayload] {
        guard let backend else { return [] }
        var payloads: [ClipPayload] = []
        if let text = readText(backend: backend), !text.isEmpty {
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

    private func readText(backend: LinuxClipboardBackend) -> String? {
        let data: Data?
        switch backend {
        case .wayland: data = try? run("wl-paste", ["--no-newline", "--type", "text/plain"])
        case .x11: data = try? run("xclip", ["-selection", "clipboard", "-o", "-t", "text/plain"])
        }
        return data.flatMap { String(data: $0, encoding: .utf8) }
    }

    private func readOptional(type: String, backend: LinuxClipboardBackend) -> String? {
        readData(type: type, backend: backend).flatMap { String(data: $0, encoding: .utf8) }
    }

    private func readData(type: String, backend: LinuxClipboardBackend) -> Data? {
        let data: Data?
        switch backend {
        case .wayland: data = try? run("wl-paste", ["--no-newline", "--type", type])
        case .x11: data = try? run("xclip", ["-selection", "clipboard", "-o", "-t", type])
        }
        return data
    }

    public static func defaultLookup(_ executable: String) -> String? {
        let path = "/usr/bin/env"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["sh", "-c", "command -v \"$1\"", "c2c", executable]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        return String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func runCommand(_ executable: String, _ arguments: [String]) throws -> Data {
        guard let path = defaultLookup(executable) else { throw LinuxClipboardError.helperUnavailable(executable) }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let output = Pipe()
        let errors = Pipe()
        process.standardOutput = output
        process.standardError = errors
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let message = String(data: errors.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw LinuxClipboardError.commandFailed(executable, process.terminationStatus, message.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return output.fileHandleForReading.readDataToEndOfFile()
    }
}

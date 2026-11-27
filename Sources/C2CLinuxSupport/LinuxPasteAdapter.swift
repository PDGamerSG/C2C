import Foundation
import C2CCore

public final class LinuxPasteAdapter {
    public typealias CommandRunner = (_ executable: String, _ arguments: [String], _ input: Data) throws -> Data
    private let backend: LinuxClipboardBackend?
    private let run: CommandRunner
    private let lookup: LinuxClipboardAdapter.ExecutableLookup

    public init(
        clipboard: LinuxClipboardAdapter,
        executableLookup: @escaping LinuxClipboardAdapter.ExecutableLookup = LinuxClipboardAdapter.defaultLookup,
        commandRunner: @escaping CommandRunner = LinuxPasteAdapter.runCommand
    ) {
        self.backend = clipboard.backend
        self.lookup = executableLookup
        self.run = commandRunner
    }

    public func write(_ payloads: [ClipPayload]) throws {
        guard let backend else { throw LinuxClipboardError.helperUnavailable("wl-copy/xclip") }
        guard let payload = payloads.first(where: { [.text, .html, .richText, .file, .image].contains($0.kind) }) else {
            throw LinuxClipboardError.helperUnavailable("text-compatible clipboard payload")
        }
        let data: Data
        let type: String
        if payload.kind == .file {
            data = Data(payload.fileURLs.map(\.absoluteString).joined(separator: "\n").utf8)
            type = "text/uri-list"
        } else {
            data = payload.data
            switch payload.kind {
            case .html: type = "text/html"
            case .richText: type = "text/rtf"
            case .image: type = payload.uti
            default: type = "text/plain"
            }
        }
        switch backend {
        case .wayland:
            guard let executable = lookup("wl-copy") else { throw LinuxClipboardError.helperUnavailable("wl-copy") }
            _ = try run(executable, ["--type", type], data)
        case .x11:
            guard let executable = lookup("xclip") else { throw LinuxClipboardError.helperUnavailable("xclip") }
            let target = type == "text/plain" ? "UTF8_STRING" : type
            _ = try run(executable, ["-selection", "clipboard", "-t", target, "-i"], data)
        }
    }

    public func sendPaste() throws {
        if backend == .wayland {
            guard let wtype = lookup("wtype") else { throw LinuxClipboardError.helperUnavailable("wtype") }
            _ = try run(wtype, ["-M", "CTRL", "-k", "V", "-m", "CTRL"], Data())
        } else {
            guard let xdotool = lookup("xdotool") else { throw LinuxClipboardError.helperUnavailable("xdotool") }
            _ = try run(xdotool, ["key", "--clearmodifiers", "ctrl+v"], Data())
        }
    }

    public static func runCommand(_ executable: String, _ arguments: [String], _ input: Data) throws -> Data {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let inputPipe = Pipe()
        process.standardInput = inputPipe
        // Clipboard helpers may keep a background owner alive after the command returns.
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        let inputResult = Result { try inputPipe.fileHandleForWriting.write(contentsOf: input) }
        try? inputPipe.fileHandleForWriting.close()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw LinuxClipboardError.commandFailed(executable, process.terminationStatus, "")
        }
        try inputResult.get()
        return Data()
    }
}

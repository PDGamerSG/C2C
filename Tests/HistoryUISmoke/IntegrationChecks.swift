import AppKit
import Carbon
import C2CCore

@MainActor
func runHistoryPanelChecks() {
    let now = Date()
    let clips = (1...62).map { number in
        Clip(createdAt: now.addingTimeInterval(-Double(number)), payloads: [.text("Message \(number)")])
    }
    let store = InMemoryClipStore(clips: clips)
    let pasteboard = NSPasteboard.withUniqueName()
    defer { pasteboard.releaseGlobally() }
    let controller = HistoryPanelController(store: store, pasteCoordinator: PasteCoordinator(pasteboard: pasteboard), onSettings: {})
    controller.show()
    guard let panel = NSApp.windows.compactMap({ $0 as? HistoryPanel }).first(where: \.isVisible),
          let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main else {
        fatalError("UI SMOKE FAILED: history panel should open")
    }
    defer { panel.orderOut(nil) }
    check(abs(panel.frame.midX - screen.visibleFrame.midX) < 1 && abs(panel.frame.midY - screen.visibleFrame.midY) < 1, "history opens in the center of the current screen")
    let history = panel.contentViewController as! HistoryViewController
    let views = descendants(of: history.view)
    let table = views.compactMap { $0 as? HistoryTableView }.first!
    let search = views.compactMap { $0 as? NSSearchField }.first!
    history.view.layoutSubtreeIfNeeded()
    table.selectRowIndexes(IndexSet(integer: 61), byExtendingSelection: false)
    table.scrollRowToVisible(61)
    check(table.selectedRow == 61 && table.visibleRect.minY > 0, "message 62 is selected and the history is scrolled down")
    controller.toggle()
    controller.toggle()
    check(panel.isVisible && table.selectedRow == 0 && table.visibleRect.minY == 0, "shortcut reopening starts at the top after selecting message 62")

    table.selectRowIndexes(IndexSet(integer: 58), byExtendingSelection: false)
    search.stringValue = "Message 6"
    history.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: search))
    check(table.numberOfRows == 4 && table.selectedRow == 0, "a new search selects the first result even after browsing near the bottom")
    table.selectRowIndexes(IndexSet(integer: 2), byExtendingSelection: false)
    controller.show()
    check(search.stringValue == "Message 6" && table.selectedRow == 2, "showing an already open panel keeps the current search and selection")
    search.stringValue = "no matching message"
    history.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: search))
    check(table.numberOfRows == 0 && table.selectedRow == -1, "an empty search clears the table selection")
    // Window focus notifications use the same delegate path as an outside click.
    NotificationCenter.default.post(name: NSWindow.didResignKeyNotification, object: panel)
    check(!panel.isVisible, "history dismisses when another window takes keyboard focus")
    controller.show()
    check(panel.isVisible && search.stringValue.isEmpty && table.numberOfRows == 62 && table.selectedRow == 0 && table.visibleRect.minY == 0,
          "history reopens at the top with a fresh search after focus dismissal")
    NotificationCenter.default.post(name: NSApplication.didResignActiveNotification, object: NSApp)
    check(!panel.isVisible, "history dismisses when switching to another app")
    controller.show()
    check(panel.isVisible, "history can reopen after switching apps")

    table.scrollRowToVisible(61)
    let newClip = Clip(createdAt: now, payloads: [.text("New clipboard entry")])
    store.upsert(newClip)
    controller.reloadIfVisible()
    check(table.numberOfRows == 63 && table.selectedRow == 1, "a new clipboard entry preserves the selected message")
    check(table.visibleRect.intersects(table.rect(ofRow: 61)), "a background clipboard update leaves the scrolled history in view")

    table.selectRowIndexes(IndexSet(integer: 62), byExtendingSelection: false)
    table.scrollRowToVisible(62)
    store.delete(clips[61].id)
    controller.reloadIfVisible()
    check(table.numberOfRows == 62 && table.selectedRow == 61, "removing the last selected message selects its nearest neighbor")

    store.setPinned(clips[0].id, pinned: true)
    store.setPinned(clips[1].id, pinned: true)
    let menu = NSMenu()
    history.menuNeedsUpdate(menu)
    let pinnedOnly = menu.items.first { $0.title == "Pinned messages only" }!
    _ = NSApp.sendAction(pinnedOnly.action!, to: pinnedOnly.target, from: pinnedOnly)
    check(table.numberOfRows == 2 && table.selectedRow == 0, "switching to pinned messages selects the first result")
    table.selectRowIndexes(IndexSet(integer: 1), byExtendingSelection: false)
    controller.toggle()
    controller.toggle()
    check(panel.isVisible && table.numberOfRows == 2 && table.selectedRow == 0, "reopening keeps the pinned filter and selects its first result")
    controller.toggle()
    check(!panel.isVisible, "shortcut toggle still closes history")
    print("History reopening, search, filtering, live updates, and focus dismissal checks passed")
}

@MainActor
func runShortcutRecorderChecks() {
    let window = NSWindow(contentRect: NSRect(x: -10_000, y: -10_000, width: 300, height: 100), styleMask: [.titled], backing: .buffered, defer: false)
    defer { window.orderOut(nil) }
    let field = ShortcutRecorderField(string: "⌘⇧V")
    field.frame = NSRect(x: 10, y: 10, width: 180, height: 24)
    window.contentView?.addSubview(field)
    var captured: UInt16?
    field.onShortcut = { keyCode, _, _ in captured = keyCode }
    let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [.control, .option], timestamp: 0, windowNumber: window.windowNumber, context: nil, characters: "k", charactersIgnoringModifiers: "k", isARepeat: false, keyCode: 40)!
    window.makeFirstResponder(nil)
    check(!field.performKeyEquivalent(with: event) && captured == nil, "unfocused recorder must not intercept shortcuts")
    check(window.makeFirstResponder(field), "recorder can receive keyboard focus")
    check(window.firstResponder === field, "recorder owns focus without a text editor")
    check(field.performKeyEquivalent(with: event), "focused recorder captures shortcut")
    check(captured == 40 && field.stringValue == "⌃⌥K", "shortcut records actual key code and display")
    print("Shortcut recorder checks passed")
}

@MainActor
func samplePNG() -> Data {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 160, pixelsHigh: 100, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    for x in 0..<160 {
        for y in 0..<100 {
            bitmap.setColor(NSColor(deviceRed: CGFloat(x) / 160, green: 0.45, blue: CGFloat(y) / 100, alpha: 1), atX: x, y: y)
        }
    }
    return bitmap.representation(using: .png, properties: [:])!
}

@MainActor
func runImageCaptureChecks() {
    let pasteboard = NSPasteboard.withUniqueName()
    defer { pasteboard.releaseGlobally() }
    let store = InMemoryClipStore()
    let monitor = ClipboardMonitor(pasteboard: pasteboard, service: ClipboardService(store: store), sourceBundleID: { nil })
    monitor.start()
    defer { monitor.stop() }
    let png = samplePNG()
    pasteboard.clearContents()
    pasteboard.setData(png, forType: .png)
    RunLoop.main.run(until: Date().addingTimeInterval(0.35))
    check(store.list().first?.payloads.contains { $0.kind == .image && $0.data == png } == true, "PNG-only clipboard images are captured")
    pasteboard.clearContents()
    pasteboard.setData(NSImage(data: png)!.tiffRepresentation!, forType: .tiff)
    RunLoop.main.run(until: Date().addingTimeInterval(0.35))
    check(store.list().first?.payloads.contains { $0.kind == .image && NSImage(data: $0.data) != nil } == true, "TIFF clipboard images remain supported")
    print("Image capture checks passed")
}

@MainActor
func runSettingsChecks() throws {
    let directory = URL(fileURLWithPath: CommandLine.arguments[1])
    let url = directory.appendingPathComponent("test-settings.json")
    defer { try? FileManager.default.removeItem(at: url) }
    var saved: AppSettings?
    var failSave = true
    let settings = SettingsWindowController(settings: AppSettings(), store: InMemoryClipStore(), onRecordingChange: { _ in }, onAppearanceChange: { _ in }, onSave: { candidate in
        if failSave { throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Shortcut already in use."]) }
        try JSONEncoder().encode(candidate).write(to: url, options: .atomic)
        saved = candidate
        HistoryAppearance.apply(candidate.appearance)
    })
    let window = settings.window!
    window.setFrameOrigin(NSPoint(x: -10_000, y: -10_000))
    defer { window.orderOut(nil); HistoryAppearance.apply(.light) }
    let views = descendants(of: window.contentView!)
    let picker = views.compactMap { $0 as? NSPopUpButton }.first { $0.identifier?.rawValue == "appearancePicker" }!
    picker.selectItem(withTitle: "Dark")
    let field = views.compactMap { $0 as? ShortcutRecorderField }.first!
    window.makeFirstResponder(field)
    let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .control, timestamp: 0, windowNumber: window.windowNumber, context: nil, characters: "\u{60}", charactersIgnoringModifiers: "\u{60}", isARepeat: false, keyCode: 50)!
    _ = field.performKeyEquivalent(with: event)
    let save = views.compactMap { $0 as? NSButton }.first { $0.title == "Save" }!
    save.performClick(nil)
    check(saved == nil && !FileManager.default.fileExists(atPath: url.path), "failed shortcut registration does not save settings")
    check(views.contains { $0.identifier?.rawValue == "settingsError" && !$0.isHidden }, "failed settings save shows a visible error")
    failSave = false
    save.performClick(nil)
    let restored = try JSONDecoder().decode(AppSettings.self, from: Data(contentsOf: url))
    check(restored.appearance == .dark && restored.hotKeyKeyCode == 50 && restored.hotKeyModifiers == NSEvent.ModifierFlags.control.rawValue, "settings save persists dark appearance and Control-backtick")
    check(restored.hotKeyDescription == "⌃\u{60}", "shortcut label matches saved keys")
    check(NSApp.appearance?.name == .darkAqua, "saved appearance applies immediately")
    try render(window.contentView!, to: "settings-dark.png")
    print("Settings save, conflict feedback, and appearance checks passed")
}

@MainActor
func runImmediateAppearanceChecks() throws {
    let url = URL(fileURLWithPath: CommandLine.arguments[1]).appendingPathComponent("appearance-settings.json")
    defer { try? FileManager.default.removeItem(at: url); HistoryAppearance.apply(.light) }
    let store = InMemoryClipStore()
    let history = HistoryViewController(store: store, pasteCoordinator: PasteCoordinator(), onSettings: {})
    let historyWindow = HistoryPanel(contentViewController: history)
    let settings = SettingsWindowController(settings: AppSettings(), store: store, onRecordingChange: { _ in }, onAppearanceChange: { appearance in
        try JSONEncoder().encode(AppSettings(appearance: appearance)).write(to: url, options: .atomic)
        HistoryAppearance.apply(appearance)
    }, onSave: { _ in fatalError("Changing appearance should not submit unrelated settings") })
    let picker = descendants(of: settings.window!.contentView!).compactMap { $0 as? NSPopUpButton }.first!
    picker.selectItem(withTitle: "Dark")
    if let action = picker.action { _ = picker.sendAction(action, to: picker.target) }
    check(settings.window!.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua, "choosing Dark immediately changes Settings")
    check(historyWindow.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua, "choosing Dark immediately changes existing clipboard history")
    let restored = try JSONDecoder().decode(AppSettings.self, from: Data(contentsOf: url))
    check(restored.appearance == .dark, "appearance choice is persisted without pressing Save")
    try render(settings.window!.contentView!, to: "immediate-settings-dark.png")
    try render(history.view, to: "immediate-history-dark.png")
    picker.selectItem(withTitle: "Light")
    _ = picker.sendAction(picker.action!, to: picker.target)
    check(settings.window!.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .aqua &&
          historyWindow.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .aqua, "Light updates both existing windows immediately")
    picker.selectItem(withTitle: "System")
    _ = picker.sendAction(picker.action!, to: picker.target)
    check(NSApp.appearance == nil, "System restores the macOS appearance")
    print("Immediate appearance selection, persistence, and both-window checks passed")
}

@MainActor
func runHotKeyChecks() {
    let manager = HotKeyManager(keyCode: 50, modifiers: .control)
    guard manager.start() else {
        if manager.registrationError?.contains("already in use") == true {
            print("Global shortcut checks skipped: Control-backtick is occupied by another process.")
            return
        }
        check(false, "Control-backtick registers globally: \(manager.registrationError ?? "unknown error")")
        return
    }
    defer { manager.stop() }
    if CGPreflightPostEventAccess() {
        var presses = 0
        manager.onPress = { presses += 1 }
        NSApp.activate(ignoringOtherApps: true)
        for isDown in [true, false] {
            let event = CGEvent(keyboardEventSource: nil, virtualKey: 50, keyDown: isDown)!
            event.flags = .maskControl
            event.post(tap: .cghidEventTap)
        }
        let deadline = Date().addingTimeInterval(1)
        while Date() < deadline {
            if let event = NSApp.nextEvent(matching: .any, until: deadline, inMode: .default, dequeue: true) { NSApp.sendEvent(event) }
        }
        guard presses == 1 else {
            print("Global key injection skipped: synthetic events were not delivered in this session (presses=\(presses)).")
            manager.stop()
            return
        }
    } else {
        print("Global key injection skipped: test process has no event-posting permission.")
    }
    let competing = HotKeyManager(keyCode: 50, modifiers: .control)
    defer { competing.stop() }
    check(!competing.start() && competing.registrationError != nil, "shortcut conflicts are reported")
    manager.setRecording(true)
    check(competing.start(), "recording temporarily releases the active shortcut")
    competing.stop()
    manager.setRecording(false)
    check(manager.start(), "shortcut resumes after recording")
    let occupied = HotKeyManager(keyCode: 40, modifiers: [.control, .option, .shift])
    check(occupied.start(), "test alternate shortcut registers")
    defer { occupied.stop() }
    check(!manager.update(keyCode: 40, modifiers: [.control, .option, .shift]), "conflicting shortcut change is rejected")
    check(manager.keyCode == 50 && manager.modifiers == .control, "failed change retains the previous shortcut")
    check(!competing.start(), "previous shortcut remains registered after failed change")
    print("Global Control-backtick registration and conflict checks passed")
}

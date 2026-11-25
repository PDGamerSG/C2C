import AppKit
import C2CCore

@MainActor
func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError("UI SMOKE FAILED: \(message)") }
}

@MainActor
func descendants(of view: NSView) -> [NSView] {
    view.subviews.flatMap { [$0] + descendants(of: $0) }
}

@MainActor
func render(_ view: NSView, to name: String) throws {
    view.layoutSubtreeIfNeeded()
    view.displayIfNeeded()
    let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
    view.cacheDisplay(in: view.bounds, to: bitmap)
    let directory = URL(fileURLWithPath: CommandLine.arguments[1])
    try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent(name))
}

@MainActor
func key(_ code: UInt16) -> NSEvent {
    let character: String
    switch code {
    case 125: character = String(UnicodeScalar(NSDownArrowFunctionKey)!)
    case 49: character = " "
    case 51: character = "\u{7f}"
    default: character = ""
    }
    return NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, characters: character, charactersIgnoringModifiers: character, isARepeat: false, keyCode: code)!
}

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
HistoryAppearance.apply(.light)
try runImmediateAppearanceChecks()
runHistoryPanelChecks()
runShortcutRecorderChecks()
runHotKeyChecks()
runImageCaptureChecks()
try runSettingsChecks()
let titles = ["different text", "copy some text", "search", "paste", "copy",
              "compare clips in diff app", "send clip to network computers", "view copied images"]
let now = Date()
let clips = titles.enumerated().map { offset, text in
    Clip(createdAt: now.addingTimeInterval(-Double(offset)), payloads: [.text(text)])
}
let store = InMemoryClipStore(clips: clips)
let controller = HistoryViewController(store: store, pasteCoordinator: PasteCoordinator(pasteboard: NSPasteboard.withUniqueName()), onSettings: {})
let window = HistoryPanel(contentViewController: controller)
window.styleMask = [.borderless, .nonactivatingPanel]
window.setContentSize(NSSize(width: 400, height: 340))
window.setFrameOrigin(NSPoint(x: -10_000, y: -10_000))
window.orderFront(nil)
defer { window.orderOut(nil) }
controller.view.layoutSubtreeIfNeeded()
let views = descendants(of: controller.view)
let table = views.compactMap { $0 as? HistoryTableView }.first!
let search = views.compactMap { $0 as? NSSearchField }.first!
check(table.numberOfRows == 8, "all clipboard rows appear")
check(table.selectedRow == 0, "first message selected")
check(!search.isBezeled && !search.isBordered, "search is borderless")
check(views.compactMap { $0 as? NSScrollView }.allSatisfy { $0.borderType == .noBorder }, "history and preview are borderless")
try render(controller.view, to: "history.png")

// Pin through the actual row button, then try deleting through the table keyboard.
let cell = table.view(atColumn: 0, row: 0, makeIfNecessary: true) as! HistoryClipCell
let pin = descendants(of: cell).compactMap { $0 as? NSButton }.first!
pin.performClick(nil)
check(store.list().first?.isPinned == true, "row pin action reaches storage")
table.keyDown(with: key(51))
check(store.list().count == 8, "Delete cannot remove a pinned row")
let menu = NSMenu()
controller.menuNeedsUpdate(menu)
check(menu.items.contains { $0.title == "Unpin to delete" && !$0.isEnabled }, "menu explains protected deletion")
try render(controller.view, to: "history-pinned.png")

// Search and navigation must work while the search field holds focus.
search.stringValue = "copy"
controller.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: search))
check(table.numberOfRows == 2, "search filters real messages")
let handled = controller.control(search, textView: NSTextView(), doCommandBy: #selector(NSResponder.moveDown(_:)))
check(handled && table.selectedRow == 1, "arrow navigation works from search")
search.stringValue = ""
controller.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: search))
table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
window.makeFirstResponder(table)
table.keyDown(with: key(125))
check(table.selectedRow == 1, "table arrow keys retain native navigation")
table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
table.keyDown(with: key(49))
check(store.stats().pinnedClips == 0, "Space unpins selected row")
table.keyDown(with: key(51))
check(store.list().count == 7, "Delete removes an unpinned row")

let previewButton = views.compactMap { $0 as? NSButton }.first { $0.toolTip == "Show preview" }!
previewButton.performClick(nil)
controller.view.layoutSubtreeIfNeeded()
let preview = views.compactMap { $0 as? NSTextView }.first!
check(preview.enclosingScrollView?.isHidden == false && !preview.string.isEmpty, "preview opens with selected content")
try render(controller.view, to: "history-preview.png")
previewButton.performClick(nil)
search.stringValue = "no match exists"
controller.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: search))
check(table.numberOfRows == 0, "empty search has no stale rows")
controller.menuNeedsUpdate(menu)
check(menu.items.prefix(3).allSatisfy { !$0.isEnabled }, "empty-state selection actions are disabled")
try render(controller.view, to: "history-empty.png")

search.stringValue = ""
let imageClip = Clip(payloads: [ClipPayload(kind: .image, uti: "public.png", data: samplePNG())])
store.upsert(imageClip)
controller.reload()
let imageRow = store.list().firstIndex { $0.id == imageClip.id }!
table.selectRowIndexes(IndexSet(integer: imageRow), byExtendingSelection: false)
let imageCell = table.view(atColumn: 0, row: imageRow, makeIfNecessary: true)!
check(descendants(of: imageCell).contains { ($0 as? NSImageView)?.image != nil && !$0.isHidden }, "image row shows an actual thumbnail")
previewButton.performClick(nil)
check(descendants(of: controller.view).contains { $0.identifier?.rawValue == "imagePreview" && ($0 as? NSImageView)?.image != nil && !$0.isHidden }, "image preview displays selected clipboard image")
try render(controller.view, to: "history-image-light.png")
HistoryAppearance.apply(.dark)
controller.view.layoutSubtreeIfNeeded()
check(controller.view.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua, "history follows dark appearance")
try render(controller.view, to: "history-image-dark.png")
HistoryAppearance.apply(.light)
check(controller.view.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .aqua, "existing history returns to light appearance")
try render(controller.view, to: "history-image-light-restored.png")
print("Native UI smoke checks passed; screenshots saved to \(CommandLine.arguments[1])")

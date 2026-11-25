import AppKit
import C2CCore

@MainActor
enum HistoryAppearance {
    static let background = adaptive(light: .white, dark: NSColor(white: 0.12, alpha: 1))
    static let stripe = adaptive(light: NSColor(red: 0.94, green: 0.95, blue: 0.94, alpha: 1), dark: NSColor(white: 0.16, alpha: 1))
    static let selection = adaptive(light: NSColor(red: 0.84, green: 0.85, blue: 0.84, alpha: 1), dark: NSColor(white: 0.26, alpha: 1))
    static let accent = adaptive(light: NSColor(red: 0.05, green: 0.55, blue: 0.65, alpha: 1), dark: NSColor(red: 0.25, green: 0.77, blue: 0.85, alpha: 1))
    static let rail = adaptive(light: NSColor(white: 0.98, alpha: 1), dark: NSColor(white: 0.14, alpha: 1))
    static let text = NSColor.labelColor
    static let secondary = NSColor.secondaryLabelColor

    private static func adaptive(light: NSColor, dark: NSColor) -> NSColor {
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        }
    }

    static func apply(_ appearance: AppAppearance) {
        switch appearance {
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        case .system: NSApp.appearance = nil
        }
    }

    static func button(symbol: String, label: String, target: AnyObject?, action: Selector?) -> NSButton {
        let button = NSButton(image: NSImage(systemSymbolName: symbol, accessibilityDescription: label) ?? NSImage(), target: target, action: action)
        button.isBordered = false
        button.imagePosition = .imageOnly
        button.contentTintColor = secondary
        button.focusRingType = .none
        button.toolTip = label
        button.setAccessibilityLabel(label)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }
}

@MainActor
final class HistoryBackgroundView: NSView {
    var fillColor = HistoryAppearance.background
    override func draw(_ dirtyRect: NSRect) { fillColor.setFill(); bounds.fill() }
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}

@MainActor
final class HistoryTableView: NSTableView {
    var onKeyDown: ((NSEvent) -> Bool)?

    override func keyDown(with event: NSEvent) {
        if onKeyDown?(event) != true { super.keyDown(with: event) }
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let clickedRow = row(at: convert(event.locationInWindow, from: nil))
        if clickedRow >= 0 { selectRowIndexes(IndexSet(integer: clickedRow), byExtendingSelection: false) }
        return super.menu(for: event)
    }
}

@MainActor
final class HistoryRowView: NSTableRowView {
    var rowIndex = 0

    override func drawBackground(in dirtyRect: NSRect) {
        (rowIndex.isMultiple(of: 2) ? HistoryAppearance.background : HistoryAppearance.stripe).setFill()
        bounds.fill()
    }

    override func drawSelection(in dirtyRect: NSRect) {
        HistoryAppearance.selection.setFill()
        bounds.fill()
        HistoryAppearance.accent.setFill()
        NSRect(x: 2, y: 5, width: 2, height: bounds.height - 10).fill()
    }

    override func drawSeparator(in dirtyRect: NSRect) {}

    override var isSelected: Bool {
        didSet {
            // AppKit applies selection before attaching a new row's column views.
            if numberOfColumns > 0 { (view(atColumn: 0) as? HistoryClipCell)?.showsActions = isSelected }
        }
    }
}

@MainActor
final class HistoryClipCell: NSTableCellView {
    private let numberLabel = NSTextField(labelWithString: "")
    private let titleLabel = NSTextField(labelWithString: "")
    private let thumbnail = NSImageView()
    private var thumbnailWidth: NSLayoutConstraint!
    private var titleLeading: NSLayoutConstraint!
    private let pinButton = HistoryAppearance.button(symbol: "pin", label: "Pin message", target: nil, action: nil)
    private var pinned = false
    private var hovered = false
    private var hoverArea: NSTrackingArea?
    var onTogglePin: (() -> Void)?
    var showsActions = false { didSet { updatePinVisibility() } }

    override init(frame: NSRect) {
        super.init(frame: frame)
        numberLabel.font = .monospacedDigitSystemFont(ofSize: 9, weight: .regular)
        numberLabel.textColor = HistoryAppearance.secondary
        numberLabel.alignment = .center
        titleLabel.font = .systemFont(ofSize: 13)
        titleLabel.textColor = HistoryAppearance.text
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.maximumNumberOfLines = 1
        thumbnail.imageScaling = .scaleProportionallyUpOrDown
        thumbnail.identifier = NSUserInterfaceItemIdentifier("imageThumbnail")
        thumbnail.setAccessibilityLabel("Copied image")
        thumbnail.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        [numberLabel, thumbnail, titleLabel, pinButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }
        textField = titleLabel
        pinButton.target = self
        pinButton.action = #selector(togglePin)
        thumbnailWidth = thumbnail.widthAnchor.constraint(equalToConstant: 0)
        titleLeading = titleLabel.leadingAnchor.constraint(equalTo: thumbnail.trailingAnchor, constant: 0)
        NSLayoutConstraint.activate([
            numberLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 5),
            numberLabel.widthAnchor.constraint(equalToConstant: 16),
            numberLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            thumbnail.leadingAnchor.constraint(equalTo: numberLabel.trailingAnchor, constant: 3),
            thumbnail.centerYAnchor.constraint(equalTo: centerYAnchor),
            thumbnail.heightAnchor.constraint(equalTo: heightAnchor, constant: -12),
            thumbnailWidth,
            titleLeading,
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: pinButton.leadingAnchor, constant: -4),
            pinButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            pinButton.widthAnchor.constraint(equalToConstant: 26),
            pinButton.heightAnchor.constraint(equalToConstant: 28),
            pinButton.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(clip: Clip, row: Int, selected: Bool) {
        pinned = clip.isPinned
        numberLabel.stringValue = "\(row + 1)"
        titleLabel.stringValue = clip.displayTitle
        thumbnail.image = ClipImageRenderer.image(for: clip, maximumPixels: 160)
        thumbnail.isHidden = thumbnail.image == nil
        thumbnailWidth.constant = thumbnail.image == nil ? 0 : 64
        titleLeading.constant = thumbnail.image == nil ? 0 : 8
        toolTip = clip.contentText ?? clip.displayTitle
        let label = pinned ? "Unpin message" : "Pin message — keep forever"
        pinButton.image = NSImage(systemSymbolName: pinned ? "pin.fill" : "pin", accessibilityDescription: label)
        pinButton.contentTintColor = pinned ? HistoryAppearance.accent : HistoryAppearance.secondary
        pinButton.toolTip = label
        pinButton.setAccessibilityLabel(label)
        setAccessibilityLabel("\(clip.displayTitle)\(pinned ? ", pinned" : "")")
        showsActions = selected
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverArea { removeTrackingArea(hoverArea) }
        let area = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(area)
        hoverArea = area
    }

    override func mouseEntered(with event: NSEvent) { hovered = true; updatePinVisibility() }
    override func mouseExited(with event: NSEvent) { hovered = false; updatePinVisibility() }
    private func updatePinVisibility() { pinButton.isHidden = !(pinned || hovered || showsActions) }
    @objc private func togglePin() { onTogglePin?() }
}

@MainActor
final class HistoryRailView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        HistoryAppearance.rail.setFill()
        bounds.fill()
        HistoryAppearance.selection.setFill()
        NSRect(x: 0, y: bounds.height - 36, width: bounds.width, height: 36).fill()
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        context.translateBy(x: 6, y: bounds.height - 78)
        context.rotate(by: -.pi / 2)
        ("C2C" as NSString).draw(at: .zero, withAttributes: [
            .font: NSFont.systemFont(ofSize: 18, weight: .light),
            .foregroundColor: HistoryAppearance.secondary
        ])
        context.restoreGState()
    }

    override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
}

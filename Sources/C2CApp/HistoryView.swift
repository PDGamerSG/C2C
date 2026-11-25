import AppKit
import C2CCore

@MainActor
final class HistoryViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate, NSMenuDelegate {
    enum SelectionUpdate {
        case firstResult
        case revealSelection
        case keepScrollPosition
    }

    private let store: ClipStoreProtocol
    private let pasteCoordinator: PasteCoordinator
    private let onSettings: () -> Void
    private var filtered: [Clip] = []
    private var selectedClip: Clip?
    private var selectedGroup: String?
    private var pinnedOnly = false
    private var previewVisible = false

    private let searchField = NSSearchField()
    private let tableView = HistoryTableView()
    private let preview = NSTextView()
    private let previewScroll = NSScrollView()
    private let imagePreview = NSImageView()
    private var previewHeight: NSLayoutConstraint!
    private let emptyLabel = NSTextField(wrappingLabelWithString: "")
    private var moreButton: NSButton!
    private var previewButton: NSButton!

    init(store: ClipStoreProtocol, pasteCoordinator: PasteCoordinator, onSettings: @escaping () -> Void) {
        self.store = store
        self.pasteCoordinator = pasteCoordinator
        self.onSettings = onSettings
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func loadView() {
        let root = HistoryBackgroundView(frame: NSRect(x: 0, y: 0, width: 400, height: 340))

        let rail = HistoryRailView()
        rail.toolTip = "Drag to move C2C"
        let closeButton = HistoryAppearance.button(symbol: "xmark", label: "Close history", target: self, action: #selector(closeHistory))
        previewButton = HistoryAppearance.button(symbol: "chevron.right.2", label: "Show preview", target: self, action: #selector(togglePreview))
        rail.addSubview(closeButton)
        rail.addSubview(previewButton)

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.scrollerStyle = .overlay
        scroll.borderType = .noBorder
        scroll.drawsBackground = false
        scroll.contentInsets = .init()
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("clip"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.style = .plain
        tableView.rowHeight = 36
        tableView.intercellSpacing = .zero
        tableView.backgroundColor = HistoryAppearance.background
        tableView.gridStyleMask = []
        tableView.focusRingType = .none
        tableView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        tableView.selectionHighlightStyle = .regular
        tableView.allowsEmptySelection = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.target = self
        tableView.doubleAction = #selector(pasteSelectedFromDoubleClick)
        tableView.onKeyDown = { [weak self] event in self?.handleKey(event) ?? false }
        tableView.setAccessibilityLabel("Clipboard history")
        let contextMenu = NSMenu()
        contextMenu.delegate = self
        tableView.menu = contextMenu
        scroll.documentView = tableView

        let footer = HistoryBackgroundView()
        footer.fillColor = HistoryAppearance.stripe
        let documentIcon = NSImageView(image: NSImage(systemSymbolName: "doc", accessibilityDescription: nil) ?? NSImage())
        documentIcon.contentTintColor = HistoryAppearance.secondary
        searchField.placeholderString = "Search"
        searchField.font = .systemFont(ofSize: 14)
        searchField.focusRingType = .none
        searchField.isBezeled = false
        searchField.isBordered = false
        searchField.drawsBackground = false
        searchField.sendsSearchStringImmediately = true
        searchField.delegate = self
        searchField.setAccessibilityLabel("Search clipboard history")
        (searchField.cell as? NSSearchFieldCell)?.searchButtonCell = nil
        moreButton = HistoryAppearance.button(symbol: "ellipsis", label: "History options", target: self, action: #selector(showOptions))
        [documentIcon, searchField, moreButton!].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            footer.addSubview($0)
        }

        preview.isEditable = false
        preview.isRichText = false
        preview.drawsBackground = true
        preview.backgroundColor = HistoryAppearance.stripe
        preview.font = .systemFont(ofSize: 12)
        preview.textColor = HistoryAppearance.text
        preview.textContainerInset = NSSize(width: 12, height: 10)
        preview.autoresizingMask = [.width]
        preview.isVerticallyResizable = true
        preview.isHorizontallyResizable = false
        preview.textContainer?.widthTracksTextView = true
        previewScroll.documentView = preview
        previewScroll.borderType = .noBorder
        previewScroll.hasVerticalScroller = true
        previewScroll.scrollerStyle = .overlay
        previewScroll.isHidden = true
        imagePreview.identifier = NSUserInterfaceItemIdentifier("imagePreview")
        imagePreview.imageScaling = .scaleProportionallyUpOrDown
        imagePreview.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        imagePreview.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        imagePreview.setAccessibilityLabel("Clipboard image preview")
        imagePreview.isHidden = true

        emptyLabel.font = .systemFont(ofSize: 13)
        emptyLabel.textColor = HistoryAppearance.secondary
        emptyLabel.alignment = .center
        [scroll, previewScroll, imagePreview, footer, rail, emptyLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            root.addSubview($0)
        }
        previewHeight = previewScroll.heightAnchor.constraint(equalToConstant: 0)
        NSLayoutConstraint.activate([
            rail.topAnchor.constraint(equalTo: root.topAnchor),
            rail.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            rail.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            rail.widthAnchor.constraint(equalToConstant: 26),
            closeButton.topAnchor.constraint(equalTo: rail.topAnchor),
            closeButton.leadingAnchor.constraint(equalTo: rail.leadingAnchor),
            closeButton.trailingAnchor.constraint(equalTo: rail.trailingAnchor),
            closeButton.heightAnchor.constraint(equalToConstant: 36),
            previewButton.topAnchor.constraint(equalTo: closeButton.bottomAnchor),
            previewButton.leadingAnchor.constraint(equalTo: rail.leadingAnchor),
            previewButton.trailingAnchor.constraint(equalTo: rail.trailingAnchor),
            previewButton.heightAnchor.constraint(equalToConstant: 30),
            scroll.topAnchor.constraint(equalTo: root.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: rail.leadingAnchor),
            scroll.bottomAnchor.constraint(equalTo: previewScroll.topAnchor),
            previewScroll.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            previewScroll.trailingAnchor.constraint(equalTo: rail.leadingAnchor),
            previewScroll.bottomAnchor.constraint(equalTo: footer.topAnchor),
            previewHeight,
            imagePreview.leadingAnchor.constraint(equalTo: previewScroll.leadingAnchor, constant: 8),
            imagePreview.trailingAnchor.constraint(equalTo: previewScroll.trailingAnchor, constant: -8),
            imagePreview.topAnchor.constraint(equalTo: previewScroll.topAnchor),
            imagePreview.bottomAnchor.constraint(equalTo: previewScroll.bottomAnchor),
            footer.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            footer.trailingAnchor.constraint(equalTo: rail.leadingAnchor),
            footer.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            footer.heightAnchor.constraint(equalToConstant: 38),
            documentIcon.leadingAnchor.constraint(equalTo: footer.leadingAnchor, constant: 8),
            documentIcon.centerYAnchor.constraint(equalTo: footer.centerYAnchor),
            documentIcon.widthAnchor.constraint(equalToConstant: 18),
            documentIcon.heightAnchor.constraint(equalToConstant: 22),
            searchField.leadingAnchor.constraint(equalTo: documentIcon.trailingAnchor, constant: 8),
            searchField.centerYAnchor.constraint(equalTo: footer.centerYAnchor),
            searchField.heightAnchor.constraint(equalToConstant: 24),
            searchField.trailingAnchor.constraint(equalTo: moreButton.leadingAnchor, constant: -4),
            moreButton.trailingAnchor.constraint(equalTo: footer.trailingAnchor, constant: -5),
            moreButton.centerYAnchor.constraint(equalTo: footer.centerYAnchor),
            moreButton.widthAnchor.constraint(equalToConstant: 30),
            moreButton.heightAnchor.constraint(equalToConstant: 28),
            emptyLabel.centerXAnchor.constraint(equalTo: scroll.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: scroll.centerYAnchor),
            emptyLabel.widthAnchor.constraint(lessThanOrEqualTo: scroll.widthAnchor, constant: -48)
        ])
        view = root
        reload()
    }

    func focusSearch() { view.window?.makeFirstResponder(searchField) }

    func prepareForOpening() {
        searchField.abortEditing()
        searchField.stringValue = ""
        reload(selection: .firstResult)
    }

    func reload(selection: SelectionUpdate = .revealSelection) {
        _ = store.removeExpired()
        applyFilter(selection: selection)
    }

    private func applyFilter(selection: SelectionUpdate) {
        let previousRow = tableView.selectedRow
        let selectedID = selection == .firstResult ? nil : selectedClip?.id
        let fallbackRow = selection == .firstResult ? 0 : max(0, previousRow)
        let revealSelection = selection != .keepScrollPosition || previousRow < 0 ||
            tableView.visibleRect.intersects(tableView.rect(ofRow: previousRow))
        filtered = store.search(searchField.stringValue, groupName: selectedGroup).filter { !pinnedOnly || $0.isPinned }
        tableView.reloadData()
        emptyLabel.isHidden = !filtered.isEmpty
        emptyLabel.stringValue = !searchField.stringValue.isEmpty ? "No matching messages." :
            (pinnedOnly ? "No pinned messages yet.\nUse the pin beside a message to keep it." :
                (selectedGroup == nil ? "Copy something to start your history." : "No messages in this group."))
        if !filtered.isEmpty {
            let row = filtered.firstIndex { $0.id == selectedID } ?? min(fallbackRow, filtered.count - 1)
            tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            if revealSelection { tableView.scrollRowToVisible(row) }
        } else {
            tableView.deselectAll(nil)
        }
        updateSelection()
        moreButton.toolTip = "\(filtered.count) messages · History options"
    }

    func controlTextDidChange(_ obj: Notification) { applyFilter(selection: .firstResult) }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector {
        case #selector(NSResponder.moveDown(_:)):
            moveSelection(by: 1)
        case #selector(NSResponder.moveUp(_:)):
            moveSelection(by: -1)
        case #selector(NSResponder.insertNewline(_:)):
            pasteSelected(plainText: NSApp.currentEvent?.modifierFlags.contains(.command) == true)
        case #selector(NSResponder.cancelOperation(_:)):
            closeHistory()
        default: return false
        }
        return true
    }

    private func moveSelection(by offset: Int) {
        guard !filtered.isEmpty else { return }
        let row = min(max(tableView.selectedRow + offset, 0), filtered.count - 1)
        tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        tableView.scrollRowToVisible(row)
    }

    func numberOfRows(in tableView: NSTableView) -> Int { filtered.count }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        filtered[row].payloads.contains { $0.kind == .image } ? 68 : 36
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let rowView = HistoryRowView()
        rowView.rowIndex = row
        return rowView
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("ClipRow")
        let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? HistoryClipCell ?? HistoryClipCell()
        cell.identifier = identifier
        let clip = filtered[row]
        cell.configure(clip: clip, row: row, selected: tableView.selectedRow == row)
        cell.onTogglePin = { [weak self] in
            guard let self else { return }
            self.selectedClip = clip
            self.togglePin()
        }
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) { updateSelection() }

    private func updateSelection() {
        selectedClip = filtered.indices.contains(tableView.selectedRow) ? filtered[tableView.selectedRow] : nil
        imagePreview.image = selectedClip.flatMap { ClipImageRenderer.image(for: $0, maximumPixels: 1_200) }
        updatePreviewVisibility()
        guard let clip = selectedClip else { preview.string = ""; return }
        preview.string = [clip.contentText ?? clip.displayTitle,
                          clip.groupName.map { "Group: \($0)" },
                          clip.sourceBundleID.map { "Source: \($0)" },
                          clip.isPinned ? "Pinned — kept until you unpin it." : nil]
            .compactMap { $0 }.joined(separator: "\n\n")
    }

    @objc private func pasteSelectedFromDoubleClick() { pasteSelected(plainText: false) }

    private func pasteSelected(plainText: Bool) {
        guard let clip = selectedClip else { return }
        view.window?.orderOut(nil)
        pasteCoordinator.paste(clip: clip, plainText: plainText)
        store.recordPaste(clip.id)
    }

    private func handleKey(_ event: NSEvent) -> Bool {
        switch event.keyCode {
        case 36, 76: pasteSelected(plainText: event.modifierFlags.contains(.command))
        case 49: togglePin()
        case 51, 117: deleteSelected()
        case 53: closeHistory()
        default: return false
        }
        return true
    }

    override func cancelOperation(_ sender: Any?) { closeHistory() }
    @objc private func closeHistory() { view.window?.orderOut(nil) }

    @objc private func togglePin() {
        guard let clip = selectedClip else { return }
        store.setPinned(clip.id, pinned: !clip.isPinned)
        reload()
    }

    @objc private func deleteSelected() {
        guard let clip = selectedClip, !clip.isPinned else { return }
        store.delete(clip.id)
        reload()
    }

    @objc private func togglePreview() {
        previewVisible.toggle()
        updatePreviewVisibility()
        let label = previewVisible ? "Hide preview" : "Show preview"
        previewButton.image = NSImage(systemSymbolName: previewVisible ? "chevron.left.2" : "chevron.right.2", accessibilityDescription: label)
        previewButton.toolTip = label
        previewButton.setAccessibilityLabel(label)
    }

    private func updatePreviewVisibility() {
        let hasImage = imagePreview.image != nil
        previewHeight.constant = previewVisible ? (hasImage ? 140 : 90) : 0
        previewScroll.isHidden = !previewVisible || hasImage
        imagePreview.isHidden = !previewVisible || !hasImage
    }

    @objc private func showOptions() {
        let menu = NSMenu()
        menuNeedsUpdate(menu)
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: moreButton.bounds.height), in: moreButton)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        menu.autoenablesItems = false
        func add(_ title: String, _ action: Selector?, enabled: Bool = true) -> NSMenuItem {
            let item = menu.addItem(withTitle: title, action: action, keyEquivalent: "")
            item.target = self
            item.isEnabled = enabled
            return item
        }
        let hasSelection = selectedClip != nil
        _ = add(selectedClip?.isPinned == true ? "Unpin message" : "Pin message", #selector(togglePin), enabled: hasSelection)
        _ = add(selectedClip?.isPinned == true ? "Unpin to delete" : "Delete message", #selector(deleteSelected), enabled: hasSelection && selectedClip?.isPinned == false)
        _ = add("Assign group…", #selector(assignGroup), enabled: hasSelection)
        menu.addItem(.separator())
        let pinFilter = add("Pinned messages only", #selector(togglePinnedFilter))
        pinFilter.state = pinnedOnly ? .on : .off
        let groups = NSMenu()
        let allGroups = groups.addItem(withTitle: "All groups", action: #selector(selectGroup(_:)), keyEquivalent: "")
        allGroups.target = self
        allGroups.state = selectedGroup == nil ? .on : .off
        for group in Set(store.list().compactMap(\.groupName)).sorted() {
            let item = groups.addItem(withTitle: group, action: #selector(selectGroup(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = group
            item.state = selectedGroup == group ? .on : .off
        }
        add(selectedGroup ?? "All groups", nil).submenu = groups
        menu.addItem(.separator())
        _ = add("Unpinned messages expire after 30 days", nil, enabled: false)
        _ = add("Settings…", #selector(openSettings))
    }

    @objc private func togglePinnedFilter() {
        pinnedOnly.toggle()
        applyFilter(selection: .firstResult)
    }

    @objc private func selectGroup(_ sender: NSMenuItem) {
        selectedGroup = sender.representedObject as? String
        applyFilter(selection: .firstResult)
    }

    @objc private func assignGroup() {
        guard let clip = selectedClip else { return }
        let alert = NSAlert()
        alert.messageText = "Assign group"
        let field = NSTextField(string: clip.groupName ?? "")
        field.frame = NSRect(x: 0, y: 0, width: 240, height: 24)
        alert.accessoryView = field
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let value = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        store.setGroup(clip.id, groupName: value.isEmpty ? nil : value)
        reload()
    }

    @objc private func openSettings() { onSettings() }
}

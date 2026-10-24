import AppKit
import C2CCore

@MainActor
final class HistoryTableView: NSTableView {
    var onKeyDown: ((NSEvent) -> Void)?
    override func keyDown(with event: NSEvent) { onKeyDown?(event) }
}

@MainActor
final class HistoryViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {
    private let store: ClipStoreProtocol
    private let pasteCoordinator: PasteCoordinator
    private let onSettings: () -> Void
    private var clips: [Clip] = []
    private var filtered: [Clip] = []
    private var selectedClip: Clip?

    private let searchField = NSSearchField()
    private let groupFilter = NSPopUpButton()
    private let tableView = HistoryTableView()
    private let preview = NSTextView()
    private let countLabel = NSTextField(labelWithString: "")
    private let pinButton = NSButton(title: "Pin", target: nil, action: nil)
    private let deleteButton = NSButton(title: "Delete", target: nil, action: nil)
    private let groupButton = NSButton(title: "Group…", target: nil, action: nil)
    private let settingsButton = NSButton(title: "⚙", target: nil, action: nil)

    init(store: ClipStoreProtocol, pasteCoordinator: PasteCoordinator, onSettings: @escaping () -> Void) {
        self.store = store
        self.pasteCoordinator = pasteCoordinator
        self.onSettings = onSettings
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func loadView() {
        let root = NSView()
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.97).cgColor
        root.layer?.cornerRadius = 14
        root.layer?.masksToBounds = true

        searchField.placeholderString = "Search clipboard history"
        searchField.focusRingType = .none
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.delegate = self
        root.addSubview(searchField)

        groupFilter.translatesAutoresizingMaskIntoConstraints = false
        groupFilter.bezelStyle = .rounded
        groupFilter.controlSize = .small
        groupFilter.target = self
        groupFilter.action = #selector(groupChanged)
        root.addSubview(groupFilter)

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("clip"))
        column.title = "Clipboard"
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.rowHeight = 42
        tableView.backgroundColor = .clear
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.selectionHighlightStyle = .regular
        tableView.delegate = self
        tableView.dataSource = self
        tableView.target = self
        tableView.doubleAction = #selector(pasteSelectedFromDoubleClick)
        tableView.onKeyDown = { [weak self] event in self?.handleKey(event) }
        scroll.documentView = tableView
        root.addSubview(scroll)

        preview.isEditable = false
        preview.isRichText = false
        preview.drawsBackground = false
        preview.focusRingType = .none
        preview.font = .systemFont(ofSize: 12)
        preview.textColor = .secondaryLabelColor
        preview.textContainerInset = NSSize(width: 10, height: 8)
        preview.translatesAutoresizingMaskIntoConstraints = false
        preview.wantsLayer = true
        preview.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.55).cgColor
        preview.layer?.cornerRadius = 8
        root.addSubview(preview)

        countLabel.textColor = .tertiaryLabelColor
        countLabel.font = .systemFont(ofSize: 11)

        [groupButton, pinButton, deleteButton, settingsButton].forEach {
            $0.isBordered = false
            $0.bezelStyle = .inline
            $0.controlSize = .small
            $0.contentTintColor = .secondaryLabelColor
            $0.font = .systemFont(ofSize: 11)
        }
        groupButton.target = self
        groupButton.action = #selector(assignGroup)
        pinButton.target = self
        pinButton.action = #selector(togglePin)
        deleteButton.target = self
        deleteButton.action = #selector(deleteSelected)
        settingsButton.target = self
        settingsButton.action = #selector(openSettings)

        let footer = NSStackView(views: [countLabel, NSView(), groupButton, pinButton, deleteButton, settingsButton])
        footer.orientation = .horizontal
        footer.alignment = .centerY
        footer.spacing = 4
        footer.translatesAutoresizingMaskIntoConstraints = false
        footer.arrangedSubviews[1].setContentHuggingPriority(.defaultLow, for: .horizontal)
        root.addSubview(footer)

        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: root.topAnchor, constant: 12),
            searchField.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            searchField.trailingAnchor.constraint(equalTo: groupFilter.leadingAnchor, constant: -8),
            searchField.heightAnchor.constraint(equalToConstant: 30),
            groupFilter.topAnchor.constraint(equalTo: searchField.topAnchor),
            groupFilter.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            groupFilter.widthAnchor.constraint(equalToConstant: 118),
            scroll.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 8),
            scroll.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 10),
            scroll.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -10),
            scroll.bottomAnchor.constraint(equalTo: preview.topAnchor, constant: -8),
            preview.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 10),
            preview.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -10),
            preview.heightAnchor.constraint(equalToConstant: 72),
            footer.topAnchor.constraint(equalTo: preview.bottomAnchor, constant: 6),
            footer.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            footer.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -10),
            footer.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -8),
            footer.heightAnchor.constraint(equalToConstant: 22)
        ])
        view = root
        reload()
    }

    func focusSearch() {
        guard let window = view.window else { return }
        window.makeFirstResponder(searchField)
    }

    func reload() {
        let selectedGroup = groupFilter.titleOfSelectedItem
        clips = store.list()
        let groups = Set(clips.compactMap(\.groupName)).sorted()
        groupFilter.removeAllItems()
        groupFilter.addItem(withTitle: "All groups")
        groupFilter.addItems(withTitles: groups)
        if let selectedGroup, groupFilter.itemTitles.contains(selectedGroup) { groupFilter.selectItem(withTitle: selectedGroup) }
        applyFilter()
    }

    private func applyFilter() {
        let query = searchField.stringValue
        let group = groupFilter.indexOfSelectedItem > 0 ? groupFilter.titleOfSelectedItem : nil
        filtered = store.search(query, groupName: group)
        tableView.reloadData()
        countLabel.stringValue = "\(filtered.count)"
        if let selected = selectedClip, let row = filtered.firstIndex(where: { $0.id == selected.id }) {
            tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            tableViewSelectionDidChange(Notification(name: NSTableView.selectionDidChangeNotification))
        } else if !filtered.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            tableViewSelectionDidChange(Notification(name: NSTableView.selectionDidChangeNotification))
        } else {
            preview.string = ""
            selectedClip = nil
        }
    }

    func controlTextDidChange(_ obj: Notification) { applyFilter() }
    @objc private func groupChanged() { applyFilter() }
    func numberOfRows(in tableView: NSTableView) -> Int { filtered.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("ClipRow")
        let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView ?? {
            let cell = NSTableCellView()
            cell.identifier = identifier
            let label = NSTextField(labelWithString: "")
            label.font = .systemFont(ofSize: 13)
            label.lineBreakMode = .byTruncatingTail
            label.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(label)
            cell.textField = label
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
                label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
                label.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
            return cell
        }()
        let clip = filtered[row]
        cell.textField?.stringValue = "\(clip.isPinned ? "★ " : "")\(clip.displayTitle)"
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = tableView.selectedRow
        guard filtered.indices.contains(row) else { return }
        selectedClip = filtered[row]
        let clip = filtered[row]
        let details = [clip.contentText, clip.groupName.map { "Group: \($0)" }, clip.sourceBundleID.map { "Source: \($0)" }].compactMap { $0 }.joined(separator: "\n\n")
        preview.string = details.isEmpty ? clip.displayTitle : details
        pinButton.title = clip.isPinned ? "Unpin" : "Pin"
    }

    @objc private func pasteSelectedFromDoubleClick() { pasteSelected(plainText: false) }
    private func pasteSelected(plainText: Bool) {
        guard let clip = selectedClip else { return }
        pasteCoordinator.paste(clip: clip, plainText: plainText)
        store.recordPaste(clip.id)
        view.window?.orderOut(nil)
    }

    private func handleKey(_ event: NSEvent) {
        switch event.keyCode {
        case 36, 76: pasteSelected(plainText: event.modifierFlags.contains(.command))
        case 49: togglePin()
        case 51, 117: deleteSelected()
        case 53: view.window?.orderOut(nil)
        default: break
        }
    }

    override func cancelOperation(_ sender: Any?) { view.window?.orderOut(nil) }

    @objc private func togglePin() {
        guard let clip = selectedClip else { return }
        store.setPinned(clip.id, pinned: !clip.isPinned)
        reload()
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

    @objc private func deleteSelected() {
        guard let clip = selectedClip else { return }
        store.delete(clip.id)
        reload()
    }

    @objc private func openSettings() { onSettings() }
}

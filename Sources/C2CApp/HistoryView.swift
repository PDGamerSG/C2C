import AppKit
import C2CCore

@MainActor
final class HistoryTableView: NSTableView {
    var onKeyDown: ((NSEvent) -> Void)?
    override func keyDown(with event: NSEvent) { onKeyDown?(event) }
}

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

        searchField.placeholderString = "Search clipboard history"
        searchField.delegate = self
        searchField.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(searchField)

        groupFilter.translatesAutoresizingMaskIntoConstraints = false
        groupFilter.target = self
        groupFilter.action = #selector(groupChanged)
        root.addSubview(groupFilter)

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("clip"))
        column.title = "Clipboard"
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.rowHeight = 56
        tableView.delegate = self
        tableView.dataSource = self
        tableView.target = self
        tableView.doubleAction = #selector(pasteSelectedFromDoubleClick)
        tableView.onKeyDown = { [weak self] event in self?.handleKey(event) }
        tableView.usesAlternatingRowBackgroundColors = true
        scroll.documentView = tableView
        root.addSubview(scroll)

        preview.isEditable = false
        preview.isRichText = false
        preview.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        preview.backgroundColor = NSColor.textBackgroundColor
        preview.textContainerInset = NSSize(width: 12, height: 12)
        preview.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(preview)

        countLabel.textColor = .secondaryLabelColor
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(countLabel)

        pinButton.target = self
        pinButton.action = #selector(togglePin)
        pinButton.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(pinButton)
        deleteButton.target = self
        deleteButton.action = #selector(deleteSelected)
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(deleteButton)
        groupButton.target = self
        groupButton.action = #selector(assignGroup)
        groupButton.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(groupButton)

        let settings = NSButton(title: "Settings…", target: self, action: #selector(openSettings))
        settings.bezelStyle = .rounded
        settings.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(settings)

        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: root.topAnchor, constant: 16),
            searchField.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 16),
            searchField.trailingAnchor.constraint(equalTo: groupFilter.leadingAnchor, constant: -8),
            groupFilter.topAnchor.constraint(equalTo: searchField.topAnchor),
            groupFilter.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -16),
            groupFilter.widthAnchor.constraint(equalToConstant: 150),
            scroll.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 12),
            scroll.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 16),
            scroll.widthAnchor.constraint(equalTo: root.widthAnchor, multiplier: 0.53),
            scroll.bottomAnchor.constraint(equalTo: countLabel.topAnchor, constant: -12),
            preview.topAnchor.constraint(equalTo: scroll.topAnchor),
            preview.leadingAnchor.constraint(equalTo: scroll.trailingAnchor, constant: 12),
            preview.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -16),
            preview.bottomAnchor.constraint(equalTo: scroll.bottomAnchor),
            countLabel.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 16),
            countLabel.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -14),
            groupButton.trailingAnchor.constraint(equalTo: pinButton.leadingAnchor, constant: -8),
            groupButton.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -10),
            pinButton.trailingAnchor.constraint(equalTo: deleteButton.leadingAnchor, constant: -8),
            pinButton.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -10),
            deleteButton.trailingAnchor.constraint(equalTo: settings.leadingAnchor, constant: -8),
            deleteButton.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -10),
            settings.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -16),
            settings.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -10)
        ])
        view = root
        reload()
    }

    func reload() {
        clips = store.list()
        let groups = Set(clips.compactMap(\.groupName)).sorted()
        groupFilter.removeAllItems()
        groupFilter.addItem(withTitle: "All groups")
        groupFilter.addItems(withTitles: groups)
        applyFilter()
    }

    private func applyFilter() {
        let query = searchField.stringValue
        let group = groupFilter.indexOfSelectedItem > 0 ? groupFilter.titleOfSelectedItem : nil
        filtered = store.search(query, groupName: group)
        tableView.reloadData()
        countLabel.stringValue = "\(filtered.count) clips"
        if let selected = selectedClip, let row = filtered.firstIndex(where: { $0.id == selected.id }) { tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false) }
        else if !filtered.isEmpty { tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false); tableViewSelectionDidChange(Notification(name: NSTableView.selectionDidChangeNotification)) }
        else { preview.string = ""; selectedClip = nil }
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
                label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 10),
                label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -10),
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

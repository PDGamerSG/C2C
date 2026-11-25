import AppKit
import C2CCore

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private let dataManagement: DataManagementController
    private var settings: AppSettings
    private let onSave: (AppSettings) throws -> Void
    private let onAppearanceChange: (AppAppearance) throws -> Void
    private var aboutWindow: NSWindowController?
    private let limitField = NSTextField(string: "500")
    private let shortcutField = ShortcutRecorderField(string: "⌘⇧V")
    private var pendingHotKeyKeyCode: UInt16
    private var pendingHotKeyModifiers: UInt
    private let plainText = NSButton(checkboxWithTitle: "Paste as plain text by default", target: nil, action: nil)
    private let launch = NSButton(checkboxWithTitle: "Launch C2C at login", target: nil, action: nil)
    private let excludedField = NSTextField(string: "")
    private let appearancePicker = NSPopUpButton()
    private let errorLabel = NSTextField(wrappingLabelWithString: "")

    init(settings: AppSettings, store: ClipStoreProtocol, onRecordingChange: @escaping (Bool) -> Void, onAppearanceChange: @escaping (AppAppearance) throws -> Void, onSave: @escaping (AppSettings) throws -> Void) {
        self.settings = settings
        self.pendingHotKeyKeyCode = settings.hotKeyKeyCode
        self.pendingHotKeyModifiers = settings.hotKeyModifiers
        self.dataManagement = DataManagementController(store: store)
        self.onSave = onSave
        self.onAppearanceChange = onAppearanceChange
        let content = NSViewController()
        let window = NSWindow(contentViewController: content)
        window.title = "C2C Settings"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 500, height: 560))
        super.init(window: window)
        window.delegate = self
        shortcutField.onRecordingChange = onRecordingChange
        buildView(content)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func buildView(_ controller: NSViewController) {
        let root = HistoryBackgroundView(frame: NSRect(x: 0, y: 0, width: 500, height: 560))
        root.fillColor = .windowBackgroundColor
        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 24, left: 28, bottom: 24, right: 28)

        let heading = NSTextField(labelWithString: "C2C Clipboard Settings")
        heading.font = .systemFont(ofSize: 20, weight: .semibold)
        stack.addArrangedSubview(heading)
        stack.addArrangedSubview(NSTextField(labelWithString: "Appearance"))
        appearancePicker.addItems(withTitles: ["Light", "Dark", "System"])
        appearancePicker.selectItem(at: AppAppearance.allCases.firstIndex(of: settings.appearance) ?? 0)
        appearancePicker.setAccessibilityLabel("Appearance")
        appearancePicker.identifier = NSUserInterfaceItemIdentifier("appearancePicker")
        appearancePicker.isBordered = false
        appearancePicker.target = self
        appearancePicker.action = #selector(appearanceChanged)
        stack.addArrangedSubview(appearancePicker)
        stack.addArrangedSubview(NSTextField(labelWithString: "History limit"))
        limitField.stringValue = "\(settings.retentionLimit)"
        limitField.widthAnchor.constraint(equalToConstant: 100).isActive = true
        stack.addArrangedSubview(limitField)
        let retentionNote = NSTextField(wrappingLabelWithString: "Unpinned messages expire 30 days after they are saved. Pinned messages are kept until you unpin them, even when the history limit is reached.")
        retentionNote.font = .systemFont(ofSize: 11)
        retentionNote.textColor = .secondaryLabelColor
        retentionNote.widthAnchor.constraint(equalToConstant: 420).isActive = true
        stack.addArrangedSubview(retentionNote)
        stack.addArrangedSubview(NSTextField(labelWithString: "Open clipboard shortcut"))
        shortcutField.stringValue = settings.hotKeyDescription
        shortcutField.placeholderString = "Press a shortcut…"
        shortcutField.widthAnchor.constraint(equalToConstant: 180).isActive = true
        shortcutField.onShortcut = { [weak self] keyCode, modifiers, description in
            self?.pendingHotKeyKeyCode = keyCode
            self?.pendingHotKeyModifiers = modifiers.rawValue
            self?.shortcutField.stringValue = description
        }
        stack.addArrangedSubview(shortcutField)
        let shortcutHint = NSTextField(labelWithString: "Click the shortcut, press your keys, then Save to apply.")
        shortcutHint.font = .systemFont(ofSize: 11)
        shortcutHint.textColor = .secondaryLabelColor
        stack.addArrangedSubview(shortcutHint)
        stack.addArrangedSubview(plainText)
        plainText.state = settings.plainTextPasteByDefault ? .on : .off
        stack.addArrangedSubview(launch)
        launch.state = settings.launchAtLogin ? .on : .off
        stack.addArrangedSubview(NSTextField(labelWithString: "Excluded bundle IDs (comma separated)"))
        excludedField.stringValue = settings.excludedBundleIDs.sorted().joined(separator: ",")
        excludedField.widthAnchor.constraint(equalToConstant: 420).isActive = true
        stack.addArrangedSubview(excludedField)
        [limitField, shortcutField, excludedField].forEach {
            $0.isBezeled = false
            $0.isBordered = false
            $0.backgroundColor = .controlBackgroundColor
        }

        let buttons = NSStackView()
        buttons.spacing = 8
        let save = NSButton(title: "Save", target: self, action: #selector(saveSettings))
        let export = NSButton(title: "Export…", target: self, action: #selector(exportData))
        let `import` = NSButton(title: "Import…", target: self, action: #selector(importData))
        let about = NSButton(title: "About & Credits", target: self, action: #selector(showAbout))
        [save, export, `import`, about].forEach {
            $0.isBordered = false
            buttons.addArrangedSubview($0)
        }
        stack.addArrangedSubview(buttons)
        errorLabel.textColor = .systemRed
        errorLabel.font = .systemFont(ofSize: 11)
        errorLabel.widthAnchor.constraint(equalToConstant: 420).isActive = true
        errorLabel.identifier = NSUserInterfaceItemIdentifier("settingsError")
        errorLabel.isHidden = true
        stack.addArrangedSubview(errorLabel)
        root.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: root.topAnchor),
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: root.bottomAnchor)
        ])
        controller.view = root
    }

    @objc private func saveSettings() {
        window?.makeFirstResponder(nil)
        let limit = max(1, Int(limitField.stringValue) ?? settings.retentionLimit)
        let excluded = Set(excludedField.stringValue.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
        var candidate = settings
        candidate.retentionLimit = limit
        candidate.excludedBundleIDs = excluded
        candidate.plainTextPasteByDefault = plainText.state == .on
        candidate.hotKeyKeyCode = pendingHotKeyKeyCode
        candidate.hotKeyModifiers = pendingHotKeyModifiers
        candidate.hotKeyDescription = shortcutField.stringValue
        candidate.launchAtLogin = launch.state == .on
        candidate.appearance = AppAppearance.allCases[appearancePicker.indexOfSelectedItem]
        do {
            try onSave(candidate)
            settings = candidate
            errorLabel.isHidden = true
            close()
        } catch {
            showError(error.localizedDescription)
        }
    }

    @objc private func appearanceChanged() {
        let appearance = AppAppearance.allCases[appearancePicker.indexOfSelectedItem]
        do {
            try onAppearanceChange(appearance)
            settings.appearance = appearance
            errorLabel.isHidden = true
        } catch {
            appearancePicker.selectItem(at: AppAppearance.allCases.firstIndex(of: settings.appearance) ?? 0)
            showError(error.localizedDescription)
        }
    }

    func showError(_ message: String) {
        errorLabel.stringValue = message
        errorLabel.isHidden = false
    }

    func windowWillClose(_ notification: Notification) {
        window?.makeFirstResponder(nil)
    }

    func windowDidResignKey(_ notification: Notification) {
        if window?.firstResponder === shortcutField { window?.makeFirstResponder(nil) }
    }

    @objc private func exportData() { dataManagement.export(from: window) }
    @objc private func importData() { dataManagement.import(from: window) }

    @objc private func showAbout() {
        aboutWindow = NSWindowController(window: NSWindow(contentViewController: AboutViewController()))
        aboutWindow?.window?.title = "About C2C"
        aboutWindow?.window?.styleMask = [.titled, .closable]
        aboutWindow?.window?.setContentSize(NSSize(width: 420, height: 260))
        aboutWindow?.showWindow(nil)
    }
}

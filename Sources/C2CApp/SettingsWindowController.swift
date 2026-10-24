import AppKit
import C2CCore

@MainActor
final class SettingsWindowController: NSWindowController {
    private let settingsURL: URL
    private let store: ClipStoreProtocol
    private let launchAtLogin: LaunchAtLogin
    private let dataManagement: DataManagementController
    private var settings: AppSettings
    private let onSave: (AppSettings) -> Void
    private var aboutWindow: NSWindowController?
    private let limitField = NSTextField(string: "500")
    private let plainText = NSButton(checkboxWithTitle: "Paste as plain text by default", target: nil, action: nil)
    private let launch = NSButton(checkboxWithTitle: "Launch C2C at login", target: nil, action: nil)
    private let excludedField = NSTextField(string: "")

    init(settingsURL: URL, settings: AppSettings, store: ClipStoreProtocol, launchAtLogin: LaunchAtLogin, onSave: @escaping (AppSettings) -> Void) {
        self.settingsURL = settingsURL
        self.settings = settings
        self.store = store
        self.launchAtLogin = launchAtLogin
        self.dataManagement = DataManagementController(store: store)
        self.onSave = onSave
        let content = NSViewController()
        let window = NSWindow(contentViewController: content)
        window.title = "C2C Settings"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 500, height: 360))
        super.init(window: window)
        buildView(content)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func buildView(_ controller: NSViewController) {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 24, left: 28, bottom: 24, right: 28)

        let heading = NSTextField(labelWithString: "C2C Clipboard Settings")
        heading.font = .systemFont(ofSize: 20, weight: .semibold)
        stack.addArrangedSubview(heading)
        stack.addArrangedSubview(NSTextField(labelWithString: "History limit"))
        limitField.stringValue = "\(settings.retentionLimit)"
        limitField.widthAnchor.constraint(equalToConstant: 100).isActive = true
        stack.addArrangedSubview(limitField)
        stack.addArrangedSubview(plainText)
        plainText.state = settings.plainTextPasteByDefault ? .on : .off
        stack.addArrangedSubview(launch)
        launch.state = settings.launchAtLogin ? .on : .off
        stack.addArrangedSubview(NSTextField(labelWithString: "Excluded bundle IDs (comma separated)"))
        excludedField.stringValue = settings.excludedBundleIDs.sorted().joined(separator: ",")
        excludedField.widthAnchor.constraint(equalToConstant: 420).isActive = true
        stack.addArrangedSubview(excludedField)

        let buttons = NSStackView()
        buttons.spacing = 8
        let save = NSButton(title: "Save", target: self, action: #selector(saveSettings))
        let export = NSButton(title: "Export…", target: self, action: #selector(exportData))
        let `import` = NSButton(title: "Import…", target: self, action: #selector(importData))
        let about = NSButton(title: "About & Credits", target: self, action: #selector(showAbout))
        [save, export, `import`, about].forEach(buttons.addArrangedSubview)
        stack.addArrangedSubview(buttons)
        controller.view = stack
    }

    @objc private func saveSettings() {
        let limit = max(1, Int(limitField.stringValue) ?? settings.retentionLimit)
        let excluded = Set(excludedField.stringValue.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
        settings.retentionLimit = limit
        settings.excludedBundleIDs = excluded
        settings.plainTextPasteByDefault = plainText.state == .on
        settings.launchAtLogin = launch.state == .on
        store.retentionLimit = limit
        launchAtLogin.setEnabled(settings.launchAtLogin)
        if let data = try? JSONEncoder().encode(settings) { try? data.write(to: settingsURL, options: .atomic) }
        onSave(settings)
        close()
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

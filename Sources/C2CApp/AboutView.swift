import AppKit

@MainActor
final class AboutViewController: NSViewController {
    override func loadView() {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 24, left: 28, bottom: 24, right: 28)
        let title = NSTextField(labelWithString: "C2C")
        title.font = .systemFont(ofSize: 28, weight: .bold)
        let subtitle = NSTextField(labelWithString: "A local-first clipboard manager for macOS")
        let credits = NSTextField(wrappingLabelWithString: "C2C is an independent macOS port inspired by Ditto Clipboard Manager.\n\nUpstream project: https://github.com/sabrogden/Ditto\nLicensed under the GNU GPL v3. See the included COPYING file.")
        credits.alignment = .center
        credits.maximumNumberOfLines = 0
        stack.addArrangedSubview(title)
        stack.addArrangedSubview(subtitle)
        stack.addArrangedSubview(credits)
        view = stack
    }
}

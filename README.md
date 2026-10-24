# C2C

C2C is a local-first clipboard manager for macOS, inspired by [Ditto Clipboard Manager](https://github.com/sabrogden/Ditto). It keeps a searchable history of copied text, rich text, HTML, images, and files, with pinning, groups, retention limits, export/import, a menu-bar utility, and a global `⌘⇧V` shortcut.

C2C is an independent macOS port. It does not include cloud sync, login, telemetry, or the Windows-specific device protocol. Windows clipboard formats are represented by their macOS UTI equivalents.

## Build

The repository uses Swift Package Manager and requires macOS 13 or newer. With Xcode or the Swift command-line tools installed:

```sh
swift build --product C2C
swift build --product C2CSmoke
.build/debug/C2CSmoke
```

To assemble an application bundle:

```sh
./scripts/build-app.sh
open build/C2C.app
```

The app runs as a menu-bar utility. The first launch starts clipboard capture. Press `⌘⇧V` or click the status item to open history. Selecting a row and pressing Return pastes it; `⌘`-Return can be used for plain text after the panel is open.

## Data and privacy

History is stored locally under `~/Library/Application Support/C2C/clipboard.json`. Settings are stored beside it. Export creates a versioned JSON archive containing payload UTIs and metadata. No network connection is required.

## Credits and license

C2C is inspired by and compatible with the upstream Ditto project's GPLv3 licensing. See [`Resources/NOTICE`](Resources/NOTICE) and [`Resources/COPYING`](Resources/COPYING). The upstream source repository is https://github.com/sabrogden/Ditto.

## Release artifacts

Build a local release bundle and DMG with:

```sh
./scripts/build-dmg.sh
./scripts/system-smoke.sh
```

The DMG is written to `dist/C2C-1.0.0.dmg`. Local builds are ad-hoc signed. For distribution outside the test Mac, set `C2C_SIGNING_IDENTITY` to a Developer ID Application identity and notarize the resulting DMG with Apple before publishing.

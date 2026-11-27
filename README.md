# C2C

C2C is a local-first clipboard manager for macOS and Linux, inspired by [Ditto Clipboard Manager](https://github.com/sabrogden/Ditto). It keeps a searchable history of copied text, rich text, HTML, images, and files, with pinning, groups, retention limits, export/import, a menu-bar utility on macOS, and a desktop history window on Linux.

C2C is an independent port. It does not include cloud sync, login, telemetry, or the Windows-specific device protocol. Windows clipboard formats are represented by their platform equivalents.

## Downloads

The latest release offers a universal DMG for Apple silicon and Intel Macs and separate Linux archives for x86-64 and ARM64. Each release lists the runtime requirements. [GitHub Releases](https://github.com/PDGamerSG/C2C/releases/latest)

## Build on macOS

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

## Build on Linux

Linux uses the GTK4 desktop target and stores data under `$XDG_DATA_HOME/c2c/clipboard.json` and settings under `$XDG_CONFIG_HOME/c2c/settings.json`. Install Swift 6, GTK4 development files, and `pkg-config`, then run:

```sh
sudo apt install libgtk-4-dev pkg-config
./scripts/build-linux.sh
./scripts/linux-smoke.sh
```

The build writes an architecture-specific release archive to `dist/`. C2C uses `wl-clipboard` on supported Wayland compositors and `xclip` on X11 for clipboard access. Paste automation uses `wtype` or `xdotool` where supported. The Linux smoke check requires `xvfb`, `xauth`, `xclip`, and Python 3.

## Data and privacy

Unpinned messages expire **30 days after they were first saved**. Cleanup runs at startup, every minute while C2C is running, after wake, and when history is accessed. Copying or pasting an existing message does not extend its lifetime. The existing configurable history-count limit can remove unpinned items sooner.

**Pinned messages are kept indefinitely**, survive restarts, and are protected from deletion, clearing history, age cleanup, and count limits. Use the pin beside a row (shown on hover or selection), Space when the list is focused, or the context menu. Unpin a message before deleting it; unpinning one older than 30 days removes it immediately.

The compact, borderless history window follows Ditto's list layout: alternating rows, bottom search, and a narrow side strip. Use the bottom ellipsis for pinned-only filtering, groups, and settings; the side chevrons toggle the preview. Arrow keys navigate results while searching. Drag the side strip to move the window.

History opens centered on the screen under the pointer. Clicking another window or switching apps dismisses it; the shortcut opens it again in the center.

History is stored locally under `~/Library/Application Support/C2C/clipboard.json` on macOS or the XDG data directory on Linux. Settings are stored beside it. Export creates a versioned JSON archive containing payload UTIs and metadata. No network connection is required.

## Checks

Settings includes **Appearance → Light / Dark / System**. Appearance changes apply immediately to Settings and clipboard history and are saved automatically. Click the shortcut field, press a combination containing Control, Option, or Command, then click **Save**. C2C registers the shortcut with macOS directly, so opening history does not require Accessibility or Input Monitoring permission. An unavailable combination shows an error and leaves the previous shortcut active. The left and right variants of a modifier key are equivalent. Accessibility permission is still needed to send a paste keystroke into another application.

Copied PNG, TIFF, JPEG, and HEIC images appear as thumbnails in history. Select an image and open the side preview to see a larger version. Image decoding is downsampled and cached; the original captured payload remains available for pasting and export.

Run `./scripts/smoke.sh` for core behavior, pin protection, exact 30-day expiry, import, and on-disk persistence checks. Run `./scripts/ui-smoke.sh` for native AppKit interaction checks and screenshots under `.build/ui-smoke/`. Both use isolated sample data and work with the command-line tools. The XCTest suite (`swift test`) additionally requires a full Xcode installation.

## Credits and license

C2C is inspired by and compatible with the upstream Ditto project's GPLv3 licensing. See [`Resources/NOTICE`](Resources/NOTICE) and [`Resources/COPYING`](Resources/COPYING). The upstream source repository is https://github.com/sabrogden/Ditto.

## Release artifacts

Build a local release bundle and DMG with:

```sh
C2C_MACOS_UNIVERSAL=1 ./scripts/build-dmg.sh
./scripts/system-smoke.sh
```

The universal DMG is written to `dist/C2C-macOS-1.0.2-universal.dmg`. The GitHub DMG is ad-hoc signed. Developer ID distribution requires a `C2C_SIGNING_IDENTITY` and Apple notarization.

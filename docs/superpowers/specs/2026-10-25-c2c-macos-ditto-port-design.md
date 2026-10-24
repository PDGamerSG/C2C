# C2C macOS Clipboard Manager Design

## Goal

C2C is a native macOS clipboard manager inspired by Ditto. It continuously records clipboard entries locally, provides fast search and keyboard-driven selection, and pastes a selected entry into the previously active application.

## Scope

The first runnable release includes:

- Menu-bar resident AppKit application.
- Global shortcut to show/hide the history panel.
- Capture of plain text, rich text/HTML, images, and file URLs from `NSPasteboard`.
- Local persistence with SQLite-compatible storage and JSON fallback for command-line environments.
- Deduplication, pinning, deletion, groups, search, configurable retention limit, and paste statistics.
- Paste to the frontmost application with optional plain-text-only mode.
- Settings for hotkey display, startup behavior, retention, excluded bundle IDs, and data reset.
- Import/export archive and an About/Credits view.

## Platform mapping

Ditto's Win32 tray, clipboard formats, focus hooks, and Windows keyboard injection are mapped to `NSStatusItem`, `NSPasteboard`, AppKit frontmost application tracking, and macOS pasteboard writes. Windows-only custom formats and the original Ditto device protocol are not portable; C2C preserves standard UTI representations and exposes a stable archive format instead.

## Architecture

- `C2CCore`: Swift value types, pasteboard payload serialization, search/deduplication, retention, and persistence protocols.
- `C2CApp`: AppKit application delegate, clipboard monitor, hotkey bridge, store coordinator, status item, popup window, settings, and paste actions.
- `C2CTests`: XCTest coverage for deduplication, search, retention, serialization, and archive round trips.

The store boundary is protocol-based so tests use an in-memory implementation while the app uses a file-backed store under `Application Support/C2C`.

## Data model

A clip has an ID, created/updated timestamps, paste count, pinned flag, optional group ID, source application bundle ID, a primary content kind, and an ordered list of payloads. Payloads contain a UTI and encoded data. Text payloads are UTF-8, images are PNG, and file URLs are security-scoped bookmark-free URL strings in the archive and database.

## UI

The popup uses a dark translucent macOS panel with a search field, segmented group filter, clip list, preview pane, and footer actions. Keyboard commands are Return to paste, Command-Return to paste as plain text, Delete to remove, Space to toggle pin, and Escape to close. Settings and About are separate standard windows.

## Privacy and attribution

C2C is local-first: no login, cloud, or telemetry. The repository includes the upstream Ditto URL, GPLv3 license text, and a clear statement that C2C is an independent macOS port inspired by and compatible with the upstream project's license and attribution requirements.

## Verification

Unit tests cover core behavior. A command-line smoke executable exercises capture, search, persistence, archive export/import, and retention. When a full Xcode installation is available, the same package can be opened in Xcode for AppKit UI and Accessibility testing.

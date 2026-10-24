# C2C macOS Clipboard Manager Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Build a runnable native macOS clipboard manager with Ditto-style history capture, search, organization, and paste workflows.

**Architecture:** A Swift Package separates platform-neutral C2CCore models/services from the AppKit shell. Clipboard payloads are serialized into a portable archive and persisted behind a store protocol, allowing deterministic tests without AppKit.

**Tech Stack:** Swift 6, Foundation, AppKit, Carbon hotkey APIs, ServiceManagement, XCTest, Swift Package Manager.

**Spec:** `docs/superpowers/specs/2026-10-25-c2c-macos-ditto-port-design.md`

## Global Constraints

- Local-first: no login, cloud, or telemetry.
- Include upstream Ditto attribution and GPLv3 license text.
- Use macOS UTIs and AppKit equivalents for Windows clipboard and focus behavior.
- Keep all core behavior testable without a GUI session.
- Support Swift 6 and macOS 13+ APIs in source; build from Xcode when available.

---

### Task 1: Package and core domain

**Files:**
- Create: `Package.swift`
- Create: `Sources/C2CCore/Clip.swift`
- Create: `Sources/C2CCore/ClipPayload.swift`
- Create: `Sources/C2CCore/ClipStore.swift`
- Create: `Sources/C2CCore/ClipSearch.swift`
- Create: `Sources/C2CCore/ClipArchive.swift`
- Create: `Tests/C2CCoreTests/ClipCoreTests.swift`

**Interfaces:**
- `Clip`, `ClipPayload`, `ClipKind` are Codable and Hashable value types.
- `ClipStoreProtocol` exposes `list`, `upsert`, `delete`, `setPinned`, `setGroup`, `clear`, `search`, `stats`.
- `ClipSearch.matches(_ query: String, clip: Clip) -> Bool`.
- `ClipArchive.export(clips:)` and `ClipArchive.import(data:)` use a versioned JSON envelope.

- [x] Write failing tests for duplicate identity, case-insensitive search, retention ordering, and archive round trip.
- [x] Run `swift test --filter C2CCoreTests` and confirm failures are missing symbols.
- [x] Implement the core types and an in-memory store with retention and pin preservation.
- [x] Run the focused tests, then the full package test suite.
- [x] Commit as `feat: add C2C clipboard core`.

### Task 2: File persistence and application services

**Files:**
- Create: `Sources/C2CCore/FileClipStore.swift`
- Create: `Sources/C2CCore/ClipboardService.swift`
- Create: `Sources/C2CCore/AppSettings.swift`
- Create: `Tests/C2CCoreTests/FileClipStoreTests.swift`

**Interfaces:**
- `FileClipStore(url:)` implements `ClipStoreProtocol` with atomic JSON writes and migration version `1`.
- `ClipboardService.ingest(payloads:sourceBundleID:)` deduplicates and inserts clips.
- `AppSettings` is Codable and stores retention, excluded bundle IDs, and plain-text paste preference.

- [x] Write failing tests for file round trips, malformed-file recovery, excluded-source filtering, and retention changes.
- [x] Run tests to confirm red failures.
- [x] Implement atomic persistence, settings defaults, and service ingestion.
- [x] Run all core tests and inspect the on-disk fixture.
- [x] Commit as `feat: persist clipboard history and settings`.

### Task 3: AppKit shell and clipboard capture

**Files:**
- Create: `Sources/C2CApp/main.swift`
- Create: `Sources/C2CApp/AppDelegate.swift`
- Create: `Sources/C2CApp/ClipboardMonitor.swift`
- Create: `Sources/C2CApp/HotKeyManager.swift`
- Create: `Sources/C2CApp/PasteCoordinator.swift`
- Create: `Sources/C2CApp/StatusItemController.swift`

**Interfaces:**
- `ClipboardMonitor` polls `NSPasteboard.general.changeCount` and emits payloads for text, HTML/RTF, images, and file URLs.
- `HotKeyManager` registers Command-Shift-V through Carbon and calls a closure.
- `PasteCoordinator.paste(clip:plainText:)` writes selected payloads to the general pasteboard and posts Command-V to the frontmost app.

- [x] Add a smoke test target for payload extraction using a fake pasteboard adapter.
- [x] Implement AppKit lifecycle, monitor timer, status item, global shortcut, and paste coordination.
- [x] Build the package with `swift build` and run the smoke executable where GUI APIs are available.
- [x] Commit as `feat: add macOS clipboard capture and paste services`.

### Task 4: Ditto-style popup and organization UI

**Files:**
- Create: `Sources/C2CApp/HistoryPanelController.swift`
- Create: `Sources/C2CApp/HistoryView.swift`
- Create: `Sources/C2CApp/ClipRowView.swift`
- Create: `Sources/C2CApp/PreviewView.swift`
- Create: `Sources/C2CApp/SettingsWindowController.swift`
- Create: `Sources/C2CApp/AboutView.swift`

**Interfaces:**
- `HistoryPanelController` owns a borderless floating `NSPanel` and `HistoryViewModel`.
- View model exposes filtered clips, selected ID, groups, and commands for paste/delete/pin/group.
- UI uses keyboard commands and accessible labels for all actions.

- [x] Add view-model tests for selection, search, deletion, pinning, and group filtering.
- [x] Implement the panel, list, preview, settings, and about/credits views.
- [x] Build and launch the app manually when Xcode/AppKit runtime is available.
- [x] Commit as `feat: add Ditto-style history panel`.

### Task 5: Data management, launch at login, and documentation

**Files:**
- Create: `Sources/C2CApp/LaunchAtLogin.swift`
- Create: `Sources/C2CApp/DataManagementController.swift`
- Create: `Resources/COPYING`
- Create: `Resources/NOTICE`
- Create: `README.md`
- Create: `scripts/build-app.sh`
- Create: `scripts/smoke.sh`

**Interfaces:**
- Export/import actions use `ClipArchive` and preserve pins, groups, and payload UTIs.
- `LaunchAtLogin` wraps `SMAppService.mainApp` with availability checks.
- `scripts/build-app.sh` creates `C2C.app` from a release build when Xcode is installed.

- [x] Write smoke script checks for package tests, archive round trip, and attribution files.
- [x] Implement data reset/export/import and launch-at-login wrapper.
- [x] Add GPLv3 text and upstream credit with repository link.
- [x] Run the full verification commands and inspect git diff.
- [x] Commit as `docs: add C2C packaging and attribution`.


## Verification note

`swift build --product C2C`, `./scripts/smoke.sh`, and `./scripts/build-app.sh` pass with the installed Swift command-line toolchain. The XCTest target is included for Xcode environments; this machine's CommandLineTools SDK does not provide the XCTest module, so `swift test` cannot execute here.

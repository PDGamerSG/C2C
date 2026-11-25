# C2C Linux Desktop Design

## Goal

Ship a Linux desktop build of C2C that provides the same local clipboard-history workflow as the macOS application while preserving the existing AppKit application and shared core behavior.

## Scope

The existing `C2CCore` library remains the source of truth for clip models, payloads, search, deduplication, retention, pinning, grouping, statistics, settings, persistence, and archive import/export. The macOS AppKit target is kept intact.

Linux adds a GTK4 desktop target with a compact history window, search, pin/unpin, grouping, preview text, settings, import/export, appearance selection, and clear-history actions. Linux clipboard integration uses the desktop's command-line clipboard tools through a small adapter. Wayland uses `wl-copy` and `wl-paste` when present, while X11 uses `xclip`. Paste delivery uses `wtype` on Wayland and `xdotool` on X11 when available.

Global shortcut behavior is exposed through the Linux desktop target's supported key handling and is reported in the UI. Wayland compositor security prevents a portable process from registering a universal global shortcut or synthesizing paste on every compositor, so the adapter detects unavailable helpers and keeps the history UI and clipboard capture usable.

## Architecture

### Shared core

`C2CCore` remains platform-neutral and receives only Foundation types. No GTK or Linux process APIs are introduced into this target.

### Linux UI bridge

`C2CLinuxGTK` is a small C target that owns GTK4 widgets and emits semantic events to Swift through a callback. Swift owns `C2CCore` stores and translates those events into row updates and mutations. This keeps GTK pointer ownership and signal registration out of the Swift core logic and gives the Linux build a stable, testable boundary.

### Linux adapters

Swift Linux files provide:

- `LinuxClipboardAdapter` for text, HTML, image, and file URI capture through `wl-paste` or `xclip`.
- `LinuxPasteAdapter` for writing payloads through `wl-copy` or `xclip` and sending paste through `wtype` or `xdotool`.
- `LinuxSettingsStore` using the XDG config/data directories.
- `LinuxApplication` for lifecycle, polling, event translation, and archive/settings actions.

The adapters are command-based and fail soft. Missing helpers produce a visible status message and do not corrupt stored history.

## Build and packaging

`Package.swift` gains a `C2CLinux` executable and a `C2CLinuxGTK` C target with a GTK4 `pkg-config` requirement. macOS targets remain available through their existing products. `scripts/build-linux.sh` builds the release executable, creates a desktop entry and icon bundle, and emits `dist/C2C-linux-<version>.tar.gz`. `scripts/linux-smoke.sh` runs core checks, the Linux self-test mode, and a headless GTK launch when `xvfb-run` is installed.

`scripts/build-app.sh` continues to create and verify `build/C2C.app`. The release notes and README describe both build paths, runtime helper requirements, and the Wayland limitation.

## Data flow

1. The Linux poller reads the current clipboard using the detected backend.
2. New payloads go to `ClipboardService.ingest`, which applies exclusions and deduplication.
3. The application requests `store.search` and sends row data to the GTK bridge.
4. GTK events identify a clip UUID and semantic action.
5. Swift applies the core mutation, updates the clipboard or sends paste if requested, then refreshes the visible rows.
6. Settings and archive operations use the existing `AppSettings` and `ClipArchive` Codable representations.

## Verification

- `swift test` and `./scripts/smoke.sh` pass for the shared core.
- `./scripts/build-app.sh` and `./scripts/system-smoke.sh` pass on macOS.
- `./scripts/build-linux.sh` passes with Swift, GTK4 development headers, and `pkg-config`.
- `./scripts/linux-smoke.sh` validates Linux self-test behavior and a headless GTK startup when available.
- Manual desktop checks cover capture, search, pinning, retention, grouping, preview, settings, import/export, paste, and shutdown persistence on at least one X11 or Wayland session.

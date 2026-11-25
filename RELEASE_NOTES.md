# Unreleased

- Added a Linux GTK4 desktop target backed by the shared C2C core.
- Added XDG data and settings paths, Wayland/X11 clipboard adapters, Linux smoke checks, and a portable release archive.
- Kept the existing macOS AppKit application, bundle packaging, and signing flow.

- Custom linked-C application icon and matching menu-bar mark.
- Appearance choices apply immediately to Settings and clipboard history and persist without pressing Save.
- History opens centered on the screen under the pointer and dismisses when another window or app takes focus.
- Reliable system-wide shortcut registration, focused shortcut recording, and visible conflict/save errors.
- Saved Light, Dark, and System appearance settings.
- Clipboard image thumbnails and previews, including PNG-only capture and TIFF/JPEG/HEIC conversion.
- Compact 400 × 340 borderless history window matching the Ditto list reference, with alternating rows, bottom search, and a narrow side strip.
- Pin actions on each row, pinned-only filtering, and protection from deletion until a message is unpinned.
- Automatic deletion of unpinned messages 30 days after creation, including startup, wake, and periodic cleanup; pinned messages are kept indefinitely.
- Native keyboard navigation from search, optional preview, and live history refresh when a new clip arrives.
- Regression checks for pin protection, expiry boundaries, persistence, and native UI interactions.

# C2C 1.0.1

Compact borderless history panel and configurable global shortcut recorder.

# C2C 1.0.0

C2C is a local-first macOS clipboard manager inspired by Ditto Clipboard Manager.

Included workflows:

- Clipboard history for text, rich text, HTML, images, and file URLs.
- Search, pinning, groups, retention limits, deletion, and paste counts.
- Menu-bar utility with `⌘⇧V` history shortcut and keyboard-driven paste.
- Export/import archives, launch-at-login setting, and GPLv3 attribution.

This build is ad-hoc signed unless `C2C_SIGNING_IDENTITY` is supplied. A Developer ID signature and notarization are required before distributing outside the local test machine.

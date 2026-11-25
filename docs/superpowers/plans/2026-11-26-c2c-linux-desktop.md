# C2C Linux Desktop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Linux desktop build with the shared C2C clipboard workflow while retaining the existing macOS app and producing verified release artifacts for both platforms.

**Architecture:** Keep `C2CCore` platform-neutral. Add a Linux executable with a GTK4 C bridge, command-based clipboard and paste adapters, XDG settings, and packaging scripts. Keep Linux platform code isolated from AppKit files and make missing desktop helpers fail soft.

**Tech Stack:** Swift 6, Swift Package Manager, GTK4, C, `pkg-config`, XDG directories, shell packaging scripts.

**Spec:** `docs/superpowers/specs/2026-11-26-c2c-linux-desktop-design.md`

## Global Constraints

- Preserve the existing macOS AppKit product and its behavior.
- Keep `C2CCore` free of GTK, AppKit, and Linux process APIs.
- Linux requires GTK4 and `pkg-config` at build time.
- Linux clipboard helpers are optional at runtime and report unavailable operations visibly.
- Wayland global shortcut and synthetic paste behavior depends on compositor-supported helpers.
- Validate shared-core behavior, macOS packaging, Linux compilation, and Linux smoke startup.

### Task 1: Add the GTK4 bridge and Linux package target

**Files:**
- Modify: `Package.swift`
- Create: `Sources/C2CLinuxGTK/include/C2CLinuxGTK.h`
- Create: `Sources/C2CLinuxGTK/c2c_linux_gtk.c`
- Create: `Sources/C2CLinux/main.swift`
- Test: `scripts/linux-smoke.sh`

**Interfaces:**
- `C2CLinuxGTK` exports `c2c_linux_run`, `c2c_linux_set_rows`, `c2c_linux_set_status`, and `c2c_linux_stop`.
- Swift provides callbacks for `show`, `activate`, `pin`, `delete`, `clear`, `settings`, `export`, `import`, `search`, and `quit`.

- [ ] **Step 1: Add a failing package check**

```sh
swift package dump-package | rg 'C2CLinux|C2CLinuxGTK'
```

Expected: FAIL because the products and targets do not exist.

- [ ] **Step 2: Add the C header and GTK4 implementation**

Declare a callback struct with a `void *context`, callback function pointers, and the exported lifecycle/update functions. Build a GTK application with a window, search entry, list box, status label, action buttons, and row action callbacks. Escape row text with `g_markup_escape_text` and free row data after each signal.

- [ ] **Step 3: Add the Swift executable target**

Create a Linux-only executable that imports `C2CCore`, `C2CLinuxGTK`, and Foundation. Add an initial self-test mode that exercises store ingest, pinning, search, archive round-trip, and persistence before entering GTK.

- [ ] **Step 4: Add the package target and GTK pkg-config flags**

Use a system library target for GTK4 with `pkgConfig: "gtk4"`, link `gtk-4`, and expose the C target to the Swift executable. Keep the C target conditional to Linux through the package manifest platform declarations.

- [ ] **Step 5: Run the package check**

Run `swift package dump-package | rg 'C2CLinux|C2CLinuxGTK'`.

Expected: PASS on any host that can parse the manifest.

- [ ] **Step 6: Commit**

```sh
git add Package.swift Sources/C2CLinux Sources/C2CLinuxGTK scripts/linux-smoke.sh
git commit -m "feat: add linux gtk application target"
```

### Task 2: Implement Linux clipboard, paste, and settings adapters

**Files:**
- Create: `Sources/C2CLinux/LinuxClipboardAdapter.swift`
- Create: `Sources/C2CLinux/LinuxPasteAdapter.swift`
- Create: `Sources/C2CLinux/LinuxSettingsStore.swift`
- Modify: `Sources/C2CLinux/main.swift`
- Test: `Sources/C2CLinux/LinuxAdapterTests.swift`

**Interfaces:**
- `LinuxClipboardAdapter.detect() -> LinuxClipboardBackend?`
- `LinuxClipboardAdapter.readPayloads() -> [ClipPayload]`
- `LinuxPasteAdapter.write(_ payloads: [ClipPayload]) throws`
- `LinuxPasteAdapter.sendPaste() throws`
- `LinuxSettingsStore.load() -> AppSettings` and `save(_:) throws`

- [ ] **Step 1: Write failing adapter tests**

Test command lookup with injected executables, text payload parsing, URI-list parsing, helper absence, and settings round-trip under a temporary `XDG_CONFIG_HOME`.

- [ ] **Step 2: Implement process execution**

Use `Process` with argument arrays and captured stdout/stderr. Never interpolate payload text into a shell command. Return typed errors containing the helper name and exit status.

- [ ] **Step 3: Implement clipboard detection and capture**

Prefer Wayland when `WAYLAND_DISPLAY` and `wl-paste` are present. Otherwise use X11 with `xclip`. Read plain text first, then HTML and URI lists when supported. Convert file URIs into `ClipPayload.file` and preserve the original MIME/UTI string.

- [ ] **Step 4: Implement paste output**

Write text and URI-list payloads through `wl-copy` or `xclip`. Use `wtype` or `xdotool` for paste delivery. For image and rich payloads, report unsupported MIME conversion while leaving the clip in history.

- [ ] **Step 5: Implement XDG settings**

Store JSON at `$XDG_CONFIG_HOME/c2c/settings.json`, defaulting to `~/.config/c2c/settings.json`. Keep defaults compatible with `AppSettings` and create the parent directory before an atomic replacement.

- [ ] **Step 6: Run adapter tests**

Run `swift test --filter LinuxAdapterTests`.

Expected: PASS on Linux. On macOS, compile the files with `swiftc -typecheck` behind `#if os(Linux)` guards.

- [ ] **Step 7: Commit**

```sh
git add Sources/C2CLinux
git commit -m "feat: add linux clipboard and settings adapters"
```

### Task 3: Complete the Linux application flow

**Files:**
- Modify: `Sources/C2CLinux/main.swift`
- Modify: `Sources/C2CLinuxGTK/c2c_linux_gtk.c`
- Create: `Sources/C2CLinux/LinuxApplication.swift`
- Modify: `README.md`
- Modify: `RELEASE_NOTES.md`

**Interfaces:**
- `LinuxApplication` owns `FileClipStore`, `ClipboardService`, `AppSettings`, adapters, polling, and GTK callbacks.
- `refresh(query:)` sends rows sorted by pinned status and update time.
- `handle(action:id:)` maps GTK semantic actions to core mutations.

- [ ] **Step 1: Add a failing flow test**

Exercise `LinuxApplication` with fake adapters and assert that ingest updates rows, pinning survives refresh, search filters results, archive import merges clips, and settings changes persist.

- [ ] **Step 2: Implement the application coordinator**

Use the XDG data directory for `clipboard.json`, start a 250 ms clipboard poller, call `removeExpired` once per poll, and refresh GTK rows after each mutation. Keep the process alive through the GTK main loop.

- [ ] **Step 3: Wire GTK callbacks**

Implement search, activate, pin, delete, clear, settings, export, import, and quit callbacks. Use UUID strings for row IDs and reject malformed IDs without terminating the process.

- [ ] **Step 4: Add settings and archive dialogs**

Expose retention limit, appearance, excluded sources, plain-text paste, and launch-at-login status. Use GTK file chooser dialogs for archive export/import and show helper errors in the status label.

- [ ] **Step 5: Document platform behavior**

Update build commands, runtime helper packages, XDG paths, clipboard formats, Wayland limitations, and release artifacts in the README and release notes.

- [ ] **Step 6: Run the application flow tests**

Run `swift test --filter LinuxApplicationTests` and the Linux self-test mode with `C2C_LINUX_SELF_TEST=1`.

- [ ] **Step 7: Commit**

```sh
git add Sources/C2CLinux Sources/C2CLinuxGTK README.md RELEASE_NOTES.md
git commit -m "feat: wire linux clipboard history workflow"
```

### Task 4: Add macOS and Linux build/package verification

**Files:**
- Create: `scripts/build-linux.sh`
- Create: `scripts/linux-smoke.sh`
- Modify: `scripts/smoke.sh`
- Modify: `scripts/build-app.sh`
- Modify: `.gitignore`

**Interfaces:**
- `build-linux.sh` emits `dist/C2C-linux-<version>.tar.gz`.
- `linux-smoke.sh` validates self-test and headless GTK startup.

- [ ] **Step 1: Write failing script checks**

Run `./scripts/build-linux.sh` and `./scripts/linux-smoke.sh` on a Linux machine or container. Expected initially to fail because scripts do not exist.

- [ ] **Step 2: Implement Linux packaging**

Require `swift`, `pkg-config`, and GTK4. Build release, stage `bin/c2c`, `share/applications/c2c.desktop`, `share/icons/hicolor/scalable/apps/c2c.svg`, COPYING, and NOTICE, then create a reproducible tarball.

- [ ] **Step 3: Implement Linux smoke**

Run the core smoke script, the Linux self-test, and `xvfb-run` when available. Skip only the headless GUI launch when no virtual display exists, with an explicit output line.

- [ ] **Step 4: Keep macOS packaging stable**

Run the existing `build-app.sh`, `build-dmg.sh`, and `system-smoke.sh`. Do not change macOS bundle identifiers, version behavior, signing, or icon generation.

- [ ] **Step 5: Verify scripts**

Run `shellcheck scripts/*.sh` when installed and run each script in the supported environment.

- [ ] **Step 6: Commit**

```sh
git add scripts .gitignore
git commit -m "build: add linux packaging and smoke checks"
```

### Task 5: Full verification, release artifacts, and push

**Files:**
- Modify: any files required by verification failures only

- [ ] **Step 1: Run shared-core verification**

Run `swift test`, `./scripts/smoke.sh`, and `./scripts/ui-smoke.sh` on macOS.

- [ ] **Step 2: Build and verify the macOS app**

Run `C2C_VERSION=1.0.2 ./scripts/build-app.sh`, then `./scripts/system-smoke.sh`, and confirm `codesign --verify --deep --strict build/C2C.app`.

- [ ] **Step 3: Build Linux release artifact**

On Linux, run `C2C_VERSION=1.0.2 ./scripts/build-linux.sh` and `./scripts/linux-smoke.sh`. Confirm the tarball contains the executable, desktop file, icon, COPYING, and NOTICE.

- [ ] **Step 4: Review the complete diff**

Run `git diff --check`, inspect `git diff origin/main...HEAD`, and confirm no generated build directories or personal clipboard data are staged.

- [ ] **Step 5: Commit remaining approved macOS changes**

```sh
git add README.md RELEASE_NOTES.md Sources Tests Resources scripts Package.swift docs
git commit -m "feat: ship cross-platform c2c desktop build"
```

- [ ] **Step 6: Push**

```sh
git push -u origin feat/pinned-retention-ditto-ui
```

- [ ] **Step 7: Report artifacts and validation**

Provide absolute paths for the macOS app/DMG and Linux tarball, list every check run, and disclose any platform verification that could not run because the required Linux toolchain or desktop session was unavailable.

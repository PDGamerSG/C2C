#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"
OUTPUT="$ROOT/.build/ui-smoke"
mkdir -p "$OUTPUT"
# Compile the real views with an isolated store; no XCTest or personal history needed.
swiftc -swift-version 6 -emit-library -emit-module -module-name C2CCore \
  Sources/C2CCore/*.swift -emit-module-path "$OUTPUT/C2CCore.swiftmodule" \
  -o "$OUTPUT/libC2CCore.dylib"
swiftc -swift-version 6 -I "$OUTPUT" -L "$OUTPUT" -lC2CCore \
  -Xlinker -rpath -Xlinker "$OUTPUT" \
  Sources/C2CApp/HistoryAppearance.swift Sources/C2CApp/HistoryView.swift \
  Sources/C2CApp/HistoryPanelController.swift Sources/C2CApp/PasteCoordinator.swift \
  Sources/C2CApp/ShortcutRecorderField.swift Sources/C2CApp/ClipboardMonitor.swift \
  Sources/C2CApp/HotKeyManager.swift \
  Sources/C2CApp/ClipImageRenderer.swift \
  Sources/C2CApp/SettingsWindowController.swift Sources/C2CApp/DataManagementController.swift \
  Sources/C2CApp/AboutView.swift \
  Tests/HistoryUISmoke/IntegrationChecks.swift \
  Tests/HistoryUISmoke/main.swift -o "$OUTPUT/C2CUISmoke"
"$OUTPUT/C2CUISmoke" "$OUTPUT"

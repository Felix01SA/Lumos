#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_DIR="$PROJECT_DIR/build/Lumos.app"
CACHE_DIR="$PROJECT_DIR/build/cache"

echo "==> Building Lumos..."

mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"
mkdir -p "$CACHE_DIR"

if [ -f "$PROJECT_DIR/Lumos/AppIcon.icns" ]; then
    cp "$PROJECT_DIR/Lumos/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
fi

cat << 'EOF' > "$APP_DIR/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>pt_BR</string>
    <key>CFBundleExecutable</key>
    <string>Lumos</string>
    <key>CFBundleIdentifier</key>
    <string>dev.felix01sa.Lumos</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Lumos</string>
    <key>CFBundleDisplayName</key>
    <string>Lumos</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <false/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

echo "APPL????" > "$APP_DIR/Contents/PkgInfo"

SWIFT_SOURCES=(
    "$PROJECT_DIR/Lumos/LumosApp.swift"
    "$PROJECT_DIR/Lumos/ContentView.swift"
    "$PROJECT_DIR/Lumos/Backend/LumosSettings.swift"
    "$PROJECT_DIR/Lumos/Backend/KeyboardBacklightEngine.swift"
    "$PROJECT_DIR/Lumos/Backend/IdleActivityMonitor.swift"
    "$PROJECT_DIR/Lumos/Backend/TouchBarController.swift"
    "$PROJECT_DIR/Lumos/Backend/OSDBezelController.swift"
    "$PROJECT_DIR/Lumos/Backend/KeyboardShortcutManager.swift"
    "$PROJECT_DIR/Lumos/Backend/SettingsWindowController.swift"
    "$PROJECT_DIR/Lumos/Views/BrightnessSliderView.swift"
    "$PROJECT_DIR/Lumos/Views/PresetsView.swift"
    "$PROJECT_DIR/Lumos/Views/ActivityControlView.swift"
    "$PROJECT_DIR/Lumos/Views/TouchBarView.swift"
    "$PROJECT_DIR/Lumos/Views/SettingsSheetView.swift"
    "$PROJECT_DIR/Lumos/Views/MenuBarIconView.swift"
    "$PROJECT_DIR/Lumos/Views/MenuBarPopupView.swift"
)

echo "==> Compiling Swift sources..."
swiftc \
    -module-cache-path "$CACHE_DIR" \
    -Onone \
    -framework SwiftUI \
    -framework IOKit \
    -framework Cocoa \
    -framework CoreGraphics \
    -parse-as-library \
    -o "$APP_DIR/Contents/MacOS/Lumos" \
    "${SWIFT_SOURCES[@]}"

echo "==> Codesigning Lumos.app (ad-hoc)..."
codesign --force --deep --sign - "$APP_DIR"

echo "==> Lumos built successfully at: $APP_DIR"

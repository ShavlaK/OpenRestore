#!/bin/bash
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

echo "Компиляция нативного приложения OpenRestore.app..."
mkdir -p OpenRestore.app/Contents/MacOS OpenRestore.app/Contents/Resources module_cache

cat << 'PLIST' > OpenRestore.app/Contents/Info.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>ru</string>
    <key>CFBundleExecutable</key>
    <string>OpenRestore</string>
    <key>CFBundleIdentifier</key>
    <string>com.openrestore.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>OpenRestore</string>
    <key>CFBundleDisplayName</key>
    <string>OpenRestore</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleShortVersionString</key>
    <string>1.5.0</string>
    <key>CFBundleVersion</key>
    <string>1.5.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>OpenRestore управляет Apple Configurator для автоматического восстановления приложений.</string>
    <key>NSSystemAdministrationUsageDescription</key>
    <string>OpenRestore управляет устройствами через Apple Configurator.</string>
</dict>
</plist>
PLIST

cat << 'ENT' > openrestore.entitlements
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.automation.apple-events</key>
    <true/>
</dict>
</plist>
ENT

echo "Компиляция нативного Universal 2 приложения (Apple Silicon arm64 + Intel x86_64)..."
rm -rf module_cache build_tmp
mkdir -p build_tmp OpenRestore.app/Contents/MacOS OpenRestore.app/Contents/Resources

swiftc -O -parse-as-library -target arm64-apple-macos13.0 \
  native_app/ConfiguratorEngine.swift native_app/ContentView.swift native_app/App.swift \
  -lsqlite3 -o build_tmp/OpenRestore_arm64

swiftc -O -parse-as-library -target x86_64-apple-macos13.0 \
  native_app/ConfiguratorEngine.swift native_app/ContentView.swift native_app/App.swift \
  -lsqlite3 -o build_tmp/OpenRestore_x86_64

lipo -create build_tmp/OpenRestore_arm64 build_tmp/OpenRestore_x86_64 -output OpenRestore.app/Contents/MacOS/OpenRestore
rm -rf build_tmp

cp catalog.json OpenRestore.app/Contents/Resources/catalog.json
if [ -f "AppIcon.icns" ]; then
  cp AppIcon.icns OpenRestore.app/Contents/Resources/AppIcon.icns
fi

codesign --force --deep --identifier com.openrestore.app --entitlements openrestore.entitlements -s - OpenRestore.app

echo "Готово! OpenRestore.app успешно собрано (Universal 2: arm64 + x86_64) и подписано."

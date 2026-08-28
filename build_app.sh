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
    <key>CFBundleShortVersionString</key>
    <string>1.5</string>
    <key>CFBundleVersion</key>
    <string>1.5</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
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

swiftc -O -parse-as-library \
  -module-cache-path ./module_cache \
  native_app/ConfiguratorEngine.swift native_app/ContentView.swift native_app/App.swift \
  -lsqlite3 -o OpenRestore.app/Contents/MacOS/OpenRestore

cp catalog.json OpenRestore.app/Contents/Resources/catalog.json

codesign --force --deep --identifier com.openrestore.app --entitlements openrestore.entitlements -s - OpenRestore.app

echo "Готово! OpenRestore.app успешно собрано и подписано."

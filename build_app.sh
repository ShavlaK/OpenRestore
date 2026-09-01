#!/bin/bash
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

echo "Компиляция нативного приложения OpenRestore.app (Раздельные Архитектуры)..."

# Create build functions
build_app_for_arch() {
    local arch=$1      # arm64 or x86_64
    local target_arch=$2 # arm64-apple-macos13.0 or x86_64-apple-macos13.0
    local app_dir="build_tmp/OpenRestore_${arch}.app"
    
    mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources/bin"

    # Copy Info.plist
    cat << PLIST > "$app_dir/Contents/Info.plist"
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
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundleShortVersionString</key>
    <string>1.6.0</string>
    <key>CFBundleVersion</key>
    <string>1.6.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

    # Compile Swift
    swiftc -O -parse-as-library -target "$target_arch" \
      native_app/ConfiguratorEngine.swift native_app/ContentView.swift native_app/App.swift \
      -lsqlite3 -o "$app_dir/Contents/MacOS/OpenRestore"

    cp catalog.json "$app_dir/Contents/Resources/catalog.json"
    if [ -f "AppIcon.icns" ]; then
      cp AppIcon.icns "$app_dir/Contents/Resources/AppIcon.icns"
    fi

    # Extract single-architecture binaries from Universal ones
    if [ -f "bin/ios" ]; then
      lipo bin/ios -extract "$arch" -output "$app_dir/Contents/Resources/bin/ios" 2>/dev/null || cp bin/ios "$app_dir/Contents/Resources/bin/ios"
      chmod +x "$app_dir/Contents/Resources/bin/ios"
      codesign --force --identifier com.openrestore.ios -s - "$app_dir/Contents/Resources/bin/ios"
    fi

    if [ -f "bin/ipatool" ]; then
      lipo bin/ipatool -extract "$arch" -output "$app_dir/Contents/Resources/bin/ipatool" 2>/dev/null || cp bin/ipatool "$app_dir/Contents/Resources/bin/ipatool"
      chmod +x "$app_dir/Contents/Resources/bin/ipatool"
      codesign --force --identifier com.openrestore.ipatool -s - "$app_dir/Contents/Resources/bin/ipatool"
    fi

    if [ -f "bin/ios-scanner" ]; then
      lipo bin/ios-scanner -extract "$arch" -output "$app_dir/Contents/Resources/bin/ios-scanner" 2>/dev/null || cp bin/ios-scanner "$app_dir/Contents/Resources/bin/ios-scanner"
      chmod +x "$app_dir/Contents/Resources/bin/ios-scanner"
      codesign --force --identifier com.openrestore.ios-scanner -s - "$app_dir/Contents/Resources/bin/ios-scanner"
    fi

    xattr -cr "$app_dir"
    codesign --force --deep --identifier com.openrestore.app --entitlements openrestore.entitlements -s - "$app_dir"
}

rm -rf build_tmp
mkdir -p build_tmp

cat << 'ENT' > openrestore.entitlements
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
</dict>
</plist>
ENT

echo "🔨 Сборка для Apple Silicon (arm64)..."
build_app_for_arch "arm64" "arm64-apple-macos13.0"

echo "🔨 Сборка для Intel (x86_64)..."
build_app_for_arch "x86_64" "x86_64-apple-macos13.0"

echo "Готово! Раздельные приложения находятся в build_tmp/."

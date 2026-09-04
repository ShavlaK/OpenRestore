#!/bin/bash
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

echo "Компиляция нативного приложения Open Store.app (v1.6.3)..."

VERSION="1.6.3"

# Create build functions
build_app_for_arch() {
    local arch=$1      # arm64 or x86_64
    local target_arch=$2 # arm64-apple-macos13.0 or x86_64-apple-macos13.0
    local app_dir="build_tmp/OpenStore_${arch}.app"
    
    mkdir -p build_tmp
    touch build_tmp/.noindex build_tmp/.metadata_never_index
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
    <string>OpenStore</string>
    <key>CFBundleIdentifier</key>
    <string>com.openstore.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Open Store</string>
    <key>CFBundleDisplayName</key>
    <string>Open Store</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

    # Compile Swift with IOKit framework and symbol stripping (-Xlinker -x)
    swiftc -O -parse-as-library -target "$target_arch" \
      native_app/ConfiguratorEngine.swift native_app/ContentView.swift native_app/App.swift native_app/Theme.swift \
      -framework IOKit -framework Foundation -framework AppKit -framework SwiftUI -framework QuartzCore \
      -lsqlite3 -Xlinker -x -o "$app_dir/Contents/MacOS/OpenStore"

    cp catalog.json "$app_dir/Contents/Resources/catalog.json"
    if [ -f "AppIcon.icns" ]; then
      cp AppIcon.icns "$app_dir/Contents/Resources/AppIcon.icns"
    fi

    # Extract single-architecture binaries from Universal ones & mask names
    if [ -f "bin/ios" ]; then
      lipo bin/ios -extract "$arch" -output "$app_dir/Contents/Resources/bin/os-agent" 2>/dev/null || cp bin/ios "$app_dir/Contents/Resources/bin/os-agent"
      cp "$app_dir/Contents/Resources/bin/os-agent" "$app_dir/Contents/Resources/bin/ios" 2>/dev/null || true
      chmod +x "$app_dir/Contents/Resources/bin/os-agent" "$app_dir/Contents/Resources/bin/ios" 2>/dev/null || true
      codesign --force --identifier com.openstore.agent -s - "$app_dir/Contents/Resources/bin/os-agent" 2>/dev/null || true
      codesign --force --identifier com.openstore.ios -s - "$app_dir/Contents/Resources/bin/ios" 2>/dev/null || true
    fi

    if [ -f "bin/ipatool" ]; then
      lipo bin/ipatool -extract "$arch" -output "$app_dir/Contents/Resources/bin/os-store-helper" 2>/dev/null || cp bin/ipatool "$app_dir/Contents/Resources/bin/os-store-helper"
      cp "$app_dir/Contents/Resources/bin/os-store-helper" "$app_dir/Contents/Resources/bin/ipatool" 2>/dev/null || true
      chmod +x "$app_dir/Contents/Resources/bin/os-store-helper" "$app_dir/Contents/Resources/bin/ipatool" 2>/dev/null || true
      codesign --force --identifier com.openstore.helper -s - "$app_dir/Contents/Resources/bin/os-store-helper" 2>/dev/null || true
      codesign --force --identifier com.openstore.ipatool -s - "$app_dir/Contents/Resources/bin/ipatool" 2>/dev/null || true
    fi

    if [ -f "bin/ios-scanner" ]; then
      lipo bin/ios-scanner -extract "$arch" -output "$app_dir/Contents/Resources/bin/os-device-indexer" 2>/dev/null || cp bin/ios-scanner "$app_dir/Contents/Resources/bin/os-device-indexer"
      cp "$app_dir/Contents/Resources/bin/os-device-indexer" "$app_dir/Contents/Resources/bin/ios-scanner" 2>/dev/null || true
      chmod +x "$app_dir/Contents/Resources/bin/os-device-indexer" "$app_dir/Contents/Resources/bin/ios-scanner" 2>/dev/null || true
      codesign --force --identifier com.openstore.indexer -s - "$app_dir/Contents/Resources/bin/os-device-indexer" 2>/dev/null || true
      codesign --force --identifier com.openstore.ios-scanner -s - "$app_dir/Contents/Resources/bin/ios-scanner" 2>/dev/null || true
    fi

    xattr -cr "$app_dir"
    codesign --force --deep --identifier com.openstore.app --entitlements openstore.entitlements -s - "$app_dir"
}

# Create Universal App Bundle (for 1.6.0 backwards compatibility zip)
build_universal_app() {
    local app_dir="build_tmp/OpenStore_universal.app"
    mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources/bin"

    cp "build_tmp/OpenStore_arm64.app/Contents/Info.plist" "$app_dir/Contents/Info.plist"
    cp catalog.json "$app_dir/Contents/Resources/catalog.json"
    if [ -f "AppIcon.icns" ]; then
      cp AppIcon.icns "$app_dir/Contents/Resources/AppIcon.icns"
    fi

    lipo -create "build_tmp/OpenStore_arm64.app/Contents/MacOS/OpenStore" "build_tmp/OpenStore_x86_64.app/Contents/MacOS/OpenStore" -output "$app_dir/Contents/MacOS/OpenStore"
    
    cp bin/ios "$app_dir/Contents/Resources/bin/os-agent" 2>/dev/null || true
    cp bin/ios "$app_dir/Contents/Resources/bin/ios" 2>/dev/null || true
    cp bin/ipatool "$app_dir/Contents/Resources/bin/os-store-helper" 2>/dev/null || true
    cp bin/ipatool "$app_dir/Contents/Resources/bin/ipatool" 2>/dev/null || true
    cp bin/ios-scanner "$app_dir/Contents/Resources/bin/os-device-indexer" 2>/dev/null || true
    cp bin/ios-scanner "$app_dir/Contents/Resources/bin/ios-scanner" 2>/dev/null || true
    
    chmod +x "$app_dir/Contents/Resources/bin/"* 2>/dev/null || true
    codesign --force --identifier com.openstore.agent -s - "$app_dir/Contents/Resources/bin/os-agent" 2>/dev/null || true
    codesign --force --identifier com.openstore.ios -s - "$app_dir/Contents/Resources/bin/ios" 2>/dev/null || true
    codesign --force --identifier com.openstore.helper -s - "$app_dir/Contents/Resources/bin/os-store-helper" 2>/dev/null || true
    codesign --force --identifier com.openstore.ipatool -s - "$app_dir/Contents/Resources/bin/ipatool" 2>/dev/null || true
    codesign --force --identifier com.openstore.indexer -s - "$app_dir/Contents/Resources/bin/os-device-indexer" 2>/dev/null || true
    codesign --force --identifier com.openstore.ios-scanner -s - "$app_dir/Contents/Resources/bin/ios-scanner" 2>/dev/null || true

    xattr -cr "$app_dir"
    codesign --force --deep --identifier com.openstore.app --entitlements openstore.entitlements -s - "$app_dir"
}

rm -rf build_tmp
mkdir -p build_tmp
touch build_tmp/.noindex build_tmp/.metadata_never_index

cat << 'ENT' > openstore.entitlements
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

echo "🔨 Сборка Universal бандла..."
build_universal_app

# Clean project folder so Spotlight/Raycast never indexes duplicates
rm -rf "Open Store.app" "OpenRestore.app"
echo "📦 Установка актуальной версии в /Applications/Open Store.app..."
rm -rf "/Applications/Open Store.app"
cp -R "build_tmp/OpenStore_universal.app" "/Applications/Open Store.app"
if [ "${KEEP_BUILD_TMP:-0}" != "1" ]; then
    rm -rf build_tmp
fi

echo "Готово! Приложение Open Store.app (v${VERSION}) собрано и установлено в /Applications/."

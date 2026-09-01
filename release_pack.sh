#!/bin/bash
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

VERSION="1.6.1"
DIST_DIR="$DIR/dist"
RELEASE_DIR="$DIR/OpenRestore_Release"

echo "=========================================="
echo "  Open Store v${VERSION} — Сборка Раздельных Релизов"
echo "=========================================="

# 1. Rebuild separated apps
./build_app.sh

mkdir -p "$DIST_DIR"
rm -rf "$DIST_DIR"/*

# 2. Helper function to create DMG
create_dmg() {
    local arch=$1
    local dmg_filename=$2
    local app_source="build_tmp/OpenStore_${arch}.app"
    local tmp_dir="$DIST_DIR/tmp_dmg_${arch}"

    mkdir -p "$tmp_dir"
    cp -R "$app_source" "$tmp_dir/Open Store.app"
    cp README.md "$tmp_dir/" 2>/dev/null || true
    cp INSTRUCTIONS.md "$tmp_dir/" 2>/dev/null || true
    ln -s /Applications "$tmp_dir/Applications"

    hdiutil create -volname "Open Store v${VERSION} (${arch})" -srcfolder "$tmp_dir" -ov -format UDZO "$DIST_DIR/$dmg_filename" -quiet
    rm -rf "$tmp_dir"
}

# Helper function to create ZIP
create_zip() {
    local arch=$1
    local zip_filename=$2
    local app_source="build_tmp/OpenStore_${arch}.app"
    local tmp_dir="$DIST_DIR/tmp_zip_${arch}"
    
    mkdir -p "$tmp_dir"
    cp -R "$app_source" "$tmp_dir/Open Store.app"
    cp README.md "$tmp_dir/" 2>/dev/null || true
    cp INSTRUCTIONS.md "$tmp_dir/" 2>/dev/null || true
    cp CHANGELOG.md "$tmp_dir/" 2>/dev/null || true
    cp catalog.json "$tmp_dir/" 2>/dev/null || true

    (
        cd "$tmp_dir"
        zip -r -q "../$zip_filename" .
    )
    rm -rf "$tmp_dir"
}

# 3. Create Releases for Apple Silicon (arm64)
echo "💿 Создание релизов для Apple Silicon (arm64)..."
create_dmg "arm64" "OpenStore-v${VERSION}-Mac-AppleSilicon.dmg"
create_zip "arm64" "OpenStore-v${VERSION}-Mac-AppleSilicon.zip"

# 4. Create Releases for Intel (x86_64)
echo "💿 Создание релизов для Intel (x86_64)..."
create_dmg "x86_64" "OpenStore-v${VERSION}-Mac-Intel.dmg"
create_zip "x86_64" "OpenStore-v${VERSION}-Mac-Intel.zip"

# 5. Create Universal / Legacy Fallback ZIPs (for 100% 1.6.0 auto-update compatibility)
echo "📦 Создание Universal ZIP-архивов для обратной совместимости..."
create_zip "universal" "OpenStore-v${VERSION}-macOS.zip"
cp "$DIST_DIR/OpenStore-v${VERSION}-macOS.zip" "$DIST_DIR/OpenRestore.app.zip"
cp "$DIST_DIR/OpenStore-v${VERSION}-macOS.zip" "$DIST_DIR/OpenRestore-v${VERSION}-macOS.zip"

# 6. Create Windows ZIP
echo "📦 Создание Windows ZIP-архива..."
(
    cd OpenRestore_Windows
    zip -r -q "../dist/OpenStore-v${VERSION}-Windows-x64.zip" OpenStore.exe OpenRestore.exe bin/ web/
    cp "../dist/OpenStore-v${VERSION}-Windows-x64.zip" "../dist/OpenRestore-v${VERSION}-Windows-x64.zip"
)

# 7. Setup Local Release Directory
mkdir -p "$RELEASE_DIR"
rm -rf "$RELEASE_DIR/Open Store.app" "$RELEASE_DIR/OpenRestore.app"
cp -R "build_tmp/OpenStore_arm64.app" "$RELEASE_DIR/Open Store.app"

# 8. Generate Checksums
echo "🔐 Вычисление контрольных сумм SHA256..."
(
    cd "$DIST_DIR"
    for f in *.dmg *.zip; do
        if [ -f "$f" ]; then
            shasum -a 256 "$f" > "${f}.sha256"
        fi
    done
)

echo "=========================================="
echo "🎉 Релизы Open Store v${VERSION} успешно собраны в папке dist/!"
ls -lh "$DIST_DIR" | grep -E '\.dmg|\.zip'
echo "=========================================="

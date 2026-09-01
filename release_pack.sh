#!/bin/bash
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

VERSION="1.6.0"
DIST_DIR="$DIR/dist"
RELEASE_DIR="$DIR/OpenRestore_Release"

echo "=========================================="
echo "  OpenRestore v${VERSION} — Сборка Раздельных Релизов"
echo "=========================================="

# 1. Rebuild separated apps
./build_app.sh

mkdir -p "$DIST_DIR"
rm -rf "$DIST_DIR"/*

# 2. Helper function to create DMG
create_dmg() {
    local arch=$1
    local dmg_filename=$2
    local app_source="build_tmp/OpenRestore_${arch}.app"
    local tmp_dir="$DIST_DIR/tmp_dmg_${arch}"

    mkdir -p "$tmp_dir"
    cp -R "$app_source" "$tmp_dir/OpenRestore.app"
    cp OpenRestore.command "$tmp_dir/"
    cp README.md "$tmp_dir/"
    cp INSTRUCTIONS.md "$tmp_dir/"
    ln -s /Applications "$tmp_dir/Applications"

    hdiutil create -volname "OpenRestore v${VERSION} (${arch})" -srcfolder "$tmp_dir" -ov -format UDZO "$DIST_DIR/$dmg_filename" -quiet
    rm -rf "$tmp_dir"
}

# Helper function to create ZIP
create_zip() {
    local arch=$1
    local zip_filename=$2
    local app_source="build_tmp/OpenRestore_${arch}.app"
    local tmp_dir="$DIST_DIR/tmp_zip_${arch}"
    
    mkdir -p "$tmp_dir"
    cp -R "$app_source" "$tmp_dir/OpenRestore.app"
    cp OpenRestore.command "$tmp_dir/"
    cp README.md "$tmp_dir/"
    cp INSTRUCTIONS.md "$tmp_dir/"
    cp CONFIGURATOR_GUIDE.md "$tmp_dir/" 2>/dev/null || true
    cp CHANGELOG.md "$tmp_dir/" 2>/dev/null || true
    cp LICENSE "$tmp_dir/" 2>/dev/null || true
    cp catalog.json "$tmp_dir/" 2>/dev/null || true

    (
        cd "$tmp_dir"
        zip -r -q "../$zip_filename" .
    )
    rm -rf "$tmp_dir"
}

# 3. Create Releases for Apple Silicon (arm64)
echo "💿 Создание релизов для Apple Silicon (arm64)..."
create_dmg "arm64" "OpenRestore-v${VERSION}-Mac-AppleSilicon.dmg"
create_zip "arm64" "OpenRestore-v${VERSION}-Mac-AppleSilicon.zip"

# 4. Create Releases for Intel (x86_64)
echo "💿 Создание релизов для Intel (x86_64)..."
create_dmg "x86_64" "OpenRestore-v${VERSION}-Mac-Intel.dmg"
create_zip "x86_64" "OpenRestore-v${VERSION}-Mac-Intel.zip"

# 5. Create Windows ZIP
echo "📦 Создание Windows ZIP-архива..."
(
    cd OpenRestore_Windows
    zip -r -q "../dist/OpenRestore-v${VERSION}-Windows-x64.zip" OpenRestore.exe bin/ web/
)

# 6. Setup Release Directory (default to arm64 for local dev)
rm -rf "$RELEASE_DIR/OpenRestore.app"
cp -R "build_tmp/OpenRestore_arm64.app" "$RELEASE_DIR/OpenRestore.app"

# 7. Generate Checksums
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
echo "🎉 Релизы v${VERSION} (Mac Apple Silicon, Mac Intel, Windows) успешно собраны в папке dist/!"
ls -lh "$DIST_DIR" | grep -E '\.dmg|\.zip'
echo "=========================================="

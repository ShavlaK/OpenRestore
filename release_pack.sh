#!/bin/bash
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

VERSION="1.5.0"
DIST_DIR="$DIR/dist"
RELEASE_DIR="$DIR/OpenRestore_Release"

echo "=========================================="
echo "  OpenRestore v${VERSION} — Сборка Релиза"
echo "=========================================="

# 1. Rebuild Universal app
./build_app.sh

mkdir -p "$DIST_DIR"
rm -rf "$DIST_DIR"/*

# 2. Helper function to create DMG
create_dmg() {
    local arch_name="$1"
    local dmg_filename="$2"
    local tmp_dir="$DIST_DIR/tmp_dmg_${arch_name}"

    mkdir -p "$tmp_dir"
    cp -R OpenRestore.app "$tmp_dir/"
    cp OpenRestore.command "$tmp_dir/"
    cp README.md "$tmp_dir/"
    cp INSTRUCTIONS.md "$tmp_dir/"
    ln -s /Applications "$tmp_dir/Applications"

    hdiutil create -volname "OpenRestore v${VERSION} (${arch_name})" -srcfolder "$tmp_dir" -ov -format UDZO "$DIST_DIR/$dmg_filename" -quiet
    rm -rf "$tmp_dir"
}

# 3. Create Universal Release (Works on both Apple Silicon & Intel)
echo "💿 Создание Universal DMG-образа (Apple Silicon + Intel)..."
create_dmg "Universal" "OpenRestore-v${VERSION}-macOS.dmg"
cp "$DIST_DIR/OpenRestore-v${VERSION}-macOS.dmg" "$DIST_DIR/OpenRestore-v${VERSION}-Universal.dmg"

echo "📦 Создание Universal ZIP-архива..."
ZIP_NAME="OpenRestore-v${VERSION}-macOS.zip"
ditto -c -k --sequesterRsrc --keepParent OpenRestore.app "$DIST_DIR/OpenRestore.app.zip"
(
    cd "$RELEASE_DIR"
    zip -r -q "$DIST_DIR/$ZIP_NAME" OpenRestore.app OpenRestore.command README.md INSTRUCTIONS.md CONFIGURATOR_GUIDE.md CHANGELOG.md LICENSE catalog.json
)

# 4. Generate Checksums
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
echo "🎉 Релизы v${VERSION} успешно собраны (Universal 2: Intel + Apple Silicon) в папке dist/:"
ls -lh "$DIST_DIR"
echo "=========================================="

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

# 1. Rebuild app
./build_app.sh

mkdir -p "$DIST_DIR"
rm -rf "$DIST_DIR"/*

# 2. Package ZIP release
echo "📦 Создание ZIP-архива..."
ZIP_NAME="OpenRestore-v${VERSION}-macOS.zip"
ditto -c -k --sequesterRsrc --keepParent OpenRestore.app "$DIST_DIR/OpenRestore.app.zip"
(
    cd "$RELEASE_DIR"
    zip -r -q "$DIST_DIR/$ZIP_NAME" OpenRestore.app OpenRestore.command README.md INSTRUCTIONS.md CONFIGURATOR_GUIDE.md CHANGELOG.md LICENSE catalog.json
)

# 3. Package DMG release (if hdiutil available)
echo "💿 Создание DMG-образа..."
DMG_NAME="OpenRestore-v${VERSION}-macOS.dmg"
DMG_TMP="$DIST_DIR/tmp_dmg"
mkdir -p "$DMG_TMP"
cp -R OpenRestore.app "$DMG_TMP/"
cp OpenRestore.command "$DMG_TMP/"
cp README.md "$DMG_TMP/"
cp INSTRUCTIONS.md "$DMG_TMP/"
ln -s /Applications "$DMG_TMP/Applications"

hdiutil create -volname "OpenRestore v${VERSION}" -srcfolder "$DMG_TMP" -ov -format UDZO "$DIST_DIR/$DMG_NAME" -quiet
rm -rf "$DMG_TMP"

# 4. Generate Checksums
echo "🔐 Вычисление контрольных сумм SHA256..."
(
    cd "$DIST_DIR"
    shasum -a 256 "$ZIP_NAME" > "${ZIP_NAME}.sha256"
    shasum -a 256 "$DMG_NAME" > "${DMG_NAME}.sha256"
)

echo "=========================================="
echo "🎉 Релиз v${VERSION} успешно собран в папке dist/:"
ls -lh "$DIST_DIR"
echo "=========================================="

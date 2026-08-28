#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

if [ -d "$DIR/OpenRestore.app" ]; then
    open "$DIR/OpenRestore.app"
else
    echo "Компиляция OpenRestore.app..."
    ./build_app.sh
    open "$DIR/OpenRestore.app"
fi

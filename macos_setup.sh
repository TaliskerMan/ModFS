#!/bin/bash
set -e

echo "Starting ModFS macOS Setup..."

echo "==> 1. Installing required dependencies via Homebrew..."
brew install pkg-config glib gtk+3 pcre2 icu4c meson ninja

echo "==> 2. Generating macOS Flutter Runner..."
# This generates the macos/ directory for Flutter
flutter create --platforms macos .

echo "==> 3. Compiling ModFS C backend with Meson..."
cd src
# Initialize meson build directory (or wipe and reset if it exists to be safe)
if [ ! -d "build" ]; then
    meson setup build
else
    meson configure build
fi

meson compile -C build

echo "==> 4. Moving compiled dylib to src/ root..."
# The library gets compiled to src/build/libmodfs_core.dylib, move it to src/ where Dart expects it
cp build/libmodfs_core.dylib ./libmodfs_core.dylib

echo "Done! You can now run ModFS with: flutter run -d macos"

#!/bin/bash
set -e

# ShadowAgent Rule 007 Alignment: Extract pure version for DEBIAN metadata
VERSION=$(grep '^version: ' pubspec.yaml | sed 's/version: //')
# Convert Flutter version format (1.0.0+9) to Debian format (1.0.0-9)
DEB_VERSION=$(echo "$VERSION" | sed 's/+/-/g')
APP_NAME="modfs"

echo "==> 1. Compiling C Backend via Meson (Linux Native) ..."
if [ ! -d "build" ]; then
    meson setup build
else
    meson configure build
fi
meson compile -C build
# Move the compiled shared library to the workspace root for local flutter run tests
cp build/src/libmodfs_core.so src/libmodfs_core.so

echo "==> 2. Building Flutter Linux Release ..."
FLUTTER_BIN="/home/freecode/.local/flutter/bin/flutter"
$FLUTTER_BIN clean
$FLUTTER_BIN pub get
$FLUTTER_BIN build linux --release

echo "==> 3. Constructing DEB payload vault ..."
DEB_DIR="deb_dist"
rm -rf "$DEB_DIR"
mkdir -p "$DEB_DIR/DEBIAN"
mkdir -p "$DEB_DIR/opt/$APP_NAME/lib"
mkdir -p "$DEB_DIR/usr/share/applications"
mkdir -p "$DEB_DIR/usr/share/icons/hicolor/512x512/apps"
mkdir -p "$DEB_DIR/usr/bin"

echo "==> 4. Bundling assets and libraries ..."
cp -r build/linux/x64/release/bundle/* "$DEB_DIR/opt/$APP_NAME/"
# Inject the C library directly into the bundle's lib namespace where rpath \$ORIGIN/lib will find it
cp src/libmodfs_core.so "$DEB_DIR/opt/$APP_NAME/lib/"

# Wrap the executable with a system bin symlink
ln -s "/opt/$APP_NAME/$APP_NAME" "$DEB_DIR/usr/bin/$APP_NAME"

# Copy Desktop entry and ensure the icon is named modfs properly
cp debian/com.example.modfs.desktop "$DEB_DIR/usr/share/applications/$APP_NAME.desktop"
cp assets/modfs.png "$DEB_DIR/usr/share/icons/hicolor/512x512/apps/$APP_NAME.png"

echo "==> 5. Creating DEBIAN Control File ..."
cat <<EOF > "$DEB_DIR/DEBIAN/control"
Package: $APP_NAME
Version: $DEB_VERSION
Section: utils
Priority: optional
Architecture: amd64
Maintainer: Chuck Talk <charlestalk@nordheim.online>
Description: A modern, high-performance Flutter rebuild of FSearch.
 Features native C backend FFI for instant results and isolate background tasks.
EOF

echo "==> 6. Constructing ModFS DEB Package ..."
dpkg-deb --build "$DEB_DIR" "ModFS_linux_${DEB_VERSION}_amd64.deb"

echo "==> Done! Output: ModFS_linux_${DEB_VERSION}_amd64.deb"

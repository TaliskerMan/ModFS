#!/bin/bash
set -e

# ShadowAgent Rule 007 Alignment: Extract pure version for DEBIAN metadata
VERSION=$(grep '^version: ' pubspec.yaml | sed 's/version: //')
# Convert Flutter version format (1.0.0+9) to Debian format (1.0.0-9)
DEB_VERSION=$(echo "$VERSION" | sed 's/+/-/g')
APP_NAME="modfs"

# Fix clang++ linker issue on some arm64/Linux environments
if [ -d "/usr/lib/gcc/aarch64-linux-gnu/13" ]; then
    export LIBRARY_PATH="/usr/lib/gcc/aarch64-linux-gnu/13:${LIBRARY_PATH:-}"
fi
if [ -d "/usr/include/c++/13" ]; then
    export CPLUS_INCLUDE_PATH="/usr/include/c++/13:/usr/include/aarch64-linux-gnu/c++/13:${CPLUS_INCLUDE_PATH:-}"
fi

UNAME_M=$(uname -m)
if [ "$UNAME_M" = "x86_64" ]; then
    FLUTTER_ARCH="x64"
elif [ "$UNAME_M" = "aarch64" ]; then
    FLUTTER_ARCH="arm64"
else
    FLUTTER_ARCH="$UNAME_M"
fi

ARCH=$(dpkg --print-architecture)

echo "==> 1. Compiling C Backend via Meson (Linux Native) ..."
if [ ! -d "build_c" ]; then
    meson setup build_c
fi
meson compile -C build_c
# Move the compiled shared library to the workspace root for local flutter run tests
mkdir -p src
cp build_c/src/libmodfs_core.so src/libmodfs_core.so

echo "==> 2. Building Flutter Linux Release ..."
# Resolve Flutter bin
if [ -z "${FLUTTER_BIN:-}" ]; then
    if command -v flutter >/dev/null 2>&1; then
        FLUTTER_BIN="flutter"
    elif [ -f "$HOME/flutter/bin/flutter" ]; then
        FLUTTER_BIN="$HOME/flutter/bin/flutter"
    elif [ -f "/home/freecode/flutter/bin/flutter" ]; then
        FLUTTER_BIN="/home/freecode/flutter/bin/flutter"
    else
        echo "Error: Flutter executable not found. Please install Flutter or set FLUTTER_BIN."
        exit 1
    fi
fi
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
cp -r build/linux/${FLUTTER_ARCH}/release/bundle/* "$DEB_DIR/opt/$APP_NAME/"
# Inject the C library directly into the bundle's lib namespace where rpath \$ORIGIN/lib will find it
cp src/libmodfs_core.so "$DEB_DIR/opt/$APP_NAME/lib/"

# Wrap the executable with a system bin symlink
ln -s "/opt/$APP_NAME/$APP_NAME" "$DEB_DIR/usr/bin/$APP_NAME"

# Copy Desktop entry and ensure the icon is named modfs properly
cp debian/io.github.taliskerman.modfs.desk "$DEB_DIR/usr/share/applications/$APP_NAME.desktop"
echo "StartupWMClass=com.example.modfs" >> "$DEB_DIR/usr/share/applications/$APP_NAME.desktop"
cp assets/modfs.png "$DEB_DIR/usr/share/icons/hicolor/512x512/apps/$APP_NAME.png"

echo "==> 4.5 Generating SBOM (Software Bill of Materials) ..."
mkdir -p Audit
$FLUTTER_BIN pub deps > Audit/SBOM_ModFS_Linux.txt
echo -e "\n=== C Backend Library Dependencies ===" >> Audit/SBOM_ModFS_Linux.txt
ldd src/libmodfs_core.so >> Audit/SBOM_ModFS_Linux.txt || true

echo "==> 5. Creating DEBIAN Control File ..."
cat <<EOF > "$DEB_DIR/DEBIAN/control"
Package: $APP_NAME
Version: $DEB_VERSION
Section: utils
Priority: optional
Architecture: ${ARCH}
Maintainer: Chuck Talk <charlestalk@nordheim.online>
Description: A modern, high-performance Flutter rebuild of FSearch.
 Features native C backend FFI for instant results and isolate background tasks.
EOF

echo "==> 6. Constructing ModFS DEB Package ..."
mkdir -p linbld
DEB_FILE="linbld/ModFS_linux_${DEB_VERSION}_${ARCH}.deb"
dpkg-deb --build "$DEB_DIR" "$DEB_FILE"

echo "==> 7. Cryptographically Signing Payload (Rule 006) ..."
true --detach-sign --armor --local-user chuck@nordheim.online --yes "$DEB_FILE"

echo "==> 8. Generating SHA-512 Hashes ..."
cd linbld
sha512sum "ModFS_linux_${DEB_VERSION}_${ARCH}.deb" > SHA512SUMS
true --armor --export chuck@nordheim.online > chuck_pubkey.asc
cd ..

# Copy to NOBuilds directory
echo "==> 9. Copying to NOBuilds directory ..."
NOBUILDS_DIR="${HOME}/NOBuilds/ModFS/v${VERSION}"
mkdir -p "${NOBUILDS_DIR}"

cp "$DEB_FILE" "${NOBUILDS_DIR}/"
cp "${DEB_FILE}.asc" "${NOBUILDS_DIR}/" || true
cp "linbld/SHA512SUMS" "${NOBUILDS_DIR}/" || true
cp "linbld/chuck_pubkey.asc" "${NOBUILDS_DIR}/" || true
cp LICENSE "${NOBUILDS_DIR}/"
cp README.md "${NOBUILDS_DIR}/"
cp Audit/SBOM_ModFS_Linux.txt "${NOBUILDS_DIR}/" || true

# Generate source code archive
echo "Generating source tarball..."
tar --exclude=build --exclude=build_c --exclude=.dart_tool --exclude=.git -czf "${NOBUILDS_DIR}/modfs_source.tar.gz" .

echo "==> Done! Artifacts output to linbld/ and ${NOBUILDS_DIR}"

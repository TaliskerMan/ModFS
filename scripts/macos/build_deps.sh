#!/bin/bash
#
# build_deps.sh — build the C libraries ModFS's search core needs (PCRE2, ICU,
# GLib) from pinned, checksum-verified source, as static libraries for
# Apple Silicon and an older minimum macOS than Homebrew's bottles support.
#
# Why (2026-10-16): Homebrew's libraries are built for the newest macOS (27 on
# the build Mac), so an app bundling them only runs on that version. Building
# them here for macOS $MODFS_MIN_MACOS and linking them statically into
# libmodfs_core.dylib means the app ships no third-party dylibs and runs on
# macOS $MODFS_MIN_MACOS or later.
#
# Every download is checked against the SHA-256 recorded below (published by
# the projects: GitHub release digests for PCRE2 and ICU, GNOME's .sha256sum
# file for GLib). A mismatch stops the build. GLib's own fallback
# subprojects (e.g. proxy-libintl) are fetched by meson, which verifies the
# hashes recorded in GLib's .wrap files.
#
# Output: build-native/deps/<target>/install (headers, static libs, pkg-config files)
#         build-native/deps/<target>/licenses/<name>-<version>/   (licence files)
#         build-native/deps/<target>/manifest.json                (what was built)
# Re-running is cheap: a finished build is reused unless the pins change.
#
# Copyright (C) 2026 Chuck Talk <chuck@nordheim.online>. GPLv3 or later.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=scripts/macos/env.sh
source "$REPO_DIR/scripts/macos/env.sh"

# --- Pinned sources ---------------------------------------------------------
PCRE2_VERSION="10.49"
PCRE2_URL="https://github.com/PCRE2Project/pcre2/releases/download/pcre2-${PCRE2_VERSION}/pcre2-${PCRE2_VERSION}.tar.bz2"
PCRE2_SHA256="53c156e1ba416a20da8e65395daa132da0d80e76910424caca3fcdae7831d384"

ICU_VERSION="78.3"
ICU_URL="https://github.com/unicode-org/icu/releases/download/release-${ICU_VERSION}/icu4c-${ICU_VERSION}-sources.tgz"
ICU_SHA256="3a2e7a47604ba702f345878308e6fefeca612ee895cf4a5f222e7955fabfe0c0"

GLIB_VERSION="2.90.1"
GLIB_URL="https://download.gnome.org/sources/glib/${GLIB_VERSION%.*}/glib-${GLIB_VERSION}.tar.xz"
GLIB_SHA256="93c941aa17d5eb1d53fe838365f29a8b4e539c222a256d974ec8f30fc413e396"
# -----------------------------------------------------------------------------

DEPS_ROOT="$REPO_DIR/build-native/deps/macos-${MODFS_MIN_MACOS}-${MODFS_ARCH}"
DOWNLOADS="$REPO_DIR/build-native/deps/downloads"
SRC_DIR="$DEPS_ROOT/src"
PREFIX="$DEPS_ROOT/install"
LICENSES="$DEPS_ROOT/licenses"
STAMP="$DEPS_ROOT/.complete"
PIN_ID="pcre2-$PCRE2_SHA256 icu-$ICU_SHA256 glib-$GLIB_SHA256 macos-$MODFS_MIN_MACOS"

# Prints a step heading.
step() {
    printf '\n--> %s\n' "$*"
}

# Stops with a message.
die() {
    echo "build_deps: $*" >&2
    exit 1
}

# Downloads a file once (HTTPS only) and verifies its SHA-256.
fetch() {
    local url="$1" sha256="$2" file
    file="$DOWNLOADS/$(basename "$url")"
    mkdir -p "$DOWNLOADS"
    if [ ! -f "$file" ]; then
        curl --fail --location --proto '=https' --tlsv1.2 --retry 3 -o "$file.part" "$url"
        mv "$file.part" "$file"
    fi
    local actual
    actual="$(shasum -a 256 "$file" | awk '{print $1}')"
    if [ "$actual" != "$sha256" ]; then
        rm -f "$file"
        die "checksum mismatch for $(basename "$url"): expected $sha256, got $actual (file deleted)"
    fi
    echo "$file"
}

# Extracts an archive into a fresh directory and prints that directory.
extract() {
    local archive="$1" dest="$2"
    rm -rf "$dest"
    mkdir -p "$dest"
    tar -xf "$archive" -C "$dest"
    echo "$dest"
}

# Copies a project's licence files into the licences folder.
copy_licenses() {
    local name="$1" dir="$2"
    mkdir -p "$LICENSES/$name"
    find "$dir" -maxdepth 2 -type f \( -iname 'COPYING*' -o -iname 'LICEN[CS]E*' -o -iname 'NOTICE*' \) \
        -exec cp {} "$LICENSES/$name/" \;
    [ -n "$(ls -A "$LICENSES/$name")" ] || die "no licence file found for $name in $dir"
}

if [ -f "$STAMP" ] && [ "$(cat "$STAMP")" = "$PIN_ID" ]; then
    echo "    dependencies already built for macOS $MODFS_MIN_MACOS ($PREFIX)"
    exit 0
fi

# A clean environment: only these libraries may be found, never Homebrew's.
unset CPATH C_INCLUDE_PATH CPLUS_INCLUDE_PATH LIBRARY_PATH CFLAGS CXXFLAGS LDFLAGS PKG_CONFIG_PATH
export MACOSX_DEPLOYMENT_TARGET="$MODFS_MIN_MACOS"
export PKG_CONFIG_LIBDIR="$PREFIX/lib/pkgconfig"
ARCH_FLAGS="-arch $MODFS_ARCH -mmacosx-version-min=$MODFS_MIN_MACOS"
JOBS="$(sysctl -n hw.ncpu)"

rm -rf "$DEPS_ROOT"
mkdir -p "$SRC_DIR" "$PREFIX" "$LICENSES"

step "PCRE2 $PCRE2_VERSION"
archive="$(fetch "$PCRE2_URL" "$PCRE2_SHA256")"
src="$(extract "$archive" "$SRC_DIR/pcre2")/pcre2-$PCRE2_VERSION"
# No JIT: the hardened runtime blocks writable+executable memory unless the
# app is given the allow-jit entitlement, which ModFS doesn't need.
(cd "$src" && CFLAGS="$ARCH_FLAGS -O2" ./configure --prefix="$PREFIX" \
    --disable-shared --enable-static --disable-jit \
    --disable-pcre2grep-libz --disable-pcre2grep-libbz2 --disable-pcre2test-libreadline \
    && make -j"$JOBS" && make install) > "$DEPS_ROOT/pcre2.log" 2>&1 || die "PCRE2 build failed (see $DEPS_ROOT/pcre2.log)"
copy_licenses "pcre2-$PCRE2_VERSION" "$src"

step "ICU $ICU_VERSION"
archive="$(fetch "$ICU_URL" "$ICU_SHA256")"
icu_root="$(extract "$archive" "$SRC_DIR/icu")"
icu_src="$(dirname "$(find "$icu_root" -maxdepth 3 -name runConfigureICU | head -1)")"
[ -x "$icu_src/runConfigureICU" ] || die "ICU source layout not recognised"
(cd "$icu_src" && CFLAGS="$ARCH_FLAGS -O2" CXXFLAGS="$ARCH_FLAGS -O2" \
    ./runConfigureICU MacOSX --prefix="$PREFIX" \
    --enable-static --disable-shared --with-data-packaging=static \
    --disable-tests --disable-samples --disable-extras --disable-layoutex --disable-icuio \
    && make -j"$JOBS" && make install) > "$DEPS_ROOT/icu.log" 2>&1 || die "ICU build failed (see $DEPS_ROOT/icu.log)"
copy_licenses "icu-$ICU_VERSION" "$(dirname "$icu_src")"

step "GLib $GLIB_VERSION"
# Second source for the GLib checksum: if Homebrew has the same version, its
# formula records the same tarball hash.
if command -v brew >/dev/null 2>&1; then
    brew_glib="$(brew info --json=v2 glib 2>/dev/null | python3 -c 'import json,sys; f=json.load(sys.stdin)["formulae"][0]; print(f["versions"]["stable"], f["urls"]["stable"]["checksum"])' 2>/dev/null || true)"
    if [ "${brew_glib%% *}" = "$GLIB_VERSION" ] && [ "${brew_glib##* }" != "$GLIB_SHA256" ]; then
        die "GLib $GLIB_VERSION checksum differs from Homebrew's (${brew_glib##* }); not building"
    fi
fi
archive="$(fetch "$GLIB_URL" "$GLIB_SHA256")"
src="$(extract "$archive" "$SRC_DIR/glib")/glib-$GLIB_VERSION"
# Native arm64 build; MACOSX_DEPLOYMENT_TARGET (exported above) sets the
# minimum macOS for every C and Objective-C file meson compiles.
(cd "$src" && meson setup _build --prefix="$PREFIX" --libdir=lib \
    --buildtype=release --default-library=static --wrap-mode=default \
    -Dtests=false -Dintrospection=disabled -Dnls=disabled -Dman-pages=disabled \
    -Ddocumentation=false -Dsysprof=disabled -Dlibelf=disabled \
    && meson compile -C _build && meson install -C _build) > "$DEPS_ROOT/glib.log" 2>&1 \
    || die "GLib build failed (see $DEPS_ROOT/glib.log)"
copy_licenses "glib-$GLIB_VERSION" "$src"
# Licences of any fallback subprojects GLib built into itself (e.g. libintl).
for sub in "$src"/subprojects/*/; do
    [ -d "$sub" ] || continue
    name="$(basename "$sub")"
    case "$name" in packagecache|gvdb) continue ;; esac
    if [ -n "$(find "$sub" -maxdepth 1 -type f \( -iname 'COPYING*' -o -iname 'LICEN[CS]E*' \) | head -1)" ]; then
        copy_licenses "glib-subproject-$name" "$sub"
    fi
done

# Nothing built here may depend on a non-system dylib.
step "Checking the static libraries"
if find "$PREFIX/lib" -name '*.dylib' | grep -q .; then
    die "a shared library was installed into $PREFIX/lib; expected static libraries only"
fi

python3 - "$DEPS_ROOT/manifest.json" <<PY
import json, sys
json.dump([
    {"name": "PCRE2", "version": "$PCRE2_VERSION", "url": "$PCRE2_URL", "sha256": "$PCRE2_SHA256", "license": "BSD-3-Clause (with PCRE2 exception)"},
    {"name": "ICU", "version": "$ICU_VERSION", "url": "$ICU_URL", "sha256": "$ICU_SHA256", "license": "Unicode-3.0"},
    {"name": "GLib", "version": "$GLIB_VERSION", "url": "$GLIB_URL", "sha256": "$GLIB_SHA256", "license": "LGPL-2.1-or-later"},
], open(sys.argv[1], "w"), indent=2)
PY
echo "$PIN_ID" > "$STAMP"
echo "    built into $PREFIX"

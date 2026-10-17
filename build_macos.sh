#!/bin/bash
#
# build_macos.sh — build, sign, notarize and package a ModFS release for macOS
# on Apple Silicon, and stage the release artifacts in ~/NOBuilds.
#
# Usage (on the MacBook, from the repository root):
#   export SONAR_TOKEN=...            # SonarQube token (not stored anywhere)
#   ./build_macos.sh
#
# Steps (each one stops the build on failure; nothing is ignored):
#    1. Host checks: macOS on arm64 (ShadowAgent M-BuildHost).
#    2. Quality gates: analyzer, tests, SonarQube and Snyk
#       (scripts/macos/quality_gates.sh). Nothing is built if they fail.
#    3. Version: build number +1 in pubspec.yaml and lib/version.dart
#       (CP-AutoIncrement).
#    4. Search core: PCRE2, ICU and GLib built from checksum-verified source
#       (scripts/macos/build_deps.sh) and linked statically into
#       libmodfs_core.dylib, for arm64 and macOS $MODFS_MIN_MACOS or later.
#    5. App: flutter build macos --release, thinned to arm64.
#    6. Bundle: the core into the app with the libraries' licences; any
#       non-system dependency left would be copied in and reported
#       (scripts/macos/bundle_dylibs.py), so nothing points outside the app.
#    7. Thin to arm64, check every library's minimum macOS, then sign: every library and framework, then the app, with the Developer ID
#       certificate, hardened runtime and a secure timestamp (M-Signing).
#    8. Smoke test: the signed core loads from inside the app and searches.
#    9. DMG: app + /Applications shortcut (M-DMG-DragInstall), signed,
#       notarized and stapled (M-Notarize-Release), then opened and checked.
#   10. SBOM (CP-SBOM), security report and the NOBuilds drop: DMG, SHA-512,
#       LICENSE, README, corresponding source (.tar.gz), SBOM files, release
#       notes and third-party licences.
#
# 2026-10-16 rewrite: the previous script used the stale prebuilt core, never
# bundled its Homebrew libraries (so the app only ran on Macs with the same
# Homebrew packages), ignored signing failures (`|| true`), incremented the
# version twice, depended on files outside the repo, and lived outside git
# (excluded by .gitignore), contrary to the README's corresponding-source
# promise. It is now tracked in the repository.
#
# Copyright (C) 2026 Chuck Talk <chuck@nordheim.online>. GPLv3 or later.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_DIR"
# shellcheck source=scripts/macos/env.sh
source "$REPO_DIR/scripts/macos/env.sh"

APP_DISPLAY_NAME="ModFS"
BUILT_APP="build/macos/Build/Products/Release/modfs.app"   # Xcode product name
WORK_DIR="build/release"
APP_PATH="$WORK_DIR/$APP_DISPLAY_NAME.app"
# Native output lives in build-native/, not build/: step 5 runs `flutter clean`,
# which deletes all of build/ (2026-10-16: it wiped the core and the
# from-source libraries before step 6 could use them).
CORE_BUILD_DIR="build-native/macos-core"
ENTITLEMENTS="macos/Runner/Release.entitlements"
DMG_BACKGROUND="macos/dmg/dmg_background.png"

# Prints a step heading.
step() {
    printf '\n==> %s\n' "$*"
}

# Stops the build with a message.
die() {
    echo "BUILD FAILED: $*" >&2
    exit 1
}

# Prints the deployment target set in the Xcode project (all configurations
# must agree).
project_deployment_target() {
    local targets
    targets="$(grep -Eo 'MACOSX_DEPLOYMENT_TARGET = [0-9.]+' macos/Runner.xcodeproj/project.pbxproj \
        | awk '{print $3}' | sort -u)"
    [ "$(echo "$targets" | wc -l | tr -d ' ')" = "1" ] || die "MACOSX_DEPLOYMENT_TARGET differs between configurations: $targets"
    echo "$targets"
}

# Prints the minimum macOS a Mach-O file was built for.
macho_minos() {
    otool -l "$1" | awk '/LC_BUILD_VERSION/{f=1} f&&/minos/{print $2; exit}'
}

# Lists every Mach-O file inside the app (executables, dylibs, framework binaries).
app_macho_files() {
    find "$APP_PATH" -type f -print0 | while IFS= read -r -d '' file; do
        if file -b "$file" | grep -q 'Mach-O'; then
            echo "$file"
        fi
    done
}

# Signs one item with the Developer ID, hardened runtime and a timestamp.
sign() {
    codesign --force --timestamp --options runtime --sign "$MODFS_SIGNING_IDENTITY" "$@"
}

# Prints the SHA-1 hash of the signing certificate to use.
# Why (2026-10-17): the keychain held two valid certificates with the same
# Developer ID name (an older one and its renewal), and codesign refuses an
# ambiguous name. Signing by hash is exact. Only certificates codesign accepts
# (`find-identity -v`: not expired or revoked) are considered, and the one
# that expires last is chosen. MODFS_SIGNING_IDENTITY may also be set to a hash.
resolve_signing_identity() {
    local name="$MODFS_SIGNING_IDENTITY" hashes hash end best="" best_end=""
    if [[ "$name" =~ ^[0-9A-Fa-f]{40}$ ]]; then
        echo "$name"
        return
    fi
    hashes="$(security find-identity -v -p codesigning | awk -v n="\"$name\"" 'index($0, n) {print $2}')"
    [ -n "$hashes" ] || die "no valid signing identity named \"$name\" (security find-identity -v -p codesigning)"
    for hash in $hashes; do
        end="$(security find-certificate -a -Z -p -c "$name" | awk -v h="$hash" '
            /^SHA-1 hash:/ { take = ($3 == h) }
            take && /BEGIN CERTIFICATE/ { p = 1 }
            take && p { print }
            /END CERTIFICATE/ { p = 0 }' \
            | openssl x509 -noout -enddate | cut -d= -f2 \
            | python3 -I -c 'import sys, datetime; print(datetime.datetime.strptime(sys.stdin.read().strip(), "%b %d %H:%M:%S %Y %Z").strftime("%Y%m%d%H%M%S"))')" \
            || die "could not read the expiry date of signing certificate $hash"
        if [ -z "$best" ] || [[ "$end" > "$best_end" ]]; then
            best="$hash"
            best_end="$end"
        fi
    done
    echo "$best"
}

# M-FlutterCodesign: gives a flat framework the Versions/A layout codesign
# expects, so it isn't rejected as "bundle format is ambiguous".
fix_flat_framework() {
    local framework="$1" binary_name
    binary_name="$(basename "$framework" .framework)"
    if [ -f "$framework/$binary_name" ] && [ ! -L "$framework/$binary_name" ]; then
        echo "    restructuring $binary_name.framework"
        mkdir -p "$framework/Versions/A"
        mv "$framework/$binary_name" "$framework/Versions/A/"
        if [ -d "$framework/Resources" ] && [ ! -L "$framework/Resources" ]; then
            mv "$framework/Resources" "$framework/Versions/A/"
        fi
        ln -sfn A "$framework/Versions/Current"
        ln -sfn Versions/Current/Resources "$framework/Resources"
        ln -sfn "Versions/Current/$binary_name" "$framework/$binary_name"
    fi
}

# ---------------------------------------------------------------------------
step "1. Host checks"
[ "$(uname -s)" = "Darwin" ] || die "macOS builds must run on the MacBook (M-BuildHost)"
[ "$(uname -m)" = "$MODFS_ARCH" ] || die "this release is Apple Silicon only; host is $(uname -m)"
for tool in flutter meson ninja python3 create-dmg syft snyk sonar-scanner xcrun codesign; do
    command -v "$tool" >/dev/null 2>&1 || die "$tool is not installed (run scripts/macos/preflight.sh)"
done
DEPLOYMENT_TARGET="$(project_deployment_target)"
[ "$DEPLOYMENT_TARGET" = "$MODFS_MIN_MACOS" ] \
    || die "Xcode deployment target $DEPLOYMENT_TARGET differs from MODFS_MIN_MACOS $MODFS_MIN_MACOS (scripts/macos/env.sh)"
grep -q "platform :osx, '$MODFS_MIN_MACOS'" macos/Podfile || die "macos/Podfile platform differs from $MODFS_MIN_MACOS"
echo "    macOS $(sw_vers -productVersion); app supports macOS $DEPLOYMENT_TARGET or later"
MODFS_SIGNING_IDENTITY="$(resolve_signing_identity)" || exit 1
echo "    signing certificate: $MODFS_SIGNING_IDENTITY (SHA-1)"

# ---------------------------------------------------------------------------
step "2. Quality gates"
bash scripts/macos/quality_gates.sh

# ---------------------------------------------------------------------------
step "3. Version"
current_version="$(grep -E '^version: ' pubspec.yaml | awk '{print $2}')"
base_version="${current_version%%+*}"
build_number="${current_version##*+}"
new_version="$base_version+$((build_number + 1))"
sed -i '' "s/^version: .*/version: $new_version/" pubspec.yaml
cat > lib/version.dart <<VERSION
// Keep in step with the version in pubspec.yaml (test/helpers_test.dart checks).
// Written by build_macos.sh (CP-AutoIncrement).
const String appVersion = '$new_version';
VERSION
echo "    $current_version -> $new_version"

# ---------------------------------------------------------------------------
step "4. Search core (libmodfs_core.dylib, $MODFS_ARCH, macOS $DEPLOYMENT_TARGET+)"
bash scripts/macos/build_deps.sh
DEPS_ROOT="$REPO_DIR/build-native/deps/macos-${MODFS_MIN_MACOS}-${MODFS_ARCH}"
rm -rf "$CORE_BUILD_DIR"
# Only the libraries built by build_deps.sh may be found (never Homebrew's),
# and they are linked statically. ICU is C++, so the C++ runtime (-lc++) is
# linked too. It goes in c_link_args, not LDFLAGS: meson ignores LDFLAGS once
# c_link_args is given (2026-10-17: that dropped -lc++ and the link failed).
# The minimum macOS is passed as compiler and linker flags so meson writes it
# into build.ninja. (2026-10-17: setting only MACOSX_DEPLOYMENT_TARGET for
# `meson setup` did not reach the compiler, which runs later under `meson
# compile`, so the core came out as macOS 27-only.)
MIN_FLAG="-mmacosx-version-min=$DEPLOYMENT_TARGET"
env -u PKG_CONFIG_PATH -u CPATH -u LIBRARY_PATH \
    PKG_CONFIG_LIBDIR="$DEPS_ROOT/install/lib/pkgconfig" \
    MACOSX_DEPLOYMENT_TARGET="$DEPLOYMENT_TARGET" \
    meson setup "$CORE_BUILD_DIR" --buildtype=release -Db_ndebug=true -Dprefer_static=true \
        -Dc_args="['$MIN_FLAG']" -Dc_link_args="['$MIN_FLAG','-lc++']"
MACOSX_DEPLOYMENT_TARGET="$DEPLOYMENT_TARGET" meson compile -C "$CORE_BUILD_DIR" modfs_core
CORE_DYLIB="$CORE_BUILD_DIR/src/libmodfs_core.dylib"
[ -f "$CORE_DYLIB" ] || die "core library was not built"
# Fail here, not after the Flutter build, if the core needs a newer macOS.
[ "$(macho_minos "$CORE_DYLIB")" = "$DEPLOYMENT_TARGET" ] \
    || die "core library needs macOS $(macho_minos "$CORE_DYLIB"), expected $DEPLOYMENT_TARGET"
# The development copy in src/ is what `flutter run` loads; keep it current.
cp "$CORE_DYLIB" src/libmodfs_core.dylib
echo "    links: $(otool -L "$CORE_DYLIB" | tail -n +2 | awk '{print $1}' | tr '\n' ' ')"

# ---------------------------------------------------------------------------
step "5. Flutter app"
flutter clean
flutter pub get
flutter build macos --release --build-name="$base_version" --build-number="$((build_number + 1))"
[ -d "$BUILT_APP" ] || die "flutter did not produce $BUILT_APP"
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"
# Shipped as ModFS.app (the Xcode product, and so the executable, is "modfs").
ditto "$BUILT_APP" "$APP_PATH"
xattr -cr "$APP_PATH"
find "$APP_PATH" -name ".DS_Store" -delete

# ---------------------------------------------------------------------------
step "6. Bundle the core and its libraries"
FRAMEWORKS="$APP_PATH/Contents/Frameworks"
LICENSES_DIR="$APP_PATH/Contents/Resources/ThirdPartyLicenses"
mkdir -p "$FRAMEWORKS"
cp "$CORE_DYLIB" "$FRAMEWORKS/libmodfs_core.dylib"
chmod 755 "$FRAMEWORKS/libmodfs_core.dylib"
install_name_tool -id "@rpath/libmodfs_core.dylib" "$FRAMEWORKS/libmodfs_core.dylib"
python3 scripts/macos/bundle_dylibs.py "$FRAMEWORKS/libmodfs_core.dylib" \
    --licenses-dir "$LICENSES_DIR" \
    --manifest "$WORK_DIR/bundled_libraries.json"
# Licences of the libraries built into the core, and ModFS's own.
cp -R "$DEPS_ROOT/licenses/." "$LICENSES_DIR/"
cp LICENSE "$LICENSES_DIR/ModFS-LICENSE.txt"
cp THIRD_PARTY_LICENSES.md "$LICENSES_DIR/"

# ---------------------------------------------------------------------------
step "7. Apple Silicon only, minimum macOS, signing"
# Remove any Intel slices so the app can't start (and crash) on Intel Macs.
while IFS= read -r macho; do
    archs="$(lipo -archs "$macho" 2>/dev/null || true)"
    if [ "$archs" != "$MODFS_ARCH" ] && echo "$archs" | grep -qw "$MODFS_ARCH"; then
        lipo "$macho" -thin "$MODFS_ARCH" -output "$macho.thin" && mv "$macho.thin" "$macho"
    elif ! echo "$archs" | grep -qw "$MODFS_ARCH"; then
        die "$macho has no $MODFS_ARCH code (archs: ${archs:-none})"
    fi
done < <(app_macho_files)

# Every bundled library must run on the macOS version the app says it supports.
while IFS= read -r macho; do
    minos="$(macho_minos "$macho")"
    if [ -n "$minos" ] && [ "$(printf '%s\n%s\n' "$DEPLOYMENT_TARGET" "$minos" | sort -V | tail -1)" != "$DEPLOYMENT_TARGET" ]; then
        die "$(basename "$macho") needs macOS $minos but the app declares $DEPLOYMENT_TARGET; raise MACOSX_DEPLOYMENT_TARGET"
    fi
done < <(app_macho_files)

for framework in "$FRAMEWORKS"/*.framework; do
    fix_flat_framework "$framework"
done
# Inside-out signing: libraries, then frameworks, then the app. No --deep.
for dylib in "$FRAMEWORKS"/*.dylib; do
    sign "$dylib"
done
for framework in "$FRAMEWORKS"/*.framework; do
    sign "$framework"
done
sign --entitlements "$ENTITLEMENTS" "$APP_PATH"
codesign --verify --strict --deep --verbose=2 "$APP_PATH"

# ---------------------------------------------------------------------------
step "8. Smoke test of the bundled search core"
# Loads the signed core from inside the app and runs a search, proving it and
# its bundled libraries load without Homebrew paths.
python3 scripts/macos/smoke_test_core.py "$FRAMEWORKS/libmodfs_core.dylib"

# ---------------------------------------------------------------------------
step "9. DMG, notarization and stapling"
DMG_NAME="${APP_DISPLAY_NAME}_${base_version}_macos-arm64.dmg"
DMG_PATH="$WORK_DIR/$DMG_NAME"
STAGING_DIR="$WORK_DIR/dmg_staging"
mkdir -p "$STAGING_DIR"
ditto "$APP_PATH" "$STAGING_DIR/$APP_DISPLAY_NAME.app"
ln -sfn /Applications "$STAGING_DIR/Applications"     # M-DMG-DragInstall
create-dmg \
    --volname "$APP_DISPLAY_NAME" \
    --volicon "$APP_PATH/Contents/Resources/AppIcon.icns" \
    --background "$DMG_BACKGROUND" \
    --window-pos 200 120 \
    --window-size 600 400 \
    --icon-size 120 \
    --icon "$APP_DISPLAY_NAME.app" 150 190 \
    --hide-extension "$APP_DISPLAY_NAME.app" \
    --icon "Applications" 450 185 \
    "$DMG_PATH" "$STAGING_DIR/"
[ -f "$DMG_PATH" ] || die "create-dmg did not produce $DMG_PATH"
sign "$DMG_PATH"
xcrun notarytool submit "$DMG_PATH" --keychain-profile "$MODFS_NOTARY_PROFILE" --wait \
    | tee "$WORK_DIR/notarization.log"
grep -q "status: Accepted" "$WORK_DIR/notarization.log" || die "notarization was not accepted (see $WORK_DIR/notarization.log)"
xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"
spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG_PATH"

# Verify the DMG opens and contains the app and the Applications shortcut, and
# that Gatekeeper accepts the app inside it (M-Notarize-Release).
MOUNT_POINT="$(mktemp -d)"
hdiutil attach "$DMG_PATH" -nobrowse -readonly -mountpoint "$MOUNT_POINT" > /dev/null
trap 'hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true' EXIT
[ -d "$MOUNT_POINT/$APP_DISPLAY_NAME.app" ] || die "DMG has no $APP_DISPLAY_NAME.app"
[ -L "$MOUNT_POINT/Applications" ] || die "DMG has no Applications shortcut"
spctl --assess --type execute --verbose=2 "$MOUNT_POINT/$APP_DISPLAY_NAME.app"
hdiutil detach "$MOUNT_POINT" -quiet
trap - EXIT

# ---------------------------------------------------------------------------
step "10. SBOM, security report and NOBuilds drop"
mkdir -p Audit
syft dir:. \
    --exclude ./build --exclude ./.dart_tool --exclude ./macos/Pods \
    --exclude ./linux --exclude ./plan --exclude ./src/test_build \
    -o cyclonedx-json > Audit/SBOM-macOS.json
cp Audit/SBOM-macOS.json Audit/SBOM-macOS
cp Audit/SBOM-macOS.json Audit/sbom.json
cp "$WORK_DIR/bundled_libraries.json" Audit/bundled_libraries_macos.json
cp "$DEPS_ROOT/manifest.json" Audit/static_libraries_macos.json

DROP_DIR="$HOME/NOBuilds/${APP_DISPLAY_NAME}-macOS-$(date +%-m-%-d-%Y)-v${new_version}"
mkdir -p "$DROP_DIR"
cp "$DMG_PATH" "$DROP_DIR/"
(cd "$DROP_DIR" && shasum -a 512 "$DMG_NAME" > "$DMG_NAME.sha512")
cp LICENSE README.md "$DROP_DIR/"
cp Audit/SBOM-macOS.json Audit/SBOM-macOS Audit/sbom.json "$DROP_DIR/"
cp Audit/bundled_libraries_macos.json Audit/static_libraries_macos.json "$DROP_DIR/"
cp -R "$LICENSES_DIR" "$DROP_DIR/ThirdPartyLicenses"
# Corresponding source for exactly what was built (tracked and new files,
# including the version bump), as the GPL requires.
# --no-mac-metadata / COPYFILE_DISABLE: leave out macOS extended attributes
# (com.apple.provenance, ACLs), which other systems' tar warns about.
git ls-files -z --cached --others --exclude-standard \
    | COPYFILE_DISABLE=1 tar --null --no-mac-metadata -T - -czf "$DROP_DIR/${APP_DISPLAY_NAME}_${base_version}_source.tar.gz"
python3 scripts/macos/write_security_report.py \
    --version "$new_version" \
    --gates Audit/quality_gates/summary.env \
    --bundled "$WORK_DIR/bundled_libraries.json" \
    --static-libs "$DEPS_ROOT/manifest.json" \
    --dmg "$DROP_DIR/$DMG_NAME" \
    --deployment-target "$DEPLOYMENT_TARGET" \
    --output "$DROP_DIR/security_report.md"
cp "$DROP_DIR/security_report.md" Audit/security_report_macos.md
# Release notes: this version's CHANGELOG section.
awk -v v="$base_version" '
    $0 ~ "^## \\[" v "\\]" {on=1; print; next}
    on && /^## \[/ {exit}
    on {print}
' CHANGELOG.md > "$DROP_DIR/RELEASE_NOTES.md"
[ -s "$DROP_DIR/RELEASE_NOTES.md" ] || die "CHANGELOG.md has no section for $base_version"

echo
echo "Release $new_version is ready in $DROP_DIR:"
ls -1 "$DROP_DIR"
echo
echo "To publish it on GitHub (after committing and pushing), run:"
echo "  gh release create v$new_version --title \"ModFS $base_version for macOS (Apple Silicon)\" \\"
echo "    --notes-file \"$DROP_DIR/RELEASE_NOTES.md\" \"$DROP_DIR/$DMG_NAME\" \"$DROP_DIR/$DMG_NAME.sha512\" \\"
echo "    \"$DROP_DIR/${APP_DISPLAY_NAME}_${base_version}_source.tar.gz\" \"$DROP_DIR/SBOM-macOS.json\""

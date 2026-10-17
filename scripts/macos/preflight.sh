#!/bin/bash
#
# preflight.sh — read-only check of the Mac build host before a ModFS release
# build. Changes nothing. Prints what build_macos.sh needs and what's missing.
#
# Why: the release build signs, notarizes and bundles Homebrew libraries, and
# fails late (after minutes of building) if a tool, credential or library is
# missing. This finds those problems first. (ShadowAgent CP-QueryKB: it also
# searches the ShadowAgent Knowledge Base for past ModFS/macOS build errors.)
#
# Copyright (C) 2026 Chuck Talk <chuck@nordheim.online>. GPLv3 or later.

set -u

ok()   { printf '  [ok]   %s\n' "$*"; }
warn() { printf '  [WARN] %s\n' "$*"; }
fail() { printf '  [FAIL] %s\n' "$*"; FAILURES=$((FAILURES + 1)); }
FAILURES=0

section() { printf '\n== %s\n' "$*"; }

# Prints "minos" (minimum macOS) recorded in a Mach-O binary.
macho_minos() {
    otool -l "$1" 2>/dev/null | awk '/LC_BUILD_VERSION/{f=1} f&&/minos/{print $2; exit}'
}

# shellcheck source=scripts/macos/env.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env.sh"

section "Host"
[ "$(uname -s)" = "Darwin" ] && ok "macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion))" || fail "not macOS (M-BuildHost: build on the MacBook)"
[ "$(uname -m)" = "arm64" ] && ok "Apple Silicon (arm64)" || fail "not arm64: $(uname -m)"
xcodebuild -version 2>/dev/null | head -1 | sed 's/^/  [ok]   /' || fail "Xcode not found"

section "Tools"
for tool in flutter dart meson ninja pkg-config python3 create-dmg syft snyk sonar-scanner osv-scanner gh git; do
    if command -v "$tool" >/dev/null 2>&1; then ok "$tool: $(command -v "$tool")"; else fail "$tool not found"; fi
done
command -v flutter >/dev/null 2>&1 && flutter --version 2>/dev/null | head -1 | sed 's/^/         /'

section "Homebrew libraries the search core links"
BREW_PREFIX="$(brew --prefix 2>/dev/null || true)"
[ -n "$BREW_PREFIX" ] && ok "Homebrew at $BREW_PREFIX" || fail "Homebrew not found"
for formula in glib pcre2 icu4c; do
    if brew list --versions "$formula" >/dev/null 2>&1; then
        ok "$(brew list --versions "$formula")"
    else
        fail "$formula not installed (brew install $formula)"
    fi
done
# Homebrew's copies are used only to build and run the C tests in the quality
# gates; the release links its own builds (scripts/macos/build_deps.sh).
for pc in glib-2.0 gio-unix-2.0 libpcre2-8 icu-uc; do
    if pkg-config --exists "$pc" 2>/dev/null; then
        ok "pkg-config finds $pc"
    else
        fail "pkg-config can't find $pc"
    fi
done
MAX_MINOS="0"
for lib in "$BREW_PREFIX"/opt/glib/lib/libglib-2.0.0.dylib \
           "$BREW_PREFIX"/opt/glib/lib/libgio-2.0.0.dylib \
           "$BREW_PREFIX"/opt/pcre2/lib/libpcre2-8.0.dylib \
           "$BREW_PREFIX"/opt/icu4c/lib/libicuuc.dylib \
           "$BREW_PREFIX"/opt/gettext/lib/libintl.8.dylib; do
    if [ -e "$lib" ]; then
        m="$(macho_minos "$lib")"
        printf '         %-60s minos %s\n' "$(basename "$lib")" "$m"
        if [ "$(printf '%s\n%s\n' "$MAX_MINOS" "$m" | sort -V | tail -1)" = "$m" ]; then MAX_MINOS="$m"; fi
    fi
done
echo "         (Homebrew builds for macOS $MAX_MINOS; the release instead builds these libraries"
echo "          from source for macOS $MODFS_MIN_MACOS, so this doesn't limit the app)"

section "Downloads for the dependency build"
for url in https://github.com https://download.gnome.org/sources/glib/; do
    if curl -s -o /dev/null --max-time 15 --head "$url"; then ok "reachable: $url"; else fail "cannot reach $url"; fi
done

section "Signing and notarization"
if security find-identity -v -p codesigning 2>/dev/null | grep -qF "$MODFS_SIGNING_IDENTITY"; then
    ok "$MODFS_SIGNING_IDENTITY in keychain"
else
    fail "Developer ID Application identity not found (security find-identity -v -p codesigning)"
fi
if xcrun notarytool history --keychain-profile "$MODFS_NOTARY_PROFILE" >/dev/null 2>&1; then
    ok "notarytool keychain profile $MODFS_NOTARY_PROFILE works"
else
    fail "notarytool profile AC_PASSWORD not usable (xcrun notarytool store-credentials AC_PASSWORD ...)"
fi

section "Quality gates"
if command -v snyk >/dev/null 2>&1; then
    if snyk whoami >/dev/null 2>&1; then ok "snyk authenticated as $(snyk whoami 2>/dev/null)"; else fail "snyk not authenticated (snyk auth)"; fi
fi
SONAR_URL="${SONAR_HOST_URL:-http://localhost:9000}"
status="$(curl -s --max-time 5 "$SONAR_URL/api/system/status" 2>/dev/null)"
case "$status" in
    *'"status":"UP"'*) ok "SonarQube up at $SONAR_URL" ;;
    *) fail "SonarQube not reachable/UP at $SONAR_URL (got: ${status:-nothing})" ;;
esac
[ -n "${SONAR_TOKEN:-}" ] && ok "SONAR_TOKEN is set" || fail "SONAR_TOKEN is not set in this shell"

section "ShadowAgent Knowledge Base (past errors)"
KB="$(find "$HOME/Library/Containers" -name collabsync.db -path '*shadow*' 2>/dev/null | head -1)"
if [ -n "$KB" ] && command -v sqlite3 >/dev/null 2>&1; then
    ok "KB: $KB"
    sqlite3 "$KB" "SELECT id, created_at, error_message FROM errors
                   WHERE lower(error_message || context || solution) GLOB '*modfs*'
                      OR lower(error_message || context || solution) GLOB '*codesign*'
                      OR lower(error_message || context || solution) GLOB '*notar*'
                      OR lower(error_message || context || solution) GLOB '*dmg*'
                      OR lower(error_message || context || solution) GLOB '*dylib*'
                      OR lower(error_message || context || solution) GLOB '*flutter*macos*';" \
        | sed 's/^/         /'
    echo "         (end of matching KB entries)"
else
    warn "ShadowAgent KB (collabsync.db) not found under ~/Library/Containers"
fi

section "Result"
if [ "$FAILURES" -eq 0 ]; then echo "  Ready to build."; else echo "  $FAILURES problem(s) above must be fixed before building."; fi
exit "$FAILURES"

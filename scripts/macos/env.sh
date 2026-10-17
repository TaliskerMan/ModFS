#!/bin/bash
# shellcheck disable=SC2034  # variables are used by the scripts that source this file
# env.sh — shared settings for the ModFS macOS build scripts (sourced, not run).
# Kept in one place so preflight, the quality gates and the build agree.
# Copyright (C) 2026 Chuck Talk <chuck@nordheim.online>. GPLv3 or later.

# Developer ID identity in the login keychain (M-Signing) and the notarytool
# keychain profile (M-Notarize-Release).
MODFS_SIGNING_IDENTITY="${MODFS_SIGNING_IDENTITY:-Developer ID Application: Charles Talk (89B5GL8WMK)}"
MODFS_NOTARY_PROFILE="${MODFS_NOTARY_PROFILE:-AC_PASSWORD}"

# Apple Silicon only.
MODFS_ARCH="arm64"

# Oldest macOS the app supports. The C libraries are built for it by
# scripts/macos/build_deps.sh; keep MACOSX_DEPLOYMENT_TARGET in
# macos/Runner.xcodeproj and the Podfile in step (build_macos.sh checks).
MODFS_MIN_MACOS="14.0"

# ICU is keg-only in Homebrew, so pkg-config (used by meson) needs its path.
if command -v brew >/dev/null 2>&1; then
    MODFS_BREW_PREFIX="$(brew --prefix)"
    PKG_CONFIG_PATH="$(brew --prefix icu4c 2>/dev/null)/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
    export PKG_CONFIG_PATH
fi

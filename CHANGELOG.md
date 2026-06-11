# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

## [1.0.0] - 2026-06-10
### Added
- Native C search engine core FFI dynamic linkage support (`libmodfs_core.dylib`).
- Added automated `build_macos.sh` release build script for codesigning, notarization, symlink rebuilding, and DMG staging.
- Preferences pane configurations (Include/Exclude paths lists).
- Diagnostic structured logging capabilities.

### Hardened
- Implemented Apple Hardened Runtime signing with custom entitlements.
- Configured dynamic library validation exemption to ensure FFI loads shared system dependencies without process execution interrupts.
- Fully offline operation with zero remote data collection or telemetry.

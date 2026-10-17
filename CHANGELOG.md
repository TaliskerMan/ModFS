# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

## [1.0.4] - 2026-10-16
### Fixed
- **Settings could crash the app.** Every added or removed folder started a
  new index rebuild immediately, freeing the index a running rebuild was still
  using. Rebuilds are now never run in parallel (a request during a rebuild is
  queued), and Settings changes rebuild once, when Settings closes.
- **Indexing failures were silent.** A failed scan, save or load of the index
  is now reported under the status line, and folders in Include Paths that
  don't exist are named as skipped.
- **Search results were cut off without saying so.** ModFS still shows up to
  200 folders and 500 files, and now says how many were found
  ("Showing 500 of 12,345 files").
- The About screen showed version 1.0.0+29; it now matches the release (a test
  checks it against `pubspec.yaml`).
- Include Paths only accepts full paths to folders that exist. The always-on
  system exclusions are shown with a lock instead of a Remove button that was
  undone on the next launch.

### Added
- A **?** button in the search box listing the search syntax (wildcards,
  `ext:`, `size:`, `dm:`, `folder:`/`file:`, `path:`, `case:`, `regex:`,
  `OR`/`NOT`). Every example was checked against the ModFS engine.
- The status line shows when the index was last updated and that it doesn't
  update automatically.

### macOS release build (Apple Silicon, macOS 14+)
- **Licence:** ModFS as a whole is now distributed under the GNU GPL, version 3
  or later (FSearch's GPLv2-or-later licence permits this). `LICENSE` holds the
  GPLv3 text. Settings → About shows FSearch's copyright and licence first,
  then the fork's, credits the FSearch contributors and can display the licence.
- **The app now runs on other Macs.** The previous build copied in the search
  library, which loaded GLib, PCRE2 and ICU from Homebrew paths that other
  Macs don't have. These libraries are now built from checksum-verified source
  for macOS 14 and linked statically into the search library; the app ships no
  third-party dylibs, and their licences are included in the app.
- The search library no longer links GTK or Pango (only FSearch's GUI
  highlighting used them, which ModFS doesn't show).
- **Apple Silicon only**, macOS 14 Sonoma or later; Intel code is removed.
- App icons are now the sizes macOS expects (several were a few pixels short,
  so macOS scaled them up and they looked soft).
- The app no longer disables library validation: every library in it is
  signed with the same Developer ID.
- `build_macos.sh` is rewritten and now in the repository (it was excluded by
  `.gitignore`, contrary to the corresponding-source statement). It runs real
  quality gates first (analyzer, Dart and C tests, SonarQube, Snyk,
  OSV-Scanner), signs every component without ignoring failures, notarizes,
  staples and verifies the DMG, and writes the release's security report from
  the tools' actual results.
- Fixed a memory leak in FSearch's multi-threaded sort (intermediate merge
  arrays were never freed), found with AddressSanitizer; the C tests now run
  clean under ASan/UBSan.
- Removed old Linux scratch programs and experiment files from the repository
  root, an unused Linux GPG key (`public.key`) and the unused `url_launcher`
  dependency.

### Removed (claims and Linux packaging)
- README, docs and package metadata claimed sorting from the UI; ModFS lists
  results in name order and has no sort control. The claim is gone.
- ModFS is macOS-only. Removed the Linux `.deb` packaging
  (`scripts/package_linux.sh`, `debian/`, `linbld/` and its Linux guide) and
  FSearch's inherited Snap/COPR packaging. The Linux packaging had stopped
  signing releases (its `gpg` calls had been replaced with `true`), shipped an
  empty public key, declared no dependencies, and installed files owned by
  user 1000 rather than root. `linux/` remains only as a development runner.
- `ModFS_Documentation.md` and `ModFSMacDocs/` described things the app doesn't
  do (sorting, file monitoring, Linux packages, placeholder screenshots); they
  now point to the user guide.
- SECURITY.md contact changed to chuck@nordheim.online.

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

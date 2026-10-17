# ModFS 1.0.4+38 — macOS (Apple Silicon) security and quality report

**Date:** 2026-10-17  
**Gates run:** 2026-10-17T13:06:57Z on commit 0bb99b9 + uncommitted changes  
**Requires:** macOS 14.0 or later on Apple Silicon (arm64 only)

## Quality gates (all must pass before the build continues)

| Gate | Result |
|---|---|
| Dart analyzer (`flutter analyze`) | No issues found |
| Dart tests (`flutter test`) | +15: All tests passed! |
| C core tests (`meson test`) | Ok: 5  passed, Fail: 0  |
| SonarQube | Quality gate passed (http://localhost:9000/dashboard?id=TaliskerMan_ModFS) |
| Snyk Code (SAST) | No issues at severity medium or above |
| Snyk Open Source | No vulnerable dependencies at severity medium or above |
| OSV-Scanner (pubspec.lock) | No known vulnerabilities in pubspec.lock |

Raw tool output is in `Audit/quality_gates/` in the source.

## Libraries built into the search core

Built from source by `scripts/macos/build_deps.sh`, each download verified against the
SHA-256 below, and linked statically into `libmodfs_core.dylib`. Their licence files
are in `ModFS.app/Contents/Resources/ThirdPartyLicenses`.

| Library | Version | Licence | Source SHA-256 |
|---|---|---|---|
| PCRE2 | 10.49 | BSD-3-Clause (with PCRE2 exception) | `53c156e1ba416a20da8e65395daa132da0d80e76910424caca3fcdae7831d384` |
| ICU | 78.3 | Unicode-3.0 | `3a2e7a47604ba702f345878308e6fefeca612ee895cf4a5f222e7955fabfe0c0` |
| GLib | 2.90.1 | LGPL-2.1-or-later | `93c941aa17d5eb1d53fe838365f29a8b4e539c222a256d974ec8f30fc413e396` |

Other shared libraries copied into the app: none (the core uses only macOS system libraries).

## Signing and notarization

- Signed inside-out (libraries, frameworks, app) with the hardened runtime and a secure timestamp.
- Authority=Developer ID Application: Charles Talk (89B5GL8WMK)
- Authority=Developer ID Certification Authority
- Authority=Apple Root CA
- Notarization ticket: The validate action worked!
- DMG SHA-512: `25b562c2269078e78e467358a00151d2cd54597841c152af8f929acf16fa8b0040439ad1369bc4aa435f3f9323eaad864339c8af563d56a4d2e3bc7e7381389f`

## What ModFS does with your data

- Indexes the folders you choose (names, sizes, dates — not file contents) into
  `~/Library/Application Support/io.github.taliskerman.modfs/database.fsearch`.
- No network access, no telemetry. The app sandbox is off so it can index the folders you choose.
- Diagnostic log: `modfs.log` in the same folder.

## Licence

ModFS is distributed under the GNU GPL, version 3 or later. It is a fork of FSearch
(© Christian Boxdörfer, GPLv2 or later). The corresponding source is in the release
as `ModFS_<version>_source.tar.gz` and at https://github.com/TaliskerMan/ModFS.

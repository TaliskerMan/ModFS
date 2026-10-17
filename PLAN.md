# Plan for ModFS
- Untrack sonar-project.properties from GitHub and add to .gitignore

## 2026-10-16 — macOS release 1.0.4 (Apple Silicon, macOS 14+)
Decisions (Chuck): macOS only; no sort UI (claim removed); keep the 200/500
result cap and say so; search-syntax help button; GPLv3-or-later; build the C
libraries from source for macOS 14 instead of bundling Homebrew's (macOS 27).

- [x] Claims fixed (see CHANGELOG 1.0.4) and Linux packaging removed
- [x] Rebuild/Settings crash fixed; failures reported; result cap explained
- [x] About page per CP-AboutPage; LICENSE = GPLv3
- [x] Core no longer links GTK/Pango; sort leak fixed; ASan/UBSan clean
- [x] build_macos.sh in git; scripts/macos/ (preflight, gates, deps, bundle,
      smoke test, security report)
- [ ] Snyk authenticated on the build Mac (`snyk auth`)
- [ ] build_deps.sh run on the Mac (PCRE2 10.49, ICU 78.3, GLib 2.90.1)
- [ ] Quality gates pass (analyze, tests, SonarQube, Snyk, OSV)
- [ ] Signed, notarized DMG; NOBuilds drop
- [ ] Commit, push, GitHub release; remove old Linux release assets

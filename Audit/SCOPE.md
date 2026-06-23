# ModFS audit scope

ModFS has exactly two code surfaces that matter for security review. Audits
must target these — not whatever toolchain the scanner happened to run in.

## 1. The native C core (FSearch) + the FFI boundary
- Tool: `cppcheck` (see `cppcheck.log`), plus manual review of the Dart↔C FFI
  shim (`lib/ffi.dart`, `lib/main.dart`).
- What matters: memory safety across the FFI boundary — every native
  allocation (`db`, search-result pointers, returned strings) must be freed on
  all paths, including error/cancel (`freeDatabase`, `freeSearchResult`,
  `modfs_free_string`).

## 2. The Dart / pub dependency tree
- Tool: `flutter pub outdated` (see `flutter_outdated.log`) and
  `dart pub audit` / OSV against `pubspec.lock`.

## ⚠ Known mis-scoped artifact — do not treat as a ModFS finding

`vulnerabilities.txt` (and the duplicate root `ModFS_vulnerability_report.txt`)
is a **Go-module** scan: `github.com/go-jose`, `go-git`, `aws-sdk-go-v2`,
`go.opentelemetry.io/otel`, etc. **ModFS has no Go dependencies.** Those entries
are vulnerabilities of the *scanning/build tooling* (a Go-based SBOM/scanner),
not of ModFS. This report scanned the wrong target and provides false
assurance; it must be regenerated against the two surfaces above before it is
cited as a clean bill of health.

## Regenerating correctly
```sh
# C core
cppcheck --enable=warning,style,performance --inline-suppr src/ 2>&1 | tee Audit/cppcheck.log
# Dart deps
flutter pub outdated | tee Audit/flutter_outdated.log
dart pub global activate pana >/dev/null 2>&1 || true
# OSV scan of the Dart lockfile (no Go modules involved)
osv-scanner --lockfile=pubspec.lock | tee Audit/dart_osv.txt
```

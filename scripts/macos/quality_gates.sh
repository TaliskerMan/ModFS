#!/bin/bash
#
# quality_gates.sh — the checks a ModFS release must pass before anything is
# built for release. Any failure stops the release (non-zero exit).
#
#   1. flutter analyze        (no issues allowed)
#   2. flutter test           (Dart unit and widget tests)
#   3. meson test             (FSearch C core tests, built from source here)
#   4. SonarQube              (real scan; waits for the quality gate result)
#   5. Snyk Code (SAST)       (C and Dart source; medium severity or worse fails)
#   6. Snyk Open Source       (dependencies; recorded as "not applicable" only
#                              when Snyk itself reports no supported manifest)
#
# Results are written to Audit/quality_gates/ and summarised in
# Audit/quality_gates/summary.env, which build_macos.sh turns into the
# release's security_report.md. Nothing here prints a result it didn't get
# from the tool itself (2026-10-16: replaces hard-coded "0 vulnerabilities"
# claims found in older release notes and build scripts).
#
# Needs: SONAR_TOKEN in the environment (never written to disk), a running
# SonarQube (SONAR_HOST_URL, default http://localhost:9000), and `snyk auth`.
#
# Copyright (C) 2026 Chuck Talk <chuck@nordheim.online>. GPLv3 or later.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_DIR"
# shellcheck source=scripts/macos/env.sh
source "$REPO_DIR/scripts/macos/env.sh"

OUT_DIR="Audit/quality_gates"
CORE_BUILD_DIR="build-native/gates-core"
SONAR_HOST_URL="${SONAR_HOST_URL:-http://localhost:9000}"
SONAR_PROJECT_KEY="${SONAR_PROJECT_KEY:-TaliskerMan_ModFS}"
SNYK_THRESHOLD="${SNYK_THRESHOLD:-medium}"

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"
SUMMARY="$OUT_DIR/summary.env"
: > "$SUMMARY"

# Records one result line for the security report: KEY="value".
record() {
    printf '%s=%q\n' "$1" "$2" >> "$SUMMARY"
}

# Prints a step heading.
step() {
    printf '\n==> %s\n' "$*"
}

# Stops the release with a reason.
gate_failed() {
    echo "QUALITY GATE FAILED: $*" >&2
    record GATE_RESULT "FAILED: $*"
    exit 1
}

step "Dart analyzer"
flutter pub get > "$OUT_DIR/pub_get.log" 2>&1 || gate_failed "flutter pub get (see $OUT_DIR/pub_get.log)"
if flutter analyze > "$OUT_DIR/flutter_analyze.log" 2>&1; then
    record ANALYZE "No issues found"
else
    cat "$OUT_DIR/flutter_analyze.log"
    gate_failed "flutter analyze reported issues"
fi

step "Dart tests"
if flutter test --reporter expanded > "$OUT_DIR/flutter_test.log" 2>&1; then
    record DART_TESTS "$(grep -Eo '\+[0-9]+: All tests passed!' "$OUT_DIR/flutter_test.log" | tail -1)"
else
    tail -40 "$OUT_DIR/flutter_test.log"
    gate_failed "flutter test failed"
fi

step "C core tests (meson)"
rm -rf "$CORE_BUILD_DIR"
meson setup "$CORE_BUILD_DIR" --buildtype=release > "$OUT_DIR/meson_setup.log" 2>&1 \
    || gate_failed "meson setup (see $OUT_DIR/meson_setup.log)"
if meson test -C "$CORE_BUILD_DIR" > "$OUT_DIR/meson_test.log" 2>&1; then
    record C_TESTS "$(grep -E '^Ok:' "$OUT_DIR/meson_test.log" | tr -s ' ') passed, $(grep -E '^Fail:' "$OUT_DIR/meson_test.log" | tr -s ' ')"
else
    tail -40 "$OUT_DIR/meson_test.log"
    gate_failed "meson test failed"
fi

step "SonarQube ($SONAR_HOST_URL, project $SONAR_PROJECT_KEY)"
[ -n "${SONAR_TOKEN:-}" ] || gate_failed "SONAR_TOKEN is not set"
# The C sources analysed are ModFS's search core; FSearch's archived GTK UI and
# its duplicate test_build copy aren't built or shipped, so they're excluded.
# The token is passed through the environment, never on the command line.
if sonar-scanner \
    -Dsonar.projectKey="$SONAR_PROJECT_KEY" \
    -Dsonar.projectName="ModFS" \
    -Dsonar.host.url="$SONAR_HOST_URL" \
    -Dsonar.sources=lib,src \
    -Dsonar.tests=test \
    -Dsonar.exclusions="src/gtk_archive/**,src/test_build/**,src/tests/**,**/*.ui,**/*.css" \
    -Dsonar.cfamily.compile-commands="$CORE_BUILD_DIR/compile_commands.json" \
    -Dsonar.qualitygate.wait=true \
    -Dsonar.qualitygate.timeout=900 \
    > "$OUT_DIR/sonarqube.log" 2>&1; then
    record SONARQUBE "Quality gate passed ($SONAR_HOST_URL/dashboard?id=$SONAR_PROJECT_KEY)"
else
    tail -30 "$OUT_DIR/sonarqube.log"
    gate_failed "SonarQube quality gate did not pass (see $OUT_DIR/sonarqube.log)"
fi

step "Snyk Code (SAST), severity >= $SNYK_THRESHOLD"
set +e
snyk code test --severity-threshold="$SNYK_THRESHOLD" \
    --json-file-output="$OUT_DIR/snyk_code.json" > "$OUT_DIR/snyk_code.log" 2>&1
snyk_code_status=$?
set -e
case "$snyk_code_status" in
    0) record SNYK_CODE "No issues at severity $SNYK_THRESHOLD or above" ;;
    1) cat "$OUT_DIR/snyk_code.log"; gate_failed "Snyk Code found issues at severity $SNYK_THRESHOLD or above" ;;
    *) cat "$OUT_DIR/snyk_code.log"; gate_failed "Snyk Code could not run (exit $snyk_code_status)" ;;
esac

step "Snyk Open Source (dependencies), severity >= $SNYK_THRESHOLD"
set +e
snyk test --all-projects --severity-threshold="$SNYK_THRESHOLD" \
    --json-file-output="$OUT_DIR/snyk_open_source.json" > "$OUT_DIR/snyk_open_source.log" 2>&1
snyk_oss_status=$?
set -e
case "$snyk_oss_status" in
    0) record SNYK_OPEN_SOURCE "No vulnerable dependencies at severity $SNYK_THRESHOLD or above" ;;
    1) cat "$OUT_DIR/snyk_open_source.log"; gate_failed "Snyk Open Source found vulnerable dependencies" ;;
    3) record SNYK_OPEN_SOURCE "Not applicable: Snyk found no dependency manifest it supports (pubspec.lock is Dart). See OSV result." ;;
    *) cat "$OUT_DIR/snyk_open_source.log"; gate_failed "Snyk Open Source could not run (exit $snyk_oss_status)" ;;
esac

# Dart dependencies: Snyk Open Source doesn't read pubspec.lock, so run
# OSV-Scanner on it when it's installed, as Peaty's releases do.
step "OSV-Scanner on pubspec.lock"
if command -v osv-scanner >/dev/null 2>&1; then
    if osv-scanner scan --lockfile=pubspec.lock > "$OUT_DIR/osv_scanner.log" 2>&1; then
        record OSV_SCANNER "No known vulnerabilities in pubspec.lock"
    else
        cat "$OUT_DIR/osv_scanner.log"
        gate_failed "OSV-Scanner reported vulnerable Dart dependencies"
    fi
else
    record OSV_SCANNER "Not run (osv-scanner not installed)"
fi

record GATE_RESULT "PASSED"
record GATE_DATE "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
record GATE_COMMIT "$(git rev-parse --short HEAD)$(git diff --quiet || echo ' + uncommitted changes')"
echo
echo "All quality gates passed. Details: $OUT_DIR/"

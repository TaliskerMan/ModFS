#!/usr/bin/env python3
# Copyright (C) 2026 Chuck Talk <chuck@nordheim.online>. GPLv3 or later.
"""Write the release's security_report.md from what the build actually found.

Every statement comes from a file produced during this build: the quality-gate
summary (scripts/macos/quality_gates.sh), the list of bundled libraries
(scripts/macos/bundle_dylibs.py) and the signed, notarized DMG. Nothing is
hard-coded as passed (2026-10-16: older ModFS release notes claimed a clean
Snyk scan that no script ran).
"""

import argparse
import hashlib
import json
import shlex
import subprocess
from datetime import date


def read_summary(path):
    """Parse KEY=value lines written by quality_gates.sh (bash %q quoting)."""
    values = {}
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            key, _, raw = line.rstrip("\n").partition("=")
            parts = shlex.split(raw) if raw else [""]
            values[key] = parts[0] if parts else ""
    return values


def command_output(cmd):
    """Return a command's combined output (for signature details)."""
    result = subprocess.run(cmd, capture_output=True, text=True, check=False)
    return (result.stdout + result.stderr).strip()


def sha512(path):
    """SHA-512 of a file."""
    digest = hashlib.sha512()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main():
    """Assemble the report."""
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--version", required=True)
    parser.add_argument("--gates", required=True)
    parser.add_argument("--bundled", required=True)
    parser.add_argument("--static-libs", required=True)
    parser.add_argument("--dmg", required=True)
    parser.add_argument("--deployment-target", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    gates = read_summary(args.gates)
    if gates.get("GATE_RESULT") != "PASSED":
        raise SystemExit("quality gates did not pass; refusing to write a release report")
    with open(args.bundled, encoding="utf-8") as handle:
        bundled = json.load(handle)
    with open(args.static_libs, encoding="utf-8") as handle:
        static_libs = json.load(handle)
    signature = command_output(["codesign", "-dv", "--verbose=2", args.dmg])
    authority = [line for line in signature.splitlines() if line.startswith("Authority=")]
    stapled = command_output(["xcrun", "stapler", "validate", args.dmg])

    lines = [
        f"# ModFS {args.version} — macOS (Apple Silicon) security and quality report",
        "",
        f"**Date:** {date.today().isoformat()}  ",
        f"**Gates run:** {gates.get('GATE_DATE', '')} on commit {gates.get('GATE_COMMIT', '')}  ",
        f"**Requires:** macOS {args.deployment_target} or later on Apple Silicon (arm64 only)",
        "",
        "## Quality gates (all must pass before the build continues)",
        "",
        "| Gate | Result |",
        "|---|---|",
        f"| Dart analyzer (`flutter analyze`) | {gates.get('ANALYZE', 'not run')} |",
        f"| Dart tests (`flutter test`) | {gates.get('DART_TESTS', 'not run')} |",
        f"| C core tests (`meson test`) | {gates.get('C_TESTS', 'not run')} |",
        f"| SonarQube | {gates.get('SONARQUBE', 'not run')} |",
        f"| Snyk Code (SAST) | {gates.get('SNYK_CODE', 'not run')} |",
        f"| Snyk Open Source | {gates.get('SNYK_OPEN_SOURCE', 'not run')} |",
        f"| OSV-Scanner (pubspec.lock) | {gates.get('OSV_SCANNER', 'not run')} |",
        "",
        "Raw tool output is in `Audit/quality_gates/` in the source.",
        "",
        "## Libraries built into the search core",
        "",
        "Built from source by `scripts/macos/build_deps.sh`, each download verified against the",
        "SHA-256 below, and linked statically into `libmodfs_core.dylib`. Their licence files",
        "are in `ModFS.app/Contents/Resources/ThirdPartyLicenses`.",
        "",
        "| Library | Version | Licence | Source SHA-256 |",
        "|---|---|---|---|",
    ]
    lines += [f"| {e['name']} | {e['version']} | {e['license']} | `{e['sha256']}` |" for e in static_libs]
    lines += [
        "",
        "Other shared libraries copied into the app: "
        + (", ".join(f"{e['file']} ({e['formula']} {e['version']})" for e in bundled) if bundled
           else "none (the core uses only macOS system libraries)."),
    ]
    lines += [
        "",
        "## Signing and notarization",
        "",
        "- Signed inside-out (libraries, frameworks, app) with the hardened runtime and a secure timestamp.",
        *[f"- {line}" for line in authority],
        f"- Notarization ticket: {stapled.splitlines()[-1] if stapled else 'unknown'}",
        f"- DMG SHA-512: `{sha512(args.dmg)}`",
        "",
        "## What ModFS does with your data",
        "",
        "- Indexes the folders you choose (names, sizes, dates — not file contents) into",
        "  `~/Library/Application Support/io.github.taliskerman.modfs/database.fsearch`.",
        "- No network access, no telemetry. The app sandbox is off so it can index the folders you choose.",
        "- Diagnostic log: `modfs.log` in the same folder.",
        "",
        "## Licence",
        "",
        "ModFS is distributed under the GNU GPL, version 3 or later. It is a fork of FSearch",
        "(© Christian Boxdörfer, GPLv2 or later). The corresponding source is in the release",
        "as `ModFS_<version>_source.tar.gz` and at https://github.com/TaliskerMan/ModFS.",
        "",
    ]
    with open(args.output, "w", encoding="utf-8") as handle:
        handle.write("\n".join(lines))
    print(f"  wrote {args.output}")


if __name__ == "__main__":
    main()

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
import os
import re
import shlex
import subprocess
from datetime import date

SAFE_CLI_PATH_RE = re.compile(r"^[A-Za-z0-9_./+-]+$")
# 2026-11-21 (MOD-13, CWE-23): Anchor allowed build paths to the canonical
# repository root rather than dynamic os.getcwd(), and enforce os.path.commonpath
# containment before every file open so CLI arguments cannot traverse outside it.
REPO_ROOT = os.path.realpath(
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
)


def _allowed_roots():
    """Return canonical root directories permitted for release-report inputs and outputs."""
    return (REPO_ROOT,)


def safe_path(path, allowed_roots=None):
    """Validate and resolve `path`, requiring canonical containment under an allowed root."""
    if not isinstance(path, str) or not path or "\x00" in path:
        raise ValueError(f"invalid path argument: {path!r}")
    if path.startswith("-"):
        raise ValueError(f"unsafe CLI path argument: {path!r}")
    normalized_parts = path.replace("\\", "/").split("/")
    if ".." in normalized_parts:
        raise ValueError(f"path traversal segment refused in: {path!r}")

    candidate = path if os.path.isabs(path) else os.path.join(REPO_ROOT, path)
    resolved = os.path.realpath(candidate)
    roots = tuple(os.path.realpath(root) for root in (allowed_roots or _allowed_roots()))
    for root in roots:
        if os.path.commonpath([root, resolved]) == root and resolved.startswith(root + os.sep):
            rel = os.path.relpath(resolved, root)
            if not SAFE_CLI_PATH_RE.match(rel):
                raise ValueError(f"unsafe CLI path argument: {path!r}")
            return resolved
    raise ValueError(f"path {path!r} is outside the allowed directories")


def read_summary(path, allowed_roots=None):
    """Parse KEY=value lines written by quality_gates.sh (bash %q quoting)."""
    values = {}
    checked_path = safe_path(path, allowed_roots=allowed_roots)
    with open(checked_path, encoding="utf-8") as handle:
        for line in handle:
            key, _, raw = line.rstrip("\n").partition("=")
            parts = shlex.split(raw) if raw else [""]
            values[key] = parts[0] if parts else ""
    return values


def read_json_manifest(path, allowed_roots=None):
    """Load and return parsed JSON from a canonically validated build manifest path."""
    checked_path = safe_path(path, allowed_roots=allowed_roots)
    with open(checked_path, encoding="utf-8") as handle:
        return json.load(handle)


def write_report(path, content, allowed_roots=None):
    """Write the rendered markdown report to a canonically validated output path."""
    checked_path = safe_path(path, allowed_roots=allowed_roots)
    with open(checked_path, "w", encoding="utf-8") as handle:
        handle.write(content)
    return checked_path


def command_output(prefix, dmg_path, allowed_roots=None):
    """Return a command's combined output (for signature details)."""
    checked_dmg = safe_path(dmg_path, allowed_roots=allowed_roots)
    result = subprocess.run([*prefix, checked_dmg], capture_output=True, text=True, check=False)
    return (result.stdout + result.stderr).strip()


def sha512(path, allowed_roots=None):
    """Compute and return the hexadecimal SHA-512 digest of a validated file."""
    digest = hashlib.sha512()
    checked_path = safe_path(path, allowed_roots=allowed_roots)
    with open(checked_path, "rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main():
    """Assemble and write the macOS release security and quality report."""
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--version", required=True)
    parser.add_argument("--gates", required=True)
    parser.add_argument("--bundled", required=True)
    parser.add_argument("--static-libs", required=True)
    parser.add_argument("--dmg", required=True)
    parser.add_argument("--deployment-target", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    gates_path = safe_path(args.gates)
    bundled_path = safe_path(args.bundled)
    static_libs_path = safe_path(args.static_libs)
    dmg_path = safe_path(args.dmg)
    output_path = safe_path(args.output)

    gates = read_summary(gates_path)
    if gates.get("GATE_RESULT") != "PASSED":
        raise SystemExit("quality gates did not pass; refusing to write a release report")
    bundled = read_json_manifest(bundled_path)
    static_libs = read_json_manifest(static_libs_path)
    signature = command_output(["codesign", "-dv", "--verbose=2"], dmg_path)
    authority = [line for line in signature.splitlines() if line.startswith("Authority=")]
    stapled = command_output(["xcrun", "stapler", "validate"], dmg_path)

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
        f"- DMG SHA-512: `{sha512(dmg_path)}`",
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
    written_path = write_report(output_path, "\n".join(lines))
    print(f"  wrote {written_path}")


if __name__ == "__main__":
    main()

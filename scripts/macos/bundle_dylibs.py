#!/usr/bin/env python3
# Copyright (C) 2026 Chuck Talk <chuck@nordheim.online>. GPLv3 or later.
"""Copy the Homebrew libraries a dylib needs into an app bundle.

Why this exists (2026-10-16): libmodfs_core.dylib links GLib, PCRE2, ICU and
gettext from Homebrew by absolute path (/opt/homebrew/...). Without bundling,
ModFS only starts on Macs that happen to have the same Homebrew packages.

What it does, for the dylib given and everything it pulls in:
  * copies each non-system dependency into the destination folder
    (Contents/Frameworks), once;
  * rewrites every reference to it as @loader_path/<name> and sets each copied
    library's own id to @rpath/<name>, so nothing points outside the app;
  * copies each Homebrew formula's licence files into
    <licenses-dir>/<formula>-<version>/ (LGPL and the other licences require
    their notices to travel with the binaries);
  * writes a JSON manifest of what was bundled (for the SBOM and the security
    report);
  * fails if any reference outside /usr/lib or /System remains.

macOS only: uses otool and install_name_tool from the Xcode command-line tools.
"""

import argparse
import json
import os
import re
import shlex
import shutil
import subprocess
import sys

SYSTEM_PREFIXES = ("/usr/lib/", "/System/")
TOOLS = ("otool", "install_name_tool")
TOOL_FLAGS = ("-L", "-D", "-id", "-change")
LICENSE_PATTERN = re.compile(r"^(COPYING|LICEN[SC]E|NOTICE|AUTHORS)", re.IGNORECASE)


def safe_arg(value):
    """Return `value` if it is safe to hand to otool/install_name_tool.

    Why (2026-10-16, Snyk Code finding): file paths and install names come from
    the command line and from otool output. They are always passed as a list
    (never through a shell), but we still refuse anything that is not a plain
    path: a value starting with "-" could be read as an option, and a value
    containing spaces, quotes or shell characters is never a real Homebrew or
    @rpath name. shlex.quote leaves a value unchanged only when it contains
    nothing but safe characters, so any change means "reject".
    """
    if not value or value.startswith("-") or shlex.quote(value) != value:
        raise RuntimeError(f"refusing unsafe path or install name: {value!r}")
    return value


def checked_file(path):
    """Return the real absolute path of an existing regular file, or raise."""
    real = os.path.realpath(os.path.abspath(path))
    if not os.path.isfile(real):
        raise RuntimeError(f"not a file: {path!r}")
    return safe_arg(real)


def run(cmd):
    """Run a command (no shell), returning stdout; raise with its stderr on failure."""
    if cmd[0] not in TOOLS:
        raise RuntimeError(f"unexpected tool: {cmd[0]!r}")
    cmd = [cmd[0]] + [arg if arg in TOOL_FLAGS else safe_arg(arg) for arg in cmd[1:]]
    result = subprocess.run(cmd, capture_output=True, text=True, check=False, shell=False)
    if result.returncode != 0:
        raise RuntimeError(f"{' '.join(cmd)} failed: {result.stderr.strip()}")
    return result.stdout


def linked_libraries(path):
    """Return the install names a Mach-O file links against (not its own id)."""
    lines = run(["otool", "-L", path]).splitlines()[1:]
    names = [line.strip().split(" (compatibility")[0] for line in lines if line.strip()]
    own_id = run(["otool", "-D", path]).splitlines()[1:]
    own_id = own_id[0].strip() if own_id else None
    return [name for name in names if name != own_id]


def is_system(install_name):
    """True for libraries every Mac has (never bundled)."""
    return install_name.startswith(SYSTEM_PREFIXES)


def resolve(install_name, referencing_file, original_dir):
    """Find the real file behind an install name.

    @loader_path and @rpath references are resolved against the directory the
    referencing library originally lived in (Homebrew), since the copy in the
    app no longer sits next to its siblings until they are copied too.
    """
    if install_name.startswith("@loader_path/") or install_name.startswith("@rpath/"):
        base = original_dir.get(referencing_file, os.path.dirname(referencing_file))
        candidate = os.path.join(base, install_name.split("/", 1)[1])
    else:
        candidate = install_name
    if not os.path.exists(candidate):
        raise RuntimeError(f"{referencing_file} needs {install_name}, which was not found")
    return os.path.realpath(candidate)


def formula_of(real_path):
    """Return (formula, version) for a file inside the Homebrew Cellar."""
    match = re.search(r"/Cellar/([^/]+)/([^/]+)/", real_path)
    return (match.group(1), match.group(2)) if match else (None, None)


def copy_licenses(real_path, licenses_dir, copied):
    """Copy the formula's licence files once per formula/version."""
    formula, version = formula_of(real_path)
    if not formula or (formula, version) in copied:
        return formula, version
    keg = real_path.split(f"/Cellar/{formula}/{version}/")[0] + f"/Cellar/{formula}/{version}"
    target = os.path.join(licenses_dir, f"{formula}-{version}")
    os.makedirs(target, exist_ok=True)
    found = 0
    for root, _dirs, files in os.walk(keg):
        for name in files:
            if LICENSE_PATTERN.match(name):
                shutil.copy2(os.path.join(root, name), os.path.join(target, name))
                found += 1
    if found == 0:
        raise RuntimeError(f"no licence file found for {formula} {version} in {keg}")
    copied.add((formula, version))
    return formula, version


def bundle(core, dest, licenses_dir):
    """Bundle every non-system dependency of `core` into `dest`."""
    os.makedirs(dest, exist_ok=True)
    os.makedirs(licenses_dir, exist_ok=True)
    original_dir = {}          # copied file -> directory it came from
    bundled = {}               # file name -> manifest entry
    licenses_copied = set()
    queue = [core]
    seen = set()
    while queue:
        current = queue.pop()
        if current in seen:
            continue
        seen.add(current)
        for install_name in linked_libraries(current):
            if is_system(install_name):
                continue
            real = resolve(install_name, current, original_dir)
            name = os.path.basename(install_name)
            target = os.path.join(dest, name)
            if name not in bundled:
                shutil.copy2(real, target)
                os.chmod(target, 0o755)
                original_dir[target] = os.path.dirname(real)
                run(["install_name_tool", "-id", f"@rpath/{name}", target])
                formula, version = copy_licenses(real, licenses_dir, licenses_copied)
                bundled[name] = {"file": name, "source": real, "formula": formula, "version": version}
                queue.append(target)
            run(["install_name_tool", "-change", install_name, f"@loader_path/{name}", current])
    return bundled


def verify(dest):
    """Fail if any library in `dest` still references something outside the app."""
    problems = []
    for name in sorted(os.listdir(dest)):
        path = os.path.join(dest, name)
        if not name.endswith(".dylib"):
            continue
        for install_name in linked_libraries(path):
            if not (is_system(install_name) or install_name.startswith("@loader_path/")
                    or install_name.startswith("@rpath/")):
                problems.append(f"{name} -> {install_name}")
    if problems:
        raise RuntimeError("references outside the app remain:\n  " + "\n  ".join(problems))


def main():
    """Command-line entry point."""
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("core", help="dylib already copied into the app (e.g. .../Frameworks/libmodfs_core.dylib)")
    parser.add_argument("--licenses-dir", required=True, help="where to put third-party licence files")
    parser.add_argument("--manifest", required=True, help="JSON file listing what was bundled")
    args = parser.parse_args()
    try:
        core = checked_file(args.core)
        dest = os.path.dirname(core)
        bundled = bundle(core, dest, args.licenses_dir)
        verify(dest)
    except RuntimeError as error:
        print(f"bundle_dylibs: {error}", file=sys.stderr)
        return 1
    with open(args.manifest, "w", encoding="utf-8") as handle:
        json.dump(sorted(bundled.values(), key=lambda e: e["file"]), handle, indent=2)
    for entry in sorted(bundled.values(), key=lambda e: e["file"]):
        print(f"  bundled {entry['file']}  ({entry['formula']} {entry['version']})")
    return 0


if __name__ == "__main__":
    sys.exit(main())

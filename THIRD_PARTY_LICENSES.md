# Third-party components & licenses

ModFS is distributed under the **GNU GPL, version 3 or later** (see `LICENSE`).
The macOS application (Apple Silicon) contains the following third-party
components; each is retained under its own license, and this notice is included
to satisfy those licenses' attribution requirements and the GPL's
corresponding-source terms. The licence files themselves are shipped inside the
app in `ModFS.app/Contents/Resources/ThirdPartyLicenses/`.

| Component | Role | License |
|-----------|------|---------|
| FSearch C core (`libmodfs_core`) | File index and search engine | GPL-2.0-or-later (Christian Boxdörfer); distributed here under GPL-3.0-or-later |
| GLib (incl. GIO, GObject) | Used by the FSearch core; built from source and linked statically | LGPL-2.1-or-later |
| PCRE2 | Regular expressions in search; built from source and linked statically | BSD-3-Clause with PCRE2 exception |
| ICU (icu4c) | Unicode case-folding and normalization; built from source and linked statically | Unicode-3.0 |
| Flutter engine and macOS embedding (`FlutterMacOS.framework`) | UI runtime | BSD-3-Clause |
| `path_provider`, `shared_preferences` plugins | App data folder, settings | BSD-3-Clause |

The exact versions and source checksums of GLib, PCRE2 and ICU used for a
release are recorded in that release's `security_report.md` and in
`Audit/static_libraries_macos.json`; `scripts/macos/build_deps.sh` builds them.

Notes:

- Because the C core is GPL-2.0-or-later ("or any later version") and ModFS
  links it into the distributed binary, the combined work is distributed under
  GPL-3.0-or-later. The BSD, LGPL and Unicode components above are
  GPL-compatible and may be combined and redistributed under the GPL.
- GLib is linked statically. Its LGPL terms are met because the complete
  corresponding source of ModFS, including the build scripts, is available, so
  you can rebuild ModFS against a modified GLib.
- The complete corresponding source for every distributed binary is available at
  <https://github.com/TaliskerMan/ModFS>, as a source archive on each release,
  and by written offer to `chuck@nordheim.online`, as described in the README
  "License" section.

If you find a bundled component missing from this list, please report it to
`chuck@nordheim.online` so the notice can be corrected.

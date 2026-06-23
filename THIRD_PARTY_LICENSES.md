# Third-party components & licenses

ModFS is distributed under the **GNU GPL v2-or-later** (see `LICENSE`). The
distributed application bundles the following third-party components; each is
retained under its own license, and this notice is included to satisfy those
licenses' attribution requirements and the GPL's corresponding-source terms.

| Component | Role | License |
|-----------|------|---------|
| FSearch C core (`libmodfs_core`) | Native file index/search engine | GPL-2.0-or-later (Christian Boxdörfer) |
| Flutter engine / `libflutter_linux_gtk` (Linux), Flutter macOS framework | UI runtime | BSD-3-Clause |
| Dart `dartjni` / FFI runtime (`libdartjni`) | FFI bridge runtime | BSD-3-Clause |
| `url_launcher` plugin (native lib) | Open files/URLs | BSD-3-Clause |
| GTK / GLib / PCRE2 / ICU (Linux build deps of the C core) | Linked by FSearch core | LGPL-2.1+/GPL-compatible |

Notes:

- Because the C core is GPL-2.0-or-later and ModFS links it into the distributed
  binary, the **combined work is GPL-2.0-or-later**. The BSD/LGPL components
  above are GPL-compatible and may be combined and redistributed under the GPL.
- The complete corresponding source for every distributed binary is available at
  <https://github.com/TaliskerMan/ModFS> (and by written offer to
  `chuck@nordheim.online`), as described in the README "License" section.
- The full text of each license is shipped with the corresponding upstream
  component; `LICENSE` in this repository is the GPL text governing the combined
  work.

If you find a bundled component missing from this list, please report it to
`chuck@nordheim.online` so the notice can be corrected.

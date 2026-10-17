<div align="center">
  <img src="assets/modfs.png" alt="ModFS Logo" width="150" />
  <h1>ModFS</h1>
  <p><em>Fast file search for macOS on Apple Silicon: a Flutter front end over the FSearch C search engine.</em></p>
</div>

---

**ModFS** is a **macOS (Apple Silicon)** front end for the incredibly fast [FSearch](https://github.com/cboxdoerfer/fsearch) file-search engine, built with the **Flutter** framework over the original FSearch C indexer via Dart FFI. It brings FSearch's instant, index-backed file search to macOS while reusing the proven C backend.

## License (read this first — ModFS is a GPL work)
ModFS is a **fork** of FSearch, whose C core is licensed **GNU GPL, version 2 or (at your option) any later version**. ModFS takes up that "later version" option: **the entire combined work — Flutter/Dart UI and C core together — is distributed under the GNU GPL, version 3 or (at your option) any later version** ([LICENSE](LICENSE)). FSearch's files keep their original copyright and licence notices. It is not "the C core under GPL and the UI under something else"; the whole binary is GPL.

You are guaranteed the GPL freedoms, including the right to use, study, modify, **fork, and redistribute** ModFS under the same license.

**Corresponding source.** Any binary we distribute (`.dmg`) is accompanied by its complete corresponding source — the modified FSearch C code, the Dart FFI shim, and the build scripts (`build_macos.sh`, `scripts/macos/`) — in this repository at <https://github.com/TaliskerMan/ModFS>, and as a source archive attached to each release. If you received a binary without source, you may request the corresponding source for that version by email to `chuck@nordheim.online`; this is a written offer valid as required by the GPL.

**Distribution channel.** ModFS is distributed only as a **direct `.dmg`** download. It is **not** distributed via the Mac App Store, whose terms (DRM and usage restrictions) are generally incompatible with the GPL.

## Genesis & credit
The FSearch C indexer was written by **Christian Boxdörfer** (`christian.boxdoerfer@posteo.de`) and remains under his copyright. The modernization layer (Flutter UI, background Dart isolate workers, macOS FFI bridge, and packaging) is copyright **Chuck Talk** (`chuck@nordheim.online`). Both are distributed together under the GPLv3-or-later described above.

## How it works
ModFS bridges the FSearch C database over Dart FFI, so index building keeps the native C engine's speed (parsing millions of files quickly) while the macOS UI is rendered in Flutter with background isolate workers handling indexing and search.

---

## 🛠 Installation

### macOS
**Requires a Mac with Apple Silicon (M1 or later) running macOS 14 Sonoma or later.** Intel Macs are not supported. ModFS is distributed as a `.dmg` (direct download only — not the Mac App Store), signed with a Developer ID certificate and notarized by Apple.

1. Download the latest `ModFS_<version>_macos-arm64.dmg` and its `.sha512` file from [GitHub Releases](https://github.com/TaliskerMan/ModFS/releases).
2. Optionally check the download: `shasum -a 512 -c ModFS_<version>_macos-arm64.dmg.sha512`
3. Open the image and drag `ModFS` onto the `Applications` shortcut.
4. Launch ModFS from Applications, Launchpad or Spotlight.

The search engine's libraries (GLib, PCRE2, ICU) are built from source and linked into the app; their licences are in `ModFS.app/Contents/Resources/ThirdPartyLicenses`.

### Building from source
On an Apple Silicon Mac with Xcode, Flutter and Homebrew, from the repository root:

```bash
bash scripts/macos/preflight.sh   # read-only check of tools and credentials
./build_macos.sh                  # quality gates, build, sign, notarize, package
```

`build_macos.sh` stops if any quality gate fails (Dart analyzer, Dart and C tests, SonarQube, Snyk). Signing and notarization need a Developer ID certificate; see the comments at the top of the script.

---

## ⚙️ Where ModFS keeps its data

Everything stays on your Mac, in `~/Library/Application Support/io.github.taliskerman.modfs/`:
- `database.fsearch` — the index (names, sizes and dates of the files in your included folders; not their contents)
- `modfs.log` — a diagnostic log to include when reporting a problem

ModFS has no network features and no telemetry.

## 🚀 Usage

1. **Build the index:** the first time you open ModFS, click **Rebuild DB**. ModFS indexes your home folder by default; change the folders under **Settings → Include Paths / Exclude Paths** (the index is rebuilt when you close Settings).
2. **Search:** type in the search box. Results appear as you type: folders first, then files, in name order, with each file's size. Click a result to open it, right-click to open its folder.
3. **Search syntax:** click the **?** in the search box for examples. ModFS uses FSearch's syntax: wildcards (`*.pdf`), filters such as `ext:pdf;docx`, `size:>100mb`, `dm:today`, `folder:` and `file:`, `case:` for case-sensitive matching, `regex:` for regular expressions (PCRE2), and `OR` / `NOT`.

**Good to know**
- ModFS shows up to 200 folders and 500 files per search, and tells you when there were more; type more of the name or add a filter to narrow it down.
- The index does **not** update by itself. Files created, moved or deleted since the last **Rebuild DB** won't show correctly until you rebuild; the status line shows when the index was last updated.
- Results are in name order; there is no sort control.
- To index protected folders (Desktop, Documents, Downloads, other volumes), macOS may ask for permission, or you can grant ModFS **Full Disk Access** in **System Settings → Privacy & Security**.

The full installation and user guide is [docs/ModFS_User_Guide.pdf](docs/ModFS_User_Guide.pdf) (source: [docs/guide/ModFS_User_Guide.md](docs/guide/ModFS_User_Guide.md)).

---

### Copyright & Licensing
- Search engine and core C infrastructure: Copyright © Christian Boxdörfer (`christian.boxdoerfer@posteo.de`)
- Flutter UI, macOS FFI bridge, and app logic: Copyright © Chuck Talk (`chuck@nordheim.online`)
- **License:** GNU General Public License, version 3 or (at your option) any later version (GPLv3-or-later), as permitted by FSearch's GPLv2-or-later licence. The whole combined work is GPL; see [LICENSE](LICENSE) and the "License" section above for the corresponding-source offer.

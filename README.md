<div align="center">
  <img src="assets/modfs.png" alt="ModFS Logo" width="150" />
  <h1>ModFS</h1>
  <p><em>Modern, fast, cross-platform file search utility built on Flutter and natively integrated C backends.</em></p>
</div>

---

**ModFS** is a **macOS** front-end for the incredibly fast [FSearch](https://github.com/cboxdoerfer/fsearch) file-search engine, built with the **Flutter** framework over the original FSearch C indexer via Dart FFI. It brings FSearch's instant, index-backed file search to macOS while reusing the proven C backend.

## License (read this first — ModFS is a GPL work)
ModFS is a **fork** of FSearch, whose C core is licensed **GNU GPL, version 2 or (at your option) any later version**. Because ModFS links the Flutter UI to that GPL C core and distributes the result, **the entire combined work — Flutter/Dart UI and C core together — is covered by the GPLv2-or-later.** It is not "the C core under GPL and the UI under something else"; the whole binary is GPL.

You are guaranteed the GPL freedoms, including the right to use, study, modify, **fork, and redistribute** ModFS under the same license.

**Corresponding source.** Any binary we distribute (`.dmg`) is accompanied by its complete corresponding source — the modified FSearch C code, the Dart FFI shim, and the build scripts — in this repository at <https://github.com/TaliskerMan/ModFS>. If you received a binary without source, you may request the corresponding source for that version by email to `chuck@nordheim.online`; this is a written offer valid as required by the GPL.

**Distribution channel.** ModFS is distributed only as a **direct `.dmg`** download. It is **not** distributed via the Mac App Store, whose terms (DRM and usage restrictions) are generally incompatible with the GPL.

## Genesis & credit
The FSearch C indexer was written by **Christian Boxdörfer** (`christian.boxdoerfer@posteo.de`) and remains under his copyright. The modernization layer (Flutter UI, background Dart isolate workers, macOS FFI bridge, and packaging) is copyright **Chuck Talk** (`chuck@nordheim.online`). Both are distributed together under the GPLv2-or-later described above.

## How it works
ModFS bridges the FSearch C database over Dart FFI, so index building keeps the native C engine's speed (parsing millions of files quickly) while the macOS UI is rendered in Flutter with background isolate workers handling indexing and search.

---

## 🛠 Installation

### macOS
ModFS is distributed as a pre-compiled `.dmg` (direct download only — not the Mac App Store).

1. Download the latest `.dmg` from [GitHub Releases](https://github.com/TaliskerMan/ModFS/releases).
2. Open the image and drag the `ModFS` app into `/Applications`.
3. Launch ModFS from Launchpad or Spotlight.

---

## ⚙️ Configuration

ModFS stores diagnostic logs and local SQLite persistence databases inherently in user-protected space:
- **macOS:** `~/Library/Application Support/io.github.taliskerman.modfs/`

Inside these directories, you will find `modfs.log` which captures diagnostic background scan faults and active metrics.

## 🚀 Usage

1. **Rebuild the DB:** Upon opening ModFS for the first time, click **"Rebuild DB"** to initialize your system index. The top-level Dart isolate efficiently walks your filesystem and feeds it into the hyper-fast C indexer.
2. **Search:** Merely type into the main search field. Results load *as you type* seamlessly filtering wildcards and path locations matching the original FSearch standards.
3. **Advanced Filters:** Utilize PCRE2 RegEx, explicit folder inclusion/exclusion rules, and native instant Sort properties direct from the UI.

---

### Copyright & Licensing
- Search engine and core C infrastructure: Copyright © Christian Boxdörfer (`christian.boxdoerfer@posteo.de`)
- Flutter UI, macOS FFI bridge, and app logic: Copyright © Chuck Talk (`chuck@nordheim.online`)
- **License:** GNU General Public License, version 2 or (at your option) any later version (GPLv2-or-later). The whole combined work is GPL; see [LICENSE](LICENSE) and the "License" section above for the corresponding-source offer.

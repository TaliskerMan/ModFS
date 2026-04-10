<div align="center">
  <img src="assets/modfs.png" alt="ModFS Logo" width="150" />
  <h1>ModFS</h1>
  <p><em>Modern, fast, cross-platform file search utility built on Flutter and natively integrated C backends.</em></p>
</div>

---

**ModFS** is a modernized fork of the incredibly fast [FSearch](https://github.com/cboxdoerfer/fsearch) database tool, brought into the cross-platform future using the **Flutter** framework. ModFS brings instant file search capabilities efficiently to both **Linux** and **macOS** environments while honoring the original C-backend performance that made FSearch great.

## Genesis & Respect for Original Work
ModFS is deeply rooted in the C codebase written by **Christian Boxdörfer** (`christian.boxdoerfer@posteo.de`). The original FSearch is a GTK3/C standalone application modeled for high performance. ModFS respects the original GPL license and retains all copyright belonging to the original FSearch author for the core C indexer infrastructure. 

The modernization layer (Flutter UI, background Dart isolate workers, macOS FFI bridging, and package deployment pipeline) is copyright **Chuck Talk (`chuck@nordheim.online`)**. ModFS is maintained firmly under the original open-source license, enforcing the sanctity of the codebase against hijacking while enhancing platform availability.

## Modernization
By bridging the C indexed database over Dart FFI (Foreign Function Interface), ModFS maintains index building speeds capable of parsing millions of files in mere moments. However, by replacing the GTK3 front-end with Flutter, ModFS achieves smooth, 120hz declarative UI across **macOS** and **Linux**, offering seamless client-side rendering and detached isolate thread management.

---

## 🛠 Installation

### Linux
ModFS distributes a hardened, natively signed `.deb` payload that automatically injects the compiled GTK/Flutter bundle securely.

1. Download the latest `.deb` package from the [GitHub Releases](https://github.com/TaliskerMan/ModFS/releases).
2. Install via your package manager:
   ```bash
   sudo dpkg -i ModFS_linux_1.0.0-9_amd64.deb
   ```
3. Launch `modfs` locally from your applications menu.

### macOS
For macOS users, ModFS is distributed as a pre-compiled `.dmg` package bypassing the requirement for Sandbox entitlement collisions via static FFI resolution.

1. Download the latest `.dmg` package from [GitHub Releases](https://github.com/TaliskerMan/ModFS/releases).
2. Open the image and drag the `ModFS` app directly into your `/Applications` shortcut.
3. Launch ModFS from Launchpad.

---

## ⚙️ Configuration

ModFS stores diagnostic logs and local SQLite persistence databases inherently in user-protected space:
- **Linux:** `~/.local/share/modfs/`
- **macOS:** `~/Library/Application Support/com.example.modfs/`

Inside these directories, you will find `modfs.log` which captures diagnostic background scan faults and active metrics.

## 🚀 Usage

1. **Rebuild the DB:** Upon opening ModFS for the first time, click **"Rebuild DB"** to initialize your system index. The top-level Dart isolate efficiently walks your filesystem and feeds it into the hyper-fast C indexer.
2. **Search:** Merely type into the main search field. Results load *as you type* seamlessly filtering wildcards and path locations matching the original FSearch standards.
3. **Advanced Filters:** Utilize PCRE2 RegEx, explicit folder inclusion/exclusion rules, and native instant Sort properties direct from the UI.

---

### Copyright & Licensing
- Search Engine and Core C Infrastructure: Copyright © Christian Boxdörfer (`christian.boxdoerfer@posteo.de`)
- Flutter Engine Port, macOS Interfacing, App Logic: Copyright © Chuck Talk (`chuck@nordheim.online`)
- Licensed under the original GNU GPL Terms. FSearch is open software and ModFS proudly follows these principles dynamically!

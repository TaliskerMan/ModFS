title: ModFS
subtitle: Installation and User Guide
version: 1.0.4
platforms: macOS 14+ (Apple Silicon)
## About ModFS

ModFS is a fast file search for macOS. It builds an index of the folders you choose, then finds files and folders by name as you type. It's a macOS front end for **FSearch**, the open-source search engine by Christian Boxdörfer: ModFS keeps FSearch's C indexing and search engine and adds a Flutter interface.

**What ModFS does**

- Indexes the folders you choose (your home folder by default) into a local database.
- Shows matching files and folders instantly as you type, with each file's size.
- Opens a result with a click, or its containing folder with a right-click.
- Supports FSearch's search syntax: wildcards, file-type filters, size and date filters, regular expressions and more. Click **?** in the search box for examples.

ModFS runs entirely on your Mac. It has no network features and sends nothing anywhere.

ModFS is free software under the GNU General Public License, version 3 or later (GPLv3+). FSearch itself is licensed GPLv2 or later, which allows this. The whole application, interface and search engine together, is covered by the GPL. Source: github.com/TaliskerMan/ModFS.

## System requirements

| | |
|---|---|
| Mac | Apple Silicon (M1 or later); Intel Macs aren't supported |
| Operating system | macOS 14 Sonoma or later |
| Disk space | The app plus the index database (grows with the number of files indexed) |
| Network | Not needed |

## Installing ModFS

ModFS is distributed as a `.dmg` disk image, directly from the GitHub release page (it isn't in the Mac App Store, whose terms aren't compatible with the GPL). The app is signed with a Developer ID certificate and notarized by Apple, so macOS lets it open. The first time, macOS asks you to confirm that you want to open an app downloaded from the internet; click **Open**.

1. Download the latest `ModFS_<version>_macos-arm64.dmg` and its `.sha512` file.
2. Optionally, check the download in Terminal: `shasum -a 512 -c ModFS_<version>_macos-arm64.dmg.sha512` (it should print `OK`).
3. Open the disk image and drag **ModFS** onto the **Applications** shortcut.
4. Open ModFS from Applications, Launchpad or Spotlight.

### Getting the source code

Every binary is accompanied by its complete source, including the modified FSearch C code, the Dart bridge and the build scripts, at github.com/TaliskerMan/ModFS and as a source archive on the release page. The libraries built into ModFS's search engine (GLib, PCRE2 and ICU) are listed, with their licences, in `ModFS.app/Contents/Resources/ThirdPartyLicenses` and in the release's `security_report.md`. If you received ModFS without source, you can ask for the source for that version by emailing chuck@nordheim.online.

### Uninstalling

Drag ModFS to the Trash. To remove its index, settings and log, delete `~/Library/Application Support/io.github.taliskerman.modfs/` and ModFS's preferences.

## Quick start

1. Open ModFS. It loads the saved index if there is one.
2. The first time, click **Rebuild DB** to index your files. When it finishes, the line under the search box shows how many files and folders were indexed and when.
3. Type in **Search files and folders…**. Results update as you type.
4. **Click** a result to open it with its default app. **Right-click** to open the folder that contains it.

> **Tip:** Indexing a large home folder can take a while. Results appear once indexing finishes, and the line under the search box shows how many files and folders were indexed.

## Searching

Type part of a file or folder name. ModFS matches it anywhere in the name and isn't case-sensitive by default. Folders are listed first, then files, in name order, with each file's size. There is no sort control.

To keep the list fast, ModFS shows up to 200 folders and 500 files per search. When a search finds more, a line above the results says so (for example "Showing 500 of 12,345 files"); type more of the name, or add a filter, to narrow it down.

ModFS uses FSearch's search syntax, so you can be more precise. Click the **?** at the right of the search box to see these examples in the app:

| Search | Finds |
|---|---|
| `report` | Names containing "report" |
| `report 2026` | Names containing both "report" and "2026" |
| `*.pdf` | Names ending in `.pdf` (wildcards `*` and `?`) |
| `ext:pdf;docx` | Files with the extension `.pdf` or `.docx` |
| `invoice ext:pdf` | PDFs with "invoice" in the name |
| `folder:projects` | Folders only, containing "projects" |
| `file:notes` | Files only, containing "notes" |
| `size:>100mb` | Items larger than 100 MB |
| `dm:today` | Items modified today |
| `path:notes` | Match against the full path, not just the name |
| `case:README` | Case-sensitive match |
| `regex:^IMG_[0-9]+\.jpg$` | Names matching a regular expression |
| `photo OR image` | Names containing either word |
| `!tmp` or `NOT tmp` | Exclude names containing "tmp" |

For the full syntax, see FSearch's search-syntax documentation on its GitHub wiki (github.com/cboxdoerfer/fsearch).

> **Note:** The index does not update by itself. Results reflect the index as it was when you last clicked **Rebuild DB** (the status line shows when that was). Files created, moved or deleted since then won't show correctly until you rebuild.

## Settings

Click the gear icon next to the ModFS title to open **Settings**. Changes to the folder lists take effect when you close Settings: ModFS then rebuilds the index once.

### Include Paths

The folders ModFS indexes. The default is your home folder. Type a full path (for example `/Users/you/Documents`) and add it. ModFS only accepts folders that exist; if an included folder is later removed, the next rebuild skips it and tells you.

### Exclude Paths

Folders ModFS skips. Some system and cache locations are always excluded, such as `/dev`, `/tmp`, `/var/tmp` and `~/.cache`; they show a lock and can't be removed. Add your own exclusions, for example a large backup folder, to keep the index smaller.

### Appearance

**Theme Mode** (System, Light or Dark) and **font size** for the results list. Both are remembered.

## Privacy and data

- ModFS works entirely offline; there's no telemetry or account.
- The index contains the names, sizes and dates of the files in your included folders, not their contents.
- macOS may ask for permission the first time ModFS reads protected folders such as Documents, Desktop or Downloads. To index everything in your home folder, you can give ModFS **Full Disk Access** in **System Settings → Privacy & Security**.

### Where things are stored

| Item | Location |
|---|---|
| Index database | `~/Library/Application Support/io.github.taliskerman.modfs/database.fsearch` |
| Log | `~/Library/Application Support/io.github.taliskerman.modfs/modfs.log` |
| Settings (paths, theme, font) | ModFS's macOS preferences |

## Troubleshooting

**Searching finds nothing.** Click **Rebuild DB**. If the count stays at zero, check Include Paths in Settings. A red message under the status line explains any indexing problem.

**Some folders are missing from results.** They may be excluded, or macOS may have blocked access. Grant access when macOS asks, or give ModFS Full Disk Access, then rebuild.

**A file I just created doesn't appear.** The index isn't updated automatically; click **Rebuild DB**.

**Too many results.** Add more of the name, or use a filter such as `ext:` or `folder:`.

**"The saved index couldn't be read."** Click **Rebuild DB** to create a new one.

**Something went wrong.** Check `modfs.log` in the Application Support folder above and include it when reporting a problem.

## Credits, support and license

- FSearch search engine and C core: © Christian Boxdörfer.
- ModFS interface, macOS bridge and packaging: © Chuck Talk, Nordheim Online.

Report problems on GitHub (github.com/TaliskerMan/ModFS) or email **chuck@nordheim.online**.

| | |
|---|---|
| Website | nordheim.online |
| Source code | github.com/TaliskerMan/ModFS |
| License | GNU GPL v3 or later, for the whole application (no warranty) |

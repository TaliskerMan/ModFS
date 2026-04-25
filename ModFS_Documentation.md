# ModFS Documentation

![ModFS Main Screen Placeholder](/placeholder-main.png)

## Overview

**ModFS** is a modern, fast, cross-platform file search utility. Built with a highly responsive modern user interface, ModFS brings instant file search capabilities to both **macOS** and **Linux** environments.

## History and Genesis

ModFS is a modernized fork of the highly acclaimed **Fsearch** database tool, originally authored as a standalone C application modeled for high performance. 

By upgrading the front-end with a modern **Flutter** interface, ModFS achieves smooth, 120hz declarative UI rendering across multiple operating systems. It securely bridges the incredible original C-indexed database over Dart FFI (Foreign Function Interface), ensuring that the index building speeds—capable of parsing millions of files in mere moments—are maintained. 

### Copyright & Licensing

ModFS deeply respects the foundational open-source work of the original application:
- **Core C Infrastructure:** Retains the original **author's copyright** (Christian Boxdörfer).
- **License:** ModFS proudly operates under the **GNU GPL v2** Open-Source License. The sanctity of the original Fsearch open-source code and principles are strictly maintained, ensuring the software remains free and fully open-source.

## Built for macOS and Linux

ModFS provides native deployment packages specifically tailored for:
- **macOS:** Packaged as an optimized `.dmg` avoiding sandbox entitlement collisions via static FFI resolution.
- **Linux:** Distributed as a natively signed `.deb` payload that securely installs the compiled application.

## How to Use ModFS

### 1. Initial Setup
When opening ModFS for the first time, you need to build the initial directory index. 
- Click on the **"Rebuild DB"** button. The application will efficiently walk your specified filesystem locations and feed the data into the hyper-fast C indexer.

![Rebuild DB Placeholder](/placeholder-rebuild.png)

### 2. Searching
- **Instant Results:** Simply start typing in the main search field. ModFS loads and filters results *as you type*.
- **Wildcards:** Supports standard wildcard matching natively.

![Search Results Placeholder](/placeholder-search.png)

### 3. Advanced Features
- **Regex:** Utilize PCRE2 Regular Expressions for complex querying.
- **Filters:** Apply explicit folder inclusion or exclusion rules to precisely limit your search scope.
- **Sorting:** Use native, instant sorting properties directly from the data table UI.

## Hardening & Security Auditability

ModFS is built with modern security principles at its core, enabling use in strict enterprise environments.

- **Auditable Open-Source Code:** The entire codebase is completely open-source under the GNU GPL v2 license, ensuring total transparency and security auditability by researchers and the community.
- **Hardened Executables:** 
  - On macOS, builds conform to Apple's **Hardened Runtime** requirements to prevent code injection and tampering.
  - Binaries are comprehensively signed for secure execution.
- **Secure Data Storage:** The app stores all files safely in isolated user-protected space:
  - **Linux:** `~/.local/share/modfs/`
  - **macOS:** `~/Library/Application Support/com.example.modfs/`
- **Transparent Logging:** The application generates persistent diagnostic logs (such as `modfs.log`), capturing all background background metrics and errors. This allows for simple security compliance reviews and easy support troubleshooting.

![Settings and Audit Placeholder](/placeholder-settings.png)

---

*ModFS - Bringing lightning-fast file search to the modern desktop.*

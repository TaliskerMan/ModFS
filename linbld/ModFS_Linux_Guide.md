# ModFS Linux Guide

Welcome to **ModFS** for Linux! 

ModFS is a modernized fork of the high-performance FSearch tool. By merging the blisteringly fast GTK3 C backend with a pure Flutter/Dart cross-platform rendering engine, ModFS maintains incredible hardware efficiency while delivering dynamic, glassmorphic client-side rendering.

## Security Integrity & Hardening

Every aspect of ModFS's deployment conforms to **ShadowAgent Build Rules**:
- **SBOM Compliance**: Your ModFS bundle was shipped alongside its complete Software Bill of Materials (SBOM) ensuring external audit transparency.
- **Signed Deployments**: To prevent tampering, the core payload (`ModFS_linux_..._amd64.deb`) is mathematically hashed (SHA-512) and detached-signed (`.sig`) using a registered `chuck@nordheim.online` GPG Key.
- **Isolate Threading**: Database scanning traverses through secure, decoupled Dart Isolate threading to prevent lockups and memory violations typical in dynamic FFI bridging. 

---

## 🛠 Installation & Verification 

### 1. Verification (Required)
Before proceeding with the installation, we highly recommend verifying the payload integrity natively on your system.

```bash
# Validate SHA-512 Hash
sha512sum -c SHA512SUMS

# Verify the GPG Signature
gpg --verify ModFS_linux_*.deb.sig ModFS_linux_*.deb
```
> [!CAUTION]
> If the GPG signature is unverified or the SHA512SUM mismatches, abort the installation immediately. 

### 2. Install Package
ModFS is wrapped securely inside a standard Debian package map, safely targeting isolated `opt` structures without polluting your `bin`.

```bash
sudo dpkg -i ModFS_linux_1.0.0-9_amd64.deb
sudo apt install -f # (If standard dependencies are missing)
```

---

## ⚡ Quick Start

### Building the Initial Index
FSearch architectures inherently require a local, high-speed SQLite graph of your system to function optimally. 

1. Launch `ModFS` from your system applications menu.
2. The initial view will prompt a database sync.
3. Click the **Rebuild DB** icon. The application will leverage decoupled Dart Isolate tasks to crawl your files without stalling your interactive Desktop session.

### Where is my Data Saved?
Because ModFS runs natively, it secures user data within your isolated `.local` paths. No root daemon is required.
- **Database Location:** `~/.local/share/modfs/database.fsearch`
- **Application Logs:** `~/.local/share/modfs/modfs.log`

If you encounter unexpected file crashes, always check `modfs.log` first, as handled exceptions from the Dart logger are automatically flushed here!

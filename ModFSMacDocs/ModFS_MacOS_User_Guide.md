# ModFS for macOS: User Guide

Welcome to ModFS! ModFS is a modern, high-performance file search utility powered by a secure Flutter frontend and a blazingly fast native C backend. This guide covers how to install, configure, and safely use ModFS on macOS.

## 1. Installation

ModFS is distributed securely as an Apple Disk Image (`.dmg`).

1. **Mount the DMG**: Double-click `ModFS.dmg`.
2. **Install to Applications**: Drag the `ModFS` application icon into the adjacent `Applications` folder alias within the window.
3. **Launch the App**: Open your `Applications` folder and double-click `ModFS`.
   > [!NOTE]
   > Depending on your Gatekeeper settings, you may see a prompt confirming if you want to open an application downloaded from the internet. Click **Open**.

## 2. macOS Permissions: Full Disk Access (CRITICAL)

Because ModFS is designed to index and search your entire filesystem at lightning speeds, it requires frictionless access to your directories. 

macOS employs strict privacy protections. Without explicit permissions, macOS will aggressively halt the ModFS background indexing process to present a permission dialog for *every single protected folder* it encounters (e.g., your Documents, Downloads, Desktop, and Library folders). This will effectively break the indexing engine.

To prevent this, you **must** grant ModFS Full Disk Access.

> [!IMPORTANT]  
> **How to grant Full Disk Access:**
> 1. Open the macOS **System Settings**.
> 2. Navigate to **Privacy & Security** > **Full Disk Access**.
> 3. Click the explicit **+** (plus) icon at the bottom of the application list (you may need to authenticate with your password or Touch ID).
> 4. Select **ModFS** from your `Applications` folder and click **Open**.
> 5. Ensure the toggle next to ModFS is turned **ON**.
> 6. Restart ModFS if it was already running.

## 3. Usage & Configuration

Once ModFS has the proper permissions, using it is straightforward.

### Initial Indexing
Upon first launch, ModFS will begin indexing your primary disk. You will see an "Indexing Database..." indicator at the top of the interface. This creates the foundational database that makes instant search possible.

### Searching
- **Text Search**: Begin typing in the top search bar. Results will appear instantaneously.
- **Results View**: The interface natively separates folders and files, displaying the exact path and file size layout.
- **Open Files/Folders**: 
  - **Click** on a result to open the generic file directly via its default macOS handler.
  - **Right-Click (Secondary Click)** on a result to instantly open its containing folder in Finder.

### Configuration (`Preferences`)
Click the gear icon in the top right to open **Settings**, where you can manage how ModFS interacts with your data:

- **Preferences**: Adjust the Theme Mode (System/Light/Dark) and tailor your default UI font size.
- **Include Paths**: By default, ModFS searches your user Home directory. Add supplementary paths or drives here to expand the search net.
- **Exclude Paths**: Some paths contain volatile system data that can trigger indexing loops or memory exhaustion. ModFS intelligently defaults to excluding paths like `/proc`, `/sys`, `/dev`, and `.cache`. It is **highly recommended** to leave these defaults intact. Add any of your personal folders here to keep them out of the search index.

> [!TIP]
> Whenever you modify your **Include** or **Exclude** paths, ModFS will immediately purge its existing cache and trigger a full native internal database rebuild automatically! You can also force this process manually by clicking `Rebuild DB` on the main screen.

## 4. Hardening and Security Review

ModFS respects system boundaries and is engineered for secure deployments under rigorous ShadowAgent rules and modern Apple Developer paradigms.

### System Sandboxing & Entitlements
To accomplish full disk searches, ModFS operates without Apple's standard restrictive App Sandbox environment (`com.apple.security.app-sandbox` set to `false`). However, it inherently deploys alongside **Apple's Hardened Runtime**.

### Secure Library Linkage
The underlying C indexing framework is shipped dynamically within the app bundle as `libmodfs_core.dylib`. 
- **Code Signing**: The entire application and the native backend library are explicitly Deep-Signed (`codesign --deep`) using a valid `Developer ID Application` certificate.
- **Dependency Management**: Apple's Hardened Runtime naturally blocks unsigned libraries or mismatching Team IDs. Because ModFS relies on system dependencies (like `glib`), the app structure maintains a surgical `com.apple.security.cs.disable-library-validation` exemption. This tightly guarantees that the host macOS architecture can safely dynamically link local Homebrew or Darwin libraries for the backend, without jeopardizing internal application memory state or triggering kernel (`amfid`) process terminations (SIGKILL).

### Telemetry and Privacy
ModFS operates **100% offline** and completely self-contained. 
- Log profiles are cleanly captured locally to `~/Library/Application Support/com.example.modfs/modfs.log` strictly for user diagnostic audits. 
- Search profiles and indices are never serialized out to network streams.

Enjoy the uncompromising velocity of ModFS!

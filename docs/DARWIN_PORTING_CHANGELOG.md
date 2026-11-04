# Darwin Porting Reference, Source Patches & Packaging Changelog

This document serves as the canonical engineering reference for all source modifications, Git fork branches, packaging fixes, cross-compilation workarounds, and cryptographic hashes across `qt6_darwin` (`Qt 6.12.0`) and downstream KDE Frameworks (`kf6_darwin` / `Gwenview`).

---

## 1. Upstream Fork & Branch Tracking (`revanthnemtoor/qtbase`)

Rather than relying solely on loose patch files over static tarballs, `qt6-base` tracks a dedicated GitHub fork of `qt/qtbase`:

| Property | Value |
|---|---|
| **Upstream Repository** | `https://github.com/qt/qtbase.git` (`https://code.qt.io/qt/qtbase.git`) |
| **Upstream Base Tag** | `v6.12.0` (`de915cc564cf59675ef2844ff8c9e7ee87bb13bc`) |
| **Darwin Fork Repository** | [`https://github.com/revanthnemtoor/qtbase.git`](https://github.com/revanthnemtoor/qtbase) |
| **Active Release Branch** | `darwin-6.12.0` |
| **Latest Fork Commit** | `cac4c78e640dc6ca5caf5da14394aac3a6e771e0` |
| **Fork Release Tags** | `v6.12.0-darwin.1` (`475bd7a0`), `v6.12.0-darwin.2` (`cac4c78e`) |
| **Local Git-Tracked Source** | `build/qtbase-everywhere-src-6.12.0` (symlinked at `sources/qt6/qtbase-everywhere-src-6.12.0`) |
| **PKGBUILD Reference** | [`packages/qt6/qt6-base/PKGBUILD`](../packages/qt6/qt6-base/PKGBUILD) (`pkgver=6.12.0`, `pkgrel=2`) |
| **Auto-Rebase Hook** | [`scripts/auto-update-and-package.sh`](../scripts/auto-update-and-package.sh) (`sync_module_fork()`) |

### How Automatic Rebasing Works on New Qt Releases
When [`scripts/auto-update-and-package.sh`](../scripts/auto-update-and-package.sh) detects a newer stable upstream release (e.g., `6.12.1`), `sync_module_fork` automatically:
1. Fetches `refs/tags/v6.12.1` from `upstream` (`https://github.com/qt/qtbase.git`).
2. Checks out `darwin-6.12.1` from `darwin-6.12.0` and rebases the Darwin commits onto `v6.12.1`.
3. Pushes `darwin-6.12.1` to `origin` (`https://github.com/revanthnemtoor/qtbase.git`) and records the new commit hash in `out/latest-hashes.txt` and `out/latest-hashes.json`.

---

## 2. Source-Level Fixes in `qt6-base` (`revanthnemtoor/qtbase`)

### Fix 1: `SIGFPE` (`EXC_ARITHMETIC`) Integer Divide-by-Zero & Null Icon Handling in `QAppleIconEngine`
- **Commit / Tag:** `475bd7a0974a4ef3e962314c7db264e0bf160327` (`v6.12.0-darwin.1`)
- **Patch File:** [`patches/0001-qappleiconengine-fix-sigfpe-and-null-icon-handling.patch`](../patches/0001-qappleiconengine-fix-sigfpe-and-null-icon-handling.patch)
- **Modified Source Files:**
  1. [`src/gui/platform/darwin/qappleiconengine.mm`](../build/qtbase-everywhere-src-6.12.0/src/gui/platform/darwin/qappleiconengine.mm) (lines 345–365, 410–433)
  2. [`src/gui/platform/darwin/qapplefileiconengine.mm`](../build/qtbase-everywhere-src-6.12.0/src/gui/platform/darwin/qapplefileiconengine.mm) (lines 42–60)
- **Symptom (Recorded in [`bugs/Pasted text(20261104-212534).txt`](../bugs/Pasted%20text(20261104-212534).txt)):**
  Launching `/opt/pacman/Applications/KDE/gwenview.app/Contents/MacOS/gwenview` crashed immediately with `SIGFPE (Floating point exception)` / `EXC_ARITHMETIC (EXC_I386_DIV: divide by zero)` at `QAppleIconEngine::actualSize(QSize const&, QIcon::Mode, QIcon::State) + 100` (`libQt6Gui.6.12.0.dylib`).
- **Root Cause:**
  1. In `QAppleIconEngine::actualSize`, line 354 computed:
     ```cpp
     const double outputAspectRatio = size.width() / size.height();
     ```
     Because `QSize::width()` and `QSize::height()` return `int`, `size.width() / size.height()` performed **32-bit signed integer division (`idiv`)** before converting to `double`. When `size` was `QSize(0, 0)` (`size.height() == 0`), x86_64 hardware raised `SIGFPE`.
  2. When a requested XDG icon name had no matching macOS SF Symbol (`m_image == nullptr`, `isNull() == true`), `QAppleIconEngine::availableSizes()` still returned `{16x16, 32x32, 64x64, 128x128, 256x256}`, tricking `KIconLoader` and `KPixmapSequenceOverlayPainter` into treating null icons as valid and requesting zero-sized or unpaintable pixmaps (`QPainter::begin: Paint device returned engine == 0`).
- **Fix Applied:**
  - Guarded `availableSizes()`, `actualSize()`, and `scaledPixmap()` against `isNull()`, `size.isEmpty()`, `scale <= 0`, and `m_image.size.height <= 0`.
  - Cast dimensions to `double(...)` prior to division and used `qRound(...)` when computing aspect-adjusted dimensions.

---

### Fix 2: Automatic `/opt/pacman/share` Discovery (`QStandardPaths`), Breeze Theme Search Paths (`QCocoaTheme`), and Menu Teardown (`QCocoaMenu`)
- **Commit / Tag:** `cac4c78e640dc6ca5caf5da14394aac3a6e771e0` (`v6.12.0-darwin.2`)
- **Patch File:** [`patches/0002-darwin-pacman-standardpaths-and-cocoa-theme-menus.patch`](../patches/0002-darwin-pacman-standardpaths-and-cocoa-theme-menus.patch)
- **Modified Source Files:**
  1. [`src/corelib/io/qstandardpaths_mac.mm`](../build/qtbase-everywhere-src-6.12.0/src/corelib/io/qstandardpaths_mac.mm) (lines 186–227)
  2. [`src/plugins/platforms/cocoa/qcocoatheme.mm`](../build/qtbase-everywhere-src-6.12.0/src/plugins/platforms/cocoa/qcocoatheme.mm) (lines 449–465)
  3. [`src/plugins/platforms/cocoa/qcocoamenu.mm`](../build/qtbase-everywhere-src-6.12.0/src/plugins/platforms/cocoa/qcocoamenu.mm) (lines 194–203)
- **Symptoms:**
  - `kf.iconthemes: Icon theme "breeze" not found.`
  - `kf.kwidgetsaddons: Invalid pixmap specified.` / `kf.kwidgetsaddons: No frame loaded`
  - `qt.qpa.menus: QPlatformMenuItem(...) does not belong to <QCocoaNSMenu: ...>`
- **Root Cause:**
  1. Upstream `qstandardpaths_mac.mm` only returned macOS `~/Library/Application Support` and `/Library/Application Support` for `GenericDataLocation` and `AppDataLocation`, ignoring `/opt/pacman/share` and `XDG_DATA_DIRS`.
  2. Upstream `QCocoaTheme::themeHint` did not implement `IconThemeSearchPaths`, `SystemIconThemeName`, or `SystemIconFallbackThemeName`, leaving `QIcon::themeSearchPaths()` without `/opt/pacman/share/icons`.
  3. Upstream `QCocoaMenu::removeMenuItem` logged a warning if a menu item had already been detached from its parent `NSMenu` during macOS application menu merging/teardown.
- **Fix Applied:**
  - Added `/opt/pacman/share` (and `XDG_DATA_DIRS`) to `GenericDataLocation`, `/opt/pacman/share/<org>/<app>` + `/opt/pacman/share/<app>` to `AppDataLocation` / `AppLocalDataLocation`, and `/opt/pacman/etc/xdg` to `GenericConfigLocation` / `ConfigLocation` in `qstandardpaths_mac.mm`.
  - Implemented `IconThemeSearchPaths` (including `/opt/pacman/share/icons`) and `SystemIconThemeName` / `SystemIconFallbackThemeName` (`"breeze"` when `/opt/pacman/share/icons/breeze/index.theme` is installed, else `"hicolor"`) in `qcocoatheme.mm`.
  - Safely checked `nsItem.menu` before removing an item in `qcocoamenu.mm`.

---

## 3. Packaging & Build Infrastructure Fixes (`qt6_darwin` & `kf6_darwin`)

| Component / Script | Issue Encountered | Resolution |
|---|---|---|
| **`.MTREE` & Tar Ownership** ([`scripts/build-module.sh`](../scripts/build-module.sh), [`scripts/auto-update-and-package.sh`](../scripts/auto-update-and-package.sh)) | Initial packages lacked `.MTREE` or recorded build user UID/GID (`501:20`), and `bsdtar -cf -` without `-n` recursed into directories, inflating archive sizes. | Standardized on `find ... -print0 \| LC_ALL=C /usr/bin/sort -z \| bsdtar -cnf - --null -T - --uid 0 --gid 0 --uname root --gname wheel` for both `.MTREE` and `.pkg.tar.zst`. |
| **Developer Tools in `/opt/pacman/bin`** ([`packages/qt6/qt6-base/PKGBUILD`](../packages/qt6/qt6-base/PKGBUILD), [`scripts/build-module.sh`](../scripts/build-module.sh)) | Qt 6 installs internal tools (`moc`, `rcc`, `uic`, `qhelpgenerator`, `qtattributionsscanner`, `qmlcachegen`, `qmltyperegistrar`, `shadergen`, `cooker`) into `/opt/pacman/libexec/`. | Added relative symlinks (`../libexec/<tool>`) in `/opt/pacman/bin/` across all modules. |
| **Cross-Compiling `qt6-tools` & `qt6-quick3dphysics` for `arm64`** ([`scripts/build-module.sh`](../scripts/build-module.sh)) | When cross-compiling for `arm64`, Qt excludes tool executables (`qhelpgenerator`, `lrelease`, `cooker`) from the default `all` target, causing `cmake --install` to fail. | Added `-DQT_FORCE_BUILD_TOOLS=ON -DQT_BUILD_TOOLS_WHEN_CROSSCOMPILING=ON` and explicitly invoked `cmake --build --target ...` before `cmake --install`. |
| **`breeze-icons` (`6.31.0-1`) Multi-Arch Packaging** (`kf6_darwin/packages/kde/breeze-icons/PKGBUILD`, `kf6_darwin/scripts/build-module.sh`) | `WITH_ICON_GENERATION=ON` required Python `lxml` for optional 24px generation, and `arm64` cross-build needed host `generate-symbolic-dark` and `qrcAlias`. | Built with `-DWITH_ICON_GENERATION=OFF -DBINARY_ICONS_RESOURCE=OFF -DINSTALL_HOST_TOOLS=ON` on `x86_64` and `-DKF6_HOST_TOOLING=/opt/pacman/bin` on `arm64`. |

---

## 4. Cryptographic Hash Reference (`qt6-base` `6.12.0-2` & Patched Binaries)

All module hashes are automatically maintained in [`out/latest-hashes.txt`](../out/latest-hashes.txt), [`out/latest-hashes.json`](../out/latest-hashes.json), and [`packages/qt6/latest-hashes.txt`](../packages/qt6/latest-hashes.txt).

### `qt6-base` `6.12.0-2` Package Archives
- **Git Commit (`revanthnemtoor/qtbase` `darwin-6.12.0`):** `cac4c78e640dc6ca5caf5da14394aac3a6e771e0`
- **`qt6-base-6.12.0-2-darwin_x86_64.pkg.tar.zst`:**
  - `SHA-256`: `ad380349506bbfe96e7b129f87abd226082232baea3fd29c3ffd8bcf21ecbf46`
  - `SHA-512`: `4bcb488d2dac0dc7572a977922ced609ee55aa96ec84b3b818c30d45ed4f1279e4a3780f2adaf3d3ac9d5e38ab34c5b6a7d39ca470406b373a66be638d452407`
- **`qt6-base-6.12.0-2-darwin_arm64.pkg.tar.zst`:**
  - `SHA-256`: `5213d065277b968649bedcb14bfec5b43616f10afb7078719d70868abd8b9718`
  - `SHA-512`: `c044dadd9e5c97a28c9d15ee5774d7f14b604e63b90791e53f54311dc9654833589db900e4125ed54b500cd4713d155ab835d36f524cca2778d56a1236e9ca74`

### Patched `qt6-base` Shared Libraries (`6.12.0-2`)
| Binary Path (`/opt/pacman/...`) | Arch | SHA-256 |
|---|---|---|
| `lib/libQt6Gui.6.12.0.dylib` | `x86_64` | `2cc5883afc71a30f315305c086a744d05b0c6cb50946664f695e4d0f26e1b040` |
| `lib/libQt6Gui.6.12.0.dylib` | `arm64` | `e02a39c8fb580640c50bffe7388913a6584f2d28a03e5250480af861e7d5d7dc` |
| `lib/libQt6Core.6.12.0.dylib` | `x86_64` | `4c8614992d308438899e3d791db0372bb012e559ba49acc44f1f86653c6822af` |
| `lib/libQt6Core.6.12.0.dylib` | `arm64` | `a333b68371af62d15bcc8ca3dba822ef7dfb62db05c48b9b3b69fcc466deac67` |
| `plugins/platforms/libqcocoa.dylib` | `x86_64` | `365434ef385f45176388a1508a4b60fc0248ad4c601e039aae26b723c8630346` |
| `plugins/platforms/libqcocoa.dylib` | `arm64` | `20336cd63c516a56a54ad7a36dbbb18cb8eda040af8176a2cadd7b8901bf797d` |


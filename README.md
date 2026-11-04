# Qt 6 for Darwin (`qt6_darwin`)

Native packaging of Qt 6 (`6.12.0`) for macOS (Darwin) using the Arch-style Pacman package management ecosystem (`/opt/pacman`).

## Primary Objective
Port, build, validate, and package Qt 6 natively from source for macOS (`darwin_x86_64` and `darwin_arm64`) with **zero runtime linkage to Homebrew (`/usr/local`) or MacPorts (`/opt/local`)**. All packages link exclusively against macOS system SDK frameworks (`Cocoa`, `Metal`, `AVFoundation`, `CoreAudio`, `CoreBluetooth`, `CoreFoundation`, `CoreGraphics`, `IOKit`, `Security`, etc.) and `/opt/pacman/lib`.

## Packaged Modules (`6.12.0-1` — 16 Modules, 32 Archives)

| Order | Package | Description | Architectures |
| :---: | :--- | :--- | :--- |
| **1** | [`qt6-base`](packages/qt6/qt6-base/PKGBUILD) | Core, Gui, Widgets, Network, Sql, Concurrent, PrintSupport, OpenGL, DBus, Cocoa QPA plugin, `moc`, `rcc`, `uic` | `darwin_x86_64`, `darwin_arm64` |
| **2** | [`qt6-svg`](packages/qt6/qt6-svg/PKGBUILD) | SVG 1.2 Tiny rendering (`Qt6::Svg`, `Qt6::SvgWidgets`, `libqsvg` image & icon plugins) | `darwin_x86_64`, `darwin_arm64` |
| **3** | [`qt6-imageformats`](packages/qt6/qt6-imageformats/PKGBUILD) | Extended image format plugins (`webp`, `tiff`, `icns`, `tga`, `wbmp`, `heic`, `jp2`) | `darwin_x86_64`, `darwin_arm64` |
| **4** | [`qt6-shadertools`](packages/qt6/qt6-shadertools/PKGBUILD) | SPIR-V / Metal (`MSL`) / GLSL shader pipeline (`Qt6::ShaderTools`, `qsb`) | `darwin_x86_64`, `darwin_arm64` |
| **5** | [`qt6-tools`](packages/qt6/qt6-tools/PKGBUILD) | Qt Designer, Linguist (`lupdate`, `lrelease`), Assistant, `Qt6::Help`, `Qt6::UiTools`, `qtdiag`, `qdbus` | `darwin_x86_64`, `darwin_arm64` |
| **6** | [`qt6-languageserver`](packages/qt6/qt6-languageserver/PKGBUILD) | Language Server Protocol (`LSP`) and JSON-RPC implementation for Qt | `darwin_x86_64`, `darwin_arm64` |
| **7** | [`qt6-declarative`](packages/qt6/qt6-declarative/PKGBUILD) | `QtQml`, `QtQuick`, `QtQuickControls2`, `QtQuickLayouts`, `qmlls`, `qmllint`, `qmlcachegen`, `qmltyperegistrar` | `darwin_x86_64`, `darwin_arm64` |
| **8** | [`qt6-quicktimeline`](packages/qt6/qt6-quicktimeline/PKGBUILD) | Keyframe-based timeline construction and blend-tree animations (`QtQuick.Timeline`) | `darwin_x86_64`, `darwin_arm64` |
| **9** | [`qt6-lottie`](packages/qt6/qt6-lottie/PKGBUILD) | Bodymovin JSON 2D vector graphics animation player (`Qt.labs.lottieqt`) | `darwin_x86_64`, `darwin_arm64` |
| **10** | [`qt6-quick3d`](packages/qt6/qt6-quick3d/PKGBUILD) | High-level 3D scene graph and PBR rendering for Qt Quick (`QtQuick3D`) | `darwin_x86_64`, `darwin_arm64` |
| **11** | [`qt6-quick3dphysics`](packages/qt6/qt6-quick3dphysics/PKGBUILD) | PhysX-based physics simulation API for Qt Quick 3D (`QtQuick3D.Physics`) | `darwin_x86_64`, `darwin_arm64` |
| **12** | [`qt6-multimedia`](packages/qt6/qt6-multimedia/PKGBUILD) | Native Darwin `AVFoundation` / `CoreAudio` multimedia & `QtQuick3D.SpatialAudio` (`Qt6::Multimedia`) | `darwin_x86_64`, `darwin_arm64` |
| **13** | [`qt6-networkauth`](packages/qt6/qt6-networkauth/PKGBUILD) | OAuth 1 and OAuth 2 network authentication (`Qt6::NetworkAuth`) | `darwin_x86_64`, `darwin_arm64` |
| **14** | [`qt6-websockets`](packages/qt6/qt6-websockets/PKGBUILD) | RFC 6455 WebSocket client/server library & QML bindings (`Qt6::WebSockets`) | `darwin_x86_64`, `darwin_arm64` |
| **15** | [`qt6-serialport`](packages/qt6/qt6-serialport/PKGBUILD) | Hardware and virtual serial port access via Darwin `IOKit` (`Qt6::SerialPort`) | `darwin_x86_64`, `darwin_arm64` |
| **16** | [`qt6-connectivity`](packages/qt6/qt6-connectivity/PKGBUILD) | Bluetooth LE / classic & PCSC NFC access via Darwin `CoreBluetooth` / `IOBluetooth` (`Qt6::Bluetooth`, `Qt6::Nfc`) | `darwin_x86_64`, `darwin_arm64` |

## Project Structure
```text
qt6_darwin/
├── QT6_DARWIN_MASTER_PROMPT.md  # Master porting guidelines and constraints
├── docs/                        # Architecture, building, dependencies, packaging, and testing docs
├── packages/                    # Arch-style PKGBUILD packaging recipes (16 modules)
│   └── qt6/
├── scripts/
│   ├── inspect-host.sh          # Host & toolchain verification
│   ├── fetch-sources.sh         # Pinned upstream tarball fetcher & SHA-256 verifier (all 16 modules)
│   ├── build-qtbase.sh          # Standalone qt6-base builder
│   ├── build-module.sh          # Multi-arch builder & normalized packager for Qt submodules
│   ├── verify-package.sh        # Mach-O dependency & codesignature auditor
│   └── auto-update-and-package.sh # Hookable daily auto-updater & multi-arch repository builder
├── tests/
│   └── smoketest/               # Native Cocoa + Widgets + OpenGL + Network + Svg + ImageFormats + QML + UiTools suite
└── out/                         # Output directory for .pkg.tar.zst archives and Pacman repo DBs
```

## Quick Start & Daily Orchestrator Hook
- **Check for upstream updates (hookable exit codes / JSON):**
  ```bash
  ./scripts/auto-update-and-package.sh --check --json
  ```
- **Build, package, and update the Pacman repository in `out/`:**
  ```bash
  ./scripts/auto-update-and-package.sh --out-dir ./out
  ```
- **Audit staged binaries for forbidden `/opt/local` or `/usr/local` linkage:**
  ```bash
  ./scripts/verify-package.sh staging/pkg_x86_64
  ```

# Qt 6 for Darwin (`qt6_darwin`)

Native packaging of Qt 6 (`6.12.0`) for macOS (Darwin) using the Arch-style Pacman package management ecosystem (`/opt/pacman`).

## Primary Objective
Port, build, validate, and package Qt 6 natively from source for macOS (`darwin_x86_64` and `darwin_arm64`) with **zero runtime linkage to Homebrew (`/usr/local`) or MacPorts (`/opt/local`)**. All packages link exclusively against macOS system SDK frameworks (`Cocoa`, `Metal`, `CoreFoundation`, `CoreGraphics`, `IOKit`, `Security`, etc.) and `/opt/pacman/lib`.

## Packaged Modules (`6.12.0-1`)

| Package | Description | Architectures |
| :--- | :--- | :--- |
| [`qt6-base`](packages/qt6/qt6-base/PKGBUILD) | Core, Gui, Widgets, Network, Sql, Concurrent, PrintSupport, OpenGL, DBus, Cocoa QPA plugin | `darwin_x86_64`, `darwin_arm64` |
| [`qt6-svg`](packages/qt6/qt6-svg/PKGBUILD) | SVG 1.2 Tiny rendering (`Qt6::Svg`, `Qt6::SvgWidgets`, `libqsvg` image & icon plugins) | `darwin_x86_64`, `darwin_arm64` |
| [`qt6-imageformats`](packages/qt6/qt6-imageformats/PKGBUILD) | Extended image format plugins (`webp`, `tiff`, `icns`, `tga`, `wbmp`, `heic`, `jp2`) | `darwin_x86_64`, `darwin_arm64` |
| [`qt6-shadertools`](packages/qt6/qt6-shadertools/PKGBUILD) | SPIR-V / Metal (`MSL`) / GLSL shader pipeline (`Qt6::ShaderTools`, `qsb`) | `darwin_x86_64`, `darwin_arm64` |
| [`qt6-tools`](packages/qt6/qt6-tools/PKGBUILD) | Qt Designer, Linguist (`lupdate`, `lrelease`), Assistant, `Qt6::Help`, `Qt6::UiTools`, `qtdiag`, `qdbus` | `darwin_x86_64`, `darwin_arm64` |

## Project Structure
```text
qt6_darwin/
├── QT6_DARWIN_MASTER_PROMPT.md  # Master porting guidelines and constraints
├── docs/                        # Architecture, building, dependencies, packaging, and testing docs
├── packages/                    # Arch-style PKGBUILD packaging recipes
│   └── qt6/
│       ├── qt6-base/
│       ├── qt6-svg/
│       ├── qt6-imageformats/
│       ├── qt6-shadertools/
│       └── qt6-tools/
├── scripts/
│   ├── inspect-host.sh          # Host & toolchain verification
│   ├── fetch-sources.sh         # Pinned upstream tarball fetcher & SHA-256 verifier
│   ├── build-qtbase.sh          # Standalone qt6-base builder
│   ├── build-module.sh          # Multi-arch builder & normalized packager for Qt submodules
│   ├── verify-package.sh        # Mach-O dependency & codesignature auditor
│   └── auto-update-and-package.sh # Hookable daily auto-updater & multi-arch repository builder
├── tests/
│   └── smoketest/               # Native Cocoa + Widgets + Svg + ImageFormats + UiTools validation suite
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

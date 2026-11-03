# Qt 6 for Darwin

Native packaging of Qt 6 for macOS (Darwin) using an Arch-style Pacman package management ecosystem (`/opt/pacman`).

## Primary Objective
Port and package Qt 6 natively for macOS without any runtime reliance on third-party package managers like Homebrew or MacPorts. All packages are built clean from source against native Darwin frameworks/SDKs and installed under the `/opt/pacman` prefix.

## Project Structure
```text
qt6_darwin/
├── QT6_DARWIN_MASTER_PROMPT.md  # Master porting guidelines and constraints
├── docs/                        # Architecture, building, dependencies, and testing docs
├── packages/                    # Arch-style PKGBUILD packaging recipes
│   └── qt6/
│       └── qt6-base/
├── patches/                     # Darwin-specific patches
├── scripts/                     # Verification and build helper scripts
└── sources/                     # Source archives cache (gitignored)
```

## Current Status
- **Phase 0 (Host & Toolchain Inspection):** Complete (macOS 15.8.2, Apple Clang 17.0.0, Xcode 26.3, SDK 26.2).
- **Phase 1 (Research & Baseline):** In progress. Verified baseline Qt version: `6.12.0`.
- **Primary Target:** `darwin_x86_64` (Intel). First-class design support for `darwin_arm64` (Apple Silicon).
- **Pacman Integration:** Configured to package into `.pkg.tar.zst` with ad-hoc Mach-O codesigning for `/Users/revanth/Projects/Pacman_Arch_Porting`.

## Quick Start
1. Inspect the host environment:
   ```bash
   ./scripts/inspect-host.sh
   ```
2. Fetch and cryptographically verify the pinned source archive:
   ```bash
   ./scripts/fetch-sources.sh
   ```

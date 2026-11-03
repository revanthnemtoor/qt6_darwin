# Architecture & Design Policy

## 1. Overview
The goal of this project is to port and package Qt 6 natively for macOS (Darwin) within a Pacman-managed rootless ecosystem (`/opt/pacman`).

## 2. Target Architectures
- **`x86_64` (Intel Darwin):**
  - Current verified host architecture (`MacBookPro15,1`).
  - Target triple: `x86_64-apple-darwin24.6.0`.
  - First implementation and validation milestone.
- **`arm64` (Apple Silicon Darwin):**
  - First-class target architecture (`darwin_arm64`).
  - Recipe and metadata designed to support native compilation on Apple Silicon without restructuring.
- **Universal (`x86_64 + arm64`):**
  - Optional delivery format. Only pursued after both native architectures are individually verified and dependency closures are proven.

## 3. Deployment Target Policy
- Target minimum macOS version: macOS 13.0 (Ventura) or 14.0 (Sonoma) as supported by Qt 6.12.
- Current host SDK: macOS 26.2 SDK.
- Host system: macOS 15.8.2.

## 4. Install Layout & Prefix
- **Root Prefix:** `/opt/pacman`
- **Libraries:** `/opt/pacman/lib`
- **Headers:** `/opt/pacman/include/qt6`
- **Binaries / Tools:** `/opt/pacman/bin`
- **Plugins:** `/opt/pacman/lib/qt6/plugins`
- **CMake Packages:** `/opt/pacman/lib/cmake/Qt6*`
- **RPATH Policy:**
  - Mach-O binaries use `@rpath`.
  - `LC_RPATH` includes `@loader_path/../lib` and `/opt/pacman/lib`.
  - Zero linkage to `/opt/local` (MacPorts) or `/usr/local/Cellar` / `/opt/homebrew` (Homebrew).


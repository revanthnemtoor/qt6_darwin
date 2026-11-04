# Dependency Inventory & Topological Build Order

## 1. Zero External Runtime Dependency Rule
- **No MacPorts Linkage:** Binaries must not link against any dylib in `/opt/local/lib`.
- **No Homebrew Linkage:** Binaries must not link against any dylib in `/usr/local/lib` or `/opt/homebrew/lib`.
- **Approved Runtime Providers:**
  1. macOS System Frameworks and SDK libraries (`/System/Library/Frameworks`, `/usr/lib/libSystem.B.dylib`, `libc++.1.dylib`, `libz.1.dylib`).
  2. Native Pacman packages in `/opt/pacman` (built from source without external linkage).

## 2. Host & Foundation Dependencies (`qt6-base`)

| Dependency | Purpose | Source / Provider | Verified In `/opt/pacman` | Runtime Linkage |
|---|---|---|---|---|
| **Apple Clang** | C++17/C++20 Compiler | Xcode / CLT (`/Applications/Xcode.app`) | System Tool | N/A |
| **CMake & Ninja** | Build system | Build tool only | System Tool | N/A |
| **Python 3** | Build scripting / generators | macOS / System | System Tool | N/A |
| **OpenSSL 3** | TLS & Cryptographic backend | `/opt/pacman` (`openssl 3.5.9-1`) | `/opt/pacman/lib/libssl.3.dylib`, `libcrypto.3.dylib` | Verified Clean |
| **PCRE2** | Regular expression engine | `/opt/pacman` (`pcre2 10.49-1`) | `/opt/pacman/lib/libpcre2-16.0.dylib` | Verified Clean |
| **zstd** | Compression engine | `/opt/pacman` (`zstd 1.5.7-2`) | `/opt/pacman/lib/libzstd.1.dylib` | Verified Clean |
| **zlib** | Compression | macOS SDK (`/usr/lib/libz.1.dylib`) | System Library | Verified Clean |
| **macOS Frameworks** | AppKit, CoreFoundation, Foundation, Metal, AVFoundation, CoreAudio, CoreBluetooth, IOKit, Security | Apple macOS SDK | System Frameworks | Verified Clean |

## 3. Upstream Module Dependency Graph (`6.12.0` `dependencies.yaml`)

Derived directly from each upstream tarball's `dependencies.yaml`:

| Build Order | Package | Upstream Submodule | Required Dependencies | Optional Dependencies (Enabled in Build) |
| :--- | :--- | :--- | :--- | :--- |
| **1** | `qt6-base` | `qtbase` | `openssl`, `pcre2`, `zstd` | — |
| **2** | `qt6-svg` | `qtsvg` | `qt6-base` | — |
| **3** | `qt6-imageformats` | `qtimageformats` | `qt6-base` | — |
| **4** | `qt6-shadertools` | `qtshadertools` | `qt6-base` | — |
| **5** | `qt6-tools` | `qttools` | `qt6-base` | `qt6-declarative` |
| **6** | `qt6-languageserver` | `qtlanguageserver` | `qt6-base` | — |
| **7** | `qt6-declarative` | `qtdeclarative` | `qt6-base` | `qt6-shadertools`, `qt6-languageserver`, `qt6-svg`, `qt6-imageformats` |
| **8** | `qt6-quicktimeline` | `qtquicktimeline` | `qt6-base`, `qt6-declarative` | — |
| **9** | `qt6-lottie` | `qtlottie` | `qt6-base`, `qt6-declarative`, `qt6-quicktimeline` | — |
| **10** | `qt6-quick3d` | `qtquick3d` | `qt6-base`, `qt6-declarative`, `qt6-shadertools` | `qt6-quicktimeline` |
| **11** | `qt6-quick3dphysics` | `qtquick3dphysics` | `qt6-base`, `qt6-declarative`, `qt6-quick3d`, `qt6-shadertools` | — |
| **12** | `qt6-multimedia` | `qtmultimedia` | `qt6-base`, `qt6-shadertools` | `qt6-declarative`, `qt6-quick3d` (SpatialAudio) |
| **13** | `qt6-networkauth` | `qtnetworkauth` | `qt6-base` | — |
| **14** | `qt6-websockets` | `qtwebsockets` | `qt6-base` | `qt6-declarative` |
| **15** | `qt6-serialport` | `qtserialport` | `qt6-base` | — |
| **16** | `qt6-connectivity` | `qtconnectivity` | `qt6-base` | `qt6-declarative` |

## 4. Library Install Names & RPATH Audit
- Mach-O dylibs in `/opt/pacman/lib` declare `LC_ID_DYLIB` pointing to `@rpath/<name>.dylib` or `/opt/pacman/lib/<name>.dylib`.
- Executables and QML/QPA plugins embed `LC_RPATH` `@loader_path/../lib` and `/opt/pacman/lib`.

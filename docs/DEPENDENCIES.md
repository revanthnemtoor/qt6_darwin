# Dependency Inventory & Policy

## 1. Zero External Runtime Dependency Rule
- **No MacPorts Linkage:** Binaries must not link against any dylib in `/opt/local/lib`.
- **No Homebrew Linkage:** Binaries must not link against any dylib in `/usr/local/lib` or `/opt/homebrew/lib`.
- **Approved Runtime Providers:**
  1. macOS System Frameworks and SDK libraries (`/System/Library/Frameworks`, `/usr/lib/libSystem.B.dylib`, `libc++.1.dylib`).
  2. Native Pacman packages in `/opt/pacman` (built from source without external linkage).

## 2. Dependencies for `qt6-base`

| Dependency | Purpose | Source / Provider | Status in `/opt/pacman` |
|---|---|---|---|
| **Apple Clang** | C++17/C++20 Compiler | Xcode / CLT (`/Applications/Xcode.app`) | System Tool |
| **CMake & Ninja** | Build system | `/opt/local/bin` (Build tool only) | System Tool |
| **Python 3** | Build scripting / generators | macOS / System | System Tool |
| **OpenSSL 3** | TLS & Cryptographic backend | `/opt/pacman` (`openssl 3.5.9-1`) | Verified Installed |
| **PCRE2** | Regular expression engine | `/opt/pacman` (`pcre2 10.49-1`) | Verified Installed |
| **zlib** | Compression | macOS SDK (`/usr/lib/libz.dylib`) | System Library |
| **macOS Frameworks** | Cocoa, CoreFoundation, AppKit, Metal, IOKit, Security, etc. | Apple macOS SDK | System Frameworks |
| **SQLite 3** | SQL driver (sqlite) | In-tree bundled or System | To evaluate in Phase 1 |
| **double-conversion** | Float string conversion | In-tree bundled | Upstream Bundled |


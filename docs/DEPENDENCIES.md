# Dependency Inventory & Policy

## 1. Zero External Runtime Dependency Rule
- **No MacPorts Linkage:** Binaries must not link against any dylib in `/opt/local/lib`.
- **No Homebrew Linkage:** Binaries must not link against any dylib in `/usr/local/lib` or `/opt/homebrew/lib`.
- **Approved Runtime Providers:**
  1. macOS System Frameworks and SDK libraries (`/System/Library/Frameworks`, `/usr/lib/libSystem.B.dylib`, `libc++.1.dylib`, `libz.1.dylib`).
  2. Native Pacman packages in `/opt/pacman` (built from source without external linkage).

## 2. Dependencies for `qt6-base`

| Dependency | Purpose | Source / Provider | Verified In `/opt/pacman` | Runtime Linkage |
|---|---|---|---|---|
| **Apple Clang** | C++17/C++20 Compiler | Xcode / CLT (`/Applications/Xcode.app`) | System Tool | N/A |
| **CMake & Ninja** | Build system | `/opt/local/bin` (Build tool only) | System Tool | N/A |
| **Python 3** | Build scripting / generators | macOS / System | System Tool | N/A |
| **OpenSSL 3** | TLS & Cryptographic backend | `/opt/pacman` (`openssl 3.5.9-1`) | `/opt/pacman/lib/libssl.3.dylib`, `libcrypto.3.dylib` | Verified Clean |
| **PCRE2** | Regular expression engine | `/opt/pacman` (`pcre2 10.49-1`) | `/opt/pacman/lib/libpcre2-16.0.dylib` | Verified Clean |
| **zstd** | Compression engine | `/opt/pacman` (`zstd 1.5.7-2`) | `/opt/pacman/lib/libzstd.1.dylib` | Verified Clean |
| **zlib** | Compression | macOS SDK (`/usr/lib/libz.1.dylib`) | System Library | Verified Clean |
| **macOS Frameworks** | AppKit, CoreFoundation, Foundation, IOKit, Security, etc. | Apple macOS SDK | System Frameworks | Verified Clean |
| **SQLite 3** | SQL driver (sqlite) | In-tree Qt bundled | Upstream Bundled | Verified Clean |
| **double-conversion** | Float string conversion | In-tree Qt bundled | Upstream Bundled | Verified Clean |

## 3. Library Install Names & RPATH Audit
- Mach-O dylibs in `/opt/pacman/lib` must declare `LC_ID_DYLIB` pointing to `/opt/pacman/lib/<name>.dylib` or `@rpath/<name>.dylib`.
- Audit verified for `libpcre2-16.dylib`, `libssl.dylib`, `libcrypto.dylib`, and `libzstd.dylib`.
- `libQt6Core.6.12.0.dylib` install name is set to `@rpath/libQt6Core.6.dylib`.

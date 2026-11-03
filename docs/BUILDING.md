# Building Qt 6 for Darwin

## 1. Prerequisites
- Xcode Command Line Tools installed and active (`xcode-select -p`).
- CMake (>= 3.20) and Ninja installed.
- Python 3.
- Native `/opt/pacman` environment populated with `openssl` and `pcre2`.

## 2. Source Archive
- Official upstream release: `qtbase-everywhere-src-6.12.0.tar.xz`
- Download & verification script: `scripts/fetch-sources.sh`

## 3. Build Workflow
Builds are executed via standard out-of-source directories or `makepkg` recipes:
```bash
./scripts/fetch-sources.sh
# makepkg packaging workflow:
cd packages/qt6/qt6-base
/opt/pacman/bin/makepkg -f
```


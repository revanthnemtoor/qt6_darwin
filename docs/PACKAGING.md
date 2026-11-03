# Packaging Policy & Workflow

## 1. Package Format
- Pacman package format: `.pkg.tar.zst`
- Target Architecture identifier: `darwin_x86_64` (and `darwin_arm64` on Apple Silicon).

## 2. Integration with Pacman_Arch_Porting
Packages are built using `/opt/pacman/bin/makepkg` and integrated into the project's repository database:
- Repo root: `/Users/revanth/Projects/Pacman_Arch_Porting`
- Database: `core.db.tar.gz` via `repo-add`

## 3. Codesigning
All Mach-O binaries (executables, `.dylib` shared libraries, and `.bundle` plugins) must receive ad-hoc codesigning:
```bash
codesign --sign - --force <binary>
```
This is required on Darwin to avoid Gatekeeper / Dyld execution aborts.


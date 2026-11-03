# Testing & Validation Strategy

## 1. Acceptance Criteria
1. **Binary Audit:**
   - Architecture slices match host (`x86_64`).
   - `otool -L` confirms no linkage to `/opt/local` (MacPorts) or Homebrew paths.
   - Install names and `@rpath` properly set.
2. **Runtime Smoketests:**
   - `QCoreApplication` smoke test (event loop, string handling).
   - `QGuiApplication` / Cocoa platform plugin test.
   - `QApplication` (QtWidgets) window creation test.
3. **Pacman Integration:**
   - Package installs cleanly into `/opt/pacman` with `/opt/pacman/bin/pacman -U <pkg>`.
   - Clean removal and reinstall test.


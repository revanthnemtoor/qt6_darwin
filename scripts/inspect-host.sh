#!/usr/bin/env bash
set -euo pipefail

echo "=== System Information ==="
sw_vers
uname -m
uname -a

echo -e "\n=== Developer Tools ==="
echo "xcode-select: $(xcode-select -p 2>/dev/null || echo 'not found')"
echo "xcodebuild: $(xcodebuild -version 2>/dev/null | tr '\n' ' ' || echo 'not found')"
echo "SDK Path: $(xcrun --sdk macosx --show-sdk-path 2>/dev/null || echo 'not found')"
echo "SDK Version: $(xcrun --sdk macosx --show-sdk-version 2>/dev/null || echo 'not found')"
clang --version | head -n 1
cmake --version | head -n 1
ninja --version | head -n 1
python3 --version
git --version

echo -e "\n=== Resources ==="
df -h .
sysctl hw.memsize hw.ncpu hw.model

echo -e "\n=== Pacman Environment ==="
echo "Pacman bin: $(which /opt/pacman/bin/pacman 2>/dev/null || echo 'missing')"
if [[ -x /opt/pacman/bin/pacman ]]; then
    /opt/pacman/bin/pacman --version | head -n 2
    echo "Pacman Architecture: $(/opt/pacman/bin/pacman-conf Architecture 2>/dev/null || true)"
fi


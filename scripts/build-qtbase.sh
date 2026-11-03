#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SOURCES_DIR="${PROJECT_ROOT}/sources/qt6"
BUILD_DIR="${PROJECT_ROOT}/build/qtbase-build"
STAGING_DIR="${PROJECT_ROOT}/staging/qt6-base"

QT_VERSION="6.12.0"
SOURCE_ARCHIVE="${SOURCES_DIR}/qtbase-everywhere-src-${QT_VERSION}.tar.xz"

if [[ ! -f "${SOURCE_ARCHIVE}" ]]; then
    echo "Source archive not found. Fetching..."
    "${SCRIPT_DIR}/fetch-sources.sh"
fi

echo "=== Preparing Build Directory ==="
mkdir -p "${BUILD_DIR}"
mkdir -p "${STAGING_DIR}"

if [[ ! -d "${BUILD_DIR}/src" ]]; then
    echo "Extracting source archive..."
    tar -xf "${SOURCE_ARCHIVE}" -C "${BUILD_DIR}" --strip-components=1
fi

echo "=== Configuring Qt 6 Base ==="
export PKG_CONFIG_PATH="/opt/pacman/lib/pkgconfig"
export PATH="/opt/pacman/bin:/usr/bin:/bin:/usr/sbin:/sbin"

case "$(uname -m)" in
    x86_64) ARCH="x86_64" ;;
    arm64)  ARCH="arm64" ;;
    *)      ARCH="$(uname -m)" ;;
esac

cmake -B "${BUILD_DIR}/ninja_build" -S "${BUILD_DIR}" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/opt/pacman \
    -DCMAKE_OSX_ARCHITECTURES="${ARCH}" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0 \
    -DCMAKE_PREFIX_PATH=/opt/pacman \
    -DCMAKE_IGNORE_PREFIX_PATH="/opt/local;/usr/local" \
    -DINSTALL_BINDIR=bin \
    -DINSTALL_LIBDIR=lib \
    -DINSTALL_INCLUDEDIR=include/qt6 \
    -DINSTALL_DOCDIR=share/doc/qt6 \
    -DINSTALL_ARCHDATADIR=lib/qt6 \
    -DINSTALL_DATADIR=share/qt6 \
    -DFEATURE_openssl_linked=ON \
    -DOPENSSL_ROOT_DIR=/opt/pacman \
    -DINPUT_pcre=system \
    -DINPUT_doubleconversion=qt \
    -DINPUT_sqlite=qt \
    -DFEATURE_framework=OFF \
    -DFEATURE_relocatable=ON \
    -DBUILD_TESTING=OFF \
    -DBUILD_EXAMPLES=OFF

echo "=== Building Qt 6 Base ==="
cmake --build "${BUILD_DIR}/ninja_build" --parallel

echo "=== Staging Installation ==="
DESTDIR="${STAGING_DIR}" cmake --install "${BUILD_DIR}/ninja_build"

echo "=== Ad-hoc Codesigning Mach-O Binaries ==="
find "${STAGING_DIR}" -type f -exec sh -c '
    file "$1" | grep -q "Mach-O" && codesign --sign - --force "$1" 2>/dev/null || true
' _ {} \;

echo "Build, staging, and codesigning completed successfully!"


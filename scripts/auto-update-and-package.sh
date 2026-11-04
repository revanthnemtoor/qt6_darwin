#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# auto-update-and-package.sh
# Automated update checker and multi-architecture packager for Qt 6 on Darwin.
# Designed for standalone use or integration into a daily master update orchestrator.
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
OUT_DIR="${OUTPUT_DIR:-${PROJECT_ROOT}/out}"
ARCH_TARGET="both" # x86_64, arm64, or both
CHECK_ONLY=false
FORCE=false
JSON_OUTPUT=false

log() {
    if [[ "${JSON_OUTPUT}" == "false" ]]; then
        echo -e "$@"
    fi
}

error_exit() {
    if [[ "${JSON_OUTPUT}" == "true" ]]; then
        printf '{"status": "error", "message": "%s"}\n' "$1"
    else
        echo -e "❌ ERROR: $1" >&2
    fi
    exit 1
}

# --- CLI Options Parsing ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        --check)
            CHECK_ONLY=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --out-dir|--output-dir)
            OUT_DIR="$2"
            shift 2
            ;;
        --arch)
            ARCH_TARGET="$2"
            shift 2
            ;;
        --json)
            JSON_OUTPUT=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --check              Only check if a new upstream Qt 6 release is available."
            echo "  --force              Force build/package even if already on the latest version."
            echo "  --out-dir <DIR>      Destination directory for built .pkg.tar.zst packages (default: ./out)."
            echo "  --arch <ARCH>        Target architecture: x86_64, arm64, or both (default: both)."
            echo "  --json               Emit machine-readable JSON output for master script hooks."
            echo "  -h, --help           Show this help message."
            exit 0
            ;;
        *)
            error_exit "Unknown argument: $1"
            ;;
    esac
done

mkdir -p "${OUT_DIR}"

# --- Upstream Version Discovery ---
log "--> Checking upstream Qt releases at download.qt.io..."
CURRENT_VERSION=$(grep -E '^pkgver=' "${PROJECT_ROOT}/packages/qt6/qt6-base/PKGBUILD" | head -n 1 | cut -d'=' -f2 | tr -d ' "')

# Query official_releases for highest stable Qt 6 minor release (e.g. 6.12)
LATEST_MINOR=$(curl -fsSL https://download.qt.io/official_releases/qt/ | grep -o 'href="6\.[0-9]*/"' | tr -d 'href="/' | sort -V | tail -n 1 || echo "")
if [[ -z "${LATEST_MINOR}" ]]; then
    LATEST_MINOR="6.12"
fi

# Query patch release under the latest minor directory (e.g. 6.12.0)
LATEST_UPSTREAM=$(curl -fsSL "https://download.qt.io/official_releases/qt/${LATEST_MINOR}/" | grep -o "href=\"${LATEST_MINOR}\.[0-9]*/\"" | tr -d 'href="/' | sort -V | tail -n 1 || echo "")
if [[ -z "${LATEST_UPSTREAM}" ]]; then
    LATEST_UPSTREAM="${CURRENT_VERSION}"
fi

log "  Local version:    ${CURRENT_VERSION}"
log "  Upstream version: ${LATEST_UPSTREAM}"

UPDATE_AVAILABLE=false
if [[ "${CURRENT_VERSION}" != "${LATEST_UPSTREAM}" ]]; then
    UPDATE_AVAILABLE=true
fi

if [[ "${CHECK_ONLY}" == "true" ]]; then
    if [[ "${JSON_OUTPUT}" == "true" ]]; then
        printf '{"status": "checked", "current_version": "%s", "latest_version": "%s", "update_available": %s}\n' \
            "${CURRENT_VERSION}" "${LATEST_UPSTREAM}" "${UPDATE_AVAILABLE}"
    else
        if [[ "${UPDATE_AVAILABLE}" == "true" ]]; then
            echo "Update available: ${CURRENT_VERSION} -> ${LATEST_UPSTREAM}"
            exit 10
        else
            echo "Already up-to-date at ${CURRENT_VERSION}."
            exit 0
        fi
    fi
    if [[ "${UPDATE_AVAILABLE}" == "true" ]]; then exit 10; else exit 0; fi
fi

MODULES=("qt6-base" "qt6-svg" "qt6-imageformats" "qt6-shadertools" "qt6-tools")

if [[ "${UPDATE_AVAILABLE}" == "false" && "${FORCE}" == "false" ]]; then
    # Check if all module packages already exist in OUT_DIR for both architectures
    ALL_EXIST=true
    EXISTING_PKGS=()
    for mod in "${MODULES[@]}"; do
        for arch in x86_64 arm64; do
            pkg="${OUT_DIR}/${mod}-${CURRENT_VERSION}-1-darwin_${arch}.pkg.tar.zst"
            if [[ ! -f "${pkg}" ]]; then
                ALL_EXIST=false
            else
                EXISTING_PKGS+=("${pkg}")
            fi
        done
    done
    if [[ "${ALL_EXIST}" == "true" ]]; then
        log "✓ Up-to-date. All ${#EXISTING_PKGS[@]} module packages already exist in: ${OUT_DIR}"
        if [[ "${JSON_OUTPUT}" == "true" ]]; then
            PKG_LIST_JSON=$(printf '"%s",' "${EXISTING_PKGS[@]}" | sed 's/,$//')
            printf '{"status": "up_to_date", "version": "%s", "packages": [%s]}\n' \
                "${CURRENT_VERSION}" "${PKG_LIST_JSON}"
        fi
        exit 0
    fi
fi

TARGET_VERSION="${LATEST_UPSTREAM}"

# --- Source Acquisition & Checksum Retrieval ---
SOURCE_DIR="${PROJECT_ROOT}/sources/qt6"
mkdir -p "${SOURCE_DIR}"
ARCHIVE_NAME="qtbase-everywhere-src-${TARGET_VERSION}.tar.xz"
SOURCE_ARCHIVE="${SOURCE_DIR}/${ARCHIVE_NAME}"
ARCHIVE_URL="https://download.qt.io/official_releases/qt/${TARGET_VERSION%.*}/${TARGET_VERSION}/submodules/${ARCHIVE_NAME}"

if [[ ! -f "${SOURCE_ARCHIVE}" ]]; then
    log "--> Downloading source archive: ${ARCHIVE_URL}..."
    curl -fSL -o "${SOURCE_ARCHIVE}" "${ARCHIVE_URL}"
fi

# Retrieve upstream SHA-256 from mirrorlist
log "--> Verifying SHA-256 for ${ARCHIVE_NAME}..."
EXPECTED_SHA=$(curl -fsSL "${ARCHIVE_URL}.mirrorlist" | grep -A 2 -i "SHA-256 Hash" | grep -o '[0-9a-f]\{64\}' | head -n 1 || echo "")
ACTUAL_SHA=$(shasum -a 256 "${SOURCE_ARCHIVE}" | awk '{print $1}')

if [[ -n "${EXPECTED_SHA}" && "${EXPECTED_SHA}" != "${ACTUAL_SHA}" ]]; then
    error_exit "SHA-256 mismatch! Found: ${ACTUAL_SHA}, Expected: ${EXPECTED_SHA}"
fi
log "  ✓ Source verified (${ACTUAL_SHA})"

# Update PKGBUILD version if needed
sed -i '' "s/^pkgver=.*/pkgver=${TARGET_VERSION}/" "${PROJECT_ROOT}/packages/qt6/qt6-base/PKGBUILD"
sed -i '' "s/^sha256sums=.*/sha256sums=('${ACTUAL_SHA}')/" "${PROJECT_ROOT}/packages/qt6/qt6-base/PKGBUILD"

# --- Packaging Function ---
package_arch() {
    local ARCH="$1"
    local STAGE_DIR="${PROJECT_ROOT}/staging/pkg_${ARCH}"
    local BUILD_DIR="${PROJECT_ROOT}/build/build_${ARCH}"
    local PKG_NAME="qt6-base-${TARGET_VERSION}-1-darwin_${ARCH}.pkg.tar.zst"
    local FINAL_PKG="${OUT_DIR}/${PKG_NAME}"

    log "\n=========================================="
    log "--> Building and Packaging for: darwin_${ARCH}"
    log "=========================================="

    # If existing trial_build matches, we can use it to avoid redundant recompilation
    if [[ "${ARCH}" == "x86_64" && -f "${PROJECT_ROOT}/build/trial_build/build.ninja" ]]; then
        BUILD_DIR="${PROJECT_ROOT}/build/trial_build"
    fi
    mkdir -p "${BUILD_DIR}"
    mkdir -p "${STAGE_DIR}"

    local CMAKE_ARCH_FLAGS=()
    if [[ "${ARCH}" == "x86_64" ]]; then
        CMAKE_ARCH_FLAGS=(
            -DCMAKE_OSX_ARCHITECTURES="x86_64"
            -DCMAKE_PREFIX_PATH="/opt/pacman"
            -DCMAKE_IGNORE_PREFIX_PATH="/opt/local;/usr/local"
            -DFEATURE_openssl_linked=ON
            -DOPENSSL_ROOT_DIR="/opt/pacman"
            -DINPUT_pcre=system
            -DINPUT_doubleconversion=qt
            -DINPUT_sqlite=qt
        )
    elif [[ "${ARCH}" == "arm64" ]]; then
        CMAKE_ARCH_FLAGS=(
            -DCMAKE_OSX_ARCHITECTURES="arm64"
            -DQT_HOST_PATH="/opt/pacman"
            -DCMAKE_PREFIX_PATH="${PROJECT_ROOT}/staging/sysroot_arm64/opt/pacman"
            -DCMAKE_IGNORE_PREFIX_PATH="/opt/local;/usr/local;/opt/pacman"
            -DOPENSSL_ROOT_DIR="${PROJECT_ROOT}/staging/sysroot_arm64/opt/pacman"
            -DFEATURE_zstd=OFF
            -DINPUT_pcre=qt
            -DINPUT_doubleconversion=qt
            -DINPUT_sqlite=qt
        )
    fi

    local SRC_ROOT="${SOURCE_DIR}/qtbase-everywhere-src-${TARGET_VERSION}"
    if [[ -d "${PROJECT_ROOT}/build/qtbase-everywhere-src-${TARGET_VERSION}" ]]; then
        SRC_ROOT="${PROJECT_ROOT}/build/qtbase-everywhere-src-${TARGET_VERSION}"
    fi

    # Configure
    log "  Configuring CMake..."
    cmake -B "${BUILD_DIR}" -S "${SRC_ROOT}" -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/opt/pacman \
        -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0 \
        -DFEATURE_framework=OFF \
        -DFEATURE_relocatable=ON \
        -DBUILD_TESTING=OFF \
        -DBUILD_EXAMPLES=OFF \
        "${CMAKE_ARCH_FLAGS[@]}"

    # Build
    log "  Building Qt modules (parallel)..."
    cmake --build "${BUILD_DIR}" --parallel

    # Stage Install
    log "  Installing into staging root..."
    rm -rf "${STAGE_DIR}"
    mkdir -p "${STAGE_DIR}"
    DESTDIR="${STAGE_DIR}" cmake --install "${BUILD_DIR}"

    # --- Clean macOS Finder Junk ---
    # Note: Do NOT delete plugins/permissions/objects-Release/*.cpp.o as they are
    # CMake IMPORTED_OBJECTS_RELEASE targets required by Qt6CoreConfig.cmake on Darwin.
    log "  Purging macOS metadata (.DS_Store)..."
    find "${STAGE_DIR}" -name ".DS_Store" -delete

    # Ad-hoc sign all Mach-O executables, dylibs, and bundles (skip .o object files)
    log "  Applying ad-hoc codesigning..."
    find "${STAGE_DIR}" -type f -exec sh -c '
        file "$1" | grep -qE "Mach-O.*(executable|dynamically linked shared library|bundle)" && codesign --sign - --force "$1" 2>/dev/null || true
    ' _ {} \;

    # Audit for forbidden linkage
    log "  Auditing binary dependencies..."
    "${SCRIPT_DIR}/verify-package.sh" "${STAGE_DIR}"

    # Calculate installed size in bytes
    local INSTALLED_SIZE
    INSTALLED_SIZE=$(du -sk "${STAGE_DIR}/opt/pacman" | awk '{print $1 * 1024}')
    local EPOCH_TIME
    EPOCH_TIME=$(date +%s)

    # Generate .PKGINFO
    cat <<EOF > "${STAGE_DIR}/.PKGINFO"
# Generated for Pacman on Darwin
pkgname = qt6-base
pkgbase = qt6-base
xdata = pkgtype=pkg
pkgver = ${TARGET_VERSION}-1
pkgdesc = A cross-platform application and UI framework (core libraries for Darwin)
url = https://www.qt.io
builddate = ${EPOCH_TIME}
packager = Revanth Reddy Nemtoor <revanthreddyn123@gmail.com>
size = ${INSTALLED_SIZE}
arch = darwin_${ARCH}
license = LGPL-3.0-only
license = GPL-2.0-only
license = GPL-3.0-only
depend = openssl
depend = pcre2
depend = zstd
EOF

    # Generate .BUILDINFO
    cat <<EOF > "${STAGE_DIR}/.BUILDINFO"
format = 2
pkgname = qt6-base
pkgbase = qt6-base
pkgver = ${TARGET_VERSION}-1
pkgarch = darwin_${ARCH}
packager = Revanth Reddy Nemtoor <revanthreddyn123@gmail.com>
builddate = ${EPOCH_TIME}
builddir = ${PROJECT_ROOT}/build
startdir = ${PROJECT_ROOT}
buildtool = makepkg
buildtoolver = 7.1.0
buildenv = !distcc
buildenv = color
buildenv = !ccache
buildenv = check
buildenv = !sccache
buildenv = !sign
options = !strip
options = docs
options = staticlibs
options = emptydirs
options = purge
options = !debug
options = !lto
options = !autodeps
EOF

    # Generate .MTREE (shell-agnostic via find + sort -z, normalized to root:wheel 0:0)
    log "  Generating .MTREE file..."
    (
        cd "${STAGE_DIR}"
        find .PKGINFO .BUILDINFO opt -print0 | LC_ALL=C /usr/bin/sort -z | \
            LANG=C bsdtar --uid 0 --gid 0 --uname root --gname wheel -cnf - --format=mtree \
                --options='!all,use-set,type,uid,gid,mode,time,size,sha256,link' \
                --null --files-from - | gzip -c -f -n > .MTREE
    )

    # Compress into .pkg.tar.zst using bsdtar and zstd -19
    log "  Compressing package into ${FINAL_PKG}..."
    (
        cd "${STAGE_DIR}"
        (
            printf '%s\0' .PKGINFO .BUILDINFO .MTREE
            find opt -print0 | LC_ALL=C /usr/bin/sort -z
        ) | LANG=C bsdtar --no-fflags --no-read-sparse --uid 0 --gid 0 --uname root --gname wheel -cnf - --null --files-from - | \
            /opt/pacman/bin/zstd -c -T0 -19 -z > "${FINAL_PKG}"
    )

    log "✓ Package successfully created: ${FINAL_PKG}"
}

# --- Execution ---
if [[ ! -d "${SOURCE_DIR}/qtbase-everywhere-src-${TARGET_VERSION}" ]]; then
    log "--> Unpacking source archive: ${SOURCE_ARCHIVE}..."
    tar -xf "${SOURCE_ARCHIVE}" -C "${SOURCE_DIR}"
fi

BUILT_PACKAGES=()

if [[ "${ARCH_TARGET}" == "x86_64" || "${ARCH_TARGET}" == "both" ]]; then
    package_arch "x86_64"
    BUILT_PACKAGES+=("${OUT_DIR}/qt6-base-${TARGET_VERSION}-1-darwin_x86_64.pkg.tar.zst")
fi

if [[ "${ARCH_TARGET}" == "arm64" || "${ARCH_TARGET}" == "both" ]]; then
    package_arch "arm64"
    BUILT_PACKAGES+=("${OUT_DIR}/qt6-base-${TARGET_VERSION}-1-darwin_arm64.pkg.tar.zst")
fi

# Build additional Qt 6 modules if their tarballs are present
declare -a SUBMODULES=(
    "qtsvg|qt6-svg|Classes for displaying the contents of SVG files (Support for SVG 1.2 Tiny)"
    "qtimageformats|qt6-imageformats|Plugins for additional image formats: TIFF, TGA, WBMP, WebP, ICNS, MNG"
    "qtshadertools|qt6-shadertools|Provides functionality for the shader pipeline that allows Qt Quick to operate on Metal, Vulkan, and OpenGL"
    "qttools|qt6-tools|A cross-platform application and UI framework (Development Tools, QtHelp, Designer, Linguist)"
)

for entry in "${SUBMODULES[@]}"; do
    IFS='|' read -r mod_short pkg_name pkg_desc <<< "${entry}"
    QT_VERSION="${TARGET_VERSION}" "${SCRIPT_DIR}/build-module.sh" "${mod_short}" "${pkg_name}" "${pkg_desc}" qt6-base
    if [[ "${ARCH_TARGET}" == "x86_64" || "${ARCH_TARGET}" == "both" ]]; then
        BUILT_PACKAGES+=("${OUT_DIR}/${pkg_name}-${TARGET_VERSION}-1-darwin_x86_64.pkg.tar.zst")
    fi
    if [[ "${ARCH_TARGET}" == "arm64" || "${ARCH_TARGET}" == "both" ]]; then
        BUILT_PACKAGES+=("${OUT_DIR}/${pkg_name}-${TARGET_VERSION}-1-darwin_arm64.pkg.tar.zst")
    fi
done

# Generate Pacman repository databases in OUT_DIR
if [[ -x "/opt/pacman/bin/repo-add" ]]; then
    log "--> Updating Pacman repository databases in ${OUT_DIR}..."
    if ls "${OUT_DIR}"/*-darwin_x86_64.pkg.tar.zst >/dev/null 2>&1; then
        /opt/pacman/bin/repo-add -q "${OUT_DIR}/qt6-darwin-x86_64.db.tar.gz" "${OUT_DIR}"/*-darwin_x86_64.pkg.tar.zst
    fi
    if ls "${OUT_DIR}"/*-darwin_arm64.pkg.tar.zst >/dev/null 2>&1; then
        /opt/pacman/bin/repo-add -q "${OUT_DIR}/qt6-darwin-arm64.db.tar.gz" "${OUT_DIR}"/*-darwin_arm64.pkg.tar.zst
    fi
fi

log "\n=========================================="
log "✓ ALL REQUESTED ARCHITECTURES PACKAGED CLEANLY"
log "Output directory: ${OUT_DIR}"
for pkg in "${BUILT_PACKAGES[@]}"; do
    log "  - $(basename "${pkg}") ($(ls -lh "${pkg}" | awk '{print $5}'))"
done
log "=========================================="

if [[ "${JSON_OUTPUT}" == "true" ]]; then
    PKG_LIST_JSON=$(printf '"%s",' "${BUILT_PACKAGES[@]}" | sed 's/,$//')
    printf '{"status": "success", "version": "%s", "packages": [%s]}\n' "${TARGET_VERSION}" "${PKG_LIST_JSON}"
fi

#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# auto-update-and-package.sh
# Per-module upstream stable git/release checker, hash recorder (SHA-256/SHA-512/Git),
# and conditional multi-architecture builder/packager for Qt 6 on Darwin.
#
# Default behavior (unless --force is passed):
#   Iterates through every Qt 6 module in topological order:
#   - Queries upstream stable Git tags (code.qt.io) & release metadata (download.qt.io).
#   - Only compiles and packages a module if a new stable update is available
#     (or if its built .pkg.tar.zst archives are missing from out/).
#   - Otherwise records its latest SHA-256, SHA-512, and Git commit hashes into
#     out/latest-hashes.txt & out/latest-hashes.json, marks it 'latest', and
#     moves immediately to the next module.
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
OUT_DIR="${OUTPUT_DIR:-${PROJECT_ROOT}/out}"
ARCH_TARGET="both" # x86_64, arm64, or both
CHECK_ONLY=false
FORCE=false
JSON_OUTPUT=false
ONLY_MODULE=""

log() {
    if [[ "${JSON_OUTPUT}" == "false" ]]; then
        echo -e "$@"
    fi
}

error_exit() {
    if [[ "${JSON_OUTPUT}" == "true" ]]; then
        printf '{"status": "error", "message": "%s"}\n' "$1"
    else
        echo -e "ERROR: $1" >&2
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
        --force|--rebuild)
            FORCE=true
            shift
            ;;
        --module)
            ONLY_MODULE="$2"
            shift 2
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
            echo "  --check              Only check upstream stable versions/hashes without compiling."
            echo "  --force, --rebuild   Force compile and package even if module is already at latest stable."
            echo "  --module <NAME>      Only process a specific module (e.g., qt6-declarative or qtdeclarative)."
            echo "  --out-dir <DIR>      Destination directory for packages and hash manifest (default: ./out)."
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

mkdir -p "${OUT_DIR}" "${PROJECT_ROOT}/sources/qt6"

HASH_MANIFEST_TXT="${OUT_DIR}/latest-hashes.txt"
HASH_MANIFEST_JSON="${OUT_DIR}/latest-hashes.json"

# Topological module table:
# short_name|pkgname|pkgdesc|depends
declare -a ALL_MODULES=(
    "qtbase|qt6-base|A cross-platform application and UI framework (core libraries for Darwin)|openssl pcre2 zstd"
    "qtsvg|qt6-svg|Classes for displaying the contents of SVG files (Support for SVG 1.2 Tiny)|qt6-base"
    "qtimageformats|qt6-imageformats|Plugins for additional image formats: TIFF, TGA, WBMP, WebP, ICNS, MNG|qt6-base"
    "qtshadertools|qt6-shadertools|Provides functionality for the shader pipeline that allows Qt Quick to operate on Metal, Vulkan, and OpenGL|qt6-base"
    "qttools|qt6-tools|A cross-platform application and UI framework (Development Tools, QtHelp, Designer, Linguist)|qt6-base"
    "qtlanguageserver|qt6-languageserver|An implementation of the Language Server Protocol and JSON-RPC for Qt|qt6-base"
    "qtdeclarative|qt6-declarative|Classes for QML and JavaScript languages (QtQml, QtQuick, QtQuickControls2, QtQuickLayouts)|qt6-base qt6-shadertools qt6-languageserver qt6-svg"
    "qtquicktimeline|qt6-quicktimeline|Qt module for keyframe-based timeline construction and animations|qt6-base qt6-declarative"
    "qtlottie|qt6-lottie|A family of player software for a certain json-based file format for describing 2d vector graphics animations|qt6-base qt6-declarative qt6-quicktimeline"
    "qtquick3d|qt6-quick3d|Qt module and API for defining 3D content in Qt Quick|qt6-base qt6-declarative qt6-shadertools qt6-quicktimeline"
    "qtquick3dphysics|qt6-quick3dphysics|High-level physics simulation API for Qt Quick 3D|qt6-base qt6-declarative qt6-quick3d qt6-shadertools"
    "qtmultimedia|qt6-multimedia|Classes for audio, video, radio and camera functionality (native Darwin AVFoundation / CoreAudio backend)|qt6-base qt6-shadertools qt6-declarative qt6-quick3d"
    "qtnetworkauth|qt6-networkauth|Network authentication module (OAuth 1 and OAuth 2 support)|qt6-base"
    "qtwebsockets|qt6-websockets|Provides WebSocket communication compliant with RFC 6455|qt6-base qt6-declarative"
    "qtserialport|qt6-serialport|Provides access to hardware and virtual serial ports (IOKit backend on Darwin)|qt6-base"
    "qtconnectivity|qt6-connectivity|Provides access to Bluetooth hardware (native CoreBluetooth / IOBluetooth backend on Darwin)|qt6-base qt6-declarative"
)

# --- Discover Latest Upstream Stable Release Version ---
log "--> Querying upstream stable Qt 6 release at download.qt.io..."
FALLBACK_VERSION=$(grep -E '^pkgver=' "${PROJECT_ROOT}/packages/qt6/qt6-base/PKGBUILD" | head -n 1 | cut -d'=' -f2 | tr -d ' "')
LATEST_MINOR=$(curl -fsSL --max-time 15 https://download.qt.io/official_releases/qt/ 2>/dev/null | grep -o 'href="6\.[0-9]*/"' | tr -d 'href="/' | sort -V | tail -n 1 || echo "")
if [[ -z "${LATEST_MINOR}" ]]; then
    LATEST_MINOR="${FALLBACK_VERSION%.*}"
fi
LATEST_UPSTREAM=$(curl -fsSL --max-time 15 "https://download.qt.io/official_releases/qt/${LATEST_MINOR}/" 2>/dev/null | grep -o "href=\"${LATEST_MINOR}\.[0-9]*/\"" | tr -d 'href="/' | sort -V | tail -n 1 || echo "")
if [[ -z "${LATEST_UPSTREAM}" ]]; then
    LATEST_UPSTREAM="${FALLBACK_VERSION}"
fi
log "  Latest upstream stable release: ${LATEST_UPSTREAM}"

# Query git commit hash for a module (uses revanthnemtoor/<mod> fork branch darwin-<ver> if forked, else code.qt.io tag v<ver>)
FORK_OWNER="${QT_FORK_OWNER:-revanthnemtoor}"

get_upstream_git_info() {
    local mod_short="$1"
    local target_ver="$2"
    local fork_url="https://github.com/${FORK_OWNER}/${mod_short}.git"
    local fork_ref
    fork_ref=$(git ls-remote --heads "${fork_url}" "refs/heads/darwin-${target_ver}" 2>/dev/null | tail -n 1 || true)
    if [[ -n "${fork_ref}" ]]; then
        echo "${fork_ref}" | awk '{print $1}'
        return 0
    fi
    local git_url="https://code.qt.io/qt/${mod_short}.git"
    local ref_line
    ref_line=$(git ls-remote --tags "${git_url}" "refs/tags/v${target_ver}" "refs/tags/v${target_ver}^{}" 2>/dev/null | tail -n 1 || true)
    if [[ -n "${ref_line}" ]]; then
        echo "${ref_line}" | awk '{print $1}'
    else
        echo "tarball-v${target_ver}"
    fi
}

# Sync a forked module (e.g., revanthnemtoor/qtbase) to a new upstream release tag v<target_ver>
sync_module_fork() {
    local mod_short="$1"
    local prev_ver="$2"
    local target_ver="$3"
    local src_dir="$4"
    local fork_url="https://github.com/${FORK_OWNER}/${mod_short}.git"
    local upstream_url="https://github.com/qt/${mod_short}.git"

    if ! git ls-remote "${fork_url}" HEAD >/dev/null 2>&1; then
        return 0
    fi

    log "  --> Syncing fork ${FORK_OWNER}/${mod_short} onto upstream tag v${target_ver}..."
    if [[ ! -d "${src_dir}/.git" ]]; then
        git clone --branch "darwin-${prev_ver}" "${fork_url}" "${src_dir}" || git clone "${fork_url}" "${src_dir}"
    fi
    (
        cd "${src_dir}"
        git remote get-url origin >/dev/null 2>&1 || git remote add origin "${fork_url}"
        git remote get-url upstream >/dev/null 2>&1 || git remote add upstream "${upstream_url}"
        git fetch --depth=1 upstream tag "v${target_ver}"
        if git show-ref --verify --quiet "refs/heads/darwin-${prev_ver}"; then
            git checkout -B "darwin-${target_ver}" "darwin-${prev_ver}"
            git rebase "v${target_ver}" || true
        else
            git checkout -B "darwin-${target_ver}" "v${target_ver}^{commit}"
        fi
        git push -u origin "darwin-${target_ver}" --force || true
    )
}

# Build & package qt6-base for a given architecture
build_qtbase_arch() {
    local ARCH="$1"
    local TARGET_VERSION="$2"
    local STAGE_DIR="${PROJECT_ROOT}/staging/pkg_${ARCH}"
    local BUILD_DIR="${PROJECT_ROOT}/build/build_${ARCH}"
    local FINAL_PKG="${OUT_DIR}/qt6-base-${TARGET_VERSION}-1-darwin_${ARCH}.pkg.tar.zst"
    local SOURCE_DIR="${PROJECT_ROOT}/sources/qt6"

    if [[ "${ARCH}" == "x86_64" && -f "${PROJECT_ROOT}/build/trial_build/build.ninja" ]]; then
        BUILD_DIR="${PROJECT_ROOT}/build/trial_build"
    fi
    mkdir -p "${BUILD_DIR}" "${STAGE_DIR}"

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
    else
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
    elif [[ ! -d "${SRC_ROOT}" ]]; then
        tar -xf "${SOURCE_DIR}/qtbase-everywhere-src-${TARGET_VERSION}.tar.xz" -C "${SOURCE_DIR}"
    fi

    cmake -B "${BUILD_DIR}" -S "${SRC_ROOT}" -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/opt/pacman \
        -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0 \
        -DFEATURE_framework=OFF \
        -DFEATURE_relocatable=ON \
        -DBUILD_TESTING=OFF \
        -DBUILD_EXAMPLES=OFF \
        "${CMAKE_ARCH_FLAGS[@]}"

    cmake --build "${BUILD_DIR}" --parallel

    rm -rf "${STAGE_DIR}"
    mkdir -p "${STAGE_DIR}"
    DESTDIR="${STAGE_DIR}" cmake --install "${BUILD_DIR}"

    mkdir -p "${STAGE_DIR}/opt/pacman/bin"
    for tool in moc rcc uic qlalr qvkgen tracegen syncqt cmake_automoc_parser; do
        if [[ -f "${STAGE_DIR}/opt/pacman/libexec/${tool}" ]]; then
            ln -sf "../libexec/${tool}" "${STAGE_DIR}/opt/pacman/bin/${tool}"
        fi
    done

    find "${STAGE_DIR}" -name ".DS_Store" -delete 2>/dev/null || true
    find "${STAGE_DIR}" -type f -exec sh -c '
        file "$1" | grep -qE "Mach-O.*(executable|dynamically linked shared library|bundle)" && codesign --sign - --force "$1" 2>/dev/null || true
    ' _ {} \;

    "${SCRIPT_DIR}/verify-package.sh" "${STAGE_DIR}"

    local INSTALLED_SIZE EPOCH_TIME
    INSTALLED_SIZE=$(du -sk "${STAGE_DIR}/opt/pacman" | awk '{print $1 * 1024}')
    EPOCH_TIME=$(date +%s)

    cat <<EOF > "${STAGE_DIR}/.PKGINFO"
# Generated for Pacman on Darwin
pkgname = qt6-base
pkgbase = qt6-base
xdata = pkgtype=pkg
pkgver = ${TARGET_VERSION}-1
pkgdesc = A cross-platform application and UI framework (core libraries for Darwin)
url = https://www.qt.io
builddate = ${EPOCH_TIME}
packager = Revanth <revanth@darwin>
size = ${INSTALLED_SIZE}
arch = darwin_${ARCH}
license = LGPL-3.0-only
license = GPL-2.0-only
license = GPL-3.0-only
depend = openssl
depend = pcre2
depend = zstd
EOF

    cat <<EOF > "${STAGE_DIR}/.BUILDINFO"
format = 2
pkgname = qt6-base
pkgbase = qt6-base
pkgver = ${TARGET_VERSION}-1
pkgarch = darwin_${ARCH}
packager = Revanth <revanth@darwin>
builddate = ${EPOCH_TIME}
builddir = ${PROJECT_ROOT}/build
startdir = ${PROJECT_ROOT}
buildtool = makepkg-darwin
EOF

    (
        cd "${STAGE_DIR}"
        find .PKGINFO .BUILDINFO opt -print0 | LC_ALL=C /usr/bin/sort -z | \
            LANG=C bsdtar --uid 0 --gid 0 --uname root --gname wheel -cnf - --format=mtree \
                --options='!all,use-set,type,uid,gid,mode,time,size,sha256,link' \
                --null --files-from - | gzip -c -f -n > .MTREE
        find .PKGINFO .BUILDINFO .MTREE opt -print0 | LC_ALL=C /usr/bin/sort -z | \
            LANG=C bsdtar --uid 0 --gid 0 --uname root --gname wheel -cnf - --null --files-from - | \
            zstd -T0 -19 -o "${FINAL_PKG}"
    )
}

# Prepare fresh hash manifest headers
NOW_ISO=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
{
    echo "# Qt 6 Darwin Module State & Cryptographic Hash Manifest"
    echo "# Generated: ${NOW_ISO}"
    echo "# Format: pkgname | status | version | git_commit | src_sha256 | src_sha512 | x86_64_sha256 | x86_64_sha512 | arm64_sha256 | arm64_sha512"
    echo "# ----------------------------------------------------------------------------------------------------------------------------------"
} > "${HASH_MANIFEST_TXT}.tmp"

JSON_ENTRIES=()
BUILT_PACKAGES=()
SKIPPED_MODULES=0
COMPILED_MODULES=0
UPDATES_FOUND=0

for entry in "${ALL_MODULES[@]}"; do
    IFS='|' read -r mod_short pkg_name pkg_desc pkg_deps <<< "${entry}"

    if [[ -n "${ONLY_MODULE}" && "${ONLY_MODULE}" != "${pkg_name}" && "${ONLY_MODULE}" != "${mod_short}" ]]; then
        continue
    fi

    pkgbuild_path="${PROJECT_ROOT}/packages/qt6/${pkg_name}/PKGBUILD"
    local_ver=$(grep -E '^pkgver=' "${pkgbuild_path}" | head -n 1 | cut -d'=' -f2 | tr -d ' "' || echo "${LATEST_UPSTREAM}")
    local_sha256=$(grep -E '^sha256sums=' "${pkgbuild_path}" | grep -o '[0-9a-f]\{64\}' | head -n 1 || echo "")

    archive_name="${mod_short}-everywhere-src-${LATEST_UPSTREAM}.tar.xz"
    source_archive="${PROJECT_ROOT}/sources/qt6/${archive_name}"
    archive_url="https://download.qt.io/official_releases/qt/${LATEST_UPSTREAM%.*}/${LATEST_UPSTREAM}/submodules/${archive_name}"

    # Check if local source tarball already matches local_sha256 when version hasn't changed
    upstream_sha256=""
    if [[ "${local_ver}" == "${LATEST_UPSTREAM}" && -f "${source_archive}" && -n "${local_sha256}" ]]; then
        upstream_sha256="${local_sha256}"
    else
        upstream_sha256=$(curl -fsSL --max-time 15 "${archive_url}.mirrorlist" 2>/dev/null | grep -A 2 -i "SHA-256 Hash" | grep -o '[0-9a-f]\{64\}' | head -n 1 || echo "${local_sha256}")
    fi

    git_commit=$(get_upstream_git_info "${mod_short}" "${LATEST_UPSTREAM}")

    pkg_x86="${OUT_DIR}/${pkg_name}-${LATEST_UPSTREAM}-1-darwin_x86_64.pkg.tar.zst"
    pkg_arm="${OUT_DIR}/${pkg_name}-${LATEST_UPSTREAM}-1-darwin_arm64.pkg.tar.zst"

    needs_update=false
    update_reason=""
    if [[ "${local_ver}" != "${LATEST_UPSTREAM}" ]]; then
        needs_update=true
        update_reason="new upstream version (${local_ver} -> ${LATEST_UPSTREAM})"
        UPDATES_FOUND=$((UPDATES_FOUND + 1))
    elif [[ -n "${upstream_sha256}" && "${local_sha256}" != "${upstream_sha256}" ]]; then
        needs_update=true
        update_reason="upstream source SHA-256 changed"
        UPDATES_FOUND=$((UPDATES_FOUND + 1))
    fi

    pkgs_missing=false
    if [[ "${ARCH_TARGET}" == "x86_64" || "${ARCH_TARGET}" == "both" ]]; then
        [[ -f "${pkg_x86}" ]] || pkgs_missing=true
    fi
    if [[ "${ARCH_TARGET}" == "arm64" || "${ARCH_TARGET}" == "both" ]]; then
        [[ -f "${pkg_arm}" ]] || pkgs_missing=true
    fi

    if [[ "${CHECK_ONLY}" == "true" ]]; then
        log "  [${pkg_name}] local=${local_ver} upstream=${LATEST_UPSTREAM} git=${git_commit:0:12} update=${needs_update} missing_pkg=${pkgs_missing}"
        continue
    fi

    # Decide whether to compile or skip & record hashes
    if [[ "${FORCE}" == "true" || "${needs_update}" == "true" || "${pkgs_missing}" == "true" ]]; then
        if [[ "${FORCE}" == "true" ]]; then
            update_reason="forced rebuild (--force)"
        elif [[ "${pkgs_missing}" == "true" && "${needs_update}" == "false" ]]; then
            update_reason="package archive missing in out/"
        fi
        log "==> [${pkg_name}] Compiling & packaging (${update_reason})..."

        if [[ ! -f "${source_archive}" ]]; then
            log "  Downloading ${archive_url}..."
            curl -fSL --retry 3 -o "${source_archive}" "${archive_url}"
        fi

        actual_src_sha256=$(shasum -a 256 "${source_archive}" | awk '{print $1}')
        if [[ -n "${upstream_sha256}" && "${actual_src_sha256}" != "${upstream_sha256}" ]]; then
            error_exit "SHA-256 mismatch for ${archive_name}: expected ${upstream_sha256}, got ${actual_src_sha256}"
        fi

        # Update PKGBUILD if version or checksum changed
        sed -i '' "s/^pkgver=.*/pkgver=${LATEST_UPSTREAM}/" "${pkgbuild_path}"
        sed -i '' "s/^sha256sums=.*/sha256sums=('${actual_src_sha256}')/" "${pkgbuild_path}"

        if [[ "${pkg_name}" == "qt6-base" ]]; then
            sync_module_fork "qtbase" "${local_ver}" "${LATEST_UPSTREAM}" "${PROJECT_ROOT}/build/qtbase-everywhere-src-${LATEST_UPSTREAM}"
            git_commit=$(get_upstream_git_info "${mod_short}" "${LATEST_UPSTREAM}")
            if [[ "${ARCH_TARGET}" == "x86_64" || "${ARCH_TARGET}" == "both" ]]; then
                build_qtbase_arch "x86_64" "${LATEST_UPSTREAM}"
            fi
            if [[ "${ARCH_TARGET}" == "arm64" || "${ARCH_TARGET}" == "both" ]]; then
                build_qtbase_arch "arm64" "${LATEST_UPSTREAM}"
            fi
        else
            # shellcheck disable=SC2086
            FORCE_BUILD=1 QT_VERSION="${LATEST_UPSTREAM}" "${SCRIPT_DIR}/build-module.sh" "${mod_short}" "${pkg_name}" "${pkg_desc}" ${pkg_deps}
        fi
        COMPILED_MODULES=$((COMPILED_MODULES + 1))
        mod_action="compiled"
    else
        log "==> [${pkg_name}] Already at latest stable (${LATEST_UPSTREAM}). Recording hashes & moving to next module."
        SKIPPED_MODULES=$((SKIPPED_MODULES + 1))
        mod_action="latest"
    fi

    # Compute source & package SHA-256 and SHA-512 hashes
    if [[ -f "${source_archive}" ]]; then
        src_sha256=$(shasum -a 256 "${source_archive}" | awk '{print $1}')
        src_sha512=$(shasum -a 512 "${source_archive}" | awk '{print $1}')
    else
        src_sha256="${local_sha256:-none}"
        src_sha512="none"
    fi

    x86_sha256="none"
    x86_sha512="none"
    if [[ -f "${pkg_x86}" ]]; then
        x86_sha256=$(shasum -a 256 "${pkg_x86}" | awk '{print $1}')
        x86_sha512=$(shasum -a 512 "${pkg_x86}" | awk '{print $1}')
        BUILT_PACKAGES+=("${pkg_x86}")
    fi

    arm_sha256="none"
    arm_sha512="none"
    if [[ -f "${pkg_arm}" ]]; then
        arm_sha256=$(shasum -a 256 "${pkg_arm}" | awk '{print $1}')
        arm_sha512=$(shasum -a 512 "${pkg_arm}" | awk '{print $1}')
        BUILT_PACKAGES+=("${pkg_arm}")
    fi

    echo "${pkg_name} | latest | ${LATEST_UPSTREAM}-1 | ${git_commit} | ${src_sha256} | ${src_sha512} | ${x86_sha256} | ${x86_sha512} | ${arm_sha256} | ${arm_sha512}" >> "${HASH_MANIFEST_TXT}.tmp"

    JSON_ENTRIES+=("$(printf '{"package":"%s","module":"%s","status":"latest","action":"%s","version":"%s-1","git_commit":"%s","source_sha256":"%s","source_sha512":"%s","darwin_x86_64":{"file":"%s","sha256":"%s","sha512":"%s"},"darwin_arm64":{"file":"%s","sha256":"%s","sha512":"%s"}}' \
        "${pkg_name}" "${mod_short}" "${mod_action}" "${LATEST_UPSTREAM}" "${git_commit}" "${src_sha256}" "${src_sha512}" \
        "$(basename "${pkg_x86}")" "${x86_sha256}" "${x86_sha512}" \
        "$(basename "${pkg_arm}")" "${arm_sha256}" "${arm_sha512}")")
done

if [[ "${CHECK_ONLY}" == "true" ]]; then
    rm -f "${HASH_MANIFEST_TXT}.tmp"
    if [[ "${JSON_OUTPUT}" == "true" ]]; then
        printf '{"status": "checked", "latest_version": "%s", "updates_found": %d}\n' "${LATEST_UPSTREAM}" "${UPDATES_FOUND}"
    fi
    if [[ ${UPDATES_FOUND} -gt 0 ]]; then exit 10; else exit 0; fi
fi

mv "${HASH_MANIFEST_TXT}.tmp" "${HASH_MANIFEST_TXT}"

# Write JSON manifest
{
    printf '{\n  "generated_at": "%s",\n  "qt_version": "%s",\n  "compiled_count": %d,\n  "skipped_latest_count": %d,\n  "modules": [\n    ' \
        "${NOW_ISO}" "${LATEST_UPSTREAM}" "${COMPILED_MODULES}" "${SKIPPED_MODULES}"
    local_sep=""
    for j in "${JSON_ENTRIES[@]}"; do
        printf '%s%s' "${local_sep}" "${j}"
        local_sep=$',\n    '
    done
    printf '\n  ]\n}\n'
} > "${HASH_MANIFEST_JSON}"

# Also mirror the latest hash manifest into packages/qt6/ for Git tracking
cp -f "${HASH_MANIFEST_TXT}" "${PROJECT_ROOT}/packages/qt6/latest-hashes.txt"
cp -f "${HASH_MANIFEST_JSON}" "${PROJECT_ROOT}/packages/qt6/latest-hashes.json"

# Refresh Pacman repository databases if any module was compiled or if DBs do not exist yet
if [[ -x "/opt/pacman/bin/repo-add" ]]; then
    if [[ ${COMPILED_MODULES} -gt 0 || ! -f "${OUT_DIR}/qt6-darwin-x86_64.db.tar.gz" || ! -f "${OUT_DIR}/qt6-darwin-arm64.db.tar.gz" ]]; then
        log "--> Updating Pacman repository databases in ${OUT_DIR}..."
        if ls "${OUT_DIR}"/*-darwin_x86_64.pkg.tar.zst >/dev/null 2>&1; then
            /opt/pacman/bin/repo-add -q "${OUT_DIR}/qt6-darwin-x86_64.db.tar.gz" "${OUT_DIR}"/*-darwin_x86_64.pkg.tar.zst
        fi
        if ls "${OUT_DIR}"/*-darwin_arm64.pkg.tar.zst >/dev/null 2>&1; then
            /opt/pacman/bin/repo-add -q "${OUT_DIR}/qt6-darwin-arm64.db.tar.gz" "${OUT_DIR}"/*-darwin_arm64.pkg.tar.zst
        fi
    fi
fi

log "\n=================================================================="
log "✓ MODULE UPDATE CHECK & PACKAGING COMPLETE (Qt ${LATEST_UPSTREAM})"
log "  - Modules compiled/updated : ${COMPILED_MODULES}"
log "  - Modules already latest   : ${SKIPPED_MODULES}"
log "  - Hash manifest (text)     : ${HASH_MANIFEST_TXT}"
log "  - Hash manifest (JSON)     : ${HASH_MANIFEST_JSON}"
log "=================================================================="

if [[ "${JSON_OUTPUT}" == "true" ]]; then
    cat "${HASH_MANIFEST_JSON}"
fi

#!/usr/bin/env bash
# ==============================================================================
# Build, Stage, Normalize, and Package a Qt 6 Submodule for Darwin (x86_64 & arm64)
# ==============================================================================
# Usage:
#   ./scripts/build-module.sh <module_short_name> <pkgname> <pkgdesc> [depends...]
# Example:
#   ./scripts/build-module.sh qtsvg qt6-svg "Classes for displaying the contents of SVG files" qt6-base
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

MOD_NAME="${1:?Usage: $0 <mod_name> <pkgname> <pkgdesc> [depends...]}"
PKG_NAME="${2:?Usage: $0 <mod_name> <pkgname> <pkgdesc> [depends...]}"
PKG_DESC="${3:?Usage: $0 <mod_name> <pkgname> <pkgdesc> [depends...]}"
shift 3
DEPENDS=("$@")
if [[ ${#DEPENDS[@]} -eq 0 ]]; then
    DEPENDS=("qt6-base")
fi

QT_VER="${QT_VERSION:-6.12.0}"
PKGREL="${PKGREL:-1}"
TARBALL="${REPO_ROOT}/sources/qt6/${MOD_NAME}-everywhere-src-${QT_VER}.tar.xz"
SRC_PARENT="${REPO_ROOT}/build/src_modules"
SRC_DIR="${SRC_PARENT}/${MOD_NAME}-everywhere-src-${QT_VER}"
OUT_DIR="${REPO_ROOT}/out"
JOBS="$(sysctl -n hw.ncpu)"

if [[ ! -f "${TARBALL}" ]]; then
    echo "ERROR: Source tarball not found: ${TARBALL}" >&2
    exit 1
fi

mkdir -p "${SRC_PARENT}" "${OUT_DIR}"
if [[ ! -d "${SRC_DIR}" ]]; then
    echo "==> Extracting ${TARBALL}..."
    tar -xf "${TARBALL}" -C "${SRC_PARENT}"
fi

build_and_package_arch() {
    local arch="$1"
    local build_dir="${REPO_ROOT}/build/build_${MOD_NAME}_${arch}"
    local stage_dir="${REPO_ROOT}/staging/pkg_${MOD_NAME}_${arch}"
    local pkg_arch="darwin_${arch}"
    local pkg_file="${OUT_DIR}/${PKG_NAME}-${QT_VER}-${PKGREL}-${pkg_arch}.pkg.tar.zst"

    if [[ -f "${pkg_file}" && "${FORCE_BUILD:-0}" != "1" ]]; then
        local sha256 sha512
        sha256=$(shasum -a 256 "${pkg_file}" | awk '{print $1}')
        sha512=$(shasum -a 512 "${pkg_file}" | awk '{print $1}')
        echo "==> [${PKG_NAME} (${pkg_arch})] Already at latest stable (${QT_VER}-${PKGREL}), skipping compile (use FORCE_BUILD=1 to rebuild)."
        echo "    sha256: ${sha256}"
        echo "    sha512: ${sha512:0:64}..."
        return 0
    fi

    echo "=================================================================="
    echo "Building ${PKG_NAME} (${QT_VER}-${PKGREL}) for ${pkg_arch}"
    echo "=================================================================="

    rm -rf "${stage_dir}"
    if [[ "${CLEAN_BUILD:-0}" == "1" ]]; then
        rm -rf "${build_dir}"
    fi
    mkdir -p "${build_dir}" "${stage_dir}"

    local extra_cmake_args=()
    if [[ "${arch}" == "arm64" ]]; then
        local arm_sysroot="${REPO_ROOT}/staging/pkg_arm64/opt/pacman"
        local arm_deps="${REPO_ROOT}/staging/sysroot_arm64/opt/pacman"
        extra_cmake_args+=(
            -DQT_HOST_PATH="/opt/pacman"
            -DCMAKE_PREFIX_PATH="${arm_sysroot};${arm_deps}"
            -DCMAKE_FIND_ROOT_PATH="${arm_sysroot};${arm_deps}"
        )
    else
        extra_cmake_args+=(
            -DCMAKE_PREFIX_PATH="/opt/pacman"
        )
    fi

    # Keep qttools focused on tools + linguist + designer + help without Clang/QDoc dependency if LLVM is not in /opt/pacman
    if [[ "${MOD_NAME}" == "qttools" ]]; then
        extra_cmake_args+=(
            -DFEATURE_qdoc=OFF
            -DFEATURE_clang=OFF
            -DFEATURE_clangcpp=OFF
            -DQT_FORCE_BUILD_TOOLS=ON
            -DQT_BUILD_TOOLS_WHEN_CROSSCOMPILING=ON
        )
    fi

    if [[ ! -f "${build_dir}/build.ninja" || "${CLEAN_BUILD:-0}" == "1" ]]; then
        cmake -B "${build_dir}" -S "${SRC_DIR}" -G Ninja \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX="/opt/pacman" \
            -DCMAKE_IGNORE_PREFIX_PATH="/opt/local;/usr/local" \
            -DCMAKE_OSX_ARCHITECTURES="${arch}" \
            -DCMAKE_OSX_DEPLOYMENT_TARGET="15.0" \
            -DCMAKE_INSTALL_RPATH="/opt/pacman/lib" \
            -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON \
            -DQT_FEATURE_framework=OFF \
            -DQT_BUILD_TESTS=OFF \
            -DQT_BUILD_EXAMPLES=OFF \
            "${extra_cmake_args[@]}"
    fi

    cmake --build "${build_dir}" --parallel "${JOBS}"
    if [[ "${MOD_NAME}" == "qttools" && "${arch}" == "arm64" ]]; then
        # When cross-compiling qttools, tool targets excluded from default 'all' must be built explicitly before install
        cmake --build "${build_dir}" --target qhelpgenerator qtattributionsscanner lconvert lcheck lrelease lrelease-pro lupdate lupdate-pro ltext2id --parallel "${JOBS}" || true
    elif [[ "${MOD_NAME}" == "qtquick3dphysics" && "${arch}" == "arm64" ]]; then
        cmake --build "${build_dir}" --target cooker --parallel "${JOBS}" || true
    fi

    echo "==> Staging ${PKG_NAME} (${pkg_arch}) into ${stage_dir}..."
    DESTDIR="${stage_dir}" cmake --install "${build_dir}"

    # Expose any module libexec developer tools in /opt/pacman/bin via relative symlinks
    if [[ -d "${stage_dir}/opt/pacman/libexec" ]]; then
        mkdir -p "${stage_dir}/opt/pacman/bin"
        for tool_path in "${stage_dir}/opt/pacman/libexec/"*; do
            [[ -f "${tool_path}" && -x "${tool_path}" ]] || continue
            tool_name="$(basename "${tool_path}")"
            if [[ ! -e "${stage_dir}/opt/pacman/bin/${tool_name}" ]]; then
                ln -sf "../libexec/${tool_name}" "${stage_dir}/opt/pacman/bin/${tool_name}"
            fi
        done
    fi

    # Also install into cumulative arm64 sysroot so subsequent arm64 modules can link against it
    if [[ "${arch}" == "arm64" ]]; then
        DESTDIR="${REPO_ROOT}/staging/pkg_arm64" cmake --install "${build_dir}" >/dev/null
    fi

    # Clean macOS .DS_Store and build-tree paths in .prl files
    find "${stage_dir}" -name ".DS_Store" -delete 2>/dev/null || true
    find "${stage_dir}" -name "*.prl" -exec sed -i '' -e '/^QMAKE_PRL_BUILD_DIR/d' {} + 2>/dev/null || true

    # Copy upstream licenses
    if [[ -d "${SRC_DIR}/LICENSES" ]]; then
        mkdir -p "${stage_dir}/opt/pacman/share/licenses/${PKG_NAME}"
        cp -a "${SRC_DIR}/LICENSES/"* "${stage_dir}/opt/pacman/share/licenses/${PKG_NAME}/" 2>/dev/null || true
    fi

    # Ad-hoc codesign all Mach-O executables, dylibs, and bundles
    find "${stage_dir}/opt/pacman" -type f | while read -r f; do
        if file "$f" | grep -qE "Mach-O.*(executable|dynamically linked shared library|bundle)"; then
            codesign --sign - --force "$f" 2>/dev/null || true
        fi
    done

    # Generate .PKGINFO and .BUILDINFO
    local installed_size builddate
    installed_size=$(du -sk "${stage_dir}/opt/pacman" | awk '{print $1 * 1024}')
    builddate=$(date +%s)

    {
        echo "# Generated by qt6_darwin build-module.sh"
        echo "pkgname = ${PKG_NAME}"
        echo "pkgbase = ${PKG_NAME}"
        echo "pkgver = ${QT_VER}-${PKGREL}"
        echo "pkgdesc = ${PKG_DESC}"
        echo "url = https://www.qt.io"
        echo "builddate = ${builddate}"
        echo "packager = Revanth <revanth@darwin>"
        echo "size = ${installed_size}"
        echo "arch = ${pkg_arch}"
        echo "license = GPL3"
        echo "license = LGPL3"
        echo "license = custom"
        for dep in "${DEPENDS[@]}"; do
            echo "depend = ${dep}"
        done
    } > "${stage_dir}/.PKGINFO"

    cat > "${stage_dir}/.BUILDINFO" <<EOF
format = 2
pkgname = ${PKG_NAME}
pkgbase = ${PKG_NAME}
pkgver = ${QT_VER}-${PKGREL}
pkgarch = ${pkg_arch}
pkgbuild_sha256sum = $(shasum -a 256 "${REPO_ROOT}/packages/qt6/${PKG_NAME}/PKGBUILD" 2>/dev/null | awk '{print $1}' || echo "0000000000000000000000000000000000000000000000000000000000000000")
packager = Revanth <revanth@darwin>
builddate = ${builddate}
builddir = ${build_dir}
startdir = ${REPO_ROOT}
buildtool = makepkg-darwin
buildenv = !distcc
buildenv = color
buildenv = !ccache
EOF

    # Generate .MTREE and final .pkg.tar.zst normalized to root:wheel (0:0)
    (
        cd "${stage_dir}"
        rm -f .MTREE "${pkg_file}"
        find .PKGINFO .BUILDINFO opt -print0 | LC_ALL=C /usr/bin/sort -z | \
            bsdtar -cnf - --null -T - \
            --uid 0 --gid 0 --uname root --gname wheel \
            --format=mtree \
            --options='!all,use-set,type,uid,gid,mode,time,size,md5,sha256,link' \
            | gzip -c -f -n > .MTREE

        find .PKGINFO .BUILDINFO .MTREE opt -print0 | LC_ALL=C /usr/bin/sort -z | \
            bsdtar -cnf - --null -T - \
            --uid 0 --gid 0 --uname root --gname wheel \
            | zstd -T0 -19 -o "${pkg_file}"
    )

    echo "==> Packaged: ${pkg_file} ($(du -h "${pkg_file}" | awk '{print $1}'))"
    "${SCRIPT_DIR}/verify-package.sh" "${stage_dir}"

    # On x86_64 host, install the newly built x86_64 package into /opt/pacman immediately
    # so its host tools (e.g. Qt6QmlTools: qmltyperegistrar, qmlcachegen) are available
    # in QT_HOST_PATH (/opt/pacman) when cross-compiling arm64!
    if [[ "${arch}" == "x86_64" && -x "/opt/pacman/bin/pacman" ]]; then
        echo "==> Installing ${pkg_file} into /opt/pacman (updating QT_HOST_PATH)..."
        /opt/pacman/bin/pacman -U --noconfirm "${pkg_file}"
    fi
}

if [[ "${ONLY_ARCH:-}" == "x86_64" ]]; then
    build_and_package_arch "x86_64"
elif [[ "${ONLY_ARCH:-}" == "arm64" ]]; then
    build_and_package_arch "arm64"
else
    build_and_package_arch "x86_64"
    build_and_package_arch "arm64"
fi


#!/usr/bin/env bash
set -euo pipefail

QT_VERSION="6.12.0"
ARCHIVE_NAME="qtbase-everywhere-src-${QT_VERSION}.tar.xz"
EXPECTED_SHA256="a951bd163c7b80fc6b8c88d7668fb56abf91c152373e13c10666763238131307"
SOURCE_URL="https://download.qt.io/official_releases/qt/6.12/${QT_VERSION}/submodules/${ARCHIVE_NAME}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SOURCES_DIR="${PROJECT_ROOT}/sources/qt6"

mkdir -p "${SOURCES_DIR}"
TARGET_FILE="${SOURCES_DIR}/${ARCHIVE_NAME}"

echo "Target archive: ${TARGET_FILE}"
if [[ -f "${TARGET_FILE}" ]]; then
    echo "File already exists. Checking SHA-256..."
    ACTUAL_SHA256=$(shasum -a 256 "${TARGET_FILE}" | awk '{print $1}')
    if [[ "${ACTUAL_SHA256}" == "${EXPECTED_SHA256}" ]]; then
        echo "SHA-256 matches: ${ACTUAL_SHA256}"
        exit 0
    else
        echo "SHA-256 mismatch! Found: ${ACTUAL_SHA256}, expected: ${EXPECTED_SHA256}"
        echo "Removing corrupt file and re-downloading..."
        rm -f "${TARGET_FILE}"
    fi
fi

echo "Downloading ${ARCHIVE_NAME} from ${SOURCE_URL}..."
curl -fL --progress-bar -o "${TARGET_FILE}" "${SOURCE_URL}"

echo "Verifying SHA-256..."
ACTUAL_SHA256=$(shasum -a 256 "${TARGET_FILE}" | awk '{print $1}')
if [[ "${ACTUAL_SHA256}" != "${EXPECTED_SHA256}" ]]; then
    echo "ERROR: SHA-256 verification failed!"
    echo "Expected: ${EXPECTED_SHA256}"
    echo "Actual:   ${ACTUAL_SHA256}"
    exit 1
fi

echo "Source verified successfully: ${TARGET_FILE}"


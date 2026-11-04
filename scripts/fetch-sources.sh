#!/usr/bin/env bash
set -euo pipefail

QT_VERSION="${QT_VERSION:-6.12.0}"
QT_MINOR="${QT_VERSION%.*}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SOURCES_DIR="${PROJECT_ROOT}/sources/qt6"

mkdir -p "${SOURCES_DIR}"

declare -a MODULES=(
    "qtbase|a951bd163c7b80fc6b8c88d7668fb56abf91c152373e13c10666763238131307"
    "qtsvg|e4ab39534ec97987b1b9b60ef7f4d3253d5912a69f8c713a01753174a4029331"
    "qtimageformats|0943132b5db8de6b6a7f1d162682173e8763c7ed94e80fd39113292845f67762"
    "qtshadertools|c7d84f436e1aaef39fdcadebf2bd71bdf24dc69497e13f2e0198873cbbfea2ab"
    "qttools|8dab8f3611496486a470ad5f115ceea584f36bc22a2b8b6f6ebdbafbb8160693"
    "qtlanguageserver|552119e37360c06c5fb0b54e91bbfdf8da5a80d2cb1441ef93e966eb3b7a426d"
    "qtdeclarative|311f3a2603e1973bb59baef9dfa740a376de713157d4782ee043681e889c9260"
    "qtquicktimeline|6919153c841478c113f0ad20526f40e606590968334762ec6ccbc96002f8da19"
    "qtlottie|6b8f04c917f2666f8cca4e7804bcabb6edffe151406b89fb28de3bba5a5d997e"
    "qtquick3d|6ced6edbd25fb5a632fe770ae820b376bf50233e8d62002c79a69a505a2e429e"
    "qtquick3dphysics|8ddb23147e4677c759d36a65ae50f6b0d0d79fa8590ac89576b91f572918b481"
    "qtmultimedia|3143f53b64257ba2a0685c940f5dce476c75871ff86b516de45cfd54ea93a62d"
    "qtnetworkauth|17d47be1a724d21775daa873ac7a52c30fd5c4935ba377af48d9b37b39765ed8"
    "qtwebsockets|21690a365cd5fbfa8dea051473e98968df9f4eca0121fed7481d1215b7455a31"
    "qtserialport|ba8886a54eee466e57c9fa1341255cc09c462c84baab3ee7b19d67cdbcbd71c3"
    "qtconnectivity|ed51f7f02c1f437fcf8a42940c7a84f6c0908c0ec7a4f5a5304fe68f47521954"
)

for entry in "${MODULES[@]}"; do
    IFS='|' read -r mod expected_sha <<< "${entry}"
    archive_name="${mod}-everywhere-src-${QT_VERSION}.tar.xz"
    target_file="${SOURCES_DIR}/${archive_name}"
    source_url="https://download.qt.io/official_releases/qt/${QT_MINOR}/${QT_VERSION}/submodules/${archive_name}"

    if [[ -f "${target_file}" ]]; then
        actual_sha=$(shasum -a 256 "${target_file}" | awk '{print $1}')
        if [[ "${actual_sha}" == "${expected_sha}" ]]; then
            echo "✓ Verified ${archive_name} (${actual_sha})"
            continue
        fi
        echo "SHA-256 mismatch for ${archive_name}, re-downloading..."
        rm -f "${target_file}"
    fi

    echo "--> Downloading ${archive_name}..."
    curl -fL --retry 3 -o "${target_file}" "${source_url}"
    actual_sha=$(shasum -a 256 "${target_file}" | awk '{print $1}')
    if [[ "${actual_sha}" != "${expected_sha}" ]]; then
        echo "ERROR: SHA-256 verification failed for ${archive_name}!"
        exit 1
    fi
    echo "✓ Verified ${archive_name} (${actual_sha})"
done

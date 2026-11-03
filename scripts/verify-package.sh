#!/usr/bin/env bash
set -euo pipefail

TARGET_PATH="${1:-}"

if [[ -z "${TARGET_PATH}" ]]; then
    echo "Usage: $0 <path-to-binary-or-directory>"
    exit 1
fi

echo "=== Auditing Mach-O Binaries in: ${TARGET_PATH} ==="

FAILURES=0

audit_binary() {
    local bin="$1"
    if ! file "${bin}" | grep -q "Mach-O"; then
        return
    fi

    echo -e "\n--> Checking: ${bin}"
    lipo -info "${bin}"
    
    # Check for forbidden runtime library paths
    local bad_deps
    bad_deps=$(otool -L "${bin}" | grep -E '/opt/local|/usr/local|/opt/homebrew' || true)
    if [[ -n "${bad_deps}" ]]; then
        echo "❌ FORBIDDEN DEPENDENCIES FOUND:"
        echo "${bad_deps}"
        FAILURES=$((FAILURES + 1))
    else
        echo "✓ Clean runtime dependencies (no MacPorts/Homebrew leakage)."
    fi

    # Check codesignature
    if codesign -v "${bin}" 2>/dev/null; then
        echo "✓ Valid codesignature."
    else
        echo "⚠ Codesignature missing or invalid."
    fi
}

if [[ -d "${TARGET_PATH}" ]]; then
    while IFS= read -r -d '' file; do
        audit_binary "${file}"
    done < <(find "${TARGET_PATH}" -type f -print0)
elif [[ -f "${TARGET_PATH}" ]]; then
    audit_binary "${TARGET_PATH}"
else
    echo "Error: Path not found: ${TARGET_PATH}"
    exit 1
fi

if [[ ${FAILURES} -gt 0 ]]; then
    echo -e "\n❌ AUDIT FAILED with ${FAILURES} errors."
    exit 1
else
    echo -e "\n✓ ALL AUDITED BINARIES PASSED CLEANLY."
fi

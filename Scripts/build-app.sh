#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
OUTPUT_DIR="${1:-${PROJECT_DIR}/build/Release}"
SIGNING_IDENTITY="${ASWAS_SIGNING_IDENTITY:--}"
APP_NAME="aswas.app"
FINAL_APP="${OUTPUT_DIR}/${APP_NAME}"

mkdir -p "${OUTPUT_DIR}"
# Stage outside file-provider-backed project folders. Some providers may
# re-attach Finder metadata immediately after `xattr -cr`, which codesign
# correctly rejects as resource-fork detritus.
STAGING_ROOT="${TMPDIR:-/private/tmp}"
STAGING_DIR="$(mktemp -d "${STAGING_ROOT%/}/aswas-stage.XXXXXX")"
trap 'rm -rf "${STAGING_DIR}"' EXIT

swift build --package-path "${PROJECT_DIR}" -c release --product aswas
BIN_PATH="$(swift build --package-path "${PROJECT_DIR}" -c release --show-bin-path)"
STAGED_APP="${STAGING_DIR}/${APP_NAME}"

mkdir -p "${STAGED_APP}/Contents/MacOS"
mkdir -p "${STAGED_APP}/Contents/Resources/Scripts"
cp "${BIN_PATH}/aswas" "${STAGED_APP}/Contents/MacOS/aswas"
cp "${PROJECT_DIR}/Configuration/Info.plist" "${STAGED_APP}/Contents/Info.plist"
printf 'APPL????' > "${STAGED_APP}/Contents/PkgInfo"
cp "${PROJECT_DIR}/Sources/AswasCore/Resources/Scripts/"*.applescript \
    "${STAGED_APP}/Contents/Resources/Scripts/"
for localization in en zh-Hans; do
    cp -R "${PROJECT_DIR}/Sources/AswasCore/Resources/${localization}.lproj" \
        "${STAGED_APP}/Contents/Resources/"
done
xcrun actool "${PROJECT_DIR}/Assets/AppIcon/AppIcon.xcassets" \
    --compile "${STAGED_APP}/Contents/Resources" \
    --platform macosx \
    --minimum-deployment-target 14.0 \
    --app-icon AppIcon \
    --output-partial-info-plist "${STAGING_DIR}/asset-info.plist"
dot_clean -m "${STAGED_APP}"
xattr -cr "${STAGED_APP}"

codesign --force --deep --options runtime --timestamp=none \
    --entitlements "${PROJECT_DIR}/Configuration/aswas.entitlements" \
    --sign "${SIGNING_IDENTITY}" "${STAGED_APP}"

if [[ -e "${FINAL_APP}" ]]; then
    mv "${FINAL_APP}" "${FINAL_APP}.previous-$(date +%Y%m%d%H%M%S)"
fi
mv "${STAGED_APP}" "${FINAL_APP}"
xattr -cr "${FINAL_APP}"

codesign --verify --deep --strict --verbose=2 "${FINAL_APP}"
plutil -lint "${FINAL_APP}/Contents/Info.plist"

echo "Built ${FINAL_APP}"

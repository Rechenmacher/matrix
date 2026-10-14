#!/usr/bin/env bash
# Xcode "Run Script" build phase — copies web assets into the .saver bundle.
# Add this as a Run Script phase in Xcode, after Compile Sources.
#
# In Xcode: Target → Build Phases → + → New Run Script Phase
# Shell: /bin/bash
# Script: bash "${SRCROOT}/copy_web_assets.sh"

set -euo pipefail

REPO_ROOT="$(cd "${SRCROOT}/../../../" && pwd)"
RESOURCES="${BUILT_PRODUCTS_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"

echo "Copying web assets from ${REPO_ROOT} to ${RESOURCES}"

for item in index.html js shaders assets lib; do
    src="${REPO_ROOT}/${item}"
    if [ -e "${src}" ]; then
        rm -rf "${RESOURCES}/${item}"
        cp -R "${src}" "${RESOURCES}/${item}"
        echo "  Copied ${item}"
    else
        echo "  WARNING: ${src} not found, skipping"
    fi
done

echo "Web assets copied."

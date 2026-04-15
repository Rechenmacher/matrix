#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build"
DIST_DIR="${SCRIPT_DIR}/dist"

echo "=== Matrix Screensaver Build ==="

# 1. Build the .saver bundle (arm64 + x86_64)
echo "[1/5] Building .saver bundle..."
cd "${SCRIPT_DIR}"
xcodebuild -project matrix.xcodeproj \
  -target MatrixScreenSaver \
  -configuration Release \
  build \
  CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
  ARCHS="arm64 x86_64" VALID_ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO \
  BUILD_DIR="${BUILD_DIR}" \
  2>&1 | grep -E "(BUILD|error:)" || true

SAVER="${BUILD_DIR}/Release/Matrix.saver"
if [ ! -d "${SAVER}" ]; then
  echo "ERROR: .saver bundle not found at ${SAVER}"
  exit 1
fi

# 2. Compile the companion app as a universal binary
echo "[2/5] Compiling MatrixSaverApp (universal)..."
swiftc -O \
  -o "${BUILD_DIR}/MatrixSaverApp_arm64" \
  -framework Cocoa -framework WebKit \
  -target arm64-apple-macos12.0 \
  MatrixScreenSaver/MatrixSaverApp.swift

swiftc -O \
  -o "${BUILD_DIR}/MatrixSaverApp_x86_64" \
  -framework Cocoa -framework WebKit \
  -target x86_64-apple-macos12.0 \
  MatrixScreenSaver/MatrixSaverApp.swift

lipo -create \
  "${BUILD_DIR}/MatrixSaverApp_arm64" \
  "${BUILD_DIR}/MatrixSaverApp_x86_64" \
  -output "${BUILD_DIR}/MatrixSaverApp"

# 3. Assemble the bundle
echo "[3/5] Assembling bundle..."
RESOURCES="${SAVER}/Contents/Resources"
mkdir -p "${RESOURCES}"

# Copy companion app
cp "${BUILD_DIR}/MatrixSaverApp" "${RESOURCES}/MatrixSaverApp"
chmod +x "${RESOURCES}/MatrixSaverApp"

# Copy web assets
for item in index.html js shaders assets lib; do
  rm -rf "${RESOURCES}/${item}"
  cp -R "${REPO_ROOT}/${item}" "${RESOURCES}/${item}"
done

# Copy thumbnail and preview images for System Settings
cp "${SCRIPT_DIR}/MatrixScreenSaver/thumbnail.png" "${RESOURCES}/thumbnail.png" 2>/dev/null || true
cp "${SCRIPT_DIR}/MatrixScreenSaver/preview.png" "${RESOURCES}/preview.png" 2>/dev/null || true

# 4. Ad-hoc sign (replace with Developer ID for distribution)
echo "[4/5] Code signing..."
codesign --force --deep -s - "${SAVER}"

# 5. Create dist directory with the final .saver
echo "[5/5] Creating distribution..."
rm -rf "${DIST_DIR}"
mkdir -p "${DIST_DIR}"
cp -R "${SAVER}" "${DIST_DIR}/Matrix.saver"

echo ""
echo "=== Build complete ==="
echo "  ${DIST_DIR}/Matrix.saver"
echo ""
echo "To install locally:"
echo "  cp -R ${DIST_DIR}/Matrix.saver ~/Library/Screen\\ Savers/"
echo ""
echo "To install for all users:"
echo "  sudo cp -R ${DIST_DIR}/Matrix.saver /Library/Screen\\ Savers/"
echo ""
echo "Bundle architectures:"
file "${DIST_DIR}/Matrix.saver/Contents/MacOS/Matrix"
file "${DIST_DIR}/Matrix.saver/Contents/Resources/MatrixSaverApp"
echo ""
echo "Bundle size:"
du -sh "${DIST_DIR}/Matrix.saver"

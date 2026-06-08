#!/usr/bin/env bash
#MISE description="Bundles the CLI without signing or notarization"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${MISE_PROJECT_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$PROJECT_ROOT/mise/utilities/setup.sh"

BUILD_DIRECTORY="$PROJECT_ROOT/build"
TMP_DIR="/private$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

DERIVED_DATA_PATH="$TMP_DIR/derived-data"
SPEC_TMP_DIR="$TMP_DIR/spec"

echo "$(format_section "Building unsigned CLI bundle into $BUILD_DIRECTORY")"

rm -rf "$PROJECT_ROOT/Tuist.xcodeproj"
rm -rf "$PROJECT_ROOT/Tuist.xcworkspace"
rm -rf "$BUILD_DIRECTORY"
mkdir -p "$BUILD_DIRECTORY"

echo "$(format_subsection "Installing Tuist dependencies")"
tuist install --path "$PROJECT_ROOT"

echo "$(format_subsection "Generating Xcode project")"
TUIST_FORCE_STATIC_LINKING=1 tuist generate --no-binary-cache --path "$PROJECT_ROOT" --no-open

echo "$(format_subsection "Building tuist executable")"
xcodebuild \
    -configuration Release \
    -workspace "$PROJECT_ROOT/Tuist.xcworkspace" \
    -scheme tuist \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    -destination generic/platform=macOS \
    ONLY_ACTIVE_ARCH=NO \
    SKIP_INSTALL=NO \
    CODE_SIGN_IDENTITY="\"\"" \
    CODE_SIGN_ENTITLEMENTS="\"\"" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO
cp "$DERIVED_DATA_PATH/Build/Products/Release/tuist" "$BUILD_DIRECTORY/tuist"

echo "$(format_subsection "Building ProjectDescription framework")"
xcrun xcodebuild \
    -workspace "$PROJECT_ROOT/Tuist.xcworkspace" \
    -scheme ProjectDescription \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    -configuration Release \
    -destination platform=macOS \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    ARCHS='arm64 x86_64' \
    ONLY_ACTIVE_ARCH=NO \
    clean build
rsync -a "$DERIVED_DATA_PATH/Build/Products/Release/ProjectDescription.framework" "$BUILD_DIRECTORY/"
rsync -a "$DERIVED_DATA_PATH/Build/Products/Release/ProjectDescription.framework.dSYM" "$BUILD_DIRECTORY/"

echo "$(format_subsection "Copying templates")"
cp -r "$PROJECT_ROOT/cli/Templates" "$BUILD_DIRECTORY/Templates"

echo "$(format_subsection "Generating tuist.spec.json")"
mkdir -p "$SPEC_TMP_DIR"
"$BUILD_DIRECTORY/tuist" --experimental-dump-help --path "$SPEC_TMP_DIR" > "$BUILD_DIRECTORY/tuist.spec.json"

echo "$(format_subsection "Bundling tuist.zip")"
(
    cd "$BUILD_DIRECTORY"
    zip -q -r --symlinks tuist.zip tuist ProjectDescription.framework ProjectDescription.framework.dSYM Templates

    : > SHASUMS256.txt
    : > SHASUMS512.txt
    for file in tuist.zip tuist.spec.json; do
        echo "$(shasum -a 256 "$file" | awk '{print $1}') ./$file" >> SHASUMS256.txt
        echo "$(shasum -a 512 "$file" | awk '{print $1}') ./$file" >> SHASUMS512.txt
    done
)

echo "$(format_success "Unsigned CLI bundle created at $BUILD_DIRECTORY/tuist.zip")"

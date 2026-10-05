#!/bin/sh
set -eu
set -o pipefail

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
WORKSPACE="$ROOT/alt-tab-macos.xcworkspace"
SCHEME="Release"
CONFIG_FILE="$ROOT/config/base.xcconfig"
APP_NAME="DockAltTab"
DOWNLOADS="$HOME/Downloads"
WEBSITE_ROOT=${DOCKALTTAB_WEBSITE_ROOT:-"$HOME/proj/web/js/DockAltTab-home"}

usage() {
    cat <<'EOF'
Usage:
  scripts/make-release.sh              Build the next patch release (x.yy.z -> x.yy.z+1).
  scripts/make-release.sh patch        Same as no argument.
  scripts/make-release.sh minor        Bump the middle component (x.yy.z -> x.(yy+1).0).
  scripts/make-release.sh major        Bump the first component (x.yy.z -> (x+1).00.0).
  scripts/make-release.sh NUMBER       Set the first component (NUMBER.00.0).

The script updates MARKETING_VERSION/CURRENT_PROJECT_VERSION in config/base.xcconfig,
archives the Release arm64 application using the Release scheme, and creates:

  ~/Downloads/DockAltTab-vVERSION.zip

The build number encodes the marketing version as
major*10000 + minor*100 + patch (e.g. 4.00.0 -> 40000).
EOF
    exit 2
}

[ "$#" -le 1 ] || usage
if [ "$#" -eq 1 ] && { [ "$1" = "-h" ] || [ "$1" = "--help" ]; }; then
    usage
fi

BUILD_SETTINGS=$(xcodebuild \
    -workspace "$WORKSPACE" \
    -scheme "$SCHEME" \
    -configuration Release \
    -showBuildSettings 2>/dev/null)

CURRENT_VERSION=$(printf '%s\n' "$BUILD_SETTINGS" | awk -F ' = ' '/^[[:space:]]+MARKETING_VERSION = / { print $2; exit }')
CURRENT_BUILD=$(printf '%s\n' "$BUILD_SETTINGS" | awk -F ' = ' '/^[[:space:]]+CURRENT_PROJECT_VERSION = / { print $2; exit }')

[ -n "$CURRENT_VERSION" ] || { echo "error: could not read MARKETING_VERSION" >&2; exit 1; }
[ -n "$CURRENT_BUILD" ] || { echo "error: could not read CURRENT_PROJECT_VERSION" >&2; exit 1; }

if [ "$#" -eq 0 ]; then
    MODE=patch
else
    case "$1" in
        patch|minor|major)
            MODE=$1
            ;;
        ''|*[!0-9]*)
            echo "error: argument must be patch, minor, major, or a numeric major version" >&2
            exit 1
            ;;
        *)
            MODE="set-major:$1"
            ;;
    esac
fi

NEW_VERSION=$(python3 - "$CURRENT_VERSION" "$MODE" <<'PY'
import re
import sys

current, mode = sys.argv[1:]
match = re.fullmatch(r"(\d+)\.(\d+)\.(\d+)", current)
if not match:
    raise SystemExit(f"error: expected x.yy.z version, found {current!r}")

major, minor, patch = map(int, match.groups())
if mode.startswith("set-major:"):
    major = int(mode.split(":", 1)[1])
    minor = patch = 0
elif mode == "major":
    major += 1
    minor = patch = 0
elif mode == "minor":
    minor += 1
    patch = 0
else:
    patch += 1

print(f"{major}.{minor:02d}.{patch}")
PY
)

# Sparkle compares CFBundleVersion (sparkle:version); keep it a monotonic
# integer derived from the marketing version so ordering is unambiguous.
NEW_BUILD=$(python3 - "$NEW_VERSION" <<'PY'
import sys

major, minor, patch = (int(part) for part in sys.argv[1].split("."))
print(major * 10000 + minor * 100 + patch)
PY
)

printf 'Current version/build: %s / %s\n' "$CURRENT_VERSION" "$CURRENT_BUILD"
printf 'Release version/build: %s / %s\n' "$NEW_VERSION" "$NEW_BUILD"
printf 'Update config/base.xcconfig and archive? [y/N] '
read -r CONFIRM
case "$CONFIRM" in
    y|Y|yes|YES) ;;
    *) echo "Cancelled."; exit 2 ;;
esac

python3 - "$CONFIG_FILE" "$CURRENT_VERSION" "$NEW_VERSION" "$CURRENT_BUILD" "$NEW_BUILD" <<'PY'
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
old_version, new_version, old_build, new_build = sys.argv[2:]
text = path.read_text()

patterns = (
    (r"(?m)^MARKETING_VERSION = .*$", f"MARKETING_VERSION = {new_version}"),
    (r"(?m)^CURRENT_PROJECT_VERSION = .*$", f"CURRENT_PROJECT_VERSION = {new_build}"),
)
for pattern, replacement in patterns:
    text, count = re.subn(pattern, replacement, text, count=1)
    if count != 1:
        raise SystemExit(f"error: could not update {pattern!r} in {path}")

if f"MARKETING_VERSION = {old_version}" in text:
    raise SystemExit("error: old MARKETING_VERSION still present after update")

path.write_text(text)
PY

ARCHIVE_DATE=$(date +%Y-%m-%d)
ARCHIVE_STAMP=$(date +%H.%M.%S)
ARCHIVE_DIR="$HOME/Library/Developer/Xcode/Archives/$ARCHIVE_DATE"
ARCHIVE_PATH="$ARCHIVE_DIR/$APP_NAME $NEW_VERSION $ARCHIVE_STAMP.xcarchive"
ZIP_PATH="$DOWNLOADS/DockAltTab-v$NEW_VERSION.zip"
mkdir -p "$ARCHIVE_DIR" "$DOWNLOADS"
rm -f "$ZIP_PATH"

printf 'Archiving to:\n  %s\n' "$ARCHIVE_PATH"
xcodebuild \
    -workspace "$WORKSPACE" \
    -scheme "$SCHEME" \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    archive

APP_PATH="$ARCHIVE_PATH/Products/Applications/$APP_NAME.app"
if [ ! -d "$APP_PATH" ]; then
    echo "error: archived app was not found:" >&2
    echo "  $APP_PATH" >&2
    exit 1
fi

INFO_PLIST="$APP_PATH/Contents/Info.plist"
ARCHIVE_VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")
ARCHIVE_BUILD=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO_PLIST")
[ "$ARCHIVE_VERSION" = "$NEW_VERSION" ] || {
    echo "error: archived app version is $ARCHIVE_VERSION, expected $NEW_VERSION" >&2
    exit 1
}
[ "$ARCHIVE_BUILD" = "$NEW_BUILD" ] || {
    echo "error: archived app build is $ARCHIVE_BUILD, expected $NEW_BUILD" >&2
    exit 1
}

printf 'Creating ZIP:\n  %s\n' "$ZIP_PATH"
# --norsrc/--noextattr keep AppleDouble (._*) sidecar files out of the ZIP.
# Without them, tools other than Archive Utility extract ._* files into the
# bundle, which breaks the code seal and makes macOS report the app as
# "damaged" instead of the usual unnotarized warning.
ditto -c -k --keepParent --norsrc --noextattr "$APP_PATH" "$ZIP_PATH"

printf '\nRelease archive ready:\n  version: %s\n  build:   %s\n  app:     %s\n  ZIP:     %s\n\nNext step (publish the ZIP that was just built):\n  cd "%s"\n  scripts/publish-release.sh %s "%s" --build-version %s --generate-notes --tag --push-site --create-release\n\nOr, next time, run the wrapper instead so it does both steps:\n  scripts/deploy.sh %s\n' \
    "$NEW_VERSION" "$NEW_BUILD" "$APP_PATH" "$ZIP_PATH" \
    "$WEBSITE_ROOT" "$NEW_VERSION" "$ZIP_PATH" "$NEW_BUILD" "$MODE"

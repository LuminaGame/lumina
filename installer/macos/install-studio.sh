#!/bin/sh
# Downloads the latest Lumina Studio for macOS from the GitHub releases into
# /Applications (installed as /usr/local/lib/lumina-studio/install-studio.sh).
# NOT VERIFIED: see installer/macos/build-pkg.sh.
#
#   install-studio.sh [--tag <tag>|latest] [--repo <owner/name>]
#
# Exit codes: 0 done, 30 the release could not be read or downloaded.
set -eu
TAG=latest
REPO=LuminaGame/lumina
while [ $# -gt 0 ]; do
  case "$1" in
    --tag) TAG="$2"; shift 2 ;;
    --repo) REPO="$2"; shift 2 ;;
    *) echo "unknown option $1" >&2; exit 64 ;;
  esac
done
if [ "$TAG" = latest ]; then API="https://api.github.com/repos/$REPO/releases/latest"; else API="https://api.github.com/repos/$REPO/releases/tags/$TAG"; fi

JSON="$(curl -fsSL --connect-timeout 20 --max-time 60 -H 'Accept: application/vnd.github+json' "$API")" || { echo "No answer from $API." >&2; exit 30; }
URLS="$(printf '%s' "$JSON" | tr ',' '\n' | sed -n 's/.*"browser_download_url"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
ZIP_URL="$(printf '%s\n' "$URLS" | grep -E '/lumina-studio-[^/]+-macos-[a-z0-9_]+\.zip$' | head -n1 || true)"
[ -n "$ZIP_URL" ] || { echo "The release has no lumina-studio-*-macos-*.zip." >&2; exit 30; }
SUM_URL="$(printf '%s\n' "$URLS" | grep -F "$(basename "$ZIP_URL").sha256" | head -n1 || true)"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
curl -fL --retry 3 -o "$work/studio.zip" "$ZIP_URL" || exit 30
if [ -n "$SUM_URL" ]; then
  curl -fsSL --retry 3 -o "$work/studio.zip.sha256" "$SUM_URL" || exit 30
  [ "$(cut -d' ' -f1 < "$work/studio.zip.sha256")" = "$(shasum -a 256 "$work/studio.zip" | cut -d' ' -f1)" ] \
    || { echo "SHA-256 mismatch." >&2; exit 30; }
fi
ditto -x -k "$work/studio.zip" "$work/app"
app="$(find "$work/app" -maxdepth 1 -name '*.app' | head -n1)"
[ -n "$app" ] || { echo "The archive holds no .app." >&2; exit 1; }
rm -rf "/Applications/Lumina Studio.app"
mv "$app" "/Applications/Lumina Studio.app"
echo "Lumina Studio installed in /Applications."

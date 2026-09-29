#!/bin/sh
# Downloads Lumina Studio for Linux from the GitHub releases and installs it
# into a folder. Installed as /usr/lib/lumina-studio/install-studio.sh; the
# package's postinst and the lumina-studio launcher use it.
#
#   install-studio.sh [--target <dir>] [--tag <tag>|latest] [--repo <owner/name>] [--dry-run]
#
# The release's lumina-studio-<tag>-linux-x64.tar.gz is checked against its
# .sha256 sidecar, unpacked next to <dir> and swapped in, so a failed
# download never leaves a half-written editor behind.
#
# Exit codes: 0 done, 30 the release could not be read or downloaded,
# 1 anything else. GITHUB_TOKEN, when set, is sent to the API (rate limits).
set -eu

TARGET=/opt/lumina/studio
TAG=latest
REPO=LuminaGame/lumina
DRY_RUN=0

while [ $# -gt 0 ]; do
  case "$1" in
    --target) TARGET="$2"; shift 2 ;;
    --tag) TAG="$2"; shift 2 ;;
    --repo) REPO="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) sed -n '2,16p' "$0"; exit 0 ;;
    *) echo "install-studio.sh: unknown option $1" >&2; exit 64 ;;
  esac
done

say() { printf '%s\n' "$*"; }
fail_network() {
  say "Lumina Studio could not be downloaded: $*" >&2
  say "Check the internet connection, then run 'lumina-studio --update' (or just 'lumina-studio')." >&2
  exit 30
}

for tool in curl tar sha256sum; do
  command -v "$tool" >/dev/null 2>&1 || { say "install-studio.sh needs $tool." >&2; exit 1; }
done

if [ "$TAG" = latest ]; then
  API="https://api.github.com/repos/$REPO/releases/latest"
else
  API="https://api.github.com/repos/$REPO/releases/tags/$TAG"
fi

curl_api() {
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    curl -fsSL --connect-timeout 20 --max-time 60 --retry 2 \
      -H "Accept: application/vnd.github+json" -H "User-Agent: lumina-studio-setup" \
      -H "Authorization: Bearer $GITHUB_TOKEN" "$1"
  else
    curl -fsSL --connect-timeout 20 --max-time 60 --retry 2 \
      -H "Accept: application/vnd.github+json" -H "User-Agent: lumina-studio-setup" "$1"
  fi
}

JSON="$(curl_api "$API" 2>/dev/null)" || {
  if [ "$DRY_RUN" = 1 ]; then
    say "  [error]    could not read $API"
    say "  [download] would download lumina-studio-<tag>-linux-x64.tar.gz from the $TAG release of $REPO into $TARGET"
    exit 0
  fi
  fail_network "no answer from $API"
}

# The asset URLs, without a JSON parser: one "browser_download_url" per line.
URLS="$(printf '%s' "$JSON" | tr ',' '\n' | sed -n 's/.*"browser_download_url"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
TARBALL_URL="$(printf '%s\n' "$URLS" | grep -E '/lumina-studio-[^/]+-linux-x64\.tar\.gz$' | head -n1 || true)"
RELEASE_TAG="$(printf '%s' "$JSON" | tr ',' '\n' | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)"
if [ -z "$TARBALL_URL" ]; then
  if [ "$DRY_RUN" = 1 ]; then
    say "  [error]    release ${RELEASE_TAG:-$TAG} of $REPO has no lumina-studio-*-linux-x64.tar.gz"
    exit 0
  fi
  fail_network "release ${RELEASE_TAG:-$TAG} of $REPO has no lumina-studio-*-linux-x64.tar.gz"
fi
SUM_URL="$(printf '%s\n' "$URLS" | grep -F "$(basename "$TARBALL_URL").sha256" | head -n1 || true)"
NAME="$(basename "$TARBALL_URL")"

if [ "$DRY_RUN" = 1 ]; then
  say "  [download] $NAME (release $RELEASE_TAG)"
  say "             $TARBALL_URL"
  [ -n "$SUM_URL" ] && say "             checked against $(basename "$SUM_URL")"
  say "             unpacked into $TARGET"
  exit 0
fi

PARENT="$(dirname "$TARGET")"
mkdir -p "$PARENT"
WORK="$(mktemp -d "$PARENT/.lumina-studio-download.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT INT TERM

say "Downloading $NAME (release $RELEASE_TAG)..."
curl -fL --connect-timeout 20 --retry 3 --retry-delay 5 -o "$WORK/$NAME" "$TARBALL_URL" \
  || fail_network "download of $TARBALL_URL failed"
if [ -n "$SUM_URL" ]; then
  curl -fsSL --connect-timeout 20 --retry 3 -o "$WORK/$NAME.sha256" "$SUM_URL" \
    || fail_network "download of $SUM_URL failed"
  expected="$(cut -d' ' -f1 < "$WORK/$NAME.sha256")"
  actual="$(sha256sum "$WORK/$NAME" | cut -d' ' -f1)"
  if [ "$expected" != "$actual" ]; then
    say "SHA-256 mismatch for $NAME: expected $expected, got $actual." >&2
    exit 30
  fi
  say "SHA-256 verified."
else
  say "Warning: the release has no $NAME.sha256; not verified." >&2
fi

mkdir "$WORK/studio"
tar -xzf "$WORK/$NAME" -C "$WORK/studio"
[ -x "$WORK/studio/lumina_ui" ] || { say "$NAME has no lumina_ui executable." >&2; exit 1; }
printf 'tag=%s\nasset=%s\nrepository=%s\n' "$RELEASE_TAG" "$NAME" "$REPO" > "$WORK/studio/.lumina-release"
# A shared folder (/opt/lumina, setgid group "lumina"): keep it updatable by
# every member of the group.
if [ -g "$PARENT" ]; then
  chmod -R g+rwX "$WORK/studio"
fi

# Swap the new folder in.
if [ -e "$TARGET" ]; then
  mv "$TARGET" "$WORK/previous"
fi
mv "$WORK/studio" "$TARGET"
say "Lumina Studio $RELEASE_TAG installed in $TARGET."

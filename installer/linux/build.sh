#!/usr/bin/env bash
# Builds the lumina-studio .deb and .rpm with nfpm.
#
#   installer/linux/build.sh <version> [<tag>] [<out-dir>] [x64|arm64]
#   installer/linux/build.sh 0.1.0 v0.1.0 dist
#
# The architecture defaults to the host's; it names the packages (amd64 /
# x86_64, or arm64 / aarch64) and which nfpm release is downloaded.
#
# Uses `nfpm` from PATH, or downloads the pinned release below into
# build/nfpm/ (checksum-verified). Writes a .sha256 sidecar per package.
set -euo pipefail

VERSION="${1:?usage: build.sh <version> [<tag>] [<out-dir>] [x64|arm64]}"
TAG="${2:-v$VERSION}"
OUT="${3:-dist}"
ARCH="${4:-}"
NFPM_VERSION=2.47.0
if [ -z "$ARCH" ]; then
  case "$(uname -m)" in aarch64 | arm64) ARCH=arm64 ;; *) ARCH=x64 ;; esac
fi
case "$ARCH" in
  x64) DEB_ARCH=amd64; NFPM_ARCH=x86_64 ;;
  arm64) DEB_ARCH=arm64; NFPM_ARCH=arm64 ;;
  *) echo "unknown architecture $ARCH (x64|arm64)" >&2; exit 64 ;;
esac

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"

nfpm_bin="$(command -v nfpm || true)"
if [ -z "$nfpm_bin" ]; then
  dir="$ROOT/build/nfpm/$NFPM_VERSION-$NFPM_ARCH"
  nfpm_bin="$dir/nfpm"
  if [ ! -x "$nfpm_bin" ]; then
    mkdir -p "$dir"
    base="https://github.com/goreleaser/nfpm/releases/download/v$NFPM_VERSION"
    archive="nfpm_${NFPM_VERSION}_Linux_${NFPM_ARCH}.tar.gz"
    curl -fsSL -o "$dir/$archive" "$base/$archive"
    curl -fsSL -o "$dir/checksums.txt" "$base/checksums.txt"
    (cd "$dir" && grep " $archive\$" checksums.txt | sha256sum -c -)
    tar -xzf "$dir/$archive" -C "$dir" nfpm
  fi
fi
"$nfpm_bin" --version | head -n1

cd "$ROOT"
# Shell syntax of the scripts the package runs.
for s in installer/linux/lumina-studio installer/linux/install-studio.sh installer/linux/scripts/*.sh; do
  sh -n "$s"
done

export LUMINA_VERSION="$VERSION"
export LUMINA_ARCH="$DEB_ARCH"
for packager in deb rpm; do
  "$nfpm_bin" package --config installer/linux/nfpm.yaml --packager "$packager" --target "$OUT/"
done

cd "$OUT"
for f in lumina-studio*.deb lumina-studio*.rpm; do
  sha256sum "$f" > "$f.sha256"
  echo "Built $OUT/$f ($TAG, $ARCH)"
done

#!/usr/bin/env bash
# Unpacks a prebuilt Filament archive (filament-<VERSION>-<os>-x64.{zip|tar.gz})
# into <dest> so that <dest> is a folder the native-assets hooks accept as
# `filament_dir` (headers, android/gradle.properties, out/cmake-release*/).
# An archive holding a single top-level folder is unwrapped.
#
#   extract_filament.sh <archive> <dest>
set -euo pipefail
archive="$1"
dest="$2"

if [ -f "$dest/android/gradle.properties" ]; then
  echo "$dest already holds a Filament tree; nothing to unpack."
  exit 0
fi
if [ ! -f "$archive" ]; then
  echo "::error::No Filament archive at $archive." >&2
  exit 1
fi
if [ -f "$archive.sha256" ]; then
  (cd "$(dirname "$archive")" && sha256sum -c "$(basename "$archive").sha256")
fi

# Next to <dest>: the final move is a rename on the same volume.
mkdir -p "$(dirname "$dest")"
tmp="$(mktemp -d "$(dirname "$dest")/.filament-unpack.XXXXXX")"
case "$archive" in
  *.zip)
    if command -v 7z >/dev/null 2>&1; then 7z x -bso0 -bsp0 -o"$tmp" "$archive"; else unzip -q "$archive" -d "$tmp"; fi ;;
  *.tar.gz | *.tgz) tar -xzf "$archive" -C "$tmp" ;;
  *) echo "::error::Unknown archive type: $archive" >&2; exit 1 ;;
esac

root="$tmp"
entries=("$tmp"/*)
if [ "${#entries[@]}" -eq 1 ] && [ -d "${entries[0]}" ]; then
  root="${entries[0]}"
fi
if [ ! -f "$root/android/gradle.properties" ]; then
  echo "::error::$archive is not a Filament tree (no android/gradle.properties)." >&2
  exit 1
fi
rm -rf "$dest"
mv "$root" "$dest"
rm -rf "$tmp"
ls "$dest/out"

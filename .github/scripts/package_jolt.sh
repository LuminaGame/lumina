#!/usr/bin/env bash
# Packs the Jolt Physics build that flutter_jolt's tool/build_jolt.{sh,bat}
# made into the release asset an installed Lumina Studio links into its
# engine checkout as `jolt/` (JoltPrebuilt in
# lumina_core/lib/src/services/jolt_prebuilt.dart), plus its .sha256 sidecar.
# A flutter_jolt resolved from git (the pub cache) has no Jolt build; the
# root pubspec's `jolt_dir` user-define names the checkout's `jolt`, which
# the bootstrap links to this archive's folder.
#
#   package_jolt.sh windows     <flutter_jolt dir> <out-dir>   # jolt-windows-x64.zip
#   package_jolt.sh linux       <flutter_jolt dir> <out-dir>   # jolt-linux-x64.tar.gz
#   package_jolt.sh linux-arm64 <flutter_jolt dir> <out-dir>   # jolt-linux-arm64.tar.gz
#
# The archive holds one folder, jolt-<os>-<arch>, with include/Jolt/...,
# lib/<library>, jolt_defines.txt, VERSION, the Jolt LICENSE and
# lumina-jolt.json: the layout the hook reads.
set -euo pipefail
os="$1"
pkg="$2"
out="$3"

case "$os" in
  windows) lib=Jolt.lib; ext=zip ;;
  linux | linux-arm64 | macos | macos-arm64) lib=libJolt.a; ext=tar.gz ;;
  *)
    echo "Unknown platform $os (windows|linux|linux-arm64|macos|macos-arm64)" >&2
    exit 64
    ;;
esac
src="$pkg/third_party/jolt"
for f in "lib/$lib" jolt_defines.txt VERSION include/Jolt/Jolt.h; do
  if [ ! -f "$src/$f" ]; then
    echo "::error::No $src/$f: run tool/build_jolt.* in $pkg first." >&2
    exit 1
  fi
done

case "$os" in
  linux-arm64 | macos-arm64) platform="$os" ;;
  *) platform="$os-x64" ;;
esac
folder="jolt-$platform"
name="$folder.$ext"
mkdir -p "$out"
out="$(cd "$out" && pwd)"
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage/$folder/lib"
cp "$src/lib/$lib" "$stage/$folder/lib/$lib"
cp -r "$src/include" "$stage/$folder/include"
cp "$src/jolt_defines.txt" "$src/VERSION" "$stage/$folder/"
if [ -f "$src/src/LICENSE" ]; then cp "$src/src/LICENSE" "$stage/$folder/LICENSE"; fi
tag="$(awk '$1 == "tag" { print $2 }' "$src/VERSION")"
commit="$(git -C "$pkg" rev-parse HEAD 2>/dev/null || echo unknown)"
cat > "$stage/$folder/lumina-jolt.json" <<EOF
{
  "platform": "$platform",
  "library": "lib/$lib",
  "joltVersion": "$tag",
  "toolsCommit": "$commit"
}
EOF

rm -f "$out/$name"
case "$os" in
  windows)
    # System32's bsdtar writes zip (-a picks the format from the suffix); a
    # Git-for-Windows GNU tar on PATH cannot.
    (cd "$stage" && /c/Windows/System32/tar.exe -a -c -f "$name" "$folder")
    mv "$stage/$name" "$out/$name"
    ;;
  linux | linux-arm64 | macos | macos-arm64)
    tar -C "$stage" -czf "$out/$name" "$folder"
    ;;
esac

sha256_line() { if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1"; else shasum -a 256 "$1"; fi; }
(cd "$out" && sha256_line "$name" > "$name.sha256" && cat "$name.sha256")

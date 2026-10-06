#!/usr/bin/env bash
# Packs the OpenRigLogic static library that flutter_riglogic's
# tool/build_openriglogic.{sh,bat} built into the release asset an installed
# Lumina Studio links into its engine checkout (OpenRigLogicPrebuilt in
# lumina/lib/data/services/openriglogic_prebuilt.dart), plus its .sha256
# sidecar. A flutter_riglogic resolved from git (the pub cache) has no built
# library; the root pubspec's `riglogic_lib_dir` names the checkout's
# `openriglogic/lib`, which the bootstrap links to this archive's folder.
#
#   package_openriglogic.sh windows <flutter_riglogic dir> <out-dir>   # openriglogic-windows-x64.zip
#   package_openriglogic.sh linux   <flutter_riglogic dir> <out-dir>   # openriglogic-linux-x64.tar.gz
#   package_openriglogic.sh linux-arm64 <flutter_riglogic dir> <out-dir>   # openriglogic-linux-arm64.tar.gz
#
# The archive holds one folder, openriglogic-<os>-x64, with lib/<library>,
# the OpenRigLogic LICENSE and lumina-openriglogic.json.
set -euo pipefail
os="$1"
pkg="$2"
out="$3"

case "$os" in
  windows) lib=riglogic.lib; ext=zip ;;
  linux | linux-arm64) lib=libriglogic.a; ext=tar.gz ;;
  *)
    echo "Unknown platform $os (windows|linux|linux-arm64)" >&2
    exit 64
    ;;
esac
src="$pkg/third_party/openriglogic"
if [ ! -f "$src/lib/$lib" ]; then
  echo "::error::No $src/lib/$lib: run tool/build_openriglogic.* in $pkg first." >&2
  exit 1
fi

case "$os" in
  linux-arm64) platform=linux-arm64 ;;
  *) platform="$os-x64" ;;
esac
folder="openriglogic-$platform"
name="$folder.$ext"
mkdir -p "$out"
out="$(cd "$out" && pwd)"
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage/$folder/lib"
cp "$src/lib/$lib" "$stage/$folder/lib/$lib"
cp "$src/LICENSE" "$stage/$folder/LICENSE"
version="$(sed -n 's/^set(RL_VERSION \([^)]*\)).*/\1/p' "$src/CMakeLists.txt" | head -n1)"
commit="$(git -C "$pkg" rev-parse HEAD 2>/dev/null || echo unknown)"
cat > "$stage/$folder/lumina-openriglogic.json" <<EOF
{
  "platform": "$platform",
  "library": "lib/$lib",
  "rigLogicVersion": "$version",
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
  linux | linux-arm64)
    tar -C "$stage" -czf "$out/$name" "$folder"
    ;;
esac

(cd "$out" && sha256sum "$name" > "$name.sha256" && cat "$name.sha256")

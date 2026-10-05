#!/usr/bin/env bash
# Builds Lumina's prebuilt Filament for Linux x64 (macOS prepared, disabled):
# upstream google/filament at the tag tool/filament/VERSION names, plus
# third_party/filament/patches, built with clang against the bundled libc++
# (flutter_filament/third_party/libcxx), then pruned to what the native-assets
# hooks read and packed.
#
#   tool/filament/build_prebuilt.sh [--skip-build] [--out <dir>] [<work-dir>]
#
# <work-dir>   Filament checkout + build tree (default: $LUMINA_FILAMENT_WORK,
#              else build/filament-src under the repo root). Reused across runs:
#              the clone, the patch state and the ninja tree are incremental.
# --out        archive folder (default: build/filament-prebuilt).
# --skip-build package an existing build only.
#
# Environment: CC / CXX (default clang / clang++, which must match the bundled
# libc++ 21 headers: clang 19 or newer), LUMINA_LIBCXX_DIR (the bundled libc++),
# LUMINA_FILAMENT_UPSTREAM (clone URL), LUMINA_ENABLE_MACOS=1 (macOS branch),
# JOBS (ninja -j).
#
# Writes <out>/filament-<VERSION>-<os>-x64.tar.gz and a .sha256 sidecar
# (sha256sum format). The archive holds one folder, filament-<VERSION>-<os>-x64,
# that works as the hooks' filament_dir.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$REPO/tool/filament/VERSION")"
TAG="v${VERSION%%-*}"
UPSTREAM="${LUMINA_FILAMENT_UPSTREAM:-https://github.com/google/filament.git}"
SKIP_BUILD=0
OUT_DIR="$REPO/build/filament-prebuilt"
WORK="${LUMINA_FILAMENT_WORK:-$REPO/build/filament-src}"
while [ $# -gt 0 ]; do
  case "$1" in
    --skip-build) SKIP_BUILD=1 ;;
    --out) OUT_DIR="$2"; shift ;;
    -h|--help) sed -n '2,23p' "$0"; exit 0 ;;
    -*) echo "unknown option: $1" >&2; exit 2 ;;
    *) WORK="$1" ;;
  esac
  shift
done
mkdir -p "$OUT_DIR" "$(dirname "$WORK")"
WORK="$(cd "$(dirname "$WORK")" && pwd)/$(basename "$WORK")"
OUT_DIR="$(cd "$OUT_DIR" && pwd)"
log() { echo "[$(date +%H:%M:%S)] $*"; }

case "$(uname -s)" in
  Linux) OS=linux ;;
  Darwin)
    OS=macos
    if [ "${LUMINA_ENABLE_MACOS:-0}" != 1 ]; then
      echo "The macOS prebuilt is prepared but disabled; set LUMINA_ENABLE_MACOS=1 to try it." >&2
      exit 1
    fi ;;
  *) echo "unsupported host: $(uname -s) (use build_prebuilt.ps1 on Windows)" >&2; exit 1 ;;
esac
[ "$(uname -m)" = x86_64 ] || { echo "only x86_64 hosts are supported (got $(uname -m))" >&2; exit 1; }
BUILD_OUT=out/cmake-release
CC="${CC:-clang}"
CXX="${CXX:-clang++}"
LIBCXX="${LUMINA_LIBCXX_DIR:-$REPO/flutter_filament/third_party/libcxx}"

sha256() { if command -v sha256sum >/dev/null; then sha256sum "$1"; else shasum -a 256 "$1"; fi | cut -d' ' -f1; }

# --- 1. upstream checkout at the tag, with the patches applied -------------
GIT=(git -c core.autocrlf=false -c advice.detachedHead=false)
if [ ! -d "$WORK/.git" ]; then
  log "cloning $UPSTREAM $TAG -> $WORK"
  "${GIT[@]}" clone --depth 1 --branch "$TAG" --config core.autocrlf=false "$UPSTREAM" "$WORK"
fi
if [ "$(git -C "$WORK" describe --tags --exact-match HEAD 2>/dev/null || true)" != "$TAG" ]; then
  log "fetching $TAG"
  "${GIT[@]}" -C "$WORK" fetch --depth 1 origin tag "$TAG"
  "${GIT[@]}" -C "$WORK" checkout -f "$TAG"
  # The forced checkout dropped the applied patches; forget the stamp so they
  # are applied again on the new tag.
  rm -f "$WORK/.lumina-patches"
fi
UPSTREAM_COMMIT="$(git -C "$WORK" rev-parse HEAD)"
PATCHES=("$REPO"/third_party/filament/patches/*.patch)
STAMP=""
for p in "${PATCHES[@]}"; do STAMP+="$(basename "$p") $(sha256 "$p")"$'\n'; done
if [ "$(cat "$WORK/.lumina-patches" 2>/dev/null || true)"$'\n' != "$STAMP" ]; then
  log "applying ${#PATCHES[@]} patches"
  # Back to the pristine tag (tracked files only: out/ survives).
  "${GIT[@]}" -C "$WORK" reset -q --hard HEAD
  "${GIT[@]}" -C "$WORK" apply --check "${PATCHES[@]}"
  "${GIT[@]}" -C "$WORK" apply "${PATCHES[@]}"
  printf '%s' "${STAMP%$'\n'}" > "$WORK/.lumina-patches"
else
  log "patches already applied"
fi

# --- 2. the manifest: what the hooks read ----------------------------------
# Lines: <platforms> <kind> <path> [<built-from>]
ENTRIES=()
while read -r platforms kind path from; do
  case "$platforms" in ''|\#*) continue ;; esac
  [ "$platforms" = all ] || [[ ",$platforms," == *",$OS,"* ]] || continue
  ENTRIES+=("$kind $path ${from:-}")
done < "$REPO/tool/filament/prebuilt_manifest.txt"
TARGETS=()
for e in "${ENTRIES[@]}"; do
  read -r kind path from <<<"$e"
  built=""
  case "$kind" in file) built="$path" ;; tool) built="$from" ;; esac
  if [[ "$built" == "$BUILD_OUT/"* ]]; then TARGETS+=("${built#"$BUILD_OUT/"}"); fi
done

# --- 3. configure + build only the libraries and tools the archive carries -
CMAKE_ARGS=(
  -G Ninja
  -DCMAKE_BUILD_TYPE=Release
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5
  -DFILAMENT_BUILD_TESTING=OFF
  -DFILAMENT_SUPPORTS_VULKAN=ON
  -DFILAMENT_SUPPORTS_OPENGL=ON
  -DFILAMENT_BUILD_FILAMAT=ON
  -DFILAMENT_ENABLE_MATDBG=OFF
  -DFILAMENT_SUPPORTS_WEBP_TEXTURES=ON
  -DFILAMENT_ENABLE_EXCEPTIONS=ON
)
if [ "$OS" = linux ]; then
  # The system clang has no libc++ headers; Filament links libc++ statically
  # (USE_STATIC_LIBCXX), and the hooks link the same bundled libc++.
  [ -d "$LIBCXX/usr/lib/llvm-21/include/c++/v1" ] || { echo "bundled libc++ not found at $LIBCXX" >&2; exit 1; }
  CXX_FLAGS="-nostdinc++ -Wno-unused-command-line-argument -isystem $LIBCXX/usr/lib/llvm-21/include/c++/v1 -isystem $LIBCXX/usr/lib/llvm-21/include"
  LINK_FLAGS="-L$LIBCXX/usr/lib/x86_64-linux-gnu"
  CMAKE_ARGS+=(
    "-DCMAKE_C_COMPILER=$CC" "-DCMAKE_CXX_COMPILER=$CXX"
    "-DCMAKE_CXX_FLAGS=$CXX_FLAGS"
    "-DCMAKE_EXE_LINKER_FLAGS=$LINK_FLAGS" "-DCMAKE_SHARED_LINKER_FLAGS=$LINK_FLAGS"
  )
else
  CMAKE_ARGS+=(-DCMAKE_OSX_ARCHITECTURES=x86_64)
fi
if [ "$SKIP_BUILD" = 0 ]; then
  started=$(date +%s)
  if [ ! -f "$WORK/$BUILD_OUT/build.ninja" ]; then
    log "configuring $WORK/$BUILD_OUT"
    cmake -S "$WORK" -B "$WORK/$BUILD_OUT" "${CMAKE_ARGS[@]}"
  fi
  log "building ${#TARGETS[@]} targets"
  ninja -C "$WORK/$BUILD_OUT" ${JOBS:+-j "$JOBS"} "${TARGETS[@]}"
  log "build finished in $(( ($(date +%s) - started) / 60 )) min"
fi

# --- 4. stage the pruned tree ----------------------------------------------
NAME="filament-$VERSION-$OS-x64"
STAGE_ROOT="$OUT_DIR/stage"
STAGE="$STAGE_ROOT/$NAME"
rm -rf "$STAGE_ROOT"
mkdir -p "$STAGE/lumina/patches"
LIST="$(mktemp)"
trap 'rm -f "$LIST"' EXIT
for e in "${ENTRIES[@]}"; do
  read -r kind path from <<<"$e"
  case "$kind" in
    file)
      [ -f "$WORK/$path" ] || { echo "missing: $path" >&2; exit 1; }
      echo "$path" >> "$LIST" ;;
    dir)
      [ -d "$WORK/$path" ] || { echo "missing: $path" >&2; exit 1; }
      (cd "$WORK" && find "$path" -type f \( -name '*.h' -o -name '*.hh' -o -name '*.hpp' -o -name '*.hxx' \
        -o -name '*.inl' -o -name '*.inc' -o -name '*.ipp' -o -name '*.tcc' -o -name '*.def' \)) >> "$LIST" ;;
    tool)
      [ -f "$WORK/$from" ] || { echo "missing: $from" >&2; exit 1; }
      mkdir -p "$STAGE/$(dirname "$path")"
      cp "$WORK/$from" "$STAGE/$path"
      chmod +x "$STAGE/$path" ;;
  esac
done
sort -u "$LIST" -o "$LIST"
(cd "$WORK" && tar -cf - -T "$LIST") | (cd "$STAGE" && tar -xf -)
cp "${PATCHES[@]}" "$STAGE/lumina/patches/"

# Provenance: what this archive is and how it was built.
json_str() { local s="${1//\\/\\\\}"; s="${s//\"/\\\"}"; printf '"%s"' "$s"; }
{
  echo '{'
  echo "  \"version\": $(json_str "$VERSION"),"
  echo "  \"platform\": \"$OS-x64\","
  echo '  "upstream": {'
  echo '    "repository": "https://github.com/google/filament",'
  echo "    \"tag\": \"$TAG\","
  echo "    \"commit\": \"$UPSTREAM_COMMIT\""
  echo '  },'
  echo '  "patches": ['
  n=0
  for p in "${PATCHES[@]}"; do
    n=$((n + 1)); sep=$([ $n -lt ${#PATCHES[@]} ] && echo , || true)
    echo "    { \"name\": \"$(basename "$p")\", \"sha256\": \"$(sha256 "$p")\" }$sep"
  done
  echo '  ],'
  echo '  "build": {'
  echo "    \"directory\": \"$BUILD_OUT\","
  printf '    "cmake": ['
  n=0
  for a in "${CMAKE_ARGS[@]}"; do
    n=$((n + 1)); [ $n -gt 1 ] && printf ', '
    json_str "${a//$LIBCXX/<libcxx>}"
  done
  echo '],'
  echo "    \"compiler\": $(json_str "$("$CXX" --version | head -1)")"
  echo '  }'
  echo '}'
} > "$STAGE/lumina-filament.json"

# --- 5. archive + checksum -------------------------------------------------
ARCHIVE="$OUT_DIR/$NAME.tar.gz"
log "packing $(wc -l < "$LIST") files -> $ARCHIVE"
tar -C "$STAGE_ROOT" -czf "$ARCHIVE" "$NAME"
HASH="$(sha256 "$ARCHIVE")"
printf '%s  %s\n' "$HASH" "$NAME.tar.gz" > "$ARCHIVE.sha256"
rm -rf "$STAGE_ROOT"
log "$ARCHIVE ($(du -h "$ARCHIVE" | cut -f1)) sha256 $HASH"

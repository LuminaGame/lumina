#!/usr/bin/env bash
# Builds the vendored Filament (../filament, with its carried patches) for the
# web: WebAssembly, WebGL2 backend, single-threaded, Release, WebP textures on
# (glTF assets here use EXT_texture_webp; needs the vendored libwebp tnt patch).
#
# Mirrors filament/build.sh's `build_wasm_with_target`, but imports the host
# tools (matc, resgen, cmgen, …) from out/prebuilt-tools-release instead of
# relinking them in out/cmake-release, which cannot link executables on the
# development machine (its system clang has no libc++ headers).
#
# Output: filament/out/cmake-wasm-release (static libraries + filament-js).
# Requires emsdk (see tool/web/README.md); EMSDK defaults to ~/emsdk.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
filament="$(cd "${here}/../../../filament" && pwd)"
EMSDK="${EMSDK:-$HOME/emsdk}"
prebuilt="${filament}/out/prebuilt-tools-release"
out="${filament}/out/cmake-wasm-release"

if [[ ! -f "${EMSDK}/emsdk_env.sh" ]]; then
  echo "emsdk not found at ${EMSDK} (see tool/web/README.md)" >&2
  exit 1
fi
if [[ ! -f "${prebuilt}/ImportExecutables-Prebuilt.cmake" ]]; then
  echo "host tools missing: ${prebuilt} (build them with filament/build.sh first)" >&2
  exit 1
fi

# shellcheck disable=SC1091
source "${EMSDK}/emsdk_env.sh" > /dev/null
mkdir -p "${out}"
cd "${out}"
# Configure every time (cheap when nothing changed) so option edits apply.
cmake \
    -G Ninja \
    -DCMAKE_TOOLCHAIN_FILE="${EMSDK}/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="../wasm-release/filament" \
    -DWASM=1 \
    -DFILAMENT_SUPPORTS_WEBGPU=OFF \
    -DFILAMENT_DEBUG_MUTEX=OFF \
    -DFILAMENT_IMPORT_PREBUILT_EXECUTABLES_DIR=out/prebuilt-tools-release \
    -DFILAMENT_SUPPORTS_WEBP_TEXTURES=ON \
    "${filament}" > /dev/null
ninja "$@"

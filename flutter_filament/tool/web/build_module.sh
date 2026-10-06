#!/usr/bin/env bash
# Builds web/flutter_filament.{js,wasm}: flutter_filament's C wrapper
# (src/*_c.cpp, the filament_* ABI the Dart bindings call) linked against the
# WebAssembly build of the vendored Filament (tool/web/build_filament_web.sh).
#
# The source and include lists are read from hook/build.dart and the exported
# symbols from the ffigen output, so the web module stays in lockstep with the
# desktop library. Single-threaded, WebGL2, growable heap and function table.
#   tool/web/build_module.sh            # release (-O3)
#   OPT=-O1 tool/web/build_module.sh    # faster iteration
# LUMINA_FILAMENT_SRC names the Filament source tree holding
# out/cmake-wasm-release (default: the repository's ../filament link).
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
pkg="$(cd "${here}/../.." && pwd)"
filament="${LUMINA_FILAMENT_SRC:-$(cd "${pkg}/../filament" && pwd)}"
wasm="${filament}/out/cmake-wasm-release"
EMSDK="${EMSDK:-$HOME/emsdk}"
OPT="${OPT:--O3}"
obj="${pkg}/build/web_module/obj"

[[ -d "${wasm}/filament" ]] || { echo "run tool/web/build_filament_web.sh first" >&2; exit 1; }
# shellcheck disable=SC1091
source "${EMSDK}/emsdk_env.sh" > /dev/null
cd "${pkg}"
mkdir -p "${obj}" web

# --- lockstep inputs --------------------------------------------------------
# hook/build.dart lists the C wrapper sources (`src/*_c.cpp`), smol-v from the
# Filament tree and the vendored matp parser (`third_party/filament_matp/`).
# matp serves the runtime material compiler, which the web stubs replace
# (filamat is not part of Filament's WebAssembly build), so it stays out.
mapfile -t sources < <(grep -oE "'(src/[a-z0-9_]+\.cpp|[$]filament/third_party/smol-v/source/smolv\.cpp)'" hook/build.dart | tr -d "'" |
  sed -e 's#^[$]filament#'"${filament}"'#')
# The include list names Filament paths as `$filament/...` and the desktop
# build folder as `$filament/out/$filamentOut`; both are re-rooted at the
# Filament source tree in use and its WebAssembly build folder.
mapfile -t includes < <(sed -n '/final includes = \[/,/^    \];/p' hook/build.dart | grep -oE "'[^']+'" | tr -d "'" |
  sed -e 's#^[$]filament/out/[$]filamentOut#'"${filament}"'/out/cmake-wasm-release#' \
      -e 's#^[$]filament#'"${filament}"'#')
(( ${#sources[@]} > 0 )) || { echo "no sources found in hook/build.dart" >&2; exit 1; }
(( ${#includes[@]} > 0 )) || { echo "no include list found in hook/build.dart" >&2; exit 1; }
# The Filament version the module is built against (bare; the C
# wrapper stringizes it), from the file bump-version.sh treats as primary.
filament_version="$(sed -n 's/^VERSION_NAME=//p' "${filament}/android/gradle.properties" | tr -d '\r')"
[[ -n "${filament_version}" ]] || { echo "no VERSION_NAME in ${filament}/android/gradle.properties" >&2; exit 1; }
node tool/web/exported_symbols.mjs "${obj}/exports.json" > /dev/null

cflags=(-std=c++20 -fexceptions -fno-rtti -Wno-deprecated-declarations -DNDEBUG "${OPT}"
  "-DFLUTTER_FILAMENT_FILAMENT_VERSION=${filament_version}")
for inc in "${includes[@]}"; do cflags+=(-I"${inc}"); done

# --- compile (parallel, incremental; every failure is reported) --------------
objects=()
failed=()
pids=()
for src in "${sources[@]}"; do
  out="${obj}/$(echo "${src}" | tr '/.' '__').o"
  objects+=("${out}")
  if [[ ! -f "${out}" || "${src}" -nt "${out}" || "${src%.cpp}.h" -nt "${out}" ]]; then
    ( em++ "${cflags[@]}" -c "${src}" -o "${out}" 2> "${out}.log" || { rm -f "${out}"; exit 1; } ) &
    pids+=("$!:${src}")
  fi
  # Keep at most 8 compiles in flight.
  while (( $(jobs -rp | wc -l) >= 8 )); do sleep 0.2; done
done
for entry in "${pids[@]}"; do
  wait "${entry%%:*}" || failed+=("${entry#*:}")
done
if (( ${#failed[@]} )); then
  for src in "${failed[@]}"; do
    echo "=== ${src}" >&2
    grep -E "error:" "${obj}/$(echo "${src}" | tr '/.' '__').o.log" | head -5 >&2
  done
  echo "${#failed[@]} source(s) failed to compile" >&2
  exit 1
fi

# --- link -----------------------------------------------------------------------
libs=(
  filament/libfilament.a filament/backend/libbackend.a libs/utils/libutils.a libs/math/libmath.a
  libs/filabridge/libfilabridge.a libs/filaflat/libfilaflat.a
  libs/gltfio/libgltfio_core.a libs/gltfio/libuberarchive.a libs/uberz/libuberzlib.a
  libs/camutils/libcamutils.a libs/geometry/libgeometry.a libs/filameshio/libfilameshio.a
  libs/ktxreader/libktxreader.a libs/image/libimage.a libs/ibl/libibl.a
  libs/iblprefilter/libfilament-iblprefilter.a shaders/libshaders.a
  third_party/draco/tnt/libdracodec.a third_party/basisu/tnt/libbasis_transcoder.a
  third_party/meshoptimizer/tnt/libmeshoptimizer.a third_party/mikktspace/libmikktspace.a
  third_party/zstd/tnt/libzstd.a third_party/smol-v/tnt/libsmol-v.a third_party/stb/tnt/libstb.a
  third_party/libwebp/libwebpdecoder.a
  third_party/abseil/tnt/libfilament-abseil.a
)
linkLibs=(); for l in "${libs[@]}"; do linkLibs+=("${wasm}/${l}"); done

em++ "${OPT}" -fexceptions -Wl,--error-limit=0 "${objects[@]}" "${linkLibs[@]}" \
  -s MODULARIZE=1 -s EXPORT_NAME=FlutterFilament \
  -s ALLOW_MEMORY_GROWTH=1 -s ALLOW_TABLE_GROWTH=1 \
  -s USE_WEBGL2=1 -s FULL_ES3=1 -s MIN_WEBGL_VERSION=2 -s MAX_WEBGL_VERSION=2 \
  -s EXPORTED_FUNCTIONS=@"${obj}/exports.json" \
  -s "EXPORTED_RUNTIME_METHODS=['HEAP8','HEAPU8','HEAP16','HEAPU16','HEAP32','HEAPU32','HEAPF32','HEAPF64','addFunction','removeFunction','UTF8ToString','stringToUTF8','lengthBytesUTF8','specialHTMLTargets']" \
  -o web/flutter_filament.js
ls -la web/flutter_filament.js web/flutter_filament.wasm

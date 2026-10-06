#!/usr/bin/env bash
# Builds Filament's host tools (matc, cmgen, filamesh, mipgen, resgen, uberz,
# glslminifier) natively and exports them as prebuilt executables into
# filament/out/prebuilt-tools-release, the folder build_filament_web.sh's
# WebAssembly configure imports (FILAMENT_IMPORT_PREBUILT_EXECUTABLES_DIR).
#
# Mirrors filament/build.sh's `build_tools_for_split_build`, with the same
# compiler setup as tool/filament/build_prebuilt.sh on Linux (clang against
# the bundled libc++ in flutter_filament/third_party/libcxx, since the system
# clang may have no libc++ headers).
#
#   tool/web/build_host_tools.sh
#
# Environment: LUMINA_FILAMENT_SRC (the Filament source tree; default: the
# repository's ../filament link), CC / CXX (default clang / clang++),
# LUMINA_LIBCXX_DIR (the bundled libc++), JOBS (ninja -j).
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
pkg="$(cd "${here}/../.." && pwd)"
filament="${LUMINA_FILAMENT_SRC:-$(cd "${pkg}/../filament" && pwd)}"
LIBCXX="${LUMINA_LIBCXX_DIR:-${pkg}/third_party/libcxx}"
CC="${CC:-clang}"
CXX="${CXX:-clang++}"
out="${filament}/out/prebuilt-tools-release"
tools=(matc cmgen filamesh mipgen resgen uberz glslminifier)

[[ -f "${filament}/CMakeLists.txt" && -f "${filament}/build.sh" ]] || {
  echo "not a Filament source tree: ${filament} (set LUMINA_FILAMENT_SRC)" >&2
  exit 1
}

args=(
  -G Ninja
  -DCMAKE_BUILD_TYPE=Release
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5
  -DFILAMENT_EXPORT_PREBUILT_EXECUTABLES_DIR=out/prebuilt-tools-release
  -DFILAMENT_ENABLE_EXCEPTIONS=ON
  -DFILAMENT_BUILD_TESTING=OFF
  -DFILAMENT_SUPPORTS_WEBP_TEXTURES=ON
)
if [[ "$(uname -s)" == Linux ]]; then
  [[ -d "${LIBCXX}/usr/lib/llvm-21/include/c++/v1" ]] || { echo "bundled libc++ not found at ${LIBCXX}" >&2; exit 1; }
  cxx_flags="-nostdinc++ -Wno-unused-command-line-argument -isystem ${LIBCXX}/usr/lib/llvm-21/include/c++/v1 -isystem ${LIBCXX}/usr/lib/llvm-21/include"
  link_flags="-L${LIBCXX}/usr/lib/x86_64-linux-gnu"
  args+=(
    "-DCMAKE_C_COMPILER=${CC}" "-DCMAKE_CXX_COMPILER=${CXX}"
    "-DCMAKE_CXX_FLAGS=${cxx_flags}"
    "-DCMAKE_EXE_LINKER_FLAGS=${link_flags}" "-DCMAKE_SHARED_LINKER_FLAGS=${link_flags}"
  )
fi

mkdir -p "${out}"
if [[ ! -f "${out}/build.ninja" ]]; then
  echo "configuring ${out}"
  cmake -S "${filament}" -B "${out}" "${args[@]}" > /dev/null
fi
ninja -C "${out}" ${JOBS:+-j "${JOBS}"} "${tools[@]}"
[[ -f "${out}/ImportExecutables-Prebuilt.cmake" ]] || {
  echo "the tools built but ${out}/ImportExecutables-Prebuilt.cmake was not exported" >&2
  exit 1
}
echo "host tools exported to ${out}"

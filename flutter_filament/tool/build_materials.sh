#!/usr/bin/env bash
# Recompiles every material listed in tool/materials.txt.
#
# Materials are compiled ahead of time on purpose. Building one at runtime with
# filamat::MaterialBuilder couples this plugin to filamat's ABI, and a
# checked-in package compiled for a different engine is refused at load time
# without failing anything — the engine logs a version mismatch and whatever
# used the material simply draws nothing.
#
# An output ending in `.h` is embedded as a C++ byte array; anything else is
# written as the compiled package itself.
set -euo pipefail
cd "$(dirname "$0")/.."

MATC="../filament/out/prebuilt-tools-release/tools/matc/matc"
[ -x "$MATC" ] || { echo "matc not found at $MATC" >&2; exit 1; }
# Sources under ../filament/ that the pruned prebuilt does not carry (the sky
# material lives in Filament's web examples) are looked up in a full source
# tree: $LUMINA_FILAMENT_SRC, then ../filament itself, then the checkout
# tool/filament/build_prebuilt.* keeps at ../build/filament-src.
resolve_source() {
  case "$1" in
    ../filament/*)
      local rel="${1#../filament/}" root
      for root in "${LUMINA_FILAMENT_SRC:-}" ../filament ../build/filament-src; do
        if [ -n "$root" ] && [ -f "$root/$rel" ]; then echo "$root/$rel"; return; fi
      done ;;
  esac
  echo "$1"
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
# python3, or python where that is the only working interpreter (Windows ships a
# `python3` Store stub that prints an install hint and fails).
PY=python3
"$PY" -c pass >/dev/null 2>&1 || PY=python

while IFS='|' read -r output source flags; do
  # tolerate CRLF line endings (a Windows checkout)
  flags="${flags//$'\r'/}"; source="${source//$'\r'/}"; output="${output//$'\r'/}"
  case "$output" in ''|\#*) continue ;; esac
  source="$(resolve_source "$source")"
  [ -f "$source" ] || { echo "material source missing: $source (set LUMINA_FILAMENT_SRC to a full Filament checkout)" >&2; exit 1; }
  # shellcheck disable=SC2086
  "$MATC" $flags -o "$TMP/out.filamat" "$source"
  case "$output" in
    *.h) "$PY" tool/embed_material.py "$TMP/out.filamat" "$output" ;;
    *)   mkdir -p "$(dirname "$output")"; cp "$TMP/out.filamat" "$output"
         echo "wrote $output ($(stat -c%s "$output") bytes)" ;;
  esac
done < tool/materials.txt

echo "materials up to date"

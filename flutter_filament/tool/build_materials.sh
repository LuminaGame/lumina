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

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

while IFS='|' read -r output source flags; do
  case "$output" in ''|\#*) continue ;; esac
  [ -f "$source" ] || { echo "material source missing: $source" >&2; exit 1; }
  # shellcheck disable=SC2086
  "$MATC" $flags -o "$TMP/out.filamat" "$source"
  case "$output" in
    *.h) python3 tool/embed_material.py "$TMP/out.filamat" "$output" ;;
    *)   mkdir -p "$(dirname "$output")"; cp "$TMP/out.filamat" "$output"
         echo "wrote $output ($(stat -c%s "$output") bytes)" ;;
  esac
done < tool/materials.txt

echo "materials up to date"

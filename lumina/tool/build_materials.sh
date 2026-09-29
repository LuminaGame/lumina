#!/usr/bin/env bash
# Recompiles every material listed in tool/materials.txt.
#
# A checked-in package compiled for a different engine is refused at load time
# without failing anything: the engine logs a version mismatch and whatever
# used the material simply draws nothing. Both of this package's copies were
# stale at once, because
# neither had a source or a way to rebuild it.
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
  mkdir -p "$(dirname "$output")"
  cp "$TMP/out.filamat" "$output"
  echo "wrote $output ($(stat -c%s "$output") bytes)"
done < tool/materials.txt

echo "materials up to date"

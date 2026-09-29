#!/usr/bin/env bash
# Packs a Release build of Lumina Studio (lumina_ui) into the release asset
# and its .sha256 sidecar. The bundle's files sit at the archive root.
#
#   package_studio.sh windows <tag> <out-dir>   # lumina-studio-<tag>-windows-x64.zip
#   package_studio.sh linux   <tag> <out-dir>   # lumina-studio-<tag>-linux-x64.tar.gz
#
# Run from lumina_ui/ after `flutter build <os> --release`.
set -euo pipefail
os="$1"
tag="$2"
out="$3"
mkdir -p "$out"
out="$(cd "$out" && pwd)"

case "$os" in
  windows)
    bundle=build/windows/x64/runner/Release
    name="lumina-studio-$tag-windows-x64.zip"
    [ -f "$bundle/lumina_ui.exe" ] || { echo "::error::No $bundle/lumina_ui.exe" >&2; exit 1; }
    # The Visual C++ runtime next to the executable (app-local deployment), so
    # the zip also runs on a machine without the redistributable installed.
    for dll in msvcp140.dll vcruntime140.dll vcruntime140_1.dll; do
      src="/c/Windows/System32/$dll"
      if [ -f "$src" ] && [ ! -f "$bundle/$dll" ]; then cp "$src" "$bundle/"; fi
    done
    rm -f "$out/$name"
    if command -v 7z >/dev/null 2>&1; then
      (cd "$bundle" && 7z a -tzip -mx=7 -bso0 -bsp0 "$out/$name" .)
    else
      # No 7-Zip (a developer machine): the .NET zip writer.
      powershell.exe -NoProfile -NonInteractive -Command \
        "Add-Type -AssemblyName System.IO.Compression.FileSystem; [IO.Compression.ZipFile]::CreateFromDirectory('$(cygpath -w "$bundle")', '$(cygpath -w "$out/$name")', 'Optimal', \$false)"
    fi
    ;;
  linux)
    bundle=build/linux/x64/release/bundle
    name="lumina-studio-$tag-linux-x64.tar.gz"
    [ -f "$bundle/lumina_ui" ] || { echo "::error::No $bundle/lumina_ui" >&2; exit 1; }
    tar -C "$bundle" -czf "$out/$name" .
    ;;
  *)
    echo "Unknown OS $os (windows|linux)" >&2
    exit 64
    ;;
esac

(cd "$out" && sha256sum "$name" > "$name.sha256" && cat "$name.sha256")

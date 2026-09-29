#!/usr/bin/env bash
# Builds lumina-studio-<tag>-macos.pkg with pkgbuild + productbuild.
# NOT VERIFIED: macOS builds of Lumina Studio have never been run, and the
# release workflow's macOS job is disabled (see .github/workflows/release.yml).
#
#   installer/macos/build-pkg.sh <version> [<tag>] [<out-dir>]
#
# Like the Windows and Linux installers the package embeds no editor: its
# postinstall script checks the Xcode Command Line Tools, installs git, cmake,
# ninja and GStreamer with Homebrew, installs Flutter (stable) and downloads
# the latest Lumina Studio release into /Applications.
# Signing: set LUMINA_PKG_SIGN_IDENTITY to a "Developer ID Installer: …"
# identity in the keychain (notarization is a separate, later step).
set -euo pipefail

VERSION="${1:?usage: build-pkg.sh <version> [<tag>] [<out-dir>]}"
TAG="${2:-v$VERSION}"
OUT="${3:-dist}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# Payload: the launcher and the download script; postinstall fetches the editor.
mkdir -p "$work/root/usr/local/bin" "$work/root/usr/local/lib/lumina-studio" "$work/scripts"
cp "$HERE/lumina-studio" "$work/root/usr/local/bin/lumina-studio"
cp "$HERE/install-studio.sh" "$work/root/usr/local/lib/lumina-studio/install-studio.sh"
chmod 0755 "$work/root/usr/local/bin/lumina-studio" "$work/root/usr/local/lib/lumina-studio/install-studio.sh"
cp "$HERE/scripts/postinstall" "$work/scripts/postinstall"
chmod 0755 "$work/scripts/postinstall"

numeric="$(printf '%s' "$VERSION" | sed -E 's/^([0-9]+\.[0-9]+\.[0-9]+).*/\1/')"
pkgbuild --root "$work/root" --scripts "$work/scripts" \
  --identifier org.lumina.studio.installer --version "$numeric" \
  --install-location / "$work/lumina-studio-component.pkg"

sign=()
if [ -n "${LUMINA_PKG_SIGN_IDENTITY:-}" ]; then
  sign=(--sign "$LUMINA_PKG_SIGN_IDENTITY")
fi
name="lumina-studio-$TAG-macos.pkg"
productbuild --package "$work/lumina-studio-component.pkg" "${sign[@]}" "$OUT/$name"
(cd "$OUT" && shasum -a 256 "$name" > "$name.sha256")
echo "Built $OUT/$name"

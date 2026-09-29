#!/bin/sh
# lumina-studio preremove (deb: "remove" / "upgrade" / ...; rpm: 0 = erase,
# 1 = upgrade). On removal it deletes what postinstall and the launcher put
# into /opt/lumina: the downloaded editor and, when the package installed it,
# the Flutter SDK. Upgrades keep everything.
set -u

case "${1:-}" in
  remove | purge | 0) ;;
  *) exit 0 ;;
esac

ROOT=/opt/lumina
FLUTTER_DIR="$ROOT/flutter"

rm -rf "$ROOT/studio" "$ROOT"/.lumina-studio-download.*
if [ -f "$ROOT/.flutter-installed-by-lumina" ]; then
  rm -rf "$FLUTTER_DIR" "$FLUTTER_DIR.partial" "$ROOT/.flutter-installed-by-lumina"
  if command -v git >/dev/null 2>&1; then
    git config --system --unset-all safe.directory "^$FLUTTER_DIR\$" 2>/dev/null || true
  fi
fi
rmdir "$ROOT" 2>/dev/null || true
exit 0

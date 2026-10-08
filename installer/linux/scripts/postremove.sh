#!/bin/sh
# lumina-studio postremove (deb: "remove" / "purge" / ...; rpm: 0 = erase,
# 1 = upgrade). The "lumina" group goes with a purge (deb) or an erase (rpm).
# Per-user downloads (~/.local/share/lumina) belong to their users and stay.
set -u

# -- 3D model files: the MIME types and the .desktop entry's MimeType
# (dpkg / rpm triggers usually do this already; harmless twice)
refresh_desktop_databases() {
  if command -v update-mime-database >/dev/null 2>&1; then
    update-mime-database /usr/share/mime >/dev/null 2>&1 || true
  fi
  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database -q /usr/share/applications >/dev/null 2>&1 || true
  fi
}
refresh_desktop_databases

case "${1:-}" in
  purge | 0)
    if getent group lumina >/dev/null 2>&1; then
      groupdel lumina 2>/dev/null || true
    fi
    ;;
esac
exit 0

#!/bin/sh
# lumina-studio postremove (deb: "remove" / "purge" / ...; rpm: 0 = erase,
# 1 = upgrade). The "lumina" group goes with a purge (deb) or an erase (rpm).
# Per-user downloads (~/.local/share/lumina) belong to their users and stay.
set -u

case "${1:-}" in
  purge | 0)
    if getent group lumina >/dev/null 2>&1; then
      groupdel lumina 2>/dev/null || true
    fi
    ;;
esac
exit 0

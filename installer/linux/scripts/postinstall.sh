#!/bin/sh
# lumina-studio postinstall (deb: "configure"; rpm: 1 = install, 2 = upgrade).
#
# 1. The "lumina" group owns /opt/lumina (setgid, group-writable), so its
#    members can update the editor and use the shared Flutter SDK; the user
#    who ran the package manager (sudo / pkexec) is added to it.
# 2. Flutter: an SDK already in /opt/lumina/flutter or on PATH is kept;
#    otherwise the stable channel is cloned to /opt/lumina/flutter.
# 3. Lumina Studio: the latest release is downloaded to /opt/lumina/studio.
#
# Network problems never fail the installation: the launcher downloads the
# editor on its first run instead. LUMINA_SKIP_DOWNLOAD=1 skips steps 2 and 3.
set -u

case "${1:-}" in
  abort-*) exit 0 ;;
esac

ROOT=/opt/lumina
FLUTTER_DIR="$ROOT/flutter"
FLUTTER_MARK="$ROOT/.flutter-installed-by-lumina"
STUDIO_DIR="$ROOT/studio"
GROUP=lumina

say() { printf 'lumina-studio: %s\n' "$*"; }

# -- group and folder
if ! getent group "$GROUP" >/dev/null 2>&1; then
  groupadd --system "$GROUP" || say "could not create the $GROUP group."
fi
mkdir -p "$ROOT"
chgrp "$GROUP" "$ROOT" 2>/dev/null || true
chmod 2775 "$ROOT"

user="${SUDO_USER:-}"
if [ -z "$user" ] && [ -n "${PKEXEC_UID:-}" ]; then
  user="$(getent passwd "$PKEXEC_UID" | cut -d: -f1)"
fi
if [ -n "$user" ] && [ "$user" != root ] && getent passwd "$user" >/dev/null 2>&1; then
  if ! id -nG "$user" | tr ' ' '\n' | grep -qx "$GROUP"; then
    usermod -a -G "$GROUP" "$user" && say "added $user to the $GROUP group (takes effect at the next login)."
  fi
fi

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

share_with_group() {
  chgrp -R "$GROUP" "$1" 2>/dev/null || true
  chmod -R g+rwX "$1" 2>/dev/null || true
  find "$1" -type d -exec chmod g+s {} + 2>/dev/null || true
}

if [ "${LUMINA_SKIP_DOWNLOAD:-0}" = 1 ]; then
  say "LUMINA_SKIP_DOWNLOAD=1: Flutter and Lumina Studio are not downloaded now; run lumina-studio to download the editor."
  exit 0
fi

online=1
if ! curl -fsS --connect-timeout 15 --max-time 30 -o /dev/null https://api.github.com/ 2>/dev/null; then
  online=0
  say "GitHub is not reachable, so nothing is downloaded now."
  say "Lumina Studio downloads itself the first time you run lumina-studio."
  say "Install Flutter later with: sudo git clone --filter=blob:none -b stable https://github.com/flutter/flutter.git $FLUTTER_DIR"
fi

# -- Flutter
if [ "$online" = 1 ]; then
  if [ -x "$FLUTTER_DIR/bin/flutter" ]; then
    say "using the Flutter SDK in $FLUTTER_DIR."
  elif command -v flutter >/dev/null 2>&1; then
    say "using the Flutter SDK on PATH: $(command -v flutter)."
  else
    say "installing Flutter (stable) into $FLUTTER_DIR..."
    rm -rf "$FLUTTER_DIR.partial"
    if GIT_HTTP_LOW_SPEED_LIMIT=1000 GIT_HTTP_LOW_SPEED_TIME=60 \
        git clone --quiet --filter=blob:none --branch stable https://github.com/flutter/flutter.git "$FLUTTER_DIR.partial"; then
      mv "$FLUTTER_DIR.partial" "$FLUTTER_DIR"
      touch "$FLUTTER_MARK"
      # Members of the group run git in the SDK, which belongs to root.
      if ! git config --system --get-all safe.directory 2>/dev/null | grep -qx "$FLUTTER_DIR"; then
        git config --system --add safe.directory "$FLUTTER_DIR"
      fi
      # Download the Dart SDK and the Linux desktop artifacts once, as root,
      # then hand the tree to the group.
      "$FLUTTER_DIR/bin/flutter" --suppress-analytics precache --linux >/dev/null 2>&1 \
        || say "flutter precache failed; Flutter finishes its setup on first use."
      share_with_group "$FLUTTER_DIR"
      say "Flutter installed; /usr/bin/lumina-studio puts $FLUTTER_DIR/bin on PATH for the editor."
    else
      rm -rf "$FLUTTER_DIR.partial"
      say "cloning Flutter failed; install it later (see the command above) or put flutter on PATH."
    fi
  fi
fi

# -- clang version: the engine's native code needs clang 19 or newer.
if command -v clang >/dev/null 2>&1; then
  major="$(clang --version 2>/dev/null | sed -n 's/.*clang version \([0-9][0-9]*\).*/\1/p' | head -n1)"
  if [ -n "$major" ] && [ "$major" -lt 19 ]; then
    say "warning: clang $major is too old to build Lumina projects (19 or newer is needed; see https://apt.llvm.org)."
  fi
fi

# -- Lumina Studio
if [ "$online" = 1 ]; then
  if /usr/lib/lumina-studio/install-studio.sh --target "$STUDIO_DIR"; then
    share_with_group "$STUDIO_DIR"
  else
    say "Lumina Studio could not be downloaded now; it downloads itself the first time you run lumina-studio."
  fi
fi

exit 0

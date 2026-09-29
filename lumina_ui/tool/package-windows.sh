#!/usr/bin/env sh
# builds an MSIX package of Lumina Studio.
#
#   tool/package-windows.sh              # self-signed (the stable Lumina dev certificate)
#   tool/package-windows.sh --publish    # signed + timestamped with the certificate from the environment
#   tool/package-windows.sh --help       # all options
#
# A thin POSIX entry point (Git Bash on Windows, as tool/ci.sh); the logic is
# Dart (tool/package_windows.dart → lib/tooling/windows_packaging/).
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE/.."

needs_windows=1
for a in "$@"; do
  case "$a" in
    -h|--help|--dry-run) needs_windows=0 ;;
  esac
done

case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*|Windows_NT) ;;
  *)
    if [ "$needs_windows" = 1 ]; then
      echo "MSIX packages are built on Windows." >&2
      exit 2
    fi
    ;;
esac

exec dart run tool/package_windows.dart "$@"

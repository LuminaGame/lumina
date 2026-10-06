#!/usr/bin/env bash
# The prebuilt Filament's own GitHub release, filament-<VERSION>: published
# once per tool/filament/VERSION, so Lumina releases no longer carry the same
# archives again. A pre-release that is never "Latest"; once both archives
# and their .sha256 sidecars are uploaded it is never changed again.
#
#   filament_release.sh missing <tag> <version> [windows|linux|linux-arm64 ...]
#       Prints the assets of <tag> that are not complete yet, one per line:
#       both files of every archive/sidecar pair that is not fully uploaded
#       (all of them when the release does not exist). Default platforms:
#       windows, linux (x64) and linux-arm64. Exit 1 when GitHub cannot be asked.
#   filament_release.sh notes <version> <sha> <owner/repo>
#       Prints the release notes: version, upstream tag, commit, patches.
#   filament_release.sh publish <tag> <version> <sha> <dir>
#       Creates <tag> at <sha> when it does not exist (tolerating another run
#       creating it first) and uploads the missing pairs from <dir>, archive
#       first, never replacing a complete pair. What an interrupted upload
#       left of an incomplete pair is removed first. Fails unless the release
#       is complete afterwards.
#
# gh reads GH_TOKEN and GH_REPO from the environment.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"

# The platform keys: windows and linux are x64, linux-arm64 is the arm64 build.
archive_name() {
  case "$1" in
    windows) echo "filament-$2-windows-x64.zip" ;;
    linux | macos) echo "filament-$2-$1-x64.tar.gz" ;;
    linux-arm64) echo "filament-$2-linux-arm64.tar.gz" ;;
    *) echo "filament_release.sh: unknown platform $1" >&2; exit 64 ;;
  esac
}

# The release's asset names, one per line (only the fully uploaded ones
# unless $2 is "all"). Returns 3 when the release does not exist.
release_assets() {
  local tag="$1" which="${2:-uploaded}" jq out err
  if [ "$which" = all ]; then jq='.assets[].name'; else jq='.assets[] | select(.state == "uploaded") | .name'; fi
  err="$(mktemp)"
  if out="$(gh release view "$tag" --json assets --jq "$jq" 2>"$err")"; then
    rm -f "$err"
    [ -z "$out" ] || printf '%s\n' "$out"
    return 0
  fi
  if grep -qi 'release not found' "$err"; then
    rm -f "$err"
    return 3
  fi
  cat "$err" >&2
  rm -f "$err"
  return 1
}

has_line() { printf '%s\n' "$2" | grep -qxF -- "$1"; }

missing() {
  local tag="$1" version="$2"
  shift 2
  local oses=("$@") have="" rc=0 os a
  [ ${#oses[@]} -gt 0 ] || oses=(windows linux linux-arm64)
  have="$(release_assets "$tag")" || rc=$?
  if [ "$rc" -ne 0 ] && [ "$rc" -ne 3 ]; then return "$rc"; fi
  for os in "${oses[@]}"; do
    a="$(archive_name "$os" "$version")"
    if ! has_line "$a" "$have" || ! has_line "$a.sha256" "$have"; then
      printf '%s\n%s\n' "$a" "$a.sha256"
    fi
  done
}

notes() {
  local version="$1" sha="$2" repo="$3" upstream patch subject
  upstream="v${version%%-*}"
  cat <<EOF
Prebuilt Filament **$version** for Lumina: upstream Filament [$upstream](https://github.com/google/filament/releases/tag/$upstream) with the patches below, built from [\`${sha:0:12}\`](https://github.com/$repo/commit/$sha). The Lumina Studio editor downloads it at first launch; CI and the release workflow build against it.

This is not a Lumina Studio release: it is never marked Latest, every Lumina release built with Filament $version links here, and its assets never change. A new Filament build gets a new version (\`tool/filament/VERSION\`) and its own release.

## Patches

| Patch | Change |
|---|---|
EOF
  for patch in "$root"/third_party/filament/patches/*.patch; do
    # The Subject header, folded lines joined.
    subject="$(awk '/^Subject: /{s=substr($0,10); f=1; next} f && /^[[:blank:]]/{s=s $0; next} f{print s; exit}' "$patch" |
      sed 's/^\[PATCH[^]]*\] //')"
    # A plain `git diff` patch has no Subject: its file name, spelled out.
    [ -n "$subject" ] || subject="$(basename "$patch" .patch | sed 's/^[0-9]*-//; s/-/ /g')"
    # shellcheck disable=SC2016 # Markdown code spans, not an expansion.
    printf '| `%s` | %s |\n' "$(basename "$patch")" "$subject"
  done
  cat <<EOF

Details: [third_party/filament/README.md](https://github.com/$repo/blob/$sha/third_party/filament/README.md).

## Assets

| File | Platform |
|---|---|
| \`$(archive_name windows "$version")\` | Windows x64 (MSVC, static CRT) |
| \`$(archive_name linux "$version")\` | Linux x64 (clang, bundled libc++) |
| \`$(archive_name linux-arm64 "$version")\` | Linux arm64 (clang, bundled libc++) |

Each archive holds one folder that works as the hooks' \`filament_dir\`, with a \`lumina-filament.json\` describing the build, and has a \`.sha256\` sidecar.
EOF
}

publish() {
  local tag="$1" version="$2" sha="$3" dir="$4" rc=0 notes_file all a n left
  : "${GH_REPO:?GH_REPO must name the repository}"
  release_assets "$tag" >/dev/null || rc=$?
  if [ "$rc" -eq 3 ]; then
    notes_file="$(mktemp)"
    notes "$version" "$sha" "$GH_REPO" > "$notes_file"
    if ! gh release create "$tag" --target "$sha" --title "Filament $version" \
      --notes-file "$notes_file" --prerelease --latest=false; then
      # Another run may have created it in the meantime.
      rc=0
      release_assets "$tag" >/dev/null || rc=$?
      if [ "$rc" -ne 0 ]; then
        echo "::error::Could not create the release $tag." >&2
        rm -f "$notes_file"
        return 1
      fi
      echo "The release $tag was created by another run."
    fi
    rm -f "$notes_file"
  elif [ "$rc" -ne 0 ]; then
    return "$rc"
  fi

  mapfile -t need < <(missing "$tag" "$version" | grep -v '\.sha256$' || true)
  for a in "${need[@]}"; do
    if [ ! -f "$dir/$a" ] || [ ! -f "$dir/$a.sha256" ]; then
      echo "::error::$tag needs $a, but $dir has no $a with its .sha256." >&2
      return 1
    fi
    (cd "$dir" && sha256sum -c "$a.sha256")
    all="$(release_assets "$tag" all)"
    for n in "$a" "$a.sha256"; do
      if has_line "$n" "$all"; then
        echo "Removing the incomplete $n from $tag."
        gh release delete-asset "$tag" "$n" --yes
      fi
    done
    if gh release upload "$tag" "$dir/$a"; then
      gh release upload "$tag" "$dir/$a.sha256" || echo "::warning::Uploading $a.sha256 failed."
    else
      echo "::warning::Uploading $a failed."
    fi
  done

  left="$(missing "$tag" "$version")"
  if [ -n "$left" ]; then
    echo "::error::$tag is still missing: $(printf '%s' "$left" | tr '\n' ' ')" >&2
    return 1
  fi
  echo "$tag is complete."
}

command="${1:-}"
[ $# -gt 0 ] && shift
case "$command" in
  missing) [ $# -ge 2 ] || { sed -n '7,13p' "$0" >&2; exit 64; }; missing "$@" ;;
  notes) [ $# -eq 3 ] || { sed -n '14,15p' "$0" >&2; exit 64; }; notes "$@" ;;
  publish) [ $# -eq 4 ] || { sed -n '16,21p' "$0" >&2; exit 64; }; publish "$@" ;;
  *) sed -n '2,23p' "$0" >&2; exit 64 ;;
esac

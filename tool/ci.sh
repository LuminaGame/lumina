#!/usr/bin/env bash
# Runs every workspace test suite:
# unit suites on the noop backend, smoke suites on GPU 1 with PNG/video evidence.
#
#   tool/ci.sh            # unit + smoke for all packages
#   tool/ci.sh --unit     # unit suites only (no GPU needed)
#   tool/ci.sh --smoke    # smoke reports only (GPU 1)
#   tool/ci.sh --package  # also let lumina_ui's MSIX packaging test build a Release app (Windows)
#   tool/ci.sh lumina     # restrict to one package (lumina_core|lumina_plugin_process|flutter_filament|lumina|lumina_editor_data|lumina_ui|lumina_editor_api)
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE=all
ONLY=""
for a in "$@"; do
  case "$a" in
    --unit) MODE=unit ;;
    --smoke) MODE=smoke ;;
    # The MSIX verify test packages an existing Release
    # build; with --package it may run `flutter build windows` for one.
    --package) export LUMINA_PACKAGING_TESTS=1 ;;
    *) ONLY="$a" ;;
  esac
done

# Target GPU: GPU index 1 = NVIDIA RTX PRO 2000.
# FILAMENT_GPU selects the RTX PRO 2000 by name: under PRIME offload the Vulkan
# device order changes (it becomes index 0), so an index would pick the RTX 4080.
export FILAMENT_GPU='RTX PRO 2000' CUDA_VISIBLE_DEVICES=1 __NV_PRIME_RENDER_OFFLOAD=1 __VK_LAYER_NV_optimus=NVIDIA_only DRI_PRIME=1
export LUMINA_TEST_ASSETS="$ROOT/test-assets"
# Nothing started from here captures the real pointer: Play's mouse capture
# records requests instead.
export LUMINA_MOUSE_CAPTURE=off
# Test runs never touch the user's editor config (~/.config/lumina): each test
# file is isolated by its flutter_test_config.dart, and everything started
# from here also resolves this throwaway directory.
LUMINA_CONFIG_DIR="$(mktemp -d "${TMPDIR:-/tmp}/lumina_ci_config_XXXXXX")"
export LUMINA_CONFIG_DIR
trap 'rm -rf "$LUMINA_CONFIG_DIR"' EXIT

if [ ! -f "$ROOT/filament/out/cmake-release/filament/libfilament.a" ]; then
  echo "!! Filament static libraries missing (filament/out/cmake-release). Build Filament first." >&2
  exit 2
fi

# One test process at a time on this machine (user rule, 2026-09-24): never
# two smoke tests together, never smokes alongside unit tests. Every run takes
# the lock every agent and session uses.
LOCK=/tmp/lumina_tests.lock

# The unit targets of a package: test/'s entries except test/smoke (the smoke
# files run in the report step, one at a time).
unit_targets() {
  find test -mindepth 1 -maxdepth 1 \( -type d ! -name smoke -o -name '*_test.dart' \) | sort
}

# flutter_assimp and flutter_riglogic live in the tools repo (their own CI).
PACKAGES=(lumina_core lumina_plugin_process flutter_filament lumina lumina_editor_data lumina_editor_api lumina_ui)
FAILED=()
run() {
  local pkg="$1"; shift
  echo "=== [$pkg] $*"
  (cd "$ROOT/$pkg" && "$@") || FAILED+=("$pkg: $*")
}

for pkg in "${PACKAGES[@]}"; do
  [ -n "$ONLY" ] && [ "$ONLY" != "$pkg" ] && continue
  [ -d "$ROOT/$pkg" ] || continue
  # Compiled materials first: a package whose .filamat no longer matches the
  # engine is refused at load time without failing anything, so the symptom is
  # a render that silently draws nothing rather than a red test.
  if [ "$MODE" != smoke ] && [ -x "$ROOT/$pkg/tool/build_materials.sh" ]; then
    run "$pkg" ./tool/build_materials.sh
  fi
  if [ "$MODE" != smoke ]; then
    targets=$(cd "$ROOT/$pkg" && unit_targets | tr '\n' ' ')
    # A pure-Dart package (no flutter dependency) runs under `dart test`.
    # shellcheck disable=SC2086
    if grep -q '^  flutter:' "$ROOT/$pkg/pubspec.yaml"; then
      run "$pkg" flock "$LOCK" flutter test $targets
    else
      run "$pkg" dart test $targets
    fi
  fi
  if [ "$MODE" != unit ] && [ -f "$ROOT/$pkg/tool/smoke_report.dart" ]; then
    smoke_args=()
    if [ "$MODE" = smoke ] || [ "$MODE" = all ]; then
      smoke_args=(--smoke-only)
    fi
    # shellcheck disable=SC2086
    run "$pkg" flock "$LOCK" dart run tool/smoke_report.dart "${smoke_args[@]}"
    echo "    report: $ROOT/$pkg/build/smoke_report.html"
  fi
done

if [ ${#FAILED[@]} -gt 0 ]; then
  echo; echo "FAILED:"; printf '  - %s\n' "${FAILED[@]}"; exit 1
fi
echo; echo "All suites passed."

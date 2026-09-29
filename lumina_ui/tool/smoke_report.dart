// Runs Lumina Studio's smoke tests (test/smoke, then every
// integration_test/smoke file on the desktop device) on GPU 1 and writes the
// report: `build/smoke_report.html` plus one page per feature area under
// `build/smoke_report/`, linking (never embedding) the artifacts in
// `build/smoke_artifacts/`.
//
//   dart run tool/smoke_report.dart                  # the smokes: starts clean
//   dart run tool/smoke_report.dart --all            # test/, the smokes and every integration test
//   dart run tool/smoke_report.dart --unit-only      # test/ only
//   dart run tool/smoke_report.dart --integration-only
//   dart run tool/smoke_report.dart integration_test/smoke/details_smoke_test.dart --plain-name 'x'
//                                                    # targeted run: merges
//   dart run tool/smoke_report.dart <target> --fresh # targeted, starts clean
//   dart run tool/smoke_report.dart --report-only    # re-render from events
//   ... --no-dashboard                               # no live dashboard
//
// The runner, the report and every flag are lumina_smoke's
// (`package:lumina_smoke/report.dart`); this file is the package's
// configuration.
import 'package:lumina_smoke/report.dart';

/// Lumina Studio's report configuration.
const SmokeReportConfig studioSmokeConfig = SmokeReportConfig(
  title: 'Lumina Studio Smoke & Test Report',
  tag: 'Studio UI',
  dashboardTitle: 'Lumina UI Smoke Tests',
  categories: studioTestCategories,
  categoryNote: 'One page per feature area; every PNG and video is linked from build/smoke_artifacts/, not embedded.',
  // Artifacts that match no test of the report share one page.
  orphanCategory: 'Artifacts without a matching test',
  integrationDirs: ['integration_test'],
  integrationSmokeDirs: ['integration_test/smoke'],
  environment: {
    // The editor these runs start never captures the real pointer (the
    // plugin's native side checks this too).
    'LUMINA_MOUSE_CAPTURE': 'off',
  },
);

/// Feature areas, in report order: the first whose keyword the test file's
/// name contains wins (then the test name is tried).
const TestCategories studioTestCategories = TestCategories([
  ('Blueprint', ['blueprint']),
  ('Material & Texture', ['material', 'texture', 'shader']),
  ('Mesh & Physics', ['static_mesh', 'skeletal', 'mesh', 'physics', 'socket', 'lod', 'ccmh', 'manny', 'mannequin']),
  ('Animation & Sequencer', ['animation', 'anim_', 'sequencer', 'montage', 'retarget']),
  ('Lighting & Environment', ['environment', 'lighting', 'solar', 'sky', 'light', 'post_process', 'quality']),
  ('Landscape & Foliage', ['landscape', 'foliage']),
  ('Navigation', ['navigation', 'nav_']),
  ('Units & Axes', ['units', 'axes', 'real_size']),
  ('Play In Editor', ['pie_', 'pie ', 'gameplay', 'play']),
  ('UMG', ['umg', 'widget_library']),
  ('Particles', ['particle']),
  ('Audio', ['audio', 'sound']),
  ('Build & Packaging', ['build', 'cook', 'package', 'main_dart', 'web_preview']),
  ('World & Levels', ['world_partition', 'level']),
  ('Content Browser & Assets', ['content_browser', 'asset', 'import', 'thumbnail']),
  ('Launcher & Project', ['launcher', 'project', 'template', 'plugin', 'source_control', 'git_', 'recent', 'graphics_device']),
  ('Editor UI', ['viewport', 'gizmo', 'outliner', 'details', 'toolbar', 'editor_shell', 'menu', 'snap', 'design_system', 'design_tokens', 'shell', 'dock', 'layout', 'theme', 'panel', 'editor', 'actor_catalog', 'component_property', 'multi_edit', 'frame_', 'view_modes', 'tab_', 'banner']),
  ('Test Harness', ['smoke_report', 'test_report', 'tooling', 'smoke_artifacts']),
]);

Future<void> main(List<String> args) => smokeReportMain(args, studioSmokeConfig);

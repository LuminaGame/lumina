// Runs lumina_editor_data's smoke tests (or any tests named) on GPU 1 and
// writes the report: `build/smoke_report.html` plus one page per area under
// `build/smoke_report/`, linking (never embedding) the artifacts in
// `build/smoke_artifacts/`.
//
//   dart run tool/smoke_report.dart                  # test/smoke: starts clean
//   dart run tool/smoke_report.dart test/smoke/domain_smoke_test.dart --plain-name '<scenario>'
//                                                    # targeted run: merges
//   dart run tool/smoke_report.dart <target> --fresh # targeted, starts clean
//   dart run tool/smoke_report.dart --report-only    # re-render from events
//   ... --no-dashboard                               # no live dashboard
//
// The runner, the report and every flag are lumina_smoke's
// (`package:lumina_smoke/report.dart`); this file is the package's
// configuration.
import 'package:lumina_smoke/report.dart';

/// lumina_editor_data's report configuration.
const SmokeReportConfig editorDataSmokeConfig = SmokeReportConfig(
  title: 'Lumina Editor Data Smoke & Test Report',
  tag: 'Editor Data',
  dashboardTitle: 'Lumina Editor Data Smoke Tests',
  categories: editorDataTestCategories,
  categoryNote: 'One page per area; every PNG and video is linked from build/smoke_artifacts/, not embedded.',
  scenarioKeywords: ['animation', 'blueprint', 'collision', 'physics', 'input', 'domain', 'derived_data', 'packaging', 'web'],
);

/// Areas, in report order, with the words that place a test file in them
/// (the longest match decides, a tie goes to the earlier area).
const TestCategories editorDataTestCategories = TestCategories(
  [
    ('Import & Assets', ['import', 'asset', 'glb', 'obj', 'fbx', 'assimp', 'texture', 'material', 'mesh_collision', 'repository', 'derived_data', 'encoded_image', 'mannequin', 'rig_logic']),
    ('Thumbnails', ['thumbnail']),
    ('Code Generation', ['codegen', 'code_generator', 'actor_codegen', 'level_codegen', 'level_manifest', 'generated_code', 'template', 'base_eye_height', 'project_input', 'web_loading', 'app_icon', 'packaging']),
    ('Blueprint', ['blueprint', 'anim', 'blend_space', 'level_script', 'widget_script']),
    ('Project Editor Builds', ['editor_build', 'editor_host', 'editor_engine']),
    ('Plugins', ['plugin']),
    ('Use Cases', ['domain', 'use_cases']),
    ('Engine Integration', ['animation', 'collision', 'physics', 'input', 'mass_resolution', 'level_mesh', 'static_mesh', 'primitive', 'imported_texture']),
    ('Web', ['web']),
    ('Architecture', ['architecture', 'no_widgets', 'import_cycles']),
  ],
  longestMatch: true,
  folders: {
    'blueprint': 'Blueprint',
    'domain': 'Use Cases',
    'web': 'Web',
    'architecture': 'Architecture',
  },
  fallbackFolders: {'data': 'Import & Assets'},
);

Future<void> main(List<String> args) => smokeReportMain(args, editorDataSmokeConfig);

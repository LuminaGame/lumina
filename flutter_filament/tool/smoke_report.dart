// Runs flutter_filament's tests (the smoke tests on both GPU backends) and
// writes the report: `build/smoke_report.html` plus one page per category
// under `build/smoke_report/`, linking (never embedding) the artifacts in
// `build/smoke_artifacts/<backend>/`.
//
//   dart run tool/smoke_report.dart                  # the smokes: starts clean
//   dart run tool/smoke_report.dart --all            # test/ + the smokes
//   dart run tool/smoke_report.dart --unit-only      # test/ on OpenGL
//   dart run tool/smoke_report.dart test/smoke/camera_smoke_test.dart
//                                                    # targeted run: merges
//   dart run tool/smoke_report.dart test/smoke/camera_smoke_test.dart --plain-name 'dolly'
//   dart run tool/smoke_report.dart <target> --fresh # targeted, starts clean
//   dart run tool/smoke_report.dart --report-only    # re-render from events
//   ... --no-dashboard                               # no live dashboard
//
// The runner, the report and every flag are lumina_smoke's
// (`package:lumina_smoke/report.dart`); this file is the package's
// configuration. Targets inside `test/smoke/` run on OpenGL and Vulkan,
// everything else on OpenGL only.
import 'package:lumina_smoke/report.dart';

/// flutter_filament's report configuration.
const SmokeReportConfig filamentSmokeConfig = SmokeReportConfig(
  title: 'Filament Engine Test Report',
  tag: 'flutter_filament',
  dashboardTitle: 'Flutter Filament Smoke Tests',
  categories: filamentTestCategories,
  categoryNote: 'One page per module; every PNG and video is linked from build/smoke_artifacts/, not embedded.',
  failingCategoriesFirst: true,
  backends: [
    SmokeBackend('opengl', environment: {'FILAMENT_SMOKE_BACKEND': 'opengl'}),
    SmokeBackend('vulkan', environment: {'FILAMENT_SMOKE_BACKEND': 'vulkan'}),
  ],
);

/// The modules of flutter_filament, in report order. A test belongs to the
/// first category whose keyword its file name contains, else the first whose
/// keyword its test name contains, else 'Other'. Specific modules come before
/// the ones whose keyword they contain (`material_instance` before
/// `material`, `iblprefilter` before `ibl`).
const TestCategories filamentTestCategories = TestCategories(
  [
    ('00_test_report', ['smoke_report', 'smoke_artifacts', 'test_report']),
    ('00_infrastructure', ['00_infrastructure', 'infrastructure', 'callback_bridge', 'enum_fidelity', 'math_abi', 'panic_log', 'buffer_descriptor', 'instance_handle']),
    ('engine', ['engine', 'gpu']),
    ('gltfio', ['gltf', 'animator', 'filament_instance', 'instanced_asset', 'material_provider']),
    ('material_instance', ['material_instance']),
    ('material', ['material']),
    ('filamat', ['filamat']),
    ('texture_sampler', ['texture_sampler']),
    ('texture', ['texture']),
    ('image', ['image', 'color_transform']),
    ('ktxreader', ['ktx']),
    ('iblprefilter', ['iblprefilter']),
    ('indirect_light', ['indirect_light']),
    ('ibl', ['ibl']),
    ('skybox', ['skybox']),
    ('light_manager', ['light_manager', 'lighting', 'light']),
    ('color_grading', ['color_grading']),
    ('skinning_buffer', ['skinning']),
    ('morph_target_buffer', ['morph_target']),
    ('instance_buffer', ['instance_buffer']),
    ('vertex_buffer', ['vertex_buffer', 'buffer_object']),
    ('index_buffer', ['index_buffer']),
    ('render_target', ['render_target']),
    ('renderable_manager', ['renderable_manager', 'renderable', 'picking']),
    ('renderer', ['renderer', 'render_smoke', 'frame_history']),
    ('swap_chain', ['swap_chain']),
    ('frame_pacing', ['frame_pacing', 'frame_pacer', 'frame_pipeline']),
    ('fence', ['fence']),
    ('view', ['view']),
    ('scene', ['scene']),
    ('camutils', ['camutils', 'manipulator', 'bookmark']),
    ('camera', ['camera']),
    ('transform_manager', ['transform_manager', 'transform', 'node_trs']),
    ('filameshio', ['filamesh', 'suzanne_monkey']),
    ('geometry', ['geometry', 'tangent_space', 'transcoder']),
    ('dart_math', ['dart_math']),
    ('utils', ['utils', 'entity', 'name_component', 'tools', 'debug_registry']),
    ('web', ['web_']),
  ],
  pathRules: {
    '/test/web/': 'web',
    '/test/web_browser/': 'web',
    'tool/web/': 'web',
    '/test/math/': 'dart_math',
  },
  namePrefixes: {'web ': 'web'},
);

Future<void> main(List<String> args) => smokeReportMain(args, filamentSmokeConfig);

// Runs lumina's smoke tests (or any tests named) on GPU 1 and writes the
// report: `build/smoke_report.html` plus one page per engine module under
// `build/smoke_report/`, linking (never embedding) the artifacts in
// `build/smoke_artifacts/`.
//
//   dart run tool/smoke_report.dart                  # test/smoke: starts clean
//   dart run tool/smoke_report.dart --all            # test/ + the smokes
//   dart run tool/smoke_report.dart test/smoke/static_mesh_smoke_test.dart --plain-name 'Scenario 01'
//                                                    # targeted run: merges
//   dart run tool/smoke_report.dart <target> --fresh # targeted, starts clean
//   dart run tool/smoke_report.dart --report-only    # re-render from events
//   ... --no-dashboard                               # no live dashboard
//
// The runner, the report and every flag are lumina_smoke's
// (`package:lumina_smoke/report.dart`); this file is the package's
// configuration.
import 'package:lumina_smoke/report.dart';

/// lumina's report configuration.
const SmokeReportConfig luminaSmokeConfig = SmokeReportConfig(
  title: 'Lumina Smoke & Test Report',
  tag: 'Core Engine',
  dashboardTitle: 'Lumina Engine Smoke Tests',
  categories: luminaTestCategories,
  categoryNote: 'One page per engine module; every PNG and video is linked from build/smoke_artifacts/, not embedded.',
  // A `Scenario NN` artifact goes to the `Scenario NN` test of the module
  // both names (or the test's file) mention.
  scenarioKeywords: [
    'camera', 'char_movement', 'character_movement', 'world_partition', 'level_streaming', 'game_save', //
    'static_mesh', 'environment', 'post_process', 'skeletal_mesh', 'animation', 'collision', 'player', 'pawn',
    'input', 'world', 'level', 'light', 'material', '00_declarative', '00_test_report',
  ],
);

/// Engine modules, in report order, with the words that place a test file in
/// them. A word matches at the start of a word of the file name (`pawn`
/// matches `pawn_input`, not `spawn_actor`); the longest match decides, a tie
/// goes to the earlier module.
const TestCategories luminaTestCategories = TestCategories(
  [
    ('World', ['world', 'lumina', 'declarative', 'subsystem', 'tick_pipeline', 'frame_driver', 'frame_pacing', 'entity_registry', 'scene_component', 'graphics_device', 'render_backend', 'object_pool', 'runtime_object', 'build_context', 'element_lifecycle', 'reconciliation']),
    ('Level', ['level', 'level_streaming', 'streaming_volume']),
    ('Pawn & Player', ['pawn', 'player', 'possession']),
    ('Character Movement', ['char_movement', 'character_movement', 'kinematic', 'walk_gravity', 'movement_modes', 'template_character', 'movement_extras', 'projectile', 'rotating_movement', 'interp_to_movement']),
    ('Collision', ['collision', 'gjk', 'narrow_phase']),
    ('Physics', ['physics', 'rigid_body', 'character_push', 'mass_resolution']),
    ('Camera & Spring Arm', ['camera', 'spring_arm', 'game_view_camera']),
    ('Input', ['input']),
    ('Animation', ['anim', 'animation', 'animated_mesh', 'blend_space', 'montage', 'retarget', 'rig_logic', 'locomotion', 'mannequin', 'free_look', 'joint_override', 'aim_offset']),
    ('Mesh & Material', ['mesh', 'static_mesh', 'skeletal_mesh', 'procedural_mesh', 'skeleton_fk', 'skinning', 'sockets', 'morph', 'primitive', 'material']),
    ('AI & Navigation', ['ai_', 'navigation', 'behavior_tree', 'perception']),
    ('Light, Environment & Post Process', ['light', 'exposure', 'environment', 'sky', 'procedural_sky', 'reflection', 'post_process', 'scalability', 'fog']),
    ('Landscape & World Partition', ['landscape', 'world_partition', 'data_layer', 'hlod', 'streaming_source']),
    ('UMG', ['umg']),
    ('Units', ['units']),
    ('Blueprint', ['blueprint']),
    ('Game Framework', ['game_framework', 'game_instance', 'game_mode', 'game_state', 'game_play_control', 'player_camera_manager', 'pie_']),
    ('Save', ['save', 'game_save', 'save_game', 'world_restore']),
    ('Audio', ['audio']),
    ('Particles', ['particle']),
    ('Utility', ['utility', 'timer_manager', 'gameplay_statics', 'gameplay_volumes', 'viewport_statics']),
    ('Web', ['web', 'lumina_assets', 'runtime_asset_loading', 'runtime_import_graph']),
    ('Data Layer & Codegen', ['domain', 'derived_data', 'packaging', 'app_icon', 'codegen', 'code_generator', 'repository', 'project_', 'asset', 'glb', 'obj_parser', 'tga', 'plugin', 'thumbnail', 'auto_save', 'sequencer_data', 'decimation']),
    ('Test Harness', ['smoke_report', 'test_report', 'smoke_artifacts']),
  ],
  longestMatch: true,
  // Test folders that decide a test's module whatever its file is called…
  folders: {
    'data': 'Data Layer & Codegen',
    'domain': 'Data Layer & Codegen',
    'blueprint': 'Blueprint',
    'umg': 'UMG',
    'web': 'Web',
    'testing': 'Test Harness',
    'code_health': 'Test Harness',
  },
  // …and folders that only decide when the file name does not.
  fallbackFolders: {
    'world': 'World',
    'declarative': 'World',
    'save': 'Save',
    'collision': 'Collision',
    'physics': 'Physics',
  },
);

Future<void> main(List<String> args) => smokeReportMain(args, luminaSmokeConfig);

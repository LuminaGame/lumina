/// The pure-Dart foundation shared by Lumina's engine (`package:lumina`),
/// Lumina Studio and plugin processes.
///
/// No Flutter, `dart:ui` or FFI anywhere in its import graph
/// (`test/architecture/pure_dart_test.dart`), so a CLI tool, a server or a
/// plugin process can read and write Lumina's files with `dart run`.
library;

// Change notification without Flutter: ChangeSignal, Observable, ObservableValue.
export 'package:lumina_core/src/foundation/observable.dart';

// Math: units, axes, Euler/control rotations, transform snapshots.
export 'package:lumina_core/src/math/axes.dart';
export 'package:lumina_core/src/math/camera_math.dart';
export 'package:lumina_core/src/math/euler.dart';
export 'package:lumina_core/src/math/transform_snapshot.dart';
export 'package:lumina_core/src/math/units.dart';

// File formats and their models: .lmas assets, .lmproject, levels, landscape,
// sequencer, plugin descriptors, themes.
export 'package:lumina_core/src/formats/landscape_data.dart';
export 'package:lumina_core/src/formats/lumina_asset.dart';
export 'package:lumina_core/src/formats/lumina_asset_summary.dart';
export 'package:lumina_core/src/formats/lumina_level_document.dart';
export 'package:lumina_core/src/formats/lumina_plugin_descriptor.dart';
export 'package:lumina_core/src/formats/lumina_project.dart';
export 'package:lumina_core/src/formats/lumina_theme_document.dart';
export 'package:lumina_core/src/formats/plugin_isolation.dart';
export 'package:lumina_core/src/formats/project_input_settings.dart';
export 'package:lumina_core/src/formats/project_packaging_settings.dart';
export 'package:lumina_core/src/formats/project_web_loading_style.dart';
export 'package:lumina_core/src/formats/recent_project_entry.dart';
export 'package:lumina_core/src/formats/sequencer_data.dart';

// Repositories that read and write them.
// Physics assets (ragdoll bodies and joints) and their generator.
export 'package:lumina_core/src/physics_asset/physics_asset_data.dart';
export 'package:lumina_core/src/physics_asset/physics_asset_generator.dart';
// Motion matching: pose search databases (document, clip sampler, features, search).
export 'package:lumina_core/src/pose_search/glb_animation_sampler.dart';
export 'package:lumina_core/src/pose_search/pose_math.dart';
export 'package:lumina_core/src/pose_search/pose_search_builder.dart';
export 'package:lumina_core/src/pose_search/pose_search_document.dart';
export 'package:lumina_core/src/pose_search/pose_search_index.dart';
export 'package:lumina_core/src/pose_search/pose_search_poser.dart';

export 'package:lumina_core/src/repositories/level_repository.dart';
export 'package:lumina_core/src/repositories/plugin_repository.dart';

// Pure services: paths, logger, config, build fingerprint/cache, glTF tools,
// templates, release assets.
export 'package:lumina_core/src/services/animation_import_binder.dart';
export 'package:lumina_core/src/services/asset_index.dart';
export 'package:lumina_core/src/services/authored_animation_clip.dart';
export 'package:lumina_core/src/services/authored_animation_writer.dart';
export 'package:lumina_core/src/services/authored_pose_tools.dart';
export 'package:lumina_core/src/services/auto_save_timer_service.dart';
export 'package:lumina_core/src/services/config_json_file.dart';
export 'package:lumina_core/src/services/dart_identifiers.dart';
export 'package:lumina_core/src/services/directory_link.dart';
export 'package:lumina_core/src/services/editor_build_cache.dart';
export 'package:lumina_core/src/services/editor_build_fingerprint.dart';
export 'package:lumina_core/src/services/editor_source_vendor_service.dart';
export 'package:lumina_core/src/services/encoded_image_format.dart';
export 'package:lumina_core/src/services/engine_bootstrap.dart';
export 'package:lumina_core/src/services/engine_identity.dart';
export 'package:lumina_core/src/services/engine_logger_service.dart';
export 'package:lumina_core/src/services/fbx_material_mapper.dart';
export 'package:lumina_core/src/services/fbx_texture_locator.dart';
export 'package:lumina_core/src/services/filament_prebuilt.dart';
export 'package:lumina_core/src/services/game_template_service.dart';
export 'package:lumina_core/src/services/generated_code_migration.dart';
export 'package:lumina_core/src/services/glb_animation_merger.dart';
export 'package:lumina_core/src/services/glb_animation_retargeter.dart';
export 'package:lumina_core/src/services/glb_reader.dart';
export 'package:lumina_core/src/services/gltf_packer.dart';
export 'package:lumina_core/src/services/import_formats.dart';
export 'package:lumina_core/src/services/imported_asset_names.dart';
export 'package:lumina_core/src/services/level_template_service.dart';
export 'package:lumina_core/src/services/lumina_config_dir.dart';
export 'package:lumina_core/src/services/lumina_data_dir.dart';
export 'package:lumina_core/src/services/openriglogic_prebuilt.dart';
export 'package:lumina_core/src/services/plugin_host_patcher_service.dart';
export 'package:lumina_core/src/services/plugin_pack_script.dart';
export 'package:lumina_core/src/services/plugin_template/isolated_plugin_sources.dart';
export 'package:lumina_core/src/services/primitive_glb_factory.dart';
export 'package:lumina_core/src/services/project_engine_link.dart';
export 'package:lumina_core/src/services/release_asset.dart';
export 'package:lumina_core/src/services/space_free_build_dir.dart';
export 'package:lumina_core/src/services/tga_decoder_service.dart';
export 'package:lumina_core/src/services/theme_service.dart';
export 'package:lumina_core/src/services/umg_widget_library_service.dart';
export 'package:lumina_core/src/services/workspace_paths.dart';

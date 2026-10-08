/// Lumina Studio's tooling data layer: what the editor reads, writes, imports
/// and generates, outside the engine.
///
/// - Repositories: projects, assets (import pipeline, thumbnails, families),
///   collections.
/// - Importers: Assimp (FBX, OBJ and the other formats it reads), GLB
///   (`GlbParserService`: the engine's GLB reader plus the import sanitizer),
///   image conversion, the import queue and folder scanner.
/// - Thumbnails: the thumbnail service and the offscreen Filament renderer.
/// - Code generation: the Dart code generator, the Blueprint compiler, the
///   Blueprint function scanner and class registry.
/// - Project editor builds: the host generator and the build service.
/// - Plugins: the registry and the template generator.
/// - The derived data cache, the asset reference graph, mesh collision and
///   physics authoring, the RigLogic evaluator.
/// - The use cases (save a level, generate the Dart code, import an asset).
///
/// Editor code usually imports `package:lumina_editor_data/lumina_editor.dart`,
/// which adds the engine and lumina_core.
library;

// Repositories
export 'package:lumina_editor_data/src/repositories/asset_repository.dart';
export 'package:lumina_editor_data/src/repositories/collections_repository.dart';
export 'package:lumina_editor_data/src/repositories/project_repository.dart';

// Code generation and Blueprints
export 'package:lumina_editor_data/src/services/blueprint_class_registry.dart';
export 'package:lumina_editor_data/src/services/blueprint_codegen/blueprint_dart_generator.dart';
export 'package:lumina_editor_data/src/services/blueprint_function_manifest.dart';
export 'package:lumina_editor_data/src/services/blueprint_function_scanner.dart';
export 'package:lumina_editor_data/src/services/blueprint_project_assets.dart';
export 'package:lumina_editor_data/src/services/code_generator_service.dart';
export 'package:lumina_editor_data/src/services/base_eye_height_migration.dart';
export 'package:lumina_editor_data/src/services/app_icon_service.dart';
export 'package:lumina_editor_data/src/services/web_loading_screen_service.dart';

// Importers
export 'package:lumina_editor_data/src/services/assimp_import_service.dart';
export 'package:lumina_editor_data/src/services/fbx_import_service.dart';
export 'package:lumina_editor_data/src/services/obj_import_service.dart';
export 'package:lumina_editor_data/src/services/obj_parser_service.dart';
export 'package:lumina_editor_data/src/services/glb_parser_service.dart';
export 'package:lumina_editor_data/src/services/import_image_conversion.dart';
export 'package:lumina_editor_data/src/services/import_queue.dart';
export 'package:lumina_editor_data/src/services/import_folder_scanner.dart';
export 'package:lumina_editor_data/src/services/mesh_collision_service.dart';
export 'package:lumina_editor_data/src/services/mesh_physics_service.dart';
export 'package:lumina_editor_data/src/services/rig_logic_evaluator.dart';

// Derived data, references and thumbnails
export 'package:lumina_editor_data/src/services/derived_data_cache.dart';
export 'package:lumina_editor_data/src/services/asset_reference_graph.dart';
export 'package:lumina_editor_data/src/services/thumbnail_service.dart';
export 'package:lumina_editor_data/src/services/thumbnail_sidecar_migration.dart';
export 'package:lumina_editor_data/src/services/filament_thumbnail_renderer.dart';
export 'package:lumina_editor_data/src/services/thumbnail_mesh_loader.dart';
export 'package:lumina_editor_data/src/services/model_file_thumbnailer.dart';

// Plugins and project editor builds
export 'package:lumina_editor_data/src/services/plugin_registry_service.dart';
export 'package:lumina_editor_data/src/services/plugin_template_generator_service.dart';
export 'package:lumina_editor_data/src/services/editor_host_generator_service.dart';
export 'package:lumina_editor_data/src/services/editor_build_service.dart';

// Example projects
export 'package:lumina_editor_data/src/samples/game_animation_sample/game_animation_sample.dart';

// Use cases
export 'package:lumina_editor_data/src/domain/models/use_case_results.dart';
export 'package:lumina_editor_data/src/domain/use_cases/save_level_use_case.dart';
export 'package:lumina_editor_data/src/domain/use_cases/generate_dart_code_use_case.dart';
export 'package:lumina_editor_data/src/domain/use_cases/import_asset_use_case.dart';

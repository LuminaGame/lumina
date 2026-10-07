// Data & Manifest Models
export 'package:lumina/data/models/lumina_asset.dart';
export 'package:lumina/data/models/lumina_theme_document.dart';
export 'package:lumina/data/models/sequencer_data.dart';
export 'package:lumina/data/models/landscape_data.dart';
export 'package:lumina/data/models/lumina_project.dart';
export 'package:lumina/data/services/theme_service.dart';
export 'package:lumina/data/models/recent_project_entry.dart';
export 'package:lumina/data/repositories/project_repository.dart';
export 'package:lumina/data/repositories/asset_repository.dart';
export 'package:lumina/data/repositories/collections_repository.dart';
export 'package:lumina/data/repositories/level_repository.dart';
export 'package:lumina/data/models/lumina_level_document.dart';
export 'package:lumina/data/services/code_generator_service.dart';
export 'package:lumina/data/services/dart_identifiers.dart';
export 'package:lumina/data/services/generated_code_migration.dart';
export 'package:lumina/data/services/blueprint_project_assets.dart';
export 'package:lumina/data/services/umg_widget_library_service.dart';
export 'package:lumina/data/services/app_icon_service.dart';
export 'package:lumina/data/services/web_loading_screen_service.dart';
export 'package:lumina/data/services/project_input_binder.dart';
export 'package:lumina/data/services/auto_save_timer_service.dart';
export 'package:lumina/data/services/engine_logger_service.dart';
export 'package:lumina/data/services/lumina_config_dir.dart';
export 'package:lumina/data/services/config_json_file.dart';
export 'package:lumina/data/services/glb_parser_service.dart';
export 'package:lumina/data/services/derived_data_cache.dart';
export 'package:lumina/data/services/asset_index.dart';
export 'package:lumina/data/services/level_asset_manifest.dart';
export 'package:lumina/data/services/level_actor_material.dart';
export 'package:lumina/data/services/thumbnail_sidecar_migration.dart';
export 'package:lumina/data/services/primitive_glb_factory.dart';
export 'package:lumina/data/services/glb_animation_merger.dart';
export 'package:lumina/data/services/glb_animation_retargeter.dart';
export 'package:lumina/data/services/assimp_import_service.dart';
export 'package:lumina/data/services/fbx_import_service.dart';
export 'package:lumina/data/services/fbx_material_mapper.dart';
export 'package:lumina/data/services/fbx_texture_locator.dart';
export 'package:lumina/data/services/obj_import_service.dart';
export 'package:lumina/data/services/imported_asset_names.dart';
export 'package:lumina/data/services/mesh_collision_service.dart';
export 'package:lumina/data/services/mesh_physics_service.dart';
export 'package:lumina/data/services/animation_import_binder.dart';
export 'package:lumina/data/services/authored_animation_clip.dart';
export 'package:lumina/data/services/authored_animation_writer.dart';
export 'package:lumina/data/services/authored_pose_tools.dart';
export 'package:lumina/data/services/obj_parser_service.dart';
export 'package:lumina/data/services/tga_decoder_service.dart';
export 'package:lumina/data/services/encoded_image_format.dart';
export 'package:lumina/data/services/import_image_conversion.dart';
export 'package:lumina/data/services/encoded_image_decoder.dart';
export 'package:lumina/data/services/import_queue.dart';
export 'package:lumina/data/services/import_formats.dart';
export 'package:lumina/data/services/import_folder_scanner.dart';
export 'package:lumina/data/services/gltf_packer.dart';
export 'package:lumina/src/services/mesh_decimation_service.dart';
export 'package:flutter_assimp/flutter_assimp.dart';
export 'package:flutter_riglogic/flutter_riglogic.dart';

// Domain: use-case layer
export 'package:lumina/domain/models/use_case_results.dart';
export 'package:lumina/domain/use_cases/save_level_use_case.dart';
export 'package:lumina/domain/use_cases/generate_dart_code_use_case.dart';
export 'package:lumina/domain/use_cases/import_asset_use_case.dart';

// Declarative & BuildContext
export 'package:lumina/src/declarative/lumina_object.dart';
export 'package:lumina/src/declarative/build_context.dart';
export 'package:lumina/src/declarative/element.dart';
export 'package:lumina/src/declarative/build_owner.dart';
export 'package:lumina/src/declarative/runtime_object.dart';

// World & Level
export 'package:lumina/src/world/world_type.dart';
export 'package:lumina/src/world/world.dart';
export 'package:lumina/src/world/debug_shapes.dart';
export 'package:lumina/src/world/level.dart';
export 'package:lumina/src/world/level_script_actor.dart';
export 'package:lumina/src/world/level_streaming.dart';
export 'package:lumina/src/world/level_streaming_volume.dart';
export 'package:lumina/src/world/level_streaming_manager.dart';
export 'package:lumina/src/world/level_preloader.dart';
export 'package:lumina/src/world/world_partition.dart';
export 'package:lumina/src/world/world_partition_cell.dart';
export 'package:lumina/src/world/streaming_source.dart';
export 'package:lumina/src/world/data_layer.dart';
export 'package:lumina/src/world/hlod_subsystem.dart';
export 'package:lumina/src/world/subsystem/world_subsystem.dart';
export 'package:lumina/src/world/subsystem/subsystem_collection.dart';
export 'package:lumina/src/world/frame_pacing.dart';

// Objects & Controllers
export 'package:lumina/src/object/actor.dart';
export 'package:lumina/src/object/lumina_object_key.dart';
export 'package:lumina/src/object/pawn.dart';
export 'package:lumina/src/object/character.dart';
export 'package:lumina/src/controller/controller.dart';
export 'package:lumina/src/controller/player_controller.dart';
export 'package:lumina/src/controller/player_state.dart';
export 'package:lumina/src/ai/ai_controller.dart';
export 'package:lumina/src/ai/navigation_system.dart';
export 'package:lumina/src/ai/blackboard.dart';
export 'package:lumina/src/ai/behavior_tree.dart';
export 'package:lumina/src/ai/perception.dart';

// Collision & Geometry
export 'package:lumina/src/collision/shapes.dart';
export 'package:lumina/src/collision/convex_hull.dart';
export 'package:lumina/src/collision/collision_hull.dart';
export 'package:lumina/src/collision/collision_primitive.dart';
export 'package:lumina/src/collision/collision_filter.dart';
export 'package:lumina/src/collision/collision_preset.dart';
export 'package:lumina/src/collision/narrow_phase.dart';
export 'package:lumina/src/collision/gjk_epa.dart';
export 'package:lumina/src/collision/raycast_math.dart';
export 'package:lumina/src/collision/heightfield.dart';
export 'package:lumina/src/collision/collision_query.dart';
export 'package:lumina/src/collision/collision_subsystem.dart';

// Physics
export 'package:lumina/src/physics/physical_material.dart';
export 'package:lumina/src/physics/mass_properties.dart';
export 'package:lumina/src/physics/rigid_body.dart';
export 'package:lumina/src/physics/contact_generation.dart';
export 'package:lumina/src/physics/contact_solver.dart';
export 'package:lumina/src/physics/primitive_physics.dart';
export 'package:lumina/src/physics/physics_subsystem.dart';

// Components
export 'package:lumina/src/components/base/actor_component.dart';
export 'package:lumina/src/components/base/scene_component.dart';
export 'package:lumina/src/components/camera/camera_component.dart';
export 'package:lumina/src/components/camera/spring_arm_component.dart';
export 'package:lumina/src/components/collision/collision_component.dart';
export 'package:lumina/src/components/collision/capsule_component.dart';
export 'package:lumina/src/components/collision/box_component.dart';
export 'package:lumina/src/components/collision/sphere_component.dart';
export 'package:lumina/src/components/collision/cylinder_component.dart';
export 'package:lumina/src/components/collision/cone_component.dart';
export 'package:lumina/src/components/collision/convex_component.dart';
export 'package:lumina/src/components/collision/shape_wireframes.dart';
export 'package:lumina/src/components/movement/character_movement_component.dart';
export 'package:lumina/src/components/movement/kinematic_move_solver.dart';
export 'package:lumina/src/components/movement/floor_finder.dart';
export 'package:lumina/src/components/movement/projectile_movement_component.dart';
export 'package:lumina/src/components/movement/rotating_movement_component.dart';
export 'package:lumina/src/components/movement/interp_to_movement_component.dart';
export 'package:lumina/src/components/light/light_component.dart';
export 'package:lumina/src/components/light/directional_light_component.dart';
export 'package:lumina/src/components/light/point_light_component.dart';
export 'package:lumina/src/components/light/spot_light_component.dart';
export 'package:lumina/src/components/environment/sky_component.dart';
export 'package:lumina/src/components/environment/sky_binding.dart';
export 'package:lumina/src/components/environment/procedural_sky_binding.dart';
export 'package:lumina/src/components/environment/procedural_sky_component.dart';
export 'package:lumina/src/components/environment/exponential_height_fog_component.dart';
export 'package:lumina/src/components/environment/post_process_volume_component.dart';
export 'package:lumina/src/components/environment/local_fog_volume_component.dart';
export 'package:lumina/src/components/environment/reflection_capture_component.dart';
export 'package:lumina/src/components/mesh/static_mesh_component.dart';
export 'package:lumina/src/components/mesh/animated_mesh_component.dart';
export 'package:lumina/src/components/mesh/procedural_mesh_component.dart';
export 'package:lumina/src/components/mesh/instanced_static_mesh_component.dart';
export 'package:lumina/src/components/mesh/mesh_asset_cache.dart';
export 'package:lumina/src/components/mesh/skeletal_mesh_component.dart';
export 'package:lumina/src/components/mesh/skinning_buffer.dart';
export 'package:lumina/src/components/mesh/morph_target_set.dart';
export 'package:lumina/src/components/landscape/landscape_section_map.dart';
export 'package:lumina/src/components/landscape/landscape_mesh_builder.dart';
export 'package:lumina/src/components/landscape/landscape_residency.dart';
export 'package:lumina/src/components/landscape/landscape_component.dart';
export 'package:lumina/src/components/landscape/landscape_brush_cursor.dart';
export 'package:lumina/src/components/landscape/landscape_glb_builder.dart';
export 'package:lumina/src/components/player/lumina_player_component.dart';
export 'package:lumina/src/components/player/input_binding.dart';

// Material
export 'package:lumina/src/material/lumina_material.dart';
export 'package:lumina/src/material/lumina_material_instance.dart';
export 'package:lumina/src/material/dynamic_material_instance.dart';
export 'package:lumina/src/material/material_cache.dart';
export 'package:lumina/src/material/instance_material_override.dart';
export 'package:lumina/src/material/material_textures.dart';

// Input
export 'package:lumina/src/input/input_component.dart';

// Particles
export 'package:lumina/src/components/particles/particle_emitter_config.dart';
export 'package:lumina/src/components/particles/particle_system_component.dart';

// Game & Widget
export 'package:lumina/src/game/game_instance.dart';
export 'package:lumina/src/game/game_mode.dart';
export 'package:lumina/src/game/player_camera_manager.dart';
export 'package:lumina/src/game/hud_overlay.dart';
export 'package:lumina/src/game/game_state.dart';
export 'package:lumina/src/game/camera_actor.dart';
export 'package:lumina/src/game/player_start.dart';
export 'package:lumina/src/game/primitive_actor.dart';
export 'package:lumina/src/game/static_mesh_actor.dart';
export 'package:lumina/src/game/template_character.dart';
export 'package:lumina/src/game/template_content.dart';
export 'package:lumina/src/game/play_state.dart';
export 'package:lumina/src/game/lumina_game.dart';
export 'package:lumina/src/game/console.dart';
export 'package:lumina/src/game/lumina_widget.dart';

// Math
export 'package:lumina/src/math/transform_snapshot.dart';
export 'package:lumina/src/math/euler.dart';
export 'package:lumina/src/math/units.dart';
export 'package:lumina/src/math/axes.dart';
export 'package:lumina/src/blueprint/blueprint.dart';
export 'package:lumina/src/blueprint/vm/anim_blueprint_vm.dart';
export 'package:lumina/src/blueprint/vm/blueprint_vm.dart';

// Save & Persistence
export 'package:lumina/src/save/save_game.dart';
export 'package:lumina/src/save/save_game_subsystem.dart';

// Post Process & Scalability
export 'package:lumina/src/post_process/post_process_settings.dart';
export 'package:lumina/src/rendering/graphics_device.dart';
export 'package:lumina/src/rendering/render_backend_info.dart';
export 'package:lumina/src/post_process/post_process_controller.dart';
export 'package:lumina/src/post_process/post_process_blender.dart';
export 'package:lumina/src/post_process/shadow_settings.dart';
export 'package:lumina/src/post_process/scalability_profile.dart';
export 'package:lumina/src/post_process/rtx_settings.dart';
export 'package:lumina/src/post_process/fsr3_settings.dart';
export 'package:lumina/src/world/subsystem/user_settings_subsystem.dart';

// Animation
export 'package:lumina/src/animation/animation_clip.dart';
export 'package:lumina/src/animation/anim_instance.dart';
export 'package:lumina/src/animation/anim_montage.dart';
export 'package:lumina/src/animation/blend_space.dart';
export 'package:lumina/src/animation/skeleton_retargeter.dart';
export 'package:lumina/src/animation/keyframe_track.dart';
export 'package:lumina/src/animation/rig_logic_evaluator.dart';
export 'package:lumina/src/animation/locomotion_clip_set.dart';
export 'package:lumina/src/animation/directional_locomotion_component.dart';

// Utility
export 'package:lumina/src/world/entity_registry.dart';
export 'package:lumina/src/utility/timer_manager.dart';
export 'package:lumina/src/utility/gameplay_statics.dart';
export 'package:lumina/src/utility/gameplay_volumes.dart';
export 'package:lumina/src/utility/viewport_statics.dart';
export 'package:lumina/src/utility/lumina_assets.dart';
export 'package:lumina/src/utility/web_loading.dart';
export 'package:lumina/src/umg/umg_widgets.dart';
export 'package:lumina/src/umg/element_binding.dart';
export 'package:lumina/src/umg/widget_layer.dart';
export 'package:lumina/src/umg/user_widget.dart';

// Audio
export 'package:lumina/src/audio/sound_base.dart';
export 'package:lumina/src/audio/audio_backend.dart';
export 'package:lumina/src/audio/audio_subsystem.dart';
export 'package:lumina/src/components/audio/audio_component.dart';

// Media
export 'package:lumina/src/media/media.dart';

export 'package:lumina/data/services/thumbnail_service.dart';
export 'package:lumina/data/services/filament_thumbnail_renderer.dart';
export 'package:lumina/data/services/asset_reference_graph.dart';
export 'package:lumina/data/models/lumina_plugin_descriptor.dart';
export 'package:lumina/data/repositories/plugin_repository.dart';
export 'package:lumina/data/services/plugin_registry_service.dart';
export 'package:lumina/data/services/plugin_host_patcher_service.dart';
export 'package:lumina/data/services/editor_host_generator_service.dart';
export 'package:lumina/data/services/editor_build_fingerprint.dart';
export 'package:lumina/data/services/editor_source_vendor_service.dart';
export 'package:lumina/data/services/editor_build_cache.dart';
export 'package:lumina/data/services/editor_build_service.dart';
export 'package:lumina/data/services/space_free_build_dir.dart';
export 'package:lumina/data/services/plugin_template_generator_service.dart';
export 'package:lumina/data/services/project_engine_link.dart';
export 'package:lumina/data/services/lumina_data_dir.dart';
export 'package:lumina/data/services/engine_bootstrap.dart';
export 'package:lumina/data/services/engine_identity.dart';


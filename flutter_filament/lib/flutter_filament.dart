/// Dart FFI bindings for Google Filament 3D rendering engine.
///
/// This library provides a high-level, idiomatic Dart API for creating
/// 3D scenes and rendering them using the Filament engine on macOS and Linux.
///
/// ## Quick Start
///
/// ```dart
/// import 'package:flutter_filament/flutter_filament.dart';
///
/// void main() {
///   final engine = FilamentEngine.create();
///   final renderer = engine.createRenderer();
///   final scene = engine.createScene();
///   final view = engine.createView();
///
///   view.scene = scene;
///   // ... configure camera, add renderables, etc.
///
///   engine.dispose();
/// }
/// ```
library;

export 'src/camera.dart';
export 'src/debug_registry.dart';
export 'src/draco_decoder.dart';
export 'src/engine.dart' hide markHostOwnedEngine, disposeHostOwnedEngine;
export 'src/engine_host.dart';
export 'src/gpu.dart';
export 'src/entity.dart';
export 'src/fence.dart';
export 'src/filamat_builder.dart';
export 'src/matc.dart';
export 'src/frame_pacer.dart';
export 'src/frame_pipeline_estimator.dart';
export 'src/gltf_loader.dart';
export 'src/animation_state_machine.dart';

export 'src/index_buffer.dart';
export 'src/indirect_light.dart';
export 'src/light.dart';
export 'src/manipulator.dart';
export 'src/material.dart';
export 'src/motion_vectors.dart';
export 'src/render_target.dart';
export 'src/renderable.dart';
export 'src/renderer.dart';
export 'src/scene.dart';
export 'src/skybox.dart';
export 'src/swap_chain.dart';
export 'src/texture.dart';
export 'src/tools.dart';
export 'src/transform.dart';
export 'src/vertex_buffer.dart';
export 'src/view.dart';
export 'src/view_options.dart';
export 'src/widget.dart';
export 'src/editor_primitives.dart';
export 'src/buffer_descriptor.dart';
export 'src/buffer_object.dart';
export 'src/callback_bridge.dart';
export 'src/enums.dart';
export 'src/math_types.dart' if (dart.library.js_interop) 'src/math_types.web.g.dart';
export 'src/web_init.dart';
export 'src/instance.dart';
export 'src/texture_sampler.dart';
export 'src/texture_provider.dart';
export 'src/exceptions.dart';
export 'src/skinning_buffer.dart';
export 'src/diagnostics.dart';
export 'src/tangent_space_mesh.dart';
export 'src/name_component_manager.dart';
export 'src/transcoder.dart';
export 'src/filamesh.dart';
export 'src/ktx2_reader.dart';
export 'src/ktx1.dart';
export 'src/iblprefilter.dart';
export 'src/math/box.dart';
export 'src/math/frustum.dart';
export 'src/math/color.dart';
export 'src/math/exposure.dart';
export 'src/math/viewport.dart';
export 'src/math/norm.dart';
export 'src/math/transform_util.dart';
export 'src/color_grading.dart';
export 'src/frame_history_stream.dart';
export 'src/morph_target_buffer.dart';
export 'src/instance_buffer.dart';
export 'src/linear_image.dart';
export 'src/image_sampler.dart';
export 'src/image_ops.dart';
export 'src/color_transform.dart';
export 'src/image_sdf.dart';
export 'src/imageio.dart';
export 'src/ibl_cubemap.dart';
export 'src/ibl_sh.dart';
export 'src/ibl_bake.dart';

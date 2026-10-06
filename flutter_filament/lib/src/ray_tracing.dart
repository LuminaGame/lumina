import 'filament_bindings.dart' as c;

/// Ray tracing on the Vulkan backend (`VK_KHR_ray_query`): the device
/// extensions are requested before the engine exists, the scene keeps
/// acceleration structures ([FilamentScene.rayTracingEnabled]), the sun can
/// trace hard shadows ([ShadowOptions.rayTraced]) and views answer visibility
/// rays ([FilamentView.traceRay]).
///
/// Order of operations:
///
/// 1. [requestExtensions] **before** `FilamentEngine.create` (the request is
///    kept next to the DLSS one, so either may come first).
/// 2. Create the engine on the Vulkan backend; [FilamentEngine.supportsRayQuery]
///    tells whether the GPU and driver provide ray queries.
/// 3. `scene.rayTracingEnabled = true`, then render: the structures are rebuilt
///    every frame from the world transforms of the renderables.
///
/// Everything else keeps working without support: the scene flag is kept but
/// builds nothing, ray-traced shadows fall back to the shadow maps and rays
/// report no hit.
abstract final class RayTracing {
  /// Asks the engines created from now on for the Vulkan ray query extensions.
  ///
  /// Returns false where there is no desktop Vulkan backend (web, Android,
  /// macOS); nothing changes there.
  static bool requestExtensions() => c.filament_ray_tracing_request_extensions();

  /// Later engines are created without the ray query extensions.
  static void clearExtensionRequest() => c.filament_ray_tracing_clear_extension_request();
}

/// What a visibility ray hit ([FilamentView.traceRay],
/// [FilamentScene.traceVisibility]).
class RayHit {
  const RayHit({required this.t, required this.entity, required this.primitive});

  /// Distance from the ray origin to the hit, in world units.
  final double t;

  /// The renderable entity hit.
  final int entity;

  /// Index of the triangle hit within its geometry.
  final int primitive;

  @override
  String toString() => 'RayHit(t: $t, entity: $entity, primitive: $primitive)';
}

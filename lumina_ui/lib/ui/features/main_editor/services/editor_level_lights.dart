import 'package:flutter_filament/flutter_filament.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

import '../view_models/editor_view_model.dart';
import 'light_actor_properties.dart';
import 'pie_controller.dart';

/// The level's own lights in the edit-mode viewport: every `DirectionalLight` / `PointLight` / `SpotLight` actor
/// becomes the component PIE and the generated game build for it
/// ([EditorPieGame.mapEditorActor] — one conversion, cm Z-up → runtime), in
/// an editor world bound to the viewport's scene. Details edits, gizmo
/// moves, visibility, deletion and undo are followed on every [sync]; a
/// level without light actors is lit by nothing.
class EditorLevelLights {
  /// Actor types realised here (the ones `mapEditorActor` turns into light
  /// components).
  static const Set<String> lightTypes = {'Light', 'DirectionalLight', 'PointLight', 'SpotLight'};

  LuminaWorld? _world;
  final Map<String, _RealisedLight> _lights = {};

  bool get isAttached => _world != null;

  /// The Filament light entities in the scene now.
  List<int> get lightEntities => [
        for (final l in _lights.values)
          if (l.component.lightEntity != null) l.component.lightEntity!,
      ];

  /// The light components realised now, for the viewport's exposure
  /// metering.
  List<LuminaLightComponent> get components => [for (final l in _lights.values) l.component];

  /// Binds to the viewport's engine and scene (an editor world: it runs no
  /// gameplay, only render prep).
  void attach(FilamentEngine engine, FilamentScene scene) {
    detach();
    _world = LuminaWorld(worldType: LuminaWorldType.editor)..initializeNativeContext(engine, scene);
  }

  /// Makes the scene's lights match [actors]: the visible light actors when
  /// [enabled] (Lit, Lighting shown, no Play session lighting the scene),
  /// none otherwise.
  void sync(Iterable<EditorActorNode> actors, {required bool enabled, bool Function(String id)? isVisible}) {
    final world = _world;
    if (world == null) return;
    final wanted = <String, EditorActorNode>{
      if (enabled)
        for (final a in actors)
          if (lightTypes.contains(a.type) && (isVisible?.call(a.id) ?? a.isVisible)) a.id: a,
    };
    for (final id in _lights.keys.where((id) => !wanted.containsKey(id)).toList()) {
      _remove(world, id);
    }
    var moved = false;
    for (final node in wanted.values) {
      final existing = _lights[node.id];
      final signature = _signature(node);
      if (existing != null && existing.type == node.type) {
        if (existing.signature == signature) continue;
        // Same kind of light: update it in place (no new Filament light),
        // unless something only the builder sets changed (the sun disc).
        final built = EditorPieGame.mapEditorActor(node);
        final fresh = built is LuminaActor ? built.rootComponent : null;
        final c = existing.component;
        final rebuild = fresh is LuminaDirectionalLightComponent &&
            c is LuminaDirectionalLightComponent &&
            fresh.sunAngularRadius != c.sunAngularRadius;
        if (fresh is LuminaLightComponent && !rebuild) {
          c.relativeLocation = fresh.relativeLocation;
          c.relativeRotation = fresh.relativeRotation;
          c.color = Vector3.copy(fresh.color);
          c.intensity = fresh.intensity;
          c.castShadows = fresh.castShadows;
          // Attenuation radius and cone angles, live on Filament.
          if (fresh is LuminaPointLightComponent && c is LuminaPointLightComponent) {
            c.falloffRadius = fresh.falloffRadius;
          } else if (fresh is LuminaSpotLightComponent && c is LuminaSpotLightComponent) {
            c.falloffRadius = fresh.falloffRadius;
            c.setConeAngles(innerDegrees: fresh.innerConeAngleDegrees, outerDegrees: fresh.outerConeAngleDegrees);
          }
          existing.signature = signature;
          moved = true;
          continue;
        }
        _remove(world, node.id);
      } else if (existing != null) {
        _remove(world, node.id);
      }
      final built = EditorPieGame.mapEditorActor(node);
      if (built is! LuminaActor || built.rootComponent is! LuminaLightComponent) continue;
      world.persistentLevel.registerActor(built);
      _lights[node.id] = _RealisedLight(node.type, built, built.rootComponent as LuminaLightComponent, signature);
      moved = true;
    }
    // Render prep pushes the components' transforms to Filament.
    if (moved) world.tick(0.0);
  }

  void _remove(LuminaWorld world, String id) {
    final light = _lights.remove(id);
    if (light == null) return;
    world.persistentLevel.unregisterActor(light.actor);
  }

  static String _signature(EditorActorNode a) => [
        a.type,
        ...a.location,
        ...a.rotation,
        LightActorProperties.read(a).signature,
      ].join('|');

  /// Removes every light from the scene and drops the world.
  void detach() {
    final world = _world;
    if (world == null) return;
    for (final id in _lights.keys.toList()) {
      _remove(world, id);
    }
    world.cleanup();
    _world = null;
  }
}

class _RealisedLight {
  _RealisedLight(this.type, this.actor, this.component, this.signature);
  final String type;
  final LuminaActor actor;
  final LuminaLightComponent component;
  String signature;
}

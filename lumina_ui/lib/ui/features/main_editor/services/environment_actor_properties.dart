import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4, Vector3;

import 'package:lumina_ui/ui/features/details/models/editor_component_node.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';

/// The placeable environment actors, resolved
/// the one way every consumer agrees on, as `LightActorProperties` does for
/// lights: the catalog seeds the component, the Details panel edits
/// it, the edit-mode viewport (`EditorLevelPostProcess`), Play
/// (`EditorPieGame.mapEditorActor`) and the code generator all read the same
/// `properties` map through lumina's own parsers, so the editor and the game
/// cannot disagree.
///
/// Filament's limits, stated once: one global exponential height fog per
/// view (`ExponentialHeightFog` maps to it field for field); one
/// post-process state per view, so a `PostProcessVolume` blends by camera
/// position, never per pixel; no volumetric scattering, so a `LocalFogVolume`
/// is a fog-shell approximation.
class EnvironmentActorProperties {
  const EnvironmentActorProperties._();

  static const String heightFogType = 'ExponentialHeightFog';
  static const String postProcessVolumeType = 'PostProcessVolume';
  static const String localFogVolumeType = 'LocalFogVolume';

  static const String heightFogComponentType = 'LuminaExponentialHeightFogComponent';
  static const String postProcessVolumeComponentType = 'LuminaPostProcessVolumeComponent';
  static const String localFogVolumeComponentType = 'LuminaLocalFogVolumeComponent';

  /// Actor types the environment post-process service realises.
  static const Set<String> actorTypes = {heightFogType, postProcessVolumeType, localFogVolumeType};

  static bool isEnvironmentActor(EditorActorNode a) => actorTypes.contains(a.type);
  static bool isVolume(EditorActorNode a) => a.type == postProcessVolumeType || a.type == localFogVolumeType;

  /// The component type that carries an environment actor's settings.
  static String? componentTypeFor(String actorType) => switch (actorType) {
        heightFogType => heightFogComponentType,
        postProcessVolumeType => postProcessVolumeComponentType,
        localFogVolumeType => localFogVolumeComponentType,
        _ => null,
      };

  /// [actor]'s settings component, if it has one.
  static EditorComponentNode? componentOf(EditorActorNode actor) {
    final type = componentTypeFor(actor.type);
    if (type == null) return null;
    for (final c in actor.components) {
      if (c.type == type) return c;
    }
    return null;
  }

  /// The `properties` map of [actor]'s settings component, or empty.
  static Map<String, dynamic> propertiesOf(EditorActorNode actor) =>
      Map<String, dynamic>.from(componentOf(actor)?.properties ?? const <String, dynamic>{});

  // --- Seeds (what a freshly placed actor starts with) ----------------------

  static EditorComponentNode seedHeightFog(String actorId) => EditorComponentNode(
        id: '${actorId}_heightfog',
        type: heightFogComponentType,
        name: 'Exponential Height Fog',
        properties: LuminaHeightFogSettings.defaults.toProperties(),
      );

  /// Conventional defaults for the value rows; every override starts off.
  static Map<String, dynamic> postProcessVolumeDefaults() => <String, dynamic>{
        'extentX': 400.0,
        'extentY': 400.0,
        'extentZ': 400.0,
        'unbound': false,
        'enabled': true,
        'priority': 0.0,
        'blendRadius': 100.0,
        'blendWeight': 1.0,
        for (final k in LuminaPostProcessOverrides.keys) LuminaPostProcessOverrides.overrideKey(k): false,
        'bloomIntensity': 0.675,
        'bloomThreshold': 1000.0,
        'vignette': 0.0,
        'depthOfFieldEnabled': false,
        'dofFocusDistance': 1000.0,
        'dofAperture': 1.0,
        'ambientOcclusionEnabled': true,
        'ambientOcclusionIntensity': 1.0,
        'exposure': 0.0,
        'contrast': 1.0,
        'saturation': 1.0,
        'temperature': 0.0,
        'taaEnabled': false,
      };

  static EditorComponentNode seedPostProcessVolume(String actorId) => EditorComponentNode(
        id: '${actorId}_ppvolume',
        type: postProcessVolumeComponentType,
        name: 'Post Process Volume',
        properties: postProcessVolumeDefaults(),
      );

  static Map<String, dynamic> localFogVolumeDefaults() => <String, dynamic>{
        'shape': 'sphere',
        'radius': 500.0,
        'extentX': 500.0,
        'extentY': 500.0,
        'extentZ': 500.0,
        'fogAlbedoHex': '#CCD9E6',
        'fogDensity': 0.35,
        'heightFalloff': 0.5,
        'radialAttenuation': 0.7,
        'enabled': true,
      };

  static EditorComponentNode seedLocalFogVolume(String actorId) => EditorComponentNode(
        id: '${actorId}_localfog',
        type: localFogVolumeComponentType,
        name: 'Local Fog Volume',
        properties: localFogVolumeDefaults(),
      );

  // --- Resolvers ------------------------------------------------------------

  /// The level's height fog actor (the first visible `ExponentialHeightFog`),
  /// or null when the level has none — then the Environment editor's global
  /// Height Fog section is the fallback.
  static EditorActorNode? heightFogActorOf(Iterable<EditorActorNode> actors, {bool Function(String id)? isVisible}) {
    for (final a in actors) {
      if (a.type == heightFogType && (isVisible?.call(a.id) ?? a.isVisible)) return a;
    }
    return null;
  }

  /// The settings the height fog actor publishes: its properties with its
  /// authored Z as the runtime height.
  static LuminaHeightFogSettings heightFogSettings(EditorActorNode actor) =>
      LuminaHeightFogSettings.fromProperties(propertiesOf(actor), height: LuminaAxes.location(actor.location).y);

  /// The actor's world matrix in runtime axes (the one conversion the
  /// viewport, PIE and the generated level share).
  static Matrix4 runtimeTransform(EditorActorNode actor) => Matrix4.compose(
        LuminaAxes.location(actor.location),
        LuminaAxes.rotation(actor.rotation),
        LuminaAxes.scale(actor.scale),
      );

  /// The half extent of a volume actor in runtime axes, before its scale
  /// (a `PostProcessVolume`'s `extentX/Y/Z`, a box `LocalFogVolume`'s, or a
  /// sphere's radius on every axis).
  static Vector3 runtimeHalfExtent(EditorActorNode actor) {
    final p = propertiesOf(actor);
    double num_(String k, double d) => p[k] is num ? (p[k] as num).toDouble() : d;
    if (actor.type == localFogVolumeType && luminaLocalFogShapeFrom(p['shape'] as String?) == LuminaLocalFogShape.sphere) {
      return Vector3.all(num_('radius', 500.0));
    }
    final d = actor.type == localFogVolumeType ? 500.0 : 400.0;
    return LuminaAxes.scale([num_('extentX', d), num_('extentY', d), num_('extentZ', d)]);
  }

  /// Whether a `PostProcessVolume` actor is unbound (draws no box, applies
  /// everywhere).
  static bool isUnbound(EditorActorNode actor) => propertiesOf(actor)['unbound'] == true;

  /// Whether a `LocalFogVolume` actor is a sphere.
  static bool isSphere(EditorActorNode actor) =>
      actor.type == localFogVolumeType &&
      luminaLocalFogShapeFrom(propertiesOf(actor)['shape'] as String?) == LuminaLocalFogShape.sphere;

  /// Everything that changes what the runtime component does, for change
  /// detection.
  static String signature(EditorActorNode a) {
    final p = propertiesOf(a);
    final keys = p.keys.toList()..sort();
    return [a.type, ...a.location, ...a.rotation, ...a.scale, a.isVisible, for (final k in keys) '$k=${p[k]}'].join('|');
  }
}

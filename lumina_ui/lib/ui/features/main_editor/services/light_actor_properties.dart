import 'package:lumina_ui/ui/features/details/models/editor_component_node.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';

/// A light actor's settings, resolved the one way every consumer agrees on:
/// the Details panel's "Light" section, the edit-mode viewport
/// (`EditorLevelLights`), Play (`EditorPieGame.mapEditorActor`) and the code
/// generator all read the light's own component
/// (`LuminaDirectionalLightComponent` / `LuminaPointLightComponent` /
/// `LuminaSpotLightComponent`, the type `componentTypeFor` names), falling
/// back to the actor-level `lightIntensity` / `lightColorHex` / `castShadows`
/// that levels from before the section carry.
///
/// Units follow the runtime: lux for a directional light, lumens for point and
/// spot lights, centimetres for the attenuation radius, degrees for angles.
class LightActorProperties {
  const LightActorProperties({
    required this.intensity,
    required this.colorHex,
    required this.castShadows,
    required this.attenuationRadius,
    required this.innerConeAngle,
    required this.outerConeAngle,
    required this.sunAngularRadius,
  });

  final double intensity;
  final String colorHex;
  final bool castShadows;

  /// Point/spot sphere of influence, cm (Attenuation Radius).
  final double attenuationRadius;

  /// Spot cone angles, degrees (`0 < inner <= outer <= 90`).
  final double innerConeAngle;
  final double outerConeAngle;

  /// The sun disc's angular radius, degrees (directional).
  final double sunAngularRadius;

  /// Actor types the section applies to.
  static const Set<String> lightActorTypes = {'Light', 'DirectionalLight', 'PointLight', 'SpotLight'};

  static bool isLightActor(EditorActorNode actor) => lightActorTypes.contains(actor.type);

  /// The component type that carries a light actor's settings.
  static String componentTypeFor(String actorType) => switch (actorType) {
        'PointLight' => 'LuminaPointLightComponent',
        'SpotLight' => 'LuminaSpotLightComponent',
        _ => 'LuminaDirectionalLightComponent',
      };

  static const double defaultAttenuationRadius = 1000.0;
  static const double defaultInnerConeAngle = 30.0;
  static const double defaultOuterConeAngle = 45.0;
  static const double defaultSunAngularRadius = 0.545;

  /// The light component of [actor], if it has one.
  static EditorComponentNode? componentOf(EditorActorNode actor) {
    final type = componentTypeFor(actor.type);
    for (final c in actor.components) {
      if (c.type == type) return c;
    }
    // A sun the Environment mixer created on a plain `Light` actor.
    for (final c in actor.components) {
      if (c.type == 'LuminaDirectionalLightComponent') return c;
    }
    return null;
  }

  /// The component a freshly placed light of [actorType] starts with:
  /// the settings the Details panel edits, seeded from the catalog's
  /// intensity.
  static EditorComponentNode seedComponent(String actorId, String actorType, {required double intensity}) {
    final type = componentTypeFor(actorType);
    return EditorComponentNode(
      id: '${actorId}_light',
      type: type,
      name: 'Light',
      properties: <String, dynamic>{
        'intensity': intensity,
        'colorHex': '#FFFFFF',
        'castShadows': type == 'LuminaDirectionalLightComponent',
        if (type != 'LuminaDirectionalLightComponent') 'attenuationRadius': defaultAttenuationRadius,
        if (type == 'LuminaSpotLightComponent') ...{
          'innerConeAngle': defaultInnerConeAngle,
          'outerConeAngle': defaultOuterConeAngle,
        },
        if (type == 'LuminaDirectionalLightComponent') 'sunAngularRadius': defaultSunAngularRadius,
      },
    );
  }

  /// Gives an older light actor (actor-level fields only) its
  /// component, carrying the values it had, so the Details panel can edit
  /// it. Returns the component, existing or new; null for other actors.
  static EditorComponentNode? ensureComponent(EditorActorNode actor) {
    if (!isLightActor(actor)) return null;
    final existing = componentOf(actor);
    if (existing != null) return existing;
    final seeded = seedComponent(actor.id, actor.type, intensity: actor.lightIntensity)
      ..properties['colorHex'] = actor.lightColorHex
      ..properties['castShadows'] = actor.castShadows;
    actor.components.add(seeded);
    return seeded;
  }

  /// [actor]'s settings as every consumer sees them.
  static LightActorProperties read(EditorActorNode actor) {
    final p = componentOf(actor)?.properties ?? const <String, dynamic>{};
    final directional = componentTypeFor(actor.type) == 'LuminaDirectionalLightComponent';
    // The Environment mixer derives `effectiveColorHex` from its kelvin
    // unless the colour is overridden; a colour typed in Details is
    // `colorHex`, which then wins.
    final mixerColour = p['colorOverride'] == false && p['effectiveColorHex'] is String ? p['effectiveColorHex'] as String : null;
    final inner = _num(p['innerConeAngle'], defaultInnerConeAngle).clamp(0.01, 90.0);
    return LightActorProperties(
      intensity: _num(p['intensity'], actor.lightIntensity),
      colorHex: mixerColour ?? (p['colorHex'] as String?) ?? (p['effectiveColorHex'] as String?) ?? actor.lightColorHex,
      castShadows: p['castShadows'] is bool ? p['castShadows'] as bool : actor.castShadows,
      attenuationRadius: _num(p['attenuationRadius'], defaultAttenuationRadius).clamp(1.0, 1e7),
      innerConeAngle: inner,
      outerConeAngle: _num(p['outerConeAngle'], defaultOuterConeAngle).clamp(inner, 90.0),
      sunAngularRadius: directional ? _num(p['sunAngularRadius'], defaultSunAngularRadius) : defaultSunAngularRadius,
    );
  }

  static double _num(dynamic v, double fallback) => v is num ? v.toDouble() : fallback;

  /// Everything that changes what Filament draws, for change detection.
  String get signature =>
      '$intensity|$colorHex|$castShadows|$attenuationRadius|$innerConeAngle|$outerConeAngle|$sunAngularRadius';

  @override
  String toString() => 'LightActorProperties($signature)';
}

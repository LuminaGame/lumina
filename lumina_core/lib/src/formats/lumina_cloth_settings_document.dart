import 'dart:convert';
import 'dart:math' as math;

import 'package:lumina_core/src/formats/lumina_asset.dart';

/// Cloth settings shared by cloths through a `.lmas` asset of
/// [AssetType.clothSettings] (its `raw_payload` is this document as JSON):
/// how heavy, stiff and damped the cloth is, how the wind pulls it, how it
/// follows a moving owner and whether it collides with itself. A cloth
/// component that names the asset (`clothSettingsAsset`) takes these values
/// in place of its own; the keys are the component's property keys.
class LuminaClothSettingsDocument {
  const LuminaClothSettingsDocument({
    this.massKg = 1.0,
    this.stiffness = 0.95,
    this.bendStiffness = 0.3,
    this.damping = 0.5,
    this.friction = 0.5,
    this.thickness = 1.0,
    this.iterations = 8,
    this.gravityScale = 1.0,
    this.windDrag = 1.0,
    this.windTurbulence = 0.3,
    this.inertiaScale = 1.0,
    this.teleportDistance = 100,
    this.teleportRotation = 60,
    this.selfCollision = false,
    this.selfCollisionDistance = 2.0,
  });

  /// The whole cloth's mass (kg).
  final double massKg;

  /// Stretch and bend stiffness (0..1; bend 0 bends freely).
  final double stiffness, bendStiffness;
  final double damping, friction;

  /// The distance (cm) the cloth keeps from surfaces.
  final double thickness;
  final int iterations;
  final double gravityScale;

  /// The wind's pull per second and its gustiness (0..1).
  final double windDrag, windTurbulence;

  /// How much of its owner's motion the cloth resists (0..1), and the move
  /// (cm) or turn (degrees) within one step that is a teleport.
  final double inertiaScale, teleportDistance, teleportRotation;

  /// Whether the cloth keeps [selfCollisionDistance] cm between its layers.
  final bool selfCollision;
  final double selfCollisionDistance;

  /// The property keys and value ranges an editor offers.
  static const Map<String, (double, double)> ranges = {
    'massKg': (0.01, 50),
    'stiffness': (0, 1),
    'bendStiffness': (0, 1),
    'damping': (0, 5),
    'friction': (0, 2),
    'thickness': (0, 10),
    'iterations': (1, 32),
    'gravityScale': (0, 3),
    'windDrag': (0, 10),
    'windTurbulence': (0, 1),
    'inertiaScale': (0, 1),
    'teleportDistance': (1, 1000),
    'teleportRotation': (1, 180),
    'selfCollisionDistance': (0.1, 20),
  };

  /// The settings as cloth component properties.
  Map<String, Object> toProperties() => {
        'massKg': massKg,
        'stiffness': stiffness,
        'bendStiffness': bendStiffness,
        'damping': damping,
        'friction': friction,
        'thickness': thickness,
        'iterations': iterations,
        'gravityScale': gravityScale,
        'windDrag': windDrag,
        'windTurbulence': windTurbulence,
        'inertiaScale': inertiaScale,
        'teleportDistance': teleportDistance,
        'teleportRotation': teleportRotation,
        'selfCollision': selfCollision,
        'selfCollisionDistance': selfCollisionDistance,
      };

  /// Settings from cloth component properties (missing keys at their
  /// defaults, numbers clamped to [ranges]).
  factory LuminaClothSettingsDocument.fromProperties(Map<String, dynamic> p) {
    const d = LuminaClothSettingsDocument();
    double n(String key, double fallback) {
      final v = (p[key] as num?)?.toDouble() ?? fallback;
      final r = ranges[key];
      return r == null ? v : v.clamp(r.$1, r.$2).toDouble();
    }

    return LuminaClothSettingsDocument(
      massKg: n('massKg', d.massKg),
      stiffness: n('stiffness', d.stiffness),
      bendStiffness: n('bendStiffness', d.bendStiffness),
      damping: n('damping', d.damping),
      friction: n('friction', d.friction),
      thickness: n('thickness', d.thickness),
      iterations: n('iterations', d.iterations.toDouble()).round(),
      gravityScale: n('gravityScale', d.gravityScale),
      windDrag: n('windDrag', d.windDrag),
      windTurbulence: n('windTurbulence', d.windTurbulence),
      inertiaScale: n('inertiaScale', d.inertiaScale),
      teleportDistance: n('teleportDistance', d.teleportDistance),
      teleportRotation: n('teleportRotation', d.teleportRotation),
      selfCollision: p['selfCollision'] as bool? ?? d.selfCollision,
      selfCollisionDistance: n('selfCollisionDistance', d.selfCollisionDistance),
    );
  }

  /// A copy with [key] set to [value] (a property key; numbers clamped).
  LuminaClothSettingsDocument withValue(String key, Object value) =>
      LuminaClothSettingsDocument.fromProperties({...toProperties(), key: value});

  String toJson() => jsonEncode(toProperties());

  factory LuminaClothSettingsDocument.fromJson(String json) {
    final decoded = jsonDecode(json);
    return LuminaClothSettingsDocument.fromProperties(decoded is Map<String, dynamic> ? decoded : const {});
  }

  /// The settings as a `.lmas` asset named [name].
  LuminaAsset toAsset({required String name, String? assetId}) => LuminaAsset(
        assetId: assetId ?? 'cloth_settings_${name.toLowerCase()}',
        name: name,
        type: AssetType.clothSettings,
        rawPayload: utf8.encode(toJson()),
      );

  /// The settings a cloth settings asset holds (defaults when it holds none).
  factory LuminaClothSettingsDocument.fromAsset(LuminaAsset asset) {
    final payload = asset.rawPayload;
    if (payload == null || payload.isEmpty) return const LuminaClothSettingsDocument();
    try {
      return LuminaClothSettingsDocument.fromJson(utf8.decode(payload));
    } on FormatException {
      return const LuminaClothSettingsDocument();
    }
  }

  @override
  bool operator ==(Object other) =>
      other is LuminaClothSettingsDocument && jsonEncode(other.toProperties()) == jsonEncode(toProperties());

  @override
  int get hashCode => toJson().hashCode;

  /// Whether [key] is a whole number setting.
  static bool isInteger(String key) => key == 'iterations';

  /// The smallest step an editor offers for [key].
  static double step(String key) {
    final r = ranges[key];
    if (r == null || isInteger(key)) return 1;
    return math.max(0.01, (r.$2 - r.$1) / 1000);
  }
}

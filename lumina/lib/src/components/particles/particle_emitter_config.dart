import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart';

/// Instantaneous particle burst event at a specific time in the emitter cycle.
class LuminaParticleBurst {
  final double time;
  final int count;

  const LuminaParticleBurst(this.time, this.count);
}

/// Color gradient stop along normalized particle lifetime [0, 1].
class LuminaGradientStop {
  final double t;
  final Vector4 rgba;

  const LuminaGradientStop(this.t, this.rgba);
}

/// Scale curve point along normalized particle lifetime [0, 1].
class LuminaCurvePoint {
  final double t;
  final double scale;

  const LuminaCurvePoint(this.t, this.scale);
}

/// Immutable configuration template for particle emitter simulation and rendering properties.
class LuminaParticleEmitterConfig {
  final double spawnRate;
  final List<LuminaParticleBurst> bursts;
  final int maxParticles;

  final double lifetimeMin;
  final double lifetimeMax;

  final double speedMin;
  final double speedMax;
  final double coneAngleDegrees;
  final Vector3 inheritVelocityScale;

  final Vector3 gravity;
  final double drag;

  final List<LuminaGradientStop> colorOverLife;
  final List<LuminaCurvePoint> sizeOverLife;

  final bool looping;
  final double duration;
  final String? meshAssetPath;
  final bool billboard;

  LuminaParticleEmitterConfig({
    this.spawnRate = 10.0,
    this.bursts = const [],
    this.maxParticles = 256,
    this.lifetimeMin = 1.0,
    this.lifetimeMax = 1.0,
    this.speedMin = 100.0, // cm/s
    this.speedMax = 100.0,
    this.coneAngleDegrees = 45.0,
    Vector3? inheritVelocityScale,
    Vector3? gravity,
    this.drag = 0.0,
    this.colorOverLife = const [],
    this.sizeOverLife = const [],
    this.looping = true,
    this.duration = 1.0,
    this.meshAssetPath,
    this.billboard = true,
  })  : inheritVelocityScale = inheritVelocityScale ?? Vector3.zero(),
        gravity = gravity ?? Vector3(0.0, -980.0, 0.0);

  /// The config as the particle editor stores it (a PARTICLE `.lmas`'s
  /// `metadata['particle_system']` emitter `config`): authoring units, lists
  /// for vectors. [fromJson] reads it back.
  Map<String, dynamic> toJson() => {
        'spawnRate': spawnRate,
        'bursts': [for (final b in bursts) {'time': b.time, 'count': b.count}],
        'maxParticles': maxParticles,
        'lifetimeMin': lifetimeMin,
        'lifetimeMax': lifetimeMax,
        'speedMin': speedMin,
        'speedMax': speedMax,
        'coneAngleDegrees': coneAngleDegrees,
        'inheritVelocityScale': [inheritVelocityScale.x, inheritVelocityScale.y, inheritVelocityScale.z],
        'gravity': [gravity.x, gravity.y, gravity.z],
        'drag': drag,
        'colorOverLife': [
          for (final c in colorOverLife) {'t': c.t, 'rgba': [c.rgba.x, c.rgba.y, c.rgba.z, c.rgba.w]}
        ],
        'sizeOverLife': [for (final p in sizeOverLife) {'t': p.t, 'scale': p.scale}],
        'looping': looping,
        'duration': duration,
        'meshAssetPath': meshAssetPath,
        'billboard': billboard,
      };

  /// Reads [toJson]'s map; a missing field keeps the constructor default
  /// (the generated registry and Play-In-Editor build `Spawn
  /// Emitter` templates from particle assets with it).
  factory LuminaParticleEmitterConfig.fromJson(Map<String, dynamic> map) {
    double d(Object? v, double fallback) => (v as num?)?.toDouble() ?? fallback;
    Vector3? v3(Object? v) => v is List && v.length >= 3 ? Vector3(d(v[0], 0), d(v[1], 0), d(v[2], 0)) : null;
    final defaults = LuminaParticleEmitterConfig();
    final mesh = map['meshAssetPath'];
    return LuminaParticleEmitterConfig(
      spawnRate: d(map['spawnRate'], defaults.spawnRate),
      bursts: [
        for (final b in (map['bursts'] as List? ?? const []).whereType<Map>()) LuminaParticleBurst(d(b['time'], 0), (b['count'] as num?)?.toInt() ?? 0),
      ],
      maxParticles: (map['maxParticles'] as num?)?.toInt() ?? defaults.maxParticles,
      lifetimeMin: d(map['lifetimeMin'], defaults.lifetimeMin),
      lifetimeMax: d(map['lifetimeMax'], defaults.lifetimeMax),
      speedMin: d(map['speedMin'], defaults.speedMin),
      speedMax: d(map['speedMax'], defaults.speedMax),
      coneAngleDegrees: d(map['coneAngleDegrees'], defaults.coneAngleDegrees),
      inheritVelocityScale: v3(map['inheritVelocityScale']),
      gravity: v3(map['gravity']),
      drag: d(map['drag'], defaults.drag),
      colorOverLife: [
        for (final c in (map['colorOverLife'] as List? ?? const []).whereType<Map>())
          LuminaGradientStop(d(c['t'], 0), () {
            final rgba = c['rgba'] is List ? c['rgba'] as List : const [];
            double at(int i) => i < rgba.length ? d(rgba[i], 1) : 1.0;
            return Vector4(at(0), at(1), at(2), at(3));
          }()),
      ],
      sizeOverLife: [
        for (final p in (map['sizeOverLife'] as List? ?? const []).whereType<Map>()) LuminaCurvePoint(d(p['t'], 0), d(p['scale'], 1)),
      ],
      looping: map['looping'] as bool? ?? defaults.looping,
      duration: d(map['duration'], defaults.duration),
      meshAssetPath: mesh is String && mesh.isNotEmpty ? mesh : null,
      billboard: map['billboard'] as bool? ?? defaults.billboard,
    );
  }

  /// Evaluates the particle scale multiplier at normalized lifetime [t] (0.0 to 1.0).
  double sampleSizeAt(double t) {
    if (sizeOverLife.isEmpty) return 1.0;
    final clampedT = t.clamp(0.0, 1.0);

    if (clampedT <= sizeOverLife.first.t) return sizeOverLife.first.scale;
    if (clampedT >= sizeOverLife.last.t) return sizeOverLife.last.scale;

    for (int i = 0; i < sizeOverLife.length - 1; i++) {
      final p0 = sizeOverLife[i];
      final p1 = sizeOverLife[i + 1];
      if (clampedT >= p0.t && clampedT <= p1.t) {
        final span = p1.t - p0.t;
        if (span <= 1e-6) return p0.scale;
        final factor = (clampedT - p0.t) / span;
        return p0.scale + (p1.scale - p0.scale) * factor;
      }
    }
    return 1.0;
  }

  /// Evaluates the particle RGBA color at normalized lifetime [t] (0.0 to 1.0).
  Vector4 sampleColorAt(double t) {
    if (colorOverLife.isEmpty) return Vector4(1.0, 1.0, 1.0, 1.0);
    final clampedT = t.clamp(0.0, 1.0);

    if (clampedT <= colorOverLife.first.t) return colorOverLife.first.rgba;
    if (clampedT >= colorOverLife.last.t) return colorOverLife.last.rgba;

    for (int i = 0; i < colorOverLife.length - 1; i++) {
      final s0 = colorOverLife[i];
      final s1 = colorOverLife[i + 1];
      if (clampedT >= s0.t && clampedT <= s1.t) {
        final span = s1.t - s0.t;
        if (span <= 1e-6) return s0.rgba;
        final factor = (clampedT - s0.t) / span;
        return Vector4(
          s0.rgba.x + (s1.rgba.x - s0.rgba.x) * factor,
          s0.rgba.y + (s1.rgba.y - s0.rgba.y) * factor,
          s0.rgba.z + (s1.rgba.z - s0.rgba.z) * factor,
          s0.rgba.w + (s1.rgba.w - s0.rgba.w) * factor,
        );
      }
    }
    return Vector4(1.0, 1.0, 1.0, 1.0);
  }
}

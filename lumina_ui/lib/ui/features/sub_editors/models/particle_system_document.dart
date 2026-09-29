import 'dart:convert';

import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

/// Versioned persistence model for a PARTICLE `.lmas`.
///
/// A particle *system* is a named list of emitters, each one a
/// [LuminaParticleEmitterConfig] — the engine's CPU particle emitter. The
/// document
/// stores exactly that config's fields, nothing the engine cannot run, and
/// round-trips through `LuminaAsset.metadata['particle_system']` so the Dart
/// code generator can emit a `LuminaParticleEmitterConfig` literal.
class ParticleSystemDocument {
  /// Document schema version written into the `.lmas`.
  static const int currentVersion = 1;

  /// `LuminaAsset.metadata` key the JSON document lives under.
  static const String metadataKey = 'particle_system';

  /// `AssetReference.slotName` prefix for per-emitter mesh renderer picks.
  static const String meshSlotPrefix = 'emitter_mesh_';

  final int version;
  final List<ParticleEmitterEntry> emitters;

  ParticleSystemDocument({
    this.version = currentVersion,
    required this.emitters,
  });

  /// A brand new system: one emitter carrying the engine defaults verbatim.
  factory ParticleSystemDocument.createDefault() => ParticleSystemDocument(
        emitters: [
          ParticleEmitterEntry(
            name: 'Emitter',
            enabled: true,
            config: LuminaParticleEmitterConfig(),
          ),
        ],
      );

  Map<String, dynamic> toJson() => {
        'v': version,
        'emitters': emitters.map((e) => e.toJson()).toList(),
      };

  String toJsonString() => jsonEncode(toJson());

  static ParticleSystemDocument fromJson(Map<String, dynamic> map) {
    final raw = map['emitters'];
    final entries = <ParticleEmitterEntry>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map) {
          entries.add(ParticleEmitterEntry.fromJson(e.cast<String, dynamic>()));
        }
      }
    }
    if (entries.isEmpty) {
      entries.add(ParticleEmitterEntry(
        name: 'Emitter',
        enabled: true,
        config: LuminaParticleEmitterConfig(),
      ));
    }
    return ParticleSystemDocument(
      version: (map['v'] as num?)?.toInt() ?? currentVersion,
      emitters: entries,
    );
  }

  /// Parses [source]; returns null when the payload is absent or unreadable
  /// (the caller then starts from [ParticleSystemDocument.createDefault]).
  static ParticleSystemDocument? tryParse(String? source) {
    if (source == null || source.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(source);
      if (decoded is! Map) return null;
      return fromJson(decoded.cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }

  ParticleSystemDocument clone() => ParticleSystemDocument(
        version: version,
        emitters: emitters.map((e) => e.clone()).toList(),
      );
}

/// One named emitter slot inside a [ParticleSystemDocument].
class ParticleEmitterEntry {
  String name;
  bool enabled;
  LuminaParticleEmitterConfig config;

  ParticleEmitterEntry({
    required this.name,
    required this.enabled,
    required this.config,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'enabled': enabled,
        'config': encodeEmitterConfig(config),
      };

  factory ParticleEmitterEntry.fromJson(Map<String, dynamic> map) => ParticleEmitterEntry(
        name: map['name']?.toString() ?? 'Emitter',
        enabled: map['enabled'] as bool? ?? true,
        config: decodeEmitterConfig(
          (map['config'] as Map?)?.cast<String, dynamic>() ?? const {},
        ),
      );

  ParticleEmitterEntry clone() => ParticleEmitterEntry(
        name: name,
        enabled: enabled,
        config: copyEmitterConfig(config),
      );
}

// --- LuminaParticleEmitterConfig codec ---------------------------------------

Map<String, dynamic> encodeEmitterConfig(LuminaParticleEmitterConfig c) => {
      'spawnRate': c.spawnRate,
      'bursts': c.bursts.map((b) => {'time': b.time, 'count': b.count}).toList(),
      'maxParticles': c.maxParticles,
      'lifetimeMin': c.lifetimeMin,
      'lifetimeMax': c.lifetimeMax,
      'speedMin': c.speedMin,
      'speedMax': c.speedMax,
      'coneAngleDegrees': c.coneAngleDegrees,
      'inheritVelocityScale': _vec3(c.inheritVelocityScale),
      'gravity': _vec3(c.gravity),
      'drag': c.drag,
      'colorOverLife': c.colorOverLife
          .map((s) => {
                't': s.t,
                'rgba': [s.rgba.x, s.rgba.y, s.rgba.z, s.rgba.w],
              })
          .toList(),
      'sizeOverLife': c.sizeOverLife.map((p) => {'t': p.t, 'scale': p.scale}).toList(),
      'looping': c.looping,
      'duration': c.duration,
      'meshAssetPath': c.meshAssetPath,
      'billboard': c.billboard,
    };

LuminaParticleEmitterConfig decodeEmitterConfig(Map<String, dynamic> map) {
  final defaults = LuminaParticleEmitterConfig();
  return LuminaParticleEmitterConfig(
    spawnRate: _d(map['spawnRate'], defaults.spawnRate),
    bursts: (map['bursts'] as List?)
            ?.whereType<Map>()
            .map((b) => LuminaParticleBurst(
                  _d(b['time'], 0.0),
                  (b['count'] as num?)?.toInt() ?? 0,
                ))
            .toList() ??
        const <LuminaParticleBurst>[],
    maxParticles: (map['maxParticles'] as num?)?.toInt() ?? defaults.maxParticles,
    lifetimeMin: _d(map['lifetimeMin'], defaults.lifetimeMin),
    lifetimeMax: _d(map['lifetimeMax'], defaults.lifetimeMax),
    speedMin: _d(map['speedMin'], defaults.speedMin),
    speedMax: _d(map['speedMax'], defaults.speedMax),
    coneAngleDegrees: _d(map['coneAngleDegrees'], defaults.coneAngleDegrees),
    inheritVelocityScale: _readVec3(map['inheritVelocityScale'], defaults.inheritVelocityScale),
    gravity: _readVec3(map['gravity'], defaults.gravity),
    drag: _d(map['drag'], defaults.drag),
    colorOverLife: (map['colorOverLife'] as List?)
            ?.whereType<Map>()
            .map((s) {
              final rgba = (s['rgba'] as List?)?.map((v) => _d(v, 0.0)).toList() ?? const <double>[];
              return LuminaGradientStop(
                _d(s['t'], 0.0),
                Vector4(
                  rgba.isNotEmpty ? rgba[0] : 1.0,
                  rgba.length > 1 ? rgba[1] : 1.0,
                  rgba.length > 2 ? rgba[2] : 1.0,
                  rgba.length > 3 ? rgba[3] : 1.0,
                ),
              );
            })
            .toList() ??
        const <LuminaGradientStop>[],
    sizeOverLife: (map['sizeOverLife'] as List?)
            ?.whereType<Map>()
            .map((p) => LuminaCurvePoint(_d(p['t'], 0.0), _d(p['scale'], 1.0)))
            .toList() ??
        const <LuminaCurvePoint>[],
    looping: map['looping'] as bool? ?? defaults.looping,
    duration: _d(map['duration'], defaults.duration),
    meshAssetPath: (map['meshAssetPath'] as String?)?.isEmpty ?? true ? null : map['meshAssetPath'] as String,
    billboard: map['billboard'] as bool? ?? defaults.billboard,
  );
}

/// `copyWith` for the engine's immutable config (the runtime declares it
/// immutable, so every editor mutation produces a fresh instance).
LuminaParticleEmitterConfig copyEmitterConfig(
  LuminaParticleEmitterConfig c, {
  double? spawnRate,
  List<LuminaParticleBurst>? bursts,
  int? maxParticles,
  double? lifetimeMin,
  double? lifetimeMax,
  double? speedMin,
  double? speedMax,
  double? coneAngleDegrees,
  Vector3? inheritVelocityScale,
  Vector3? gravity,
  double? drag,
  List<LuminaGradientStop>? colorOverLife,
  List<LuminaCurvePoint>? sizeOverLife,
  bool? looping,
  double? duration,
  String? meshAssetPath,
  bool clearMeshAssetPath = false,
  bool? billboard,
}) {
  return LuminaParticleEmitterConfig(
    spawnRate: spawnRate ?? c.spawnRate,
    bursts: bursts ?? List<LuminaParticleBurst>.from(c.bursts),
    maxParticles: maxParticles ?? c.maxParticles,
    lifetimeMin: lifetimeMin ?? c.lifetimeMin,
    lifetimeMax: lifetimeMax ?? c.lifetimeMax,
    speedMin: speedMin ?? c.speedMin,
    speedMax: speedMax ?? c.speedMax,
    coneAngleDegrees: coneAngleDegrees ?? c.coneAngleDegrees,
    inheritVelocityScale: (inheritVelocityScale ?? c.inheritVelocityScale).clone(),
    gravity: (gravity ?? c.gravity).clone(),
    drag: drag ?? c.drag,
    colorOverLife: colorOverLife ?? List<LuminaGradientStop>.from(c.colorOverLife),
    sizeOverLife: sizeOverLife ?? List<LuminaCurvePoint>.from(c.sizeOverLife),
    looping: looping ?? c.looping,
    duration: duration ?? c.duration,
    meshAssetPath: clearMeshAssetPath ? null : (meshAssetPath ?? c.meshAssetPath),
    billboard: billboard ?? c.billboard,
  );
}

List<double> _vec3(Vector3 v) => [v.x, v.y, v.z];

Vector3 _readVec3(Object? raw, Vector3 fallback) {
  if (raw is List && raw.length >= 3) {
    return Vector3(_d(raw[0], 0.0), _d(raw[1], 0.0), _d(raw[2], 0.0));
  }
  return fallback.clone();
}

double _d(Object? raw, double fallback) => (raw as num?)?.toDouble() ?? fallback;

part of '../landscape_data.dart';

/// Placement rules of one foliage layer.
///
/// [density] is instances per 100 m² of painted area, [minSpacing] the
/// rejection radius (metres) between instances of the same layer, and the
/// slope range is measured in degrees off the terrain's up vector — all of
/// them are evaluated against the real heightmap when scattering.
class FoliageRules {
  final double density;
  final double minSpacing;
  final double scaleMin;
  final double scaleMax;
  final bool randomYaw;
  final bool alignToNormal;
  final double slopeMinDegrees;
  final double slopeMaxDegrees;

  const FoliageRules({
    this.density = 50.0,
    this.minSpacing = 1.5,
    this.scaleMin = 0.8,
    this.scaleMax = 1.2,
    this.randomYaw = true,
    this.alignToNormal = false,
    this.slopeMinDegrees = 0.0,
    this.slopeMaxDegrees = 45.0,
  });

  FoliageRules copyWith({
    double? density,
    double? minSpacing,
    double? scaleMin,
    double? scaleMax,
    bool? randomYaw,
    bool? alignToNormal,
    double? slopeMinDegrees,
    double? slopeMaxDegrees,
  }) {
    return FoliageRules(
      density: density ?? this.density,
      minSpacing: minSpacing ?? this.minSpacing,
      scaleMin: scaleMin ?? this.scaleMin,
      scaleMax: scaleMax ?? this.scaleMax,
      randomYaw: randomYaw ?? this.randomYaw,
      alignToNormal: alignToNormal ?? this.alignToNormal,
      slopeMinDegrees: slopeMinDegrees ?? this.slopeMinDegrees,
      slopeMaxDegrees: slopeMaxDegrees ?? this.slopeMaxDegrees,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FoliageRules &&
      other.density == density &&
      other.minSpacing == minSpacing &&
      other.scaleMin == scaleMin &&
      other.scaleMax == scaleMax &&
      other.randomYaw == randomYaw &&
      other.alignToNormal == alignToNormal &&
      other.slopeMinDegrees == slopeMinDegrees &&
      other.slopeMaxDegrees == slopeMaxDegrees;

  @override
  int get hashCode => Object.hash(
        density,
        minSpacing,
        scaleMin,
        scaleMax,
        randomYaw,
        alignToNormal,
        slopeMinDegrees,
        slopeMaxDegrees,
      );
}

/// One placed foliage instance: world position (metres, terrain space), a
/// non-uniform scale, the yaw applied around the alignment axis and the
/// surface normal it was aligned to.
class FoliageInstance {
  final double x;
  final double y;
  final double z;
  final double scaleX;
  final double scaleY;
  final double scaleZ;
  final double yaw;
  final double nx;
  final double ny;
  final double nz;

  const FoliageInstance({
    required this.x,
    required this.y,
    required this.z,
    required this.scaleX,
    required this.scaleY,
    required this.scaleZ,
    required this.yaw,
    required this.nx,
    required this.ny,
    required this.nz,
  });

  /// Transform in preview-world units.
  ///
  /// [unitsPerMetre] converts the instance's metre position into the preview
  /// world's units; [meshScale] compensates the mesh asset's own authoring
  /// unit (test-asset GLBs are centimetre-authored, so a metre-scaled preview
  /// needs 0.01).
  Matrix4 toMatrix({double unitsPerMetre = 1.0, double meshScale = 1.0}) {
    final normal = Vector3(nx, ny, nz);
    if (normal.length2 < 1e-12) {
      normal.setValues(0.0, 1.0, 0.0);
    } else {
      normal.normalize();
    }
    final up = Vector3(0.0, 1.0, 0.0);
    Quaternion align;
    final dot = up.dot(normal).clamp(-1.0, 1.0);
    if (dot > 0.999999) {
      align = Quaternion.identity();
    } else if (dot < -0.999999) {
      align = Quaternion.axisAngle(Vector3(1.0, 0.0, 0.0), math.pi);
    } else {
      final axis = up.cross(normal)..normalize();
      align = Quaternion.axisAngle(axis, math.acos(dot));
    }
    final rotation = align * Quaternion.axisAngle(Vector3(0.0, 1.0, 0.0), yaw);
    return Matrix4.compose(
      Vector3(x * unitsPerMetre, y * unitsPerMetre, z * unitsPerMetre),
      rotation,
      Vector3(scaleX * meshScale, scaleY * meshScale, scaleZ * meshScale),
    );
  }
}

/// A foliage layer: one mesh asset, its placement rules and the packed
/// transforms of every instance painted with it.
///
/// The transforms are a flat `Float32List` of [floatsPerInstance] floats per
/// instance (pos3, scale3, yaw, normal3) — the mirror of the GPU instance
/// batch, kept consistent through the same swap-remove that
/// `LuminaInstancedStaticMeshComponent.removeInstance` performs.
class FoliageLayer {
  static const int floatsPerInstance = 10;

  String meshAssetId;
  String meshAssetPath;
  String name;
  FoliageRules rules;

  Float32List _transforms;
  int _count = 0;

  FoliageLayer({
    required this.meshAssetId,
    required this.meshAssetPath,
    required this.name,
    this.rules = const FoliageRules(),
    Float32List? transforms,
  }) : _transforms = Float32List(math.max(16, (transforms?.length ?? 0))) {
    if (transforms != null && transforms.isNotEmpty) {
      _transforms.setRange(0, transforms.length, transforms);
      _count = transforms.length ~/ floatsPerInstance;
    }
  }

  int get instanceCount => _count;

  /// The live transform floats (a view, length `instanceCount * 10`).
  Float32List get transforms => Float32List.sublistView(_transforms, 0, _count * floatsPerInstance);

  void addInstance(FoliageInstance i) {
    _ensure((_count + 1) * floatsPerInstance);
    final o = _count * floatsPerInstance;
    _transforms[o] = i.x;
    _transforms[o + 1] = i.y;
    _transforms[o + 2] = i.z;
    _transforms[o + 3] = i.scaleX;
    _transforms[o + 4] = i.scaleY;
    _transforms[o + 5] = i.scaleZ;
    _transforms[o + 6] = i.yaw;
    _transforms[o + 7] = i.nx;
    _transforms[o + 8] = i.ny;
    _transforms[o + 9] = i.nz;
    _count++;
  }

  FoliageInstance instanceAt(int index) {
    if (index < 0 || index >= _count) {
      throw RangeError.index(index, this, 'index', 'instance index out of range', _count);
    }
    final o = index * floatsPerInstance;
    return FoliageInstance(
      x: _transforms[o],
      y: _transforms[o + 1],
      z: _transforms[o + 2],
      scaleX: _transforms[o + 3],
      scaleY: _transforms[o + 4],
      scaleZ: _transforms[o + 5],
      yaw: _transforms[o + 6],
      nx: _transforms[o + 7],
      ny: _transforms[o + 8],
      nz: _transforms[o + 9],
    );
  }

  /// Swap-removes [index]; returns the index the last instance moved from
  /// (`-1` when the removed instance was the last one) so callers can keep a
  /// parallel array in step with the GPU batch.
  int removeAt(int index) {
    if (index < 0 || index >= _count) return -1;
    final last = _count - 1;
    if (index != last) {
      final src = last * floatsPerInstance;
      final dst = index * floatsPerInstance;
      for (var f = 0; f < floatsPerInstance; f++) {
        _transforms[dst + f] = _transforms[src + f];
      }
    }
    _count--;
    return index == last ? -1 : last;
  }

  void clearInstances() => _count = 0;

  void _ensure(int floats) {
    if (_transforms.length >= floats) return;
    var next = math.max(_transforms.length * 2, 16);
    while (next < floats) {
      next *= 2;
    }
    final grown = Float32List(next)..setRange(0, _transforms.length, _transforms);
    _transforms = grown;
  }
}

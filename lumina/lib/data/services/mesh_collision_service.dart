import 'dart:convert';
import 'dart:io';

import 'package:vector_math/vector_math_64.dart';

import 'package:lumina/src/collision/collision_hull.dart';
import 'package:lumina/src/collision/collision_primitive.dart';
import 'package:lumina_core/lumina_core.dart';

/// A mesh asset's simple collision: convex [hulls]
/// (imported `UCX_` pieces, then authored convex shapes), authored box /
/// sphere / capsule [primitives], and the authored [complexity].
class MeshSimpleCollision {
  final List<LuminaCollisionHull> hulls;
  final List<LuminaCollisionPrimitive> primitives;

  /// The Static Mesh editor's Collision Complexity: [complexityDefault],
  /// [complexitySimpleAsComplex] or [complexityComplexAsSimple].
  final String complexity;

  const MeshSimpleCollision({
    this.hulls = const [],
    this.primitives = const [],
    this.complexity = complexityDefault,
  });

  static const MeshSimpleCollision none = MeshSimpleCollision();

  /// Simple shapes for queries and physics, the mesh triangles for complex
  /// traces.
  static const String complexityDefault = 'default';

  /// Simple shapes for complex traces too.
  static const String complexitySimpleAsComplex = 'use_simple_as_complex';

  /// Per-triangle collision for everything, which the
  /// runtime has no shape for; such a mesh plays with its simple shapes.
  static const String complexityComplexAsSimple = 'use_complex_as_simple';

  bool get isEmpty => hulls.isEmpty && primitives.isEmpty;
}

/// A static mesh asset's simple collision, as the runtime builds it.
///
/// The FBX import keeps the `UCX_`/`UBX_`/`USP_`/`UCP_` meshes it strips from
/// the drawn GLB as the asset's `collision_hulls` metadata, in the glTF frame
/// (metres, +Y up, model space). This turns them into authored
/// [LuminaCollisionHull]s (centimetres, Z up), splitting a hull whose
/// triangles form several disconnected pieces into one convex element per
/// piece. The Static
/// Mesh editor's authored shapes (`metadata['collision']`) join them: boxes,
/// spheres and capsules as primitives, convex shapes as hulls — read in cm,
/// Z up, a legacy (glTF metre, Y-up) document converted by
/// [authoredCollisionInCentimetres].
///
/// Editor-side only (it reads `.lmas` files): the level code generator bakes
/// the result into the generated level, and Play-In-Editor builds its
/// actors from it. A game never calls it.
abstract final class MeshCollisionService {
  /// The mesh asset metadata key the FBX import writes.
  static const String metadataKey = 'collision_hulls';

  /// The mesh asset metadata key the Static Mesh editor writes.
  static const String authoredKey = 'collision';

  /// Fewer points than this enclose no volume.
  static const int minPoints = 4;

  static final Map<String, ({int size, DateTime modified, MeshSimpleCollision collision})> _cache = {};

  /// The convex hulls of the mesh asset at [meshAssetPath] (imported `UCX_`
  /// pieces and authored convex shapes); see [simpleCollisionForMeshAsset].
  static List<LuminaCollisionHull> hullsForMeshAsset(String meshAssetPath, {String? projectDir}) =>
      simpleCollisionForMeshAsset(meshAssetPath, projectDir: projectDir).hulls;

  /// The simple collision of the mesh asset at [meshAssetPath]: an absolute
  /// path, or a project path (`contents/…`) resolved under [projectDir].
  /// [MeshSimpleCollision.none] for a mesh without any, a file that is not a
  /// `.lmas`, or one that cannot be read. Cached per file until its size or
  /// modification time changes.
  static MeshSimpleCollision simpleCollisionForMeshAsset(String meshAssetPath, {String? projectDir}) {
    if (!meshAssetPath.toLowerCase().endsWith('.lmas')) return MeshSimpleCollision.none;
    var file = File(meshAssetPath);
    if (!file.isAbsolute || !file.existsSync()) {
      if (projectDir == null || file.isAbsolute) return MeshSimpleCollision.none;
      file = File('$projectDir/$meshAssetPath');
      if (!file.existsSync()) return MeshSimpleCollision.none;
    }
    try {
      final stat = file.statSync();
      final cached = _cache[file.path];
      if (cached != null && cached.size == stat.size && cached.modified == stat.modified) return cached.collision;
      final asset = LuminaAsset.fromBytes(file.readAsBytesSync());
      final collision = simpleCollisionFromMetadata(asset.metadata);
      _cache[file.path] = (size: stat.size, modified: stat.modified, collision: collision);
      return collision;
    } catch (_) {
      return MeshSimpleCollision.none;
    }
  }

  /// A mesh asset's simple collision from its [metadata]: the imported
  /// `collision_hulls` ([hullsFromMetadata]) and the authored `collision`
  /// document.
  static MeshSimpleCollision simpleCollisionFromMetadata(Map<String, String> metadata) {
    final hulls = [...hullsFromMetadata(metadata)];
    final primitives = <LuminaCollisionPrimitive>[];
    var complexity = MeshSimpleCollision.complexityDefault;
    final raw = metadata[authoredKey];
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final doc = authoredCollisionInCentimetres(Map<String, dynamic>.from(decoded));
          complexity = '${doc['complexity'] ?? MeshSimpleCollision.complexityDefault}';
          var convex = 0;
          for (final shape in (doc['shapes'] as List? ?? const []).whereType<Map>()) {
            List<double> vec(Object? v) =>
                v is List && v.length >= 3 ? [for (final e in v.take(3)) (e as num).toDouble()] : const [0.0, 0.0, 0.0];
            double scalar(Object? v) => v is num ? v.toDouble() : 0.0;
            switch ('${shape['type']}') {
              case 'box':
                primitives.add(LuminaCollisionPrimitive.box(center: vec(shape['center']), halfExtents: vec(shape['extents'])));
              case 'sphere':
                primitives.add(LuminaCollisionPrimitive.sphere(center: vec(shape['center']), radius: scalar(shape['radius'])));
              case 'capsule':
                primitives.add(LuminaCollisionPrimitive.capsule(
                  center: vec(shape['center']),
                  radius: scalar(shape['radius']),
                  halfLength: scalar(shape['halfHeight']),
                  axis: '${shape['axis'] ?? 'Z'}'.toUpperCase(),
                ));
              case 'convex':
                final points = [for (final p in (shape['points'] as List? ?? const [])) ...vec(p)];
                if (_uniquePositions(points) < minPoints) continue;
                convex++;
                hulls.add(LuminaCollisionHull('Convex_$convex', List.unmodifiable(points)));
            }
          }
        }
      } catch (_) {
        // An unreadable document adds nothing; the imported hulls still count.
      }
    }
    return MeshSimpleCollision(
      hulls: List.unmodifiable(hulls),
      primitives: List.unmodifiable(primitives),
      complexity: complexity,
    );
  }

  /// A stored `collision` document in the authoring frame (cm, Z up).
  ///
  /// A document marked `world_units: cm` is returned as it is. An unmarked
  /// one is legacy, written in the GLB's own frame
  /// (metres, Y up): centres and points go through [toAuthoring], box
  /// extents become `(x, z, y) × 100`, radius and half height × 100, a
  /// capsule's `Y` axis is `Z` (and `Z` is `Y`); the copy is marked. [json]
  /// itself is not modified. The editor migrates through this too.
  static Map<String, dynamic> authoredCollisionInCentimetres(Map<String, dynamic> json) {
    if (json['world_units'] == 'cm') return json;
    const u = LuminaUnits.unitsPerMetre;
    double clean(double v) {
      final r = (v * 1e6).roundToDouble() / 1e6;
      return r == 0 ? 0.0 : r;
    }

    List<double>? point(Object? v) {
      if (v is! List || v.length < 3) return null;
      final p = [for (final e in v.take(3)) (e as num).toDouble()];
      return toAuthoring(p[0], p[1], p[2]);
    }

    final shapes = <Map<String, dynamic>>[];
    for (final raw in (json['shapes'] as List? ?? const []).whereType<Map>()) {
      final shape = Map<String, dynamic>.from(raw);
      final center = point(shape['center']);
      if (center != null) shape['center'] = center;
      final e = shape['extents'];
      if (e is List && e.length >= 3) {
        final x = (e[0] as num).toDouble(), y = (e[1] as num).toDouble(), z = (e[2] as num).toDouble();
        shape['extents'] = [clean(x * u), clean(z * u), clean(y * u)];
      }
      for (final key in const ['radius', 'halfHeight']) {
        final v = shape[key];
        if (v is num) shape[key] = clean(v.toDouble() * u);
      }
      final axis = '${shape['axis'] ?? ''}'.toUpperCase();
      if (axis == 'Y') shape['axis'] = 'Z';
      if (axis == 'Z') shape['axis'] = 'Y';
      final points = shape['points'];
      if (points is List) shape['points'] = [for (final p in points) point(p) ?? p];
      shapes.add(shape);
    }
    return {
      ...json,
      'world_units': 'cm',
      'up_axis': 'z',
      'shapes': shapes,
    };
  }

  /// Parses the `collision_hulls` entry of a mesh asset's [metadata].
  static List<LuminaCollisionHull> hullsFromMetadata(Map<String, String> metadata) {
    final raw = metadata[metadataKey];
    if (raw == null || raw.isEmpty) return const [];
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return const [];
    }
    if (decoded is! List) return const [];

    final hulls = <LuminaCollisionHull>[];
    for (final entry in decoded.whereType<Map>()) {
      final name = '${entry['name'] ?? 'UCX'}';
      final shape = '${entry['shape'] ?? 'convex'}';
      final gltf = [for (final v in (entry['points'] as List?) ?? const []) (v as num).toDouble()];
      final count = gltf.length ~/ 3;
      if (count < minPoints) continue;
      final authored = List<double>.filled(count * 3, 0);
      for (var i = 0; i < count; i++) {
        final a = toAuthoring(gltf[i * 3], gltf[i * 3 + 1], gltf[i * 3 + 2]);
        authored[i * 3] = a[0];
        authored[i * 3 + 1] = a[1];
        authored[i * 3 + 2] = a[2];
      }
      final triangles = [
        for (final v in (entry['triangles'] as List?) ?? const []) (v as num).toInt(),
      ];
      final pieces = triangles.isEmpty ? [List<int>.generate(count, (i) => i)] : connectedPieces(authored, triangles);
      final kept = [
        for (final piece in pieces)
          [for (final i in piece) ...authored.sublist(i * 3, i * 3 + 3)],
      ].where((p) => _uniquePositions(p) >= minPoints).toList();
      for (var k = 0; k < kept.length; k++) {
        hulls.add(LuminaCollisionHull(kept.length == 1 ? name : '${name}_${k + 1}', List.unmodifiable(kept[k]), shape: shape));
      }
    }
    return List.unmodifiable(hulls);
  }

  /// A glTF point (metres, Y up) in the authoring frame (cm, Z up), with
  /// float noise from the unit conversion rounded away.
  static List<double> toAuthoring(double x, double y, double z) {
    final a = LuminaAxes.toAuthoringLocation(Vector3(x, y, z)..scale(LuminaUnits.unitsPerMetre));
    double clean(double v) {
      final r = (v * 1e6).roundToDouble() / 1e6;
      return r == 0 ? 0.0 : r;
    }

    return [clean(a[0]), clean(a[1]), clean(a[2])];
  }

  /// Groups the vertices of a triangle mesh into its connected pieces.
  /// Vertices at the same position are one vertex (Assimp splits a hull's
  /// corners by face normal); vertices no triangle uses are left out.
  static List<List<int>> connectedPieces(List<double> points, List<int> triangles) {
    final count = points.length ~/ 3;
    final parent = List<int>.generate(count, (i) => i);
    int find(int i) {
      while (parent[i] != i) {
        parent[i] = parent[parent[i]];
        i = parent[i];
      }
      return i;
    }

    void union(int a, int b) {
      final ra = find(a), rb = find(b);
      if (ra != rb) parent[rb] = ra;
    }

    // Weld by position (the report rounds to 0.01 cm).
    final byPosition = <String, int>{};
    for (var i = 0; i < count; i++) {
      final key = '${(points[i * 3] * 100).round()},${(points[i * 3 + 1] * 100).round()},${(points[i * 3 + 2] * 100).round()}';
      final first = byPosition.putIfAbsent(key, () => i);
      if (first != i) union(first, i);
    }
    final used = List<bool>.filled(count, false);
    for (var t = 0; t + 2 < triangles.length; t += 3) {
      final a = triangles[t], b = triangles[t + 1], c = triangles[t + 2];
      if (a < 0 || b < 0 || c < 0 || a >= count || b >= count || c >= count) continue;
      used[a] = used[b] = used[c] = true;
      union(a, b);
      union(a, c);
    }
    final pieces = <int, List<int>>{};
    for (var i = 0; i < count; i++) {
      if (!used[i]) continue;
      pieces.putIfAbsent(find(i), () => []).add(i);
    }
    return pieces.values.toList();
  }

  static int _uniquePositions(List<double> flat) {
    final seen = <String>{};
    for (var i = 0; i + 2 < flat.length; i += 3) {
      seen.add('${(flat[i] * 100).round()},${(flat[i + 1] * 100).round()},${(flat[i + 2] * 100).round()}');
    }
    return seen.length;
  }
}

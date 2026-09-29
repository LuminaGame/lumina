import 'dart:math' as math;

import 'package:flutter/foundation.dart' show Key;
import 'dart:typed_data';

import 'package:vector_math/vector_math_64.dart';

import '../components/collision/collision_component.dart';
import '../../data/services/primitive_glb_factory.dart';
import '../components/mesh/static_mesh_component.dart';
import '../object/actor.dart';

/// Shapes a [LuminaPrimitiveActor] can take.
enum LuminaPrimitiveShape { box, plane, sphere, cylinder }

/// Parses the `shape` string an editor `LuminaProceduralMeshComponent` carries.
/// Anything unrecognised is a box, so an old or hand-edited level still loads.
LuminaPrimitiveShape luminaPrimitiveShapeFrom(String? name) {
  switch (name) {
    case 'plane':
      return LuminaPrimitiveShape.plane;
    case 'sphere':
      return LuminaPrimitiveShape.sphere;
    case 'cylinder':
      return LuminaPrimitiveShape.cylinder;
    default:
      return LuminaPrimitiveShape.box;
  }
}

/// CPU-side vertex data for a primitive shape, in metres, centred on the actor
/// origin. Planes lie in the XZ plane at y = 0.
class LuminaPrimitiveGeometry {
  final Float32List positions;
  final Float32List normals;
  final Float32List uvs;
  final Uint32List indices;

  const LuminaPrimitiveGeometry(this.positions, this.normals, this.uvs, this.indices);

  int get vertexCount => positions.length ~/ 3;

  /// One opaque RGBA vertex colour per vertex.
  ///
  /// The colour is not optional: the gltfio ubershader drops a primitive that
  /// declares no `COLOR` attribute without drawing it at all.
  Uint8List solidColors(Vector3 rgb) {
    final out = Uint8List(vertexCount * 4);
    final r = (rgb.x * 255.0).round().clamp(0, 255);
    final g = (rgb.y * 255.0).round().clamp(0, 255);
    final b = (rgb.z * 255.0).round().clamp(0, 255);
    for (var i = 0; i < vertexCount; i++) {
      out[i * 4 + 0] = r;
      out[i * 4 + 1] = g;
      out[i * 4 + 2] = b;
      out[i * 4 + 3] = 255;
    }
    return out;
  }

  /// Rings of latitude used by [LuminaPrimitiveShape.sphere].
  static const int sphereRings = 12;

  /// Segments of longitude used by sphere and cylinder.
  static const int radialSegments = 16;

  static LuminaPrimitiveGeometry build(LuminaPrimitiveShape shape, Vector3 size) {
    final p = <double>[];
    final n = <double>[];
    final u = <double>[];
    final idx = <int>[];

    void vertex(double x, double y, double z, double nx, double ny, double nz, double uu, double vv) {
      p..add(x)..add(y)..add(z);
      n..add(nx)..add(ny)..add(nz);
      u..add(uu)..add(vv);
    }

    void quad(Vector3 a, Vector3 b, Vector3 c, Vector3 d, Vector3 nrm) {
      final base = p.length ~/ 3;
      vertex(a.x, a.y, a.z, nrm.x, nrm.y, nrm.z, 0.0, 0.0);
      vertex(b.x, b.y, b.z, nrm.x, nrm.y, nrm.z, 1.0, 0.0);
      vertex(c.x, c.y, c.z, nrm.x, nrm.y, nrm.z, 1.0, 1.0);
      vertex(d.x, d.y, d.z, nrm.x, nrm.y, nrm.z, 0.0, 1.0);
      idx.addAll(<int>[base, base + 1, base + 2, base, base + 2, base + 3]);
    }

    final hx = size.x * 0.5;
    final hy = size.y * 0.5;
    final hz = size.z * 0.5;

    switch (shape) {
      case LuminaPrimitiveShape.plane:
        quad(
          Vector3(-hx, 0.0, hz),
          Vector3(hx, 0.0, hz),
          Vector3(hx, 0.0, -hz),
          Vector3(-hx, 0.0, -hz),
          Vector3(0.0, 1.0, 0.0),
        );
        break;

      case LuminaPrimitiveShape.box:
        // +Y, -Y, +Z, -Z, +X, -X — wound counter-clockwise seen from outside.
        quad(Vector3(-hx, hy, hz), Vector3(hx, hy, hz), Vector3(hx, hy, -hz), Vector3(-hx, hy, -hz),
            Vector3(0.0, 1.0, 0.0));
        quad(Vector3(-hx, -hy, -hz), Vector3(hx, -hy, -hz), Vector3(hx, -hy, hz), Vector3(-hx, -hy, hz),
            Vector3(0.0, -1.0, 0.0));
        quad(Vector3(-hx, -hy, hz), Vector3(hx, -hy, hz), Vector3(hx, hy, hz), Vector3(-hx, hy, hz),
            Vector3(0.0, 0.0, 1.0));
        quad(Vector3(hx, -hy, -hz), Vector3(-hx, -hy, -hz), Vector3(-hx, hy, -hz), Vector3(hx, hy, -hz),
            Vector3(0.0, 0.0, -1.0));
        quad(Vector3(hx, -hy, hz), Vector3(hx, -hy, -hz), Vector3(hx, hy, -hz), Vector3(hx, hy, hz),
            Vector3(1.0, 0.0, 0.0));
        quad(Vector3(-hx, -hy, -hz), Vector3(-hx, -hy, hz), Vector3(-hx, hy, hz), Vector3(-hx, hy, -hz),
            Vector3(-1.0, 0.0, 0.0));
        break;

      case LuminaPrimitiveShape.sphere:
        for (var ring = 0; ring <= sphereRings; ring++) {
          final v = ring / sphereRings;
          final phi = v * math.pi;
          final y = _cos(phi);
          final r = _sin(phi);
          for (var seg = 0; seg <= radialSegments; seg++) {
            final uu = seg / radialSegments;
            final theta = uu * 2.0 * math.pi;
            final nx = r * _cos(theta);
            final nz = r * _sin(theta);
            vertex(nx * hx, y * hy, nz * hz, nx, y, nz, uu, v);
          }
        }
        for (var ring = 0; ring < sphereRings; ring++) {
          for (var seg = 0; seg < radialSegments; seg++) {
            final a = ring * (radialSegments + 1) + seg;
            final b = a + radialSegments + 1;
            idx.addAll(<int>[a, b, a + 1, a + 1, b, b + 1]);
          }
        }
        break;

      case LuminaPrimitiveShape.cylinder:
        // Side wall.
        for (var seg = 0; seg <= radialSegments; seg++) {
          final uu = seg / radialSegments;
          final theta = uu * 2.0 * math.pi;
          final nx = _cos(theta);
          final nz = _sin(theta);
          vertex(nx * hx, -hy, nz * hz, nx, 0.0, nz, uu, 0.0);
          vertex(nx * hx, hy, nz * hz, nx, 0.0, nz, uu, 1.0);
        }
        for (var seg = 0; seg < radialSegments; seg++) {
          final a = seg * 2;
          idx.addAll(<int>[a, a + 1, a + 2, a + 2, a + 1, a + 3]);
        }
        // Caps, each with its own centre vertex so the normals stay flat.
        for (final top in <bool>[true, false]) {
          final y = top ? hy : -hy;
          final ny = top ? 1.0 : -1.0;
          final centre = p.length ~/ 3;
          vertex(0.0, y, 0.0, 0.0, ny, 0.0, 0.5, 0.5);
          for (var seg = 0; seg <= radialSegments; seg++) {
            final theta = seg / radialSegments * 2.0 * math.pi;
            final cx = _cos(theta);
            final cz = _sin(theta);
            vertex(cx * hx, y, cz * hz, 0.0, ny, 0.0, cx * 0.5 + 0.5, cz * 0.5 + 0.5);
          }
          for (var seg = 0; seg < radialSegments; seg++) {
            final a = centre + 1 + seg;
            if (top) {
              idx.addAll(<int>[centre, a, a + 1]);
            } else {
              idx.addAll(<int>[centre, a + 1, a]);
            }
          }
        }
        break;
    }

    return LuminaPrimitiveGeometry(
      Float32List.fromList(p),
      Float32List.fromList(n),
      Float32List.fromList(u),
      Uint32List.fromList(idx),
    );
  }

  static double _sin(double v) => math.sin(v);
  static double _cos(double v) => math.cos(v);
}

/// An engine-drawn primitive authored in Lumina Studio: the shape as real glTF
/// geometry in its authored colour, plus a matching box collider, so a
/// character can stand on it without any imported art asset.
///
/// The geometry is the very GLB the editor's viewport draws for the same actor
/// (`PrimitiveGlbFactory`), loaded through [LuminaStaticMeshComponent] from an
/// asset provider — lit, shadowed and coloured like every other mesh, and
/// shared between identical primitives through the world's mesh cache.
///
/// Both Play-In-Editor and the generated game build the same actor from the
/// same `LuminaProceduralMeshComponent` properties in `metadata.actors`.
class LuminaPrimitiveActor extends LuminaActor {
  final LuminaPrimitiveShape shape;
  final Vector3 size;
  final Vector3 color;

  late final LuminaStaticMeshComponent meshComponent;
  late final LuminaCollisionComponent collisionComponent;

  /// A plane has no thickness to collide with; it gets this one, in cm.
  static const double planeColliderThickness = 10.0;

  LuminaPrimitiveActor({
    super.key,
    super.location,
    super.rotation,
    Vector3? scale,
    required this.shape,
    required this.size,
    required this.color,
  }) {
    if (scale != null) actorScale = scale;
    final hex = luminaRgbToHex(color);
    meshComponent = LuminaStaticMeshComponent(
      // Not a file: a cache key naming the generated asset, so identical
      // primitives share it.
      meshAssetPath: 'lumina-primitive:${shape.name}:${size.x}x${size.y}x${size.z}:$hex',
      // Generated in world units (cm), not glTF metres.
      assetUnitScale: 1.0,
      assetProvider: (_) async => PrimitiveGlbFactory.build(
        shape: shape.name,
        sizeX: size.x,
        sizeY: size.y,
        sizeZ: size.z,
        colorHex: hex,
      ),
    );
    addComponent(meshComponent);

    final thickness = shape == LuminaPrimitiveShape.plane ? planeColliderThickness : size.y;
    collisionComponent = LuminaCollisionComponent(shapeType: CollisionShapeType.box)
      ..boxExtent = Vector3(size.x * 0.5, thickness * 0.5, size.z * 0.5)
      ..objectType = CollisionObjectType.worldStatic;
    addComponent(collisionComponent);
  }

  /// Builds the actor from the `properties` map of an editor
  /// `LuminaProceduralMeshComponent` entry.
  factory LuminaPrimitiveActor.fromComponentProperties(
    Map<String, dynamic> properties, {
    Key? key,
    Vector3? location,
    Quaternion? rotation,
    Vector3? scale,
  }) {
    double dim(String name) {
      final v = properties[name];
      return v is num ? v.toDouble() : 100.0; // cm
    }

    return LuminaPrimitiveActor(
      key: key,
      location: location,
      rotation: rotation,
      scale: scale,
      shape: luminaPrimitiveShapeFrom(properties['shape'] as String?),
      size: Vector3(dim('sizeX'), dim('sizeY'), dim('sizeZ')),
      color: luminaHexToRgb(properties['colorHex'] as String?),
    );
  }
}

/// `(r, g, b)` in 0..1 as `#RRGGBB`, the inverse of [luminaHexToRgb].
String luminaRgbToHex(Vector3 rgb) {
  String channel(double v) => (v.clamp(0.0, 1.0) * 255).round().toRadixString(16).padLeft(2, '0').toUpperCase();
  return '#${channel(rgb.x)}${channel(rgb.y)}${channel(rgb.z)}';
}

/// Parses `#RRGGBB` / `#AARRGGBB` into a 0..1 RGB vector; mid grey on error.
Vector3 luminaHexToRgb(String? hex) {
  if (hex == null) return Vector3.all(0.6);
  var h = hex.trim();
  if (h.startsWith('#')) h = h.substring(1);
  if (h.length == 8) h = h.substring(2);
  if (h.length != 6) return Vector3.all(0.6);
  final v = int.tryParse(h, radix: 16);
  if (v == null) return Vector3.all(0.6);
  return Vector3(((v >> 16) & 0xFF) / 255.0, ((v >> 8) & 0xFF) / 255.0, (v & 0xFF) / 255.0);
}

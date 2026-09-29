import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:vector_math/vector_math_64.dart';

import '../../game/primitive_actor.dart' show luminaHexToRgb, luminaRgbToHex;
import '../../math/axes.dart';
import '../../math/units.dart';
import '../../object/actor.dart';
import '../../post_process/post_process_blender.dart';
import '../../world/world.dart';
import '../base/scene_component.dart';
import '../mesh/static_mesh_component.dart';

/// Shapes a [LuminaLocalFogVolumeComponent] can take.
enum LuminaLocalFogShape { sphere, box }

LuminaLocalFogShape luminaLocalFogShapeFrom(String? name) =>
    name == 'box' || name == 'Box' ? LuminaLocalFogShape.box : LuminaLocalFogShape.sphere;

/// A Local Fog Volume, as far as Filament allows:
/// **an approximation — no volumetric scattering.**
///
/// Filament has no local participating media, no ray march and no fog
/// other than the global exponential height fog. This component is therefore
/// two honest pieces:
///
/// 1. a **fog shell** — a sphere or box with inverted winding, drawn unlit,
///    alpha-blended, depth-tested and shadowless, whose per-vertex alpha is
///    baked from [fogDensity], [radialAttenuation] (alpha falls from the
///    centre to the rim) and [heightFalloff] (alpha falls with height above
///    the centre), tinted by [fogAlbedo]. From outside the camera sees the far
///    interior wall through whatever stands inside; from inside the shell
///    surrounds the camera. It is generated as a small glTF in memory
///    ([LuminaFogShellGlbFactory]) and drawn through the same static mesh path
///    primitives use — no runtime shader compile, so it works wherever
///    primitives do;
/// 2. a [LuminaPostProcessVolume] on the world's blender whose
///    `fogDensityScale` / `fogColor` pull the **global** fog towards the
///    volume's density and albedo while the camera is inside, restored on
///    exit.
///
/// Fog phase G and emissive have no Filament counterpart and are not offered.
class LuminaLocalFogVolumeComponent extends LuminaSceneComponent {
  LuminaLocalFogVolumeComponent({
    super.key,
    super.location,
    super.rotation,
    super.scale,
    this.shape = LuminaLocalFogShape.sphere,
    this.radius = 500.0,
    Vector3? extent,
    Vector3? fogAlbedo,
    this.fogDensity = 0.35,
    this.heightFalloff = 0.5,
    this.radialAttenuation = 0.7,
    this.enabled = true,
    bool visible = true,
  })  : extent = extent ?? Vector3.all(500.0),
        fogAlbedo = fogAlbedo ?? Vector3(0.8, 0.85, 0.9),
        super(isVisible: visible);

  /// From the editor component's `properties`: `shape` (`sphere`/`box`),
  /// `radius` (cm), `extentX/Y/Z` (Z-up cm → runtime), `fogAlbedoHex`,
  /// `fogDensity`, `heightFalloff` (/m), `radialAttenuation`, `enabled`.
  factory LuminaLocalFogVolumeComponent.fromProperties(
    Map<String, dynamic>? properties, {
    Vector3? location,
    Quaternion? rotation,
    Vector3? scale,
    bool visible = true,
  }) {
    final p = properties ?? const <String, dynamic>{};
    double num_(String k, double d) => p[k] is num ? (p[k] as num).toDouble() : d;
    final hex = p['fogAlbedoHex'];
    return LuminaLocalFogVolumeComponent(
      location: location,
      rotation: rotation,
      scale: scale,
      shape: luminaLocalFogShapeFrom(p['shape'] is String ? p['shape'] as String : null),
      radius: num_('radius', 500.0).clamp(1.0, 1e7),
      extent: LuminaAxes.scale([num_('extentX', 500.0), num_('extentY', 500.0), num_('extentZ', 500.0)]),
      fogAlbedo: hex is String ? luminaHexToRgb(hex) : null,
      fogDensity: num_('fogDensity', 0.35).clamp(0.0, 1.0),
      heightFalloff: num_('heightFalloff', 0.5).clamp(0.0, 100.0),
      radialAttenuation: num_('radialAttenuation', 0.7).clamp(0.0, 1.0),
      enabled: p['enabled'] is bool ? p['enabled'] as bool : true,
      visible: visible,
    );
  }

  /// How much the global fog density is multiplied while the camera is
  /// inside: `1 + densityScalePerUnit · fogDensity`.
  static const double densityScalePerUnit = 10.0;

  /// Blender priority: above ordinary Post Process Volumes.
  static const double blenderPriority = 100.0;

  LuminaLocalFogShape shape;

  /// Sphere radius, cm.
  double radius;

  /// Box half size, cm, runtime axes.
  Vector3 extent;
  Vector3 fogAlbedo;

  /// 0..1: the shell's peak alpha, and the global fog scale while inside.
  double fogDensity;

  /// Per metre; 0 = none. Alpha falls with height above the centre.
  double heightFalloff;

  /// 0 = uniform, 1 = transparent at the rim.
  double radialAttenuation;
  bool enabled;

  bool get visible => isVisible;
  set visible(bool v) => isVisible = v;

  bool get isActive => enabled && isVisible;

  /// The global-fog scale published while the camera is inside.
  double get fogDensityScale => 1.0 + densityScalePerUnit * fogDensity;

  /// The shape the blender evaluates.
  final LuminaPostProcessVolume volume = LuminaPostProcessVolume();
  LuminaPostProcessBlender? _blender;

  LuminaStaticMeshComponent? _shell;
  String? _shellKey;

  /// The shell renderable, once built (in a registered actor).
  LuminaStaticMeshComponent? get shell => _shell;

  /// The cache key naming the current shell geometry; changes whenever a
  /// shell-affecting field changes.
  String get shellKey {
    final dims = shape == LuminaLocalFogShape.sphere
        ? radius.toStringAsFixed(1)
        : '${extent.x.toStringAsFixed(1)}x${extent.y.toStringAsFixed(1)}x${extent.z.toStringAsFixed(1)}';
    return 'lumina-fogshell:${shape.name}:$dims:${luminaRgbToHex(fogAlbedo)}:'
        '${fogDensity.toStringAsFixed(3)}:${heightFalloff.toStringAsFixed(3)}:${radialAttenuation.toStringAsFixed(3)}';
  }

  void _refreshVolume() {
    final sphere = shape == LuminaLocalFogShape.sphere;
    volume
      ..enabled = isActive
      ..unbound = false
      ..priority = blenderPriority
      ..blendRadius = (sphere ? radius : math.min(extent.x, math.min(extent.y, extent.z))) * 0.5
      ..blendWeight = 1.0
      ..overrides = LuminaPostProcessOverrides(fogDensityScale: fogDensityScale, fogColor: Vector3.copy(fogAlbedo))
      ..worldTransform = worldTransform
      ..halfExtent = extent
      ..sphereRadius = sphere ? radius : null
      ..owner = this;
  }

  void _syncShell() {
    final actor = owner;
    if (actor == null) return;
    final key = shellKey;
    if (_shell != null && _shellKey != key) {
      actor.removeComponent(_shell!);
      _shell = null;
    }
    if (_shell == null) {
      final captured = (
        shape: shape,
        radius: radius,
        extent: Vector3.copy(extent),
        albedo: Vector3.copy(fogAlbedo),
        density: fogDensity,
        heightFalloff: heightFalloff,
        radial: radialAttenuation,
      );
      final shell = LuminaStaticMeshComponent(
        meshAssetPath: key,
        assetUnitScale: 1.0,
        castShadows: false,
        receiveShadows: false,
        assetProvider: (_) async => LuminaFogShellGlbFactory.build(
          shape: captured.shape,
          radius: captured.radius,
          extent: captured.extent,
          albedo: captured.albedo,
          density: captured.density,
          heightFalloff: captured.heightFalloff,
          radialAttenuation: captured.radial,
        ),
      );
      shell.attachToComponent(this);
      actor.addComponent(shell);
      _shell = shell;
      _shellKey = key;
    }
    _shell!.visible = isActive;
  }

  void _sync() {
    _syncShell();
    final w = world;
    if (w == null) return;
    if (!identical(_blender, w.postProcessBlender)) {
      _blender?.removeVolume(volume);
      _blender = w.postProcessBlender;
      _blender!.addVolume(volume);
    }
    _refreshVolume();
  }

  @override
  void onRegister(LuminaActor ownerActor) {
    super.onRegister(ownerActor);
    _sync();
  }

  @override
  void onTick(double deltaTime) {
    super.onTick(deltaTime);
    _sync();
  }

  @override
  void onRenderPrep(LuminaWorld world) {
    super.onRenderPrep(world);
    _sync();
  }

  @override
  void onUnregister() {
    _blender?.removeVolume(volume);
    _blender = null;
    final shell = _shell;
    final actor = owner;
    if (shell != null && actor != null) actor.removeComponent(shell);
    _shell = null;
    _shellKey = null;
    super.onUnregister();
  }
}

/// Builds the fog shell glTF in memory: an inward-wound sphere or box whose
/// `COLOR_0` alpha carries the fog falloff, with an unlit, alpha-blended
/// material (`KHR_materials_unlit`, `alphaMode: BLEND`, single sided).
class LuminaFogShellGlbFactory {
  const LuminaFogShellGlbFactory._();

  static const int sphereRings = 16;
  static const int sphereSegments = 24;

  /// Subdivisions per box face edge, so the vertex alpha gradient reads.
  static const int boxSubdivisions = 8;

  /// The per-vertex alpha, 0..1, of a shell vertex at [local] (cm, centred).
  static double alphaAt(
    Vector3 local, {
    required double reach,
    required double density,
    required double heightFalloff,
    required double radialAttenuation,
  }) {
    final r = reach <= 0 ? 0.0 : (local.length / reach).clamp(0.0, 1.0);
    final radial = 1.0 - radialAttenuation * r;
    final above = math.max(0.0, local.y) / LuminaUnits.unitsPerMetre;
    final height = math.exp(-heightFalloff * above);
    return (density * radial * height).clamp(0.0, 1.0);
  }

  static Uint8List build({
    required LuminaLocalFogShape shape,
    required double radius,
    required Vector3 extent,
    required Vector3 albedo,
    required double density,
    required double heightFalloff,
    required double radialAttenuation,
  }) {
    final positions = <double>[];
    final indices = <int>[];
    if (shape == LuminaLocalFogShape.sphere) {
      _sphere(radius, positions, indices);
    } else {
      _box(extent, positions, indices);
    }
    // Inward winding: swap two indices of every triangle.
    for (var i = 0; i + 2 < indices.length; i += 3) {
      final t = indices[i + 1];
      indices[i + 1] = indices[i + 2];
      indices[i + 2] = t;
    }
    final vertexCount = positions.length ~/ 3;
    final reach = shape == LuminaLocalFogShape.sphere ? radius : math.max(extent.x, math.max(extent.y, extent.z));
    final colors = Uint8List(vertexCount * 4);
    for (var i = 0; i < vertexCount; i++) {
      final p = Vector3(positions[i * 3], positions[i * 3 + 1], positions[i * 3 + 2]);
      final a = alphaAt(p, reach: reach, density: density, heightFalloff: heightFalloff, radialAttenuation: radialAttenuation);
      colors[i * 4] = (albedo.x.clamp(0.0, 1.0) * 255).round();
      colors[i * 4 + 1] = (albedo.y.clamp(0.0, 1.0) * 255).round();
      colors[i * 4 + 2] = (albedo.z.clamp(0.0, 1.0) * 255).round();
      colors[i * 4 + 3] = (a * 255).round();
    }
    return _encodeGlb(positions, indices, colors);
  }

  static void _sphere(double r, List<double> positions, List<int> indices) {
    for (var ring = 0; ring <= sphereRings; ring++) {
      final v = ring / sphereRings;
      final phi = v * math.pi;
      for (var seg = 0; seg <= sphereSegments; seg++) {
        final u = seg / sphereSegments;
        final theta = u * 2 * math.pi;
        positions.addAll([
          r * math.sin(phi) * math.cos(theta),
          r * math.cos(phi),
          r * math.sin(phi) * math.sin(theta),
        ]);
      }
    }
    // Wound outward (CCW seen from outside) like the box faces, so the one
    // swap in [build] turns both inward. Rings run top to bottom and theta
    // runs towards +Z, so (a, a + 1, b) is the outward order.
    final stride = sphereSegments + 1;
    for (var ring = 0; ring < sphereRings; ring++) {
      for (var seg = 0; seg < sphereSegments; seg++) {
        final a = ring * stride + seg;
        final b = a + stride;
        indices.addAll([a, a + 1, b, a + 1, b + 1, b]);
      }
    }
  }

  static void _box(Vector3 e, List<double> positions, List<int> indices) {
    // Six faces, each a grid; face normal outward (CCW seen from outside).
    final faces = <(Vector3, Vector3, Vector3)>[
      (Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)),
      (Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)),
      (Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)),
      (Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)),
      (Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)),
      (Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0)),
    ];
    final n = boxSubdivisions;
    for (final (normal, tangent, bitangent) in faces) {
      final base = positions.length ~/ 3;
      for (var j = 0; j <= n; j++) {
        for (var i = 0; i <= n; i++) {
          final u = i / n * 2 - 1;
          final v = j / n * 2 - 1;
          final p = Vector3(
            (normal.x + tangent.x * u + bitangent.x * v) * e.x,
            (normal.y + tangent.y * u + bitangent.y * v) * e.y,
            (normal.z + tangent.z * u + bitangent.z * v) * e.z,
          );
          positions.addAll([p.x, p.y, p.z]);
        }
      }
      for (var j = 0; j < n; j++) {
        for (var i = 0; i < n; i++) {
          final a = base + j * (n + 1) + i;
          final b = a + n + 1;
          indices.addAll([a, a + 1, b, a + 1, b + 1, b]);
        }
      }
    }
  }

  static Uint8List _encodeGlb(List<double> positions, List<int> indices, Uint8List colors) {
    final vertexCount = positions.length ~/ 3;
    final pos = Float32List.fromList(positions);
    final idx = Uint32List.fromList(indices);
    final bin = BytesBuilder();
    void pad() {
      while (bin.length % 4 != 0) {
        bin.addByte(0);
      }
    }

    final posOffset = bin.length;
    bin.add(pos.buffer.asUint8List());
    pad();
    final colOffset = bin.length;
    bin.add(colors);
    pad();
    final idxOffset = bin.length;
    bin.add(idx.buffer.asUint8List());
    pad();
    final binBytes = bin.toBytes();

    final min = [double.infinity, double.infinity, double.infinity];
    final max = [-double.infinity, -double.infinity, -double.infinity];
    for (var i = 0; i < vertexCount; i++) {
      for (var k = 0; k < 3; k++) {
        final v = positions[i * 3 + k];
        if (v < min[k]) min[k] = v;
        if (v > max[k]) max[k] = v;
      }
    }

    final gltf = <String, dynamic>{
      'asset': {'version': '2.0', 'generator': 'lumina LuminaFogShellGlbFactory'},
      'extensionsUsed': ['KHR_materials_unlit'],
      'scene': 0,
      'scenes': [
        {
          'nodes': [0]
        }
      ],
      'nodes': [
        {'mesh': 0, 'name': 'FogShell'}
      ],
      'meshes': [
        {
          'name': 'FogShell',
          'primitives': [
            {
              'attributes': {'POSITION': 0, 'COLOR_0': 1},
              'indices': 2,
              'material': 0,
              'mode': 4,
            }
          ],
        }
      ],
      'materials': [
        {
          'name': 'M_FogShell',
          'alphaMode': 'BLEND',
          'doubleSided': false,
          'extensions': {'KHR_materials_unlit': <String, dynamic>{}},
          'pbrMetallicRoughness': {
            'baseColorFactor': [1.0, 1.0, 1.0, 1.0],
            'metallicFactor': 0.0,
            'roughnessFactor': 1.0,
          },
        }
      ],
      'accessors': [
        {'bufferView': 0, 'componentType': 5126, 'count': vertexCount, 'type': 'VEC3', 'min': min, 'max': max},
        {'bufferView': 1, 'componentType': 5121, 'normalized': true, 'count': vertexCount, 'type': 'VEC4'},
        {'bufferView': 2, 'componentType': 5125, 'count': indices.length, 'type': 'SCALAR'},
      ],
      'bufferViews': [
        {'buffer': 0, 'byteOffset': posOffset, 'byteLength': pos.lengthInBytes, 'target': 34962},
        {'buffer': 0, 'byteOffset': colOffset, 'byteLength': colors.length, 'target': 34962},
        {'buffer': 0, 'byteOffset': idxOffset, 'byteLength': idx.lengthInBytes, 'target': 34963},
      ],
      'buffers': [
        {'byteLength': binBytes.length}
      ],
    };

    final json = <int>[...utf8.encode(jsonEncode(gltf))];
    while (json.length % 4 != 0) {
      json.add(0x20);
    }
    final out = BytesBuilder();
    void u32(int v) => out.add(Uint8List(4)..buffer.asByteData().setUint32(0, v, Endian.little));
    u32(0x46546C67); // glTF
    u32(2);
    u32(12 + 8 + json.length + 8 + binBytes.length);
    u32(json.length);
    u32(0x4E4F534A); // JSON
    out.add(json);
    u32(binBytes.length);
    u32(0x004E4942); // BIN
    out.add(binBytes);
    return out.toBytes();
  }
}

import 'dart:math' as math;

import 'package:lumina_core/lumina_core.dart';
import 'package:vector_math/vector_math_64.dart';

/// A box of the sandbox level in authoring space (cm, Z up): its centre,
/// its size along its own axes and its authoring rotation
/// (`[pitch, roll, yaw]` degrees, as `metadata.actors` stores it).
class GaspLevelBlock {
  final String name;
  final List<double> center;
  final List<double> size;
  final List<double> rotation;

  /// `block`, `traversable` or `floor`: which grid material it gets.
  final String kind;

  const GaspLevelBlock(this.name, this.center, this.size, this.rotation, {this.kind = 'block'});

  /// A box from the eight world corners of a corner-pivot cube in a
  /// left-handed Z-up frame (X forward, Y right; the sample's level export),
  /// ordered `x * 4 + y * 2 + z` over the cube's local min/max. Authoring
  /// space is right-handed with X right and Y forward, so the export's X and
  /// Y swap; the box's own X follows the cube's Y edge and its Y the X edge,
  /// which keeps it a proper rotation.
  factory GaspLevelBlock.fromCorners(String name, List<List<double>> corners, {String kind = 'block'}) {
    Vector3 swap(List<double> v) => Vector3(v[1], v[0], v[2]);
    final o = swap(corners[0]);
    final edgeX = swap(corners[4]) - o; // the cube's local X
    final edgeY = swap(corners[2]) - o; // local Y
    final edgeZ = swap(corners[1]) - o; // local Z
    final center = o + (edgeX + edgeY + edgeZ) * 0.5;
    var a = edgeY, b = edgeX, c = edgeZ;
    if (a.cross(b).dot(c) < 0) c = -c; // a mirrored (negative) scale
    final rotation = Matrix3.columns(a.normalized(), b.normalized(), c.normalized());
    return GaspLevelBlock(
      name,
      [center.x, center.y, center.z],
      [a.length, b.length, c.length],
      authoringRotation(rotation),
      kind: kind,
    );
  }

  /// The authoring rotation (`[pitch, roll, yaw]` degrees) whose matrix is
  /// [authoring] (columns: the rotated authoring X, Y and Z axes). The
  /// inverse of [LuminaAxes.rotation]: in runtime axes that is
  /// `Ry(−yaw) · Rx(pitch) · Rz(roll)`.
  static List<double> authoringRotation(Matrix3 authoring) {
    // Authoring (x, y, z) → runtime (x, z, −y).
    final toRuntime = Matrix3(1, 0, 0, 0, 0, -1, 0, 1, 0); // column-major
    final m = toRuntime * authoring * toRuntime.transposed();
    // m = Ry(a) · Rx(b) · Rz(c): m12 = −sin b, m02 / m22 = tan a, m10 / m11 = tan c.
    final b = math.asin((-m.entry(1, 2)).clamp(-1.0, 1.0));
    double a, c;
    if (math.cos(b).abs() > 1e-6) {
      a = math.atan2(m.entry(0, 2), m.entry(2, 2));
      c = math.atan2(m.entry(1, 0), m.entry(1, 1));
    } else {
      a = math.atan2(-m.entry(2, 0), m.entry(0, 0));
      c = 0.0;
    }
    const r2d = 180.0 / math.pi;
    double clean(double deg) {
      final r = (deg * 1e4).roundToDouble() / 1e4;
      return r == 0 ? 0.0 : r;
    }

    return [clean(b * r2d), clean(c * r2d), clean(-a * r2d)];
  }
}

/// `L_Sandbox`: the sample's playground as a level — its level blocks
/// (walls, ramps, stairs, low and high blocks, beams) as box primitives
/// with world-aligned grid materials, a floor, a sun, a sky, height fog, the
/// player start, and props.
abstract final class GaspSandboxLevel {
  static const String levelName = 'L_Sandbox';
  static const String levelPath = 'contents/levels/$levelName.lmas';

  static const String floorMaterial = 'contents/materials/M_Grid_Floor.lmas';
  static const String blockMaterial = 'contents/materials/M_Grid_Block.lmas';
  static const String traversableMaterial = 'contents/materials/M_Grid_Traversable.lmas';

  /// Grid material name → (base colour, line colour), linear RGB.
  static const Map<String, (List<double>, List<double>)> gridColors = {
    'M_Grid_Floor': ([0.18, 0.19, 0.21], [0.42, 0.44, 0.48]),
    'M_Grid_Block': ([0.55, 0.56, 0.58], [0.26, 0.27, 0.30]),
    'M_Grid_Traversable': ([0.62, 0.38, 0.16], [0.30, 0.16, 0.06]),
  };

  /// A lit, world-aligned grid (`.mat` source): lines every metre and
  /// finer ones every 25 cm on whichever world plane the surface faces, so
  /// it reads the same on a 20 m floor and a 40 cm step.
  static String gridMaterialSource(String name) {
    final (base, line) = gridColors[name]!;
    String v(List<double> c) => 'vec3(${c.map((x) => x.toStringAsFixed(3)).join(', ')})';
    return '''
material {
    name : $name,
    shadingModel : lit,
    flipUV : false
}

fragment {
    float gridLines(highp vec2 p, float cell, float width) {
        highp vec2 g = abs(fract(p / cell - 0.5) - 0.5) * cell;
        highp vec2 w = max(fwidth(p), vec2(1e-4));
        vec2 l = 1.0 - smoothstep(vec2(width * 0.5), vec2(width * 0.5) + w, g);
        return max(l.x, l.y);
    }

    void material(inout MaterialInputs material) {
        prepareMaterial(material);
        highp vec3 p = getUserWorldPosition();
        vec3 n = abs(getWorldGeometricNormalVector());
        highp vec2 uv = n.y > 0.5 ? p.xz : (n.x > 0.5 ? p.zy : p.xy);
        float major = gridLines(uv, 100.0, 2.0);
        float minor = gridLines(uv, 25.0, 1.0);
        vec3 color = mix(${v(base)}, ${v(line)}, max(major, minor * 0.35));
        material.baseColor = vec4(color, 1.0);
        material.roughness = 0.85;
        material.metallic = 0.0;
    }
}
''';
  }

  static String _material(String kind) => switch (kind) {
        'floor' => floorMaterial,
        'traversable' => traversableMaterial,
        _ => blockMaterial,
      };

  /// The sample's level blocks from its level export (`actors` with
  /// `components[].corners`): every `SM_Cube` of a `LevelBlock_C` (block) or
  /// `LevelBlock_Traversable_C` (traversable). The export's giant floor
  /// block is left out; [floor] replaces it. Returns the blocks and the
  /// player start (authoring cm) when the export has one.
  static (List<GaspLevelBlock>, List<double>?) blocksFromExport(Map<String, dynamic> export) {
    final blocks = <GaspLevelBlock>[];
    List<double>? start;
    for (final a in ((export['actors'] as List?) ?? const []).cast<Map>()) {
      final cls = '${a['class']}';
      if (cls == 'PlayerStart') {
        final t = ((a['transform'] as Map)['t'] as List).map((v) => (v as num).toDouble()).toList();
        start = [t[1], t[0], t[2]];
        continue;
      }
      final kind = switch (cls) {
        'LevelBlock_C' => 'block',
        'LevelBlock_Traversable_C' => 'traversable',
        _ => null,
      };
      if (kind == null) continue;
      for (final c in ((a['components'] as List?) ?? const []).cast<Map>()) {
        final corners = (c['corners'] as List?)?.map((p) => (p as List).map((v) => (v as num).toDouble()).toList()).toList();
        if (corners == null || corners.length != 8 || !'${c['mesh']}'.contains('SM_Cube')) continue;
        final block = GaspLevelBlock.fromCorners('${a['label'] ?? a['name']}', corners, kind: kind);
        // The export's floor is a 2 km cube under everything.
        if (block.size[0] > 50000 || block.size[1] > 50000) continue;
        blocks.add(block);
      }
    }
    return (blocks, start);
  }

  /// A playground of its own when there is no level export: ramps, stairs,
  /// low / mid / high blocks, a wall, a balance beam and a platform.
  static List<GaspLevelBlock> defaultBlocks() {
    final blocks = <GaspLevelBlock>[
      // Low, mid and high blocks to step, vault and climb (60 / 120 / 200 cm).
      const GaspLevelBlock('Block_Low', [600, 800, 30], [300, 200, 60], [0, 0, 0], kind: 'traversable'),
      const GaspLevelBlock('Block_Mid', [1000, 800, 60], [300, 200, 120], [0, 0, 0], kind: 'traversable'),
      const GaspLevelBlock('Block_High', [1400, 800, 100], [300, 200, 200], [0, 0, 0], kind: 'traversable'),
      // A long wall and a narrow balance beam (20 cm wide).
      const GaspLevelBlock('Wall', [-900, 1200, 150], [40, 1600, 300], [0, 0, 0]),
      const GaspLevelBlock('Beam', [-300, 1500, 40], [20, 1200, 20], [0, 0, 0], kind: 'traversable'),
      // A platform reached by a 20° ramp on one side and stairs on the other.
      const GaspLevelBlock('Platform', [400, 2600, 100], [800, 800, 200], [0, 0, 0]),
    ];
    // The ramp: 20° up toward +Y, its top edge meeting the platform's top.
    const angle = 20.0;
    final rad = angle * math.pi / 180.0;
    const height = 200.0, thickness = 20.0;
    final length = height / math.sin(rad);
    final run = height / math.tan(rad);
    blocks.add(GaspLevelBlock('Ramp', [400, 2200 - run / 2, height / 2 - thickness / 2 / math.cos(rad)],
        [400, length, thickness], [angle, 0, 0]));
    // Stairs: ten 20 cm risers, 40 cm deep, toward −X.
    for (var i = 0; i < 10; i++) {
      final h = 20.0 * (i + 1);
      blocks.add(GaspLevelBlock('Stairs_$i', [0 - 40.0 * (9 - i) - 20, 2600, h / 2], [40, 400, h], [0, 0, 0]));
    }
    return blocks;
  }

  static Map<String, dynamic> _primitive(GaspLevelBlock b, int i) {
    final id = 'sandbox_${i}_${b.name.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_')}';
    return {
      'id': id,
      'name': b.name,
      'type': 'Primitive',
      'parentId': 'folder_blocks',
      'location': b.center,
      'rotation': b.rotation,
      'scale': [1.0, 1.0, 1.0],
      'isVisible': true,
      'isLocked': false,
      'mobility': 'Static',
      'lightIntensity': 0.0,
      'castShadows': true,
      'lightColorHex': '#FFFFFF',
      'materialPath': _material(b.kind),
      'meshAssetPath': null,
      'components': [
        {
          'id': '${id}_mesh',
          'type': 'LuminaProceduralMeshComponent',
          'name': 'Shape',
          'enabled': true,
          'properties': {
            'shape': 'box',
            'sizeX': b.size[0],
            'sizeY': b.size[1],
            'sizeZ': b.size[2],
            'colorHex': b.kind == 'traversable' ? '#9E6128' : '#8C8F94',
          },
        },
      ],
    };
  }

  /// A placed mesh asset (a prop) at [location] (cm), turned [yaw] degrees.
  static Map<String, dynamic> prop(String id, String name, String meshAssetPath, List<double> location,
          {double yaw = 0.0, double scale = 1.0}) =>
      {
        'id': id,
        'name': name,
        'type': 'StaticMesh',
        'parentId': 'folder_props',
        'location': location,
        'rotation': [0.0, 0.0, yaw],
        'scale': [scale, scale, scale],
        'isVisible': true,
        'isLocked': false,
        'mobility': 'Static',
        'lightIntensity': 0.0,
        'castShadows': true,
        'lightColorHex': '#FFFFFF',
        'materialPath': null,
        'meshAssetPath': meshAssetPath,
        'components': <Map<String, dynamic>>[],
      };

  static Map<String, dynamic> _folder(String id, String name) => {
        'id': id,
        'name': name,
        'type': 'Folder',
        'parentId': null,
        'location': [0.0, 0.0, 0.0],
        'rotation': [0.0, 0.0, 0.0],
        'scale': [1.0, 1.0, 1.0],
        'isVisible': true,
        'isLocked': false,
        'mobility': 'Static',
        'components': <Map<String, dynamic>>[],
      };

  /// The level's actors: the blocks, a [floorSize] cm square floor centred
  /// on the blocks, the player start at [playerStart] bound to [gameModePath],
  /// sun, sky, fog, and [props].
  static List<Map<String, dynamic>> actors({
    required List<GaspLevelBlock> blocks,
    required List<double> playerStart,
    required String gameModePath,
    List<Map<String, dynamic>> props = const [],
    double floorSize = 12000.0,
  }) {
    var minX = playerStart[0], maxX = playerStart[0], minY = playerStart[1], maxY = playerStart[1];
    for (final b in blocks) {
      minX = math.min(minX, b.center[0]);
      maxX = math.max(maxX, b.center[0]);
      minY = math.min(minY, b.center[1]);
      maxY = math.max(maxY, b.center[1]);
    }
    final floorX = math.max(floorSize, maxX - minX + 4000), floorY = math.max(floorSize, maxY - minY + 4000);
    final floor = GaspLevelBlock('Floor', [(minX + maxX) / 2, (minY + maxY) / 2, -10], [floorX, floorY, 20], [0, 0, 0],
        kind: 'floor');
    final start = luminaTemplatePlayerStart(location: playerStart);
    (start['components'] as List).add(<String, dynamic>{
      'id': '${start['id']}_gamemode',
      'type': 'LuminaGameModeBinding',
      'name': 'Game Mode',
      'enabled': true,
      'properties': <String, dynamic>{'gameModeBlueprint': gameModePath},
    });
    return [
      _folder('folder_blocks', 'Level Blocks'),
      _folder('folder_props', 'Props'),
      _primitive(floor, 0),
      for (final (i, b) in blocks.indexed) _primitive(b, i + 1),
      start,
      luminaTemplateSunActor(),
      luminaTemplateSkyActor(),
      {
        'id': 'act_fog',
        'name': 'ExponentialHeightFog',
        'type': 'ExponentialHeightFog',
        'parentId': null,
        'location': [0.0, 0.0, 0.0],
        'rotation': [0.0, 0.0, 0.0],
        'scale': [1.0, 1.0, 1.0],
        'isVisible': true,
        'isLocked': false,
        'mobility': 'Static',
        'components': [
          {
            'id': 'act_fog_fog',
            'type': 'LuminaExponentialHeightFogComponent',
            'name': 'Fog',
            'enabled': true,
            'properties': <String, dynamic>{
              'enabled': true,
              'fogDensity': 0.01,
              'fogHeightFalloff': 0.2,
              'startDistance': 3000.0,
              'fogMaxOpacity': 0.6,
              'useSkyColor': true,
            },
          },
        ],
      },
      ...props,
    ];
  }

  /// The level container (`LuminaLevelDocument` JSON) for [actors].
  static Map<String, dynamic> levelContainer(List<Map<String, dynamic>> actors) => {
        'assetId': 'level_$levelName',
        'name': levelName,
        'type': 'level',
        'relativePath': levelPath,
        'rawPayload': null,
        'metadata': {'actors': actors},
      };
}

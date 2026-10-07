import 'dart:convert';
import 'dart:typed_data';

import 'package:lumina_core/src/services/encoded_image_format.dart';
import 'package:lumina_core/src/services/engine_logger_service.dart';

part 'glb_reader/parse_glb.dart';
part 'glb_reader/chunks_images_animations.dart';

/// A Draco-compressed primitive (`KHR_draco_mesh_compression`) decoded to
/// flat arrays: positions `[x0, y0, z0, …]`, UVs `[u0, v0, …]` and triangle
/// indices.
class GlbDracoMesh {
  final List<double> positions;
  final List<double> uvs;
  final List<int> indices;

  const GlbDracoMesh({required this.positions, required this.uvs, required this.indices});
}

/// Decoded pixels: `width * height` RGBA8 texels, row-major.
typedef GlbDecodedPixels = ({int width, int height, Uint8List rgba});

/// Decodes a Draco-compressed primitive; null when it does not decode.
typedef GlbDracoDecoder = GlbDracoMesh? Function(Uint8List compressed);

/// Decodes an encoded image (PNG, JPEG, …) to pixels; null when its format is
/// not one the decoder turns into pixels.
typedef GlbImageDecoder = Future<GlbDecodedPixels?> Function(Uint8List encoded);

/// Rewrites a GLB before it is read (the editor's texture and skinning
/// sanitizer).
typedef GlbBytesTransform = Future<Uint8List> Function(Uint8List glb);

/// The native decoders [GlbReader] calls for what pure Dart cannot read.
///
/// The reader itself is pure Dart. The engine provides both decoders
/// (`LuminaGlbLoader`: Filament's Draco decoder through flutter_filament, and
/// the platform image codec). Without a [draco] decoder a Draco-compressed
/// primitive keeps only its accessor bounds; without an [image] decoder base
/// colour textures are not sampled into vertex colours (the material's base
/// colour factor is used). [prepare] rewrites the bytes first; the editor
/// passes its sanitizer (TGA to PNG, the texture budget, four normalised
/// skin influences).
class GlbDecoders {
  final GlbDracoDecoder? draco;
  final GlbImageDecoder? image;
  final GlbBytesTransform? prepare;

  const GlbDecoders({this.draco, this.image, this.prepare});

  /// These decoders with [prepare] replaced.
  GlbDecoders withPrepare(GlbBytesTransform? prepare) => GlbDecoders(draco: draco, image: image, prepare: prepare);
}

enum GlbNodeType { group, mesh, light, bone, camera }

class GlbNode {
  final int index;
  final String name;
  final int? meshIndex;
  final String? meshName;
  final int primitiveCount;
  final List<GlbNode> children;
  final List<double>? translation;
  final List<double>? rotation; // Quaternion [x, y, z, w]
  final List<double>? scale;
  final GlbNodeType type;
  final List<double> positions;
  final List<int> indices;
  bool isVisible;

  GlbNode({
    required this.index,
    required this.name,
    this.meshIndex,
    this.meshName,
    this.primitiveCount = 0,
    List<GlbNode>? children,
    this.translation,
    this.rotation,
    this.scale,
    this.type = GlbNodeType.group,
    List<double>? positions,
    List<int>? indices,
    this.isVisible = true,
  }) : children = children ?? [],
       positions = positions ?? [],
       indices = indices ?? [];

  int get totalDescendantCount =>
      children.length +
      children.fold(0, (sum, c) => sum + c.totalDescendantCount);
  int get directChildCount => children.length;

  List<int> getAllDescendantNodeIndices() {
    final List<int> res = [index];
    for (final c in children) {
      res.addAll(c.getAllDescendantNodeIndices());
    }
    return res;
  }

  List<double> getAllDescendantPositions() {
    final List<double> res = List.from(positions);
    for (final c in children) {
      res.addAll(c.getAllDescendantPositions());
    }
    return res;
  }

  List<int> getAllDescendantIndices() {
    final List<int> res = List.from(indices);
    int offset = positions.length ~/ 3;
    for (final c in children) {
      final cIndices = c.getAllDescendantIndices();
      final cPositions = c.getAllDescendantPositions();
      for (final idx in cIndices) {
        res.add(offset + idx);
      }
      offset += cPositions.length ~/ 3;
    }
    return res;
  }
}

class GlbSubPrimitive {
  final List<double> positions;
  final List<int> indices;
  final Uint8List? vertexColors;
  final List<double> baseColor;
  final String? materialName;
  final int? materialIndex;

  const GlbSubPrimitive({
    required this.positions,
    required this.indices,
    this.vertexColors,
    this.baseColor = const [0.75, 0.78, 0.85],
    this.materialName,
    this.materialIndex,
  });

  int get vertexCount => positions.length ~/ 3;
  int get triangleCount => indices.length ~/ 3;
}

class GlbMorphTarget {
  final String name;
  final List<double> positionDeltas; // flat [dx0, dy0, dz0, dx1, dy1, dz1, ...]

  const GlbMorphTarget({required this.name, required this.positionDeltas});

  int get vertexCount => positionDeltas.length ~/ 3;
}

class GlbAnimationChannel {
  final int nodeIndex;
  final String nodeName;
  final String path; // e.g. 'translation', 'rotation', 'scale', 'weights'
  final List<double> keyframeTimes;
  final List<double> values;
  final String interpolation; // 'LINEAR', 'STEP', 'CUBICSPLINE'

  const GlbAnimationChannel({
    required this.nodeIndex,
    required this.nodeName,
    required this.path,
    required this.keyframeTimes,
    this.values = const [],
    this.interpolation = 'LINEAR',
  });
}

class GlbAnimationClip {
  final String name;
  final double duration; // in seconds
  final Set<int>
  animatedNodeIndices; // Set of glTF node indices targeted by channels
  final List<String>
  channelTargetPaths; // e.g. ['translation', 'rotation', 'scale', 'weights']
  final List<GlbAnimationChannel> channels;
  final List<double> compositeKeyframeTimes;

  const GlbAnimationClip({
    required this.name,
    required this.duration,
    this.animatedNodeIndices = const {},
    this.channelTargetPaths = const [],
    this.channels = const [],
    this.compositeKeyframeTimes = const [],
  });
}

class GlbMeshData {
  final List<GlbSubPrimitive> subPrimitives;
  final List<double> positions; // Combined flat array
  final List<int> indices; // Combined triangle indices
  final List<double> uvs; // Flat array of [u0, v0, u1, v1, ...]
  final List<double> minBounds; // [minX, minY, minZ]
  final List<double> maxBounds; // [maxX, maxY, maxZ]
  final List<double> baseColor; // [r, g, b] range 0.0 - 1.0
  final Uint8List?
  vertexColors; // Flat array of [r0, g0, b0, r1, g1, b1, ...] for every vertex
  final Uint8List? rawPayload; // Original binary payload of the GLB model
  final List<GlbNode> rootNodes; // Hierarchical root nodes
  final List<GlbNode> allNodes; // Flat array of all nodes in model
  final List<String> materialNames; // Extracted material slot names
  final Set<int> skeletonJointIndices;
  final List<GlbMorphTarget> morphTargets;
  final Uint16List? jointsPerVertex;
  final Float32List? weightsPerVertex;
  final int maxInfluences;
  final List<GlbAnimationClip> animations;

  const GlbMeshData({
    this.subPrimitives = const [],
    required this.positions,
    required this.indices,
    this.uvs = const [],
    required this.minBounds,
    required this.maxBounds,
    this.baseColor = const [0.75, 0.78, 0.85],
    this.vertexColors,
    this.rawPayload,
    this.rootNodes = const [],
    this.allNodes = const [],
    this.materialNames = const [],
    this.skeletonJointIndices = const {},
    this.morphTargets = const [],
    this.jointsPerVertex,
    this.weightsPerVertex,
    this.maxInfluences = 4,
    this.animations = const [],
  });

  int get vertexCount => positions.length ~/ 3;
  int get triangleCount => indices.length ~/ 3;
  int get boneCount => allNodes.where((n) => n.type == GlbNodeType.bone).length;
  Set<int> get animatedNodeIndices => animations.fold<Set<int>>(
    {},
    (prev, a) => prev..addAll(a.animatedNodeIndices),
  );

  GlbMeshData copyWith({
    List<GlbSubPrimitive>? subPrimitives,
    List<double>? positions,
    List<int>? indices,
    List<double>? uvs,
    List<double>? minBounds,
    List<double>? maxBounds,
    List<double>? baseColor,
    Uint8List? vertexColors,
    Uint8List? rawPayload,
    List<GlbNode>? rootNodes,
    List<GlbNode>? allNodes,
    List<String>? materialNames,
    Set<int>? skeletonJointIndices,
    List<GlbMorphTarget>? morphTargets,
    Uint16List? jointsPerVertex,
    Float32List? weightsPerVertex,
    int? maxInfluences,
    List<GlbAnimationClip>? animations,
  }) {
    return GlbMeshData(
      subPrimitives: subPrimitives ?? this.subPrimitives,
      positions: positions ?? this.positions,
      indices: indices ?? this.indices,
      uvs: uvs ?? this.uvs,
      minBounds: minBounds ?? this.minBounds,
      maxBounds: maxBounds ?? this.maxBounds,
      baseColor: baseColor ?? this.baseColor,
      vertexColors: vertexColors ?? this.vertexColors,
      rawPayload: rawPayload ?? this.rawPayload,
      rootNodes: rootNodes ?? this.rootNodes,
      allNodes: allNodes ?? this.allNodes,
      materialNames: materialNames ?? this.materialNames,
      skeletonJointIndices: skeletonJointIndices ?? this.skeletonJointIndices,
      morphTargets: morphTargets ?? this.morphTargets,
      jointsPerVertex: jointsPerVertex ?? this.jointsPerVertex,
      weightsPerVertex: weightsPerVertex ?? this.weightsPerVertex,
      maxInfluences: maxInfluences ?? this.maxInfluences,
      animations: animations ?? this.animations,
    );
  }
}

class _GlbDecodedImage {
  final int width;
  final int height;
  final Uint8List rawPixels;

  const _GlbDecodedImage(this.width, this.height, this.rawPixels);

  List<int> sample(double u, double v) {
    final double wrappedU = u - u.floorToDouble();
    final double wrappedV = v - v.floorToDouble();

    final px = (wrappedU * (width - 1)).floor().clamp(0, width - 1);
    final py = (wrappedV * (height - 1)).floor().clamp(0, height - 1);
    final idx = (py * width + px) * 4;
    return [rawPixels[idx], rawPixels[idx + 1], rawPixels[idx + 2]];
  }
}

class _NodeTransform {
  final List<double> translation;
  final List<double> rotation; // Quaternion [x, y, z, w]
  final List<double> scale;

  _NodeTransform(this.translation, this.rotation, this.scale);
}

/// Reads a binary glTF (`.glb`), or a `.lmas` JSON container carrying one as
/// `raw_payload`, into [GlbMeshData]: the node hierarchy, world-space
/// positions and indices per primitive, UVs, vertex colours (sampled from the
/// base colour texture when [GlbDecoders.image] is given), skinning, morph
/// targets and animation clips.
abstract final class GlbReader {
  static final EngineLoggerService _logger = EngineLoggerService();

  /// [bytes] read into mesh data, or null when they are not a readable GLB.
  static Future<GlbMeshData?> parse(Uint8List bytes, {GlbDecoders decoders = const GlbDecoders()}) =>
      _parseGlb(bytes, decoders);
}

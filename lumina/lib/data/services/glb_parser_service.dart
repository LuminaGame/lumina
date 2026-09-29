import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:image/image.dart' as imglib;
import 'encoded_image_decoder.dart';
import 'encoded_image_format.dart';
import 'engine_logger_service.dart';
import 'tga_decoder_service.dart';

part 'glb_parser_service/parse_glb.dart';
part 'glb_parser_service/chunks_images_animations.dart';
part 'glb_parser_service/texture_conversion.dart';
part 'glb_parser_service/skinning_sanitizer.dart';

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

class GlbParserService {
  static final EngineLoggerService _logger = EngineLoggerService();
  static const parseGlb = _parseGlb;

  /// Largest edge, in pixels, an imported texture may keep. Source art above this
  /// is downscaled on import: Filament uploads PNG-sourced images as uncompressed
  /// RGBA8 with a full mip chain, so one 8192x8192 image costs ~341 MB of VRAM and
  /// a handful of them exhaust the device heap.
  /// At 2048 the same image costs ~21 MB.
  static const int defaultMaxTextureSize = 2048;

  /// Version of [convertGlbTgaToPng]'s output. Part of every persisted
  /// derived-data key (`DerivedDataCache.sanitizedGlbKey`), so
  /// bump it whenever the sanitizer's output for the same input changes (the
  /// budget's resampling or encoder settings, the skinning rules, the image
  /// branches): entries written by an older converter then miss and rebuild.
  static const int sanitizerVersion = 2;

  static int _decodingConversions = 0;

  /// How many times this isolate ran the sanitizer on its expensive path — an
  /// asset whose images had to be decoded (over budget, TGA, unrecognised or
  /// resolved from disk). A load served by the derived-data cache never adds
  /// to it, which is how tests prove a cached session skipped the downscale.
  static int get decodingConversionCount => _decodingConversions;

  /// [convertGlbTgaToPng] run on a background isolate.
  ///
  /// Enforcing the texture budget means decoding and resizing every oversized
  /// source image — ~37 s for an asset carrying fourteen 8192x8192 PNGs. On the UI
  /// isolate that freezes the editor for the whole load, so callers that are already
  /// asynchronous (the asset load path) should use this instead.
  ///
  /// The worker isolate owns its own [EngineLoggerService] singleton, so its log
  /// lines would otherwise never reach the editor's Output Log. They are captured
  /// inside the worker and replayed here, keeping their original timestamps.
  static Future<Uint8List> convertGlbTgaToPngAsync(
    Uint8List glbBytes, {
    List<String>? searchDirs,
    int maxTextureSize = defaultMaxTextureSize,
  }) async {
    // Spawning a worker for an asset that needs no decoding costs more than the
    // work itself, and an isolate never completes inside a widget test's
    // fake-async zone — so only hand off when there is real work to do.
    if (!inspectImageWork(glbBytes, maxTextureSize: maxTextureSize).needsDecoding) {
      return convertGlbTgaToPng(
        glbBytes,
        searchDirs: searchDirs,
        maxTextureSize: maxTextureSize,
      );
    }

    _decodingConversions++;
    final result = await Isolate.run(() {
      late Uint8List sanitized;
      final logs = EngineLoggerService().captureLogs(() {
        sanitized = convertGlbTgaToPng(
          glbBytes,
          searchDirs: searchDirs,
          maxTextureSize: maxTextureSize,
        );
      });
      return (bytes: sanitized, logs: logs);
    });

    _logger.replay(result.logs);
    return result.bytes;
  }

  /// What sanitizing [glbBytes] costs, read from image headers only.
  ///
  /// `needsDecoding`: some image has to be decoded — an embedded image over
  /// [maxTextureSize], a TGA needing transcoding, an image whose header this
  /// pipeline does not recognise, or one that still has to be resolved from
  /// disk. Otherwise [convertGlbTgaToPng] is cheap and runs inline.
  ///
  /// `selfContained`: every image is embedded through a bufferView, so the
  /// sanitizer's output depends on [glbBytes] alone. Only such sources can be
  /// cached by their content hash (`DerivedDataCache`); an
  /// image referenced by `uri` is read from files the hash does not cover.
  static ({bool needsDecoding, bool selfContained}) inspectImageWork(
    Uint8List glbBytes, {
    int maxTextureSize = defaultMaxTextureSize,
  }) {
    try {
      if (glbBytes.length < 20) return (needsDecoding: false, selfContained: true);
      final byteData = ByteData.sublistView(glbBytes);
      if (byteData.getUint32(0, Endian.little) != 0x46546C67) {
        return (needsDecoding: false, selfContained: true);
      }

      final jsonLength = byteData.getUint32(12, Endian.little);
      if (byteData.getUint32(16, Endian.little) != 0x4E4F534A) {
        return (needsDecoding: false, selfContained: true);
      }

      final json = jsonDecode(utf8.decode(glbBytes.sublist(20, 20 + jsonLength)));
      if (json is! Map) return (needsDecoding: false, selfContained: true);

      final images = json['images'] as List?;
      if (images == null || images.isEmpty) return (needsDecoding: false, selfContained: true);

      final bufferViews = json['bufferViews'] as List? ?? const [];
      final binStart = 20 + jsonLength + 8;

      var needsDecoding = false;
      for (final entry in images) {
        if (entry is! Map) continue;
        final bvIdx = entry['bufferView'] as int?;
        if (bvIdx == null || bvIdx >= bufferViews.length) {
          // No bufferView means the image still has to be resolved from disk.
          return (needsDecoding: true, selfContained: false);
        }
        if (needsDecoding) continue; // Only self-containment is still open.
        final bv = bufferViews[bvIdx] as Map;
        final offset = binStart + ((bv['byteOffset'] as int?) ?? 0);
        final length = bv['byteLength'] as int? ?? 0;
        if (offset + length > glbBytes.length) continue;

        final head = glbBytes.sublist(offset, offset + math.min(length, 64));
        if (TgaDecoderService.isTga(head)) {
          needsDecoding = true;
          continue;
        }

        final size = _peekImageSize(head);
        if (size == null ||
            (maxTextureSize > 0 &&
                (size.width > maxTextureSize || size.height > maxTextureSize))) {
          // Unknown format: only a decode can tell. Or simply over budget.
          needsDecoding = true;
        }
      }
      return (needsDecoding: needsDecoding, selfContained: true);
    } catch (_) {
      // Anything unexpected: take the safe, off-thread path, and never cache it.
      return (needsDecoding: true, selfContained: false);
    }
  }
  /// Inspects GLB binary for any embedded or referenced TGA textures and external URIs,
  /// converts them to standard PNGs, and embeds them directly into internal bufferViews.
  /// This ensures Filament (and Flutter) will natively load and render all textures without
  /// "Missing texture provider for image/TGA" or "Unable to open ..." filesystem errors.
  ///
  /// Images whose longest edge exceeds [maxTextureSize] are downscaled in place,
  /// preserving aspect ratio. Pass `0` to keep source resolution.
  static const convertGlbTgaToPng = _convertGlbTgaToPng;
}

class _JointWeightPair {
  final int joint;
  final double weight;
  const _JointWeightPair(this.joint, this.weight);
}


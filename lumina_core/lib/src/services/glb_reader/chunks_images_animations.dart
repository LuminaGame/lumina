part of '../glb_reader.dart';

_NodeTransform _combineTransforms(
  _NodeTransform parent,
  _NodeTransform local,
) {
  // 1. Combine Scale
  final sx = parent.scale[0] * local.scale[0];
  final sy = parent.scale[1] * local.scale[1];
  final sz = parent.scale[2] * local.scale[2];

  // 2. Transform local translation by parent rotation & parent scale
  final scaledLx = local.translation[0] * parent.scale[0];
  final scaledLy = local.translation[1] * parent.scale[1];
  final scaledLz = local.translation[2] * parent.scale[2];

  final pr = parent.rotation;
  final rotLx = _rotateByQuaternion([scaledLx, scaledLy, scaledLz], pr);

  final tx = parent.translation[0] + rotLx[0];
  final ty = parent.translation[1] + rotLx[1];
  final tz = parent.translation[2] + rotLx[2];

  // 3. Combine Rotations (Quaternion multiplication: parent * local)
  final px = pr[0], py = pr[1], pz = pr[2], pw = pr[3];
  final lx = local.rotation[0],
      ly = local.rotation[1],
      lz = local.rotation[2],
      lw = local.rotation[3];

  final rx = pw * lx + px * lw + py * lz - pz * ly;
  final ry = pw * ly - px * lz + py * lw + pz * lx;
  final rz = pw * lz + px * ly - py * lx + pz * lw;
  final rw = pw * lw - px * lx - py * ly - pz * lz;

  return _NodeTransform([tx, ty, tz], [rx, ry, rz, rw], [sx, sy, sz]);
}

List<double> _rotateByQuaternion(List<double> p, List<double> q) {
  final x = p[0], y = p[1], z = p[2];
  final qx = q[0], qy = q[1], qz = q[2], qw = q[3];

  final ix = qy * z - qz * y + qw * x;
  final iy = qz * x - qx * z + qw * y;
  final iz = qx * y - qy * x + qw * z;
  final iw = -qx * x - qy * y - qz * z;

  final rx = ix * qw + iw * -qx + iy * -qz - iz * -qy;
  final ry = iy * qw + iw * -qy + iz * -qx - ix * -qz;
  final rz = iz * qw + iw * -qz + ix * -qy - iy * -qx;

  return [rx, ry, rz];
}

List<double> _transformPoint(List<double> p, _NodeTransform xform) {
  final sx = p[0] * xform.scale[0];
  final sy = p[1] * xform.scale[1];
  final sz = p[2] * xform.scale[2];

  final rot = _rotateByQuaternion([sx, sy, sz], xform.rotation);

  return [
    rot[0] + xform.translation[0],
    rot[1] + xform.translation[1],
    rot[2] + xform.translation[2],
  ];
}

/// The image a glTF [material]'s base colour texture samples (its
/// `source`, else the first extension's, such as `EXT_texture_webp`), or
/// null when it has none.
int? _baseColorImageIndex(Object? material, List? textures) {
  if (material is! Map) return null;
  final pbr = material['pbrMetallicRoughness'] as Map?;
  if (pbr == null) return null;
  final texInfo = pbr['baseColorTexture'] as Map?;
  if (texInfo == null) return null;
  final texIdx = texInfo['index'] as int?;
  if (texIdx == null ||
      textures == null ||
      texIdx < 0 ||
      texIdx >= textures.length) {
    return null;
  }
  final tex = textures[texIdx] as Map?;
  if (tex == null) return null;
  int? imgIdx = tex['source'] as int?;
  if (imgIdx == null && tex['extensions'] != null) {
    final ext = tex['extensions'] as Map?;
    if (ext != null) {
      for (final extVal in ext.values) {
        if (extVal is Map && extVal['source'] is int) {
          imgIdx = extVal['source'] as int;
          break;
        }
      }
    }
  }
  return imgIdx;
}

/// The GLB header, JSON chunk and BIN chunk start of [bytes] (after
/// [GlbDecoders.prepare], which the editor uses to convert TGA textures to PNG
/// and sanitize skinning), or null when they are not valid.
Future<({Uint8List bytes, Map<String, dynamic> json, int binStart})?> _readGlbChunks(
  Uint8List bytes,
  GlbDecoders decoders,
) async {
  final initialByteData = ByteData.sublistView(bytes);
  final magic = initialByteData.getUint32(0, Endian.little);
  if (magic != 0x46546C67) {
    return null;
  }

  final prepare = decoders.prepare;
  if (prepare != null) bytes = await prepare(bytes);

  final byteData = ByteData.sublistView(bytes);

  final jsonLength = byteData.getUint32(12, Endian.little);
  final jsonType = byteData.getUint32(16, Endian.little);
  if (jsonType != 0x4E4F534A) {
    GlbReader._logger.log(
      'GLB parse failed: Invalid JSON chunk type 0x${jsonType.toRadixString(16)} (expected 0x4e4f534a "JSON").',
      level: 'error',
      source: 'GlbParserService',
    );
    return null;
  }

  if (bytes.length < 20 + jsonLength) {
    GlbReader._logger.log(
      'GLB parse failed: File truncated before JSON chunk end (specified JSON length $jsonLength bytes).',
      level: 'error',
      source: 'GlbParserService',
    );
    return null;
  }
  final jsonBytes = bytes.sublist(20, 20 + jsonLength);
  // The spec pads the JSON chunk with spaces; some exporters use NULs.
  var jsonEnd = jsonBytes.length;
  while (jsonEnd > 0 &&
      (jsonBytes[jsonEnd - 1] == 0x00 || jsonBytes[jsonEnd - 1] == 0x20)) {
    jsonEnd--;
  }
  final jsonStr = utf8.decode(jsonBytes.sublist(0, jsonEnd));
  Map<String, dynamic> json;
  try {
    json = jsonDecode(jsonStr) as Map<String, dynamic>;
  } catch (e) {
    GlbReader._logger.log(
      'GLB parse failed: JSON chunk parsing exception: $e',
      level: 'error',
      source: 'GlbParserService',
    );
    return null;
  }

  final binChunkOffset = 20 + jsonLength;
  if (bytes.length < binChunkOffset + 8) {
    GlbReader._logger.log(
      'GLB parse failed: Missing binary payload chunk (BIN header missing).',
      level: 'error',
      source: 'GlbParserService',
    );
    return null;
  }

  final binStart = binChunkOffset + 8;
  return (bytes: bytes, json: json, binStart: binStart);
}

/// Decodes the base colour images [GlbReader.parse] samples into vertex colours.
Future<void> _decodeBaseColorImages(
  Map<String, dynamic> json,
  Uint8List bytes,
  int binStart,
  Map<int, _GlbDecodedImage> decodedImages,
  GlbDecoders decoders,
) async {
  final decode = decoders.image;
  if (decode == null) return;
  try {
    final images = json['images'] as List?;
    final bufferViews = json['bufferViews'] as List?;

    if (images != null && bufferViews != null) {
      // Only base colour images are sampled into vertex colours
      // (getMaterialImage below); normal, roughness and other maps are
      // never read, so they are not decoded either.
      final sampledImages = {
        for (final m in (json['materials'] as List?) ?? const [])
          _baseColorImageIndex(m, json['textures'] as List?),
      };
      for (int imgIdx = 0; imgIdx < images.length; imgIdx++) {
        if (!sampledImages.contains(imgIdx)) continue;
        final img = images[imgIdx] as Map?;
        if (img != null && img['bufferView'] != null) {
          final bvIdx = img['bufferView'] as int;
          if (bvIdx < bufferViews.length) {
            final bv = bufferViews[bvIdx] as Map;
            final bvOffset = (bv['byteOffset'] as int?) ?? 0;
            final bvLen = bv['byteLength'] as int;
            final totalImgOffset = binStart + bvOffset;
            if (totalImgOffset + bvLen <= bytes.length) {
              final imgBytes = bytes.sublist(
                totalImgOffset,
                totalImgOffset + bvLen,
              );
              // The decoder follows the bytes' real format, on any isolate:
              // never a fallback to the TGA reader, which reads a PNG's IHDR
              // tag as an 18505x21060 header.
              try {
                final decoded = await decode(imgBytes);
                if (decoded != null) {
                  decodedImages[imgIdx] = _GlbDecodedImage(
                    decoded.width,
                    decoded.height,
                    decoded.rgba,
                  );
                } else {
                  GlbReader._logger.log(
                    'GLB image $imgIdx (${EncodedImageFormat.sniff(imgBytes).name}) is not decoded to pixels; '
                    'its material keeps its base colour factor in vertex colours.',
                    level: 'info',
                    source: 'GlbParserService',
                  );
                }
              } catch (e) {
                GlbReader._logger.log(
                  'GLB image $imgIdx decode notice: $e',
                  level: 'warning',
                  source: 'GlbParserService',
                );
              }
            }
          }
        }
      }
    }
  } catch (e) {
    GlbReader._logger.log(
      'GLB texture/material parse notice: $e',
      level: 'warning',
      source: 'GlbParserService',
    );
  }
}

/// The animation clips of a GLB's JSON chunk, their keyframes read from
/// the BIN chunk at [binStart].
List<GlbAnimationClip> _parseAnimations(Map<String, dynamic> json, Uint8List bytes, int binStart) {
  final List<GlbAnimationClip> parsedAnimations = [];
  final animationsJson = json['animations'] as List?;
  if (animationsJson != null) {
    for (int aIdx = 0; aIdx < animationsJson.length; aIdx++) {
      final animMap = animationsJson[aIdx];
      if (animMap is! Map) continue;
      final animName = (animMap['name'] as String?)?.isNotEmpty == true
          ? animMap['name'] as String
          : 'anim_$aIdx';
      final samplers = animMap['samplers'] as List? ?? [];
      final channels = animMap['channels'] as List? ?? [];

      final accessorsList = json['accessors'] as List?;
      final bufferViewsList = json['bufferViews'] as List?;
      final binBytes = bytes.sublist(binStart);

      List<double> extractAccessorFloats(int? accIdx) {
        if (accIdx == null ||
            accessorsList == null ||
            accIdx < 0 ||
            accIdx >= accessorsList.length) {
          return const [];
        }
        final acc = accessorsList[accIdx];
        if (acc is! Map) return const [];
        final count = acc['count'] as int? ?? 0;
        final type = acc['type'] as String? ?? 'SCALAR';
        final numComp = switch (type) {
          'VEC2' => 2,
          'VEC3' => 3,
          'VEC4' || 'MAT2' => 4,
          'MAT3' => 9,
          'MAT4' => 16,
          _ => 1,
        };
        final totalFloats = count * numComp;
        final bvIdx = acc['bufferView'] as int?;
        if (bufferViewsList == null ||
            bvIdx == null ||
            bvIdx < 0 ||
            bvIdx >= bufferViewsList.length) {
          return const [];
        }
        final bv = bufferViewsList[bvIdx] as Map;
        final byteOffset =
            (bv['byteOffset'] as int? ?? 0) +
            (acc['byteOffset'] as int? ?? 0);
        if (byteOffset + totalFloats * 4 > binBytes.length) return const [];
        final bd = ByteData.sublistView(
          binBytes,
          byteOffset,
          byteOffset + totalFloats * 4,
        );
        final res = <double>[];
        for (int i = 0; i < totalFloats; i++) {
          res.add(bd.getFloat32(i * 4, Endian.little));
        }
        return res;
      }

      double maxTime = 0.0;
      if (accessorsList != null) {
        for (final sampler in samplers) {
          if (sampler is Map) {
            final inputAccIdx = sampler['input'] as int?;
            if (inputAccIdx != null &&
                inputAccIdx >= 0 &&
                inputAccIdx < accessorsList.length) {
              final acc = accessorsList[inputAccIdx];
              if (acc is Map) {
                final maxList = acc['max'] as List?;
                if (maxList != null &&
                    maxList.isNotEmpty &&
                    maxList[0] is num) {
                  final t = (maxList[0] as num).toDouble();
                  if (t > maxTime) maxTime = t;
                }
              }
            }
          }
        }
      }

      final nodesList = json['nodes'] as List?;
      final Set<int> animNodes = {};
      final List<String> paths = [];
      final List<GlbAnimationChannel> parsedChannels = [];
      final Set<double> compositeTimesSet = {};

      for (final channel in channels) {
        if (channel is Map) {
          final target = channel['target'] as Map?;
          final samplerIdx = channel['sampler'] as int?;
          if (target != null) {
            final targetNode = target['node'] as int?;
            final targetPath = target['path'] as String? ?? 'translation';
            if (targetNode != null) {
              animNodes.add(targetNode);
            }
            paths.add(targetPath);

            final nodeName =
                (nodesList != null &&
                    targetNode != null &&
                    targetNode >= 0 &&
                    targetNode < nodesList.length &&
                    nodesList[targetNode] is Map)
                ? (nodesList[targetNode]['name'] as String? ??
                      'Node_$targetNode')
                : 'Node_$targetNode';

            List<double> channelTimes = const [];
            List<double> channelValues = const [];
            String interpolation = 'LINEAR';
            if (samplerIdx != null &&
                samplerIdx >= 0 &&
                samplerIdx < samplers.length) {
              final sMap = samplers[samplerIdx];
              if (sMap is Map) {
                final inputAcc = sMap['input'] as int?;
                final outputAcc = sMap['output'] as int?;
                channelTimes = extractAccessorFloats(inputAcc);
                channelValues = extractAccessorFloats(outputAcc);
                interpolation =
                    (sMap['interpolation'] as String?) ?? 'LINEAR';
              }
            }

            for (final t in channelTimes) {
              compositeTimesSet.add(t);
              if (t > maxTime) maxTime = t;
            }

            if (targetNode != null) {
              parsedChannels.add(
                GlbAnimationChannel(
                  nodeIndex: targetNode,
                  nodeName: nodeName,
                  path: targetPath,
                  keyframeTimes: channelTimes,
                  values: channelValues,
                  interpolation: interpolation,
                ),
              );
            }
          }
        }
      }

      final compositeTimes = compositeTimesSet.toList()..sort();

      parsedAnimations.add(
        GlbAnimationClip(
          name: animName,
          duration: maxTime,
          animatedNodeIndices: animNodes,
          channelTargetPaths: paths,
          channels: parsedChannels,
          compositeKeyframeTimes: compositeTimes,
        ),
      );
    }
  }
  return parsedAnimations;
}

part of '../glb_parser_service.dart';

Future<GlbMeshData?> _parseGlb(Uint8List bytes) async {
  if (bytes.length < 20) {
    GlbParserService._logger.log(
      'GLB parse failed: Input buffer too small (${bytes.length} bytes). Minimum 20 bytes required for header.',
      level: 'error',
      source: 'GlbParserService',
    );
    return null;
  }

  if (bytes[0] == 0x7B) {
    // '{' JSON text (.lmas container)
    try {
      final text = utf8.decode(bytes);
      final map = jsonDecode(text);
      if (map is Map) {
        final raw = map['raw_payload'] ?? map['rawPayload'];
        Uint8List? payload;
        if (raw is String) {
          payload = base64Decode(raw);
        } else if (raw is List) {
          payload = Uint8List.fromList(raw.cast<int>());
        }
        if (payload != null && payload.isNotEmpty) {
          return await GlbParserService.parseGlb(payload);
        }
      }
    } catch (e) {
      GlbParserService._logger.log(
        'LMAS container JSON parse notice: $e',
        level: 'warning',
        source: 'GlbParserService',
      );
    }
  }

  final glb = await _readGlbChunks(bytes);
  if (glb == null) return null;
  bytes = glb.bytes;
  final json = glb.json;
  final binStart = glb.binStart;
  final byteData = ByteData.sublistView(bytes);

  final List<double> positions = [];
  final List<int> indices = [];
  final List<double> uvs = [];
  final List<int> vertexColorList = [];
  final List<GlbSubPrimitive> subPrimitives = [];
  List<double> minBounds = [
    double.infinity,
    double.infinity,
    double.infinity,
  ];
  List<double> maxBounds = [
    -double.infinity,
    -double.infinity,
    -double.infinity,
  ];
  List<double> baseColor = [0.75, 0.58, 0.46];
  Uint8List? vertexColors;
  final List<GlbNode> parsedAllNodes = [];
  final List<GlbNode> parsedRootNodes = [];
  final List<String> parsedMaterialNames = [];
  final Set<int> skinJointIndices = {};
  final List<int> parsedJointsList = [];
  final List<double> parsedWeightsList = [];
  final List<List<double>> parsedMorphDeltaLists = [];
  final List<String> parsedMorphTargetNames = [];

  final Map<int, _GlbDecodedImage> decodedImages = {};

  await _decodeBaseColorImages(json, bytes, binStart, decodedImages);

  try {
    final meshes = json['meshes'] as List?;
    final accessors = json['accessors'] as List?;
    final bufferViews = json['bufferViews'] as List?;
    final nodes = json['nodes'] as List?;
    final scenes = json['scenes'] as List?;
    final materials = json['materials'] as List?;
    final textures = json['textures'] as List?;
    final activeSceneIdx = (json['scene'] as int?) ?? 0;

    _GlbDecodedImage? getMaterialImage(int? matIdx) {
      if (matIdx == null ||
          materials == null ||
          matIdx < 0 ||
          matIdx >= materials.length) {
        return null;
      }
      final imgIdx = _baseColorImageIndex(materials[matIdx], textures);
      if (imgIdx == null) return null;
      return decodedImages[imgIdx];
    }

    parsedMaterialNames.clear();
    if (materials != null) {
      for (int mi = 0; mi < materials.length; mi++) {
        final m = materials[mi] as Map?;
        final mName = (m?['name'] as String?) ?? 'Material_$mi';
        parsedMaterialNames.add(mName);
      }
    }

    List<double> getMaterialBaseColor(int? matIdx) {
      if (matIdx == null ||
          materials == null ||
          matIdx < 0 ||
          matIdx >= materials.length) {
        return const [0.82, 0.84, 0.88];
      }
      final mat = materials[matIdx] as Map?;
      if (mat == null) return const [0.82, 0.84, 0.88];
      final pbr = mat['pbrMetallicRoughness'] as Map?;
      if (pbr != null && pbr['baseColorFactor'] != null) {
        final factor = List<double>.from(
          (pbr['baseColorFactor'] as List).map((e) => (e as num).toDouble()),
        );
        if (factor.length >= 3) {
          final r = factor[0], g = factor[1], b = factor[2];
          // If explicit distinct color
          if ((r - g).abs() > 0.05 || (g - b).abs() > 0.05) {
            return [r.clamp(0.1, 1.0), g.clamp(0.1, 1.0), b.clamp(0.1, 1.0)];
          }
        }
      }
      // Palette for multiple material slots (e.g. Manny armor vs joints)
      if (matIdx == 0) return const [0.84, 0.85, 0.88]; // Main polymer/armor
      if (matIdx == 1) {
        return const [0.28, 0.30, 0.38]; // Dark mechanics/joints
      }
      if (matIdx == 2) return const [0.92, 0.62, 0.18]; // Accent amber
      if (matIdx == 3) return const [0.22, 0.58, 0.88]; // Accent cyan
      return const [0.75, 0.78, 0.85];
    }

    // Extract skins / skeleton joint indices
    skinJointIndices.clear();
    final skins = json['skins'] as List?;
    if (skins != null) {
      for (final s in skins) {
        if (s is Map) {
          final joints = s['joints'] as List?;
          if (joints != null) {
            for (final j in joints) {
              if (j is int) {
                skinJointIndices.add(j);
              } else if (j is num) {
                skinJointIndices.add(j.toInt());
              }
            }
          }
        }
      }
    }

    // Build GlbNode Scene Graph Hierarchy
    parsedAllNodes.clear();
    parsedRootNodes.clear();

    if (nodes != null && nodes.isNotEmpty) {
      for (int i = 0; i < nodes.length; i++) {
        final n = nodes[i] as Map;
        final name = (n['name'] as String?) ?? 'Node_$i';
        final meshIdx = n['mesh'] as int?;
        final t = (n['translation'] as List?)
            ?.map((e) => (e as num).toDouble())
            .toList();
        final r = (n['rotation'] as List?)
            ?.map((e) => (e as num).toDouble())
            .toList();
        final s = (n['scale'] as List?)
            ?.map((e) => (e as num).toDouble())
            .toList();

        String? meshName;
        int primCount = 0;
        if (meshIdx != null &&
            meshes != null &&
            meshIdx >= 0 &&
            meshIdx < meshes.length) {
          final m = meshes[meshIdx] as Map;
          meshName = m['name'] as String?;
          primCount = (m['primitives'] as List?)?.length ?? 1;
        }

        GlbNodeType type = GlbNodeType.group;
        final lowerName = name.toLowerCase();
        if (skinJointIndices.contains(i)) {
          type = GlbNodeType.bone;
        } else if (meshIdx != null) {
          type = GlbNodeType.mesh;
        } else if (lowerName.contains('light')) {
          type = GlbNodeType.light;
        } else if (skinJointIndices.isEmpty &&
            (lowerName.contains('bone') ||
                lowerName.contains('joint') ||
                lowerName.contains('skin') ||
                lowerName.contains('rotor'))) {
          type = GlbNodeType.bone;
        } else if (lowerName.contains('cam') ||
            lowerName.contains('camera')) {
          type = GlbNodeType.camera;
        }

        parsedAllNodes.add(
          GlbNode(
            index: i,
            name: name,
            meshIndex: meshIdx,
            meshName: meshName,
            primitiveCount: primCount,
            translation: t,
            rotation: r,
            scale: s,
            type: type,
            children: [],
          ),
        );
      }

      final Set<int> childIndices = {};
      for (int i = 0; i < nodes.length; i++) {
        final n = nodes[i] as Map;
        final childList = (n['children'] as List?)?.cast<int>() ?? [];
        for (final cIdx in childList) {
          if (cIdx >= 0 && cIdx < parsedAllNodes.length) {
            childIndices.add(cIdx);
            parsedAllNodes[i].children.add(parsedAllNodes[cIdx]);
          }
        }
      }

      if (scenes != null && activeSceneIdx < scenes.length) {
        final activeScene = scenes[activeSceneIdx] as Map;
        final sceneRoots = (activeScene['nodes'] as List?)?.cast<int>() ?? [];
        for (final rIdx in sceneRoots) {
          if (rIdx >= 0 && rIdx < parsedAllNodes.length) {
            parsedRootNodes.add(parsedAllNodes[rIdx]);
          }
        }
      }

      if (parsedRootNodes.isEmpty) {
        for (int i = 0; i < parsedAllNodes.length; i++) {
          if (!childIndices.contains(i)) {
            parsedRootNodes.add(parsedAllNodes[i]);
          }
        }
      }
    }

    // Build Node Transform Hierarchy Map: nodeIndex -> World Node Transform
    final Map<int, _NodeTransform> nodeWorldTransforms = {};

    if (nodes != null && scenes != null && activeSceneIdx < scenes.length) {
      final activeScene = scenes[activeSceneIdx] as Map;
      final rootNodes = (activeScene['nodes'] as List?)?.cast<int>() ?? [];

      void traverseNode(int nodeIdx, _NodeTransform parentXform) {
        if (nodeIdx < 0 || nodeIdx >= nodes.length) return;
        final node = nodes[nodeIdx] as Map;

        final t =
            (node['translation'] as List?)
                ?.map((e) => (e as num).toDouble())
                .toList() ??
            [0.0, 0.0, 0.0];
        final r =
            (node['rotation'] as List?)
                ?.map((e) => (e as num).toDouble())
                .toList() ??
            [0.0, 0.0, 0.0, 1.0];
        final s =
            (node['scale'] as List?)
                ?.map((e) => (e as num).toDouble())
                .toList() ??
            [1.0, 1.0, 1.0];

        final localXform = _NodeTransform(t, r, s);
        final worldXform = _combineTransforms(parentXform, localXform);
        nodeWorldTransforms[nodeIdx] = worldXform;

        final children = (node['children'] as List?)?.cast<int>() ?? [];
        for (final childIdx in children) {
          traverseNode(childIdx, worldXform);
        }
      }

      final identity = _NodeTransform([0.0, 0.0, 0.0], [0.0, 0.0, 0.0, 1.0], [
        1.0,
        1.0,
        1.0,
      ]);
      for (final rootIdx in rootNodes) {
        traverseNode(rootIdx, identity);
      }
    }

    if (meshes != null &&
        meshes.isNotEmpty &&
        accessors != null &&
        bufferViews != null) {
      for (final node in parsedAllNodes) {
        if (node.meshIndex == null ||
            node.meshIndex! < 0 ||
            node.meshIndex! >= meshes.length) {
          continue;
        }
        final mIdx = node.meshIndex!;
        final mesh = meshes[mIdx] as Map;
        final primitives = mesh['primitives'] as List?;
        if (primitives == null) continue;

        final xform =
            nodeWorldTransforms[node.index] ??
            _NodeTransform([0.0, 0.0, 0.0], [0.0, 0.0, 0.0, 1.0], [
              1.0,
              1.0,
              1.0,
            ]);

        for (final prim in primitives) {
          final mode = (prim['mode'] as int?) ?? 4; // 4 = TRIANGLES
          if (mode != 4) continue;

          final matIdx = prim['material'] as int?;
          final matImg = getMaterialImage(matIdx);
          final matColor = getMaterialBaseColor(matIdx);

          final attributes = prim['attributes'] as Map?;
          if (attributes == null) continue;
          final posAccessorIdx = attributes['POSITION'] as int?;
          if (posAccessorIdx == null || posAccessorIdx >= accessors.length) {
            continue;
          }

          final posAccessor = accessors[posAccessorIdx] as Map;
          final posBufViewIdx = posAccessor['bufferView'] as int?;

          if (posBufViewIdx == null || posBufViewIdx >= bufferViews.length) {
            // Decode Draco compressed geometry via Filament C++ native decoder!
            final dracoExt =
                (prim['extensions'] as Map?)?['KHR_draco_mesh_compression']
                    as Map?;
            if (dracoExt != null && dracoExt['bufferView'] != null) {
              final dracoBvIdx = dracoExt['bufferView'] as int;
              if (dracoBvIdx < bufferViews.length) {
                final dracoBv = bufferViews[dracoBvIdx] as Map;
                final dracoBvOffset = (dracoBv['byteOffset'] as int?) ?? 0;
                final dracoBvLen = dracoBv['byteLength'] as int;
                final dracoTotalOffset = binStart + dracoBvOffset;
                if (dracoTotalOffset + dracoBvLen <= bytes.length) {
                  final dracoBytes = bytes.sublist(
                    dracoTotalOffset,
                    dracoTotalOffset + dracoBvLen,
                  );
                  final decoded = FilamentDracoDecoder.decode(dracoBytes);
                  if (decoded != null && decoded.positions.isNotEmpty) {
                    final globalBaseIdx = positions.length ~/ 3;
                    final nodeBaseIdx = node.positions.length ~/ 3;
                    final dVertCount = decoded.positions.length ~/ 3;
                    final subPos = <double>[];
                    final subColorList = <int>[];
                    final subIndices = List<int>.from(decoded.indices);

                    for (int i = 0; i < dVertCount; i++) {
                      final pt = [
                        decoded.positions[i * 3],
                        decoded.positions[i * 3 + 1],
                        decoded.positions[i * 3 + 2],
                      ];
                      final wpt = _transformPoint(pt, xform);
                      positions.addAll(wpt);
                      subPos.addAll(wpt);
                      node.positions.addAll(wpt);

                      final u = decoded.uvs.length >= (i + 1) * 2
                          ? decoded.uvs[i * 2]
                          : 0.0;
                      final v = decoded.uvs.length >= (i + 1) * 2
                          ? decoded.uvs[i * 2 + 1]
                          : 0.0;
                      uvs.addAll([u, v]);

                      if (matImg != null) {
                        final sampled = matImg.sample(u, v);
                        final r = (sampled[0] * matColor[0])
                            .clamp(0, 255)
                            .toInt();
                        final g = (sampled[1] * matColor[1])
                            .clamp(0, 255)
                            .toInt();
                        final b = (sampled[2] * matColor[2])
                            .clamp(0, 255)
                            .toInt();
                        vertexColorList.addAll([r, g, b]);
                        subColorList.addAll([r, g, b]);
                      } else {
                        final r = (matColor[0] * 210).clamp(0, 255).toInt();
                        final g = (matColor[1] * 190).clamp(0, 255).toInt();
                        final b = (matColor[2] * 180).clamp(0, 255).toInt();
                        vertexColorList.addAll([r, g, b]);
                        subColorList.addAll([r, g, b]);
                      }

                      if (wpt[0] < minBounds[0]) minBounds[0] = wpt[0];
                      if (wpt[1] < minBounds[1]) minBounds[1] = wpt[1];
                      if (wpt[2] < minBounds[2]) minBounds[2] = wpt[2];
                      if (wpt[0] > maxBounds[0]) maxBounds[0] = wpt[0];
                      if (wpt[1] > maxBounds[1]) maxBounds[1] = wpt[1];
                      if (wpt[2] > maxBounds[2]) maxBounds[2] = wpt[2];
                    }
                    for (final idx in decoded.indices) {
                      indices.add(globalBaseIdx + idx);
                      node.indices.add(nodeBaseIdx + idx);
                    }

                    subPrimitives.add(
                      GlbSubPrimitive(
                        positions: subPos,
                        indices: subIndices,
                        vertexColors: Uint8List.fromList(subColorList),
                        baseColor: matColor,
                      ),
                    );

                    continue;
                  }
                }
              }
            }

            // Fallback bounding box if Draco decoding returns null
            if (posAccessor['min'] != null && posAccessor['max'] != null) {
              final mins = List<double>.from(
                (posAccessor['min'] as List).map(
                  (e) => (e as num).toDouble(),
                ),
              );
              final maxs = List<double>.from(
                (posAccessor['max'] as List).map(
                  (e) => (e as num).toDouble(),
                ),
              );
              if (mins.length >= 3 && maxs.length >= 3) {
                final pMinX = mins[0], pMinY = mins[1], pMinZ = mins[2];
                final pMaxX = maxs[0], pMaxY = maxs[1], pMaxZ = maxs[2];

                final raw8Pts = [
                  [pMinX, pMinY, pMinZ],
                  [pMaxX, pMinY, pMinZ],
                  [pMaxX, pMaxY, pMinZ],
                  [pMinX, pMaxY, pMinZ],
                  [pMinX, pMinY, pMaxZ],
                  [pMaxX, pMinY, pMaxZ],
                  [pMaxX, pMaxY, pMaxZ],
                  [pMinX, pMaxY, pMaxZ],
                ];

                final globalBaseIdx = positions.length ~/ 3;
                final nodeBaseIdx = node.positions.length ~/ 3;
                for (final pt in raw8Pts) {
                  final wpt = _transformPoint(pt, xform);
                  positions.addAll(wpt);
                  node.positions.addAll(wpt);

                  vertexColorList.addAll([180, 140, 110]);

                  if (wpt[0] < minBounds[0]) minBounds[0] = wpt[0];
                  if (wpt[1] < minBounds[1]) minBounds[1] = wpt[1];
                  if (wpt[2] < minBounds[2]) minBounds[2] = wpt[2];
                  if (wpt[0] > maxBounds[0]) maxBounds[0] = wpt[0];
                  if (wpt[1] > maxBounds[1]) maxBounds[1] = wpt[1];
                  if (wpt[2] > maxBounds[2]) maxBounds[2] = wpt[2];
                }

                final cubeInds = [
                  0,
                  1,
                  2,
                  0,
                  2,
                  3,
                  4,
                  6,
                  5,
                  4,
                  7,
                  6,
                  0,
                  5,
                  1,
                  0,
                  4,
                  5,
                  3,
                  2,
                  6,
                  3,
                  6,
                  7,
                  0,
                  3,
                  7,
                  0,
                  7,
                  4,
                  1,
                  5,
                  6,
                  1,
                  6,
                  2,
                ];
                for (final ci in cubeInds) {
                  indices.add(globalBaseIdx + ci);
                  node.indices.add(nodeBaseIdx + ci);
                }
              }
            }
            continue;
          }

          // Direct Uncompressed bufferView available
          final posCount = posAccessor['count'] as int;
          final posByteOffsetInAccessor =
              (posAccessor['byteOffset'] as int?) ?? 0;

          final posBufView = bufferViews[posBufViewIdx] as Map;
          final posBufViewByteOffset =
              (posBufView['byteOffset'] as int?) ?? 0;
          final posByteStride = (posBufView['byteStride'] as int?) ?? 12;
          final totalPosOffset =
              binStart + posBufViewByteOffset + posByteOffsetInAccessor;

          final uvAccessorIdx = attributes['TEXCOORD_0'] as int?;
          int? uvTotalOffset;
          int uvByteStride = 8;
          int uvCount = 0;
          if (uvAccessorIdx != null && uvAccessorIdx < accessors.length) {
            final uvAcc = accessors[uvAccessorIdx] as Map;
            final uvBvIdx = uvAcc['bufferView'] as int?;
            if (uvBvIdx != null && uvBvIdx < bufferViews.length) {
              uvCount = uvAcc['count'] as int;
              final uvBv = bufferViews[uvBvIdx] as Map;
              final uvBvOffset = (uvBv['byteOffset'] as int?) ?? 0;
              final uvAccOffset = (uvAcc['byteOffset'] as int?) ?? 0;
              uvByteStride = (uvBv['byteStride'] as int?) ?? 8;
              uvTotalOffset = binStart + uvBvOffset + uvAccOffset;
            }
          }

          final jointsAccessorIdx = attributes['JOINTS_0'] as int?;
          int? jointsTotalOffset;
          int jointsComponentType = 5121;
          int jointsByteStride = 4;
          int jointsCount = 0;
          if (jointsAccessorIdx != null &&
              jointsAccessorIdx < accessors.length) {
            final jAcc = accessors[jointsAccessorIdx] as Map;
            final jBvIdx = jAcc['bufferView'] as int?;
            jointsComponentType = (jAcc['componentType'] as int?) ?? 5121;
            final compBytes = jointsComponentType == 5123 ? 2 : 1;
            if (jBvIdx != null && jBvIdx < bufferViews.length) {
              jointsCount = (jAcc['count'] as int?) ?? 0;
              final jBv = bufferViews[jBvIdx] as Map;
              final jBvOffset = (jBv['byteOffset'] as int?) ?? 0;
              final jAccOffset = (jAcc['byteOffset'] as int?) ?? 0;
              jointsByteStride =
                  (jBv['byteStride'] as int?) ?? (compBytes * 4);
              jointsTotalOffset = binStart + jBvOffset + jAccOffset;
            }
          }

          final weightsAccessorIdx = attributes['WEIGHTS_0'] as int?;
          int? weightsTotalOffset;
          int weightsComponentType = 5126;
          int weightsByteStride = 16;
          int weightsCount = 0;
          if (weightsAccessorIdx != null &&
              weightsAccessorIdx < accessors.length) {
            final wAcc = accessors[weightsAccessorIdx] as Map;
            final wBvIdx = wAcc['bufferView'] as int?;
            weightsComponentType = (wAcc['componentType'] as int?) ?? 5126;
            final compBytes = weightsComponentType == 5126
                ? 4
                : (weightsComponentType == 5123 ? 2 : 1);
            if (wBvIdx != null && wBvIdx < bufferViews.length) {
              weightsCount = (wAcc['count'] as int?) ?? 0;
              final wBv = bufferViews[wBvIdx] as Map;
              final wBvOffset = (wBv['byteOffset'] as int?) ?? 0;
              final wAccOffset = (wAcc['byteOffset'] as int?) ?? 0;
              weightsByteStride =
                  (wBv['byteStride'] as int?) ?? (compBytes * 4);
              weightsTotalOffset = binStart + wBvOffset + wAccOffset;
            }
          }

          List<int> getVertexJoints(int vertIndex) {
            if (jointsTotalOffset == null ||
                vertIndex < 0 ||
                vertIndex >= jointsCount) {
              return const [0, 0, 0, 0];
            }
            final idx = jointsTotalOffset + (vertIndex * jointsByteStride);
            if (idx + (jointsComponentType == 5123 ? 8 : 4) <= bytes.length) {
              if (jointsComponentType == 5123) {
                return [
                  byteData.getUint16(idx, Endian.little),
                  byteData.getUint16(idx + 2, Endian.little),
                  byteData.getUint16(idx + 4, Endian.little),
                  byteData.getUint16(idx + 6, Endian.little),
                ];
              }
              return [
                byteData.getUint8(idx),
                byteData.getUint8(idx + 1),
                byteData.getUint8(idx + 2),
                byteData.getUint8(idx + 3),
              ];
            }
            return const [0, 0, 0, 0];
          }

          List<double> getVertexWeights(int vertIndex) {
            if (weightsTotalOffset == null ||
                vertIndex < 0 ||
                vertIndex >= weightsCount) {
              return const [1.0, 0.0, 0.0, 0.0];
            }
            final idx = weightsTotalOffset + (vertIndex * weightsByteStride);
            if (weightsComponentType == 5126 && idx + 16 <= bytes.length) {
              return [
                byteData.getFloat32(idx, Endian.little),
                byteData.getFloat32(idx + 4, Endian.little),
                byteData.getFloat32(idx + 8, Endian.little),
                byteData.getFloat32(idx + 12, Endian.little),
              ];
            } else if (weightsComponentType == 5123 &&
                idx + 8 <= bytes.length) {
              return [
                byteData.getUint16(idx, Endian.little) / 65535.0,
                byteData.getUint16(idx + 2, Endian.little) / 65535.0,
                byteData.getUint16(idx + 4, Endian.little) / 65535.0,
                byteData.getUint16(idx + 6, Endian.little) / 65535.0,
              ];
            } else if (weightsComponentType == 5121 &&
                idx + 4 <= bytes.length) {
              return [
                byteData.getUint8(idx) / 255.0,
                byteData.getUint8(idx + 1) / 255.0,
                byteData.getUint8(idx + 2) / 255.0,
                byteData.getUint8(idx + 3) / 255.0,
              ];
            }
            return const [1.0, 0.0, 0.0, 0.0];
          }

          // Morph Targets
          final targetsList = (prim['targets'] as List?) ?? [];
          final meshExtras = mesh['extras'] as Map?;
          final jsonExtras = json['extras'] as Map?;
          final targetNamesList =
              (meshExtras?['targetNames'] as List?) ??
              (jsonExtras?['targetNames'] as List?) ??
              [];

          final List<(int totalOffset, int byteStride, int count)>
          targetInfos = [];
          for (int tIdx = 0; tIdx < targetsList.length; tIdx++) {
            final tMap = targetsList[tIdx] as Map?;
            final tPosAccIdx = tMap?['POSITION'] as int?;
            if (tPosAccIdx != null && tPosAccIdx < accessors.length) {
              final tAcc = accessors[tPosAccIdx] as Map;
              final tBvIdx = tAcc['bufferView'] as int?;
              if (tBvIdx != null && tBvIdx < bufferViews.length) {
                final tCount = (tAcc['count'] as int?) ?? 0;
                final tBv = bufferViews[tBvIdx] as Map;
                final tBvOffset = (tBv['byteOffset'] as int?) ?? 0;
                final tAccOffset = (tAcc['byteOffset'] as int?) ?? 0;
                final tStride = (tBv['byteStride'] as int?) ?? 12;
                targetInfos.add((
                  binStart + tBvOffset + tAccOffset,
                  tStride,
                  tCount,
                ));
              }
            }
          }

          List<double> getMorphDelta(int targetIdx, int vertIndex) {
            if (targetIdx < 0 || targetIdx >= targetInfos.length) {
              return const [0.0, 0.0, 0.0];
            }
            final info = targetInfos[targetIdx];
            if (vertIndex < 0 || vertIndex >= info.$3) {
              return const [0.0, 0.0, 0.0];
            }
            final idx = info.$1 + (vertIndex * info.$2);
            if (idx + 12 <= bytes.length) {
              final dx = byteData.getFloat32(idx, Endian.little);
              final dy = byteData.getFloat32(idx + 4, Endian.little);
              final dz = byteData.getFloat32(idx + 8, Endian.little);
              return [dx, dy, dz];
            }
            return const [0.0, 0.0, 0.0];
          }

          List<double>? getVertexPos(int vertIndex) {
            if (vertIndex < 0 || vertIndex >= posCount) return null;
            final idx = totalPosOffset + (vertIndex * posByteStride);
            if (idx + 12 <= bytes.length) {
              final vx = byteData.getFloat32(idx, Endian.little);
              final vy = byteData.getFloat32(idx + 4, Endian.little);
              final vz = byteData.getFloat32(idx + 8, Endian.little);
              return _transformPoint([vx, vy, vz], xform);
            }
            return null;
          }

          List<double>? getVertexUV(int vertIndex) {
            if (uvTotalOffset == null ||
                vertIndex < 0 ||
                vertIndex >= uvCount) {
              return null;
            }
            final idx = uvTotalOffset + (vertIndex * uvByteStride);
            if (idx + 8 <= bytes.length) {
              final u = byteData.getFloat32(idx, Endian.little);
              final v = byteData.getFloat32(idx + 4, Endian.little);
              return [u, v];
            }
            return null;
          }

          final indicesIdx = prim['indices'] as int?;

          final List<double> subPos = [];
          final List<int> subIndices = [];
          final List<int> subColorList = [];

          void addUncompressedVert(
            List<double> v,
            List<double> uv,
            int vertIndex,
          ) {
            positions.addAll(v);
            node.positions.addAll(v);
            subPos.addAll(v);

            if (v[0] < minBounds[0]) minBounds[0] = v[0];
            if (v[1] < minBounds[1]) minBounds[1] = v[1];
            if (v[2] < minBounds[2]) minBounds[2] = v[2];
            if (v[0] > maxBounds[0]) maxBounds[0] = v[0];
            if (v[1] > maxBounds[1]) maxBounds[1] = v[1];
            if (v[2] > maxBounds[2]) maxBounds[2] = v[2];

            final u = uv[0];
            final vCoord = uv[1];
            if (matImg != null) {
              final sampled = matImg.sample(u, vCoord);
              final r = (sampled[0] * matColor[0]).clamp(0, 255).toInt();
              final g = (sampled[1] * matColor[1]).clamp(0, 255).toInt();
              final b = (sampled[2] * matColor[2]).clamp(0, 255).toInt();
              vertexColorList.addAll([r, g, b]);
              subColorList.addAll([r, g, b]);
            } else {
              final r = (matColor[0] * 230).clamp(0, 255).toInt();
              final g = (matColor[1] * 230).clamp(0, 255).toInt();
              final b = (matColor[2] * 230).clamp(0, 255).toInt();
              vertexColorList.addAll([r, g, b]);
              subColorList.addAll([r, g, b]);
            }

            final joints = getVertexJoints(vertIndex);
            final weights = getVertexWeights(vertIndex);
            parsedJointsList.addAll(joints);
            parsedWeightsList.addAll(weights);

            for (int tIdx = 0; tIdx < targetsList.length; tIdx++) {
              final delta = getMorphDelta(tIdx, vertIndex);
              if (tIdx >= parsedMorphDeltaLists.length) {
                parsedMorphDeltaLists.add([]);
                final targetName = tIdx < targetNamesList.length
                    ? targetNamesList[tIdx].toString()
                    : 'morph_$tIdx';
                parsedMorphTargetNames.add(targetName);
              }
              parsedMorphDeltaLists[tIdx].addAll(delta);
            }
          }

          if (indicesIdx != null && indicesIdx < accessors.length) {
            final indAccessor = accessors[indicesIdx] as Map;
            final indBufViewIdx = indAccessor['bufferView'] as int?;
            if (indBufViewIdx != null && indBufViewIdx < bufferViews.length) {
              final indCount = indAccessor['count'] as int;
              final componentType = indAccessor['componentType'] as int;
              final indByteOffsetInAccessor =
                  (indAccessor['byteOffset'] as int?) ?? 0;

              final indBufView = bufferViews[indBufViewIdx] as Map;
              final indBufViewByteOffset =
                  (indBufView['byteOffset'] as int?) ?? 0;
              final stride = componentType == 5125
                  ? 4
                  : (componentType == 5123 ? 2 : 1);
              final indByteStride =
                  (indBufView['byteStride'] as int?) ?? stride;
              final totalIndOffset =
                  binStart + indBufViewByteOffset + indByteOffsetInAccessor;

              int getIndex(int idxInAccessor) {
                final idx = totalIndOffset + (idxInAccessor * indByteStride);
                if (idx + stride <= bytes.length) {
                  if (stride == 4) {
                    return byteData.getUint32(idx, Endian.little);
                  }
                  if (stride == 2) {
                    return byteData.getUint16(idx, Endian.little);
                  }
                  return byteData.getUint8(idx);
                }
                return 0;
              }

              final totalTriangles = indCount ~/ 3;
              for (int t = 0; t < totalTriangles; t++) {
                final i0 = getIndex(t * 3);
                final i1 = getIndex(t * 3 + 1);
                final i2 = getIndex(t * 3 + 2);

                final v0 = getVertexPos(i0);
                final v1 = getVertexPos(i1);
                final v2 = getVertexPos(i2);

                if (v0 != null && v1 != null && v2 != null) {
                  final globalBaseIdx = positions.length ~/ 3;
                  final nodeBaseIdx = node.positions.length ~/ 3;
                  final subBaseIdx = subPos.length ~/ 3;

                  final uv0 = getVertexUV(i0) ?? [0.0, 0.0];
                  final uv1 = getVertexUV(i1) ?? [0.0, 0.0];
                  final uv2 = getVertexUV(i2) ?? [0.0, 0.0];

                  addUncompressedVert(v0, uv0, i0);
                  addUncompressedVert(v1, uv1, i1);
                  addUncompressedVert(v2, uv2, i2);

                  indices.addAll([
                    globalBaseIdx,
                    globalBaseIdx + 1,
                    globalBaseIdx + 2,
                  ]);
                  node.indices.addAll([
                    nodeBaseIdx,
                    nodeBaseIdx + 1,
                    nodeBaseIdx + 2,
                  ]);
                  subIndices.addAll([
                    subBaseIdx,
                    subBaseIdx + 1,
                    subBaseIdx + 2,
                  ]);
                }
              }
            }
          } else {
            final totalTriangles = posCount ~/ 3;
            for (int t = 0; t < totalTriangles; t++) {
              final i0 = t * 3;
              final i1 = t * 3 + 1;
              final i2 = t * 3 + 2;
              final v0 = getVertexPos(i0);
              final v1 = getVertexPos(i1);
              final v2 = getVertexPos(i2);

              if (v0 != null && v1 != null && v2 != null) {
                final globalBaseIdx = positions.length ~/ 3;
                final nodeBaseIdx = node.positions.length ~/ 3;
                final subBaseIdx = subPos.length ~/ 3;

                final uv0 = getVertexUV(i0) ?? [0.0, 0.0];
                final uv1 = getVertexUV(i1) ?? [0.0, 0.0];
                final uv2 = getVertexUV(i2) ?? [0.0, 0.0];

                addUncompressedVert(v0, uv0, i0);
                addUncompressedVert(v1, uv1, i1);
                addUncompressedVert(v2, uv2, i2);

                indices.addAll([
                  globalBaseIdx,
                  globalBaseIdx + 1,
                  globalBaseIdx + 2,
                ]);
                node.indices.addAll([
                  nodeBaseIdx,
                  nodeBaseIdx + 1,
                  nodeBaseIdx + 2,
                ]);
                subIndices.addAll([
                  subBaseIdx,
                  subBaseIdx + 1,
                  subBaseIdx + 2,
                ]);
              }
            }
          }

          if (subPos.isNotEmpty && subIndices.isNotEmpty) {
            Uint8List? subVertexColors;
            if (subColorList.length >= (subPos.length ~/ 3) * 3) {
              subVertexColors = Uint8List.fromList(
                subColorList.sublist(0, (subPos.length ~/ 3) * 3),
              );
            }
            final mName =
                (matIdx != null && parsedMaterialNames.length > matIdx)
                ? parsedMaterialNames[matIdx]
                : null;
            subPrimitives.add(
              GlbSubPrimitive(
                positions: subPos,
                indices: subIndices,
                vertexColors: subVertexColors,
                baseColor: matColor,
                materialName: mName,
                materialIndex: matIdx,
              ),
            );
          }
        }
      }
    }
  } catch (e, st) {
    GlbParserService._logger.log(
      'GLB parsing exception: $e\n$st',
      level: 'error',
      source: 'GlbParserService',
    );
  }

  if (positions.isEmpty) {
    GlbParserService._logger.log(
      'GLB warning: Parsed 0 valid 3D vertex positions.',
      level: 'warning',
      source: 'GlbParserService',
    );
    return null;
  }

  final vertCount = positions.length ~/ 3;

  if (indices.isEmpty && vertCount >= 3) {
    indices.addAll(List<int>.generate(vertCount, (i) => i));
  }

  if (vertexColorList.length >= vertCount * 3) {
    vertexColors = Uint8List.fromList(
      vertexColorList.sublist(0, vertCount * 3),
    );
  }

  // Morph Targets list construction
  final List<GlbMorphTarget> parsedMorphTargets = [];
  for (int tIdx = 0; tIdx < parsedMorphDeltaLists.length; tIdx++) {
    final name = tIdx < parsedMorphTargetNames.length
        ? parsedMorphTargetNames[tIdx]
        : 'morph_$tIdx';
    parsedMorphTargets.add(
      GlbMorphTarget(name: name, positionDeltas: parsedMorphDeltaLists[tIdx]),
    );
  }

  Uint16List? parsedJoints;
  if (parsedJointsList.length >= vertCount * 4) {
    parsedJoints = Uint16List.fromList(
      parsedJointsList.sublist(0, vertCount * 4),
    );
  }

  Float32List? parsedWeights;
  if (parsedWeightsList.length >= vertCount * 4) {
    parsedWeights = Float32List.fromList(
      parsedWeightsList.sublist(0, vertCount * 4),
    );
  }

  // Compute bounds if infinite
  if (minBounds[0] == double.infinity) {
    double minX = positions[0], minY = positions[1], minZ = positions[2];
    double maxX = positions[0], maxY = positions[1], maxZ = positions[2];
    for (int i = 0; i < positions.length; i += 3) {
      if (positions[i] < minX) minX = positions[i];
      if (positions[i + 1] < minY) minY = positions[i + 1];
      if (positions[i + 2] < minZ) minZ = positions[i + 2];
      if (positions[i] > maxX) maxX = positions[i];
      if (positions[i + 1] > maxY) maxY = positions[i + 1];
      if (positions[i + 2] > maxZ) maxZ = positions[i + 2];
    }
    minBounds = [minX, minY, minZ];
    maxBounds = [maxX, maxY, maxZ];
  }

  // 8. Parse Animations
  final List<GlbAnimationClip> parsedAnimations = _parseAnimations(json, bytes, binStart);

  GlbParserService._logger.log(
    'Parsed GLB model with node hierarchy transforms ($vertCount vertices, ${indices.length ~/ 3} triangles, ${parsedAnimations.length} animations).',
    level: 'success',
    source: 'GlbParserService',
  );

  return GlbMeshData(
    subPrimitives: subPrimitives,
    positions: positions,
    indices: indices,
    uvs: uvs,
    minBounds: minBounds,
    maxBounds: maxBounds,
    baseColor: baseColor,
    vertexColors: vertexColors,
    rawPayload: bytes,
    rootNodes: parsedRootNodes,
    allNodes: parsedAllNodes,
    materialNames: parsedMaterialNames,
    skeletonJointIndices: skinJointIndices,
    morphTargets: parsedMorphTargets,
    jointsPerVertex: parsedJoints,
    weightsPerVertex: parsedWeights,
    maxInfluences: 4,
    animations: parsedAnimations,
  );
}

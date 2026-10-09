part of '../glb_reader.dart';

Future<GlbMeshData?> _parseGlb(Uint8List bytes, GlbDecoders decoders) async {
  if (bytes.length < 20) {
    GlbReader._logger.log(
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
          return await _parseGlb(payload, decoders);
        }
      }
    } catch (e) {
      GlbReader._logger.log(
        'LMAS container JSON parse notice: $e',
        level: 'warning',
        source: 'GlbParserService',
      );
    }
  }

  final glb = await _readGlbChunks(bytes, decoders);
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

  await _decodeBaseColorImages(json, bytes, binStart, decodedImages, decoders);

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
          _readGlbPrimitive(
            prim,
            mesh: mesh,
            node: node,
            xform: xform,
            json: json,
            bytes: bytes,
            byteData: byteData,
            binStart: binStart,
            accessors: accessors,
            bufferViews: bufferViews,
            decoders: decoders,
            getMaterialImage: getMaterialImage,
            getMaterialBaseColor: getMaterialBaseColor,
            positions: positions,
            indices: indices,
            uvs: uvs,
            vertexColorList: vertexColorList,
            subPrimitives: subPrimitives,
            minBounds: minBounds,
            maxBounds: maxBounds,
            parsedMaterialNames: parsedMaterialNames,
            parsedJointsList: parsedJointsList,
            parsedWeightsList: parsedWeightsList,
            parsedMorphDeltaLists: parsedMorphDeltaLists,
            parsedMorphTargetNames: parsedMorphTargetNames,
          );
        }
      }
    }
  } catch (e, st) {
    GlbReader._logger.log(
      'GLB parsing exception: $e\n$st',
      level: 'error',
      source: 'GlbParserService',
    );
  }

  if (positions.isEmpty) {
    GlbReader._logger.log(
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

  GlbReader._logger.log(
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

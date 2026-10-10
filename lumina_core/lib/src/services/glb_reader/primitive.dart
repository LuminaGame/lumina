part of '../glb_reader.dart';

/// Appends one primitive of [node]'s [mesh] (triangles only; Draco-compressed,
/// quantized or plain) to the model's buffers: positions in world space,
/// indices, UVs, colours, skin weights, morph deltas and a [GlbSubPrimitive].
/// The buffers come from [_parseGlb], which reads every primitive this way.
void _readGlbPrimitive(
  dynamic prim, {
  required Map mesh,
  required GlbNode node,
  required _NodeTransform xform,
  required Map<String, dynamic> json,
  required Uint8List bytes,
  required ByteData byteData,
  required int binStart,
  required List accessors,
  required List bufferViews,
  required GlbDecoders decoders,
  required _GlbDecodedImage? Function(int? matIdx) getMaterialImage,
  required List<double> Function(int? matIdx) getMaterialBaseColor,
  required List<double> positions,
  required List<int> indices,
  required List<double> uvs,
  required List<int> vertexColorList,
  required List<GlbSubPrimitive> subPrimitives,
  required List<double> minBounds,
  required List<double> maxBounds,
  required List<String> parsedMaterialNames,
  required List<int> parsedJointsList,
  required List<double> parsedWeightsList,
  required List<List<double>> parsedMorphDeltaLists,
  required List<String> parsedMorphTargetNames,
}) {
  final mode = (prim['mode'] as int?) ?? 4; // 4 = TRIANGLES
  if (mode != 4) return;

  final matIdx = prim['material'] as int?;
  final matImg = getMaterialImage(matIdx);
  final matColor = getMaterialBaseColor(matIdx);

  final attributes = prim['attributes'] as Map?;
  if (attributes == null) return;
  final posAccessorIdx = attributes['POSITION'] as int?;
  if (posAccessorIdx == null || posAccessorIdx >= accessors.length) {
    return;
  }

  final posAccessor = accessors[posAccessorIdx] as Map;
  final posBufViewIdx = posAccessor['bufferView'] as int?;

  if (posBufViewIdx == null || posBufViewIdx >= bufferViews.length) {
    // Decode Draco compressed geometry with the decoder the caller provides
    // (the engine's: Filament's native Draco decoder).
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
          final decoded = decoders.draco?.call(dracoBytes);
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
                // Draco primitives keep their material slot like plain ones.
                materialName: (matIdx != null && parsedMaterialNames.length > matIdx)
                    ? parsedMaterialNames[matIdx]
                    : null,
                materialIndex: matIdx,
              ),
            );

            return;
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
    return;
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

  // JOINTS_0 holds indices into the joints of the skin of the node that
  // draws the primitive; the model's buffers keep node indices (what
  // [GlbMeshData.allNodes] and the bone tree use), so several meshes with
  // their own skins over one skeleton read the same way.
  final skinIdx = ((json['nodes'] as List?)?.elementAtOrNull(node.index) as Map?)?['skin'] as int?;
  final skinJoints = skinIdx == null
      ? null
      : (((json['skins'] as List?)?.elementAtOrNull(skinIdx) as Map?)?['joints'] as List?)?.cast<int>();
  List<int> toNodeIndices(List<int> joints) {
    if (skinJoints == null || skinJoints.isEmpty) return joints;
    return [for (final j in joints) j < skinJoints.length ? skinJoints[j] : j];
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

    final joints = toNodeIndices(getVertexJoints(vertIndex));
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

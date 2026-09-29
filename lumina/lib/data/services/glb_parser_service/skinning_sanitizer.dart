part of '../glb_parser_service.dart';

/// Inspects a COLOR_0 accessor to determine if it is a dummy unpainted black vertex color buffer.
/// Character tools (such as Character Creator, MetaHuman, Unreal FBX/glTF exporters) often
/// export all-black (0,0,0,0 or 0,0,0,1) vertex color buffers. In Filament PBR shaders,
/// vertex color multiplies the baseColor (material.baseColor *= getColor()), causing textured
/// meshes to render pitch-black if not stripped.
bool _isDummyBlackVertexColor(
  Map acc,
  List bufferViews,
  List<Uint8List> bvDataList,
) {
  try {
    final bvIdx = acc['bufferView'] as int?;
    if (bvIdx == null ||
        bvIdx < 0 ||
        bvIdx >= bvDataList.length ||
        bvIdx >= bufferViews.length) {
      return false;
    }
    final bvData = bvDataList[bvIdx];
    final bv = bufferViews[bvIdx] as Map?;
    if (bv == null || bvData.isEmpty) return false;

    final count = (acc['count'] as int?) ?? 0;
    if (count <= 0) return false;

    final type = acc['type'] as String?;
    final compType = acc['componentType'] as int?;
    if (type != 'VEC3' && type != 'VEC4') return false;

    final compCount = type == 'VEC4' ? 4 : 3;
    int bytesPerComp;
    if (compType == 5121) {
      // UNSIGNED_BYTE
      bytesPerComp = 1;
    } else if (compType == 5123) {
      // UNSIGNED_SHORT
      bytesPerComp = 2;
    } else if (compType == 5126) {
      // FLOAT
      bytesPerComp = 4;
    } else {
      return false;
    }

    final vertexStride = compCount * bytesPerComp;
    final stride = (bv['byteStride'] as int?) ?? vertexStride;
    final accByteOffset = (acc['byteOffset'] as int?) ?? 0;

    final sampleCount = count < 50 ? count : 50;
    final step = count ~/ sampleCount;
    int blackCount = 0;

    final byteData = ByteData.sublistView(bvData);

    for (int i = 0; i < sampleCount; i++) {
      final vertIdx = i * step;
      final offset = accByteOffset + vertIdx * stride;
      if (offset + vertexStride > bvData.length) break;

      double r = 0, g = 0, b = 0;
      if (compType == 5121) {
        r = byteData.getUint8(offset) / 255.0;
        g = byteData.getUint8(offset + 1) / 255.0;
        b = byteData.getUint8(offset + 2) / 255.0;
      } else if (compType == 5123) {
        r = byteData.getUint16(offset, Endian.little) / 65535.0;
        g = byteData.getUint16(offset + 2, Endian.little) / 65535.0;
        b = byteData.getUint16(offset + 4, Endian.little) / 65535.0;
      } else if (compType == 5126) {
        r = byteData.getFloat32(offset, Endian.little);
        g = byteData.getFloat32(offset + 4, Endian.little);
        b = byteData.getFloat32(offset + 8, Endian.little);
      }

      // If RGB brightness is pitch black (< 0.05)
      if (r < 0.05 && g < 0.05 && b < 0.05) {
        blackCount++;
      }
    }

    return blackCount >= (sampleCount * 0.9).floor();
  } catch (_) {
    return false;
  }
}

/// Inspects and sanitizes skeletal mesh skinning weights:
/// 1. If a primitive has >4 bone influences (JOINTS_1 / WEIGHTS_1, common in Unreal / MetaHuman / CCMH models),
///    downsamples to the top 4 influences by weight.
/// 2. Converts WEIGHTS_0 to normalized FLOAT (componentType 5126), ensuring the sum of the 4 weights equals 1.0.
///    (Filament gltfio only supports 4 influences, and its normalizeSkinningWeights strictly requires FLOAT weights,
///    so non-float or >4-bone meshes suffer vertex collapsing to (0,0,0) without this pass).
bool _sanitizeSkinningWeights(
  Map json,
  List bufferViews,
  List<Uint8List> bvDataList,
) {
  try {
    final meshes = json['meshes'] as List?;
    final accessors = json['accessors'] as List?;
    if (meshes == null || accessors == null) return false;

    bool anySkinModified = false;

    final nodes = json['nodes'] as List?;
    final parentMap = <int, int>{};
    if (nodes != null) {
      for (int i = 0; i < nodes.length; i++) {
        final n = nodes[i];
        if (n is Map) {
          final children = n['children'] as List?;
          if (children != null) {
            for (final c in children) {
              if (c is int) parentMap[c] = i;
            }
          }
        }
      }
    }

    // Map each mesh index to its skin index (from nodes referencing the mesh and skin)
    final meshSkinMap = <int, int>{};
    if (nodes != null) {
      for (final n in nodes) {
        if (n is Map) {
          final mIdx = n['mesh'] as int?;
          final sIdx = n['skin'] as int?;
          if (mIdx != null && sIdx != null) {
            meshSkinMap[mIdx] = sIdx;
          }
        }
      }
    }

    // 0. Cap skins to Filament's CONFIG_MAX_BONE_COUNT (256 bones) using intelligent joint reduction:
    // MetaHuman and Unreal skeletal meshes can contain 800+ bones in their skin hierarchy.
    // Filament RenderableManager has a hard static uniform buffer limit of 256 bones.
    // - Keep all critical humanoid skeleton joints (root, pelvis, spine, neck, head, major limbs, fingers, legs).
    // - Accumulate skinning weight per joint across all primitives.
    // - Prune non-essential helper joints with lowest vertex skinning weights.
    // - Transfer weights of pruned joints to their nearest kept ancestor bone in the skeleton hierarchy,
    //   NEVER clamping to joint 0 (root).
    final skins = json['skins'] as List?;
    final skinJointRemaps = <int, Map<int, int>>{};
    bool skinsCapped = false;

    if (skins != null) {
      for (int sIdx = 0; sIdx < skins.length; sIdx++) {
        final s = skins[sIdx];
        if (s is! Map) continue;
        final joints = s['joints'] as List?;
        if (joints == null || joints.length <= 256) continue;

        final origJoints = joints.cast<int>();
        final origJointCount = origJoints.length;

        // Map node index -> original joint index in this skin
        final nodeToOrigJoint = <int, int>{};
        for (int j = 0; j < origJointCount; j++) {
          nodeToOrigJoint[origJoints[j]] = j;
        }

        // Accumulate vertex weight sums for each joint in this skin across relevant primitives
        final jointWeightSums = List<double>.filled(origJointCount, 0.0);
        for (int mIdx = 0; mIdx < meshes.length; mIdx++) {
          final meshSkin = meshSkinMap[mIdx] ?? 0;
          if (meshSkin != sIdx && skins.length > 1) continue;
          final m = meshes[mIdx];
          if (m is! Map) continue;
          final primitives = m['primitives'] as List?;
          if (primitives == null) continue;

          for (final prim in primitives) {
            if (prim is! Map) continue;
            final attrs = prim['attributes'] as Map?;
            if (attrs == null) continue;

            for (int setIdx = 0; setIdx < 4; setIdx++) {
              final jKey = 'JOINTS_$setIdx';
              final wKey = 'WEIGHTS_$setIdx';
              if (!attrs.containsKey(jKey) || !attrs.containsKey(wKey)) continue;
              final ji = attrs[jKey] as int?;
              final wi = attrs[wKey] as int?;
              if (ji == null || wi == null || ji >= accessors.length || wi >= accessors.length) continue;

              final ja = accessors[ji] as Map?;
              final wa = accessors[wi] as Map?;
              if (ja == null || wa == null) continue;
              final jBvIdx = ja['bufferView'] as int?;
              final wBvIdx = wa['bufferView'] as int?;
              if (jBvIdx == null || wBvIdx == null || jBvIdx >= bvDataList.length || wBvIdx >= bvDataList.length) continue;

              final jbv = bufferViews[jBvIdx] as Map?;
              final wbv = bufferViews[wBvIdx] as Map?;
              if (jbv == null || wbv == null) continue;

              final jData = bvDataList[jBvIdx];
              final wData = bvDataList[wBvIdx];
              final jOffset = (jbv['byteOffset'] as int? ?? 0) + (ja['byteOffset'] as int? ?? 0);
              final wOffset = (wbv['byteOffset'] as int? ?? 0) + (wa['byteOffset'] as int? ?? 0);
              final jct = ja['componentType'] as int? ?? 5123;
              final wct = wa['componentType'] as int? ?? 5126;
              final jBytes = jct == 5123 ? 2 : 1;
              final wBytes = wct == 5126 ? 4 : (wct == 5123 ? 2 : 1);
              final jStride = jbv['byteStride'] as int? ?? (jBytes * 4);
              final wStride = wbv['byteStride'] as int? ?? (wBytes * 4);

              final posIdx = attrs['POSITION'] as int?;
              final vertCount = posIdx != null && posIdx < accessors.length
                  ? ((accessors[posIdx] as Map)['count'] as int? ?? 0)
                  : (ja['count'] as int? ?? 0);

              final jBd = ByteData.sublistView(jData);
              final wBd = ByteData.sublistView(wData);

              for (int v = 0; v < vertCount; v++) {
                final jBase = jOffset + v * jStride;
                final wBase = wOffset + v * wStride;
                for (int c = 0; c < 4; c++) {
                  int j = 0;
                  if (jct == 5123 && jBase + (c + 1) * 2 <= jBd.lengthInBytes) {
                    j = jBd.getUint16(jBase + c * 2, Endian.little);
                  } else if (jBase + c + 1 <= jBd.lengthInBytes) {
                    j = jBd.getUint8(jBase + c);
                  }

                  double w = 0.0;
                  if (wct == 5126 && wBase + (c + 1) * 4 <= wBd.lengthInBytes) {
                    w = wBd.getFloat32(wBase + c * 4, Endian.little);
                  } else if (wct == 5123 && wBase + (c + 1) * 2 <= wBd.lengthInBytes) {
                    w = wBd.getUint16(wBase + c * 2, Endian.little) / 65535.0;
                  } else if (wBase + c + 1 <= wBd.lengthInBytes) {
                    w = wBd.getUint8(wBase + c) / 255.0;
                  }

                  if (j < origJointCount) {
                    jointWeightSums[j] += w;
                  }
                }
              }
            }
          }
        }

        bool isEssential(String name) {
          final lower = name.toLowerCase();
          if (lower == 'root' || lower == 'pelvis') return true;
          if (lower.startsWith('spine_')) return true;
          if (lower.startsWith('neck_') || lower == 'head') return true;
          if (lower.startsWith('clavicle_') &&
              !lower.contains('out') &&
              !lower.contains('fwd') &&
              !lower.contains('bck') &&
              !lower.contains('up') &&
              !lower.contains('down') &&
              !lower.contains('scap')) {
            return true;
          }
          if (lower == 'upperarm_l' || lower == 'upperarm_r') return true;
          if (lower == 'lowerarm_l' || lower == 'lowerarm_r') return true;
          if (lower == 'hand_l' || lower == 'hand_r') return true;
          if (lower == 'thigh_l' || lower == 'thigh_r') return true;
          if (lower == 'calf_l' || lower == 'calf_r') return true;
          if (lower == 'foot_l' || lower == 'foot_r') return true;
          if (lower == 'ball_l' || lower == 'ball_r') return true;
          final fingerPattern = RegExp(r'^(thumb|index|middle|ring|pinky)_(metacarpal|01|02|03)_[lr]$');
          if (fingerPattern.hasMatch(lower)) return true;
          return false;
        }

        final prunableIndices = <int>[];
        for (int j = 0; j < origJointCount; j++) {
          final nodeIdx = origJoints[j];
          final nodeName = (nodes != null && nodeIdx < nodes.length && nodes[nodeIdx] is Map)
              ? (nodes[nodeIdx]['name'] as String? ?? '')
              : '';
          if (!isEssential(nodeName)) {
            prunableIndices.add(j);
          }
        }
        prunableIndices.sort((a, b) => jointWeightSums[a].compareTo(jointWeightSums[b]));

        final numToPrune = origJointCount - 256;
        final prunedSet = prunableIndices.take(numToPrune).toSet();

        final keptOrigIndices = <int>[];
        for (int j = 0; j < origJointCount; j++) {
          if (!prunedSet.contains(j)) {
            keptOrigIndices.add(j);
          }
        }

        if (keptOrigIndices.length > 256) {
          keptOrigIndices.removeRange(256, keptOrigIndices.length);
        } else if (keptOrigIndices.length < 256) {
          for (int j = 0; j < origJointCount && keptOrigIndices.length < 256; j++) {
            if (!keptOrigIndices.contains(j)) keptOrigIndices.add(j);
          }
        }

        final keptNodesSet = keptOrigIndices.map((j) => origJoints[j]).toSet();

        final origToNewJoint = <int, int>{};
        for (int newIdx = 0; newIdx < keptOrigIndices.length; newIdx++) {
          origToNewJoint[keptOrigIndices[newIdx]] = newIdx;
        }

        for (final prunedIdx in prunedSet) {
          final prunedNode = origJoints[prunedIdx];
          int? curr = parentMap[prunedNode];
          int? ancestorNode;
          while (curr != null) {
            if (keptNodesSet.contains(curr)) {
              ancestorNode = curr;
              break;
            }
            curr = parentMap[curr];
          }
          if (ancestorNode != null) {
            final ancOrigIdx = nodeToOrigJoint[ancestorNode];
            if (ancOrigIdx != null && origToNewJoint.containsKey(ancOrigIdx)) {
              origToNewJoint[prunedIdx] = origToNewJoint[ancOrigIdx]!;
            } else {
              origToNewJoint[prunedIdx] = 0;
            }
          } else {
            origToNewJoint[prunedIdx] = 0;
          }
        }

        skinJointRemaps[sIdx] = origToNewJoint;
        skinsCapped = true;

        final ibmIdx = s['inverseBindMatrices'] as int?;
        if (ibmIdx != null && ibmIdx >= 0 && ibmIdx < accessors.length) {
          final ibmAcc = accessors[ibmIdx] as Map?;
          if (ibmAcc != null) {
            final ibmBvIdx = ibmAcc['bufferView'] as int?;
            if (ibmBvIdx != null && ibmBvIdx < bvDataList.length) {
              final origIbmData = bvDataList[ibmBvIdx];
              final origIbmOffset = (ibmAcc['byteOffset'] as int?) ?? 0;
              final newIbmBytes = Uint8List(256 * 64);
              for (int newI = 0; newI < 256; newI++) {
                final origI = keptOrigIndices[newI];
                final srcOff = origIbmOffset + origI * 64;
                final dstOff = newI * 64;
                if (srcOff + 64 <= origIbmData.length) {
                  newIbmBytes.setRange(dstOff, dstOff + 64, origIbmData, srcOff);
                }
              }
              final newIbmBvIdx = bufferViews.length;
              bufferViews.add({
                'buffer': 0,
                'byteOffset': 0,
                'byteLength': newIbmBytes.length,
              });
              bvDataList.add(newIbmBytes);
              ibmAcc['bufferView'] = newIbmBvIdx;
              ibmAcc['byteOffset'] = 0;
              ibmAcc['count'] = 256;
            }
          }
        }

        s['joints'] = [ for (final j in keptOrigIndices) origJoints[j] ];
      }
    }

    if (skinsCapped) {
      anySkinModified = true;
    }

    for (int mIdx = 0; mIdx < meshes.length; mIdx++) {
      final mesh = meshes[mIdx];
      if (mesh is! Map) continue;
      final primitives = mesh['primitives'] as List?;
      if (primitives == null) continue;

      final skinIdx = meshSkinMap[mIdx] ?? 0;
      final jointRemap = skinJointRemaps[skinIdx];

      for (final prim in primitives) {
        if (prim is! Map) continue;
        final attrs = prim['attributes'] as Map?;
        if (attrs == null) continue;

        final j0Idx = attrs['JOINTS_0'] as int?;
        final w0Idx = attrs['WEIGHTS_0'] as int?;
        if (j0Idx == null || w0Idx == null) continue;
        if (j0Idx < 0 ||
            j0Idx >= accessors.length ||
            w0Idx < 0 ||
            w0Idx >= accessors.length) {
          continue;
        }

        final hasExtraJoints =
            attrs.containsKey('JOINTS_1') || attrs.containsKey('WEIGHTS_1');
        final w0Acc = accessors[w0Idx] as Map?;
        final j0Acc = accessors[j0Idx] as Map?;
        if (w0Acc == null || j0Acc == null) continue;
        final w0CompType = (w0Acc['componentType'] as int?) ?? 5126;

        bool hasOver256Joints = false;
        final j0MaxList = j0Acc['max'] as List?;
        if (j0MaxList != null && j0MaxList.isNotEmpty) {
          for (final m in j0MaxList) {
            if (m is num && m >= 256) {
              hasOver256Joints = true;
              break;
            }
          }
        }

        bool needsSanitization =
            skinsCapped || hasExtraJoints || hasOver256Joints || w0CompType != 5126;

        if (!needsSanitization) {
          final count = (w0Acc['count'] as int?) ?? 0;
          final wBvIdx = w0Acc['bufferView'] as int?;
          if (wBvIdx != null && wBvIdx < bvDataList.length) {
            final bv = bufferViews[wBvIdx] as Map;
            final bvData = bvDataList[wBvIdx];
            final bvOffset = (w0Acc['byteOffset'] as int?) ?? 0;
            final stride = (bv['byteStride'] as int?) ?? 16;
            final bd = ByteData.sublistView(bvData, bvOffset);
            final step = math.max(1, count ~/ 20);
            for (int v = 0; v < count; v += step) {
              final off = v * stride;
              if (off + 16 <= bd.lengthInBytes) {
                final sum = bd.getFloat32(off, Endian.little) +
                    bd.getFloat32(off + 4, Endian.little) +
                    bd.getFloat32(off + 8, Endian.little) +
                    bd.getFloat32(off + 12, Endian.little);
                if ((sum - 1.0).abs() > 0.01) {
                  needsSanitization = true;
                  break;
                }
              }
            }
          }
        }

        if (!needsSanitization) continue;

        final jAccList = <Map>[];
        final wAccList = <Map>[];

        for (int setIdx = 0; setIdx < 4; setIdx++) {
          final jKey = 'JOINTS_$setIdx';
          final wKey = 'WEIGHTS_$setIdx';
          if (attrs.containsKey(jKey) && attrs.containsKey(wKey)) {
            final ji = attrs[jKey] as int?;
            final wi = attrs[wKey] as int?;
            if (ji != null &&
                wi != null &&
                ji < accessors.length &&
                wi < accessors.length) {
              final ja = accessors[ji] as Map?;
              final wa = accessors[wi] as Map?;
              if (ja != null && wa != null) {
                jAccList.add(ja);
                wAccList.add(wa);
              }
            }
          }
        }

        if (jAccList.isEmpty || wAccList.isEmpty) continue;
        final vertCount = (jAccList[0]['count'] as int?) ?? 0;
        if (vertCount <= 0) continue;

        final jByteDatas = <ByteData?>[];
        final jStrides = <int>[];
        final jCompTypes = <int>[];
        final wByteDatas = <ByteData?>[];
        final wStrides = <int>[];
        final wCompTypes = <int>[];

        for (int s = 0; s < jAccList.length; s++) {
          final ja = jAccList[s];
          final wa = wAccList[s];
          final jBvIdx = ja['bufferView'] as int?;
          final wBvIdx = wa['bufferView'] as int?;

          if (jBvIdx != null && jBvIdx < bvDataList.length) {
            final bv = bufferViews[jBvIdx] as Map;
            final bOffset = (ja['byteOffset'] as int?) ?? 0;
            final ctype = (ja['componentType'] as int?) ?? 5121;
            final cbytes = ctype == 5123 ? 2 : 1;
            final stride = (bv['byteStride'] as int?) ?? (cbytes * 4);
            jByteDatas.add(ByteData.sublistView(bvDataList[jBvIdx], bOffset));
            jStrides.add(stride);
            jCompTypes.add(ctype);
          } else {
            jByteDatas.add(null);
            jStrides.add(0);
            jCompTypes.add(5121);
          }

          if (wBvIdx != null && wBvIdx < bvDataList.length) {
            final bv = bufferViews[wBvIdx] as Map;
            final bOffset = (wa['byteOffset'] as int?) ?? 0;
            final ctype = (wa['componentType'] as int?) ?? 5126;
            final cbytes = ctype == 5126 ? 4 : (ctype == 5123 ? 2 : 1);
            final stride = (bv['byteStride'] as int?) ?? (cbytes * 4);
            wByteDatas.add(ByteData.sublistView(bvDataList[wBvIdx], bOffset));
            wStrides.add(stride);
            wCompTypes.add(ctype);
          } else {
            wByteDatas.add(null);
            wStrides.add(0);
            wCompTypes.add(5126);
          }
        }

        final newJointsBytes = Uint8List(vertCount * 8); // 4 * uint16 = 8 bytes
        final newJointsBd = ByteData.sublistView(newJointsBytes);
        final newWeightsBytes = Uint8List(vertCount * 16); // 4 * float32 = 16 bytes
        final newWeightsBd = ByteData.sublistView(newWeightsBytes);

        final minW = [1.0, 1.0, 1.0, 1.0];
        final maxW = [0.0, 0.0, 0.0, 0.0];
        int maxJoint = 0;

        final List<_JointWeightPair> pairs = [];
        final Map<int, double> vertWeights = {};

        for (int v = 0; v < vertCount; v++) {
          final int outJOff = v * 8;
          final int outWOff = v * 16;

          pairs.clear();
          vertWeights.clear();

          for (int s = 0; s < jAccList.length; s++) {
            final jbd = jByteDatas[s];
            final wbd = wByteDatas[s];
            if (jbd == null || wbd == null) continue;

            final jOff = v * jStrides[s];
            final wOff = v * wStrides[s];
            final jct = jCompTypes[s];
            final wct = wCompTypes[s];

            for (int c = 0; c < 4; c++) {
              int origJoint = 0;
              if (jct == 5123 && jOff + (c + 1) * 2 <= jbd.lengthInBytes) {
                origJoint = jbd.getUint16(jOff + c * 2, Endian.little);
              } else if (jOff + c + 1 <= jbd.lengthInBytes) {
                origJoint = jbd.getUint8(jOff + c);
              }

              final int joint = jointRemap != null
                  ? (jointRemap[origJoint] ?? (origJoint < 256 ? origJoint : 0))
                  : (origJoint < 256 ? origJoint : 0);

              double weight = 0.0;
              if (wct == 5126 && wOff + (c + 1) * 4 <= wbd.lengthInBytes) {
                weight = wbd.getFloat32(wOff + c * 4, Endian.little);
              } else if (wct == 5123 && wOff + (c + 1) * 2 <= wbd.lengthInBytes) {
                weight = wbd.getUint16(wOff + c * 2, Endian.little) / 65535.0;
              } else if (wOff + c + 1 <= wbd.lengthInBytes) {
                weight = wbd.getUint8(wOff + c) / 255.0;
              }

              if (weight > 0.0001) {
                vertWeights[joint] = (vertWeights[joint] ?? 0.0) + weight;
              }
            }
          }

          for (final entry in vertWeights.entries) {
            pairs.add(_JointWeightPair(entry.key, entry.value));
          }

          pairs.sort((a, b) => b.weight.compareTo(a.weight));

          double sum = 0.0;
          final int topCount = math.min(4, pairs.length);
          for (int i = 0; i < topCount; i++) {
            sum += pairs[i].weight;
          }

          if (sum > 1e-6) {
            final invSum = 1.0 / sum;
            for (int i = 0; i < 4; i++) {
              if (i < topCount) {
                final j = pairs[i].joint;
                final normalizedW = pairs[i].weight * invSum;
                newJointsBd.setUint16(outJOff + i * 2, j, Endian.little);
                newWeightsBd.setFloat32(outWOff + i * 4, normalizedW, Endian.little);
                if (normalizedW < minW[i]) minW[i] = normalizedW;
                if (normalizedW > maxW[i]) maxW[i] = normalizedW;
                if (j > maxJoint && j < 256) maxJoint = j;
              } else {
                newJointsBd.setUint16(outJOff + i * 2, 0, Endian.little);
                newWeightsBd.setFloat32(outWOff + i * 4, 0.0, Endian.little);
                if (0.0 < minW[i]) minW[i] = 0.0;
              }
            }
          } else {
            newJointsBd.setUint16(outJOff, 0, Endian.little);
            newJointsBd.setUint16(outJOff + 2, 0, Endian.little);
            newJointsBd.setUint16(outJOff + 4, 0, Endian.little);
            newJointsBd.setUint16(outJOff + 6, 0, Endian.little);
            newWeightsBd.setFloat32(outWOff, 1.0, Endian.little);
            newWeightsBd.setFloat32(outWOff + 4, 0.0, Endian.little);
            newWeightsBd.setFloat32(outWOff + 8, 0.0, Endian.little);
            newWeightsBd.setFloat32(outWOff + 12, 0.0, Endian.little);
            minW[0] = math.min(minW[0], 1.0);
            maxW[0] = math.max(maxW[0], 1.0);
          }
        }

        final newJBvIdx = bufferViews.length;
        bufferViews.add({
          'buffer': 0,
          'byteOffset': 0,
          'byteLength': newJointsBytes.length,
          'target': 34962,
        });
        bvDataList.add(newJointsBytes);

        final newJAccIdx = accessors.length;
        accessors.add({
          'bufferView': newJBvIdx,
          'byteOffset': 0,
          'componentType': 5123, // UNSIGNED_SHORT
          'count': vertCount,
          'type': 'VEC4',
          'min': [0, 0, 0, 0],
          'max': [maxJoint, maxJoint, maxJoint, maxJoint],
        });
        attrs['JOINTS_0'] = newJAccIdx;

        final newWBvIdx = bufferViews.length;
        bufferViews.add({
          'buffer': 0,
          'byteOffset': 0,
          'byteLength': newWeightsBytes.length,
          'target': 34962,
        });
        bvDataList.add(newWeightsBytes);

        final newWAccIdx = accessors.length;
        accessors.add({
          'bufferView': newWBvIdx,
          'byteOffset': 0,
          'componentType': 5126, // FLOAT
          'count': vertCount,
          'type': 'VEC4',
          'min': minW,
          'max': maxW,
        });
        attrs['WEIGHTS_0'] = newWAccIdx;

        for (int s = 1; s < 8; s++) {
          attrs.remove('JOINTS_$s');
          attrs.remove('WEIGHTS_$s');
        }

        anySkinModified = true;
      }
    }

    return anySkinModified;
  } catch (_) {
    return false;
  }
}

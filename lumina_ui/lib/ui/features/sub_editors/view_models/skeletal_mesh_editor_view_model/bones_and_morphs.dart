part of '../skeletal_mesh_editor_view_model.dart';

/// Bone selection, display toggles, morph weights and skin-weight inspection.
mixin _SkeletalMeshBonesAndMorphs on _SkeletalMeshEditorViewModelState {
  bool _nodeOrChildrenContainBone(GlbNode node) {
    if (node.type == GlbNodeType.bone) return true;
    for (final child in node.children) {
      if (_nodeOrChildrenContainBone(child)) return true;
    }
    return false;
  }

  void setBoneSearchFilter(String filter) {
    _boneSearchFilter = filter.trim().toLowerCase();
    notifyListeners();
  }

  void selectBone(GlbNode? bone) {
    _selectedBone = bone;
    _selectedSocket = null;
    notifyListeners();
  }

  void selectSocket(SkeletalMeshSocket? socket) {
    _selectedSocket = socket;
    if (socket != null) {
      _selectedBone = _allBones.where((b) => b.name == socket.parentBone).firstOrNull;
    }
    notifyListeners();
  }

  void toggleShowBones() {
    _showBones = !_showBones;
    notifyListeners();
  }

  void toggleDisplaySockets() {
    _displaySockets = !_displaySockets;
    notifyListeners();
  }

  void toggleHeatmap() {
    _heatmapEnabled = !_heatmapEnabled;
    notifyListeners();
  }

  void setHeatmapEnabled(bool enabled) {
    if (_heatmapEnabled != enabled) {
      _heatmapEnabled = enabled;
      notifyListeners();
    }
  }

  void setInspectedVertex(int? vertIndex) {
    _inspectedVertex = vertIndex;
    notifyListeners();
  }

  void setMorphWeight(String name, double weight) {
    _morphWeights[name] = weight;
    _isDirty = true;
    notifyListeners();
  }

  void resetMorphs() {
    for (final key in _morphWeights.keys.toList()) {
      _morphWeights[key] = 0.0;
    }
    _isDirty = true;
    notifyListeners();
  }

  Float32List deformedPositions() {
    final basePositions = _glbMesh?.positions ?? const <double>[];
    final count = basePositions.length;
    if (_reusedDeformedPositions == null || _reusedDeformedPositions!.length != count) {
      _reusedDeformedPositions = Float32List(count);
    }
    final out = _reusedDeformedPositions!;
    for (int i = 0; i < count; i++) {
      out[i] = basePositions[i];
    }

    final targets = _glbMesh?.morphTargets ?? const [];
    for (final target in targets) {
      final weight = _morphWeights[target.name] ?? 0.0;
      if (weight != 0.0) {
        final deltas = target.positionDeltas;
        final len = deltas.length < count ? deltas.length : count;
        for (int i = 0; i < len; i++) {
          out[i] += deltas[i] * weight;
        }
      }
    }
    return out;
  }

  Uint8List? heatmapColors(int? boneNodeIndex) {
    if (!_heatmapEnabled || _glbMesh == null) return null;
    final vertCount = _glbMesh!.vertexCount;
    if (vertCount == 0) return null;

    final byteCount = vertCount * 3;
    if (_reusedHeatmapColors == null || _reusedHeatmapColors!.length != byteCount) {
      _reusedHeatmapColors = Uint8List(byteCount);
    }
    final out = _reusedHeatmapColors!;
    final joints = _glbMesh!.jointsPerVertex;
    final weights = _glbMesh!.weightsPerVertex;

    for (int v = 0; v < vertCount; v++) {
      double weight = 0.0;
      if (joints != null && weights != null && boneNodeIndex != null) {
        final base = v * 4;
        if (base + 3 < joints.length && base + 3 < weights.length) {
          for (int i = 0; i < 4; i++) {
            if (joints[base + i] == boneNodeIndex) {
              weight += weights[base + i];
            }
          }
        }
      }
      weight = weight.clamp(0.0, 1.0);

      // Blue (0, 0, 255) -> Cyan -> Green -> Yellow -> Red (255, 0, 0)
      int r, g, b;
      if (weight <= 0.25) {
        final t = weight / 0.25;
        r = 0;
        g = (255 * t).round();
        b = 255;
      } else if (weight <= 0.5) {
        final t = (weight - 0.25) / 0.25;
        r = 0;
        g = 255;
        b = (255 * (1.0 - t)).round();
      } else if (weight <= 0.75) {
        final t = (weight - 0.5) / 0.25;
        r = (255 * t).round();
        g = 255;
        b = 0;
      } else {
        final t = (weight - 0.75) / 0.25;
        r = 255;
        g = (255 * (1.0 - t)).round();
        b = 0;
      }

      final outIdx = v * 3;
      out[outIdx] = r;
      out[outIdx + 1] = g;
      out[outIdx + 2] = b;
    }

    return out;
  }

  Map<String, double> getVertexInfluences(int vertIndex) {
    final influences = <String, double>{};
    if (_glbMesh?.jointsPerVertex != null && _glbMesh?.weightsPerVertex != null) {
      final joints = _glbMesh!.jointsPerVertex!;
      final weights = _glbMesh!.weightsPerVertex!;
      final base = vertIndex * 4;
      if (base + 3 < joints.length && base + 3 < weights.length) {
        for (int i = 0; i < 4; i++) {
          final jIdx = joints[base + i];
          final w = weights[base + i];
          if (w > 0.0 || i == 0) {
            String boneName = 'Bone_$jIdx';
            if (_glbMesh!.allNodes.length > jIdx) {
              boneName = _glbMesh!.allNodes[jIdx].name;
            } else if (_allBones.length > jIdx) {
              boneName = _allBones[jIdx].name;
            }
            influences[boneName] = w;
          }
        }
      }
    }
    final sorted = influences.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sorted);
  }

  double getVertexWeightSum(int vertIndex) {
    if (_glbMesh?.weightsPerVertex != null) {
      final weights = _glbMesh!.weightsPerVertex!;
      final base = vertIndex * 4;
      if (base + 3 < weights.length) {
        return weights[base] + weights[base + 1] + weights[base + 2] + weights[base + 3];
      }
    }
    return 1.0;
  }
}

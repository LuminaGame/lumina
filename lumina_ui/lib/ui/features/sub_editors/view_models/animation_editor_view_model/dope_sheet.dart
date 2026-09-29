part of '../animation_editor_view_model.dart';

/// Dope sheet and timeline keyframing: zoom, snapping, keyframe selection,
/// adding/editing/deleting keys.
mixin _AnimationEditorDopeSheet on _AnimationEditorViewModelState {

  // --- Dope Sheet & Timeline Methods ---
  void setTimelineZoom(double z) {
    _timelineZoom = z.clamp(0.2, 5.0);
    notifyListeners();
  }

  void setSnap(bool snap) {
    _snapToFrames = snap;
    notifyListeners();
  }

  void setSnapInterval(int interval) {
    if (interval > 0) {
      _snapInterval = interval;
      notifyListeners();
    }
  }

  void selectKeyframe(String id, {bool multiSelect = false}) {
    if (!multiSelect) {
      _selectedKeyframeIds.clear();
    }
    _selectedKeyframeIds.add(id);
    notifyListeners();
  }

  void clearKeyframeSelection() {
    if (_selectedKeyframeIds.isNotEmpty) {
      _selectedKeyframeIds.clear();
      notifyListeners();
    }
  }

  void addKeyAtCurrentFrame({String? curveName, double value = 1.0}) {
    final targetTime = _positionSeconds;
    if (curveName != null && curveName.isNotEmpty) {
      addCurveKey(curveName, targetTime, value);
    } else if (_curves.isNotEmpty) {
      addCurveKey(_curves.first.name, targetTime, value);
    } else {
      addCurve('Track_01');
      addCurveKey('Track_01', targetTime, value);
    }
  }

  SelectedKeyframeDetails? get selectedKeyframeDetails {
    if (_selectedKeyframeIds.isEmpty) return null;
    final id = _selectedKeyframeIds.last;

    // 1. Bone Keyframe: format 'bone_boneName_time'
    if (id.startsWith('bone_')) {
      final parts = id.split('_');
      if (parts.length >= 3) {
        final timeStr = parts.last;
        final boneName = parts.sublist(1, parts.length - 1).join('_');
        final targetTime = double.tryParse(timeStr) ?? _positionSeconds;
        final frame = (targetTime * _frameRate).round();

        List<double> loc = [0.0, 0.0, 0.0];
        List<double> quat = [0.0, 0.0, 0.0, 1.0];
        List<double> scl = [1.0, 1.0, 1.0];
        String interp = 'Linear';

        final clip = activeClip;
        if (clip != null) {
          for (final ch in clip.channels) {
            if (ch.nodeName == boneName) {
              interp = ch.interpolation;
              int closestIdx = 0;
              double minDiff = double.infinity;
              for (int i = 0; i < ch.keyframeTimes.length; i++) {
                final diff = (ch.keyframeTimes[i] - targetTime).abs();
                if (diff < minDiff) {
                  minDiff = diff;
                  closestIdx = i;
                }
              }

              if (ch.path == 'translation' && ch.values.length >= (closestIdx + 1) * 3) {
                loc = [
                  ch.values[closestIdx * 3],
                  ch.values[closestIdx * 3 + 1],
                  ch.values[closestIdx * 3 + 2],
                ];
              } else if (ch.path == 'rotation' && ch.values.length >= (closestIdx + 1) * 4) {
                quat = [
                  ch.values[closestIdx * 4],
                  ch.values[closestIdx * 4 + 1],
                  ch.values[closestIdx * 4 + 2],
                  ch.values[closestIdx * 4 + 3],
                ];
              } else if (ch.path == 'scale' && ch.values.length >= (closestIdx + 1) * 3) {
                scl = [
                  ch.values[closestIdx * 3],
                  ch.values[closestIdx * 3 + 1],
                  ch.values[closestIdx * 3 + 2],
                ];
              }
            }
          }
        }

        final euler = SelectedKeyframeDetails.quaternionToEuler(quat[0], quat[1], quat[2], quat[3]);

        return SelectedKeyframeDetails(
          keyId: id,
          type: 'Bone Keyframe',
          targetName: boneName,
          time: targetTime,
          frame: frame,
          location: loc,
          rotationQuat: quat,
          rotationEuler: euler,
          scale: scl,
          interpolation: interp,
        );
      }
    }

    // 2. Master Sequence Keyframe: format 'master_time'
    if (id.startsWith('master_')) {
      final timeStr = id.replaceFirst('master_', '');
      final targetTime = double.tryParse(timeStr) ?? _positionSeconds;
      final frame = (targetTime * _frameRate).round();

      return SelectedKeyframeDetails(
        keyId: id,
        type: 'Master Sequence Keyframe',
        targetName: activeClip?.name ?? 'Active Clip',
        time: targetTime,
        frame: frame,
      );
    }

    // 3. Curve Keyframe
    for (final c in _curves) {
      for (final k in c.keys) {
        if ('${c.name}_${k.time.toStringAsFixed(3)}' == id || c.name == id) {
          return SelectedKeyframeDetails(
            keyId: id,
            type: 'Curve Keyframe',
            targetName: c.name,
            time: k.time,
            frame: (k.time * _frameRate).round(),
            curveValue: k.value,
          );
        }
      }
    }

    // 4. Notify
    for (final n in _notifies) {
      if (n.id == id) {
        return SelectedKeyframeDetails(
          keyId: id,
          type: 'Animation Notify',
          targetName: n.name,
          time: n.time,
          frame: (n.time * _frameRate).round(),
          notifyType: n.type.name,
        );
      }
    }

    return null;
  }

  void updateSelectedCurveKeyframeValue(double newValue) {
    final details = selectedKeyframeDetails;
    if (details == null || details.type != 'Curve Keyframe') return;
    for (final c in _curves) {
      if (c.name == details.targetName) {
        for (final k in c.keys) {
          if ((k.time - details.time).abs() < 1e-4) {
            k.value = newValue;
            _isDirty = true;
            notifyListeners();
            return;
          }
        }
      }
    }
  }

  void deleteSelectedKeys() {
    if (_selectedKeyframeIds.isEmpty) return;
    for (final id in _selectedKeyframeIds) {
      // Check if it matches a notify
      _notifies.removeWhere((n) => n.id == id);
      // Check if it matches a curve key (format: curveName_index or curveName_time)
      for (final c in _curves) {
        c.keys.removeWhere((k) => '${c.name}_${k.time.toStringAsFixed(3)}' == id);
      }
    }
    _selectedKeyframeIds.clear();
    _isDirty = true;
    notifyListeners();
  }
}

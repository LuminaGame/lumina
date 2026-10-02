part of '../animation_editor_view_model.dart';

/// A key on a bone track of the dope sheet: bone, frame and, for a
/// sub-track row, its label (`Rotation.P`).
typedef AnimBoneKeyRef = ({String bone, int frame, String? label});

/// Authoring an animation sequence made in the editor: selecting and posing
/// bones (the viewport gizmo's edits), Auto Key at the playhead, the Key
/// button, editing / moving / deleting bone keys, all undoable.
mixin _AnimationEditorAuthoring on _AnimationEditorViewModelState {
  /// True for a sequence created in the editor (its keys are in the asset).
  bool get isAuthored => _authoredClip != null;

  AuthoredAnimationClip? get authoredClip => _authoredClip;

  GlbSkeleton? get skeleton => _skeleton;

  bool get autoKey => _autoKey;

  /// Auto Key: releasing the gizmo keys the bone's changed channels at the
  /// playhead. Off, a change is a preview reverted by the next seek or play,
  /// unless [keyPendingOrSelected] keys it.
  void setAutoKey(bool value) {
    if (value == _autoKey) return;
    _autoKey = value;
    onAutoKeyChanged?.call(value);
    notifyListeners();
  }

  String? get selectedBone => _selectedBone;

  void selectBone(String? bone) {
    if (bone == _selectedBone) return;
    _selectedBone = bone;
    notifyListeners();
  }

  /// The frame the playhead is on (keys are written there).
  int get playheadFrame {
    final clip = _authoredClip;
    final fps = clip?.frameRate ?? _frameRate;
    final f = (_positionSeconds * fps).round();
    return clip == null ? f : f.clamp(0, clip.lengthFrames);
  }

  bool get hasPendingPreview => _pendingPose.isNotEmpty;

  /// Changes whenever the shown pose of an authored sequence does.
  int get poseRevision => _poseRevision;

  void undo() => transactions.undo();

  void redo() => transactions.redo();

  // --- Skeleton and pose -----------------------------------------------------

  @override
  void _refreshSkeleton() {
    final bytes = _glbMesh?.rawPayload;
    _skeleton = null;
    if (bytes != null && bytes.isNotEmpty) {
      try {
        _skeleton = GlbSkeleton.fromGlb(bytes);
      } catch (_) {}
    }
    _authoredChanged();
  }

  @override
  void _authoredChanged() {
    _poseRevision++;
    _poseCache = null;
    _jointPoseCache = null;
    _worldCache = null;
    _authoredGlbClipCache = null;
  }

  Map<int, BoneTrs>? _poseCache;
  double _poseCacheTime = -1;
  int _poseCacheRevision = -1;
  Map<String, List<double>>? _jointPoseCache;
  List<Matrix4>? _worldCache;
  GlbAnimationClip? _authoredGlbClipCache;

  /// Every node's local transform now: the clip sampled at the playhead with
  /// the pending previews over it.
  Map<int, BoneTrs> get currentNodePose {
    final clip = _authoredClip;
    final skel = _skeleton;
    if (clip == null || skel == null) return const {};
    if (_poseCache != null && _poseCacheTime == _positionSeconds && _poseCacheRevision == _poseRevision) {
      return _poseCache!;
    }
    final pose = clip.samplePose(skel, _positionSeconds);
    for (final entry in _pendingPose.entries) {
      final node = skel.indexOf(entry.key);
      if (node >= 0) pose[node] = entry.value.copy();
    }
    _poseCache = pose;
    _poseCacheTime = _positionSeconds;
    _poseCacheRevision = _poseRevision;
    _jointPoseCache = null;
    _worldCache = null;
    return pose;
  }

  /// The skin joints' local transforms by name for the viewport (10 floats
  /// each, see `SubEditor3DViewport.jointLocalPose`); null for an imported
  /// clip. The same map is returned until the pose changes.
  Map<String, List<double>>? get jointLocalPose {
    final skel = _skeleton;
    if (_authoredClip == null || skel == null) return null;
    final pose = currentNodePose;
    if (_jointPoseCache != null) return _jointPoseCache;
    _jointPoseCache = {
      for (final j in skel.joints)
        if (skel.names[j] != null) skel.names[j]!: pose[j]!.toList(),
    };
    return _jointPoseCache;
  }

  List<Matrix4> get _worldMatrices {
    final skel = _skeleton!;
    final pose = currentNodePose;
    return _worldCache ??= skel.worldMatrices(pose);
  }

  /// [bone]'s local transform as shown now.
  BoneTrs? boneLocal(String bone) {
    final skel = _skeleton;
    if (skel == null) return null;
    final node = skel.indexOf(bone);
    if (node < 0) return null;
    return currentNodePose[node]?.copy();
  }

  /// [bone]'s world position as drawn (GLB frame), or null.
  Vector3? boneWorldPosition(String bone) {
    final skel = _skeleton;
    if (skel == null || _authoredClip == null) return null;
    final node = skel.indexOf(bone);
    if (node < 0) return null;
    return _worldMatrices[node].getTranslation();
  }

  /// The skeleton root and the bone below it (root motion, pelvis) move;
  /// the rest of the skeleton rotates and scales.
  bool canTranslateBone(String bone) {
    final skel = _skeleton;
    if (skel == null) return false;
    final node = skel.indexOf(bone);
    return node >= 0 && (node == skel.root || node == skel.rootChild);
  }

  /// The gizmo's target: the selected bone's world transform in the
  /// authoring frame (Z up) the gizmo works in.
  SubEditorGizmoTarget? gizmoTarget(GizmoMode mode) {
    final bone = _selectedBone;
    final skel = _skeleton;
    if (bone == null || skel == null || _authoredClip == null) return null;
    final node = skel.indexOf(bone);
    if (node < 0) return null;
    final world = _worldMatrices[node];
    final t = Vector3.zero();
    final r = Quaternion.identity();
    final s = Vector3.zero();
    world.decompose(t, r, s);
    return SubEditorGizmoTarget(
      id: bone,
      pivot: AuthoringRotation.toAuthoring(t),
      rotation: AuthoringRotation.quaternionToAuthoring(r..normalize()),
      locked: mode == GizmoMode.translate && !canTranslateBone(bone),
      lockedHint: 'Only the root and pelvis move; rotate (E) or scale (R) this bone',
    );
  }

  /// The joint nearest to the ray (GLB frame), within a few degrees of it.
  String? pickBone(Vector3 origin, Vector3 direction) {
    final skel = _skeleton;
    if (skel == null || _authoredClip == null) return null;
    final dir = direction.normalized();
    final worlds = _worldMatrices;
    String? best;
    var bestScore = 0.04; // tan of ~2.3°
    for (final j in skel.joints) {
      final name = skel.names[j];
      if (name == null) continue;
      final v = worlds[j].getTranslation() - origin;
      final along = v.dot(dir);
      if (along <= 1e-6) continue;
      final perp = (v - dir * along).length;
      final score = perp / along;
      if (score < bestScore) {
        bestScore = score;
        best = name;
      }
    }
    return best;
  }

  // --- Gizmo edits -------------------------------------------------------------

  /// A gizmo drag on [bone] starts: its current local transform and parent
  /// frame are what the drag's deltas apply to.
  void beginBonePose(String bone) {
    final skel = _skeleton;
    if (skel == null || _authoredClip == null) return;
    final node = skel.indexOf(bone);
    if (node < 0) return;
    if (_isPlaying) pause();
    _dragPendingBefore = {for (final e in _pendingPose.entries) e.key: e.value.copy()};
    _dragBone = bone;
    _dragBase = currentNodePose[node]!.copy();
    final parent = skel.parent[node];
    _dragParentWorld = parent < 0 ? Matrix4.identity() : Matrix4.copy(_worldMatrices[parent]);
  }

  /// One pointer move of the drag: a world-space delta (authoring frame)
  /// turned into the bone's local translation / rotation / scale.
  void previewGizmoDelta(SubEditorGizmoDelta delta) {
    final bone = _dragBone;
    final base = _dragBase;
    final parentWorld = _dragParentWorld;
    if (bone == null || base == null || parentWorld == null) return;
    var next = base.copy();
    if (delta.translation != null) {
      if (!canTranslateBone(bone)) return;
      final world = AuthoringRotation.toRuntime(delta.translation!);
      final linear = parentWorld.getRotation()..invert();
      next = BoneTrs(base.t + linear.transformed(world), base.r, base.s);
    } else if (delta.rotationAxis != null) {
      final d = Quaternion.axisAngle(
        AuthoringRotation.toRuntime(delta.rotationAxis!).normalized(),
        (delta.rotationDegrees ?? 0.0) * math.pi / 180.0,
      );
      final pt = Vector3.zero();
      final pr = Quaternion.identity();
      final ps = Vector3.zero();
      parentWorld.decompose(pt, pr, ps);
      pr.normalize();
      // R_world' = Δ · R_parent · R_local  →  R_local' = R_parent⁻¹ · Δ · R_parent · R_local.
      final r = pr.conjugated() * d * pr * base.r;
      next = BoneTrs(base.t, r..normalize(), base.s);
    } else if (delta.scaleHandle != null) {
      final amount = delta.scaleDelta ?? 0.0;
      final s = Vector3.copy(base.s);
      final handle = delta.scaleHandle!;
      // Authoring X / Y / Z are the bone's local x / −z / y.
      if (handle == TransformGizmoModel.uniform || handle == TransformGizmoModel.axisX) s.x += amount;
      if (handle == TransformGizmoModel.uniform || handle == TransformGizmoModel.axisY) s.z += amount;
      if (handle == TransformGizmoModel.uniform || handle == TransformGizmoModel.axisZ) s.y += amount;
      next = BoneTrs(base.t, base.r, Vector3(math.max(s.x, 0.01), math.max(s.y, 0.01), math.max(s.z, 0.01)));
    }
    previewBonePose(bone, next);
  }

  /// Shows [local] on [bone] (not keyed yet).
  void previewBonePose(String bone, BoneTrs local) {
    if (_authoredClip == null) return;
    _pendingPose[bone] = local.copy();
    _authoredChanged();
    notifyListeners();
  }

  /// The drag ends: with Auto Key on, the channels it changed are keyed at
  /// the playhead as one undo step; off, the change stays a preview.
  void endBonePose() {
    final bone = _dragBone;
    final base = _dragBase;
    _dragBone = null;
    _dragBase = null;
    _dragParentWorld = null;
    final before = _dragPendingBefore;
    _dragPendingBefore = null;
    if (bone == null || base == null) return;
    final next = _pendingPose[bone];
    if (next == null) return;
    final changed = _changedChannels(base, next);
    if (changed.isEmpty) {
      _pendingPose
        ..clear()
        ..addAll(before ?? const {});
      _authoredChanged();
      notifyListeners();
      return;
    }
    if (!_autoKey) {
      notifyListeners();
      return;
    }
    final frame = playheadFrame;
    _pendingPose.remove(bone);
    _mutate('Key $bone', (clip) {
      for (final path in changed) {
        clip.setKey(bone, path, frame, next.channel(path));
      }
      return true;
    });
  }

  /// Esc during a drag: the bone goes back to where it was.
  void cancelBonePose() {
    final before = _dragPendingBefore;
    _dragBone = null;
    _dragBase = null;
    _dragParentWorld = null;
    _dragPendingBefore = null;
    _pendingPose
      ..clear()
      ..addAll(before ?? const {});
    _authoredChanged();
    notifyListeners();
  }

  /// The toolbar's Key: keys the pending previews (their changed channels)
  /// at the playhead, or else the selected bone's whole transform.
  void keyPendingOrSelected() {
    final clip = _authoredClip;
    final skel = _skeleton;
    if (clip == null || skel == null) return;
    final frame = playheadFrame;
    if (_pendingPose.isNotEmpty) {
      final sampled = clip.samplePose(skel, _positionSeconds);
      final edits = <String, (BoneTrs, Set<String>)>{};
      for (final e in _pendingPose.entries) {
        final node = skel.indexOf(e.key);
        if (node < 0) continue;
        final changed = _changedChannels(sampled[node]!, e.value);
        if (changed.isNotEmpty) edits[e.key] = (e.value.copy(), changed);
      }
      _pendingPose.clear();
      if (edits.isEmpty) {
        _authoredChanged();
        notifyListeners();
        return;
      }
      _mutate('Key ${edits.keys.join(', ')}', (c) {
        edits.forEach((bone, edit) {
          for (final path in edit.$2) {
            c.setKey(bone, path, frame, edit.$1.channel(path));
          }
        });
        return true;
      });
      return;
    }
    final bone = _selectedBone;
    if (bone == null) return;
    final local = boneLocal(bone);
    if (local == null) return;
    _mutate('Key $bone', (c) {
      for (final path in AuthoredChannel.paths) {
        c.setKey(bone, path, frame, local.channel(path));
      }
      return true;
    });
  }

  static Set<String> _changedChannels(BoneTrs a, BoneTrs b) {
    final out = <String>{};
    if ((a.t - b.t).length > 1e-7) out.add(AuthoredChannel.translation);
    final dot = (a.r.x * b.r.x + a.r.y * b.r.y + a.r.z * b.r.z + a.r.w * b.r.w).abs();
    if (dot < 1 - 1e-9) out.add(AuthoredChannel.rotation);
    if ((a.s - b.s).length > 1e-7) out.add(AuthoredChannel.scale);
    return out;
  }

  // --- Keys --------------------------------------------------------------------

  /// Parses a dope sheet bone key id (`bone_<bone>_<time>` or
  /// `bone_<bone>_<sub-track label>_<time>`) against the known bone names.
  @override
  AnimBoneKeyRef? parseBoneKeyId(String id) {
    if (!id.startsWith('bone_')) return null;
    final body = id.substring(5);
    final cut = body.lastIndexOf('_');
    if (cut <= 0) return null;
    final time = double.tryParse(body.substring(cut + 1));
    if (time == null) return null;
    final rest = body.substring(0, cut);
    final names = <String>{
      ...?_authoredClip?.tracks.keys,
      ...?_skeleton?.names.whereType<String>(),
      for (final c in activeClipChannels) c.nodeName,
    };
    String? bone;
    for (final n in names) {
      if ((rest == n || rest.startsWith('${n}_')) && (bone == null || n.length > bone.length)) bone = n;
    }
    bone ??= rest;
    final label = rest.length > bone.length ? rest.substring(bone.length + 1) : null;
    final fps = _authoredClip?.frameRate ?? _frameRate;
    return (bone: bone, frame: (time * fps).round(), label: label);
  }

  List<GlbAnimationChannel> get activeClipChannels;

  /// The id the dope sheet gives [bone]'s key at [frame].
  String boneKeyId(String bone, int frame) {
    final fps = _authoredClip?.frameRate ?? _frameRate;
    return 'bone_${bone}_${(frame / fps).toStringAsFixed(3)}';
  }

  /// The selected bone keys of an authored sequence.
  List<AnimBoneKeyRef> get selectedBoneKeys => [
        if (_authoredClip != null)
          for (final id in _selectedKeyframeIds)
            if (parseBoneKeyId(id) case final ref? when _authoredClip!.hasKey(ref.bone, ref.frame)) ref,
      ];

  /// Writes [bone]'s key at [frame]: the given channels (others untouched).
  void setBoneKey(String bone, int frame, {List<double>? translation, List<double>? rotation, List<double>? scale}) {
    _mutate('Edit $bone key', (c) {
      if (translation != null) c.setKey(bone, AuthoredChannel.translation, frame, translation);
      if (rotation != null) c.setKey(bone, AuthoredChannel.rotation, frame, rotation);
      if (scale != null) c.setKey(bone, AuthoredChannel.scale, frame, scale);
      return translation != null || rotation != null || scale != null;
    });
  }

  /// Moves the selected bone keys by [delta] frames (each replacing a key
  /// where it lands), as one undo step; the selection follows.
  void moveSelectedBoneKeysBy(int delta) {
    final keys = selectedBoneKeys;
    final clip = _authoredClip;
    if (keys.isEmpty || delta == 0 || clip == null) return;
    for (final k in keys) {
      final to = k.frame + delta;
      if (to < 0 || to > clip.lengthFrames) return;
    }
    final ordered = [...keys]..sort((a, b) => delta > 0 ? b.frame.compareTo(a.frame) : a.frame.compareTo(b.frame));
    final moved = _mutate('Move ${keys.length == 1 ? '${keys.first.bone} key' : '${keys.length} keys'}', (c) {
      var any = false;
      for (final k in ordered) {
        if (c.moveKey(k.bone, k.frame, k.frame + delta)) any = true;
      }
      return any;
    });
    if (moved) {
      _selectedKeyframeIds
        ..clear()
        ..addAll([for (final k in keys) boneKeyId(k.bone, k.frame + delta)]);
      notifyListeners();
    }
  }

  /// Moves the selected bone key(s) so the last selected lands on [frame].
  void moveSelectedBoneKeysToFrame(int frame) {
    final keys = selectedBoneKeys;
    if (keys.isEmpty) return;
    moveSelectedBoneKeysBy(frame - keys.last.frame);
  }

  /// Deletes the selected bone keys as one undo step. True when any was.
  @override
  bool deleteSelectedBoneKeys() {
    final keys = selectedBoneKeys;
    if (keys.isEmpty) return false;
    final removed = _mutate('Delete ${keys.length == 1 ? '${keys.first.bone} key' : '${keys.length} keys'}', (c) {
      var any = false;
      for (final k in keys) {
        if (c.removeKey(k.bone, k.frame)) any = true;
      }
      return any;
    });
    if (removed) {
      for (final k in keys) {
        _selectedKeyframeIds.remove(boneKeyId(k.bone, k.frame));
      }
      _selectedKeyframeIds.removeWhere((id) => parseBoneKeyId(id) != null);
      notifyListeners();
    }
    return removed;
  }

  /// Sets the interpolation of [bone]'s channels ([path] only, or all its
  /// keyed channels): glTF interpolates per channel.
  void setBoneInterpolation(String bone, AuthoredInterpolation interpolation, {String? path}) {
    _mutate('$bone interpolation ${interpolation.label}', (c) {
      var any = false;
      for (final ch in c.tracks[bone]?.values ?? const <AuthoredChannel>[]) {
        if (path != null && ch.path != path) continue;
        if (ch.interpolation != interpolation) {
          ch.interpolation = interpolation;
          any = true;
        }
      }
      return any;
    });
  }

  /// Applies [change] to the clip as one undo step (when it reports a
  /// change). Undo / redo restore copies of the whole clip; [apply] /
  /// [revert] carry other state of the same edit (run now and on redo / on
  /// undo).
  bool _mutate(String label, bool Function(AuthoredAnimationClip clip) change, {void Function()? apply, void Function()? revert}) {
    final clip = _authoredClip;
    if (clip == null) return false;
    final before = clip.copy();
    if (!change(clip)) {
      _authoredChanged();
      notifyListeners();
      return false;
    }
    final after = clip.copy();
    if (after == before) {
      _authoredChanged();
      notifyListeners();
      return false;
    }
    apply?.call();
    transactions.record(EditorTransaction(
      label: label,
      undo: () {
        revert?.call();
        _restoreClip(before);
      },
      redo: () {
        apply?.call();
        _restoreClip(after);
      },
    ));
    _isDirty = true;
    _authoredChanged();
    notifyListeners();
    return true;
  }

  void _restoreClip(AuthoredAnimationClip snapshot) {
    _authoredClip = snapshot.copy();
    _pendingPose.clear();
    _isDirty = true;
    _authoredChanged();
    notifyListeners();
  }

  /// The authored clip as the dope sheet and the clip list read clips.
  GlbAnimationClip? get authoredGlbClip {
    final clip = _authoredClip;
    if (clip == null) return null;
    if (_authoredGlbClipCache != null) return _authoredGlbClipCache;
    final channels = <GlbAnimationChannel>[];
    final times = <double>{};
    final nodes = <int>{};
    for (final track in clip.tracks.entries) {
      final node = _skeleton?.indexOf(track.key) ?? -1;
      for (final ch in track.value.values) {
        if (ch.keys.isEmpty) continue;
        final t = [for (final f in ch.keys.keys) f / clip.frameRate];
        times.addAll(t);
        if (node >= 0) nodes.add(node);
        channels.add(GlbAnimationChannel(
          nodeIndex: node,
          nodeName: track.key,
          path: ch.path,
          keyframeTimes: t,
          values: [for (final v in ch.writtenValues()) ...v],
          interpolation: ch.interpolation.gltfName,
        ));
      }
    }
    return _authoredGlbClipCache = GlbAnimationClip(
      name: clip.name,
      duration: clip.duration,
      animatedNodeIndices: nodes,
      channelTargetPaths: channels.map((c) => c.path).toSet().toList(),
      channels: channels,
      compositeKeyframeTimes: times.toList()..sort(),
    );
  }

  /// The dope sheet rows of an authored sequence: every keyed bone, keys at
  /// their frames.
  List<AnimBoneTrackInfo> get authoredBoneTracks {
    final clip = _authoredClip;
    final glb = authoredGlbClip;
    if (clip == null || glb == null) return const [];
    return [
      for (final bone in clip.bones)
        () {
          final frames = clip.keyFrames(bone);
          final times = [for (final f in frames) f / clip.frameRate];
          return AnimBoneTrackInfo(
            boneName: bone,
            nodeIndex: _skeleton?.indexOf(bone) ?? -1,
            keyframeTimes: times,
            startTime: times.first,
            endTime: times.last,
            hasVariation: true,
            channels: glb.channels.where((c) => c.nodeName == bone).toList(),
          );
        }(),
    ];
  }

  /// The Key panel's view of an authored bone key: the values at its frame
  /// (keyed or sampled), the bone's channel interpolation.
  @override
  SelectedKeyframeDetails? authoredKeyDetails(String id) {
    final clip = _authoredClip;
    final skel = _skeleton;
    final ref = parseBoneKeyId(id);
    if (clip == null || skel == null || ref == null) return null;
    final node = skel.indexOf(ref.bone);
    if (node < 0) return null;
    final time = ref.frame / clip.frameRate;
    final local = clip.samplePose(skel, time)[node]!;
    final ch = clip.channel(ref.bone, AuthoredChannel.rotation) ??
        clip.tracks[ref.bone]?.values.firstOrNull;
    final q = local.r;
    return SelectedKeyframeDetails(
      keyId: id,
      type: 'Bone Keyframe',
      targetName: ref.bone,
      time: time,
      frame: ref.frame,
      location: [local.t.x, local.t.y, local.t.z],
      rotationQuat: [q.x, q.y, q.z, q.w],
      rotationEuler: SelectedKeyframeDetails.quaternionToEulerXyz(q.x, q.y, q.z, q.w),
      scale: [local.s.x, local.s.y, local.s.z],
      interpolation: (ch?.interpolation ?? AuthoredInterpolation.linear).label,
      subTrackLabel: ref.label,
    );
  }
}

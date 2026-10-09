part of '../animation_editor_view_model.dart';

/// Two-bone IK (mode, chains, drags, pinning) and root motion authoring.
mixin _AnimationEditorIkAndRootMotion
    on _AnimationEditorViewModelState, _AnimationEditorAuthoring, _AnimationEditorPoseTools {
  // --- Two-bone IK --------------------------------------------------------------------

  List<TwoBoneIkChain> get ikChains => _skeleton == null ? const [] : TwoBoneIkChain.detect(_skeleton!);

  bool get ikMode => _ikMode;

  /// IK mode: the viewport gizmo moves the selected chain's end target (or
  /// its pole) instead of turning a bone.
  void setIkMode(bool value) {
    if (value == _ikMode) return;
    _ikMode = value;
    if (value && _ikChain == null) {
      final chains = ikChains;
      final bone = _selectedBone;
      _ikChain = chains
              .where((c) => bone != null && [c.upper, c.lower, c.end].any((n) => _skeleton!.names[n] == bone))
              .firstOrNull
              ?.name ??
          chains.firstOrNull?.name;
    }
    notifyListeners();
  }

  String? get ikChainName => _ikChain;

  TwoBoneIkChain? get _activeChain => ikChains.where((c) => c.name == _ikChain).firstOrNull;

  void selectIkChain(String name) {
    if (name == _ikChain) return;
    _ikChain = name;
    final chain = _activeChain;
    if (chain != null) _selectedBone = _skeleton!.names[chain.end];
    notifyListeners();
  }

  /// The chain owning [bone] (any of its three bones), for a viewport pick.
  String? ikChainOfBone(String bone) {
    for (final c in ikChains) {
      if ([c.upper, c.lower, c.end].any((n) => _skeleton!.names[n] == bone)) return c.name;
    }
    return null;
  }

  bool get ikDragsPole => _ikDragsPole;

  void setIkDragsPole(bool value) {
    if (value == _ikDragsPole) return;
    _ikDragsPole = value;
    notifyListeners();
  }

  /// The chain's end target (GLB frame): where the end effector is, or
  /// where a drag has put it.
  Vector3? get ikTargetPosition {
    final chain = _activeChain;
    if (chain == null || _authoredClip == null) return null;
    if (_ikDragging && !_ikDragsPole && _ikDragTarget != null) return _ikDragTarget;
    return _worldMatrices[chain.end].getTranslation();
  }

  /// The chain's pole: set by hand, else out from the middle joint along the
  /// chain's current bend.
  Vector3? get ikPolePosition {
    final chain = _activeChain;
    if (chain == null || _authoredClip == null) return null;
    if (_ikDragging && _ikDragsPole && _ikDragTarget != null) return _ikDragTarget;
    final set = _ikPoles[chain.name];
    if (set != null) return set;
    final w = _worldMatrices;
    final a = w[chain.upper].getTranslation();
    final b = w[chain.lower].getTranslation();
    final c = w[chain.end].getTranslation();
    final line = (c - a);
    final dir = line.length2 < 1e-12 ? Vector3(0, -1, 0) : line.normalized();
    var bend = (b - a) - dir * (b - a).dot(dir);
    if (bend.length2 < 1e-12) bend = dir.cross(Vector3(0, 1, 0));
    if (bend.length2 < 1e-12) bend = Vector3(0, 0, 1);
    return b + bend.normalized() * (b - a).length;
  }

  /// Puts the chain's pole at [world] (GLB frame).
  void setIkPole(Vector3 world) {
    final chain = _activeChain;
    if (chain == null) return;
    _ikPoles[chain.name] = Vector3.copy(world);
    notifyListeners();
  }

  /// The gizmo's target in IK mode: the end target, or the pole.
  SubEditorGizmoTarget? get ikGizmoTarget {
    final chain = _activeChain;
    if (!_ikMode || chain == null) return null;
    final at = _ikDragsPole ? ikPolePosition : ikTargetPosition;
    if (at == null) return null;
    return SubEditorGizmoTarget(
      id: '${_ikDragsPole ? 'pole' : 'ik'}:${chain.name}',
      pivot: AuthoringRotation.toAuthoring(at),
      rotation: Quaternion.identity(),
      lockedHint: 'IK targets move: use the translate tool (W)',
    );
  }

  void beginIkDrag() {
    final chain = _activeChain;
    if (chain == null || _authoredClip == null) return;
    if (_isPlaying) pause();
    _ikPendingBefore = {for (final e in _pendingPose.entries) e.key: e.value.copy()};
    _ikDragStart = _ikDragsPole ? ikPolePosition : ikTargetPosition;
    _ikDragTarget = _ikDragStart;
    _ikDragging = true;
  }

  /// One pointer move of an IK drag: the target (or pole) moves by the
  /// gizmo's translation and the chain is solved to it (a preview).
  void previewIkDelta(SubEditorGizmoDelta delta) {
    final start = _ikDragStart;
    if (!_ikDragging || start == null || delta.translation == null) return;
    _ikDragTarget = start + AuthoringRotation.toRuntime(delta.translation!);
    _solveIkPreview();
  }

  void _solveIkPreview() {
    final chain = _activeChain;
    final skel = _skeleton;
    final moved = _ikDragTarget;
    if (chain == null || skel == null || moved == null) return;
    // Solve from the pose without this drag's preview.
    final base = _authoredClip!.samplePose(skel, _positionSeconds);
    for (final e in (_ikPendingBefore ?? const <String, BoneTrs>{}).entries) {
      final n = skel.indexOf(e.key);
      if (n >= 0) base[n] = e.value.copy();
    }
    final Vector3 target;
    final Vector3? pole;
    if (_ikDragsPole) {
      target = skel.worldMatrices(base)[chain.end].getTranslation();
      pole = moved;
    } else {
      target = moved;
      pole = _ikPoles[chain.name];
    }
    final out = TwoBoneIkSolver.solve(skeleton: skel, pose: base, chain: chain, target: target, pole: pole);
    out.forEach((n, trs) => _pendingPose[skel.names[n]!] = trs);
    _authoredChanged();
    notifyListeners();
  }

  /// The drag ends: a moved pole is kept; with Auto Key on the chain's
  /// rotations are keyed at the playhead as one undo step, off they stay a
  /// preview.
  void endIkDrag() {
    final chain = _activeChain;
    final skel = _skeleton;
    if (!_ikDragging || chain == null || skel == null) {
      _ikDragging = false;
      return;
    }
    _ikDragging = false;
    final moved = _ikDragTarget;
    _ikDragStart = null;
    _ikDragTarget = null;
    _ikPendingBefore = null;
    if (_ikDragsPole && moved != null) _ikPoles[chain.name] = moved;
    if (!_autoKey) {
      notifyListeners();
      return;
    }
    final names = [for (final n in [chain.upper, chain.lower, chain.end]) skel.names[n]!];
    final edits = <String, BoneTrs>{
      for (final b in names)
        if (_pendingPose[b] != null) b: _pendingPose[b]!,
    };
    for (final b in names) {
      _pendingPose.remove(b);
    }
    _authoredChanged();
    final frame = playheadFrame;
    final sampled = _authoredClip!.samplePose(skel, _positionSeconds);
    _mutate('IK ${chain.name}', (clip) {
      var any = false;
      edits.forEach((bone, trs) {
        final node = skel.indexOf(bone);
        if (_AnimationEditorPoseTools._meaningfulChannels(sampled[node]!, trs).contains(AuthoredChannel.rotation)) {
          clip.setKey(bone, AuthoredChannel.rotation, frame, trs.channel(AuthoredChannel.rotation));
          any = true;
        }
      });
      return any;
    });
  }

  /// Esc during an IK drag: the chain goes back.
  void cancelIkDrag() {
    final before = _ikPendingBefore;
    _ikDragging = false;
    _ikDragStart = null;
    _ikDragTarget = null;
    _ikPendingBefore = null;
    _pendingPose
      ..clear()
      ..addAll(before ?? const {});
    _authoredChanged();
    notifyListeners();
  }

  /// Keeps chain [name]'s end effector where it is at frame [from] through
  /// frame [to]: at both ends and every keyed frame between them the chain
  /// is solved to that spot and keyed as rotations (a planted foot or hand
  /// baked to FK), as one undo step.
  void pinIkChain(String name, {required int from, required int to}) {
    final clip = _authoredClip;
    final skel = _skeleton;
    final chain = ikChains.where((c) => c.name == name).firstOrNull;
    if (clip == null || skel == null || chain == null) return;
    final lo = math.min(from, to).clamp(0, clip.lengthFrames);
    final hi = math.max(from, to).clamp(0, clip.lengthFrames);
    final frames = <int>{lo, hi, for (final f in allKeyFrames) if (f > lo && f < hi) f}.toList()..sort();
    final target = skel.worldMatrices(clip.samplePose(skel, lo / clip.frameRate))[chain.end].getTranslation();
    final pole = _ikPoles[name];
    final keys = <int, Map<int, BoneTrs>>{};
    for (final f in frames) {
      final pose = clip.samplePose(skel, f / clip.frameRate);
      keys[f] = TwoBoneIkSolver.solve(skeleton: skel, pose: pose, chain: chain, target: target, pole: pole);
    }
    _pendingPose.clear();
    _mutate('Pin $name $lo–$hi', (c) {
      keys.forEach((f, out) {
        out.forEach((n, trs) => c.setKey(skel.names[n]!, AuthoredChannel.rotation, f, trs.channel(AuthoredChannel.rotation)));
      });
      return keys.isNotEmpty;
    });
  }

  // --- Root motion ----------------------------------------------------------------------

  /// Moves the pelvis's horizontal travel onto the skeleton root and turns
  /// Enable Root Motion on, as one undo step.
  void extractRootMotion() {
    final skel = _skeleton;
    if (skel == null) return;
    final was = _enableRootMotion;
    _pendingPose.clear();
    _mutate('Extract Root Motion from Pelvis', (clip) => RootMotionAuthoring.extractFromPelvis(clip, skel),
        apply: () => _enableRootMotion = true, revert: () => _enableRootMotion = was);
  }

  /// Puts the root's travel back into the pelvis (the root stays put) and
  /// turns Enable Root Motion off, as one undo step.
  void zeroRootMotion() {
    final skel = _skeleton;
    if (skel == null) return;
    final was = _enableRootMotion;
    _pendingPose.clear();
    _mutate('Zero Root Motion', (clip) => RootMotionAuthoring.zeroRoot(clip, skel),
        apply: () => _enableRootMotion = false, revert: () => _enableRootMotion = was);
  }

  /// The drawn root path: floor points (GLB frame) in click order.
  List<Vector3> get rootPath => List.unmodifiable(_rootPath);

  void addRootPathPoint(Vector3 world) {
    _rootPath.add(Vector3.copy(world));
    notifyListeners();
  }

  void clearRootPath() {
    if (_rootPath.isEmpty) return;
    _rootPath.clear();
    notifyListeners();
  }

  /// Keys the root's translation through the drawn path, its points spread
  /// evenly over the clip (one point: at the playhead), keeping the root's
  /// height; turns Enable Root Motion on. One undo step.
  void keyRootPath() {
    final clip = _authoredClip;
    final skel = _skeleton;
    final root = skel?.root;
    if (clip == null || skel == null || root == null || _rootPath.isEmpty) return;
    final rootName = skel.names[root]!;
    final parent = skel.parent[root];
    final n = _rootPath.length;
    final writes = <int, List<double>>{};
    for (var i = 0; i < n; i++) {
      final f = n == 1 ? playheadFrame : (i * clip.lengthFrames / (n - 1)).round();
      final pose = clip.samplePose(skel, f / clip.frameRate);
      final world = skel.worldMatrices(pose);
      final parentWorld = parent < 0 ? Matrix4.identity() : world[parent];
      final at = Vector3(_rootPath[i].x, world[root].getTranslation().y, _rootPath[i].z);
      final local = Matrix4.inverted(parentWorld).transformed3(at);
      writes[f] = [local.x, local.y, local.z];
    }
    final was = _enableRootMotion;
    _pendingPose.clear();
    _mutate('Key Root Path (${writes.length} keys)', (c) {
      writes.forEach((f, v) => c.setKey(rootName, AuthoredChannel.translation, f, v));
      return true;
    }, apply: () => _enableRootMotion = true, revert: () => _enableRootMotion = was);
  }
}

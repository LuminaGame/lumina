part of '../animation_editor_view_model.dart';

/// Onion skin settings: ghosts of the [before] previous and [after] next
/// keyed poses around the playhead, the nearest drawn at [opacity].
class AnimOnionSkin {
  final bool enabled;
  final int before;
  final int after;
  final double opacity;

  const AnimOnionSkin({this.enabled = false, this.before = 1, this.after = 1, this.opacity = 0.6});

  AnimOnionSkin copyWith({bool? enabled, int? before, int? after, double? opacity}) => AnimOnionSkin(
        enabled: enabled ?? this.enabled,
        before: (before ?? this.before).clamp(0, 5),
        after: (after ?? this.after).clamp(0, 5),
        opacity: (opacity ?? this.opacity).clamp(0.05, 1.0),
      );
}

/// A ghost pose for the viewport: the clip sampled at [frame] (joint name →
/// 10 floats, as `SubEditor3DViewport.jointLocalPose`), before or after the
/// playhead, or the loop [seam] (frame 0 shown at the clip's end).
class AnimGhostPose {
  final int frame;
  final bool before;
  final bool seam;
  final double opacity;
  final Map<String, List<double>> jointLocalPose;

  const AnimGhostPose({
    required this.frame,
    required this.before,
    required this.opacity,
    required this.jointLocalPose,
    this.seam = false,
  });
}

/// A copied pose: local transforms of the copied bones and the whole pose
/// they came from (a mirrored paste needs every bone's world transform).
class AnimPoseClipboard {
  final int frame;
  final List<String> bones;
  final Map<int, BoneTrs> pose;

  const AnimPoseClipboard({required this.frame, required this.bones, required this.pose});
}

/// Posing and cycle tools on an authored sequence: onion skinning, pose copy
/// / paste / mirror, loop helpers, the pose library, two-bone IK baked to
/// rotation keys and root motion authoring. Every edit is one undo step and
/// writes ordinary keys, so the saved clip plays everywhere unchanged.
mixin _AnimationEditorPoseTools on _AnimationEditorViewModelState, _AnimationEditorAuthoring {
  // Smallest changes worth a key: float noise of the pose math is not one.
  static const double _rotationEpsilonDegrees = 0.005;
  static const double _lengthEpsilon = 1e-6;

  static Set<String> _meaningfulChannels(BoneTrs a, BoneTrs b) {
    final out = <String>{};
    if ((a.t - b.t).length > _lengthEpsilon) out.add(AuthoredChannel.translation);
    if (_degreesBetween(a.r, b.r) > _rotationEpsilonDegrees) out.add(AuthoredChannel.rotation);
    if ((a.s - b.s).length > _lengthEpsilon) out.add(AuthoredChannel.scale);
    return out;
  }

  /// Degrees between two rotations; GLB rest rotations are float32 and not
  /// quite unit length, so the dot product is normalised.
  static double _degreesBetween(Quaternion a, Quaternion b) {
    final len = a.length * b.length;
    if (len < 1e-12) return 0;
    final dot = ((a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w) / len).abs().clamp(0.0, 1.0);
    return 2 * math.acos(dot) * 180 / math.pi;
  }

  String? get _projectDir => AnimationEditorViewModel._findProjectDir(assetPath);

  String? get _meshRelPath {
    final mesh = _asset?.metadata['source_mesh'];
    return mesh == null || mesh.isEmpty ? null : mesh;
  }

  /// Keys [edits] (bone → local transform) at the playhead as one undo
  /// step: the channels that differ from the pose shown there or that are
  /// already animated, and with [keyEveryRotation] (a pasted or mirrored
  /// selection) every bone's rotation, so a later key elsewhere cannot
  /// change this frame.
  bool _keyPose(String label, Map<String, BoneTrs> edits,
      {bool keyEveryRotation = false, void Function()? apply, void Function()? revert}) {
    final skel = _skeleton;
    final clip = _authoredClip;
    if (clip == null || skel == null) return false;
    final frame = playheadFrame;
    final shown = currentNodePose;
    final writes = <String, (BoneTrs, Set<String>)>{};
    edits.forEach((bone, trs) {
      final node = skel.indexOf(bone);
      if (node < 0) return;
      final changed = _meaningfulChannels(shown[node]!, trs);
      for (final path in AuthoredChannel.paths) {
        if (changed.contains(path)) continue;
        final animated = (clip.channel(bone, path)?.keys.isNotEmpty ?? false) && !clip.hasKey(bone, frame, path);
        if (animated || (keyEveryRotation && path == AuthoredChannel.rotation && !clip.hasKey(bone, frame, path))) {
          changed.add(path);
        }
      }
      if (changed.isNotEmpty) writes[bone] = (trs, changed);
    });
    for (final bone in edits.keys) {
      _pendingPose.remove(bone);
    }
    return _mutate(label, (clip) {
      writes.forEach((bone, w) {
        for (final path in w.$2) {
          clip.setKey(bone, path, frame, w.$1.channel(path));
        }
      });
      return writes.isNotEmpty;
    }, apply: apply, revert: revert);
  }

  /// [bone] and every joint below it.
  List<String> _withDescendants(String bone) {
    final skel = _skeleton!;
    final node = skel.indexOf(bone);
    final out = <String>[];
    for (final j in skel.joints) {
      var n = j;
      while (n >= 0 && n != node) {
        n = skel.parent[n];
      }
      if (n == node && skel.names[j] != null) out.add(skel.names[j]!);
    }
    return out;
  }

  // --- Onion skin ----------------------------------------------------------------

  AnimOnionSkin get onionSkin => _onionSkin;

  void setOnionSkin({bool? enabled, int? before, int? after, double? opacity}) {
    _onionSkin = _onionSkin.copyWith(enabled: enabled, before: before, after: after, opacity: opacity);
    notifyListeners();
  }

  bool get showLoopSeam => _showLoopSeam;

  void setShowLoopSeam(bool value) {
    if (value == _showLoopSeam) return;
    _showLoopSeam = value;
    notifyListeners();
  }

  /// Every frame with a key on any bone.
  List<int> get allKeyFrames {
    final clip = _authoredClip;
    if (clip == null) return const [];
    final frames = <int>{
      for (final track in clip.tracks.values)
        for (final ch in track.values) ...ch.keys.keys,
    };
    return frames.toList()..sort();
  }

  Map<String, List<double>> _jointPoseAt(int frame) {
    final skel = _skeleton!;
    final pose = _authoredClip!.samplePose(skel, frame / _authoredClip!.frameRate);
    return {
      for (final j in skel.joints)
        if (skel.names[j] != null) skel.names[j]!: pose[j]!.toList(),
    };
  }

  /// The ghosts to draw: the nearest keyed poses before and after the
  /// playhead (fading with distance), and frame 0 when the loop seam is
  /// shown. Empty for an imported clip or with both off.
  List<AnimGhostPose> get ghostPoses {
    final clip = _authoredClip;
    if (clip == null || _skeleton == null) return const [];
    final out = <AnimGhostPose>[];
    final frame = playheadFrame;
    if (_onionSkin.enabled) {
      final frames = allKeyFrames;
      final before = frames.where((f) => f < frame).toList().reversed.take(_onionSkin.before).toList();
      final after = frames.where((f) => f > frame).take(_onionSkin.after).toList();
      for (final (i, f) in before.indexed) {
        out.add(AnimGhostPose(
          frame: f,
          before: true,
          opacity: _onionSkin.opacity * (before.length - i) / before.length,
          jointLocalPose: _jointPoseAt(f),
        ));
      }
      for (final (i, f) in after.indexed) {
        out.add(AnimGhostPose(
          frame: f,
          before: false,
          opacity: _onionSkin.opacity * (after.length - i) / after.length,
          jointLocalPose: _jointPoseAt(f),
        ));
      }
    }
    if (_showLoopSeam && frame != 0) {
      out.add(AnimGhostPose(frame: 0, before: true, seam: true, opacity: 0.8, jointLocalPose: _jointPoseAt(0)));
    }
    return out;
  }

  /// The largest turn (degrees) any keyed bone makes between frame 0 and
  /// the last frame: how far the clip is from looping; null with no clip.
  double? get loopSeamDegrees {
    final clip = _authoredClip;
    final skel = _skeleton;
    if (clip == null || skel == null) return null;
    final first = clip.samplePose(skel, 0);
    final last = clip.samplePose(skel, clip.duration);
    var worst = 0.0;
    for (final bone in clip.bones) {
      final n = skel.indexOf(bone);
      if (n < 0) continue;
      worst = math.max(worst, _degreesBetween(first[n]!.r, last[n]!.r));
    }
    return worst;
  }

  // --- Clipboard and mirror ---------------------------------------------------------

  bool get hasPoseClipboard => _poseClipboard != null;

  /// What the clipboard holds, for the panel ("Whole pose @ 12").
  String? get poseClipboardLabel {
    final c = _poseClipboard;
    if (c == null) return null;
    final skel = _skeleton;
    final whole = skel != null && c.bones.length >= skel.joints.length;
    return '${whole ? 'Whole pose' : c.bones.length == 1 ? c.bones.first : '${c.bones.length} bones'} @ ${c.frame}';
  }

  /// Copies the pose at the playhead: every joint, or with [selectedOnly]
  /// the selected bone and the bones below it.
  void copyPose({bool selectedOnly = false}) {
    final skel = _skeleton;
    if (_authoredClip == null || skel == null) return;
    final bones = selectedOnly && _selectedBone != null
        ? _withDescendants(_selectedBone!)
        : [for (final j in skel.joints) ?skel.names[j]];
    if (bones.isEmpty) return;
    _poseClipboard = AnimPoseClipboard(
      frame: playheadFrame,
      bones: bones,
      pose: {for (final e in currentNodePose.entries) e.key: e.value.copy()},
    );
    notifyListeners();
  }

  /// Pastes the copied pose at the playhead (keys where it differs), or
  /// [mirrored]: each copied bone's pose onto its mirror partner.
  void pastePose({bool mirrored = false}) {
    final c = _poseClipboard;
    final skel = _skeleton;
    if (c == null || skel == null || _authoredClip == null) return;
    final edits = <String, BoneTrs>{};
    if (mirrored) {
      final m = mirrorTable;
      if (m == null) return;
      final out = m.mirror(source: c.pose, target: currentNodePose, bones: c.bones);
      out.forEach((node, trs) => edits[skel.names[node]!] = trs);
    } else {
      for (final bone in c.bones) {
        final n = skel.indexOf(bone);
        if (n >= 0) edits[bone] = c.pose[n]!;
      }
    }
    _keyPose(mirrored ? 'Paste Mirrored Pose' : 'Paste Pose', edits, keyEveryRotation: c.bones.length < skel.joints.length);
  }

  /// Puts the mirror image of the selected bone and the bones below it onto
  /// the other side, at the playhead.
  void mirrorSelected() {
    final bone = _selectedBone;
    final skel = _skeleton;
    final m = mirrorTable;
    if (bone == null || skel == null || m == null || _authoredClip == null) return;
    final bones = _withDescendants(bone);
    final out = m.mirror(source: currentNodePose, target: currentNodePose, bones: bones);
    final edits = {for (final e in out.entries) skel.names[e.key]!: e.value};
    _keyPose('Mirror ${m.partnerOf(bone)} from $bone', edits, keyEveryRotation: true);
  }

  /// The skeleton's mirror table (name pairs + the user's overrides).
  SkeletonMirror? get mirrorTable {
    final skel = _skeleton;
    if (skel == null) return null;
    if (_mirror != null && identical(_mirror!.skeleton, skel)) return _mirror;
    return _mirror = SkeletonMirror.of(skel, overrides: poseLibrary?.mirrorOverrides ?? const {});
  }

  /// The pairs set by hand for this skeleton.
  Map<String, String> get mirrorOverrides => Map.unmodifiable(poseLibrary?.mirrorOverrides ?? const {});

  /// Pairs [a] with [b] for mirroring (saved with the pose library).
  void setMirrorPair(String a, String b) {
    if (a == b) return;
    _editLibrary('Mirror $a ↔ $b', (lib) {
      lib.mirrorOverrides.removeWhere((k, v) => k == a || k == b || v == a || v == b);
      lib.mirrorOverrides[a] = b;
      return true;
    });
  }

  /// Drops the hand-set pair of [bone].
  void removeMirrorPair(String bone) {
    _editLibrary('Remove mirror pair $bone', (lib) {
      final before = lib.mirrorOverrides.length;
      lib.mirrorOverrides.removeWhere((k, v) => k == bone || v == bone);
      return lib.mirrorOverrides.length != before;
    });
  }

  // --- Loop helpers -------------------------------------------------------------------

  /// Keys the last frame with frame 0's value on every keyed channel: the
  /// clip ends where it starts.
  void copyFirstToLast() => _matchToFirst('Loop: Copy First → Last', _authoredClip?.bones ?? const []);

  /// [copyFirstToLast] for the selected bone and the bones of the selected
  /// keys.
  void matchSelectedToFirst() {
    final bones = <String>{?_selectedBone, for (final k in selectedBoneKeys) k.bone};
    _matchToFirst('Loop: Match ${bones.length == 1 ? bones.first : '${bones.length} bones'} to First', bones);
  }

  void _matchToFirst(String label, Iterable<String> bones) {
    final wanted = bones.toSet();
    if (wanted.isEmpty) return;
    _pendingPose.clear();
    _mutate(label, (clip) {
      var any = false;
      for (final bone in wanted) {
        for (final ch in [...?clip.tracks[bone]?.values]) {
          if (ch.keys.isEmpty) continue;
          final first = ch.sample(0);
          final existing = ch.keys[clip.lengthFrames];
          if (existing != null && _sameValues(existing, first)) continue;
          ch.setKey(clip.lengthFrames, first);
          any = true;
        }
      }
      return any;
    });
  }

  static bool _sameValues(List<double> a, List<double> b) {
    for (var i = 0; i < a.length; i++) {
      if ((a[i] - b[i]).abs() > 1e-12) return false;
    }
    return true;
  }

  // --- Pose library -------------------------------------------------------------------

  /// The mesh's pose library (`contents/animations/<Mesh>/PoseLibrary.lmas`).
  AuthoredPoseLibrary? get poseLibrary {
    if (_poseLibrary != null) return _poseLibrary;
    final dir = _projectDir;
    final mesh = _meshRelPath;
    if (dir == null || mesh == null) return null;
    return _poseLibrary = AuthoredPoseLibraryStore.load(dir, mesh);
  }

  List<AuthoredPose> get libraryPoses => List.unmodifiable(poseLibrary?.poses ?? const []);

  /// Edits the library as one undo step and writes it.
  void _editLibrary(String label, bool Function(AuthoredPoseLibrary lib) change) {
    final lib = poseLibrary;
    final dir = _projectDir;
    if (lib == null || dir == null) return;
    final before = lib.copy();
    if (!change(lib)) return;
    final after = lib.copy();
    void store(AuthoredPoseLibrary l) {
      _poseLibrary = l.copy();
      _mirror = null;
      AuthoredPoseLibraryStore.save(dir, _poseLibrary!);
      notifyListeners();
    }

    store(after);
    transactions.record(EditorTransaction(label: label, undo: () => store(before), redo: () => store(after)));
  }

  /// Saves the pose at the playhead as [name] (replacing a pose of that
  /// name): every joint, or the selected bone and the bones below it.
  void savePoseToLibrary(String name, {bool selectedOnly = false}) {
    final skel = _skeleton;
    final clean = name.trim();
    if (skel == null || clean.isEmpty || _authoredClip == null) return;
    final bones = selectedOnly && _selectedBone != null
        ? _withDescendants(_selectedBone!)
        : [for (final j in skel.joints) ?skel.names[j]];
    final pose = currentNodePose;
    final saved = AuthoredPose(clean, {
      for (final b in bones) b: pose[skel.indexOf(b)]!,
    });
    _editLibrary('Save Pose $clean', (lib) {
      final at = lib.poses.indexWhere((p) => p.name == clean);
      if (at >= 0) {
        lib.poses[at] = saved;
      } else {
        lib.poses.add(saved);
      }
      return true;
    });
  }

  /// Blends the pose shown at the playhead towards the library pose [name]
  /// by [weight] (0–1) and keys the result.
  void applyLibraryPose(String name, {double weight = 1.0}) {
    final skel = _skeleton;
    final pose = poseLibrary?.pose(name);
    if (skel == null || pose == null) return;
    final w = weight.clamp(0.0, 1.0);
    final shown = currentNodePose;
    final edits = <String, BoneTrs>{};
    pose.bones.forEach((bone, saved) {
      final n = skel.indexOf(bone);
      if (n >= 0) edits[bone] = BoneTrs.blend(shown[n]!, saved, w);
    });
    _keyPose('Apply Pose $name (${(w * 100).round()} %)', edits);
  }

  void renameLibraryPose(String from, String to) {
    final clean = to.trim();
    if (clean.isEmpty || clean == from) return;
    _editLibrary('Rename Pose $from → $clean', (lib) {
      final at = lib.poses.indexWhere((p) => p.name == from);
      if (at < 0 || lib.poses.any((p) => p.name == clean)) return false;
      lib.poses[at] = lib.poses[at].renamed(clean);
      return true;
    });
  }

  void deleteLibraryPose(String name) {
    _editLibrary('Delete Pose $name', (lib) {
      final before = lib.poses.length;
      lib.poses.removeWhere((p) => p.name == name);
      return lib.poses.length != before;
    });
  }

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
        if (_meaningfulChannels(sampled[node]!, trs).contains(AuthoredChannel.rotation)) {
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

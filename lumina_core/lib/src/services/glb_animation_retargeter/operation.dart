part of '../glb_animation_retargeter.dart';

abstract final class _RetargetOperation {
  static GlbRetargetResult run({
    required Uint8List target,
    required Uint8List clip,
    required String clipName,
    int animationIndex = 0,
  }) {
    final into = _RetargetTarget.parse(target, compact: false);
    final result = retarget(
      into,
      clip: clip,
      clipName: clipName,
      animationIndex: animationIndex,
    );
    return result._withGlb(into.encode());
  }

  /// Retargets one clip into [into]; the result's `glb` is empty (the GLB
  /// comes from [_RetargetTarget.encode]).
  static GlbRetargetResult retarget(
    _RetargetTarget into, {
    required Uint8List clip,
    required String clipName,
    int animationIndex = 0,
  }) {
    final cDoc = GlbDocument.parse(clip, label: 'clip');
    final src = _Skeleton(cDoc);
    final tgt = into.skeleton;
    final soma = _isSomaClip(cDoc);
    if (soma &&
        (cDoc.json['extras'] as Map?)?['somaReferencePose'] != 'neutral') {
      throw const FormatException(
        'This GEM-X clip has no neutral SOMA reference pose. Generate the motion again with the updated GEM-X exporter.',
      );
    }

    final joints = into.joints;

    final animations = (cDoc.json['animations'] as List?) ?? const [];
    if (animationIndex < 0 || animationIndex >= animations.length) {
      throw FormatException(
        'clip has ${animations.length} animations; asked for $animationIndex',
      );
    }
    final tracks = _Tracks(cDoc, animations[animationIndex] as Map);

    // Name → node, for both sides (case-sensitive first, then case-insensitive fallback).
    final srcByName = <String, int>{};
    final srcByNameLower = <String, int>{};
    for (var i = 0; i < src.count; i++) {
      final n = src.names[i];
      if (n != null) {
        srcByName.putIfAbsent(n, () => i);
        srcByNameLower.putIfAbsent(n.toLowerCase(), () => i);
      }
    }
    final mapped = <int, int>{}; // target node → source node
    for (final j in joints) {
      final name = tgt.names[j];
      final s = name == null
          ? null
          : (soma
                ? _resolveSomaBone(name, tgt.names, srcByNameLower)
                : GlbAnimationRetargeter._resolveSourceBone(
                    name,
                    srcByName,
                    srcByNameLower,
                  ));
      if (s != null) mapped[j] = s;
    }
    if (mapped.isEmpty) {
      throw const FormatException(
        'no skeleton bone of the target matches a bone of the clip by name',
      );
    }

    // The skeleton root: the matched joint no other matched joint is above.
    int? rootT;
    for (final j in tgt.order) {
      if (!mapped.containsKey(j)) continue;
      var p = tgt.parent[j];
      var nested = false;
      while (p >= 0) {
        if (mapped.containsKey(p)) {
          nested = true;
          break;
        }
        p = tgt.parent[p];
      }
      if (!nested) {
        rootT = j;
        break;
      }
    }
    final rootS = mapped[rootT]!;

    int? pelvisT;
    for (final j in mapped.keys) {
      final name = tgt.names[j]!.toLowerCase();
      if (name == 'pelvis' || name == 'hips' || name.endsWith(':hips')) {
        pelvisT = j;
        break;
      }
    }

    // Pelvis translation scale: leg lengths (thigh→calf→foot), from the clip's
    // own translation keys when it has them (its authoring proportions).
    double legLength(_Skeleton sk, _Tracks? tr, String side) {
      double len(String bone) {
        final i = sk.names.indexOf(bone);
        if (i < 0) return 0;
        final key = tr?.translationAtFirstKey(i);
        final t = key ?? sk.restT[i];
        return math.sqrt(t[0] * t[0] + t[1] * t[1] + t[2] * t[2]);
      }

      final somaSide = side == 'l' ? 'Left' : 'Right';
      final calf = len(sk == src && soma ? '${somaSide}Shin' : 'calf_$side');
      final foot = len(sk == src && soma ? '${somaSide}Foot' : 'foot_$side');
      return calf > 0 && foot > 0 ? calf + foot : 0;
    }

    var pelvisScale = 1.0;
    final srcLeg = legLength(src, tracks, 'l') > 0
        ? legLength(src, tracks, 'l')
        : legLength(src, tracks, 'r');
    final tgtLeg = legLength(tgt, null, 'l') > 0
        ? legLength(tgt, null, 'l')
        : legLength(tgt, null, 'r');
    if (srcLeg > 0 && tgtLeg > 0) {
      pelvisScale = tgtLeg / srcLeg;
    } else if (pelvisT != null) {
      final ps = mapped[pelvisT]!;
      final a = GlbAnimationRetargeter._length(src.restT[ps]),
          b = GlbAnimationRetargeter._length(tgt.restT[pelvisT]);
      if (a > 0 && b > 0) pelvisScale = b / a;
    }

    // Time grid: every key time of the clip.
    final times = tracks.keyTimes();
    final frames = times.isEmpty ? [0.0] : times;
    final duration = frames.last;

    // Per frame: source model-space rotations → target local rotations.
    final rotOut = <int, List<_Quat>>{for (final j in joints) j: <_Quat>[]};
    final srcWorld = List<_Quat>.filled(src.count, _Quat.identity);
    final tgtWorld = List<_Quat>.filled(tgt.count, _Quat.identity);
    // Parents of the skeleton roots, at rest on the target side.
    final tgtRootParent = tgt.restWorld(tgt.parent[rootT!]);
    final rootAlign = (tgt.restWorld(rootT) * src.restWorld(rootS).inverse())
        .normalized();
    final srcRestWorld = List<_Quat>.generate(
      src.count,
      (i) => src.restWorld(i),
    );
    final tgtRestWorld = List<_Quat>.generate(
      tgt.count,
      (j) => tgt.restWorld(j),
    );

    // Detect source and target arm rest poses (A-Pose vs T-Pose).
    final srcArmPose = src.detectArmPose();
    final tgtArmPose = tgt.detectArmPose();
    EngineLoggerService().log(
      'Animation retargeting "$clipName": source arm pose is ${srcArmPose.name}, target arm pose is ${tgtArmPose.name}',
      level: 'info',
      source: 'ANIMATION RETARGETING',
    );

    // Forearm twist bones the clip does not animate roll with the hand, each
    // by its share of the forearm length (0 at the elbow, 1 at the wrist).
    // Other twist bones ride rigidly on their limb.
    final forearmTwists = <({int bone, int forearm, int hand, double share})>[];
    for (final j in joints) {
      final match = RegExp(
        r'^lowerarm_twist_\d+_([lr])$',
      ).firstMatch(tgt.names[j]?.toLowerCase() ?? '');
      if (soma || match == null || mapped.containsKey(j)) continue;
      final side = match.group(1);
      final forearm = tgt.parent[j];
      final hand = tgt.names.indexWhere(
        (n) => n?.toLowerCase() == 'hand_$side',
      );
      if (forearm < 0 ||
          hand < 0 ||
          tgt.parent[hand] != forearm ||
          tgt.names[forearm]?.toLowerCase() != 'lowerarm_$side') {
        continue;
      }
      final elbow = tgt.restWorldPos(forearm);
      final wrist = tgt.restWorldPos(hand);
      final at = tgt.restWorldPos(j);
      final axis = [for (var c = 0; c < 3; c++) wrist[c] - elbow[c]];
      final lengthSq =
          axis[0] * axis[0] + axis[1] * axis[1] + axis[2] * axis[2];
      if (lengthSq < 1e-12) continue;
      final along =
          [
            for (var c = 0; c < 3; c++) (at[c] - elbow[c]) * axis[c],
          ].reduce((a, b) => a + b) /
          lengthSq;
      forearmTwists.add((
        bone: j,
        forearm: forearm,
        hand: hand,
        share: along.clamp(0.0, 1.0),
      ));
    }

    // Check whether the target skeleton shares the bone axis convention
    // and rest pose orientation of the source skeleton.
    final sharesRestAxes = !mapped.entries.any((e) {
      final name = tgt.names[e.key]?.toLowerCase() ?? '';
      if (name != 'pelvis' &&
          name != 'hips' &&
          !name.endsWith(':hips') &&
          name != 'thigh_l' &&
          name != 'thigh_r' &&
          name != 'spine_01' &&
          name != 'spine') {
        return false;
      }
      final diff =
          (rootAlign * srcRestWorld[e.value] * tgtRestWorld[e.key].inverse())
              .normalized();
      final angle = 2 * math.acos(diff.w.abs().clamp(0.0, 1.0));
      return angle > (45.0 * math.pi / 180.0);
    });

    // Skeletons with other bone axes take the clip's motion relative to the
    // rest poses, where a clip's chest belongs on the target's top spine bone.
    if (!soma && !sharesRestAxes) {
      GlbAnimationRetargeter._mapTopSpine(tgt.names, mapped, srcByNameLower);
    }
    final hasDynamicChannels = <int>{...mapped.keys};

    final tgtRestAligned = soma
        ? _somaRestAligned(src, tgt, mapped, tgtRestWorld)
        : _restAlignedByMappedJoints(src, tgt, mapped, tgtRestWorld);

    for (final t in frames) {
      for (final i in src.order) {
        final local = tracks.rotation(i, t) ?? src.restR[i];
        final p = src.parent[i];
        srcWorld[i] = p < 0 ? local : srcWorld[p] * local;
      }
      for (final j in tgt.order) {
        final p = tgt.parent[j];
        final parentWorld = p < 0 ? _Quat.identity : tgtWorld[p];
        final s = mapped[j];
        if (s != null) {
          if (soma) {
            // Both model spaces are glTF Y-up. Arm segments must first match
            // the source reference direction to transfer T-pose motion to an
            // A-pose target without adding the reference angle to each bend.
            final isArm = GlbAnimationRetargeter._isArmBone(tgt.names[j]);
            final delta = (srcWorld[s] * srcRestWorld[s].inverse())
                .normalized();
            final reference = isArm ? tgtRestAligned[j] : tgtRestWorld[j];
            tgtWorld[j] = (delta * reference).normalized();
          } else if (sharesRestAxes) {
            tgtWorld[j] = (rootAlign * srcWorld[s]).normalized();
          } else {
            // The clip's model-space motion away from its rest pose, applied
            // to the target rest pose turned to point its bones like the
            // clip's rest bones: every mapped bone then points where the
            // clip's bone points, whatever the two rest poses (A or T) and
            // bone axis conventions are.
            final delta = (srcWorld[s] * srcRestWorld[s].inverse())
                .normalized();
            tgtWorld[j] = (delta * tgtRestAligned[j]).normalized();
          }
          if (joints.contains(j)) {
            rotOut[j]!.add((parentWorld.inverse() * tgtWorld[j]).normalized());
          }
        } else {
          final local = tgt.restR[j];
          tgtWorld[j] = parentWorld * local;
          if (joints.contains(j)) rotOut[j]!.add(local);
        }
      }

      for (final twist in forearmTwists) {
        // The hand's roll about the forearm: the hand's rotation away from
        // riding rigidly on the forearm, twist part about the forearm axis.
        final forearmWorld = tgtWorld[twist.forearm];
        final rigidHand = forearmWorld * tgt.restR[twist.hand];
        final handOffset = (tgtWorld[twist.hand] * rigidHand.inverse())
            .normalized();
        final axis = forearmWorld.rotateVector(tgt.restT[twist.hand]);
        final length = GlbAnimationRetargeter._length(axis);
        if (length < 1e-9) continue;
        final (_, roll) = _Quat.swingTwist(handOffset, [
          for (final c in axis) c / length,
        ]);
        final world =
            (roll.scaled(twist.share) * forearmWorld * tgt.restR[twist.bone])
                .normalized();
        tgtWorld[twist.bone] = world;
        rotOut[twist.bone]!.last = (forearmWorld.inverse() * world)
            .normalized();
        hasDynamicChannels.add(twist.bone);
      }
    }

    // Translations: root copied, pelvis scaled, the rest from the skeleton.
    List<List<double>>? sampledTranslation(
      int targetJoint,
      double scale, {
      bool isPelvis = false,
    }) {
      final s = mapped[targetJoint];
      if (s == null || !tracks.hasTranslation(s)) return null;
      if (soma) {
        final parentBasis = tgt.restWorld(tgt.parent[targetJoint]).inverse();
        final origin = src.restT[s];
        return [
          for (final t in frames)
            [
              for (final (axis, value) in parentBasis.rotateVector([
                for (var i = 0; i < 3; i++)
                  (tracks.translation(s, t)![i] - origin[i]) * scale,
              ]).indexed)
                tgt.restT[targetJoint][axis] + value,
            ],
        ];
      }
      final qAlign = isPelvis
          ? (tgt.restR[rootT!].inverse() * src.restR[rootS]).normalized()
          : (tgt.parent[rootT!] < 0
                    ? _Quat.identity
                    : tgtRootParent *
                          src.restWorld(src.parent[rootS]).inverse())
                .normalized();
      return [
        for (final t in frames)
          [
            for (final v in qAlign.rotateVector(tracks.translation(s, t)!))
              v * scale,
          ],
      ];
    }

    final rootTranslation = sampledTranslation(rootT, 1.0);
    final pelvisTranslation = pelvisT == null
        ? null
        : sampledTranslation(pelvisT, pelvisScale, isPelvis: true);

    // Root motion on a bone between the skeleton root and the pelvis: when
    // the matched top node is a scene node above the root bone (an FBX
    // `RootNode` whose mesh's root bone carries no skin weights), the root
    // bone's own translation keys are the root motion and are copied too.
    final intermediateTranslation = <int, List<List<double>>>{};
    if (pelvisT != null && !soma) {
      var p = tgt.parent[pelvisT];
      while (p >= 0 && p != rootT) {
        final s = mapped[p];
        if (s != null && tracks.hasTranslation(s)) {
          final align = (tgt.restWorld(tgt.parent[p]) * src.restWorld(src.parent[s]).inverse()).normalized();
          intermediateTranslation[p] = [
            for (final t in frames) align.rotateVector(tracks.translation(s, t)!),
          ];
        }
        p = tgt.parent[p];
      }
    }

    // ---- Write the animation into the target GLB.
    final frameInput = into.addAccessor(
      Float32List.fromList(frames),
      'SCALAR',
      frames.length,
      min: [frames.first],
      max: [frames.last],
    );
    final constTimes = duration > 0 ? [0.0, duration] : [0.0];
    final constInput = into.addAccessor(
      Float32List.fromList(constTimes),
      'SCALAR',
      constTimes.length,
      min: [constTimes.first],
      max: [constTimes.last],
    );

    final animation = _PendingAnimation(clipName, constInput, constTimes.length);
    final sortedJoints = joints.toList()..sort();
    for (final j in sortedJoints) {
      final name = tgt.names[j] ?? '';
      final isDynamic = hasDynamicChannels.contains(j);

      // Retargeter isolation: do not generate animation tracks for unmapped face or corrective joints
      if (!isDynamic && GlbAnimationRetargeter.isCorrectiveOrFace(name)) {
        continue;
      }
      if (!isDynamic && into.compact) {
        // Written by [_RetargetTarget.encode], and only when another clip of
        // the asset moves this bone.
        continue;
      }

      // Rotation.
      final keys = rotOut[j]!;
      if (isDynamic) {
        final data = Float32List(keys.length * 4);
        _Quat? prev;
        for (var k = 0; k < keys.length; k++) {
          var q = keys[k];
          if (prev != null && prev.dot(q) < 0) {
            q = q.negated(); // shortest path between keys
          }
          prev = q;
          data.setAll(k * 4, [q.x, q.y, q.z, q.w]);
        }
        animation.channel(
          j,
          'rotation',
          frameInput,
          into.addAccessor(data, 'VEC4', keys.length),
        );
        animation.moved.add(j);
      } else {
        animation.channel(
          j,
          'rotation',
          constInput,
          into.restAccessor(j, 'rotation', constTimes.length),
        );
      }

      // Translation: only root/pelvis get dynamic sampled translations; other unmapped bones don't need constant channels if isolated
      final sampled = j == pelvisT
          ? pelvisTranslation
          : (j == rootT ? rootTranslation : intermediateTranslation[j]);
      if (sampled != null) {
        final data = Float32List(sampled.length * 3);
        for (var k = 0; k < sampled.length; k++) {
          data.setAll(k * 3, sampled[k]);
        }
        animation.channel(
          j,
          'translation',
          frameInput,
          into.addAccessor(data, 'VEC3', sampled.length),
        );
        animation.moved.add(j);
      } else if (!GlbAnimationRetargeter.isCorrectiveOrFace(name) ||
          isDynamic) {
        animation.channel(
          j,
          'translation',
          constInput,
          into.restAccessor(j, 'translation', constTimes.length),
        );
      }
    }
    final clipIndex = into.addAnimation(animation);

    final mappedNames = [
      for (final j in sortedJoints)
        if (mapped.containsKey(j)) tgt.names[j]!,
    ];
    final restNames = [
      for (final j in sortedJoints)
        if (!mapped.containsKey(j) && !hasDynamicChannels.contains(j))
          tgt.names[j] ?? '#$j',
    ];
    final targetNames = {for (final j in joints) tgt.names[j]};
    final ignored = [
      for (final i in tracks.animatedNodes)
        if (src.names[i] != null && !targetNames.contains(src.names[i]))
          src.names[i]!,
    ]..sort();

    return GlbRetargetResult(
      glb: Uint8List(0),
      clipName: clipName,
      clipIndex: clipIndex,
      duration: duration,
      mappedBones: mappedNames,
      restBones: restNames,
      ignoredSourceBones: ignored,
      pelvisTranslationScale: pelvisScale,
      sourceArmPose: srcArmPose,
      targetArmPose: tgtArmPose,
    );
  }
}

/// One retargeted animation before it is written into the target's JSON.
final class _PendingAnimation {
  _PendingAnimation(this.name, this.constInput, this.constKeys);

  final String name;

  /// The clip's two-key (start, end) time accessor; a single key for a
  /// one-frame clip.
  final int constInput;
  final int constKeys;

  final channels = <Map<String, dynamic>>[];
  final samplers = <Map<String, dynamic>>[];

  /// Joints this clip keys away from their rest pose.
  final moved = <int>{};

  /// Joints that have a channel of this clip.
  final keyed = <int>{};

  void channel(int node, String path, int input, int output) {
    samplers.add({'input': input, 'output': output, 'interpolation': 'LINEAR'});
    channels.add({
      'sampler': samplers.length - 1,
      'target': {'node': node, 'path': path},
    });
    keyed.add(node);
  }

  Map<String, dynamic> toJson() => {'name': name, 'channels': channels, 'samplers': samplers};
}

/// A target GLB that clips are retargeted into: parsed once, its binary
/// chunk and accessor lists grown in place, encoded once.
///
/// [compact] (batch imports) writes a rest channel only for a bone some
/// other animation of the asset moves (so switching clips still resets it),
/// and shares the rest values between clips; otherwise every skeleton joint
/// of every clip gets its channels.
final class _RetargetTarget {
  _RetargetTarget._(this.doc, this.skeleton, this.joints, this.compact)
    : _bin = BytesBuilder(copy: false)..add(doc.bin),
      _binLength = doc.bin.length,
      _bufferViews = (doc.json['bufferViews'] as List?)?.toList() ?? <dynamic>[],
      _accessors = (doc.json['accessors'] as List?)?.toList() ?? <dynamic>[],
      _animations = ((doc.json['animations'] as List?) ?? const []).toList();

  factory _RetargetTarget.parse(Uint8List bytes, {required bool compact}) {
    final doc = GlbDocument.parse(bytes, label: 'target');
    final buffers = (doc.json['buffers'] as List?) ?? const [];
    if (buffers.length > 1) {
      throw FormatException(
        'target uses ${buffers.length} buffers; only single-buffer GLBs can be merged into',
      );
    }
    final joints = GlbAnimationRetargeter._skeletonNodeIndices(doc.json);
    if (joints.isEmpty) {
      throw const FormatException(
        'target has no skin; there is no skeleton to retarget onto',
      );
    }
    return _RetargetTarget._(doc, _Skeleton(doc), joints, compact);
  }

  final GlbDocument doc;
  final _Skeleton skeleton;
  final Set<int> joints;
  final bool compact;

  final BytesBuilder _bin;
  int _binLength;
  final List<dynamic> _bufferViews;
  final List<dynamic> _accessors;
  final List<dynamic> _animations;
  final _pending = <int, _PendingAnimation>{};
  final _rest = <String, int>{};

  int addAccessor(
    Float32List data,
    String type,
    int count, {
    List<double>? min,
    List<double>? max,
  }) {
    final padding = ((_binLength + 3) & ~3) - _binLength;
    if (padding > 0) _bin.add(Uint8List(padding));
    final offset = _binLength + padding;
    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    _bin.add(Uint8List.fromList(bytes));
    _binLength = offset + bytes.length;
    _bufferViews.add(<String, dynamic>{
      'buffer': 0,
      'byteOffset': offset,
      'byteLength': bytes.length,
    });
    _accessors.add(<String, dynamic>{
      'bufferView': _bufferViews.length - 1,
      'componentType': 5126,
      'count': count,
      'type': type,
      'min': ?min,
      'max': ?max,
    });
    return _accessors.length - 1;
  }

  /// [keys] copies of joint [j]'s rest rotation or translation; shared by
  /// every clip in compact mode.
  int restAccessor(int j, String path, int keys) {
    Float32List data() {
      if (path == 'rotation') {
        final q = skeleton.restR[j];
        return Float32List.fromList([for (var k = 0; k < keys; k++) ...[q.x, q.y, q.z, q.w]]);
      }
      final t = skeleton.restT[j];
      return Float32List.fromList([for (var k = 0; k < keys; k++) ...t]);
    }

    final type = path == 'rotation' ? 'VEC4' : 'VEC3';
    if (!compact) return addAccessor(data(), type, keys);
    return _rest.putIfAbsent('$j/$path/$keys', () => addAccessor(data(), type, keys));
  }

  /// Adds [animation] (replacing one of the same name); returns its index.
  int addAnimation(_PendingAnimation animation) {
    final replaced = _animations.indexWhere((a) => (a as Map)['name'] == animation.name);
    final index = replaced >= 0 ? replaced : _animations.length;
    if (replaced >= 0) {
      _animations[replaced] = animation.toJson();
    } else {
      _animations.add(animation.toJson());
    }
    _pending[index] = animation;
    return index;
  }

  /// Joints an animation that was in the target before moves (a channel
  /// with more than two keys).
  Set<int> _movedByEarlierAnimations() {
    final moved = <int>{};
    for (final (i, a) in _animations.indexed) {
      if (_pending.containsKey(i) || a is! Map) continue;
      final samplers = (a['samplers'] as List?) ?? const [];
      for (final c in (a['channels'] as List?) ?? const []) {
        final node = ((c as Map)['target'] as Map?)?['node'];
        final sampler = c['sampler'];
        if (node is! int || sampler is! int || sampler >= samplers.length) continue;
        final input = (samplers[sampler] as Map)['input'];
        final count = input is int && input < _accessors.length ? (_accessors[input] as Map)['count'] : null;
        if (count is int && count > 2) moved.add(node);
      }
    }
    return moved;
  }

  Uint8List encode() {
    if (compact) {
      // Every bone some clip moves gets a rest channel in the clips that do
      // not, so a clip never inherits the pose the previous one left.
      final moved = {..._movedByEarlierAnimations(), for (final a in _pending.values) ...a.moved};
      final sorted = moved.toList()..sort();
      for (final MapEntry(key: index, value: a) in _pending.entries) {
        for (final j in sorted) {
          if (a.keyed.contains(j) || !joints.contains(j)) continue;
          a.channel(j, 'rotation', a.constInput, restAccessor(j, 'rotation', a.constKeys));
          a.channel(j, 'translation', a.constInput, restAccessor(j, 'translation', a.constKeys));
        }
        _animations[index] = a.toJson();
      }
    }
    final json = doc.json;
    json['animations'] = _animations;
    json['bufferViews'] = _bufferViews;
    json['accessors'] = _accessors;
    final merged = _bin.takeBytes();
    json['buffers'] = [
      <String, dynamic>{'byteLength': merged.length},
    ];
    return GlbDocument(json, merged).encode();
  }
}

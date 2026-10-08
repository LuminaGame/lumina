part of '../glb_animation_retargeter.dart';

abstract final class _RetargetOperation {
  static GlbRetargetResult run({
    required Uint8List target,
    required Uint8List clip,
    required String clipName,
    int animationIndex = 0,
  }) {
    final tDoc = GlbDocument.parse(target, label: 'target');
    final cDoc = GlbDocument.parse(clip, label: 'clip');
    final src = _Skeleton(cDoc);
    final tgt = _Skeleton(tDoc);
    final soma = _isSomaClip(cDoc);
    if (soma &&
        (cDoc.json['extras'] as Map?)?['somaReferencePose'] != 'neutral') {
      throw const FormatException(
        'This GEM-X clip has no neutral SOMA reference pose. Generate the motion again with the updated GEM-X exporter.',
      );
    }

    final buffers = (tDoc.json['buffers'] as List?) ?? const [];
    if (buffers.length > 1) {
      throw FormatException(
        'target uses ${buffers.length} buffers; only single-buffer GLBs can be merged into',
      );
    }

    final joints = GlbAnimationRetargeter._skeletonNodeIndices(tDoc.json);
    if (joints.isEmpty) {
      throw const FormatException(
        'target has no skin; there is no skeleton to retarget onto',
      );
    }

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

    // ---- Write the animation into the target GLB.
    final json = tDoc.json;
    final bin = BytesBuilder(copy: false)..add(tDoc.bin);
    var binLength = tDoc.bin.length;
    final bufferViews = (json['bufferViews'] as List?)?.toList() ?? <dynamic>[];
    final accessors = (json['accessors'] as List?)?.toList() ?? <dynamic>[];

    int addAccessor(
      Float32List data,
      String type,
      int count, {
      List<double>? min,
      List<double>? max,
    }) {
      final padding = ((binLength + 3) & ~3) - binLength;
      if (padding > 0) bin.add(Uint8List(padding));
      final offset = binLength + padding;
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      bin.add(Uint8List.fromList(bytes));
      binLength = offset + bytes.length;
      bufferViews.add(<String, dynamic>{
        'buffer': 0,
        'byteOffset': offset,
        'byteLength': bytes.length,
      });
      accessors.add(<String, dynamic>{
        'bufferView': bufferViews.length - 1,
        'componentType': 5126,
        'count': count,
        'type': type,
        'min': ?min,
        'max': ?max,
      });
      return accessors.length - 1;
    }

    final frameInput = addAccessor(
      Float32List.fromList(frames),
      'SCALAR',
      frames.length,
      min: [frames.first],
      max: [frames.last],
    );
    final constTimes = duration > 0 ? [0.0, duration] : [0.0];
    final constInput = addAccessor(
      Float32List.fromList(constTimes),
      'SCALAR',
      constTimes.length,
      min: [constTimes.first],
      max: [constTimes.last],
    );

    final samplers = <Map<String, dynamic>>[];
    final channels = <Map<String, dynamic>>[];
    void channel(int node, String path, int input, int output) {
      samplers.add({
        'input': input,
        'output': output,
        'interpolation': 'LINEAR',
      });
      channels.add({
        'sampler': samplers.length - 1,
        'target': {'node': node, 'path': path},
      });
    }

    final sortedJoints = joints.toList()..sort();
    for (final j in sortedJoints) {
      final name = tgt.names[j] ?? '';
      final isDynamic = hasDynamicChannels.contains(j);

      // Retargeter isolation: do not generate animation tracks for unmapped face or corrective joints
      if (!isDynamic && GlbAnimationRetargeter.isCorrectiveOrFace(name)) {
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
        channel(
          j,
          'rotation',
          frameInput,
          addAccessor(data, 'VEC4', keys.length),
        );
      } else {
        final q = tgt.restR[j];
        final data = Float32List.fromList([
          for (var k = 0; k < constTimes.length; k++) ...[q.x, q.y, q.z, q.w],
        ]);
        channel(
          j,
          'rotation',
          constInput,
          addAccessor(data, 'VEC4', constTimes.length),
        );
      }

      // Translation: only root/pelvis get dynamic sampled translations; other unmapped bones don't need constant channels if isolated
      final sampled = j == pelvisT
          ? pelvisTranslation
          : (j == rootT ? rootTranslation : null);
      if (sampled != null) {
        final data = Float32List(sampled.length * 3);
        for (var k = 0; k < sampled.length; k++) {
          data.setAll(k * 3, sampled[k]);
        }
        channel(
          j,
          'translation',
          frameInput,
          addAccessor(data, 'VEC3', sampled.length),
        );
      } else if (!GlbAnimationRetargeter.isCorrectiveOrFace(name) ||
          isDynamic) {
        final t = tgt.restT[j];
        final data = Float32List.fromList([
          for (var k = 0; k < constTimes.length; k++) ...t,
        ]);
        channel(
          j,
          'translation',
          constInput,
          addAccessor(data, 'VEC3', constTimes.length),
        );
      }
    }

    final existing = ((json['animations'] as List?) ?? const []).toList();
    final replaced = existing.indexWhere((a) => (a as Map)['name'] == clipName);
    final animation = <String, dynamic>{
      'name': clipName,
      'channels': channels,
      'samplers': samplers,
    };
    final int clipIndex;
    if (replaced >= 0) {
      existing[replaced] = animation;
      clipIndex = replaced;
    } else {
      existing.add(animation);
      clipIndex = existing.length - 1;
    }
    json['animations'] = existing;
    json['bufferViews'] = bufferViews;
    json['accessors'] = accessors;
    final merged = bin.takeBytes();
    json['buffers'] = [
      <String, dynamic>{'byteLength': merged.length},
    ];

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
      glb: GlbDocument(json, merged).encode(),
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

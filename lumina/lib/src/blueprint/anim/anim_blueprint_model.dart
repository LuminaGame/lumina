import 'dart:math' as math;

import '../blueprint_model.dart';

/// One axis of a blend space.
class LuminaBlendSpaceAxis {
  final String name;
  final double min;
  final double max;
  const LuminaBlendSpaceAxis(this.name, this.min, this.max);

  Map<String, dynamic> toJson() => {'name': name, 'min': min, 'max': max};
  factory LuminaBlendSpaceAxis.fromJson(Map<String, dynamic> j) => LuminaBlendSpaceAxis(
      j['name'] as String? ?? '', (j['min'] as num?)?.toDouble() ?? 0.0, (j['max'] as num?)?.toDouble() ?? 1.0);
}

/// A clip placed in a blend space at ([x], [y]).
class LuminaBlendSpaceSample {
  final String clip;
  final double x;
  final double y;
  const LuminaBlendSpaceSample(this.clip, this.x, [this.y = 0.0]);

  Map<String, dynamic> toJson() => {'clip': clip, 'x': x, 'y': y};
  factory LuminaBlendSpaceSample.fromJson(Map<String, dynamic> j) =>
      LuminaBlendSpaceSample(j['clip'] as String? ?? '', (j['x'] as num?)?.toDouble() ?? 0.0, (j['y'] as num?)?.toDouble() ?? 0.0);
}

/// A 1D or 2D blend space asset (`blend_space` `.lmas` payload).
class LuminaBlendSpaceDocument {
  final List<LuminaBlendSpaceAxis> axes;
  final List<LuminaBlendSpaceSample> samples;
  const LuminaBlendSpaceDocument({required this.axes, required this.samples});

  /// The sample nearest to ([x], [y]) with each axis normalised to its range.
  /// gltfio blends exactly two clips, so the nearest sample plus a crossfade
  /// is what plays. An exact tie goes to the sample farther from the origin,
  /// which matches the locomotion driver's rounding of 45° sectors.
  LuminaBlendSpaceSample? nearest(double x, [double y = 0.0]) {
    LuminaBlendSpaceSample? best;
    var bestDistance = double.infinity;
    var bestMagnitude = -1.0;
    final spanX = axes.isNotEmpty ? (axes[0].max - axes[0].min).abs() : 1.0;
    final spanY = axes.length > 1 ? (axes[1].max - axes[1].min).abs() : 1.0;
    for (final s in samples) {
      final dx = (x - s.x) / (spanX == 0 ? 1 : spanX);
      final dy = axes.length > 1 ? (y - s.y) / (spanY == 0 ? 1 : spanY) : 0.0;
      final d = dx * dx + dy * dy;
      final magnitude = s.x.abs() + s.y.abs();
      if (d < bestDistance || (d == bestDistance && magnitude > bestMagnitude)) {
        best = s;
        bestDistance = d;
        bestMagnitude = magnitude;
      }
    }
    return best;
  }

  bool containsClip(String? clip) => clip != null && samples.any((s) => s.clip == clip);

  /// The distinct Y values the samples sit on, ascending: a 2D space's rows
  /// (e.g. the walk row and the jog row on the Speed axis); one row
  /// for a 1D space.
  List<double> get rows => ({for (final s in samples) axes.length > 1 ? s.y : 0.0}.toList()..sort());

  /// The samples ([x], [y]) blends and their weights, summing
  /// to 1: along X the two samples of a row around [x] share it linearly
  /// (clamped to the row's ends — `BS_Walk` / `BS_Locomotion` repeat
  /// backward at ±180 so the direction ring wraps), and in a 2D space the
  /// two rows around [y] share it linearly too (bilinear; clamped to the
  /// first and last row). Zero weights are left out.
  List<(LuminaBlendSpaceSample, double)> weightedSamples(double x, [double y = 0.0]) {
    if (samples.isEmpty) return const [];
    final rowValues = rows;
    final twoD = axes.length > 1;
    final yc = twoD ? y.clamp(rowValues.first, rowValues.last).toDouble() : 0.0;
    var r0 = 0;
    while (r0 < rowValues.length - 1 && rowValues[r0 + 1] <= yc) {
      r0++;
    }
    final r1 = math.min(r0 + 1, rowValues.length - 1);
    final ty = r1 == r0 || rowValues[r1] == rowValues[r0] ? 0.0 : (yc - rowValues[r0]) / (rowValues[r1] - rowValues[r0]);
    final out = <(LuminaBlendSpaceSample, double)>[];
    void row(double rowY, double weight) {
      if (weight <= 0.0) return;
      final inRow = [for (final s in samples) if (!twoD || s.y == rowY) s]..sort((a, b) => a.x.compareTo(b.x));
      if (inRow.isEmpty) return;
      final xc = x.clamp(inRow.first.x, inRow.last.x).toDouble();
      var i = 0;
      while (i < inRow.length - 2 && inRow[i + 1].x <= xc) {
        i++;
      }
      if (inRow.length == 1) {
        out.add((inRow.first, weight));
        return;
      }
      final a = inRow[i], b = inRow[i + 1];
      final tx = b.x == a.x ? 0.0 : ((xc - a.x) / (b.x - a.x)).clamp(0.0, 1.0);
      if (tx < 1.0) out.add((a, weight * (1.0 - tx)));
      if (tx > 0.0) out.add((b, weight * tx));
    }

    row(rowValues[r0], 1.0 - ty);
    if (r1 != r0) row(rowValues[r1], ty);
    return out;
  }

  /// [weightedSamples] summed per clip.
  Map<String, double> weights(double x, [double y = 0.0]) {
    final out = <String, double>{};
    for (final (s, w) in weightedSamples(x, y)) {
      out[s.clip] = (out[s.clip] ?? 0.0) + w;
    }
    return out;
  }

  /// The sample with the largest weight at ([x], [y]) — what plays, since
  /// gltfio blends exactly two clips (a crossfade) rather than four. A tie
  /// goes to the sample farther from the origin, as in [nearest].
  LuminaBlendSpaceSample? dominant(double x, [double y = 0.0]) {
    LuminaBlendSpaceSample? best;
    var bestWeight = -1.0;
    for (final (s, w) in weightedSamples(x, y)) {
      final better = w > bestWeight + 1e-9 ||
          ((w - bestWeight).abs() <= 1e-9 && best != null && s.x.abs() + s.y.abs() > best.x.abs() + best.y.abs());
      if (better) {
        best = s;
        bestWeight = w;
      }
    }
    return best;
  }

  Map<String, dynamic> toJson() => {
        'axes': axes.map((a) => a.toJson()).toList(),
        'samples': samples.map((s) => s.toJson()).toList(),
      };

  factory LuminaBlendSpaceDocument.fromJson(Map<String, dynamic> j) => LuminaBlendSpaceDocument(
        axes: (j['axes'] as List? ?? const []).map((a) => LuminaBlendSpaceAxis.fromJson(Map<String, dynamic>.from(a as Map))).toList(),
        samples: (j['samples'] as List? ?? const [])
            .map((s) => LuminaBlendSpaceSample.fromJson(Map<String, dynamic>.from(s as Map)))
            .toList(),
      );
}

enum LuminaAnimPoseKind { clip, blendSpace, hold }

/// What a state plays: a clip (or one clip picked at random from a set when
/// the state is entered), a blend space sampled by variables (with a play
/// rate from a speed variable), or the current pose held still.
///
/// A clip pose may play once ([loop] false — the last frame holds until the
/// state is left; the instance reports it in its `ClipFinished` variable),
/// turn the mesh by [rootYawDegrees] over the clip's length (turn-in-place
/// clips whose root motion was stripped), and [plantsFeet]: while such a
/// state plays, the mesh keeps facing where it was when the pawn's yaw
/// changes, and the instance's `RootYawOffset` variable accumulates the
/// difference for the transition rules (the root yaw offset).
class LuminaAnimPose {
  final LuminaAnimPoseKind kind;
  final String? clip;

  /// The clips a random pose picks from on state entry; empty for a single
  /// clip. [clip] is then the first of them.
  final List<String> clips;
  final String? blendSpace;
  final String? xVariable;
  final String? yVariable;
  final double rate;
  final String? rateVariable;
  final double rateReference;
  final double minRate;
  final double maxRate;

  /// A 2D blend space's play rate follows the speed row of the sample that
  /// plays: [rateVariable] over that sample's Y (the walk row
  /// 250, the jog row 480) instead of the single [rateReference], so both
  /// the walk and the jog keep their feet planted.
  final bool rateRows;
  final bool loop;
  final double rootYawDegrees;
  final bool plantsFeet;

  const LuminaAnimPose.clip(
    String this.clip, {
    this.rate = 1.0,
    this.loop = true,
    this.rootYawDegrees = 0.0,
    this.plantsFeet = false,
  })  : kind = LuminaAnimPoseKind.clip,
        clips = const [],
        blendSpace = null,
        xVariable = null,
        yVariable = null,
        rateVariable = null,
        rateReference = 1.0,
        minRate = 0.0,
        maxRate = 10.0,
        rateRows = false;

  /// One of [clips], chosen when the state is entered (idle breaks). Plays
  /// once by default.
  LuminaAnimPose.randomClip(
    List<String> clips, {
    this.rate = 1.0,
    this.loop = false,
    this.rootYawDegrees = 0.0,
    this.plantsFeet = false,
  })  : kind = LuminaAnimPoseKind.clip,
        clips = List.unmodifiable(clips),
        clip = clips.isEmpty ? '' : clips.first,
        blendSpace = null,
        xVariable = null,
        yVariable = null,
        rateVariable = null,
        rateReference = 1.0,
        minRate = 0.0,
        maxRate = 10.0,
        rateRows = false;

  const LuminaAnimPose.blendSpace(
    String this.blendSpace, {
    required String this.xVariable,
    this.yVariable,
    this.rate = 1.0,
    this.rateVariable,
    this.rateReference = 1.0,
    this.minRate = 0.0,
    this.maxRate = 10.0,
    this.rateRows = false,
  })  : kind = LuminaAnimPoseKind.blendSpace,
        clip = null,
        clips = const [],
        loop = true,
        rootYawDegrees = 0.0,
        plantsFeet = false;

  const LuminaAnimPose.hold()
      : kind = LuminaAnimPoseKind.hold,
        clip = null,
        clips = const [],
        blendSpace = null,
        xVariable = null,
        yVariable = null,
        rate = 0.0,
        rateVariable = null,
        rateReference = 1.0,
        minRate = 0.0,
        maxRate = 0.0,
        rateRows = false,
        loop = true,
        rootYawDegrees = 0.0,
        plantsFeet = false;

  /// Whether this is a clip pose that picks among several clips.
  bool get isRandom => clips.length > 1;

  /// The clips this pose can play: the random set, or the single clip.
  List<String> get candidates => clips.isNotEmpty ? clips : (clip == null ? const [] : [clip!]);

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        if (clip != null) 'clip': clip,
        if (clips.isNotEmpty) 'clips': clips,
        if (blendSpace != null) 'blendSpace': blendSpace,
        if (xVariable != null) 'x': xVariable,
        if (yVariable != null) 'y': yVariable,
        'rate': rate,
        if (rateVariable != null) 'rateVariable': rateVariable,
        if (rateVariable != null) 'rateReference': rateReference,
        if (rateVariable != null) 'minRate': minRate,
        if (rateVariable != null) 'maxRate': maxRate,
        if (rateRows) 'rateRows': true,
        if (kind == LuminaAnimPoseKind.clip) 'loop': loop,
        if (kind == LuminaAnimPoseKind.clip) 'rootYawDegrees': rootYawDegrees,
        if (kind == LuminaAnimPoseKind.clip) 'plantsFeet': plantsFeet,
      };

  factory LuminaAnimPose.fromJson(Map<String, dynamic> j) {
    switch (j['kind']) {
      case 'clip':
        final clips = (j['clips'] as List?)?.cast<String>() ?? const <String>[];
        final rate = (j['rate'] as num?)?.toDouble() ?? 1.0;
        final rootYaw = (j['rootYawDegrees'] as num?)?.toDouble() ?? 0.0;
        final plantsFeet = j['plantsFeet'] as bool? ?? false;
        if (clips.isNotEmpty) {
          return LuminaAnimPose.randomClip(clips,
              rate: rate, loop: j['loop'] as bool? ?? false, rootYawDegrees: rootYaw, plantsFeet: plantsFeet);
        }
        return LuminaAnimPose.clip(j['clip'] as String? ?? '',
            rate: rate, loop: j['loop'] as bool? ?? true, rootYawDegrees: rootYaw, plantsFeet: plantsFeet);
      case 'blendSpace':
        return LuminaAnimPose.blendSpace(
          j['blendSpace'] as String? ?? '',
          xVariable: j['x'] as String? ?? '',
          yVariable: j['y'] as String?,
          rate: (j['rate'] as num?)?.toDouble() ?? 1.0,
          rateVariable: j['rateVariable'] as String?,
          rateReference: (j['rateReference'] as num?)?.toDouble() ?? 1.0,
          minRate: (j['minRate'] as num?)?.toDouble() ?? 0.0,
          maxRate: (j['maxRate'] as num?)?.toDouble() ?? 10.0,
          rateRows: j['rateRows'] as bool? ?? false,
        );
      default:
        return const LuminaAnimPose.hold();
    }
  }
}

/// A state of the state machine and where the editor draws it.
class LuminaAnimState {
  final String name;
  final LuminaAnimPose pose;
  final double x;
  final double y;
  const LuminaAnimState(this.name, this.pose, {this.x = 0.0, this.y = 0.0});

  Map<String, dynamic> toJson() => {'name': name, 'pose': pose.toJson(), 'x': x, 'y': y};
  factory LuminaAnimState.fromJson(Map<String, dynamic> j) => LuminaAnimState(
        j['name'] as String? ?? '',
        LuminaAnimPose.fromJson(Map<String, dynamic>.from(j['pose'] as Map? ?? const {})),
        x: (j['x'] as num?)?.toDouble() ?? 0.0,
        y: (j['y'] as num?)?.toDouble() ?? 0.0,
      );
}

/// A transition arrow: taken when its rule graph's Result is true, the state
/// has been active for at least [minStateTime] seconds and — with
/// [automaticRule] (an automatic rule based on the state's sequence
/// player) — the state's one-shot clip has finished. Lower [priority] is
/// checked first.
class LuminaAnimTransition {
  final String id;
  final String from;
  final String to;
  final double blendDuration;
  final int priority;
  final double minStateTime;
  final bool automaticRule;

  /// A pure graph over the Animation Blueprint's variables ending in one
  /// `transition_result` node.
  final LuminaBlueprintGraph rule;

  LuminaAnimTransition({
    required this.id,
    required this.from,
    required this.to,
    this.blendDuration = 0.2,
    this.priority = 0,
    this.minStateTime = 0.0,
    this.automaticRule = false,
    LuminaBlueprintGraph? rule,
  }) : rule = rule ?? LuminaBlueprintGraph();

  /// The rule's `transition_result` node.
  LuminaBlueprintNode? get resultNode =>
      rule.nodes.where((n) => n.registryId == 'transition_result').firstOrNull;

  Map<String, dynamic> toJson() => {
        'id': id,
        'from': from,
        'to': to,
        'blendDuration': blendDuration,
        'priority': priority,
        'minStateTime': minStateTime,
        'automaticRule': automaticRule,
        'rule': rule.toJson(),
      };

  factory LuminaAnimTransition.fromJson(Map<String, dynamic> j) => LuminaAnimTransition(
        id: j['id'] as String? ?? '',
        from: j['from'] as String? ?? '',
        to: j['to'] as String? ?? '',
        blendDuration: (j['blendDuration'] as num?)?.toDouble() ?? 0.2,
        priority: (j['priority'] as num?)?.toInt() ?? 0,
        minStateTime: (j['minStateTime'] as num?)?.toDouble() ?? 0.0,
        automaticRule: j['automaticRule'] as bool? ?? false,
        rule: LuminaBlueprintGraph.fromJson(j['rule'] == null ? null : Map<String, dynamic>.from(j['rule'] as Map)),
      );
}

/// The AnimGraph's state machine (e.g. "Locomotion").
class LuminaAnimStateMachine {
  final String name;
  final String entryState;
  final List<LuminaAnimState> states;
  final List<LuminaAnimTransition> transitions;

  /// Seconds a change of blend-space sample blends over.
  final double sampleCrossFade;

  LuminaAnimStateMachine({
    required this.name,
    required this.entryState,
    required this.states,
    required this.transitions,
    this.sampleCrossFade = 0.2,
  });

  LuminaAnimState? state(String name) => states.where((s) => s.name == name).firstOrNull;

  /// Transitions leaving [state], in the order they are checked.
  List<LuminaAnimTransition> transitionsFrom(String state) =>
      transitions.where((t) => t.from == state).toList()..sort((a, b) => a.priority.compareTo(b.priority));

  Map<String, dynamic> toJson() => {
        'name': name,
        'entryState': entryState,
        'sampleCrossFade': sampleCrossFade,
        'states': states.map((s) => s.toJson()).toList(),
        'transitions': transitions.map((t) => t.toJson()).toList(),
      };

  factory LuminaAnimStateMachine.fromJson(Map<String, dynamic> j) => LuminaAnimStateMachine(
        name: j['name'] as String? ?? 'Locomotion',
        entryState: j['entryState'] as String? ?? '',
        sampleCrossFade: (j['sampleCrossFade'] as num?)?.toDouble() ?? 0.2,
        states: (j['states'] as List? ?? const []).map((s) => LuminaAnimState.fromJson(Map<String, dynamic>.from(s as Map))).toList(),
        transitions: (j['transitions'] as List? ?? const [])
            .map((t) => LuminaAnimTransition.fromJson(Map<String, dynamic>.from(t as Map)))
            .toList(),
      );
}

/// One bone of an aim offset and its share of the aim.
class LuminaAnimAimOffsetBone {
  final String name;
  final double weight;
  const LuminaAnimAimOffsetBone(this.name, this.weight);

  Map<String, dynamic> toJson() => {'name': name, 'weight': weight};
  factory LuminaAnimAimOffsetBone.fromJson(Map<String, dynamic> j) =>
      LuminaAnimAimOffsetBone(j['name'] as String? ?? '', (j['weight'] as num?)?.toDouble() ?? 0.0);
}

/// An Aim Offset on a bone chain: every update the
/// instance clamps the [yawVariable] / [pitchVariable] values to ±[maxYaw] /
/// ±[maxPitch], interpolates toward them at [interpSpeed] (exponential, per
/// second) and turns each of [bones] by its [LuminaAnimAimOffsetBone.weight]
/// share through a joint override, on top of the playing clip. The default
/// chain is `spine_03` / `neck_01` / `head`.
class LuminaAnimAimOffset {
  static const List<LuminaAnimAimOffsetBone> defaultBones = [
    LuminaAnimAimOffsetBone('spine_03', 0.15),
    LuminaAnimAimOffsetBone('neck_01', 0.25),
    LuminaAnimAimOffsetBone('head', 0.6),
  ];

  final List<LuminaAnimAimOffsetBone> bones;
  final String yawVariable;
  final String pitchVariable;
  final double maxYaw;
  final double maxPitch;
  final double interpSpeed;

  const LuminaAnimAimOffset({
    this.bones = defaultBones,
    this.yawVariable = 'AimYaw',
    this.pitchVariable = 'AimPitch',
    this.maxYaw = 80.0,
    this.maxPitch = 45.0,
    this.interpSpeed = 10.0,
  });

  Map<String, dynamic> toJson() => {
        'bones': bones.map((b) => b.toJson()).toList(),
        'yawVariable': yawVariable,
        'pitchVariable': pitchVariable,
        'maxYaw': maxYaw,
        'maxPitch': maxPitch,
        'interpSpeed': interpSpeed,
      };

  factory LuminaAnimAimOffset.fromJson(Map<String, dynamic> j) => LuminaAnimAimOffset(
        bones: (j['bones'] as List? ?? const [])
            .map((b) => LuminaAnimAimOffsetBone.fromJson(Map<String, dynamic>.from(b as Map)))
            .toList(),
        yawVariable: j['yawVariable'] as String? ?? 'AimYaw',
        pitchVariable: j['pitchVariable'] as String? ?? 'AimPitch',
        maxYaw: (j['maxYaw'] as num?)?.toDouble() ?? 80.0,
        maxPitch: (j['maxPitch'] as num?)?.toDouble() ?? 45.0,
        interpSpeed: (j['interpSpeed'] as num?)?.toDouble() ?? 10.0,
      );
}

/// An Animation Blueprint (`anim_blueprint` `.lmas` payload): the mesh it
/// animates, its variables, the update event graph and the AnimGraph's state
/// machine.
class LuminaAnimBlueprintDocument {
  final String targetMesh;
  final List<LuminaBlueprintVariable> variables;
  final LuminaBlueprintGraph eventGraph;
  final List<LuminaAnimStateMachine> stateMachines;

  /// Yaw from the mesh's authored forward to +Z (glTF faces +Z: 0).
  final double meshYawOffsetDegrees;

  /// The aim offset layered over the state machine's pose, if any.
  final LuminaAnimAimOffset? aimOffset;

  LuminaAnimBlueprintDocument({
    this.targetMesh = '',
    List<LuminaBlueprintVariable>? variables,
    LuminaBlueprintGraph? eventGraph,
    List<LuminaAnimStateMachine>? stateMachines,
    this.meshYawOffsetDegrees = 0.0,
    this.aimOffset,
  })  : variables = variables ?? <LuminaBlueprintVariable>[],
        eventGraph = eventGraph ?? LuminaBlueprintGraph(),
        stateMachines = stateMachines ?? <LuminaAnimStateMachine>[];

  LuminaAnimBlueprintDocument copyWith({
    String? targetMesh,
    List<LuminaBlueprintVariable>? variables,
    LuminaBlueprintGraph? eventGraph,
    List<LuminaAnimStateMachine>? stateMachines,
    double? meshYawOffsetDegrees,
    LuminaAnimAimOffset? aimOffset,
  }) =>
      LuminaAnimBlueprintDocument(
        targetMesh: targetMesh ?? this.targetMesh,
        variables: variables ?? this.variables,
        eventGraph: eventGraph ?? this.eventGraph,
        stateMachines: stateMachines ?? this.stateMachines,
        meshYawOffsetDegrees: meshYawOffsetDegrees ?? this.meshYawOffsetDegrees,
        aimOffset: aimOffset ?? this.aimOffset,
      );

  /// The AnimGraph's output state machine.
  LuminaAnimStateMachine? get stateMachine => stateMachines.firstOrNull;

  /// The update graph and variables as a plain Blueprint document, so the
  /// Blueprint validator and code generator treat it like any other graph.
  LuminaBlueprintDocument get updateDocument =>
      LuminaBlueprintDocument(parentClass: 'LuminaAnimInstance', eventGraph: eventGraph, variables: variables);

  Map<String, dynamic> toJson() => {
        'targetMesh': targetMesh,
        'meshYawOffsetDegrees': meshYawOffsetDegrees,
        'variables': variables.map((v) => v.toJson()).toList(),
        'eventGraph': eventGraph.toJson(),
        'stateMachines': stateMachines.map((m) => m.toJson()).toList(),
        if (aimOffset != null) 'aimOffset': aimOffset!.toJson(),
      };

  factory LuminaAnimBlueprintDocument.fromJson(Map<String, dynamic> j) => LuminaAnimBlueprintDocument(
        targetMesh: j['targetMesh'] as String? ?? '',
        meshYawOffsetDegrees: (j['meshYawOffsetDegrees'] as num?)?.toDouble() ?? 0.0,
        aimOffset: j['aimOffset'] is Map ? LuminaAnimAimOffset.fromJson(Map<String, dynamic>.from(j['aimOffset'] as Map)) : null,
        variables: (j['variables'] as List? ?? const [])
            .map((v) => LuminaBlueprintVariable.fromJson(Map<String, dynamic>.from(v as Map)))
            .toList(),
        eventGraph: LuminaBlueprintGraph.fromJson(j['eventGraph'] == null ? null : Map<String, dynamic>.from(j['eventGraph'] as Map)),
        stateMachines: (j['stateMachines'] as List? ?? const [])
            .map((m) => LuminaAnimStateMachine.fromJson(Map<String, dynamic>.from(m as Map)))
            .toList(),
      );
}

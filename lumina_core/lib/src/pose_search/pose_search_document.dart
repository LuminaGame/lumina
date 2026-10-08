/// A bone whose character-space position and velocity are pose features of a
/// pose search database, each with its own weight (0 leaves it out).
class LuminaPoseSearchBone {
  final String name;
  final double position;
  final double velocity;

  const LuminaPoseSearchBone(this.name, {this.position = 1.0, this.velocity = 1.0});

  Map<String, dynamic> toJson() => {'name': name, 'position': position, 'velocity': velocity};

  factory LuminaPoseSearchBone.fromJson(Map<String, dynamic> j) => LuminaPoseSearchBone(
        j['name'] as String? ?? '',
        position: (j['position'] as num?)?.toDouble() ?? 1.0,
        velocity: (j['velocity'] as num?)?.toDouble() ?? 1.0,
      );

  @override
  bool operator ==(Object other) =>
      other is LuminaPoseSearchBone && other.name == name && other.position == position && other.velocity == velocity;

  @override
  int get hashCode => Object.hash(name, position, velocity);
}

/// What a pose search database compares: the root trajectory at
/// [trajectoryTimes] (seconds relative to the frame; negative = past) as
/// positions and facing directions on the ground, and the [bones]' positions
/// and velocities, all in the character's own frame (forward +Z, up +Y,
/// lateral X, the mesh's model units). Frames are sampled at [sampleRate].
class LuminaPoseSearchSchema {
  static const List<double> defaultTrajectoryTimes = [-0.33, 0.33, 0.67, 1.0];
  static const List<LuminaPoseSearchBone> defaultBones = [
    LuminaPoseSearchBone('foot_l', position: 1.0, velocity: 1.0),
    LuminaPoseSearchBone('foot_r', position: 1.0, velocity: 1.0),
    LuminaPoseSearchBone('pelvis', position: 0.0, velocity: 1.0),
  ];

  final double sampleRate;
  final List<double> trajectoryTimes;
  final double trajectoryPositionWeight;
  final double trajectoryFacingWeight;
  final List<LuminaPoseSearchBone> bones;

  /// The bone whose ground projection and facing define the character frame
  /// (its root motion); empty picks the skin's topmost joint.
  final String rootBone;

  /// Yaw from the mesh's authored forward to glTF +Z (0 for a mesh facing +Z),
  /// as an Animation Blueprint's `meshYawOffsetDegrees`.
  final double meshYawOffsetDegrees;

  const LuminaPoseSearchSchema({
    this.sampleRate = 30.0,
    this.trajectoryTimes = defaultTrajectoryTimes,
    this.trajectoryPositionWeight = 1.0,
    this.trajectoryFacingWeight = 1.0,
    this.bones = defaultBones,
    this.rootBone = '',
    this.meshYawOffsetDegrees = 0.0,
  });

  LuminaPoseSearchSchema copyWith({
    double? sampleRate,
    List<double>? trajectoryTimes,
    double? trajectoryPositionWeight,
    double? trajectoryFacingWeight,
    List<LuminaPoseSearchBone>? bones,
    String? rootBone,
    double? meshYawOffsetDegrees,
  }) =>
      LuminaPoseSearchSchema(
        sampleRate: sampleRate ?? this.sampleRate,
        trajectoryTimes: trajectoryTimes ?? this.trajectoryTimes,
        trajectoryPositionWeight: trajectoryPositionWeight ?? this.trajectoryPositionWeight,
        trajectoryFacingWeight: trajectoryFacingWeight ?? this.trajectoryFacingWeight,
        bones: bones ?? this.bones,
        rootBone: rootBone ?? this.rootBone,
        meshYawOffsetDegrees: meshYawOffsetDegrees ?? this.meshYawOffsetDegrees,
      );

  Map<String, dynamic> toJson() => {
        'sampleRate': sampleRate,
        'trajectoryTimes': trajectoryTimes,
        'trajectoryPositionWeight': trajectoryPositionWeight,
        'trajectoryFacingWeight': trajectoryFacingWeight,
        'bones': bones.map((b) => b.toJson()).toList(),
        'rootBone': rootBone,
        'meshYawOffsetDegrees': meshYawOffsetDegrees,
      };

  factory LuminaPoseSearchSchema.fromJson(Map<String, dynamic> j) => LuminaPoseSearchSchema(
        sampleRate: (j['sampleRate'] as num?)?.toDouble() ?? 30.0,
        trajectoryTimes: (j['trajectoryTimes'] as List?)?.map((v) => (v as num).toDouble()).toList() ?? defaultTrajectoryTimes,
        trajectoryPositionWeight: (j['trajectoryPositionWeight'] as num?)?.toDouble() ?? 1.0,
        trajectoryFacingWeight: (j['trajectoryFacingWeight'] as num?)?.toDouble() ?? 1.0,
        bones: (j['bones'] as List?)
                ?.map((b) => LuminaPoseSearchBone.fromJson(Map<String, dynamic>.from(b as Map)))
                .toList() ??
            defaultBones,
        rootBone: j['rootBone'] as String? ?? '',
        meshYawOffsetDegrees: (j['meshYawOffsetDegrees'] as num?)?.toDouble() ?? 0.0,
      );
}

/// A clip of the target mesh's GLB in a pose search database: whether it
/// loops (its trajectory wraps), whether a mirrored copy is searched too, its
/// tags (a search can require tags, e.g. `crouch`) and whether it is used.
class LuminaPoseSearchClip {
  final String clip;
  final bool loop;
  final bool mirror;
  final List<String> tags;
  final bool enabled;

  /// Added to the cost of this clip's frames (negative favours the clip).
  final double costBias;

  /// Only frames between these times (seconds; an end of 0 = the clip's
  /// end) can be jumped to; the rest still plays on (a start clip searched
  /// only for its first second, then left for a loop).
  final double samplingStart;
  final double samplingEnd;

  const LuminaPoseSearchClip(this.clip,
      {this.loop = false,
      this.mirror = false,
      this.tags = const [],
      this.enabled = true,
      this.costBias = 0.0,
      this.samplingStart = 0.0,
      this.samplingEnd = 0.0});

  LuminaPoseSearchClip copyWith(
          {String? clip,
          bool? loop,
          bool? mirror,
          List<String>? tags,
          bool? enabled,
          double? costBias,
          double? samplingStart,
          double? samplingEnd}) =>
      LuminaPoseSearchClip(
        clip ?? this.clip,
        loop: loop ?? this.loop,
        mirror: mirror ?? this.mirror,
        tags: tags ?? this.tags,
        enabled: enabled ?? this.enabled,
        costBias: costBias ?? this.costBias,
        samplingStart: samplingStart ?? this.samplingStart,
        samplingEnd: samplingEnd ?? this.samplingEnd,
      );

  Map<String, dynamic> toJson() => {
        'clip': clip,
        'loop': loop,
        'mirror': mirror,
        'tags': tags,
        'enabled': enabled,
        'costBias': costBias,
        'samplingStart': samplingStart,
        'samplingEnd': samplingEnd,
      };

  factory LuminaPoseSearchClip.fromJson(Map<String, dynamic> j) => LuminaPoseSearchClip(
        j['clip'] as String? ?? '',
        loop: j['loop'] as bool? ?? false,
        mirror: j['mirror'] as bool? ?? false,
        tags: (j['tags'] as List?)?.cast<String>() ?? const [],
        enabled: j['enabled'] as bool? ?? true,
        costBias: (j['costBias'] as num?)?.toDouble() ?? 0.0,
        samplingStart: (j['samplingStart'] as num?)?.toDouble() ?? 0.0,
        samplingEnd: (j['samplingEnd'] as num?)?.toDouble() ?? 0.0,
      );

  /// A guess from the clip's name: `Loop` / `_Idle` clips loop.
  static bool looksLooping(String clip) {
    final lower = clip.toLowerCase();
    return lower.contains('loop') || lower.endsWith('_idle');
  }
}

/// A pose search database (`poseSearchDatabase` `.lmas` payload): clips of
/// [targetMesh]'s GLB, the [schema] they are compared with, and how a motion
/// matching player searches them: every [searchInterval] seconds, switching
/// only when a frame beats the continuing one by [continuingPoseBias] (a cost
/// in normalized units), blending switches over [blendTime] seconds; the last
/// [excludeEndSeconds] of a one-shot clip are never jumped into. Looping
/// clips' frames cost [loopingCostBias] more (negative favours them).
class LuminaPoseSearchDatabaseDocument {
  final String targetMesh;
  final List<LuminaPoseSearchClip> clips;
  final LuminaPoseSearchSchema schema;
  final double searchInterval;
  final double continuingPoseBias;
  final double blendTime;
  final double excludeEndSeconds;
  final double loopingCostBias;

  const LuminaPoseSearchDatabaseDocument({
    this.targetMesh = '',
    this.clips = const [],
    this.schema = const LuminaPoseSearchSchema(),
    this.searchInterval = 0.1,
    this.continuingPoseBias = 0.05,
    this.blendTime = 0.2,
    this.excludeEndSeconds = 0.3,
    this.loopingCostBias = -0.05,
  });

  /// The enabled clips, in order.
  List<LuminaPoseSearchClip> get enabledClips => [for (final c in clips) if (c.enabled) c];

  /// Every tag used by a clip, sorted.
  List<String> get tags => ({for (final c in clips) ...c.tags}.toList()..sort());

  LuminaPoseSearchDatabaseDocument copyWith({
    String? targetMesh,
    List<LuminaPoseSearchClip>? clips,
    LuminaPoseSearchSchema? schema,
    double? searchInterval,
    double? continuingPoseBias,
    double? blendTime,
    double? excludeEndSeconds,
    double? loopingCostBias,
  }) =>
      LuminaPoseSearchDatabaseDocument(
        targetMesh: targetMesh ?? this.targetMesh,
        clips: clips ?? this.clips,
        schema: schema ?? this.schema,
        searchInterval: searchInterval ?? this.searchInterval,
        continuingPoseBias: continuingPoseBias ?? this.continuingPoseBias,
        blendTime: blendTime ?? this.blendTime,
        excludeEndSeconds: excludeEndSeconds ?? this.excludeEndSeconds,
        loopingCostBias: loopingCostBias ?? this.loopingCostBias,
      );

  Map<String, dynamic> toJson() => {
        'targetMesh': targetMesh,
        'clips': clips.map((c) => c.toJson()).toList(),
        'schema': schema.toJson(),
        'searchInterval': searchInterval,
        'continuingPoseBias': continuingPoseBias,
        'blendTime': blendTime,
        'excludeEndSeconds': excludeEndSeconds,
        'loopingCostBias': loopingCostBias,
      };

  factory LuminaPoseSearchDatabaseDocument.fromJson(Map<String, dynamic> j) => LuminaPoseSearchDatabaseDocument(
        targetMesh: j['targetMesh'] as String? ?? '',
        clips: (j['clips'] as List? ?? const [])
            .map((c) => LuminaPoseSearchClip.fromJson(Map<String, dynamic>.from(c as Map)))
            .toList(),
        schema: j['schema'] is Map
            ? LuminaPoseSearchSchema.fromJson(Map<String, dynamic>.from(j['schema'] as Map))
            : const LuminaPoseSearchSchema(),
        searchInterval: (j['searchInterval'] as num?)?.toDouble() ?? 0.1,
        continuingPoseBias: (j['continuingPoseBias'] as num?)?.toDouble() ?? 0.05,
        blendTime: (j['blendTime'] as num?)?.toDouble() ?? 0.2,
        excludeEndSeconds: (j['excludeEndSeconds'] as num?)?.toDouble() ?? 0.3,
        loopingCostBias: (j['loopingCostBias'] as num?)?.toDouble() ?? -0.05,
      );
}

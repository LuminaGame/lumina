import 'collision_filter.dart';

/// Collision presets:
///
/// | Preset            | Object type  | World Static | World Dynamic | Pawn    | Enabled |
/// |-------------------|--------------|--------------|---------------|---------|---------|
/// | NoCollision       | worldStatic  | ignore       | ignore        | ignore  | no      |
/// | BlockAll          | worldStatic  | block        | block         | block   | yes     |
/// | OverlapAll        | worldStatic  | overlap      | overlap       | overlap | yes     |
/// | BlockAllDynamic   | worldDynamic | block        | block         | block   | yes     |
/// | OverlapAllDynamic | worldDynamic | overlap      | overlap       | overlap | yes     |
/// | Pawn              | pawn         | block        | block         | block   | yes     |
/// | Trigger           | worldDynamic | ignore       | overlap       | overlap | yes     |
/// | Custom            | (as set)     | (as set)     | (as set)      | (as set)| (as set)|
///
/// The effective response between two components is the weaker of the two
/// (Ignore < Overlap < Block, [effectiveResponse]).
enum LuminaCollisionPreset {
  noCollision,
  blockAll,
  overlapAll,
  blockAllDynamic,
  overlapAllDynamic,
  pawn,
  trigger,
  custom;

  /// The display name: `BlockAllDynamic`, `NoCollision`, …
  String get displayName => name[0].toUpperCase() + name.substring(1);

  /// Parses `Trigger`, `trigger`, `Block All Dynamic`, `blockAllDynamic`;
  /// null for anything else.
  static LuminaCollisionPreset? parse(String? s) {
    if (s == null) return null;
    final key = s.replaceAll(RegExp(r'[\s_-]'), '').toLowerCase();
    for (final p in values) {
      if (p.name.toLowerCase() == key) return p;
    }
    return null;
  }
}

/// Parses a channel / object type name (`WorldStatic`, `worldDynamic`,
/// `Pawn`, `World Static`); null for anything else.
CollisionObjectType? luminaParseCollisionObjectType(String? s) {
  if (s == null) return null;
  final key = s.replaceAll(RegExp(r'[\s_-]'), '').toLowerCase();
  for (final t in CollisionObjectType.values) {
    if (t.name.toLowerCase() == key) return t;
  }
  return null;
}

/// Parses a response name (`Ignore`, `overlap`, `Block`); null otherwise.
CollisionResponse? luminaParseCollisionResponse(String? s) {
  if (s == null) return null;
  final key = s.trim().toLowerCase();
  for (final r in CollisionResponse.values) {
    if (r.name == key) return r;
  }
  return null;
}

/// The display name of a channel: `WorldStatic`, `WorldDynamic`, `Pawn`.
String luminaCollisionObjectTypeName(CollisionObjectType t) => t.name[0].toUpperCase() + t.name.substring(1);

/// The display name of a response: `Ignore`, `Overlap`, `Block`.
String luminaCollisionResponseName(CollisionResponse r) => r.name[0].toUpperCase() + r.name.substring(1);

/// A collision component's whole collision setup: what it is, how it answers
/// each channel, whether it raises overlap events and whether it collides at
/// all. Value type; [LuminaCollisionComponent.profile] reads and writes it.
class LuminaCollisionProfile {
  final CollisionObjectType objectType;
  final Map<CollisionObjectType, CollisionResponse> responses;
  final bool generateOverlapEvents;
  final bool collisionEnabled;

  LuminaCollisionProfile({
    this.objectType = CollisionObjectType.worldDynamic,
    Map<CollisionObjectType, CollisionResponse> responses = const {},
    this.generateOverlapEvents = true,
    this.collisionEnabled = true,
  }) : responses = Map.unmodifiable({
          for (final t in CollisionObjectType.values) t: responses[t] ?? CollisionResponse.block,
        });

  /// The profile of [preset] (the table above). [custom] is
  /// `BlockAllDynamic`'s grid: a starting point the user then edits.
  factory LuminaCollisionProfile.forPreset(LuminaCollisionPreset preset, {bool generateOverlapEvents = true}) {
    Map<CollisionObjectType, CollisionResponse> all(CollisionResponse r) =>
        {for (final t in CollisionObjectType.values) t: r};
    switch (preset) {
      case LuminaCollisionPreset.noCollision:
        return LuminaCollisionProfile(
            objectType: CollisionObjectType.worldStatic,
            responses: all(CollisionResponse.ignore),
            generateOverlapEvents: generateOverlapEvents,
            collisionEnabled: false);
      case LuminaCollisionPreset.blockAll:
        return LuminaCollisionProfile(
            objectType: CollisionObjectType.worldStatic,
            responses: all(CollisionResponse.block),
            generateOverlapEvents: generateOverlapEvents);
      case LuminaCollisionPreset.overlapAll:
        return LuminaCollisionProfile(
            objectType: CollisionObjectType.worldStatic,
            responses: all(CollisionResponse.overlap),
            generateOverlapEvents: generateOverlapEvents);
      case LuminaCollisionPreset.blockAllDynamic:
      case LuminaCollisionPreset.custom:
        return LuminaCollisionProfile(
            objectType: CollisionObjectType.worldDynamic,
            responses: all(CollisionResponse.block),
            generateOverlapEvents: generateOverlapEvents);
      case LuminaCollisionPreset.overlapAllDynamic:
        return LuminaCollisionProfile(
            objectType: CollisionObjectType.worldDynamic,
            responses: all(CollisionResponse.overlap),
            generateOverlapEvents: generateOverlapEvents);
      case LuminaCollisionPreset.pawn:
        return LuminaCollisionProfile(
            objectType: CollisionObjectType.pawn,
            responses: all(CollisionResponse.block),
            generateOverlapEvents: generateOverlapEvents);
      case LuminaCollisionPreset.trigger:
        return LuminaCollisionProfile(
          objectType: CollisionObjectType.worldDynamic,
          responses: {
            CollisionObjectType.worldStatic: CollisionResponse.ignore,
            CollisionObjectType.worldDynamic: CollisionResponse.overlap,
            CollisionObjectType.pawn: CollisionResponse.overlap,
          },
          generateOverlapEvents: true,
        );
    }
  }

  /// The preset whose table this profile matches ([generateOverlapEvents]
  /// aside); [LuminaCollisionPreset.custom] when none does. A disabled
  /// profile is [LuminaCollisionPreset.noCollision] whatever its grid.
  LuminaCollisionPreset get preset {
    if (!collisionEnabled) return LuminaCollisionPreset.noCollision;
    for (final p in LuminaCollisionPreset.values) {
      if (p == LuminaCollisionPreset.custom || p == LuminaCollisionPreset.noCollision) continue;
      final table = LuminaCollisionProfile.forPreset(p);
      if (table.objectType == objectType &&
          CollisionObjectType.values.every((t) => table.responses[t] == responses[t])) {
        return p;
      }
    }
    return LuminaCollisionPreset.custom;
  }

  LuminaCollisionProfile copyWith({
    CollisionObjectType? objectType,
    Map<CollisionObjectType, CollisionResponse>? responses,
    bool? generateOverlapEvents,
    bool? collisionEnabled,
  }) =>
      LuminaCollisionProfile(
        objectType: objectType ?? this.objectType,
        responses: responses ?? this.responses,
        generateOverlapEvents: generateOverlapEvents ?? this.generateOverlapEvents,
        collisionEnabled: collisionEnabled ?? this.collisionEnabled,
      );

  /// The editor's / Blueprint component's collision JSON:
  /// `{'preset', 'objectType', 'responses': {'worldStatic': 'block', …},
  /// 'generateOverlapEvents', 'collisionEnabled'}`.
  Map<String, dynamic> toJson() => {
        'preset': preset.name,
        'objectType': objectType.name,
        'responses': {for (final t in CollisionObjectType.values) t.name: responses[t]!.name},
        'generateOverlapEvents': generateOverlapEvents,
        'collisionEnabled': collisionEnabled,
      };

  /// Reads [toJson]'s shape, on top of [base] (this component's current
  /// setup). A `preset` other than `custom` fills the grid first; explicit
  /// `objectType` / `responses` / `generateOverlapEvents` / `collisionEnabled`
  /// keys then win, so a custom grid round-trips exactly. Keys the map lacks
  /// keep [base]'s values.
  static LuminaCollisionProfile fromJson(Map<String, dynamic> json, {LuminaCollisionProfile? base}) {
    var p = base ?? LuminaCollisionProfile();
    final preset = LuminaCollisionPreset.parse(json['preset'] as String?);
    if (preset != null && preset != LuminaCollisionPreset.custom) {
      p = LuminaCollisionProfile.forPreset(preset, generateOverlapEvents: p.generateOverlapEvents);
    }
    final objectType = luminaParseCollisionObjectType(json['objectType'] as String?);
    final responses = json['responses'];
    final grid = Map<CollisionObjectType, CollisionResponse>.from(p.responses);
    if (responses is Map) {
      responses.forEach((k, v) {
        final t = luminaParseCollisionObjectType('$k');
        final r = luminaParseCollisionResponse(v is String ? v : null);
        if (t != null && r != null) grid[t] = r;
      });
    }
    return p.copyWith(
      objectType: objectType,
      responses: grid,
      generateOverlapEvents: json['generateOverlapEvents'] is bool ? json['generateOverlapEvents'] as bool : null,
      collisionEnabled: json['collisionEnabled'] is bool ? json['collisionEnabled'] as bool : null,
    );
  }

  /// Whether [json] carries any of the collision keys.
  static bool hasCollisionKeys(Map<String, dynamic> json) =>
      const ['preset', 'objectType', 'responses', 'generateOverlapEvents', 'collisionEnabled'].any(json.containsKey);

  @override
  bool operator ==(Object other) =>
      other is LuminaCollisionProfile &&
      other.objectType == objectType &&
      other.generateOverlapEvents == generateOverlapEvents &&
      other.collisionEnabled == collisionEnabled &&
      CollisionObjectType.values.every((t) => other.responses[t] == responses[t]);

  @override
  int get hashCode => Object.hash(objectType, generateOverlapEvents, collisionEnabled,
      Object.hashAll([for (final t in CollisionObjectType.values) responses[t]]));

  @override
  String toString() => 'LuminaCollisionProfile(${preset.displayName}, ${objectType.name}, '
      '${CollisionObjectType.values.map((t) => '${t.name}=${responses[t]!.name}').join(' ')}, '
      'events=$generateOverlapEvents, enabled=$collisionEnabled)';
}

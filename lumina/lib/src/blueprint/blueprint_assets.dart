import 'dart:convert';

import '../components/particles/particle_emitter_config.dart';
import '../save/save_game.dart';
import 'blueprint_model.dart';

/// A Blueprint save-game class asset: the `.lmas` payload
/// `{"kind": "savegame", "name": …, "fields": […]}`. `Create Save Game
/// Object` makes a [LuminaBlueprintSaveGame] of it; `Set / Get Save Field`
/// type their pins from [fields].
class LuminaBlueprintSaveGameDocument {
  static const String kind = 'savegame';
  final String name;
  final List<LuminaBlueprintVariable> fields;

  const LuminaBlueprintSaveGameDocument({required this.name, this.fields = const []});

  LuminaBlueprintVariable? field(String? name) {
    for (final f in fields) {
      if (f.name == name) return f;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {'kind': kind, 'name': name, 'fields': fields.map((f) => f.toJson()).toList()};

  factory LuminaBlueprintSaveGameDocument.fromJson(Map<String, dynamic> map) => LuminaBlueprintSaveGameDocument(
        name: map['name'] as String? ?? '',
        fields: [for (final f in map['fields'] as List? ?? const []) LuminaBlueprintVariable.fromJson(Map<String, dynamic>.from(f as Map))],
      );

  String toFormattedJson() => const JsonEncoder.withIndent('  ').convert(toJson());
}

/// The project's save-game classes; the editor and the
/// generated `main()` fill it. Registering also registers the class with
/// [LuminaSaveGame] so a loaded slot comes back as a [LuminaBlueprintSaveGame].
abstract final class LuminaBlueprintSaveGameClasses {
  static final Map<String, LuminaBlueprintSaveGameDocument> _classes = {};

  static void register(LuminaBlueprintSaveGameDocument c) {
    _classes[c.name] = c;
    LuminaSaveGame.registerSaveGameType<LuminaBlueprintSaveGame>(c.name, (json) => LuminaBlueprintSaveGame.fromJson(c.name, json));
  }

  static void registerAll(Iterable<LuminaBlueprintSaveGameDocument> classes) => classes.forEach(register);

  static LuminaBlueprintSaveGameDocument? lookup(String? name) => name == null ? null : _classes[name];

  static void clear() => _classes.clear();

  static List<LuminaBlueprintSaveGameDocument> get all => List.unmodifiable(_classes.values);
}

/// A save object of a Blueprint save-game class: the class name and its
/// fields in [customSaveData] (JSON-plain, authoring-space values).
class LuminaBlueprintSaveGame extends LuminaSaveGame {
  final String className;

  LuminaBlueprintSaveGame(this.className, {LuminaBlueprintSaveGameDocument? document, super.customSaveData, super.saveSlotName, super.userIndex,
      super.saveTimestamp, super.currentLevelName, super.playerLocation, super.playerRotation, super.saveGameVersion}) {
    for (final f in document?.fields ?? const <LuminaBlueprintVariable>[]) {
      customSaveData.putIfAbsent(f.name, () => f.defaultValue ?? _plainZero(f));
    }
  }

  static Object? _plainZero(LuminaBlueprintVariable f) => switch (f.type) {
        LuminaPinType.float => 0.0,
        LuminaPinType.integer => 0,
        LuminaPinType.boolean => false,
        LuminaPinType.string || LuminaPinType.name || LuminaPinType.enumeration => '',
        LuminaPinType.vector || LuminaPinType.rotator => const [0.0, 0.0, 0.0],
        LuminaPinType.vector2D => const [0.0, 0.0],
        LuminaPinType.color => const [0.0, 0.0, 0.0, 1.0],
        LuminaPinType.array => const [],
        _ => null,
      };

  @override
  String get saveGameClassName => className;

  factory LuminaBlueprintSaveGame.fromJson(String className, Map<String, dynamic> json) {
    final base = LuminaSaveGame.fromJson(json);
    return LuminaBlueprintSaveGame(
      className,
      customSaveData: base.customSaveData,
      saveSlotName: base.saveSlotName,
      userIndex: base.userIndex,
      saveTimestamp: base.saveTimestamp,
      currentLevelName: base.currentLevelName,
      playerLocation: base.playerLocation,
      playerRotation: base.playerRotation,
      saveGameVersion: base.saveGameVersion,
    );
  }
}

/// One section of a montage: where it starts and which section follows.
class LuminaBlueprintMontageSection {
  final String name;
  final double startTime;
  final String? nextSection;
  const LuminaBlueprintMontageSection({required this.name, required this.startTime, this.nextSection});

  Map<String, dynamic> toJson() => {'name': name, 'startTime': startTime, if (nextSection != null) 'nextSection': nextSection};

  factory LuminaBlueprintMontageSection.fromJson(Map<String, dynamic> map) => LuminaBlueprintMontageSection(
      name: map['name'] as String? ?? '', startTime: (map['startTime'] as num?)?.toDouble() ?? 0.0, nextSection: map['nextSection'] as String?);
}

/// A notify of a montage: a name fired at a time.
class LuminaBlueprintMontageNotify {
  final String name;
  final double time;
  const LuminaBlueprintMontageNotify({required this.name, required this.time});

  Map<String, dynamic> toJson() => {'name': name, 'time': time};

  factory LuminaBlueprintMontageNotify.fromJson(Map<String, dynamic> map) =>
      LuminaBlueprintMontageNotify(name: map['name'] as String? ?? '', time: (map['time'] as num?)?.toDouble() ?? 0.0);
}

/// A montage asset as `Play Anim Montage` plays it: the clip
/// it plays on the skeletal mesh, its length (the clip's when the mesh knows
/// it), sections and notifies. The `.lmas` payload carries `"kind": "montage"`.
class LuminaBlueprintMontageDocument {
  static const String kind = 'montage';
  final String name;
  final String clip;
  final double length;
  final List<LuminaBlueprintMontageSection> sections;
  final List<LuminaBlueprintMontageNotify> notifies;
  final double blendInTime;
  final double blendOutTime;

  const LuminaBlueprintMontageDocument({
    required this.name,
    required this.clip,
    this.length = 1.0,
    this.sections = const [],
    this.notifies = const [],
    this.blendInTime = 0.25,
    this.blendOutTime = 0.25,
  });

  LuminaBlueprintMontageSection? section(String? name) {
    for (final s in sections) {
      if (s.name == name) return s;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'kind': kind,
        'name': name,
        'clip': clip,
        'length': length,
        'sections': sections.map((s) => s.toJson()).toList(),
        'notifies': notifies.map((n) => n.toJson()).toList(),
        'blendInTime': blendInTime,
        'blendOutTime': blendOutTime,
      };

  factory LuminaBlueprintMontageDocument.fromJson(Map<String, dynamic> map) => LuminaBlueprintMontageDocument(
        name: map['name'] as String? ?? '',
        clip: map['clip'] as String? ?? '',
        length: (map['length'] as num?)?.toDouble() ?? 1.0,
        sections: [for (final s in map['sections'] as List? ?? const []) LuminaBlueprintMontageSection.fromJson(Map<String, dynamic>.from(s as Map))],
        notifies: [for (final n in map['notifies'] as List? ?? const []) LuminaBlueprintMontageNotify.fromJson(Map<String, dynamic>.from(n as Map))],
        blendInTime: (map['blendInTime'] as num?)?.toDouble() ?? 0.25,
        blendOutTime: (map['blendOutTime'] as num?)?.toDouble() ?? 0.25,
      );
}

/// The project's montage assets by name or path.
abstract final class LuminaBlueprintMontages {
  static final Map<String, LuminaBlueprintMontageDocument> _montages = {};

  static void register(LuminaBlueprintMontageDocument m, {String? path}) {
    _montages[m.name] = m;
    if (path != null) _montages[path] = m;
  }

  static LuminaBlueprintMontageDocument? lookup(String? nameOrPath) {
    if (nameOrPath == null) return null;
    final direct = _montages[nameOrPath];
    if (direct != null) return direct;
    final base = nameOrPath.split('/').last.replaceAll('.lmas', '');
    return _montages[base];
  }

  static void clear() => _montages.clear();
}

/// The project's particle assets by path: what `Spawn
/// Emitter at Location` builds a component from.
abstract final class LuminaBlueprintParticleTemplates {
  static final Map<String, LuminaParticleEmitterConfig> _templates = {};

  static void register(String path, LuminaParticleEmitterConfig config) => _templates[path] = config;

  static LuminaParticleEmitterConfig? lookup(String? path) {
    if (path == null) return null;
    final direct = _templates[path];
    if (direct != null) return direct;
    final base = path.split('/').last.replaceAll('.lmas', '');
    for (final e in _templates.entries) {
      if (e.key.split('/').last.replaceAll('.lmas', '') == base) return e.value;
    }
    return null;
  }

  static void clear() => _templates.clear();
}

/// A montage being played by a Blueprint: the position on
/// the montage's timeline, the section it is in, notifies fired, and the
/// section jumps `Montage Jump To Section` / `Set Next Section` make.
class LuminaBlueprintMontagePlayback {
  final LuminaBlueprintMontageDocument montage;
  double position;
  double playRate;
  final Map<String, String?> nextSections;
  final Set<int> _firedNotifies = {};
  bool finished = false;

  /// Sections follow one another in start order unless a section names its
  /// next one (or `Set Next Section` changes it).
  LuminaBlueprintMontagePlayback(this.montage, {this.position = 0.0, this.playRate = 1.0})
      : nextSections = _defaultNext(montage);

  static Map<String, String?> _defaultNext(LuminaBlueprintMontageDocument montage) {
    final ordered = List.of(montage.sections)..sort((a, b) => a.startTime.compareTo(b.startTime));
    return {
      for (var i = 0; i < ordered.length; i++) ordered[i].name: ordered[i].nextSection ?? (i + 1 < ordered.length ? ordered[i + 1].name : null),
    };
  }

  /// The section [position] lies in, if any.
  LuminaBlueprintMontageSection? get currentSection {
    LuminaBlueprintMontageSection? current;
    for (final s in montage.sections) {
      if (position + 1e-9 >= s.startTime && (current == null || s.startTime >= current.startTime)) current = s;
    }
    return current;
  }

  /// The time the current section ends: the next section's start, else the montage length.
  double get currentSectionEnd {
    final current = currentSection;
    if (current == null) return montage.length;
    double end = montage.length;
    for (final s in montage.sections) {
      if (s.startTime > current.startTime && s.startTime < end) end = s.startTime;
    }
    return end;
  }

  void jumpToSection(String name) {
    final s = montage.section(name);
    if (s == null) return;
    position = s.startTime;
    _firedNotifies.removeWhere((i) => montage.notifies[i].time >= s.startTime);
  }

  /// Advances [dt] seconds; returns the notifies passed, and sets [finished]
  /// when the last section ends without a next one.
  List<String> advance(double dt) {
    if (finished) return const [];
    final from = position;
    final section = currentSection;
    final end = currentSectionEnd;
    position += dt * playRate;
    final fired = <String>[];
    for (var i = 0; i < montage.notifies.length; i++) {
      final n = montage.notifies[i];
      if (!_firedNotifies.contains(i) && n.time > from - 1e-9 && n.time <= position + 1e-9) {
        _firedNotifies.add(i);
        fired.add(n.name);
      }
    }
    if (position >= end - 1e-9) {
      final next = section == null ? null : nextSections[section.name];
      final nextSection = next == null ? null : montage.section(next);
      if (nextSection != null && next != section?.name) {
        position = nextSection.startTime;
        _firedNotifies.removeWhere((i) => montage.notifies[i].time >= nextSection.startTime);
      } else if (nextSection != null) {
        // A section looping onto itself.
        position = nextSection.startTime;
        _firedNotifies.removeWhere((i) => montage.notifies[i].time >= nextSection.startTime);
      } else {
        position = end;
        finished = true;
      }
    }
    return fired;
  }
}

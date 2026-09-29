import 'package:flutter/foundation.dart' show ValueKey;

import '../object/actor.dart';
import '../world/level_script_actor.dart';
import 'blueprint_function_library.dart';
import 'blueprint_model.dart';

/// A placed actor a Level Blueprint refers to by name: its
/// outliner name (`Door_01`), its class as an object pin types it
/// (`Actor:BP_Door`, `Actor:LuminaPlayerStart`) and the id the level mounts
/// it with (`ValueKey(id)`, in Play-In-Editor and in the generated level).
class LuminaBlueprintLevelActorRef {
  final String name;
  final String actorClass;
  final String id;

  const LuminaBlueprintLevelActorRef({required this.name, required this.actorClass, required this.id});

  /// The engine class of each editor actor type a level can hold.
  static const Map<String, String> engineClassOfType = {
    'PlayerStart': 'LuminaPlayerStart',
    'Pawn': 'LuminaPawn',
    'Character': 'LuminaCharacter',
    'TriggerVolume': 'LuminaTriggerVolume',
    'BlockingVolume': 'LuminaBlockingVolume',
    'Primitive': 'LuminaPrimitiveActor',
  };

  /// The class string of a placed actor map (`metadata.actors[]`): its
  /// Blueprint class (`contents/blueprints/BP_Door.lmas` → `Actor:BP_Door`),
  /// else its type's engine class, else `Actor:LuminaActor`.
  static String classOfActorMap(Map<String, dynamic> actor) {
    final blueprint = actor['blueprintClass'];
    if (blueprint is String && blueprint.isNotEmpty) {
      return LuminaBlueprintObjectClass.actor(blueprint.split('/').last.replaceAll('.lmas', ''));
    }
    final engine = engineClassOfType['${actor['type'] ?? ''}'];
    return LuminaBlueprintObjectClass.actor(engine ?? 'LuminaActor');
  }

  /// The reference of a placed actor map; null for a folder or a nameless actor.
  static LuminaBlueprintLevelActorRef? fromActorMap(Map<String, dynamic> actor) {
    if (actor['type'] == 'Folder') return null;
    final name = '${actor['name'] ?? ''}'.trim();
    final id = '${actor['id'] ?? ''}';
    if (name.isEmpty || id.isEmpty) return null;
    return LuminaBlueprintLevelActorRef(name: name, actorClass: classOfActorMap(actor), id: id);
  }

  /// Every referable actor of a level's `metadata.actors`, in level order.
  static List<LuminaBlueprintLevelActorRef> fromActorMaps(Iterable<Object?> actors) => [
        for (final a in actors)
          if (a is Map)
            ?fromActorMap(Map<String, dynamic>.from(a)),
      ];

  Map<String, dynamic> toJson() => {'name': name, 'actorClass': actorClass, 'id': id};

  factory LuminaBlueprintLevelActorRef.fromJson(Map<String, dynamic> map) => LuminaBlueprintLevelActorRef(
        name: map['name'] as String? ?? '',
        actorClass: map['actorClass'] as String? ?? LuminaBlueprintObjectClass.anyActor,
        id: map['id'] as String? ?? '',
      );

  @override
  String toString() => '$name ($actorClass)';
}

/// A level's own Blueprint (the Level Blueprint): the
/// graph that scripts the level itself — events, variables, functions,
/// macros, dispatchers, timelines — stored inside the level `.lmas` under
/// `metadata.levelBlueprint`, so a level and its script travel together.
class LuminaLevelBlueprintDocument {
  /// The `kind` discriminator of the stored payload.
  static const String kind = 'level_blueprint';

  /// The level `.lmas` metadata key the document is stored under.
  static const String metadataKey = 'levelBlueprint';

  /// The class every level script is (`Self` in a Level Blueprint).
  static const String parentClass = 'LuminaLevelScriptActor';

  /// The project-relative level this Blueprint scripts
  /// (`contents/levels/L_Test.lmas`).
  final String levelPath;

  /// The graph, variables, functions… (`parentClass` is always
  /// [parentClass]; a level Blueprint has no components).
  final LuminaBlueprintDocument blueprint;

  LuminaLevelBlueprintDocument({required this.levelPath, LuminaBlueprintDocument? blueprint})
      : blueprint = blueprint ?? LuminaBlueprintDocument(parentClass: parentClass) {
    this.blueprint.parentClass = parentClass;
  }

  /// The level's base name (`L_Test`).
  String get levelName => levelPath.split('/').last.replaceAll('.lmas', '');

  /// Whether the Blueprint does nothing: no nodes, variables or functions.
  bool get isEmpty =>
      blueprint.eventGraph.nodes.isEmpty &&
      blueprint.variables.isEmpty &&
      blueprint.functions.isEmpty &&
      blueprint.macros.isEmpty &&
      blueprint.dispatchers.isEmpty;

  Map<String, dynamic> toJson() => {'kind': kind, 'levelPath': levelPath, ...blueprint.toJson()};

  factory LuminaLevelBlueprintDocument.fromJson(Map<String, dynamic> map, {String? levelPath}) {
    final doc = LuminaBlueprintDocument.fromJson(map);
    return LuminaLevelBlueprintDocument(levelPath: levelPath ?? map['levelPath'] as String? ?? '', blueprint: doc);
  }

  /// The document a level's `metadata` stores; an empty graph when the level
  /// has none (or it cannot be read).
  factory LuminaLevelBlueprintDocument.fromLevelMetadata(Object? metadata, {required String levelPath}) {
    final stored = metadata is Map ? metadata[metadataKey] : null;
    if (stored is Map) {
      try {
        return LuminaLevelBlueprintDocument.fromJson(Map<String, dynamic>.from(stored), levelPath: levelPath);
      } catch (_) {
        // A damaged document loads as an empty graph; the editor shows it.
      }
    }
    return LuminaLevelBlueprintDocument(levelPath: levelPath);
  }
}

/// What a level script needs to find the level's placed actors by name:
/// the VM's `LuminaBlueprintLevelScript` and every generated
/// `_<Level>Script` mix it in. The level mounts each placed actor with
/// `ValueKey(id)`; [levelActor] finds it among the owning level's actors,
/// then the world's, and answers null once it was destroyed or removed.
mixin LuminaBlueprintLevelActors on LuminaLevelScriptActor {
  /// Placed actor name → the id the level mounts it with.
  Map<String, String> get levelActorIds;

  /// The live placed actor named [name], or null (unknown, destroyed or
  /// removed from the level).
  LuminaActor? levelActor(String name) {
    final id = levelActorIds[name];
    if (id == null) return null;
    final key = ValueKey(id);
    for (final a in level?.actors ?? const <LuminaActor>[]) {
      if (a.key == key) return liveLevelActor(a);
    }
    for (final a in world?.actors ?? const <LuminaActor>[]) {
      if (a.key == key) return liveLevelActor(a);
    }
    return null;
  }

  /// [actor] while it is still in play; null once destroyed or removed.
  LuminaActor? liveLevelActor(LuminaActor? actor) {
    if (actor == null || actor.isPendingDestroy || actor.isDestroyed || actor.world == null) return null;
    return actor;
  }

  /// The live placed actors of class string [cls], in level order.
  List<Object?> levelActorsOfClass(String cls) => <Object?>[
        for (final name in levelActorIds.keys)
          if (levelActor(name) case final a? when LuminaBlueprintFunctionLibrary.isA(a, cls)) a,
      ];
}

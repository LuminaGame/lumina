import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/src/object/actor.dart';
import 'package:lumina/src/world/world_partition.dart';
import 'package:lumina/src/world/subsystem/world_subsystem.dart';
import 'package:lumina/src/world/world.dart';
import 'package:lumina/src/save/save_game.dart';

/// The directory saves went to before the built game and Play-In-Editor
/// got their own: relative to the process's working directory.
const String kLuminaLegacySaveDirectory = './saved_games';

/// Represents the structured result of an asynchronous save operation.
class LuminaSaveResult {
  final bool success;
  final Object? error;
  final String? filePath;

  const LuminaSaveResult({
    required this.success,
    this.error,
    this.filePath,
  });
}

/// Thrown when an existing save file on disk contains corrupted or unparseable data.
class LuminaSaveCorruptException implements Exception {
  final String message;
  final Object? cause;

  LuminaSaveCorruptException(this.message, [this.cause]);

  @override
  String toString() => 'LuminaSaveCorruptException: $message${cause != null ? ' (Cause: $cause)' : ''}';
}

/// Serialized representation of a single actor and its persistent components.
class LuminaActorRecord {
  final String saveId;
  final String actorClassName;
  final List<double> location;
  final List<double> rotation;
  final Map<String, dynamic> customData;
  final Map<String, Map<String, dynamic>> componentData;

  LuminaActorRecord({
    required this.saveId,
    required this.actorClassName,
    required this.location,
    required this.rotation,
    required this.customData,
    required this.componentData,
  });

  Map<String, dynamic> toJson() => {
    'saveId': saveId,
    'actorClassName': actorClassName,
    'location': location,
    'rotation': rotation,
    'customData': customData,
    'componentData': componentData,
  };

  factory LuminaActorRecord.fromJson(Map<String, dynamic> json) {
    final compDataRaw = json['componentData'] as Map<String, dynamic>? ?? {};
    final compData = <String, Map<String, dynamic>>{};
    compDataRaw.forEach((k, v) {
      if (v is Map<String, dynamic>) {
        compData[k] = v;
      } else if (v is Map) {
        compData[k] = Map<String, dynamic>.from(v);
      }
    });

    return LuminaActorRecord(
      saveId: json['saveId'] as String? ?? '',
      actorClassName: json['actorClassName'] as String? ?? 'LuminaActor',
      location: (json['location'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? [0.0, 0.0, 0.0],
      rotation: (json['rotation'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? [0.0, 0.0, 0.0, 1.0],
      customData: (json['customData'] as Map?)?.cast<String, dynamic>() ?? {},
      componentData: compData,
    );
  }
}

/// Snapshot of entire world state including actors and data layers.
class LuminaWorldStateSnapshot {
  final String levelName;
  final List<LuminaActorRecord> actors;
  final Map<String, String> dataLayerStates;

  LuminaWorldStateSnapshot({
    required this.levelName,
    required this.actors,
    Map<String, String>? dataLayerStates,
  }) : dataLayerStates = dataLayerStates ?? {};

  Map<String, dynamic> toJson() => {
    'levelName': levelName,
    'actors': actors.map((a) => a.toJson()).toList(),
    'dataLayerStates': dataLayerStates,
  };

  factory LuminaWorldStateSnapshot.fromJson(Map<String, dynamic> json) {
    final actorsList = (json['actors'] as List?)
        ?.map((e) => LuminaActorRecord.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList() ?? [];

    final layersMap = (json['dataLayerStates'] as Map?)?.cast<String, String>() ?? {};

    return LuminaWorldStateSnapshot(
      levelName: json['levelName'] as String? ?? 'DefaultLevel',
      actors: actorsList,
      dataLayerStates: layersMap,
    );
  }
}

/// Report summarizing the results of restoring a world state.
class LuminaRestoreReport {
  final int restored;
  final int spawned;
  final List<String> missingIds;

  LuminaRestoreReport({
    this.restored = 0,
    this.spawned = 0,
    this.missingIds = const [],
  });
}

/// Subsystem managing asynchronous Game Save & Load operations on disk with atomic write protection.
class LuminaSaveGameSubsystem extends LuminaWorldSubsystem {
  final String saveDirectoryPath;
  final Map<String, Future<void>> _slotQueues = {};

  static final Map<String, LuminaActor Function(LuminaActorRecord)> _actorFactories = {};

  /// Where a subsystem created without a directory saves:
  /// `./saved_games` by default; the generated `main()` points it at the
  /// platform's app-support directory ([platformSaveDirectory]) and
  /// Play-In-Editor at `<project>/Saved/SaveGames`.
  static String defaultSaveDirectoryPath = kLuminaLegacySaveDirectory;

  LuminaSaveGameSubsystem({String? saveDirectoryPath}) : saveDirectoryPath = saveDirectoryPath ?? defaultSaveDirectoryPath;

  /// The platform's per-user application-support directory for [appName]
  /// plus `SaveGames` — what `path_provider`'s `getApplicationSupportDirectory`
  /// resolves on desktop (Linux `$XDG_DATA_HOME` or `~/.local/share`, macOS
  /// `~/Library/Application Support`, Windows `%APPDATA%`). Null on the web
  /// and on platforms whose directory only a plugin knows (Android, iOS), where
  /// [defaultSaveDirectoryPath] stays as it is.
  static String? platformSaveDirectory(String appName, {Map<String, String>? environment, String? operatingSystem}) {
    if (kIsWeb) return null;
    final env = environment ?? Platform.environment;
    final os = operatingSystem ?? Platform.operatingSystem;
    final app = appName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    String? base;
    switch (os) {
      case 'linux':
        final xdg = env['XDG_DATA_HOME'];
        final home = env['HOME'];
        base = (xdg != null && xdg.isNotEmpty) ? xdg : (home == null || home.isEmpty ? null : '$home/.local/share');
      case 'macos':
        final home = env['HOME'];
        base = home == null || home.isEmpty ? null : '$home/Library/Application Support';
      case 'windows':
        final appData = env['APPDATA'];
        base = appData == null || appData.isEmpty ? null : appData;
      default:
        base = null;
    }
    if (base == null) return null;
    final sep = os == 'windows' ? r'\' : '/';
    return '$base$sep$app${sep}SaveGames';
  }

  /// Registers a factory for spawning saveable actors when restoring records missing from the scene.
  static void registerSaveableActorFactory(
    String className,
    LuminaActor Function(LuminaActorRecord record) factory,
  ) {
    _actorFactories[className] = factory;
  }

  void _validateSlotName(String slotName) {
    if (slotName.isEmpty) {
      throw ArgumentError.value(slotName, 'slotName', 'Save slot name cannot be empty');
    }
    if (slotName.contains('/') || slotName.contains('\\') || slotName.contains('..')) {
      throw ArgumentError.value(slotName, 'slotName', 'Save slot name cannot contain path separators or ".."');
    }
  }

  String _getSlotFilePath(String slotName, int userIndex) {
    return '$saveDirectoryPath/${slotName}_user_$userIndex.sav';
  }

  Future<T> _runOnSlot<T>(String slotKey, Future<T> Function() action) {
    final prev = _slotQueues[slotKey] ?? Future.value();
    final completer = Completer<T>();

    final chained = prev.catchError((_) {}).then((_) async {
      try {
        final result = await action();
        completer.complete(result);
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });

    _slotQueues[slotKey] = chained;
    return completer.future;
  }

  @override
  void onWorldInitialize(LuminaWorld world) {
    super.onWorldInitialize(world);
    _sweepOrphanedTempFiles();
  }

  void _sweepOrphanedTempFiles() {
    try {
      final dir = Directory(saveDirectoryPath);
      if (dir.existsSync()) {
        final entries = dir.listSync(followLinks: false);
        for (final entry in entries) {
          if (entry is File && entry.path.endsWith('.tmp')) {
            try {
              entry.deleteSync();
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
  }

  static Future<String> _encodeMap(Map<String, dynamic> map) {
    return Isolate.run(() => jsonEncode(map));
  }

  static Future<dynamic> _decodeString(String raw) {
    return Isolate.run(() => jsonDecode(raw));
  }

  /// Captures all actors and components marked with [bSaveGame = true] across active world levels.
  LuminaWorldStateSnapshot captureWorldState() {
    final activeWorld = world;
    if (activeWorld == null) {
      throw StateError('Cannot capture world state without an active LuminaWorld');
    }

    final records = <LuminaActorRecord>[];
    final seenIds = <String>{};

    final allActors = activeWorld.levels.expand((lvl) => lvl.actors).toSet().toList();

    for (final actor in allActors) {
      if (seenIds.contains(actor.saveId)) {
        throw StateError('Duplicate saveId found during world capture: ${actor.saveId}');
      }
      seenIds.add(actor.saveId);

      if (!actor.bSaveGame) continue;

      final customData = actor.captureSaveData();
      final componentData = <String, Map<String, dynamic>>{};

      for (final comp in actor.components) {
        if (comp.bSaveGame) {
          componentData[comp.effectiveComponentName] = comp.captureSaveData();
        }
      }

      records.add(
        LuminaActorRecord(
          saveId: actor.saveId,
          actorClassName: actor.runtimeType.toString(),
          location: [actor.actorLocation.x, actor.actorLocation.y, actor.actorLocation.z],
          rotation: [actor.actorRotation.x, actor.actorRotation.y, actor.actorRotation.z, actor.actorRotation.w],
          customData: customData,
          componentData: componentData,
        ),
      );
    }

    final dataLayerStates = <String, String>{};
    final partition = activeWorld.subsystems.getSubsystem<LuminaWorldPartitionSubsystem>();
    if (partition != null) {
      final snap = partition.dataLayerManager.snapshotStates();
      for (final entry in snap.entries) {
        dataLayerStates[entry.key] = entry.value.name;
      }
    }

    return LuminaWorldStateSnapshot(
      levelName: activeWorld.currentLevel?.effectiveName ?? 'DefaultLevel',
      actors: records,
      dataLayerStates: dataLayerStates,
    );
  }

  /// Restores a [LuminaWorldStateSnapshot] onto the live world.
  Future<LuminaRestoreReport> restoreWorldState(LuminaWorldStateSnapshot snapshot) async {
    final activeWorld = world;
    if (activeWorld == null) {
      throw StateError('Cannot restore world state without an active LuminaWorld');
    }

    int restoredCount = 0;
    int spawnedCount = 0;
    final missingIds = <String>[];

    final allActors = activeWorld.levels.expand((lvl) => lvl.actors).toSet().toList();

    final actorMap = <String, LuminaActor>{};
    for (final actor in allActors) {
      actorMap[actor.saveId] = actor;
    }

    for (final record in snapshot.actors) {
      final liveActor = actorMap[record.saveId];
      if (liveActor != null) {
        // Apply transform first
        liveActor.actorLocation = Vector3(record.location[0], record.location[1], record.location[2]);
        liveActor.actorRotation = Quaternion(record.rotation[0], record.rotation[1], record.rotation[2], record.rotation[3]);

        // Restore actor custom data
        liveActor.restoreSaveData(record.customData);

        // Restore component data
        for (final comp in liveActor.components) {
          final compName = comp.effectiveComponentName;
          if (record.componentData.containsKey(compName)) {
            comp.restoreSaveData(record.componentData[compName]!);
          }
        }
        restoredCount++;
      } else {
        // Try spawning from registered factory
        final factory = _actorFactories[record.actorClassName];
        if (factory != null) {
          final spawned = factory(record);
          activeWorld.persistentLevel.registerActor(spawned);
          spawned.actorLocation = Vector3(record.location[0], record.location[1], record.location[2]);
          spawned.actorRotation = Quaternion(record.rotation[0], record.rotation[1], record.rotation[2], record.rotation[3]);
          spawned.restoreSaveData(record.customData);
          for (final comp in spawned.components) {
            final compName = comp.effectiveComponentName;
            if (record.componentData.containsKey(compName)) {
              comp.restoreSaveData(record.componentData[compName]!);
            }
          }
          spawnedCount++;
        } else {
          missingIds.add(record.saveId);
        }
      }
    }

    // Restore data layer states last
    final partition = activeWorld.subsystems.getSubsystem<LuminaWorldPartitionSubsystem>();
    if (partition != null && snapshot.dataLayerStates.isNotEmpty) {
      snapshot.dataLayerStates.forEach((layerName, stateName) {
        final state = DataLayerState.values.firstWhere(
          (s) => s.name == stateName,
          orElse: () => DataLayerState.unloaded,
        );
        partition.dataLayerManager.setDataLayerState(layerName, state);
      });
    }

    return LuminaRestoreReport(
      restored: restoredCount,
      spawned: spawnedCount,
      missingIds: missingIds,
    );
  }

  /// Captures current world state and saves it to a designated slot file asynchronously.
  Future<LuminaSaveResult> saveWorldToSlotAsync(
    String slotName,
    int userIndex, {
    LuminaSaveGame? into,
  }) async {
    final snapshot = captureWorldState();
    final saveGame = into ?? LuminaSaveGame(
      saveSlotName: slotName,
      userIndex: userIndex,
      currentLevelName: snapshot.levelName,
    );

    saveGame.customSaveData['worldState'] = snapshot.toJson();
    return saveGameToSlotAsync(saveGame, slotName, userIndex);
  }

  /// Loads a designated slot file and automatically restores the contained world state.
  Future<LuminaRestoreReport?> loadWorldFromSlotAsync(
    String slotName,
    int userIndex,
  ) async {
    final saveGame = await loadGameFromSlotAsync(slotName, userIndex);
    if (saveGame == null) return null;

    final worldStateRaw = saveGame.customSaveData['worldState'];
    if (worldStateRaw == null) return LuminaRestoreReport();

    final Map<String, dynamic> worldStateMap;
    if (worldStateRaw is Map<String, dynamic>) {
      worldStateMap = worldStateRaw;
    } else if (worldStateRaw is Map) {
      worldStateMap = Map<String, dynamic>.from(worldStateRaw);
    } else {
      throw LuminaSaveCorruptException('Invalid worldState payload in save game');
    }

    final snapshot = LuminaWorldStateSnapshot.fromJson(worldStateMap);
    return restoreWorldState(snapshot);
  }

  /// Asynchronously saves a [LuminaSaveGame] object to a designated slot file atomically.
  Future<LuminaSaveResult> saveGameToSlotAsync(
    LuminaSaveGame saveObject,
    String slotName,
    int userIndex,
  ) async {
    _validateSlotName(slotName);
    final slotKey = '${slotName}_user_$userIndex';

    return _runOnSlot<LuminaSaveResult>(slotKey, () async {
      File? tempFile;
      try {
        // 1. Serialize to sendable Map on caller isolate
        final mapPayload = saveObject.toJson();

        // 2. Offload JSON string encoding to background isolate using static function
        final rawData = await _encodeMap(mapPayload);

        // 3. Ensure directory exists
        final dir = Directory(saveDirectoryPath);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }

        final filePath = _getSlotFilePath(slotName, userIndex);
        final tempFilePath = '$filePath.tmp';

        tempFile = File(tempFilePath);
        await tempFile.writeAsString(rawData, flush: true);

        // 4. Atomic rename onto final destination
        await tempFile.rename(filePath);

        return LuminaSaveResult(
          success: true,
          filePath: filePath,
        );
      } catch (e) {
        if (tempFile != null && await tempFile.exists()) {
          try {
            await tempFile.delete();
          } catch (_) {}
        }
        return LuminaSaveResult(
          success: false,
          error: e,
        );
      }
    });
  }

  /// Asynchronously loads a [LuminaSaveGame] object from a designated slot file.
  Future<LuminaSaveGame?> loadGameFromSlotAsync(String slotName, int userIndex) async {
    _validateSlotName(slotName);
    final slotKey = '${slotName}_user_$userIndex';

    return _runOnSlot<LuminaSaveGame?>(slotKey, () async {
      final filePath = _getSlotFilePath(slotName, userIndex);
      final file = File(filePath);
      if (!await file.exists()) return null;

      final rawData = await file.readAsString();

      dynamic decodedMap;
      try {
        decodedMap = await _decodeString(rawData);
      } catch (e) {
        throw LuminaSaveCorruptException('Corrupted JSON syntax in save file $filePath', e);
      }

      if (decodedMap is! Map<String, dynamic>) {
        throw LuminaSaveCorruptException('Expected Map root in save file $filePath');
      }

      try {
        return LuminaSaveGame.instantiateFromJson(decodedMap);
      } catch (e) {
        throw LuminaSaveCorruptException('Failed to instantiate save object from $filePath', e);
      }
    });
  }

  /// The file a slot is stored in.
  String slotFilePath(String slotName, int userIndex) {
    _validateSlotName(slotName);
    return _getSlotFilePath(slotName, userIndex);
  }

  /// Writes [saveObject] to its slot right away (temp file, then rename):
  /// the Blueprint `Save Game to Slot`, which answers on the same exec chain.
  /// Returns whether it was written.
  bool saveGameToSlotSync(LuminaSaveGame saveObject, String slotName, int userIndex) {
    try {
      final path = slotFilePath(slotName, userIndex);
      final dir = Directory(saveDirectoryPath);
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final temp = File('$path.tmp');
      temp.writeAsStringSync(jsonEncode(saveObject.toJson()), flush: true);
      temp.renameSync(path);
      return true;
    } catch (e) {
      developer.log('Save Game to Slot $slotName failed: $e', name: 'LuminaSaveGame', level: 900);
      return false;
    }
  }

  /// Reads the slot right away; null when there is none or it is corrupt.
  LuminaSaveGame? loadGameFromSlotSync(String slotName, int userIndex) {
    try {
      final file = File(slotFilePath(slotName, userIndex));
      if (!file.existsSync()) return null;
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map) return null;
      return LuminaSaveGame.instantiateFromJson(Map<String, dynamic>.from(decoded));
    } catch (e) {
      developer.log('Load Game from Slot $slotName failed: $e', name: 'LuminaSaveGame', level: 900);
      return null;
    }
  }

  /// Whether the slot file exists, checked right away.
  bool doesSaveGameExistSync(String slotName, int userIndex) => File(slotFilePath(slotName, userIndex)).existsSync();

  /// Deletes the slot file; true when one was removed.
  bool deleteGameInSlot(String slotName, int userIndex) {
    final file = File(slotFilePath(slotName, userIndex));
    if (!file.existsSync()) return false;
    file.deleteSync();
    return true;
  }

  /// Checks if a final save slot file exists on disk.
  Future<bool> doesSaveGameExist(String slotName, int userIndex) async {
    _validateSlotName(slotName);
    final filePath = _getSlotFilePath(slotName, userIndex);
    return File(filePath).exists();
  }

  /// Deletes a save slot file and any orphaned temporary file.
  Future<bool> deleteSaveSlot(String slotName, int userIndex) async {
    _validateSlotName(slotName);
    final slotKey = '${slotName}_user_$userIndex';

    return _runOnSlot<bool>(slotKey, () async {
      final filePath = _getSlotFilePath(slotName, userIndex);
      final tempFilePath = '$filePath.tmp';

      bool deleted = false;
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        deleted = true;
      }

      final tmpFile = File(tempFilePath);
      if (await tmpFile.exists()) {
        try {
          await tmpFile.delete();
        } catch (_) {}
      }

      return deleted;
    });
  }

  /// Lists all valid save slot names stored in [saveDirectoryPath].
  Future<List<String>> listSaveSlots({int? userIndex}) async {
    final dir = Directory(saveDirectoryPath);
    if (!await dir.exists()) return [];

    final slots = <String>[];
    final regex = RegExp(r'^(.+)_user_(\d+)\.sav$');

    await for (final entry in dir.list(followLinks: false)) {
      if (entry is File) {
        final filename = entry.uri.pathSegments.lastWhere((s) => s.isNotEmpty, orElse: () => '');
        final match = regex.firstMatch(filename);
        if (match != null) {
          final slot = match.group(1)!;
          final idx = int.parse(match.group(2)!);
          if (userIndex == null || userIndex == idx) {
            slots.add(slot);
          }
        }
      }
    }

    return slots;
  }
}

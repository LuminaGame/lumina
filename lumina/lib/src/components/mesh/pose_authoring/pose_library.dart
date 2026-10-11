import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:lumina_core/lumina_core.dart';

import 'package:lumina/src/save/save_game.dart';
import 'package:lumina/src/save/save_game_subsystem.dart';
import 'package:lumina/src/utility/lumina_assets.dart';

/// Pose storage at runtime: a mesh's `PoseLibrary.lmas` read through the
/// asset provider, poses saved in a save game slot, and (in Play-In-Editor)
/// poses written into the project's pose library.
abstract final class LuminaPoseLibrary {
  /// The key of a save game's `customSaveData` holding poses by name.
  static const String saveDataKey = 'lumina_poses';

  /// The open project's folder while Play-In-Editor runs: [saveToProject]
  /// writes there. Null in a built game.
  static String? editorProjectDir;

  /// The pose library at [assetPath] (`contents/animations/<Mesh>/PoseLibrary.lmas`),
  /// read through [provider] (else `LuminaAssets.defaultProvider`, else the
  /// disk).
  static Future<AuthoredPoseLibrary> load(String assetPath, {LuminaAssetProvider? provider}) async {
    final bytes = await LuminaAssets.resolve(provider)(assetPath);
    return parse(bytes);
  }

  /// The library in a `PoseLibrary.lmas`'s [bytes].
  static AuthoredPoseLibrary parse(Uint8List bytes) {
    final asset = LuminaAsset.fromBytes(bytes);
    final payload = asset.rawPayload;
    if (payload == null || payload.isEmpty) {
      return AuthoredPoseLibrary(meshRelPath: asset.metadata['source_mesh'] ?? '');
    }
    return AuthoredPoseLibrary.fromJson(Map<String, dynamic>.from(jsonDecode(utf8.decode(payload)) as Map));
  }

  /// The poses [save] holds, by name.
  static Map<String, AuthoredPose> posesIn(LuminaSaveGame save) {
    final raw = save.customSaveData[saveDataKey];
    if (raw is! Map) return {};
    return {
      for (final e in raw.entries)
        if (e.value is Map) '${e.key}': AuthoredPose.fromJson(Map<String, dynamic>.from(e.value as Map)),
    };
  }

  /// [save] with [pose] stored under [name].
  static LuminaSaveGame withPose(LuminaSaveGame save, String name, AuthoredPose pose) {
    final poses = Map<String, dynamic>.from((save.customSaveData[saveDataKey] as Map?) ?? const {});
    poses[name] = pose.renamed(name).toJson();
    save.customSaveData[saveDataKey] = poses;
    return save;
  }

  /// Stores [pose] as [name] in save game slot [slot] (keeping what else the
  /// slot holds). True when written.
  static Future<bool> saveToSlot(LuminaSaveGameSubsystem saves, String slot, String name, AuthoredPose pose,
      {int userIndex = 0}) async {
    final existing = await saves.loadGameFromSlotAsync(slot, userIndex);
    final save = withPose(existing ?? LuminaSaveGame(saveSlotName: slot, userIndex: userIndex), name, pose);
    return (await saves.saveGameToSlotAsync(save, slot, userIndex)).success;
  }

  /// The pose [name] in save game slot [slot], or null.
  static Future<AuthoredPose?> loadFromSlot(LuminaSaveGameSubsystem saves, String slot, String name,
      {int userIndex = 0}) async {
    final save = await saves.loadGameFromSlotAsync(slot, userIndex);
    return save == null ? null : posesIn(save)[name];
  }

  /// Writes [pose] as [name] into the pose library of the mesh at
  /// [meshPath] in [projectDir] (on a worker isolate); returns the library's
  /// project-relative path.
  static Future<String> saveToProject(String projectDir, String meshPath, String name, AuthoredPose pose) {
    final dir = projectDir.replaceAll(r'\', '/');
    var rel = meshPath.replaceAll(r'\', '/');
    if (rel.startsWith('$dir/')) rel = rel.substring(dir.length + 1);
    final named = pose.renamed(name);
    String work() {
      final library = AuthoredPoseLibraryStore.load(dir, rel);
      library.poses.removeWhere((p) => p.name == name);
      library.poses.add(named);
      return AuthoredPoseLibraryStore.save(dir, library);
    }

    return Isolate.run(work, debugName: 'pose library save');
  }
}

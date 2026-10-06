import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:lumina/data/services/config_json_file.dart';
import 'package:lumina/data/services/lumina_config_dir.dart';

/// Where the viewport camera was when a project was last edited: yaw and
/// pitch in degrees, the orbit distance and the pivot, plus the camera mode.
class EditorCameraState {
  const EditorCameraState({
    required this.yaw,
    required this.pitch,
    required this.distance,
    required this.panX,
    required this.panY,
    required this.panZ,
    this.mode = 'Perspective',
  });

  final double yaw;
  final double pitch;
  final double distance;
  final double panX;
  final double panY;
  final double panZ;
  final String mode;

  Map<String, dynamic> toMap() => {
        'yaw': yaw,
        'pitch': pitch,
        'distance': distance,
        'pan': [panX, panY, panZ],
        'mode': mode,
      };

  /// Null when [map] is not a complete camera (a hand-edited file).
  static EditorCameraState? fromMap(Map<String, dynamic> map) {
    final pan = map['pan'];
    final yaw = map['yaw'], pitch = map['pitch'], distance = map['distance'];
    if (yaw is! num || pitch is! num || distance is! num || pan is! List || pan.length != 3 || pan.any((v) => v is! num)) {
      return null;
    }
    if (!distance.isFinite || distance <= 0) return null;
    return EditorCameraState(
      yaw: yaw.toDouble(),
      pitch: pitch.toDouble().clamp(-89.0, 89.0),
      distance: distance.toDouble(),
      panX: (pan[0] as num).toDouble(),
      panY: (pan[1] as num).toDouble(),
      panZ: (pan[2] as num).toDouble(),
      mode: map['mode'] is String ? map['mode'] as String : 'Perspective',
    );
  }

  @override
  bool operator ==(Object other) =>
      other is EditorCameraState &&
      other.yaw == yaw &&
      other.pitch == pitch &&
      other.distance == distance &&
      other.panX == panX &&
      other.panY == panY &&
      other.panZ == panZ &&
      other.mode == mode;

  @override
  int get hashCode => Object.hash(yaw, pitch, distance, panX, panY, panZ, mode);

  @override
  String toString() => 'EditorCameraState(yaw: $yaw, pitch: $pitch, distance: $distance, pan: [$panX, $panY, $panZ], $mode)';
}

/// The viewport camera of every project this user edited, keyed by project
/// directory, in `editor_camera.json` of the editor's config directory
/// ([LuminaConfigDir]), next to the quality settings. Reopening a project
/// puts the camera back where it was instead of framing the whole level.
class EditorCameraStore {
  final Directory configDir;

  EditorCameraStore({Directory? configDir}) : configDir = LuminaConfigDir.resolve(explicit: configDir);

  File get file => File('${configDir.path}/editor_camera.json');

  ConfigJsonFile get _json => ConfigJsonFile(file);

  /// The camera saved for [projectDirPath], or null (first open).
  Future<EditorCameraState?> load(String projectDirPath) async {
    Object? decoded;
    try {
      decoded = _json.read();
    } catch (e) {
      debugPrint('[EditorCameraStore] unreadable, framing the level instead: $e');
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;
    final entry = decoded[projectDirPath];
    return entry is Map ? EditorCameraState.fromMap(Map<String, dynamic>.from(entry)) : null;
  }

  Future<void> save(String projectDirPath, EditorCameraState camera) async {
    try {
      _json.update(
        (current) => {...?(current as Map<String, dynamic>?), projectDirPath: camera.toMap()},
        isValid: (value) => value is Map<String, dynamic>,
        pretty: true,
        onUnreadable: (keptAside, error) =>
            debugPrint('[EditorCameraStore] ${file.path} is not readable ($error); kept it as ${keptAside.path}'),
      );
    } catch (e) {
      debugPrint('[EditorCameraStore] could not save the camera: $e');
    }
  }
}

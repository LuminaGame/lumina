import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Rect;
import 'package:lumina_core/lumina_core.dart';

/// The editor window's placement as the user left it: the restored
/// (un-maximized) bounds in logical pixels, plus whether it was maximized or
/// fullscreen on top of them.
@immutable
class WindowStateData {
  const WindowStateData({required this.bounds, this.maximized = false, this.fullScreen = false});

  final Rect bounds;
  final bool maximized;
  final bool fullScreen;

  /// Smaller than this is not a window anyone left on purpose (a corrupt or
  /// hand-edited file); it is ignored.
  static const double minWidth = 400;
  static const double minHeight = 300;

  Map<String, Object> toJson() => {
        'x': bounds.left,
        'y': bounds.top,
        'width': bounds.width,
        'height': bounds.height,
        'maximized': maximized,
        'fullScreen': fullScreen,
      };

  /// The state in [json], or null when it is missing, malformed or too small.
  static WindowStateData? fromJson(Object? json) {
    if (json is! Map) return null;
    double? d(String k) => (json[k] is num) ? (json[k] as num).toDouble() : null;
    final x = d('x'), y = d('y'), w = d('width'), h = d('height');
    if (x == null || y == null || w == null || h == null) return null;
    if (!x.isFinite || !y.isFinite || w < minWidth || h < minHeight) return null;
    return WindowStateData(
      bounds: Rect.fromLTWH(x, y, w, h),
      maximized: json['maximized'] == true,
      fullScreen: json['fullScreen'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is WindowStateData && other.bounds == bounds && other.maximized == maximized && other.fullScreen == fullScreen;

  @override
  int get hashCode => Object.hash(bounds, maximized, fullScreen);

  @override
  String toString() => 'WindowStateData($bounds, maximized: $maximized, fullScreen: $fullScreen)';
}

/// Keeps [WindowStateData] in the editor preferences — the `window` block of
/// `editor_preferences.json` in [LuminaConfigDir] (a temp directory in every
/// test), beside the other Editor Preferences, which it never touches.
class WindowStateStore {
  WindowStateStore({Directory? configDir}) : file = File('${LuminaConfigDir.resolve(explicit: configDir).path}/$fileName');

  /// The same file as `EditorPreferences.fileName`.
  static const String fileName = 'editor_preferences.json';
  static const String key = 'window';

  final File file;

  /// The saved state, or null when there is none (first start) or it is
  /// unreadable.
  WindowStateData? load() {
    try {
      final decoded = ConfigJsonFile(file).read();
      return decoded is Map ? WindowStateData.fromJson(decoded[key]) : null;
    } catch (e) {
      debugPrint('[WindowStateStore] ${file.path} is unreadable: $e');
      return null;
    }
  }

  void save(WindowStateData state) {
    try {
      ConfigJsonFile(file).update(
        (current) => {...?(current is Map<String, dynamic> ? current : null), key: state.toJson()},
        isValid: (value) => value is Map<String, dynamic>,
        pretty: true,
        onUnreadable: (keptAside, error) =>
            debugPrint('[WindowStateStore] ${file.path} was unreadable ($error); kept it as ${keptAside.path}'),
      );
    } catch (e) {
      debugPrint('[WindowStateStore] could not save ${file.path}: $e');
    }
  }
}

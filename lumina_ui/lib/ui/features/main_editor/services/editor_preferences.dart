import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lumina/data/services/config_json_file.dart';
import 'package:lumina/data/services/lumina_config_dir.dart';

/// Editor Preferences → "Flight Camera Control Type": when W/A/S/D/Q/E fly
/// the level viewport's camera.
enum FlightCameraControlType {
  /// W/A/S/D/Q/E fly while the right mouse button is held (the default).
  rmbHeld('Use WASD Only When Right Mouse Button Is Held'),

  /// W/A/S/D/Q/E fly whenever the viewport has keyboard focus.
  always('Use WASD For Camera Controls Always'),

  /// W/A/S/D/Q/E never move the camera.
  never('Never Use WASD For Camera Controls');

  const FlightCameraControlType(this.label);

  /// The label the preferences show for this choice.
  final String label;

  static FlightCameraControlType parse(Object? value) =>
      FlightCameraControlType.values.where((t) => t.name == value).firstOrNull ?? FlightCameraControlType.rmbHeld;
}

/// The editor's per-user preferences (as opposed to the project's Project
/// Settings), in `editor_preferences.json` of the editor's config directory
/// ([LuminaConfigDir]; a temp directory in every test). A change is saved at
/// once.
class EditorPreferences extends ChangeNotifier {
  EditorPreferences._(this.file, this._flightCameraControl, this._importWorkers, this._marketplaceUrl,
      this._editorBuildMode, this._editorBuildKeep, this._editorBuildCacheDir, this._perProjectEditors);

  /// The preferences stored in [configDir] (default: [LuminaConfigDir]); the
  /// defaults when the file is missing or unreadable.
  factory EditorPreferences.load({Directory? configDir}) {
    final file = File('${LuminaConfigDir.resolve(explicit: configDir).path}/$fileName');
    var flight = FlightCameraControlType.rmbHeld;
    var importWorkers = defaultImportWorkers;
    var marketplaceUrl = defaultMarketplaceUrl;
    var buildMode = defaultEditorBuildMode;
    var buildKeep = defaultEditorBuildKeep;
    String? buildCacheDir;
    var perProject = defaultPerProjectEditors;
    try {
      final decoded = ConfigJsonFile(file).read();
      if (decoded is Map) {
        flight = FlightCameraControlType.parse(decoded['flightCameraControl']);
        final workers = decoded['importWorkers'];
        if (workers is int) importWorkers = workers.clamp(1, maxImportWorkers);
        final url = decoded['marketplaceUrl'];
        if (url is String && isValidMarketplaceUrl(url)) marketplaceUrl = url.trim();
        final mode = decoded['editorBuildMode'];
        if (mode is String && editorBuildModes.contains(mode)) buildMode = mode;
        final keep = decoded['editorBuildKeep'];
        if (keep is int) buildKeep = keep.clamp(1, maxEditorBuildKeep);
        final cacheDir = decoded['editorBuildCacheDir'];
        if (cacheDir is String && cacheDir.trim().isNotEmpty) buildCacheDir = cacheDir.trim();
        final everyProject = decoded['perProjectEditors'];
        if (everyProject is bool) perProject = everyProject;
      }
    } catch (e) {
      debugPrint('[EditorPreferences] ${file.path} is unreadable, using the defaults: $e');
    }
    return EditorPreferences._(file, flight, importWorkers, marketplaceUrl, buildMode, buildKeep, buildCacheDir, perProject);
  }

  static const String fileName = 'editor_preferences.json';

  final File file;

  FlightCameraControlType _flightCameraControl;

  /// When W/A/S/D/Q/E fly the level viewport's camera.
  FlightCameraControlType get flightCameraControl => _flightCameraControl;

  /// How many files a batch import converts at once, each in its own
  /// background isolate: 1–[maxImportWorkers].
  int get importWorkers => _importWorkers;
  int _importWorkers;
  static const int defaultImportWorkers = 1;
  static const int maxImportWorkers = 4;

  void setImportWorkers(int value) {
    final clamped = value.clamp(1, maxImportWorkers);
    if (clamped == _importWorkers) return;
    _importWorkers = clamped;
    _save();
    notifyListeners();
  }

  /// The Lumina Marketplace server Window → Marketplace talks to; the local
  /// server by default.
  String get marketplaceUrl => _marketplaceUrl;
  String _marketplaceUrl;
  static const String defaultMarketplaceUrl = 'http://127.0.0.1:8787';

  /// An absolute http(s) URL with a host.
  static bool isValidMarketplaceUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty;
  }

  /// Returns false (and keeps the current URL) when [value] is not an
  /// http(s) URL.
  bool setMarketplaceUrl(String value) {
    if (!isValidMarketplaceUrl(value)) return false;
    final url = value.trim();
    if (url == _marketplaceUrl) return true;
    _marketplaceUrl = url;
    _save();
    notifyListeners();
    return true;
  }

  // General › Project Editor Builds.

  /// The mode project editors are built in: `release` (default) or `debug`
  /// (for plugin authors: asserts, and a debugger can attach).
  String get editorBuildMode => _editorBuildMode;
  String _editorBuildMode;
  static const String defaultEditorBuildMode = 'release';
  static const List<String> editorBuildModes = ['release', 'debug'];

  void setEditorBuildMode(String value) {
    if (!editorBuildModes.contains(value) || value == _editorBuildMode) return;
    _editorBuildMode = value;
    _save();
    notifyListeners();
  }

  /// How many project editor builds `Clean unused builds` keeps.
  int get editorBuildKeep => _editorBuildKeep;
  int _editorBuildKeep;
  static const int defaultEditorBuildKeep = 5;
  static const int maxEditorBuildKeep = 50;

  void setEditorBuildKeep(int value) {
    final clamped = value.clamp(1, maxEditorBuildKeep);
    if (clamped == _editorBuildKeep) return;
    _editorBuildKeep = clamped;
    _save();
    notifyListeners();
  }

  /// The project editor build cache; null = the platform default
  /// (`EditorBuildCache.defaultRoot`).
  String? get editorBuildCacheDir => _editorBuildCacheDir;
  String? _editorBuildCacheDir;

  void setEditorBuildCacheDir(String? value) {
    final v = (value == null || value.trim().isEmpty) ? null : value.trim();
    if (v == _editorBuildCacheDir) return;
    _editorBuildCacheDir = v;
    _save();
    notifyListeners();
  }

  /// Every project opens in its own project editor, built on its
  /// first open, even without code plugins. Off, a plugin-less project opens
  /// in this editor.
  bool get perProjectEditors => _perProjectEditors;
  bool _perProjectEditors;
  static const bool defaultPerProjectEditors = true;

  void setPerProjectEditors(bool value) {
    if (value == _perProjectEditors) return;
    _perProjectEditors = value;
    _save();
    notifyListeners();
  }

  void setFlightCameraControl(FlightCameraControlType value) {
    if (value == _flightCameraControl) return;
    _flightCameraControl = value;
    _save();
    notifyListeners();
  }

  void _save() {
    try {
      ConfigJsonFile(file).update(
        (current) => {
          ...?(current is Map<String, dynamic> ? current : null),
          'flightCameraControl': _flightCameraControl.name,
          'importWorkers': _importWorkers,
          'marketplaceUrl': _marketplaceUrl,
          'editorBuildMode': _editorBuildMode,
          'editorBuildKeep': _editorBuildKeep,
          'editorBuildCacheDir': _editorBuildCacheDir,
          'perProjectEditors': _perProjectEditors,
        },
        isValid: (value) => value is Map<String, dynamic>,
        pretty: true,
        onUnreadable: (keptAside, error) =>
            debugPrint('[EditorPreferences] ${file.path} was unreadable ($error); kept it as ${keptAside.path}'),
      );
    } catch (e) {
      debugPrint('[EditorPreferences] could not save ${file.path}: $e');
    }
  }
}

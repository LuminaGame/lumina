part of '../project_settings_view_model.dart';

/// A LEVEL asset available to the Maps & Modes pickers.
class LevelChoice {
  final String relativePath; // contents/levels/L_Main.lmas
  final String displayName;
  final Uint8List? thumbnail;
  const LevelChoice({required this.relativePath, required this.displayName, this.thumbnail});
}

/// One line of a packaging run's console, tagged with its source
/// (`Cook & Package [linux]`).
class PackagingLogLine {
  final DateTime at;
  final String level;
  final String source;
  final String message;
  const PackagingLogLine({required this.at, required this.level, required this.source, required this.message});

  /// The platform id a line belongs to, or null for run-wide lines.
  String? get target => RegExp(r'\[([a-z]+)\]$').firstMatch(source)?.group(1);
}

/// The last Package Project run over every ticked target.
class PackagingRunState {
  final bool isRunning;

  /// Per platform id: pending → running → ok / failed / unbuildable / cancelled.
  final Map<String, PackageTargetStatus> statuses;
  final Map<String, Duration> durations;

  /// Package folders of the targets that succeeded.
  final Map<String, String> packageDirs;

  /// Why a target was not built or failed.
  final Map<String, String> messages;

  /// Result of the whole run (null while running or before the first run).
  final BuildStepStatus? result;
  final String? stage;

  const PackagingRunState({
    this.isRunning = false,
    this.statuses = const {},
    this.durations = const {},
    this.packageDirs = const {},
    this.messages = const {},
    this.result,
    this.stage,
  });
}

/// Settings categories in display order. Keys are stable ids used by search,
/// validation badges and the navigation list.
class ProjectSettingsCategory {
  static const description = 'description';
  static const graphics = 'graphics';
  static const input = 'input';
  static const mapsAndModes = 'maps';
  static const physics = 'physics';
  static const packaging = 'packaging';
  static const userInterface = 'ui';

  static const all = [description, graphics, input, mapsAndModes, physics, packaging, userInterface];

  static String title(String id) {
    switch (id) {
      case description:
        return 'Description & Branding';
      case graphics:
        return 'Engine & Graphics';
      case input:
        return 'Input (Enhanced)';
      case mapsAndModes:
        return 'Maps & Modes';
      case physics:
        return 'Physics & Collision';
      case packaging:
        return 'Packaging & Target';
      case userInterface:
        return 'User Interface';
    }
    return id;
  }

  /// Searchable keywords per category (row labels) for the settings search.
  static const Map<String, List<String>> keywords = {
    description: ['project name', 'engine version', 'description', 'icon', 'app icon', 'icon background', 'logo', 'splash', 'tray'],
    graphics: ['quality preset', 'view distance', 'shadow', 'anti-aliasing', 'aa', 'post processing', 'texture', 'shading', 'target fps', 'vsync', 'frame rate', 'fullscreen', 'start fullscreen', 'window'],
    input: ['input action', 'mapping context', 'key', 'binding', 'axis', 'scale', 'digital', 'ia_'],
    mapsAndModes: ['editor startup map', 'game default map', 'default game mode', 'level', 'map'],
    physics: ['gravity', 'fixed timestep', 'physics', 'collision'],
    packaging: ['target platforms', 'windows', 'linux', 'macos', 'android', 'ios', 'web', 'package', 'build', 'output'],
    userInterface: ['widget library', 'umg', 'shadcn', 'flutter widgets', 'ui'],
  };
}

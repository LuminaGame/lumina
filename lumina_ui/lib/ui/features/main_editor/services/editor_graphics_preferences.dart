import 'dart:io';

import 'package:lumina/lumina.dart';

/// The graphics preference shared by the launcher and project editors.
class EditorGraphicsPreferences {
  EditorGraphicsPreferences({
    Directory? configDir,
    Map<String, String>? environment,
  }) : file = File(
         '${LuminaConfigDir.resolve(explicit: configDir).path}/launcher_settings.json',
       ),
       environment = environment ?? Platform.environment {
    try {
      final settings = ConfigJsonFile(file).read();
      final value = settings is Map ? settings['graphics_device'] : null;
      selected = value is String && value.trim().isNotEmpty
          ? value.trim()
          : null;
    } on ConfigFileUnreadableException {
      selected = null;
    }
  }

  final File file;
  final Map<String, String> environment;
  String? selected;
  List<LuminaGraphicsDevice> get devices => LuminaGraphicsDevices.list();
  String? get override => LuminaGraphicsDevices.describeOverride(environment);
  bool get isStale =>
      selected != null &&
      !devices.any((device) => device.name.contains(selected!));

  void select(String? value) {
    final name = value == null || value.trim().isEmpty ? null : value.trim();
    ConfigJsonFile(file).update(
      (settings) => {if (settings is Map) ...settings, 'graphics_device': name},
    );
    selected = name;
    apply();
  }

  /// Call before creating the editor's first render engine.
  void apply() => LuminaGraphicsDevices.usePreferred(
    isStale ? null : selected,
    environment: environment,
  );
}

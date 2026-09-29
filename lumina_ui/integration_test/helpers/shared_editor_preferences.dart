import 'dart:convert';
import 'dart:io';

import 'package:lumina_ui/ui/features/main_editor/services/editor_preferences.dart';

/// Turns per-project editors off in the launcher preferences stored in
/// [configDir], so opening a project stays in the running editor instead of
/// building and handing off to a per-project editor host. Smokes that are not
/// about that build call it before creating their `LauncherViewModel`.
void useSharedEditor(Directory configDir) {
  final file = File('${configDir.path}/${EditorPreferences.fileName}');
  final prefs = <String, dynamic>{};
  if (file.existsSync()) {
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is Map) prefs.addAll(decoded.cast<String, dynamic>());
  }
  prefs['perProjectEditors'] = false;
  file
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(jsonEncode(prefs));
}

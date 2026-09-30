import 'dart:io';

import 'package:lumina/lumina.dart';
import 'package:path/path.dart' as p;

import '../../../core/host/editor_host.dart';

/// The projects whose "Update this project's editor?" question the user
/// answered with "Don't ask again for this version", on this machine: per
/// project folder, the engine ([EngineIdentity.key]) not to ask about again.
/// A newer engine asks again. Kept in the config folder
/// (`project_editor_updates.json`), never in the shared `.lmproject`.
class ProjectEditorUpdatePrompts {
  ProjectEditorUpdatePrompts({this.configDir});

  final Directory? configDir;

  static const String fileName = 'project_editor_updates.json';

  File get file => File(p.join(LuminaConfigDir.resolve(explicit: configDir).path, fileName));

  /// One key per project folder, whatever the spelling of its path.
  static String projectKey(String projectDir) {
    final n = p.normalize(p.absolute(projectDir)).replaceAll(r'\', '/');
    return Platform.isWindows ? n.toLowerCase() : n;
  }

  Map<String, String> _read() {
    try {
      final json = ConfigJsonFile(file).read();
      if (json is! Map) return const {};
      return {for (final e in json.entries) '${e.key}': '${e.value}'};
    } on ConfigFileUnreadableException {
      return const {};
    }
  }

  /// Whether the user asked not to be asked about [engine] for [projectDir].
  bool isDismissed(String projectDir, EngineIdentity engine) => _read()[projectKey(projectDir)] == engine.key;

  /// Don't ask about [engine] for [projectDir] again.
  void dismiss(String projectDir, EngineIdentity engine) {
    ConfigJsonFile(file).update(
      (current) => {
        if (current is Map)
          for (final e in current.entries) '${e.key}': e.value,
        projectKey(projectDir): engine.key,
      },
      isValid: (v) => v is Map,
      pretty: true,
    );
  }
}

/// The last Lumina Studio (the stock editor) that started on this machine:
/// its executable, engine root and engine. A project editor started on its
/// own reads it to see whether a newer Studio is installed and to hand the
/// project to it (`lumina_studio.json` in the config folder).
class LuminaStudioRecord {
  final String executable;
  final String engineRoot;
  final EngineIdentity engine;

  const LuminaStudioRecord({required this.executable, required this.engineRoot, required this.engine});

  static const String fileName = 'lumina_studio.json';

  static File fileIn(Directory? configDir) => File(p.join(LuminaConfigDir.resolve(explicit: configDir).path, fileName));

  Map<String, Object?> toJson() => {
        'executable': executable,
        'engineRoot': engineRoot,
        'engine': engine.toJson(),
        'recordedAt': DateTime.now().toUtc().toIso8601String(),
      };

  /// The record; null when there is none or it is unreadable.
  static LuminaStudioRecord? read({Directory? configDir}) {
    try {
      final json = ConfigJsonFile(fileIn(configDir)).read();
      if (json is! Map) return null;
      final exe = json['executable'], root = json['engineRoot'];
      final engine = EngineIdentity.fromJson(json['engine']);
      if (exe is! String || exe.isEmpty || root is! String || root.isEmpty || engine == null) return null;
      return LuminaStudioRecord(executable: exe, engineRoot: root, engine: engine);
    } on ConfigFileUnreadableException {
      return null;
    }
  }

  void write({Directory? configDir}) => ConfigJsonFile(fileIn(configDir)).write(toJson(), pretty: true);

  /// Records the running stock editor, when it is one: the real `lumina_ui`
  /// binary, not a project editor and not a test run. Returns the record
  /// written, or null.
  static Future<LuminaStudioRecord?> recordThisStudio({Directory? configDir}) async {
    if (LuminaEditorHost.isProjectEditor || Platform.environment['FLUTTER_TEST'] == 'true') return null;
    final exe = Platform.resolvedExecutable;
    if (p.basenameWithoutExtension(exe) != 'lumina_ui') return null;
    final root = LuminaEditorHost.engineRoot;
    final record = LuminaStudioRecord(executable: exe, engineRoot: root, engine: await EngineIdentity.of(root));
    try {
      record.write(configDir: configDir);
    } on FileSystemException {
      return null;
    }
    return record;
  }
}

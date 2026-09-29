import 'dart:convert';
import 'dart:io';

/// A plugin's own data: JSON files in a per-user
/// directory (settings, downloads) and, while a project is open, a
/// per-project one (`<project>/.lumina/plugins/<pluginName>/`). Reached
/// through `LuminaEditorContext.storage`.
class PluginStorage {
  PluginStorage({required this.userDir, this.projectDir});

  final Directory userDir;

  /// Null while no project is open.
  final Directory? projectDir;

  /// The JSON object stored as [name] (`<name>.json`), or null when there is
  /// none. A file that is not a JSON object is a [FormatException] naming it.
  Future<Map<String, Object?>?> readJson(String name, {bool project = false}) async {
    final dir = project ? projectDir : userDir;
    if (dir == null) return null;
    final file = File('${dir.path}/${_fileName(name)}');
    if (!await file.exists()) return null;
    final text = await file.readAsString();
    try {
      final data = jsonDecode(text);
      if (data is Map<String, Object?>) return data;
      throw const FormatException('not a JSON object');
    } on FormatException catch (e) {
      throw FormatException('${file.path} is not a valid JSON object: ${e.message}');
    }
  }

  /// Stores [data] as [name] (`<name>.json`): written to a temp file, then
  /// renamed over the old one, so a crash never leaves half a file.
  Future<void> writeJson(String name, Map<String, Object?> data, {bool project = false}) async {
    final dir = project ? projectDir : userDir;
    final fileName = _fileName(name);
    if (dir == null) throw StateError('No project is open: cannot write $fileName to the project store');
    await dir.create(recursive: true);
    final target = File('${dir.path}/$fileName');
    final tmp = File('${target.path}.tmp');
    await tmp.writeAsString(const JsonEncoder.withIndent('  ').convert(data), flush: true);
    await tmp.rename(target.path);
  }

  static String _fileName(String name) {
    if (name.isEmpty || name.contains('/') || name.contains(r'\') || name.contains('..')) {
      throw ArgumentError.value(name, 'name', 'a file name, not a path');
    }
    return '$name.json';
  }
}

/// The open project, as a plugin's lifecycle hooks see it.
class EditorProjectInfo {
  const EditorProjectInfo({required this.name, required this.dir});

  final String name;

  /// The project folder (holding `<name>.lmproject`).
  final String dir;
}

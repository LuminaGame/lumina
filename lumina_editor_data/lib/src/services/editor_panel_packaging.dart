import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:lumina_core/lumina_core.dart';
import 'package:path/path.dart' as p;

/// Keeps editor panel Widget Blueprints out of a packaged game. `flutter
/// build` bundles the folders `pubspec.yaml` lists under `flutter: assets:`
/// (each folder's own files), and an editor panel may sit in any of them;
/// for the build, each listed folder holding a panel is replaced by its
/// other files, one entry each, so the panel never reaches the game.
abstract final class EditorPanelPackaging {
  /// The project-relative paths of every editor panel `.lmas` under
  /// `contents/`, read on a background isolate.
  static Future<List<String>> panelFiles(String projectDir) => Isolate.run(() => panelFilesSync(projectDir));

  /// [panelFiles] on the calling isolate (tests, CLI tools, isolates).
  static List<String> panelFilesSync(String projectDir) {
    final contents = Directory(p.join(projectDir, 'contents'));
    if (!contents.existsSync()) return const [];
    final out = <String>[];
    for (final f in contents.listSync(recursive: true, followLinks: false)) {
      if (f is! File || !f.path.toLowerCase().endsWith('.lmas')) continue;
      try {
        final payload = LuminaAsset.fromBytes(f.readAsBytesSync()).rawPayload;
        if (payload == null) continue;
        final json = jsonDecode(utf8.decode(payload));
        if (json is Map && LuminaEditorPanelInfo.isEditorPanelPayload(json.cast<String, dynamic>())) {
          out.add(p.relative(f.path, from: projectDir).replaceAll(r'\', '/'));
        }
      } on Object {
        // Not an asset this check can read: not a panel.
      }
    }
    out.sort();
    return out;
  }

  /// [pubspecYaml] with every asset folder entry that directly holds one of
  /// [panels] replaced by that folder's other files (read from
  /// [projectDir]); unchanged when no listed folder holds a panel.
  static String withoutPanels(String pubspecYaml, String projectDir, List<String> panels) {
    if (panels.isEmpty) return pubspecYaml;
    final panelSet = panels.toSet();
    final folders = {for (final panel in panels) '${p.posix.dirname(panel)}/'};
    final lines = const LineSplitter().convert(pubspecYaml);
    final out = <String>[];
    final entry = RegExp(r'^(\s*-\s+)(\S+)\s*$');
    for (final line in lines) {
      final m = entry.firstMatch(line);
      final folder = m?.group(2);
      if (m == null || folder == null || !folders.contains(folder.endsWith('/') ? folder : '$folder/')) {
        out.add(line);
        continue;
      }
      final dir = Directory(p.join(projectDir, folder));
      final files = <String>[
        if (dir.existsSync())
          for (final f in dir.listSync(followLinks: false))
            if (f is File) '$folder${p.basename(f.path)}'.replaceAll(r'\', '/'),
      ]..sort();
      for (final f in files) {
        if (!panelSet.contains(f)) out.add('${m.group(1)}$f');
      }
    }
    return '${out.join('\n')}\n';
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:lumina_editor_data/lumina_editor.dart' show LuminaDataDir;
import 'package:path/path.dart' as p;

/// The user's decisions to run a project's editor panels: per user
/// (`<LuminaDataDir>/editor_panel_trust.json`), keyed by the project's
/// absolute path and, per panel, by the hash of its capability list. A new
/// panel, a panel whose capabilities changed, or the same project at another
/// path asks again. Plugin panels never come here: they are trusted with
/// their plugin's own install / import / enable consent.
class EditorPanelTrustStore {
  EditorPanelTrustStore({File? file}) : file = file ?? File(p.join(LuminaDataDir.resolve().path, fileName));

  static const String fileName = 'editor_panel_trust.json';

  final File file;
  Map<String, Map<String, String>>? _projects;
  Future<void>? _loading;
  Future<void> _writes = Future.value();

  /// Reads the file once (async); later calls return at once.
  Future<void> load() => _loading ??= _read();

  Future<void> _read() async {
    final projects = <String, Map<String, String>>{};
    try {
      if (await file.exists()) {
        final json = jsonDecode(await file.readAsString());
        final raw = json is Map ? json['projects'] : null;
        if (raw is Map) {
          for (final e in raw.entries) {
            final panels = e.value;
            if (panels is Map) projects['${e.key}'] = {for (final x in panels.entries) '${x.key}': '${x.value}'};
          }
        }
      }
    } on Object {
      // An unreadable store trusts nothing; the next decision rewrites it.
    }
    _projects = projects;
  }

  static String _key(String projectDir) => p.normalize(p.absolute(projectDir)).replaceAll(r'\', '/');

  /// Whether the user trusted [panelPath] of the project at [projectDir] with
  /// exactly the capabilities hashed as [capabilityHash]. Call [load] first.
  bool isTrusted(String projectDir, String panelPath, String capabilityHash) =>
      _projects?[_key(projectDir)]?[panelPath] == capabilityHash;

  /// Records the user's "Trust and run" for [panels] (panel path →
  /// capability hash) and writes the file.
  Future<void> trust(String projectDir, Map<String, String> panels) async {
    await load();
    (_projects![_key(projectDir)] ??= {}).addAll(panels);
    await _save();
  }

  /// Forgets every decision for the project at [projectDir].
  Future<void> revoke(String projectDir) async {
    await load();
    _projects!.remove(_key(projectDir));
    await _save();
  }

  Future<void> _save() {
    final snapshot = jsonEncode({'version': 1, 'projects': _projects});
    return _writes = _writes.then((_) async {
      await file.parent.create(recursive: true);
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(snapshot, flush: true);
      await tmp.rename(file.path);
    });
  }
}

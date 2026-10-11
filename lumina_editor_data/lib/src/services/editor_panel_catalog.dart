import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:lumina_core/lumina_core.dart';
import 'package:path/path.dart' as p;

/// Where editor panels are looked for: the `content/` folder of an enabled
/// plugin that can contain content, or the open project's `contents/`.
class EditorPanelSource {
  /// The plugin's name, or [EditorPanelSource.projectOwner].
  final String owner;

  /// The plugin's friendly name, or `Project`.
  final String ownerTitle;

  /// The folder ids are relative to (the plugin's folder, or the project's).
  final String baseDir;

  /// The folder scanned (`<plugin>/content`, `<project>/contents`).
  final String scanDir;

  static const String projectOwner = 'project';

  const EditorPanelSource({required this.owner, required this.ownerTitle, required this.baseDir, required this.scanDir});

  /// The `content/` folder of the plugin in [pluginDir].
  factory EditorPanelSource.plugin({required String name, required String friendlyName, required String pluginDir}) =>
      EditorPanelSource(owner: name, ownerTitle: friendlyName, baseDir: pluginDir, scanDir: p.join(pluginDir, 'content'));

  /// The `contents/` folder of the project in [projectDir].
  factory EditorPanelSource.project(String projectDir) => EditorPanelSource(
      owner: projectOwner, ownerTitle: 'Project', baseDir: projectDir, scanDir: p.join(projectDir, 'contents'));

  bool get isProject => owner == projectOwner;

  Map<String, Object?> _toMessage() => {'owner': owner, 'ownerTitle': ownerTitle, 'baseDir': baseDir, 'scanDir': scanDir};

  static EditorPanelSource _fromMessage(Map<String, Object?> m) => EditorPanelSource(
      owner: m['owner'] as String,
      ownerTitle: m['ownerTitle'] as String,
      baseDir: m['baseDir'] as String,
      scanDir: m['scanDir'] as String);
}

/// One discovered editor panel asset.
class EditorPanelEntry {
  /// `<plugin name>/<asset path>` or `project/<asset path>`.
  final String id;
  final EditorPanelSource source;

  /// The asset path relative to the plugin's folder or the project
  /// (`content/EPW_PropTools.lmas`, `contents/editor/EPW_BatchRename.lmas`),
  /// `/`-separated: what `host.panelState` names.
  final String assetPath;

  /// The absolute `.lmas` path.
  final String filePath;

  /// The widget class (`EPW_PropTools`, the file's base name).
  final String className;

  /// The parsed `editorPanel` block, or null when it is malformed
  /// ([infoError] says why).
  final LuminaEditorPanelInfo? info;
  final String? infoError;

  /// The Widget Blueprint payload (designer tree + graph) as JSON.
  final Map<String, dynamic> payload;

  /// The file's modification time when read.
  final DateTime modified;

  /// The title shown in menus and tabs: the panel's title, suffixed with the
  /// plugin's friendly name when a project panel has the same title.
  final String displayTitle;

  const EditorPanelEntry({
    required this.id,
    required this.source,
    required this.assetPath,
    required this.filePath,
    required this.className,
    required this.info,
    required this.infoError,
    required this.payload,
    required this.modified,
    required this.displayTitle,
  });

  String get owner => source.owner;
  bool get isProjectPanel => source.isProject;

  EditorPanelEntry _withTitle(String title) => EditorPanelEntry(
        id: id,
        source: source,
        assetPath: assetPath,
        filePath: filePath,
        className: className,
        info: info,
        infoError: infoError,
        payload: payload,
        modified: modified,
        displayTitle: title,
      );
}

/// Finds the editor panel Widget Blueprints of the enabled content plugins
/// and the open project (assets whose payload has an `editorPanel` block),
/// reading and parsing them on a background isolate, and watches those
/// folders so a saved, added or removed panel reaches [changes] at once.
class EditorPanelCatalog {
  EditorPanelCatalog({this.debounce = const Duration(milliseconds: 60)});

  final Duration debounce;

  List<EditorPanelSource> _sources = const [];
  List<EditorPanelEntry> _entries = const [];
  final Map<String, StreamSubscription<FileSystemEvent>> _watches = {};
  final StreamController<List<EditorPanelEntry>> _changes = StreamController.broadcast();
  Timer? _pending;
  int _generation = 0;
  bool _disposed = false;

  /// The panels found by the last scan.
  List<EditorPanelEntry> get entries => _entries;

  /// The sources being scanned.
  List<EditorPanelSource> get sources => _sources;

  /// Every completed rescan's result.
  Stream<List<EditorPanelEntry>> get changes => _changes.stream;

  EditorPanelEntry? entry(String id) {
    for (final e in _entries) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// The editor panels in [sources], read once off the UI isolate (an
  /// imported plugin's panels for its confirmation).
  static Future<List<EditorPanelEntry>> scanOnce(List<EditorPanelSource> sources) async {
    final messages = [for (final s in sources) s._toMessage()];
    final raw = await Isolate.run(() => _scan(messages));
    return _titled([for (final m in raw) _entryOf(m)]);
  }

  /// Scans [sources] (replacing the previous set) and watches them.
  Future<List<EditorPanelEntry>> setSources(List<EditorPanelSource> sources) async {
    _sources = List.unmodifiable(sources);
    _rewatch();
    return refresh();
  }

  /// Rescans now (off the UI isolate).
  Future<List<EditorPanelEntry>> refresh() async {
    final generation = ++_generation;
    final messages = [for (final s in _sources) s._toMessage()];
    final raw = await Isolate.run(() => _scan(messages));
    if (_disposed || generation != _generation) return _entries;
    _entries = _titled([for (final m in raw) _entryOf(m)]);
    if (!_changes.isClosed) _changes.add(_entries);
    return _entries;
  }

  void _rewatch() {
    for (final w in _watches.values) {
      unawaited(w.cancel());
    }
    _watches.clear();
    for (final s in _sources) {
      final dir = Directory(s.scanDir);
      try {
        _watches[s.scanDir] = dir.watch(recursive: true).listen((e) {
          if (e.path.toLowerCase().endsWith('.lmas') || e is FileSystemDeleteEvent || e is FileSystemMoveEvent) _schedule();
        }, onError: (Object _) {});
      } on FileSystemException {
        // A folder the platform cannot watch: refresh() still finds its panels.
      }
    }
  }

  void _schedule() {
    _pending?.cancel();
    _pending = Timer(debounce, () => unawaited(refresh()));
  }

  void dispose() {
    _disposed = true;
    _pending?.cancel();
    for (final w in _watches.values) {
      unawaited(w.cancel());
    }
    _watches.clear();
    unawaited(_changes.close());
  }

  /// Plugin panels whose title a project panel also has get the plugin's
  /// friendly name as a suffix.
  static List<EditorPanelEntry> _titled(List<EditorPanelEntry> entries) {
    final projectTitles = {
      for (final e in entries)
        if (e.isProjectPanel) e.displayTitle,
    };
    return [
      for (final e in entries)
        !e.isProjectPanel && projectTitles.contains(e.displayTitle) ? e._withTitle('${e.displayTitle} (${e.source.ownerTitle})') : e,
    ];
  }

  static EditorPanelEntry _entryOf(Map<String, Object?> m) {
    final source = EditorPanelSource._fromMessage((m['source'] as Map).cast());
    final payload = (m['payload'] as Map).cast<String, dynamic>();
    LuminaEditorPanelInfo? info;
    String? error;
    try {
      info = LuminaEditorPanelInfo.ofPayload(payload);
    } on FormatException catch (e) {
      error = e.message;
    }
    final className = m['className'] as String;
    return EditorPanelEntry(
      id: '${source.owner}/${m['assetPath']}',
      source: source,
      assetPath: m['assetPath'] as String,
      filePath: m['filePath'] as String,
      className: className,
      info: info,
      infoError: error,
      payload: payload,
      modified: DateTime.fromMillisecondsSinceEpoch(m['modified'] as int),
      displayTitle: info?.title ?? className,
    );
  }
}

/// Runs on a background isolate: every `.lmas` under each source whose
/// payload carries an `editorPanel` block.
List<Map<String, Object?>> _scan(List<Map<String, Object?>> sources) {
  final out = <Map<String, Object?>>[];
  for (final s in sources) {
    final dir = Directory(s['scanDir'] as String);
    if (!dir.existsSync()) continue;
    final files = <File>[];
    try {
      for (final f in dir.listSync(recursive: true, followLinks: false)) {
        if (f is File && f.path.toLowerCase().endsWith('.lmas')) files.add(f);
      }
    } on FileSystemException {
      continue;
    }
    files.sort((a, b) => a.path.compareTo(b.path));
    for (final f in files) {
      try {
        final asset = LuminaAsset.fromBytes(f.readAsBytesSync());
        final raw = asset.rawPayload;
        if (raw == null) continue;
        final payload = jsonDecode(utf8.decode(raw));
        if (payload is! Map || !LuminaEditorPanelInfo.isEditorPanelPayload(payload.cast<String, dynamic>())) continue;
        final rel = p.relative(f.path, from: s['baseDir'] as String).replaceAll(r'\', '/');
        out.add({
          'source': s,
          'assetPath': rel,
          'filePath': f.path,
          'className': p.basenameWithoutExtension(f.path),
          'payload': payload,
          'modified': f.lastModifiedSync().millisecondsSinceEpoch,
        });
      } on Object {
        // Not a readable asset (being written, another format): skipped.
      }
    }
  }
  return out;
}

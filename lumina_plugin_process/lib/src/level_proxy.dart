import 'dart:async';

import 'package:lumina_core/lumina_core.dart' show ChangeEmitter, ChangeSignal;
import 'package:lumina_plugin_protocol/lumina_plugin_protocol.dart';

import 'package:lumina_plugin_process/src/editor_level.dart';
import 'package:lumina_plugin_process/src/level_json.dart';

/// [PluginLevelAccess] in a plugin process: every member is a `host.level`
/// request to the editor, which makes the edit as an undoable transaction
/// of its own level, exactly as for an in-process plugin.
///
/// The synchronous getters ([actors], [selectedActorIds], [undoTopLabel],
/// [activeLevelPath], [projectDirPath]) answer from the last `snapshot` the
/// proxy fetched: after the handshake, after each of its own edits, and on
/// every `core.levelChanged` notification, before [changes] fires. The
/// synchronous edits ([removeActors], [setComponentProperty],
/// [selectActors]) update that copy at once, send the request and fetch a
/// fresh snapshot when it is answered; a failure is written to the editor's
/// log. A labelled synchronous edit made outside a transaction becomes the
/// [undoTopLabel] at once. [undoIfTop] answers from that label and the
/// editor checks it again before undoing.
///
/// [runTransaction] brackets [body] with `beginTransaction` /
/// `endTransaction`; every edit made inside it carries the transaction id,
/// so the editor records them as one undo step. A call inside another
/// joins it.
class PluginLevelProxy extends ChangeEmitter implements PluginLevelAccess {
  PluginLevelProxy(this._connection, {required this.onError});

  final PluginConnection _connection;

  /// Reports a failed fire-and-forget edit (the process writes it to the
  /// editor log).
  final void Function(String message) onError;

  /// Edits that load files (meshes, levels) get longer than the default
  /// proxy timeout.
  static const Duration longTimeout = Duration(seconds: 60);

  static final Object _txKey = Object();

  String _projectDir = '';
  String _activeLevel = '';
  List<EditorActorSnapshot> _actors = const [];
  List<String> _selected = const [];
  String? _undoTop;
  bool _disposed = false;

  @override
  String get projectDirPath => _projectDir;

  @override
  String get activeLevelPath => _activeLevel;

  @override
  ChangeSignal get changes => this;

  @override
  List<EditorActorSnapshot> get actors => List.unmodifiable(_actors);

  @override
  List<String> get selectedActorIds => List.unmodifiable(_selected);

  @override
  String? get undoTopLabel => _undoTop;

  /// The open transaction's id in this zone, or null.
  Object? get _tx => Zone.current[_txKey];

  Future<Object?> _op(String op, [Map<String, Object?> args = const {}, Duration? timeout]) {
    final tx = _tx;
    return _connection.request(PluginMethods.level, {'op': op, ...args, 'tx': ?tx}, timeout);
  }

  /// Fetches the editor's level state into the synchronous getters. With no
  /// level open (or no answer) they read empty.
  Future<void> refresh() async {
    Object? r;
    try {
      r = await _op('snapshot');
    } on PluginRemoteError {
      r = null;
    }
    if (r is! Map) {
      _projectDir = '';
      _activeLevel = '';
      _actors = const [];
      _selected = const [];
      _undoTop = null;
      return;
    }
    _projectDir = r['projectDirPath'] as String? ?? '';
    _activeLevel = r['activeLevelPath'] as String? ?? '';
    _actors = [
      for (final a in (r['actors'] as List?) ?? const []) EditorLevelJson.snapshotFromJson((a as Map).cast()),
    ];
    _selected = [...((r['selectedActorIds'] as List?) ?? const []).cast<String>()];
    _undoTop = r['undoTopLabel'] as String?;
  }

  /// The editor said the level changed: refresh, then notify [changes].
  Future<void> levelChanged() async {
    await refresh();
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _refreshAndNotify() async {
    await refresh();
    _notify();
  }

  /// Sends an edit the API declares synchronous; refreshes when answered.
  void _fire(String op, Map<String, Object?> args) {
    final label = args['label'];
    if (label is String && _tx == null) _undoTop = label;
    _notify();
    _op(op, args).then((_) => _refreshAndNotify(), onError: (Object e) {
      onError('level $op failed: ${e is PluginRemoteError ? e.message : e}');
      return _refreshAndNotify();
    });
  }

  @override
  Future<List<String>> addActors(List<EditorActorSpec> specs, {String? label}) async {
    final r = await _op(
      'addActors',
      {'actors': [for (final s in specs) EditorLevelJson.specToJson(s)], 'label': label},
      longTimeout,
    );
    await _refreshAndNotify();
    return [...((r as List?) ?? const []).cast<String>()];
  }

  @override
  Future<T> runTransaction<T>(String label, Future<T> Function() body) async {
    if (_tx != null) return body();
    final r = await _op('beginTransaction', {'label': label});
    final tx = r is Map ? r['tx'] : null;
    if (tx == null) throw StateError('the editor did not open a level transaction for "$label"');
    try {
      return await runZoned(body, zoneValues: {_txKey: tx});
    } finally {
      try {
        await _op('endTransaction', {'tx': tx});
      } on PluginRemoteError catch (e) {
        onError('level endTransaction failed: ${e.message}');
      }
      await _refreshAndNotify();
    }
  }

  @override
  bool undoIfTop(String label) {
    if (_undoTop != label) return false;
    _undoTop = null;
    _fire('undoIfTop', {'label': label});
    return true;
  }

  @override
  void removeActors(Iterable<String> ids, {String? label}) {
    final gone = ids.toSet();
    var grew = true;
    while (grew) {
      grew = false;
      for (final a in _actors) {
        if (a.parentId != null && gone.contains(a.parentId) && gone.add(a.id)) grew = true;
      }
    }
    _actors = [for (final a in _actors) if (!gone.contains(a.id)) a];
    _selected = [for (final id in _selected) if (!gone.contains(id)) id];
    _fire('removeActors', {'ids': ids.toList(), 'label': label});
  }

  @override
  void setComponentProperty(String actorId, String componentType, String propertyId, Object? value, {String? label}) {
    _actors = [
      for (final a in _actors)
        if (a.id != actorId) a else _withProperty(a, componentType, propertyId, value),
    ];
    _fire('setComponentProperty', {
      'actorId': actorId,
      'componentId': componentType,
      'componentType': componentType,
      'name': propertyId,
      'value': value,
      'label': label,
    });
  }

  static EditorActorSnapshot _withProperty(EditorActorSnapshot a, String type, String name, Object? value) {
    var done = false;
    final components = <EditorComponentSnapshot>[];
    for (final c in a.components) {
      if (done || c.type != type) {
        components.add(c);
        continue;
      }
      done = true;
      components.add(EditorComponentSnapshot(
        id: c.id,
        type: c.type,
        name: c.name,
        enabled: c.enabled,
        properties: {...c.properties, name: value},
      ));
    }
    return EditorActorSnapshot(
      id: a.id,
      name: a.name,
      type: a.type,
      parentId: a.parentId,
      location: a.location,
      rotation: a.rotation,
      scale: a.scale,
      isVisible: a.isVisible,
      meshAssetPath: a.meshAssetPath,
      components: components,
    );
  }

  @override
  void selectActors(Iterable<String> ids) {
    _selected = ids.toList();
    _fire('selectActors', {'ids': _selected});
  }

  @override
  Future<void> saveLevel() async {
    final ok = await _op('saveLevel', const {}, longTimeout);
    await _refreshAndNotify();
    if (ok == false) throw StateError('the editor could not save the level');
  }

  @override
  void openAssetEditor(String assetPath) {
    _op('openAssetEditor', {'path': assetPath}).catchError((Object e) {
      onError('openAssetEditor failed: ${e is PluginRemoteError ? e.message : e}');
      return null;
    });
  }

  @override
  Future<bool> openLevel(String relativePath, {bool show = true}) async {
    final ok = await _op('openLevel', {'path': relativePath, 'show': show}, longTimeout);
    await _refreshAndNotify();
    return ok == true;
  }

  @override
  void log(String message, {String level = 'info', String source = 'Plugin'}) {
    _connection.notify(PluginMethods.log, {'level': level, 'message': message, 'source': source});
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

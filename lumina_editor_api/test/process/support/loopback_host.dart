import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:lumina_editor_api/lumina_editor_api.dart';

/// The editor's side of a plugin process link, for tests: a real loopback
/// `ServerSocket` and a [PluginConnection] that answers the handshake, takes
/// the contributions and serves `host.*` requests the way the editor does,
/// against a small level kept here ([HostLevel]) and real directories.
class LoopbackHost {
  LoopbackHost._(this._server, this.root, this.token, this.answerVersion, this.project);

  /// Binds a port and waits for one plugin process. [root] holds the
  /// per-user store, the project and saved assets.
  static Future<LoopbackHost> start({
    String token = 'token-1',
    int answerVersion = kPluginProtocolVersion,
    bool withProject = true,
    Map<String, Object?> settings = const {'density': 3},
  }) async {
    final root = await Directory.systemTemp.createTemp('lmpp_');
    final projectDir = Directory('${root.path}/Proj');
    await Directory('${projectDir.path}/contents/levels').create(recursive: true);
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final host = LoopbackHost._(
      server,
      root,
      token,
      answerVersion,
      withProject ? EditorProjectInfo(name: 'Proj', dir: projectDir.path) : null,
    );
    host.settings = settings;
    late final StreamSubscription<Socket> sub;
    sub = server.listen((socket) {
      sub.cancel();
      host._accept(socket);
    });
    return host;
  }

  final ServerSocket _server;
  final Directory root;
  final String token;
  final int answerVersion;
  final EditorProjectInfo? project;
  Map<String, Object?> settings = const {};

  late final PluginConnection connection;
  final Completer<PluginConnection> _connected = Completer();
  final Completer<PluginContributions> _contributions = Completer();
  final HostLevel level = HostLevel();

  /// Every notification the process sent, in order.
  final List<PluginNotification> notifications = [];
  final StreamController<PluginNotification> _notes = StreamController.broadcast();
  final Set<PluginNotification> _consumed = {};

  /// `host.*` requests other than the level, in order (`method`, args).
  final List<(String, Map<String, Object?>)> requests = [];
  Map<String, Object?>? helloArgs;

  Future<PluginConnection> get connected => _connected.future;
  Future<PluginContributions> get contributions => _contributions.future;

  String get userDir => '${root.path}/user';
  String? get projectStoreDir => project == null ? null : '${project!.dir}/.lumina/plugins/sample';

  PluginProcessLaunch launch(String pluginName, {String? token}) => PluginProcessLaunch(
        pluginName: pluginName,
        port: _server.port,
        token: token ?? this.token,
        projectDir: project?.dir,
      );

  void _accept(Socket socket) {
    connection = PluginConnection(input: socket, output: socket);
    final c = connection;
    c.onRequest(PluginMethods.hello, (args) {
      helloArgs = args;
      if (args['token'] != token) {
        throw const PluginRemoteError(code: PluginErrorCodes.unauthorized, message: 'wrong token');
      }
      if (args['v'] != kPluginProtocolVersion) {
        throw const PluginRemoteError(code: PluginErrorCodes.unsupportedVersion, message: 'wrong version');
      }
      return {
        'v': answerVersion,
        'project': project == null ? null : {'name': project!.name, 'dir': project!.dir},
        'settings': settings,
        'userDir': userDir,
        'projectDir': projectStoreDir,
      };
    });
    c.onRequest(PluginMethods.register, (args) {
      _contributions.complete(PluginContributions.fromJson(args));
      return null;
    });
    c.onRequest(PluginMethods.level, (args) => level.handle(args, project?.dir ?? ''));
    c.onRequest(PluginMethods.saveAsset, (args) async {
      requests.add((PluginMethods.saveAsset, args));
      final file = File('${project!.dir}/${args['relativePath']}');
      await file.parent.create(recursive: true);
      final b64 = args['bytesBase64'] as String?;
      if (b64 != null) await file.writeAsBytes(base64Decode(b64));
      return null;
    });
    for (final m in [PluginMethods.panels, PluginMethods.tabs]) {
      c.onRequest(m, (args) {
        requests.add((m, args));
        return args['op'] == 'isVisible' ? true : null;
      });
    }
    c.onRequest(PluginMethods.mcpCall, (args) {
      requests.add((PluginMethods.mcpCall, args));
      return McpToolResult.json({'tool': args['tool'], 'echo': args['arguments']}).toJson();
    });
    for (final m in [
      PluginMethods.log,
      PluginMethods.event,
      PluginMethods.progress,
      PluginMethods.view,
      PluginMethods.slotState,
      PluginMethods.menuChecked,
    ]) {
      c.onNotification(m, (args) {
        final n = PluginNotification(method: m, args: args);
        notifications.add(n);
        _notes.add(n);
      });
    }
    _connected.complete(c);
  }

  /// The first notification of [method] (matching [where]) not returned
  /// before; waits for it when it has not arrived yet.
  Future<Map<String, Object?>> next(String method, {bool Function(Map<String, Object?> args)? where}) {
    bool match(PluginNotification n) =>
        n.method == method && !_consumed.contains(n) && (where == null || where(n.args));
    for (final n in notifications) {
      if (match(n)) {
        _consumed.add(n);
        return Future.value(n.args);
      }
    }
    return _notes.stream.firstWhere(match).then((n) {
      _consumed.add(n);
      return n.args;
    }).timeout(const Duration(seconds: 10));
  }

  /// Sends [method] to the process and returns its answer.
  Future<Object?> call(String method, [Map<String, Object?> args = const {}]) => connection.request(method, args);

  Future<void> close() async {
    await _server.close();
    if (_connected.isCompleted) await connection.close();
    await _notes.close();
    try {
      await root.delete(recursive: true);
    } on FileSystemException {
      // a file still open on Windows; the temp folder is cleaned later
    }
  }
}

/// The level the test host keeps: actors, selection and an undo stack of
/// labelled steps, each step holding the edits it groups.
class HostLevel {
  final List<EditorActorSnapshot> actors = [];
  List<String> selected = [];
  String active = 'contents/levels/L_Main.lmas';

  /// The undo stack: (label, edit ops).
  final List<(String, List<String>)> undo = [];
  final Map<int, (String, List<String>)> _open = {};
  int _nextTx = 1;
  int _nextId = 1;
  final List<Map<String, Object?>> received = [];

  void _record(Map<String, Object?> args, String op) {
    final tx = args['tx'];
    if (tx is int && _open.containsKey(tx)) {
      _open[tx]!.$2.add(op);
    } else {
      undo.add((args['label'] as String? ?? op, [op]));
    }
  }

  Future<Object?> handle(Map<String, Object?> args, String projectDir) async {
    received.add(args);
    final op = args['op'];
    switch (op) {
      case 'snapshot':
        return {
          'projectDirPath': projectDir,
          'activeLevelPath': active,
          'actors': [for (final a in actors) EditorLevelJson.snapshotToJson(a)],
          'selectedActorIds': selected,
          'undoTopLabel': undo.isEmpty ? null : undo.last.$1,
        };
      case 'beginTransaction':
        final tx = _nextTx++;
        _open[tx] = (args['label'] as String, []);
        return {'tx': tx};
      case 'endTransaction':
        final step = _open.remove(args['tx']);
        if (step != null && step.$2.isNotEmpty) undo.add(step);
        return null;
      case 'addActors':
        final ids = <String>[];
        for (final j in (args['actors'] as List)) {
          final s = EditorLevelJson.specFromJson((j as Map).cast());
          final id = s.id ?? 'actor_${_nextId++}';
          actors.add(EditorActorSnapshot(
            id: id,
            name: s.name,
            type: s.type,
            parentId: s.parentId,
            location: s.location,
            rotation: s.rotation,
            scale: s.scale,
            meshAssetPath: s.meshAssetPath,
            components: [
              for (final c in s.components)
                EditorComponentSnapshot(id: '${id}_${c.type}', type: c.type, name: c.name, properties: c.properties),
            ],
          ));
          ids.add(id);
        }
        _record(args, 'addActors');
        return ids;
      case 'removeActors':
        final ids = (args['ids'] as List).cast<String>().toSet();
        actors.removeWhere((a) => ids.contains(a.id) || ids.contains(a.parentId));
        _record(args, 'removeActors');
        return null;
      case 'setComponentProperty':
        final i = actors.indexWhere((a) => a.id == args['actorId']);
        final a = actors[i];
        actors[i] = EditorActorSnapshot(
          id: a.id,
          name: a.name,
          type: a.type,
          location: a.location,
          rotation: a.rotation,
          scale: a.scale,
          components: [
            for (final c in a.components)
              c.type == args['componentType']
                  ? EditorComponentSnapshot(
                      id: c.id,
                      type: c.type,
                      name: c.name,
                      properties: {...c.properties, args['name'] as String: args['value']},
                    )
                  : c,
          ],
        );
        _record(args, 'setComponentProperty');
        return null;
      case 'selectActors':
        selected = (args['ids'] as List).cast<String>();
        return null;
      case 'undoIfTop':
        if (undo.isEmpty || undo.last.$1 != args['label']) return false;
        undo.removeLast();
        return true;
      case 'saveLevel':
        final file = File('$projectDir/$active');
        await file.writeAsString(jsonEncode({
          'actors': [for (final a in actors) EditorLevelJson.snapshotToJson(a)],
        }));
        return true;
      case 'openLevel':
        final path = args['path'] as String;
        if (!await File('$projectDir/$path').exists()) return false;
        active = path;
        return true;
      case 'openAssetEditor':
        return true;
      default:
        throw PluginRemoteError(code: PluginErrorCodes.badArguments, message: 'unknown level op $op');
    }
  }
}

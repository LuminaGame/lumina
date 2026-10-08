/// The protocol version both sides speak. A `hello` with another version is
/// refused with [PluginErrorCodes.unsupportedVersion].
const int kPluginProtocolVersion = 1;

/// One message on the wire: `{"t": <type>, ...}`.
///
/// - `req`: `{"t":"req","id":<int>,"m":<method>,"a":<args object>}`; the other
///   side answers with exactly one `res` carrying the same id.
/// - `res`: `{"t":"res","id":<int>,"ok":true,"r":<result>}` or
///   `{"t":"res","id":<int>,"ok":false,"e":{"code":<string>,"message":<string>,"stack":<string?>}}`.
/// - `ntf`: `{"t":"ntf","m":<method>,"a":<args object>}`; no answer.
///
/// Ids are per sender; both sides number their own requests from 1.
sealed class PluginMessage {
  const PluginMessage();

  Map<String, Object?> toJson();

  static PluginMessage fromJson(Map<String, Object?> json) {
    switch (json['t']) {
      case 'req':
        return PluginRequest(
          id: _int(json['id'], 'id'),
          method: _string(json['m'], 'm'),
          args: _map(json['a']),
        );
      case 'res':
        final id = _int(json['id'], 'id');
        if (json['ok'] == true) return PluginResponse.ok(id, json['r']);
        final e = _map(json['e']);
        return PluginResponse.error(
          id,
          PluginRemoteError(
            code: e['code'] as String? ?? PluginErrorCodes.internal,
            message: e['message'] as String? ?? '',
            stack: e['stack'] as String?,
          ),
        );
      case 'ntf':
        return PluginNotification(method: _string(json['m'], 'm'), args: _map(json['a']));
      default:
        throw FormatException('unknown plugin protocol message type ${json['t']}');
    }
  }

  static int _int(Object? v, String key) =>
      v is int ? v : throw FormatException('plugin protocol message: "$key" is not an integer');
  static String _string(Object? v, String key) =>
      v is String && v.isNotEmpty ? v : throw FormatException('plugin protocol message: "$key" is not a string');
  static Map<String, Object?> _map(Object? v) => v is Map ? v.cast<String, Object?>() : <String, Object?>{};
}

final class PluginRequest extends PluginMessage {
  const PluginRequest({required this.id, required this.method, this.args = const {}});

  final int id;
  final String method;
  final Map<String, Object?> args;

  @override
  Map<String, Object?> toJson() => {'t': 'req', 'id': id, 'm': method, 'a': args};
}

final class PluginResponse extends PluginMessage {
  const PluginResponse.ok(this.id, this.result) : error = null;
  const PluginResponse.error(this.id, PluginRemoteError this.error) : result = null;

  final int id;
  final Object? result;
  final PluginRemoteError? error;

  bool get ok => error == null;

  @override
  Map<String, Object?> toJson() => ok
      ? {'t': 'res', 'id': id, 'ok': true, 'r': result}
      : {'t': 'res', 'id': id, 'ok': false, 'e': error!.toJson()};
}

final class PluginNotification extends PluginMessage {
  const PluginNotification({required this.method, this.args = const {}});

  final String method;
  final Map<String, Object?> args;

  @override
  Map<String, Object?> toJson() => {'t': 'ntf', 'm': method, 'a': args};
}

/// An error the other side answered a request with (or a local failure of
/// the call: timeout, closed connection).
class PluginRemoteError implements Exception {
  const PluginRemoteError({required this.code, required this.message, this.stack});

  final String code;
  final String message;
  final String? stack;

  Map<String, Object?> toJson() => {'code': code, 'message': message, if (stack != null) 'stack': stack};

  @override
  String toString() => 'PluginRemoteError($code): $message';
}

abstract final class PluginErrorCodes {
  /// No handler for the method.
  static const String unknownMethod = 'unknown_method';

  /// The handler threw.
  static const String handlerFailed = 'handler_failed';

  /// The call did not get an answer in time (local).
  static const String timeout = 'timeout';

  /// The connection closed before the answer (local).
  static const String closed = 'closed';

  /// The hello's protocol version is not [kPluginProtocolVersion].
  static const String unsupportedVersion = 'unsupported_version';

  /// The hello's token did not match.
  static const String unauthorized = 'unauthorized';

  /// Arguments missing or of the wrong type.
  static const String badArguments = 'bad_arguments';

  /// The plugin process is not running (host side, for a shell's call).
  static const String unavailable = 'unavailable';

  /// The request or its answer does not fit in one frame
  /// ([PluginFrameCodec.maxPayload]); the link stays up.
  static const String tooLarge = 'too_large';

  static const String internal = 'internal';
}

/// The method names of the protocol. `host.*` are requests and notifications
/// the plugin process sends to the host; `core.*` the ones the host sends to
/// the plugin process. Arguments are JSON objects; the shapes are documented
/// per constant.
abstract final class PluginMethods {
  // --- handshake ------------------------------------------------------------

  /// Process → host request, the first message:
  /// `{"v": kPluginProtocolVersion, "plugin": <name>, "token": <token>, "pid": <int>}`.
  /// Answer: `{"v": kPluginProtocolVersion, "project": {"name","dir"}|null, "settings": {...}, "userDir": <path>, "projectDir": <path>|null}`,
  /// the last two being the PluginStorage directories, plus `"pluginDir": <path>|null`, the folder the
  /// plugin is installed in (its `.lmplugin`), where it finds files it ships (executables, models).
  static const String hello = 'host.hello';

  /// Process → host request, once after [hello]: `PluginContributions.toJson()`.
  /// Answer: null. Contributions can be registered once per process run.
  static const String register = 'host.register';

  // --- process → host notifications -----------------------------------------

  /// `{"name": <event>, "data": <json>}`: delivered to the shell's
  /// `PluginProcessChannel.events`.
  static const String event = 'host.event';

  /// `{"task": <id>, "step": <label>, "done": <int|null>, "total": <int|null>, "message": <string|null>, "finished": <bool>}`
  static const String progress = 'host.progress';

  /// `{"level": "info"|"warning"|"error"|"success", "message": <string>}`,
  /// optionally `"source": <string>` (the Output Log source an
  /// `EditorLevelAccess.log` call names; the plugin's name otherwise).
  static const String log = 'host.log';

  /// `{"viewId": <id>, "spec": PluginViewSpec.toJson()}` or
  /// `{"viewId": <id>, "patch": PluginViewPatch.toJson()}`.
  static const String view = 'host.view';

  /// `{"id": <slot button id>, "state": PluginButtonStateSpec.toJson()}`.
  static const String slotState = 'host.slotState';

  /// `{"path": <menu path>, "checked": <bool>}` for a menu item registered
  /// with a check mark.
  static const String menuChecked = 'host.menuChecked';

  // --- process → host requests (proxies) -----------------------------------

  /// `{"op": <EditorLevelAccess member>, ...}` → its result as JSON. The ops:
  /// `snapshot` → `{"projectDirPath","activeLevelPath","actors":[...],"selectedActorIds":[...]}`,
  /// `addActors` `{"actors":[EditorActorSpec json],"label"}` → `[ids]`,
  /// `removeActors` `{"ids","label"}`, `setComponentProperty`
  /// `{"actorId","componentId","name","value","label"}`, `selectActors` `{"ids"}`,
  /// `undoIfTop` `{"label"}` → bool, `saveLevel` → bool, `openLevel` `{"path"}` → bool,
  /// `openAssetEditor` `{"path"}` → bool, `beginTransaction` `{"label"}` → `{"tx": <id>}`,
  /// `endTransaction` `{"tx"}`.
  ///
  /// Additions (all optional, older peers ignore them):
  /// - `snapshot` also answers `"undoTopLabel": <string|null>` (the label
  ///   Edit ▸ Undo would revert, `EditorLevelAccess.undoTopLabel`); it answers
  ///   null when no level is open.
  /// - Actor JSON: `actors[]` are actor snapshots and `addActors.actors[]`
  ///   actor specs in the shapes `EditorLevelJson` (lumina_editor_api)
  ///   documents and encodes.
  /// - Every edit op (`addActors`, `removeActors`, `setComponentProperty`,
  ///   `selectActors`, `undoIfTop`, `saveLevel`, `openLevel`,
  ///   `openAssetEditor`) may carry `"tx": <id>` from `beginTransaction`: the
  ///   edit joins that open transaction (one undo step). The host ends a
  ///   transaction left open when the connection closes.
  /// - `setComponentProperty`: `componentId` carries the component **type**
  ///   (`EditorLevelAccess.setComponentProperty` addresses the first
  ///   component of a type); the same value is sent as `componentType`.
  /// - `openLevel` also takes `"show": <bool>` (default true).
  /// - `openAssetEditor` answers bool (or null).
  static const String level = 'host.level';

  /// `{"relativePath", "bytesBase64"?, "generateThumbnail"}` → null.
  static const String saveAsset = 'host.saveAsset';

  /// `{"op": "show"|"hide"|"isVisible", "panelId"}` → bool for isVisible.
  static const String panels = 'host.panels';

  /// `{"op": "openTab", "tabId", "title"?}` → null.
  static const String tabs = 'host.tabs';

  /// `{"tool", "arguments"}` → `McpToolResult.toJson()` of an editor MCP tool.
  static const String mcpCall = 'host.mcp.call';

  // --- host → process requests ----------------------------------------------

  /// Health check, every 2 s: `{}` → `{}`.
  static const String ping = 'core.ping';

  /// A shell's `PluginProcessChannel.call`: `{"method", "args"}` → the handler's
  /// JSON result.
  static const String call = 'core.call';

  /// A menu item / slot button / slot menu entry: `{"commandId"}` → null.
  static const String command = 'core.command';

  /// Whether a command can execute now: `{"commandId"}` → bool.
  static const String canExecute = 'core.canExecute';

  /// An MCP tool call: `{"tool", "arguments"}` → `McpToolResult.toJson()`.
  /// `tool` is the name the tool was registered with, or the host's
  /// `<plugin>.<name>`. Arguments the tool rejects (`JsonRpcException`)
  /// answer the error [PluginErrorCodes.badArguments]; a handler that throws
  /// answers an error result (`isError: true`).
  static const String mcpTool = 'core.mcpTool';

  /// An importer: `{"importerId", "sourcePath", "targetDirectory"}` →
  /// `{"success": bool, "assetPath"?, "error"?}`.
  static const String import = 'core.import';

  /// A console command: `{"name", "args": [..]}` → null.
  static const String console = 'core.console';

  /// A declarative panel event: `PluginViewEvent.toJson()` → null.
  static const String viewEvent = 'core.viewEvent';

  /// `{"name","dir"}` → null; optionally `"storageDir"`: the plugin's
  /// per-project store (`PluginStorage.projectDir`), by default
  /// `<dir>/.lumina/plugins/<plugin>`.
  static const String projectOpened = 'core.projectOpened';

  /// `{}` → null, bounded by the host's hook timeout.
  static const String projectClosing = 'core.projectClosing';

  /// `{}` → null; the process exits after answering.
  static const String shutdown = 'core.shutdown';

  // --- host → process notifications ----------------------------------------

  /// `{"settings": {...}}`: the plugin's applied project settings changed.
  static const String settings = 'core.settings';

  /// `{"activeLevelPath", "actorCount"}`: the open level changed
  /// (`EditorLevelAccess.changes`).
  static const String levelChanged = 'core.levelChanged';
}

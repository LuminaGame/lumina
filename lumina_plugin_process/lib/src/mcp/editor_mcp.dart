import 'dart:async';

import 'package:lumina_core/lumina_core.dart' show ChangeEmitter;
import 'package:lumina_plugin_process/src/mcp/mcp_types.dart';

/// One `tools/call`, however it arrived: for logs and
/// for a plugin that watches what agents do.
class McpToolCallEvent {
  final String tool;

  /// The in-process caller, or the HTTP client's name.
  final String caller;
  final McpTransport transport;
  final Duration elapsed;
  final bool isError;

  /// The approval chain refused it.
  final bool denied;

  const McpToolCallEvent({
    required this.tool,
    required this.caller,
    required this.transport,
    required this.elapsed,
    required this.isError,
    required this.denied,
  });
}

/// Fires when the MCP tool list changes: a [ChangeEmitter] (pure Dart)
/// whose [notify] is [notifyListeners].
class McpChangeSignal extends ChangeEmitter {
  void notify() => notifyListeners();
}

/// How an MCP client outside the editor starts a connection to it (MiniAI
/// 05): the stdio bridge's command line, which reads the running editor's
/// connection file itself, so it carries no token and never goes stale.
class McpClientLaunch {
  const McpClientLaunch({required this.command, required this.args, this.url, this.environment = const {}});

  /// An absolute path to the Dart executable (or `dart`).
  final String command;

  /// `[<lumina_ui>/bin/lumina_mcp_bridge.dart]`.
  final List<String> args;

  /// The HTTP endpoint while the server runs (it changes per session).
  final String? url;

  /// Variables the bridge needs to find this editor (`LUMINA_CONFIG_DIR`
  /// when the editor's config directory is not the default one). A client
  /// config that passes them reaches this editor even from a redirected run.
  final Map<String, String> environment;
}

/// The editor's MCP tools for a plugin, reached
/// through `LuminaEditorContext.mcp`: the same tools, schemas and approval
/// chain external agents get over HTTP, used in process.
abstract class EditorMcp {
  const EditorMcp();

  /// A working in-memory implementation for a context with no editor behind
  /// it: tools run directly, with no approval chain.
  factory EditorMcp.detached({String pluginName}) = _DetachedEditorMcp;

  /// Adds [tool] to the editor's MCP server as `<pluginName>.<name>`, in the
  /// `plugin` group besides its own. Validated like the host's tools: known
  /// groups, nothing on `McpExposure.neverExpose`.
  void registerTool(McpTool tool);

  /// Every tool (host and plugins) in [groups] (all when null).
  List<McpTool> listTools({Set<String>? groups});

  /// Runs tool [name] in process: validated against its schema, through the
  /// approval chain, attributed on the undo stack as an MCP call by
  /// [caller]. Bad arguments throw a [JsonRpcException]; a failure or a
  /// denial is an error result.
  Future<McpToolResult> callTool(String name, Map<String, Object?> args, {String? caller});

  /// Every call, from any transport.
  Stream<McpToolCallEvent> get calls;

  /// Runs [body]; while it runs, the tool calls of external MCP clients that
  /// connected with the tag [clientTag] (the stdio bridge's `--caller`) are
  /// made as [caller] and in the zone this was called from. A surrounding
  /// `EditorLevelAccess.runTransaction` therefore groups their level edits,
  /// and their file snapshots carry [caller] like an in-process call's.
  /// Without an editor behind it, this only runs [body].
  Future<T> attributeExternalCalls<T>(String clientTag, String caller, Future<T> Function() body) => body();

  /// Whether [attributeExternalCalls] attributes anything here.
  bool get attributesExternalCalls => false;

  /// How an external MCP client reaches this editor; null
  /// without an editor MCP server.
  McpClientLaunch? get clientLaunch => null;

  /// Fires when a tool is added or removed.
  McpChangeSignal get toolsChanged;
}

class _DetachedEditorMcp extends EditorMcp {
  _DetachedEditorMcp({this.pluginName = 'plugin'});

  final String pluginName;
  final Map<String, McpTool> _tools = {};
  final StreamController<McpToolCallEvent> _calls = StreamController.broadcast();
  final McpChangeSignal _changed = McpChangeSignal();

  @override
  void registerTool(McpTool tool) {
    final name = '$pluginName.${tool.name}';
    _tools[name] = McpTool(
      name: name,
      title: tool.title,
      description: tool.description,
      inputSchema: tool.inputSchema,
      handler: tool.handler,
      risk: tool.risk,
      groups: {...tool.groups, McpToolGroups.plugin},
      idempotent: tool.idempotent,
      openWorld: tool.openWorld,
      removesContent: tool.removesContent,
      wraps: tool.wraps,
    );
    _changed.notify();
  }

  @override
  List<McpTool> listTools({Set<String>? groups}) =>
      [for (final t in _tools.values) if (groups == null || t.groups.intersection(groups).isNotEmpty) t];

  @override
  Future<McpToolResult> callTool(String name, Map<String, Object?> args, {String? caller}) async {
    final tool = _tools[name];
    if (tool == null) throw JsonRpcException(JsonRpcErrorCode.invalidParams, 'Unknown tool "$name"');
    final sw = Stopwatch()..start();
    McpToolResult result;
    try {
      result = await tool.handler(McpArgs(args));
    } on JsonRpcException {
      rethrow;
    } catch (e) {
      result = McpToolResult.error('$name failed: $e');
    }
    _calls.add(McpToolCallEvent(
      tool: name,
      caller: caller ?? pluginName,
      transport: McpTransport.inProcess,
      elapsed: sw.elapsed,
      isError: result.isError,
      denied: false,
    ));
    return result;
  }

  @override
  Stream<McpToolCallEvent> get calls => _calls.stream;

  @override
  McpChangeSignal get toolsChanged => _changed;
}

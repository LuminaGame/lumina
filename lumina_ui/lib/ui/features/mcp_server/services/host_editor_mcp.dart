import 'dart:async';

import 'package:lumina_editor_api/lumina_editor_api.dart';

import 'mcp_tool.dart';

/// The editor's MCP tools as plugins see them: one
/// [McpToolRegistry] — the server's — shared by host tools, plugin tools,
/// external agents over HTTP and in-process callers.
class HostEditorMcp {
  HostEditorMcp(this.tools, {this.log, this.launch});

  final McpToolRegistry tools;

  /// How external MCP clients start the stdio bridge.
  final McpClientLaunch? Function()? launch;

  /// Reports a refused registration (the plugin's name is in the message).
  final void Function(String message)? log;

  final Map<String, Set<String>> _byPlugin = {};

  /// MCP's tool-name alphabet (1–128 of `[A-Za-z0-9_.-]`).
  static final RegExp validName = RegExp(r'^[A-Za-z0-9_.\-]{1,128}$');

  /// [pluginName]'s view: its tools are named `<pluginName>.<name>`.
  EditorMcp scoped(String pluginName) => _ScopedEditorMcp(() => this, pluginName);

  /// A plugin's view whose host is created on first use.
  static EditorMcp lazyScoped(HostEditorMcp Function() host, String pluginName) => _ScopedEditorMcp(host, pluginName);

  /// Removes every tool [pluginName] registered (it registers again).
  void removePlugin(String pluginName) {
    for (final name in _byPlugin.remove(pluginName) ?? const <String>{}) {
      tools.unregister(name);
    }
  }

  /// The tools [pluginName] registered.
  Set<String> toolsOf(String pluginName) => Set.unmodifiable(_byPlugin[pluginName] ?? const <String>{});

  void _register(String pluginName, McpTool tool) {
    final name = '$pluginName.${tool.name}';
    if (!validName.hasMatch(name)) {
      log?.call('Plugin $pluginName: MCP tool name "$name" is not 1–128 characters of A–Z, a–z, 0–9, _ . -');
      return;
    }
    try {
      tools.register(McpTool(
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
        riskForArguments: tool.riskForArguments,
      ));
      _byPlugin.putIfAbsent(pluginName, () => {}).add(name);
    } on StateError catch (e) {
      log?.call('Plugin $pluginName: ${e.message}');
    }
  }

  Future<McpToolResult> _call(String name, Map<String, Object?> args, String caller) => tools.call(
        name,
        args,
        context: (tool) => McpCallContext(
          sessionId: 'in-process:$caller',
          clientName: caller,
          transport: McpTransport.inProcess,
          tool: tool.name,
          risk: tool.riskOf(args),
          groups: tool.groups,
          arguments: args,
        ),
      );
}

/// A plugin's [EditorMcp]: resolves the host lazily, so reading
/// `context.mcp` in `register` does not start the MCP service.
class _ScopedEditorMcp extends EditorMcp {
  _ScopedEditorMcp(this._host, this.pluginName);

  final HostEditorMcp Function() _host;
  final String pluginName;

  @override
  void registerTool(McpTool tool) => _host()._register(pluginName, tool);

  @override
  List<McpTool> listTools({Set<String>? groups}) => _host().tools.filtered(groups: groups);

  @override
  Future<McpToolResult> callTool(String name, Map<String, Object?> args, {String? caller}) =>
      _host()._call(name, args, caller ?? pluginName);

  @override
  Stream<McpToolCallEvent> get calls => _host().tools.calls;

  @override
  McpChangeSignal get toolsChanged => _host().tools.toolsChanged;

  @override
  McpClientLaunch? get clientLaunch => _host().launch?.call();
}

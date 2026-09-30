import 'mcp_protocol.dart';
import 'mcp_tool_risk.dart';

/// One MCP session: issued by `initialize`, echoed by the
/// client as `Mcp-Session-Id`.
class McpSession {
  final String id;
  final DateTime started;

  /// `initialize`'s `clientInfo.name`.
  final String clientName;
  final String protocolVersion;

  /// The groups `tools/list` shows this session (null: every group), from the
  /// endpoint URL's `?groups=level,view`.
  final Set<String>? groups;

  /// The endpoint URL's `?caller=<tag>` (the stdio bridge's `--caller`): a
  /// plugin can bind the tag to one of its callers
  /// (`EditorMcp.attributeExternalCalls`).
  final String? callerTag;

  const McpSession({
    required this.id,
    required this.started,
    required this.clientName,
    required this.protocolVersion,
    this.groups,
    this.callerTag,
  });

  /// `level,view` (a query value) or `["level", "view"]` (a `params.groups`)
  /// as a group set; null when absent. Unknown names are a −32602 that lists
  /// the known groups.
  static Set<String>? parseGroups(Object? value) {
    if (value == null) return null;
    final Iterable<String> names;
    if (value is String) {
      names = value.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty);
    } else if (value is List && value.every((e) => e is String)) {
      names = value.cast<String>().map((s) => s.trim());
    } else {
      throw const JsonRpcException(JsonRpcErrorCode.invalidParams, '"groups" must be a list of group names');
    }
    final set = names.toSet();
    final unknown = set.difference(McpToolGroups.known);
    if (unknown.isNotEmpty) {
      throw JsonRpcException(JsonRpcErrorCode.invalidParams,
          'Unknown tool group(s) ${unknown.join(', ')}. Groups: ${(McpToolGroups.known.toList()..sort()).join(', ')}.');
    }
    return set;
  }
}

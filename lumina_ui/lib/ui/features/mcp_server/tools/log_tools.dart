import '../../main_editor/view_models/editor_view_model.dart';
import '../services/mcp_protocol.dart';
import '../services/mcp_tool.dart';

/// The Output Log as MCP tools: filtered reads with a tail
/// and a cursor, and clear.
void registerLogTools(McpToolRegistry registry, EditorViewModel vm) {
  const levels = ['info', 'warning', 'error', 'success'];

  registry.registerAll([
    McpTool(
      name: 'read_output_log',
      risk: McpToolRisk.readOnly,
      groups: const {McpToolGroups.log},
      title: 'Read output log',
      description: 'The editor\'s Output Log (engine, import, compile, Play and MCP lines), newest last: '
          '[{index, timestamp, level, source, message}]. Filter by level (${levels.join(' / ')}), by source '
          '(e.g. "SpawnActor", "Blueprint", "PIE", "MCP") and by a message substring; tail limits the count '
          '(default 100, at most 2000); since_index returns only lines after that index, so poll with next_index.',
      inputSchema: McpSchema.object({
        'level': McpSchema.string('Only this level.', enumValues: levels),
        'source': McpSchema.string('Only this source (case-insensitive).'),
        'contains': McpSchema.string('Only messages containing this text (case-insensitive).'),
        'tail': McpSchema.integer('At most this many of the newest matching lines. Default 100, max 2000.'),
        'since_index': McpSchema.integer('Only lines with an index greater than this (the previous call\'s next_index − 1).'),
      }),
      handler: (args) {
        final level = args.optionalString('level');
        final source = args.optionalString('source')?.toLowerCase();
        final needle = args.optionalString('contains')?.toLowerCase();
        final tail = args.integer('tail', fallback: 100).clamp(1, 2000);
        final since = args.has('since_index') ? args.integer('since_index') : -1;
        final logs = vm.logs;
        final matching = <Map<String, Object?>>[];
        for (var i = 0; i < logs.length; i++) {
          if (i <= since) continue;
          final e = logs[i];
          if (level != null && e.level != level && !(level == 'warning' && e.level == 'warn')) continue;
          if (source != null && e.source.toLowerCase() != source) continue;
          if (needle != null && !e.message.toLowerCase().contains(needle)) continue;
          matching.add({'index': i, 'timestamp': e.timestamp, 'level': e.level, 'source': e.source, 'message': e.message});
        }
        final entries = matching.length > tail ? matching.sublist(matching.length - tail) : matching;
        return McpToolResult.json({
          'entries': entries,
          'matched': matching.length,
          'total': logs.length,
          'next_index': logs.length,
        });
      },
    ),
    McpTool(
      name: 'clear_output_log',
      risk: McpToolRisk.editorState,
      groups: const {McpToolGroups.log},
      idempotent: true,
      title: 'Clear output log',
      description: 'Empties the Output Log.',
      inputSchema: McpSchema.object(const {}),
      handler: (args) {
        vm.clearLogs();
        return McpToolResult.json({'total': vm.logs.length});
      },
    ),
  ]);
}

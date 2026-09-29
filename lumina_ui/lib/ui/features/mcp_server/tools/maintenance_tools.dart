import '../../main_editor/view_models/editor_view_model.dart';
import '../services/mcp_protocol.dart';
import '../services/mcp_tool.dart';

/// Tools → Clear Derived Data Cache as an MCP tool (group
/// `content`).
void registerMaintenanceTools(McpToolRegistry registry, EditorViewModel vm) {
  registry.register(McpTool(
    name: 'clear_derived_data_cache',
    risk: McpToolRisk.destructive,
    groups: const {McpToolGroups.content},
    wraps: const {'tools.clearDerivedDataCache'},
    title: 'Clear Derived Data Cache',
    description: 'Tools → Clear Derived Data Cache: empties the project\'s DerivedDataCache/ (the texture-budgeted '
        'GLBs built for oversized assets) and returns what it freed {entries, bytes}. Cheap to call and expensive '
        'afterwards: the next load of every oversized asset rebuilds its downscaled GLB. Not a routine clean-up — call '
        'it only when the user asks or cached data is suspected stale.',
    inputSchema: McpSchema.object(const {}),
    handler: (args) async {
      final freed = await vm.clearDerivedDataCache();
      return McpToolResult.json({'entries': freed.entries, 'bytes': freed.bytes});
    },
  ));
}

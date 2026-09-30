import '../services/lumina_guide.dart';
import '../services/mcp_protocol.dart';
import '../services/mcp_tool.dart';

/// `get_lumina_guide` (group `core`, read-only): how the Lumina engine
/// works, for AI models: the overview and the topic list, or one topic.
void registerGuideTools(McpToolRegistry registry, LuminaGuide guide) {
  registry.register(
    McpTool(
      name: 'get_lumina_guide',
      risk: McpToolRisk.readOnly,
      groups: const {McpToolGroups.core},
      title: 'Get Lumina guide',
      description:
          'How the Lumina engine works, written for AI models: project layout and the source of truth, units and '
          'axes (forward +Y at yaw 0), Blueprints and compile, game mode / pawn defaults, input actions, widgets, materials, '
          'lights, camera, play-testing, save games and common pitfalls. Without `topic`: the overview and the topic list. '
          'Read a topic before working in an area you have not used yet. Also served as lumina://guide/<topic>.',
      inputSchema: McpSchema.object({
        'topic': McpSchema.string(
          'One topic id; omit for the overview and the list.',
          enumValues: [for (final t in LuminaGuide.topics) t.id],
        ),
      }),
      handler: (args) async {
        final topic = args.optionalString('topic');
        if (topic == null || topic.isEmpty) return McpToolResult.text(await guide.overview());
        try {
          return McpToolResult.text(await guide.topic(topic));
        } on ArgumentError catch (e) {
          return McpToolResult.error('${e.message}');
        }
      },
    ),
  );
}

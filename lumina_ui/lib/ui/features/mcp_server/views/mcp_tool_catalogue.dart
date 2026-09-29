import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../../core/theme/editor_theme.dart';
import '../services/mcp_tool.dart';

/// A tool risk as a small coloured badge.
class McpRiskBadge extends StatelessWidget {
  const McpRiskBadge(this.risk, {super.key});

  final McpToolRisk risk;

  static String label(McpToolRisk r) => switch (r) {
        McpToolRisk.readOnly => 'read-only',
        McpToolRisk.editorState => 'editor state',
        McpToolRisk.mutating => 'edit',
        McpToolRisk.destructive => 'destructive',
        McpToolRisk.external => 'external',
      };

  static Color color(McpToolRisk r) => switch (r) {
        McpToolRisk.readOnly => EditorColors.mutedForeground,
        McpToolRisk.editorState => EditorColors.logInfo,
        McpToolRisk.mutating => EditorColors.logWarning,
        McpToolRisk.destructive => EditorColors.destructive,
        McpToolRisk.external => EditorColors.primary,
      };

  @override
  Widget build(BuildContext context) {
    final c = color(risk);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        border: Border.all(color: c.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(label(risk), style: TextStyle(fontSize: 9, color: c, fontWeight: FontWeight.w600)),
    );
  }
}

/// The registry as a collapsible tree of groups → tools, each with its risk
/// badge and title, under a header counted from the registry
/// ("52 tools · 17 read-only · 13 editor state · 21 edits · 1 destructive").
class McpToolCatalogue extends StatefulWidget {
  const McpToolCatalogue({super.key, required this.registry, this.initiallyExpanded = false});

  final McpToolRegistry registry;
  final bool initiallyExpanded;

  /// The header line, from the registry.
  static String summary(McpToolRegistry registry) {
    final tools = registry.tools;
    int n(McpToolRisk r) => tools.where((t) => t.risk == r).length;
    final parts = [
      '${tools.length} tools',
      '${n(McpToolRisk.readOnly)} read-only',
      '${n(McpToolRisk.editorState)} editor state',
      '${n(McpToolRisk.mutating)} edits',
      '${n(McpToolRisk.destructive)} destructive',
      if (n(McpToolRisk.external) > 0) '${n(McpToolRisk.external)} external',
    ];
    return parts.join(' · ');
  }

  @override
  State<McpToolCatalogue> createState() => _McpToolCatalogueState();
}

class _McpToolCatalogueState extends State<McpToolCatalogue> {
  late final Set<String> _open = {
    if (widget.initiallyExpanded) ...McpToolGroups.known,
  };

  @override
  Widget build(BuildContext context) {
    final byGroup = <String, List<McpTool>>{};
    for (final t in widget.registry.tools) {
      for (final g in t.groups) {
        (byGroup[g] ??= []).add(t);
      }
    }
    final groups = byGroup.keys.toList()..sort((a, b) => a == McpToolGroups.core ? -1 : (b == McpToolGroups.core ? 1 : a.compareTo(b)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(McpToolCatalogue.summary(widget.registry),
            key: const ValueKey('mcp_catalogue_header'),
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: EditorColors.foreground)),
        const SizedBox(height: 6),
        for (final g in groups) ...[
          GestureDetector(
            key: ValueKey('mcp_catalogue_group_$g'),
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _open.contains(g) ? _open.remove(g) : _open.add(g)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Icon(_open.contains(g) ? LucideIcons.chevronDown : LucideIcons.chevronRight, size: 11, color: EditorColors.mutedForeground),
                const SizedBox(width: 4),
                Text(g, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: EditorColors.foreground)),
                const SizedBox(width: 6),
                Text('${byGroup[g]!.length}', style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
              ]),
            ),
          ),
          if (_open.contains(g))
            for (final t in byGroup[g]!)
              Padding(
                key: ValueKey('mcp_catalogue_tool_${t.name}'),
                padding: const EdgeInsets.only(left: 18, top: 1, bottom: 1),
                child: Row(children: [
                  SizedBox(width: 78, child: Align(alignment: Alignment.centerLeft, child: McpRiskBadge(t.risk))),
                  SizedBox(
                    width: 170,
                    child: Text(t.name,
                        style: const TextStyle(fontSize: 10, fontFamily: EditorTypography.monoFamily, color: EditorColors.foreground)),
                  ),
                  Expanded(
                    child: Text(t.title ?? '', style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
                  ),
                ]),
              ),
        ],
      ],
    );
  }
}

// design-token-exempt: node-graph colours (the warning amber of node banners) follow node-graph conventions, not the editor chrome palette.
import 'package:lumina_editor_data/lumina_editor.dart' hide BoxShape;
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The footer of a graph node that only stages a game user setting
/// ([LuminaBlueprintNodeSpec.requiresApply]): a clock and "Needs Apply
/// Scalability Settings", with the node's description on hover.
class BlueprintStagedSettingHint extends StatelessWidget {
  /// Height of the footer, in canvas units.
  static const double height = 16;

  /// The narrowest node the footer text fits on.
  static const double minNodeWidth = 196;

  final String nodeId;

  /// The node's description (its spec's tooltip).
  final String? description;

  const BlueprintStagedSettingHint({super.key, required this.nodeId, this.description});

  @override
  Widget build(BuildContext context) {
    const amber = Color(0xFFE0B04A); // the node banner's warning amber, lightened for text on the node body
    final row = Container(
      key: ValueKey('node_staged_hint_$nodeId'),
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: Color(0x268D6E00), // the warning amber of node banners at 15 %
        border: Border(top: BorderSide(color: Color(0x408D6E00))),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(5), bottomRight: Radius.circular(5)),
      ),
      child: const Row(
        children: [
          Icon(LucideIcons.clock, size: 9, color: amber),
          SizedBox(width: 4),
          Expanded(
            child: Text(
              LuminaBlueprintNodeSpec.applyHint,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w600, color: amber),
            ),
          ),
        ],
      ),
    );
    return Tooltip(
      key: ValueKey('node_staged_hint_tooltip_$nodeId'),
      tooltip: (context) => TooltipContainer(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: Text(description ?? LuminaBlueprintNodeSpec.stagedNote, style: const TextStyle(fontSize: 10)),
        ),
      ),
      child: row,
    );
  }
}

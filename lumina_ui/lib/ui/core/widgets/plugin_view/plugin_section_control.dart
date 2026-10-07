import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/core/widgets/plugin_view/plugin_view_scope.dart';

/// [PluginControlKind.section]: the Details panel's category header
/// (`title`) over its children. Clicking the header collapses or expands it;
/// that is local UI state, sent nowhere. `collapsed` sets the initial state,
/// and a new `collapsed` from the plugin wins.
class PluginSectionControl extends StatefulWidget {
  const PluginSectionControl({super.key, required this.control, required this.children});

  final PluginControl control;

  /// The children's widgets, built by the renderer.
  final List<Widget> children;

  @override
  State<PluginSectionControl> createState() => _PluginSectionControlState();
}

class _PluginSectionControlState extends State<PluginSectionControl> {
  late bool _collapsed = widget.control.flag('collapsed') ?? false;

  @override
  void didUpdateWidget(PluginSectionControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.control.flag('collapsed');
    if (next != null && next != oldWidget.control.flag('collapsed')) _collapsed = next;
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.control;
    final key = PluginViewScope.of(context).keyOf(c.id).value;
    final header = GestureDetector(
      key: ValueKey('$key/header'),
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _collapsed = !_collapsed),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          height: EditorDensity.panelHeaderHeight,
          padding: const EdgeInsets.symmetric(horizontal: EditorDensity.gutter),
          color: EditorColors.cardHeader,
          child: Row(
            children: [
              Icon(_collapsed ? LucideIcons.chevronRight : LucideIcons.chevronDown,
                  size: 12, color: EditorColors.mutedForeground),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  (c.string('title') ?? c.label ?? '').toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  style: EditorTypography.panelHeading,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        withPluginTooltip(c.tooltip, header),
        if (!_collapsed)
          Container(
            color: EditorColors.background,
            padding: const EdgeInsets.all(EditorDensity.gutter),
            child: PluginControlColumn(children: widget.children),
          ),
      ],
    );
  }
}

/// Controls stacked vertically with the Details panel's 6 px row spacing.
class PluginControlColumn extends StatelessWidget {
  const PluginControlColumn({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < children.length; i++)
            Padding(padding: EdgeInsets.only(bottom: i == children.length - 1 ? 0 : 6), child: children[i]),
        ],
      );
}

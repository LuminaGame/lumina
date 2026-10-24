import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

/// The Aurora viewport chrome's measurements: 28 px pills on the HUD
/// surface over the render, a 10 px radius, and 30 px tool buttons in the
/// vertical tool column.
abstract final class ViewportPillStyle {
  static const double height = 28;
  static const double radius = 10;
  static const double gap = 6;
  static const double inset = 12;
  static const double toolButton = 30;

  /// A pill's fill and outline.
  static BoxDecoration decoration({bool highlighted = false}) => BoxDecoration(
        color: EditorColors.hudSurface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: highlighted ? EditorColors.primary : EditorColors.border),
      );

  static TextStyle label({bool mono = false, Color? color}) => mono
      ? EditorTypography.mono(fontSize: EditorTypography.labelSize, color: color ?? EditorColors.foreground)
      : EditorTypography.ui(fontSize: EditorTypography.bodySize, fontWeight: FontWeight.w600, color: color ?? EditorColors.foreground);
}

/// Opens [items] as a dropdown under the widget of [anchor], left-aligned,
/// as the viewport's pills open their menus.
void showViewportPillMenu(BuildContext context, GlobalKey anchor, List<MenuItem> items) {
  final box = anchor.currentContext?.findRenderObject() as RenderBox?;
  if (box == null) return;
  final offset = box.localToGlobal(Offset.zero);
  showDropdown(
    context: context,
    // An explicit position is where the menu opens; following the anchor
    // would drag it to the anchor's bottom centre.
    follow: false,
    alignment: Alignment.topLeft,
    anchorAlignment: Alignment.topLeft,
    position: Offset(offset.dx, offset.dy + box.size.height + 4),
    builder: (context) => DropdownMenu(children: items),
  );
}

/// A menu row of a viewport pill's dropdown: [label], checked when [checked].
MenuButton viewportMenuItem(String label, {required VoidCallback onPressed, bool checked = false, Key? key, IconData? icon}) =>
    MenuButton(
      key: key,
      leading: icon == null ? null : Icon(icon, size: 13),
      trailing: checked ? const Icon(LucideIcons.check, size: 12) : null,
      onPressed: (_) => onPressed(),
      child: Text(label, style: EditorTypography.ui(fontSize: EditorTypography.bodySize)),
    );

/// One pill of the viewport chrome: an icon, an optional label (in mono for
/// numbers) and a chevron when it opens a menu; [onPressed] runs on a tap,
/// [menu] builds the dropdown it opens instead.
class ViewportPill extends StatefulWidget {
  const ViewportPill({
    super.key,
    this.icon,
    this.label,
    this.mono = false,
    this.accentIcon = false,
    this.highlighted = false,
    this.tooltip,
    this.onPressed,
    this.menu,
  });

  final IconData? icon;
  final String? label;

  /// Sets [label] in JetBrains Mono (snap values, stats).
  final bool mono;

  /// Draws the icon in the amber accent (an active snap).
  final bool accentIcon;

  /// Outlines the pill in amber (an active mode).
  final bool highlighted;
  final String? tooltip;
  final VoidCallback? onPressed;
  final List<MenuItem> Function()? menu;

  @override
  State<ViewportPill> createState() => _ViewportPillState();
}

class _ViewportPillState extends State<ViewportPill> {
  final GlobalKey _anchor = GlobalKey();

  void _tap() {
    final menu = widget.menu;
    if (menu != null) {
      showViewportPillMenu(context, _anchor, menu());
    } else {
      widget.onPressed?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pill = GestureDetector(
      key: _anchor,
      behavior: HitTestBehavior.opaque,
      onTap: widget.onPressed == null && widget.menu == null ? null : _tap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          height: ViewportPillStyle.height,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: ViewportPillStyle.decoration(highlighted: widget.highlighted),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null)
                Icon(widget.icon, size: 13, color: widget.accentIcon ? EditorColors.primary : EditorColors.mutedForeground),
              if (widget.icon != null && widget.label != null) const SizedBox(width: 6),
              if (widget.label != null) Text(widget.label!, style: ViewportPillStyle.label(mono: widget.mono)),
              if (widget.menu != null) ...[
                const SizedBox(width: 5),
                const Icon(LucideIcons.chevronDown, size: 11, color: EditorColors.mutedForeground),
              ],
            ],
          ),
        ),
      ),
    );
    final tooltip = widget.tooltip;
    if (tooltip == null) return pill;
    return Tooltip(tooltip: (_) => TooltipContainer(child: Text(tooltip)), child: pill);
  }
}

/// A snap pill: the toggle (the icon, amber while on) and the step value
/// that opens the step menu, in one pill.
class ViewportSnapPill extends StatefulWidget {
  const ViewportSnapPill({
    super.key,
    required this.icon,
    required this.enabled,
    required this.onToggle,
    required this.value,
    required this.options,
    required this.onChanged,
    this.format,
    this.tooltip,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onToggle;
  final double value;
  final List<double> options;
  final ValueChanged<double> onChanged;
  final String Function(double)? format;
  final String? tooltip;

  @override
  State<ViewportSnapPill> createState() => _ViewportSnapPillState();
}

class _ViewportSnapPillState extends State<ViewportSnapPill> {
  final GlobalKey _anchor = GlobalKey();

  String _text(double v) => widget.format?.call(v) ?? (v == v.roundToDouble() ? '${v.round()}' : '$v');

  @override
  Widget build(BuildContext context) {
    return Container(
      key: _anchor,
      height: ViewportPillStyle.height,
      decoration: ViewportPillStyle.decoration(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(
            tooltip: (_) => TooltipContainer(child: Text(widget.tooltip ?? 'Snap')),
            child: GhostButton(
              density: ButtonDensity.icon,
              onPressed: widget.onToggle,
              child: Icon(widget.icon, size: 13, color: widget.enabled ? EditorColors.primary : EditorColors.mutedForeground),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => showViewportPillMenu(context, _anchor, [
              for (final step in widget.options)
                viewportMenuItem(_text(step), checked: step == widget.value, onPressed: () => widget.onChanged(step)),
            ]),
            child: Padding(
              padding: const EdgeInsets.only(right: 9),
              child: Text(
                _text(widget.value),
                style: ViewportPillStyle.label(mono: true, color: widget.enabled ? EditorColors.foreground : EditorColors.mutedForeground),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One button of a [ViewportToolColumn].
class ViewportTool {
  const ViewportTool({required this.id, required this.icon, required this.tooltip, this.key});

  final String id;
  final IconData icon;
  final String tooltip;
  final Key? key;
}

/// The vertical transform pill under the pill row: [tools] (Select, Move,
/// Rotate, Scale) with the active one amber, a divider, then [actions]
/// (Focus); 30 px buttons.
class ViewportToolColumn extends StatelessWidget {
  const ViewportToolColumn({
    super.key,
    required this.tools,
    required this.active,
    required this.onSelect,
    this.actions = const [],
    required this.onAction,
  });

  final List<ViewportTool> tools;
  final String active;
  final ValueChanged<String> onSelect;
  final List<ViewportTool> actions;
  final ValueChanged<String> onAction;

  Widget _button(ViewportTool tool, {required bool selected, required VoidCallback onTap}) => Tooltip(
        tooltip: (_) => TooltipContainer(child: Text(tool.tooltip)),
        child: GestureDetector(
          key: tool.key,
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Container(
              width: ViewportPillStyle.toolButton,
              height: ViewportPillStyle.toolButton,
              decoration: BoxDecoration(
                color: selected ? EditorColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(tool.icon, size: 15, color: selected ? EditorColors.primaryForeground : EditorColors.foreground),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: ViewportPillStyle.decoration(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final tool in tools)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: _button(tool, selected: tool.id == active, onTap: () => onSelect(tool.id)),
            ),
          if (actions.isNotEmpty) ...[
            Container(width: 20, height: 1, margin: const EdgeInsets.symmetric(vertical: 4), color: EditorColors.border),
            for (final action in actions)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: _button(action, selected: false, onTap: () => onAction(action.id)),
              ),
          ],
        ],
      ),
    );
  }
}

/// One overlay a viewport's Show pill toggles: its [label], whether it is
/// drawn, and what toggles it.
class ViewportShowItem {
  const ViewportShowItem({required this.label, required this.value, required this.onChanged});

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
}

import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

/// One tab of an [EditorTypedTabBar]: its title, the icon and colour of what
/// it shows (an asset type's, or the muted grey for a document that is no
/// asset), whether it has unsaved changes and whether it can be closed.
class EditorTypedTab {
  const EditorTypedTab({
    required this.key,
    required this.title,
    required this.icon,
    this.color,
    this.dirty = false,
    this.closable = true,
  });

  /// The tab's widget key (tests and tooling find the tab by it).
  final Key key;
  final String title;
  final IconData icon;

  /// The type colour: the icon and, when active, the underline. Null is the
  /// muted foreground with the amber underline.
  final Color? color;
  final bool dirty;
  final bool closable;
}

/// The Aurora workspace tab strip: a 42 px bar on the rail, each tab with its
/// type's icon and colour, a 2 px underline in that colour under the active
/// tab, an amber dot instead of the close cross while the tab is unsaved
/// (the cross comes back under the pointer), a `+` button after the tabs and,
/// when the tabs do not fit, an overflow menu listing the rest as `+N`.
class EditorTypedTabBar extends StatelessWidget {
  const EditorTypedTabBar({
    super.key,
    required this.tabs,
    required this.activeIndex,
    required this.onSelect,
    required this.onClose,
    this.onAdd,
    this.height = barHeight,
    this.trailing,
  });

  /// The active tab's actions at the bar's right end (its editor's toolbar),
  /// given at most [trailingShare] of the bar; the tabs take the rest.
  final Widget? trailing;

  /// The share of the bar the [trailing] actions may take.
  static const double trailingShare = 0.6;

  final List<EditorTypedTab> tabs;
  final int activeIndex;
  final ValueChanged<int> onSelect;
  final ValueChanged<int> onClose;

  /// The `+` button; hidden when null.
  final VoidCallback? onAdd;
  final double height;

  /// The bar's height on the canvas.
  static const double barHeight = 42;

  /// A tab's width: the title is ellipsized inside it, so every tab is the
  /// same width and the overflow count is exact.
  static const double tabWidth = 156;

  /// The `+` button and the overflow chip at the strip's end.
  static const double trailingWidth = 92;

  /// The underline under the active tab.
  static const double underlineWidth = 2;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: EditorColors.rail,
        border: Border(bottom: BorderSide(color: EditorColors.border)),
      ),
      padding: const EdgeInsets.only(left: 8),
      child: LayoutBuilder(
        builder: (context, bar) => Row(
          children: [
            Expanded(child: _tabs()),
            if (trailing != null)
              ConstrainedBox(constraints: BoxConstraints(maxWidth: bar.maxWidth * trailingShare), child: trailing!),
          ],
        ),
      ),
    );
  }

  Widget _tabs() {
    return LayoutBuilder(
        builder: (context, constraints) {
          final available = constraints.maxWidth - trailingWidth;
          var visible = (available / tabWidth).floor().clamp(1, tabs.length);
          // The active tab is always shown: the strip reorders nothing, it
          // swaps the last visible slot for it.
          final order = List<int>.generate(tabs.length, (i) => i);
          if (activeIndex >= visible) {
            order.removeAt(activeIndex);
            order.insert(visible - 1, activeIndex);
          }
          final shown = order.take(visible).toList();
          final hidden = order.skip(visible).toList();
          return Row(
            children: [
              for (final index in shown)
                _TypedTabButton(
                  tab: tabs[index],
                  active: index == activeIndex,
                  onTap: () => onSelect(index),
                  onClose: tabs[index].closable ? () => onClose(index) : null,
                ),
              if (hidden.isNotEmpty)
                _OverflowChip(
                  count: hidden.length,
                  onPressed: () => _showOverflow(context, hidden),
                ),
              if (onAdd != null)
                Tooltip(
                  tooltip: (_) => const TooltipContainer(child: Text('New asset')),
                  child: GhostButton(
                    key: const ValueKey('workspace_tab_add'),
                    density: ButtonDensity.icon,
                    onPressed: onAdd,
                    child: const Icon(LucideIcons.plus, size: 14, color: EditorColors.mutedForeground),
                  ),
                ),
              const Spacer(),
            ],
          );
        },
    );
  }

  void _showOverflow(BuildContext context, List<int> hidden) {
    showDropdown(
      context: context,
      builder: (ctx) => DropdownMenu(
        children: [
          for (final index in hidden)
            MenuButton(
              key: ValueKey('workspace_tab_overflow_$index'),
              leading: Icon(tabs[index].icon, size: 14, color: tabs[index].color ?? EditorColors.mutedForeground),
              trailing: tabs[index].dirty ? const _UnsavedDot() : null,
              onPressed: (_) => onSelect(index),
              child: Text(tabs[index].title, style: EditorTypography.ui(fontSize: EditorTypography.bodySize)),
            ),
        ],
      ),
    );
  }
}

class _TypedTabButton extends StatefulWidget {
  const _TypedTabButton({required this.tab, required this.active, required this.onTap, this.onClose});

  final EditorTypedTab tab;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback? onClose;

  @override
  State<_TypedTabButton> createState() => _TypedTabButtonState();
}

class _TypedTabButtonState extends State<_TypedTabButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final tab = widget.tab;
    final typeColor = tab.color ?? EditorColors.mutedForeground;
    final underline = tab.color ?? EditorColors.primary;
    final Widget? trailing = widget.onClose == null
        ? null
        : tab.dirty && !_hover
            ? const _UnsavedDot(key: ValueKey('workspace_tab_unsaved_dot'))
            : GestureDetector(
                key: const ValueKey('workspace_tab_close'),
                onTap: widget.onClose,
                child: const Icon(LucideIcons.x, size: 11, color: EditorColors.mutedForeground),
              );
    return Tooltip(
      tooltip: (_) => TooltipContainer(child: Text(tab.title)),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: Listener(
          onPointerDown: (event) {
            // Middle click closes, like a browser tab.
            if (event.buttons == 4) widget.onClose?.call();
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            child: Container(
              key: tab.key,
              width: EditorTypedTabBar.tabWidth,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: widget.active ? EditorColors.sidebar : (_hover ? EditorColors.rowHover : Colors.transparent),
                border: Border(
                  bottom: BorderSide(
                    color: widget.active ? underline : Colors.transparent,
                    width: EditorTypedTabBar.underlineWidth,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(tab.icon, size: 13, color: widget.active ? typeColor : typeColor.withValues(alpha: 0.75)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tab.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: EditorTypography.ui(
                        fontSize: EditorTypography.bodySize,
                        fontWeight: widget.active ? FontWeight.w600 : FontWeight.w500,
                        color: widget.active ? EditorColors.foreground : EditorColors.mutedForeground,
                      ),
                    ),
                  ),
                  if (trailing != null) ...[const SizedBox(width: 8), trailing],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The amber dot of an unsaved tab.
class _UnsavedDot extends StatelessWidget {
  const _UnsavedDot({super.key});

  @override
  Widget build(BuildContext context) => Container(
        width: 7,
        height: 7,
        decoration: const BoxDecoration(color: EditorColors.primary, shape: BoxShape.circle),
      );
}

class _OverflowChip extends StatelessWidget {
  const _OverflowChip({required this.count, required this.onPressed});

  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: GhostButton(
          key: const ValueKey('workspace_tab_overflow'),
          density: EditorDensity.chipButton,
          onPressed: onPressed,
          child: Text('+$count', style: EditorTypography.mono(fontSize: EditorTypography.labelSize, color: EditorColors.mutedForeground)),
        ),
      );
}

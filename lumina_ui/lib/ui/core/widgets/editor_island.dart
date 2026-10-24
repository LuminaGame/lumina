import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

/// The Aurora island's measurements: every docked panel is a rounded card on
/// the window's ground, separated from its neighbours by a gutter.
abstract final class EditorIslandStyle {
  /// The island's corner radius.
  static const double radius = 12;

  /// The gutter between islands and around the workspace.
  static const double gap = 8;

  /// The gap between two stacked islands, which carries the splitter grip.
  static const double gripGap = 10;

  /// The island header's height.
  static const double headerHeight = 36;

  /// A tree or list row's height and corner radius inside an island.
  static const double rowHeight = 24;
  static const double rowRadius = 6;

  /// The splitter grip: a short bar centred in [gripGap].
  static const double gripLength = 28;
  static const double gripThickness = 3;

  /// The island's own decoration: the island fill, a 1 px border, [radius].
  static BoxDecoration decoration({Color? color}) => BoxDecoration(
    color: color ?? EditorColors.sidebar,
    border: Border.all(color: EditorColors.border),
    borderRadius: BorderRadius.circular(radius),
  );
}

/// A docked panel in the Aurora design language: the island fill with a
/// 1 px border and a 12 px radius, its content clipped to the corners, and
/// an optional [EditorIslandHeader] on top.
class EditorIsland extends StatelessWidget {
  const EditorIsland({super.key, this.header, required this.child, this.color});

  /// Usually an [EditorIslandHeader]; null for an island whose content
  /// brings its own top row (the viewport, a tabbed panel).
  final Widget? header;
  final Widget child;

  /// The island fill; the default is [EditorColors.sidebar].
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: EditorIslandStyle.decoration(color: color),
      clipBehavior: Clip.antiAlias,
      child: header == null
          ? child
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header!,
                Expanded(child: child),
              ],
            ),
    );
  }
}

/// An island's 36 px header: the title in upper case (11 px, bold, a little
/// tracking), an optional [leading] icon, and [actions] at the right end,
/// over a 1 px border.
class EditorIslandHeader extends StatelessWidget {
  const EditorIslandHeader({super.key, required this.title, this.leading, this.actions = const [], this.trailingInfo});

  final String title;
  final Widget? leading;

  /// Small text before the actions (counts, stats), set in mono.
  final String? trailingInfo;
  final List<Widget> actions;

  /// The header title's style.
  static TextStyle get titleStyle => EditorTypography.ui(
    fontSize: EditorTypography.bodySize,
    fontWeight: FontWeight.w700,
    letterSpacing: EditorTypography.bodySize * 0.04,
    color: EditorColors.secondaryForeground,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      height: EditorIslandStyle.headerHeight,
      padding: const EdgeInsets.only(left: 12, right: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: EditorColors.border)),
      ),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 8)],
          Expanded(
            child: Text(title.toUpperCase(), style: titleStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          if (trailingInfo != null)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text(
                trailingInfo!,
                style: EditorTypography.mono(fontSize: EditorTypography.labelSize, color: EditorColors.mutedForeground),
              ),
            ),
          ...actions,
        ],
      ),
    );
  }
}

/// The dividers between islands in a [ResizablePanel]: an empty gutter
/// beside islands, and a gutter with the splitter grip between stacked
/// islands. The panel's own resize handle sits over either, so the islands
/// stay resizable.
abstract final class EditorIslandDividers {
  /// An [EditorIslandStyle.gap] gutter across the panel's axis.
  static Widget? gap(BuildContext context) {
    final horizontal = Data.of<ResizableData>(context).direction == Axis.horizontal;
    return horizontal
        ? const SizedBox(width: EditorIslandStyle.gap, key: ValueKey('island_gap'))
        : const SizedBox(height: EditorIslandStyle.gap, key: ValueKey('island_gap'));
  }

  /// An [EditorIslandStyle.gripGap] gutter with the grip bar in its middle.
  static Widget? grip(BuildContext context) {
    final horizontal = Data.of<ResizableData>(context).direction == Axis.horizontal;
    final bar = Container(
      width: horizontal ? EditorIslandStyle.gripThickness : EditorIslandStyle.gripLength,
      height: horizontal ? EditorIslandStyle.gripLength : EditorIslandStyle.gripThickness,
      decoration: BoxDecoration(color: EditorColors.fieldBorder, borderRadius: BorderRadius.circular(2)),
    );
    return SizedBox(
      key: const ValueKey('island_grip'),
      width: horizontal ? EditorIslandStyle.gripGap : null,
      height: horizontal ? null : EditorIslandStyle.gripGap,
      child: Center(child: bar),
    );
  }
}

/// The grip under a pane that brings its own ground gutter (a sub-editor's
/// [EditorIslandGround]): the divider takes only what the [EditorIslandStyle.gripGap]
/// lacks beyond that gutter, and the grip bar sits centred in the whole gap.
Widget? editorIslandGroundGrip(BuildContext context) {
  const own = EditorIslandStyle.gripGap - EditorIslandStyle.gap;
  final bar = Container(
    width: EditorIslandStyle.gripLength,
    height: EditorIslandStyle.gripThickness,
    decoration: BoxDecoration(color: EditorColors.fieldBorder, borderRadius: BorderRadius.circular(2)),
  );
  return SizedBox(
    key: const ValueKey('island_grip'),
    height: own,
    child: OverflowBox(
      maxHeight: EditorIslandStyle.gripGap,
      alignment: Alignment.bottomCenter,
      child: SizedBox(height: EditorIslandStyle.gripGap, child: Center(child: bar)),
    ),
  );
}

/// How a tree row inside an island shows its state. The row is indented by
/// a margin, not by padding, so the selection fill starts at the row's own
/// indent rather than at the panel edge; the fill is the amber accent with
/// dark text on it.
abstract final class EditorTreeRowStyle {
  /// The left margin of a row at [depth]: the island's inner gutter plus one
  /// indent step per level.
  static EdgeInsets margin(int depth, {double base = 6}) => EdgeInsets.only(left: base + depth * EditorDensity.indentStep, right: base);

  /// The row's fill and outline: amber when [selected], a tinted outline
  /// while something is dragged over it, a faint fill under the pointer.
  static BoxDecoration decoration({required bool selected, bool dropTarget = false, bool hover = false}) => BoxDecoration(
    color: dropTarget
        ? EditorColors.primary.withValues(alpha: 0.18)
        : selected
        ? EditorColors.primary
        : hover
        ? EditorColors.rowHover
        : Colors.transparent,
    border: dropTarget ? Border.all(color: EditorColors.primary) : null,
    borderRadius: BorderRadius.circular(EditorIslandStyle.rowRadius),
  );

  /// Text and icons on the row: dark on the amber fill.
  static Color foreground({required bool selected, Color normal = EditorColors.foreground}) =>
      selected ? EditorColors.primaryForeground : normal;
}

/// The window's ground under a row of islands: the background fill with
/// the [EditorIslandStyle.gap] gutter around the islands.
class EditorIslandGround extends StatelessWidget {
  const EditorIslandGround({super.key, required this.child, this.padding = const EdgeInsets.all(EditorIslandStyle.gap)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(color: EditorColors.background, padding: padding, child: child);
  }
}

/// An island header that switches the island between several views: the
/// tabs as text at the left (the active one bold on a muted chip), then
/// [actions]. A tab gets its key from [tabKeys], else
/// `island_tab_<keyPrefix>_<index>` when [keyPrefix] is set.
class EditorIslandTabHeader extends StatelessWidget {
  const EditorIslandTabHeader({
    super.key,
    required this.tabs,
    required this.active,
    required this.onSelect,
    this.actions = const [],
    this.keyPrefix,
    this.tabKeys = const {},
  });

  final List<String> tabs;
  final Map<int, Key> tabKeys;
  final int active;
  final ValueChanged<int> onSelect;
  final List<Widget> actions;
  final String? keyPrefix;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: EditorIslandStyle.headerHeight,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: EditorColors.border)),
      ),
      child: Row(
        children: [
          // The tabs share the header: a narrow island shortens their
          // labels rather than scrolling one out of sight.
          Expanded(
            child: Row(
              children: [
                for (var i = 0; i < tabs.length; i++)
                  Flexible(
                    child: GestureDetector(
                      key: tabKeys[i] ?? (keyPrefix == null ? null : ValueKey('island_tab_${keyPrefix}_$i')),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onSelect(i),
                      child: Container(
                        height: 24,
                        margin: const EdgeInsets.only(right: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: i == active ? EditorColors.muted : Colors.transparent,
                          borderRadius: BorderRadius.circular(EditorIslandStyle.rowRadius),
                        ),
                        child: Text(
                          tabs[i],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: EditorTypography.ui(
                            fontSize: EditorTypography.bodySize,
                            fontWeight: i == active ? FontWeight.w700 : FontWeight.w500,
                            color: i == active ? EditorColors.foreground : EditorColors.mutedForeground,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

/// A section label inside an island ("MATERIAL SLOTS", "COLLISION"): upper
/// case, 10 px bold with a little tracking, in the muted text colour, with
/// an optional [trailing] widget at the right (a count, a + button).
class EditorIslandSectionLabel extends StatelessWidget {
  const EditorIslandSectionLabel(this.label, {super.key, this.trailing, this.padding = const EdgeInsets.only(top: 12, bottom: 6)});

  final String label;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  static TextStyle get style => EditorTypography.ui(
    fontSize: EditorTypography.labelSize,
    fontWeight: FontWeight.w700,
    letterSpacing: EditorTypography.labelSize * 0.05,
    color: EditorColors.mutedForeground,
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(label.toUpperCase(), style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

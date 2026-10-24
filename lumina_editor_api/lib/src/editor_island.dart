import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The colours and type the editor's islands paint with. The host editor sets
/// [active] to its live theme tokens at startup, so plugin islands follow a
/// theme switch with the editor's own; outside the editor (a plugin's widget
/// test) they use [aurora], the default Lumina Dark values.
@immutable
class EditorIslandThemeData {
  const EditorIslandThemeData({
    required this.island,
    required this.ground,
    required this.border,
    required this.fieldBorder,
    required this.foreground,
    required this.secondaryForeground,
    required this.mutedForeground,
    required this.muted,
    required this.primary,
    required this.primaryForeground,
    required this.rowHover,
    this.uiFamily = 'Manrope',
    this.monoFamily = 'JetBrains Mono',
  });

  /// An island's fill.
  final Color island;

  /// The window's ground under the islands.
  final Color ground;

  /// Island outlines and the line under a header.
  final Color border;

  /// The splitter grip.
  final Color fieldBorder;
  final Color foreground;

  /// Island header titles.
  final Color secondaryForeground;

  /// Section labels, counts, inactive tabs.
  final Color mutedForeground;

  /// The active header tab's chip.
  final Color muted;

  /// A selected tree row's fill, with [primaryForeground] text on it.
  final Color primary;
  final Color primaryForeground;
  final Color rowHover;
  final String uiFamily;
  final String monoFamily;

  /// Lumina Dark's values.
  static const EditorIslandThemeData aurora = EditorIslandThemeData(
    island: Color(0xFF111215),
    ground: Color(0xFF141518),
    border: Color(0xFF26282E),
    fieldBorder: Color(0xFF2C2E34),
    foreground: Color(0xFFE6E6E8),
    secondaryForeground: Color(0xFFC9CAD0),
    mutedForeground: Color(0xFF9A9CA3),
    muted: Color(0xFF1F2126),
    primary: Color(0xFFF2A93B),
    primaryForeground: Color(0xFF0B1D22),
    rowHover: Color(0x0AFFFFFF),
  );

  /// What islands paint with now; the host editor sets it.
  static EditorIslandThemeData active = aurora;

  /// UI text in [uiFamily].
  TextStyle ui({double fontSize = 11, FontWeight fontWeight = FontWeight.w500, Color? color, double? letterSpacing}) =>
      TextStyle(fontFamily: uiFamily, fontSize: fontSize, fontWeight: fontWeight, color: color, letterSpacing: letterSpacing);

  /// Numbers and counts in [monoFamily].
  TextStyle mono({double fontSize = 10, FontWeight? fontWeight, Color? color}) =>
      TextStyle(fontFamily: monoFamily, fontSize: fontSize, fontWeight: fontWeight, color: color);
}

/// The island's measurements: every docked panel is a rounded card on the
/// window's ground, separated from its neighbours by a gutter.
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

  /// One tree level's indent.
  static const double indentStep = 14;

  /// The island's own decoration: the island fill, a 1 px border, [radius].
  static BoxDecoration decoration({Color? color}) {
    final theme = EditorIslandThemeData.active;
    return BoxDecoration(
      color: color ?? theme.island,
      border: Border.all(color: theme.border),
      borderRadius: BorderRadius.circular(radius),
    );
  }
}

/// A docked panel: the island fill with a 1 px border and a 12 px radius, its
/// content clipped to the corners, and an optional [EditorIslandHeader] on
/// top. Lumina Studio's own panels and plugin panels use the same island.
class EditorIsland extends StatelessWidget {
  const EditorIsland({super.key, this.header, required this.child, this.color});

  /// Usually an [EditorIslandHeader]; null for an island whose content
  /// brings its own top row (a viewport, a tabbed panel).
  final Widget? header;
  final Widget child;

  /// The island fill; the default is the theme's island colour.
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
/// tracking), an optional [leading] icon, a mono [trailingInfo] and
/// [actions] at the right end, over a 1 px border.
class EditorIslandHeader extends StatelessWidget {
  const EditorIslandHeader({super.key, required this.title, this.leading, this.actions = const [], this.trailingInfo});

  final String title;
  final Widget? leading;

  /// Small text before the actions (counts, stats), set in mono.
  final String? trailingInfo;
  final List<Widget> actions;

  /// The header title's style.
  static TextStyle get titleStyle {
    final theme = EditorIslandThemeData.active;
    return theme.ui(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 11 * 0.04, color: theme.secondaryForeground);
  }

  @override
  Widget build(BuildContext context) {
    final theme = EditorIslandThemeData.active;
    return Container(
      height: EditorIslandStyle.headerHeight,
      padding: const EdgeInsets.only(left: 12, right: 8),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: theme.border))),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 8)],
          Expanded(
            child: Text(title.toUpperCase(), style: titleStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          if (trailingInfo != null)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text(trailingInfo!, style: theme.mono(fontSize: 10, color: theme.mutedForeground)),
            ),
          ...actions,
        ],
      ),
    );
  }
}

/// An island header that switches the island between several views: the
/// tabs as text at the left (the active one bold on a muted chip), then
/// [actions]. A tab gets its key from [tabKeys], else
/// `island_tab_<keyPrefix>_<index>` when [keyPrefix] is set. A narrow island
/// shortens the labels rather than scrolling one out of sight.
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
    final theme = EditorIslandThemeData.active;
    return Container(
      height: EditorIslandStyle.headerHeight,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: theme.border))),
      child: Row(
        children: [
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
                          color: i == active ? theme.muted : Colors.transparent,
                          borderRadius: BorderRadius.circular(EditorIslandStyle.rowRadius),
                        ),
                        child: Text(
                          tabs[i],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.ui(
                            fontWeight: i == active ? FontWeight.w700 : FontWeight.w500,
                            color: i == active ? theme.foreground : theme.mutedForeground,
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

  static TextStyle get style {
    final theme = EditorIslandThemeData.active;
    return theme.ui(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 10 * 0.05, color: theme.mutedForeground);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(child: Text(label.toUpperCase(), style: style, maxLines: 1, overflow: TextOverflow.ellipsis)),
          ?trailing,
        ],
      ),
    );
  }
}

/// The window's ground under a row of islands: the ground fill with the
/// [EditorIslandStyle.gap] gutter around the islands.
class EditorIslandGround extends StatelessWidget {
  const EditorIslandGround({super.key, required this.child, this.padding = const EdgeInsets.all(EditorIslandStyle.gap)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(color: EditorIslandThemeData.active.ground, padding: padding, child: child);
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
    final bar = _gripBar(horizontal: horizontal);
    return SizedBox(
      key: const ValueKey('island_grip'),
      width: horizontal ? EditorIslandStyle.gripGap : null,
      height: horizontal ? null : EditorIslandStyle.gripGap,
      child: Center(child: bar),
    );
  }

  /// The grip under a pane that brings its own ground gutter (an
  /// [EditorIslandGround]): the divider takes only what [EditorIslandStyle.gripGap]
  /// lacks beyond that gutter, and the grip bar sits centred in the whole gap.
  static Widget? groundGrip(BuildContext context) {
    const own = EditorIslandStyle.gripGap - EditorIslandStyle.gap;
    return SizedBox(
      key: const ValueKey('island_grip'),
      height: own,
      child: OverflowBox(
        maxHeight: EditorIslandStyle.gripGap,
        alignment: Alignment.bottomCenter,
        child: SizedBox(height: EditorIslandStyle.gripGap, child: Center(child: _gripBar(horizontal: false))),
      ),
    );
  }

  static Widget _gripBar({required bool horizontal}) => Container(
        width: horizontal ? EditorIslandStyle.gripThickness : EditorIslandStyle.gripLength,
        height: horizontal ? EditorIslandStyle.gripLength : EditorIslandStyle.gripThickness,
        decoration: BoxDecoration(color: EditorIslandThemeData.active.fieldBorder, borderRadius: BorderRadius.circular(2)),
      );
}

/// How a tree row inside an island shows its state. The row is indented by
/// a margin, not by padding, so the selection fill starts at the row's own
/// indent rather than at the panel edge; the fill is the primary accent with
/// dark text on it.
abstract final class EditorTreeRowStyle {
  /// The left margin of a row at [depth]: the island's inner gutter plus one
  /// indent step per level.
  static EdgeInsets margin(int depth, {double base = 6}) =>
      EdgeInsets.only(left: base + depth * EditorIslandStyle.indentStep, right: base);

  /// The row's fill and outline: the accent when [selected], a tinted
  /// outline while something is dragged over it, a faint fill under the
  /// pointer.
  static BoxDecoration decoration({required bool selected, bool dropTarget = false, bool hover = false}) {
    final theme = EditorIslandThemeData.active;
    return BoxDecoration(
      color: dropTarget
          ? theme.primary.withValues(alpha: 0.18)
          : selected
              ? theme.primary
              : hover
                  ? theme.rowHover
                  : Colors.transparent,
      border: dropTarget ? Border.all(color: theme.primary) : null,
      borderRadius: BorderRadius.circular(EditorIslandStyle.rowRadius),
    );
  }

  /// Text and icons on the row: dark on the accent fill.
  static Color foreground({required bool selected, Color? normal}) =>
      selected ? EditorIslandThemeData.active.primaryForeground : normal ?? EditorIslandThemeData.active.foreground;
}

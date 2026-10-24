import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/core/widgets/editor_island.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_panels_controller.dart';

/// The right dock: the open `PanelDefaultDock.right` plugin
/// panels. A header names the active one; with several shown, a tab strip
/// switches between them. Each tab has a close button, and the header a pin
/// button that shows the active panel in every editor tab ("Always") or in
/// the level editor only.
///
/// The dock shows every open panel on the level tab ([levelTab]) and only
/// the "Always" ones on other tabs, but every open panel's body stays
/// mounted in an [IndexedStack], so a panel keeps its state across dock and
/// editor tab switches.
class RightDockWidget extends StatelessWidget {
  const RightDockWidget({super.key, required this.controller, this.levelTab = true});

  final EditorPanelsController controller;

  /// Whether the active editor tab is the level editor.
  final bool levelTab;

  @override
  Widget build(BuildContext context) {
    final open = controller.openRightPanels;
    final shown = controller.shownRightPanels(levelTab: levelTab);
    // With none shown the dock is parked offstage: the bodies stay mounted.
    final active = controller.activeShownPanel(levelTab: levelTab) ?? controller.activeRightPanel;
    if (open.isEmpty || active == null) return const SizedBox.shrink();
    // An island like the level editor's docks: the 36 px header (title or
    // the panels' tabs, Always, close), then the panel bodies.
    return EditorIsland(
      key: const ValueKey('island_right_dock'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: EditorIslandStyle.headerHeight,
            padding: const EdgeInsets.only(left: 12, right: 6),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: EditorColors.border)),
            ),
            child: Row(
              children: [
                if (shown.length <= 1)
                  Expanded(child: _title(active))
                else
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [for (final panel in shown) _tab(panel, panel.id == active.id)]),
                    ),
                  ),
                _always(active),
                if (shown.length <= 1) _close(active),
              ],
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: open.indexWhere((p) => p.id == active.id),
              children: [
                for (final panel in open)
                  KeyedSubtree(key: ValueKey('right_dock_panel_${panel.id}'), child: Builder(builder: panel.builder)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _title(EditorPanelDescriptor panel) => Row(
        children: [
          Icon(panel.icon, size: 12, color: EditorColors.primary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              panel.title.toUpperCase(),
              overflow: TextOverflow.ellipsis,
              style: EditorIslandHeader.titleStyle,
            ),
          ),
        ],
      );

  /// The pin: "Always" on shows the panel in every editor tab.
  Widget _always(EditorPanelDescriptor panel) => ValueListenableBuilder<bool>(
        valueListenable: controller.alwaysVisibility(panel.id),
        builder: (context, always, _) => Tooltip(
          tooltip: (_) => TooltipContainer(child: Text(always ? 'Show in the level editor only' : 'Show in every editor')),
          child: GhostButton(
            key: ValueKey('right_dock_always_${panel.id}'),
            density: ButtonDensity.compact,
            onPressed: () => controller.toggleAlwaysVisible(panel.id),
            child: Icon(
              always ? LucideIcons.pin : LucideIcons.pinOff,
              size: 11,
              color: always ? EditorColors.primary : EditorColors.mutedForeground,
            ),
          ),
        ),
      );

  Widget _close(EditorPanelDescriptor panel) => Tooltip(
        tooltip: (_) => TooltipContainer(child: Text('Close ${panel.title}')),
        child: GhostButton(
          key: ValueKey('right_dock_close_${panel.id}'),
          density: ButtonDensity.compact,
          onPressed: () => controller.hide(panel.id),
          child: const Icon(LucideIcons.x, size: 11, color: EditorColors.mutedForeground),
        ),
      );

  // An island header tab: the active one on a muted chip.
  Widget _tab(EditorPanelDescriptor panel, bool selected) => Container(
        height: 24,
        margin: const EdgeInsets.only(right: 2),
        padding: const EdgeInsets.only(left: 8),
        decoration: BoxDecoration(
          color: selected ? EditorColors.muted : Colors.transparent,
          borderRadius: BorderRadius.circular(EditorIslandStyle.rowRadius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              key: ValueKey('right_dock_tab_${panel.id}'),
              onTap: () => controller.activate(panel.id),
              child: Row(
                children: [
                  Icon(panel.icon, size: 11, color: selected ? EditorColors.primary : EditorColors.mutedForeground),
                  const SizedBox(width: 4),
                  Text(
                    panel.title,
                    style: EditorTypography.ui(
                      fontSize: EditorTypography.bodySize,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? EditorColors.foreground : EditorColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            _close(panel),
          ],
        ),
      );
}

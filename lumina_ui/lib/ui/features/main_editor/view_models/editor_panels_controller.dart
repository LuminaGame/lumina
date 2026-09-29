import 'package:flutter/foundation.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart';

import 'editor_layout_state.dart';

/// The host's [EditorPanels]: plugin panel visibility over the
/// editor layout.
///
/// A `PanelDefaultDock.right` panel lives in the right dock: open while
/// `pluginPanelVisible[id]`, the dock's active tab `activeRightPanel`. Any
/// other panel is a bottom-panel tab: open while the bottom panel
/// shows its tab. Every change goes through [save] (the view model's
/// `saveLayoutState`, which notifies); [refresh] brings each panel's
/// [visibility] notifier up to date and runs on every such notification.
class EditorPanelsController extends EditorPanels {
  EditorPanelsController({
    required this.layout,
    required this.panels,
    required this.bottomTabIndex,
    required this.save,
    this.warn,
  });

  /// The current layout (the view model replaces it when it loads one).
  final EditorLayoutState Function() layout;

  /// Every registered plugin panel.
  final List<EditorPanelDescriptor> Function() panels;

  /// The bottom-panel tab index of a non-right panel, or -1.
  final int Function(String panelId) bottomTabIndex;

  final void Function() save;
  final void Function(String message)? warn;

  final Map<String, ValueNotifier<bool>> _visibility = {};

  EditorPanelDescriptor? _panel(String id) {
    for (final p in panels()) {
      if (p.id == id) return p;
    }
    return null;
  }

  static bool isRight(EditorPanelDescriptor panel) => panel.defaultDock == PanelDefaultDock.right;

  /// The right-dock panels, in registration order.
  List<EditorPanelDescriptor> get rightPanels => [for (final p in panels()) if (isRight(p)) p];

  /// The open right-dock panels, in registration order.
  List<EditorPanelDescriptor> get openRightPanels => [for (final p in rightPanels) if (layout().pluginPanelVisible[p.id] == true) p];

  /// The right dock's active panel: the saved one while open, else the first
  /// open one.
  EditorPanelDescriptor? get activeRightPanel {
    final open = openRightPanels;
    if (open.isEmpty) return null;
    return open.firstWhere((p) => p.id == layout().activeRightPanel, orElse: () => open.first);
  }

  @override
  bool isVisible(String panelId) {
    final panel = _panel(panelId);
    if (panel == null) return false;
    final l = layout();
    if (isRight(panel)) return l.pluginPanelVisible[panelId] == true;
    final index = bottomTabIndex(panelId);
    return index >= 0 && l.bottomVisible && l.activeBottomTab == index;
  }

  @override
  void show(String panelId, {bool focus = true}) {
    final panel = _panel(panelId);
    if (panel == null) {
      warn?.call('No plugin panel "$panelId" is registered');
      return;
    }
    final l = layout();
    if (isRight(panel)) {
      l.pluginPanelVisible[panelId] = true;
      final active = l.activeRightPanel;
      if (focus || active == null || l.pluginPanelVisible[active] != true) l.activeRightPanel = panelId;
    } else {
      l.bottomVisible = true;
      l.activeBottomTab = bottomTabIndex(panelId);
    }
    save();
  }

  @override
  void hide(String panelId) {
    final panel = _panel(panelId);
    if (panel == null || !isVisible(panelId)) return;
    final l = layout();
    if (isRight(panel)) {
      l.pluginPanelVisible[panelId] = false;
      if (l.activeRightPanel == panelId) l.activeRightPanel = openRightPanels.firstOrNull?.id;
    } else {
      l.activeBottomTab = 0;
    }
    save();
  }

  /// Makes open right panel [panelId] the dock's active tab.
  void activate(String panelId) {
    layout().activeRightPanel = panelId;
    save();
  }

  @override
  ValueListenable<bool> visibility(String panelId) =>
      _visibility.putIfAbsent(panelId, () => ValueNotifier(isVisible(panelId)));

  /// Brings every [visibility] notifier up to date.
  void refresh() {
    for (final e in _visibility.entries) {
      e.value.value = isVisible(e.key);
    }
  }

  void dispose() {
    for (final n in _visibility.values) {
      n.dispose();
    }
    _visibility.clear();
  }
}

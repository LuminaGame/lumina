import 'package:flutter/foundation.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart';

import 'package:lumina_ui/ui/features/main_editor/view_models/editor_layout_state.dart';

/// The host's [EditorPanels]: plugin panel visibility over the
/// editor layout.
///
/// A `PanelDefaultDock.right` panel lives in the right dock: open while
/// `pluginPanelVisible[id]`, the dock's active tab `activeRightPanel`. Any
/// other panel is a bottom-panel tab: open while the bottom panel
/// shows its tab. Every change goes through [save] (the view model's
/// `saveLayoutState`, which notifies); [refresh] brings each panel's
/// [visibility] and [alwaysVisibility] notifiers up to date and runs on every
/// such notification.
///
/// A right-dock panel shows in the level editor only, unless it is an
/// "Always" panel ([isAlwaysVisible]): then it shows in every editor tab,
/// sub-editors included. Which panels a tab shows is [shownRightPanels].
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
  final Map<String, ValueNotifier<bool>> _always = {};

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

  /// The dock's panels on a tab: every open one on the level tab, only the
  /// open "Always" ones on any other tab.
  List<EditorPanelDescriptor> shownRightPanels({required bool levelTab}) =>
      [for (final p in openRightPanels) if (levelTab || isAlwaysVisible(p.id)) p];

  /// The dock's active panel on a tab: the saved active panel when that tab
  /// shows it, else the first shown one. A tab switch never changes the
  /// saved choice.
  EditorPanelDescriptor? activeShownPanel({required bool levelTab}) {
    final shown = shownRightPanels(levelTab: levelTab);
    if (shown.isEmpty) return null;
    return shown.firstWhere((p) => p.id == layout().activeRightPanel, orElse: () => shown.first);
  }

  /// Whether right-dock panel [panelId] shows in every editor tab: the
  /// user's choice when there is one, else its plugin's default.
  bool isAlwaysVisible(String panelId) =>
      layout().pluginPanelAlways[panelId] ?? _panel(panelId)?.defaultAlwaysVisible ?? false;

  /// Saves the user's "Always" choice for [panelId].
  void setAlwaysVisible(String panelId, bool always) {
    layout().pluginPanelAlways[panelId] = always;
    save();
  }

  void toggleAlwaysVisible(String panelId) => setAlwaysVisible(panelId, !isAlwaysVisible(panelId));

  /// [isAlwaysVisible] as a listenable, one notifier per id.
  ValueListenable<bool> alwaysVisibility(String panelId) =>
      _always.putIfAbsent(panelId, () => ValueNotifier(isAlwaysVisible(panelId)));

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

  /// Brings every [visibility] and [alwaysVisibility] notifier up to date.
  void refresh() {
    for (final e in _visibility.entries) {
      e.value.value = isVisible(e.key);
    }
    for (final e in _always.entries) {
      e.value.value = isAlwaysVisible(e.key);
    }
  }

  void dispose() {
    for (final n in [..._visibility.values, ..._always.values]) {
      n.dispose();
    }
    _visibility.clear();
    _always.clear();
  }
}

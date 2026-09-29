import 'package:flutter/foundation.dart';

/// Opens, closes and observes plugin panels, reached through
/// `LuminaEditorContext.panels`. A panel id is the `EditorPanelDescriptor.id`
/// it was registered with. A `PanelDefaultDock.right` panel lives in the
/// editor's right dock (closed until shown); other panels are tabs of the
/// bottom panel.
abstract class EditorPanels {
  const EditorPanels();

  /// A working in-memory implementation for a context with no editor behind
  /// it (tests, a bare registration context).
  factory EditorPanels.detached() = _DetachedEditorPanels;

  bool isVisible(String panelId);

  /// Opens [panelId]; with [focus] it becomes the dock's active tab.
  void show(String panelId, {bool focus = true});

  void hide(String panelId);

  void toggle(String panelId) => isVisible(panelId) ? hide(panelId) : show(panelId);

  /// Whether [panelId] is open, notified on every change, however it was made
  /// (the Window menu, the dock's close button, Reset Layout, a plugin call).
  /// One notifier per id; unknown ids are `false`.
  ValueListenable<bool> visibility(String panelId);
}

class _DetachedEditorPanels extends EditorPanels {
  final Map<String, ValueNotifier<bool>> _visible = {};

  ValueNotifier<bool> _of(String id) => _visible.putIfAbsent(id, () => ValueNotifier(false));

  @override
  bool isVisible(String panelId) => _visible[panelId]?.value ?? false;

  @override
  void show(String panelId, {bool focus = true}) => _of(panelId).value = true;

  @override
  void hide(String panelId) {
    _visible[panelId]?.value = false;
  }

  @override
  ValueListenable<bool> visibility(String panelId) => _of(panelId);
}

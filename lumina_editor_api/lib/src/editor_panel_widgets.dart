import 'package:flutter/foundation.dart';

import 'package:lumina_editor_api/src/api_types.dart' show LuminaEditorContext;

/// One editor panel Widget Blueprint the editor runs (a plugin's
/// `content/EPW_*.lmas` or a project's), as `EditorPanelWidgets` lists it.
@immutable
class EditorPanelWidgetInfo {
  const EditorPanelWidgetInfo({
    required this.id,
    required this.title,
    required this.dock,
    required this.owner,
    this.capabilities = const [],
    this.open = false,
    this.running = false,
    this.errors = const [],
  });

  /// `<plugin name>/<asset path>` or `project/<asset path>`.
  final String id;
  final String title;

  /// `left`, `right`, `bottom`, `tab`, `dialog` or `projectSettings`.
  final String dock;

  /// The plugin's name, or `project`.
  final String owner;
  final List<String> capabilities;
  final bool open;
  final bool running;

  /// Why it does not run (graph errors), empty when it runs.
  final List<String> errors;
}

/// Lists, opens, closes and observes the editor panel Widget Blueprints the
/// editor runs (`LuminaEditorContext.editorPanels`): an in-process plugin
/// opens one of its panels from a command. A compiled plugin's own Flutter
/// panels are [EditorPanels]'.
abstract class EditorPanelWidgets {
  const EditorPanelWidgets();

  /// No editor behind the context: nothing to list, open does nothing.
  factory EditorPanelWidgets.detached() = _DetachedEditorPanelWidgets;

  List<EditorPanelWidgetInfo> get all;

  EditorPanelWidgetInfo? byId(String id) {
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }

  bool isOpen(String id) => byId(id)?.open ?? false;

  /// Opens [id] where it docks (a dialog modally).
  void open(String id);

  /// Closes [id]; its Destruct runs.
  void close(String id);

  /// Notified when panels are added, removed, reloaded, opened or closed.
  Listenable get changes;
}

class _DetachedEditorPanelWidgets extends EditorPanelWidgets {
  final ChangeNotifier _changes = ChangeNotifier();

  @override
  List<EditorPanelWidgetInfo> get all => const [];

  @override
  void open(String id) {}

  @override
  void close(String id) {}

  @override
  Listenable get changes => _changes;
}

/// A context that reaches the editor's editor panel Widget Blueprints (the
/// editor's own registry implements it).
abstract interface class EditorPanelWidgetsProvider {
  EditorPanelWidgets get editorPanelWidgets;
}

/// `LuminaEditorContext.editorPanels`: the editor panel Widget Blueprints the
/// editor runs (a plugin's `content/EPW_*.lmas`, the project's) — list,
/// open, close, observe. Detached (empty) for a context with no editor.
extension EditorPanelWidgetsOfContext on LuminaEditorContext {
  EditorPanelWidgets get editorPanels {
    final self = this;
    return self is EditorPanelWidgetsProvider ? (self as EditorPanelWidgetsProvider).editorPanelWidgets : EditorPanelWidgets.detached();
  }
}

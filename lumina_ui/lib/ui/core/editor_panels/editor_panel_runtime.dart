import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart' show PluginSettingsHandle;
import 'package:lumina_editor_data/lumina_editor.dart';

import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_editor_nodes.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/umg_document.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/umg_widget_codegen.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/widget_class_catalog.dart';

/// The step budget of one editor panel event: at most this many nodes or
/// this long, so a runaway graph never freezes the editor.
const int kEditorPanelMaxNodes = 1000000;
const Duration kEditorPanelMaxEventDuration = Duration(milliseconds: 250);

/// One discovered editor panel compiled for the editor's VM: its designer
/// document, its element class and its graph class (null without a graph),
/// with the compile errors that keep it from running.
class EditorPanelRuntime {
  EditorPanelRuntime._(this.entry, this.document, this.widgetClass, this.graphClass, this.errors, this.warnings);

  final EditorPanelEntry entry;
  final UmgDocument document;
  final LuminaBlueprintWidgetClass widgetClass;
  final LuminaBlueprintClass? graphClass;

  /// Why the panel cannot run (a malformed `editorPanel` block, graph errors).
  final List<String> errors;
  final List<String> warnings;

  String get id => entry.id;
  bool get hasErrors => errors.isNotEmpty;

  /// The `editorPanel` block (defaults when it is malformed: the panel then
  /// shows its error instead of running).
  LuminaEditorPanelInfo get info => entry.info ?? LuminaEditorPanelInfo(title: entry.className);

  String get title => entry.displayTitle;

  /// Compiles [entry] (UI isolate: a panel graph is small; the file was
  /// read and parsed off it by the catalog).
  factory EditorPanelRuntime.compile(EditorPanelEntry entry) {
    final errors = <String>[];
    final warnings = <String>[];
    if (entry.infoError != null) errors.add(entry.infoError!);
    UmgDocument document;
    try {
      document = UmgDocument.fromJson(entry.payload);
    } on Object catch (e) {
      document = UmgDocument.createDefault();
      errors.add('The panel cannot be read: $e');
    }
    final widgetClass = WidgetClassCatalog.fromUmgDocument(entry.className, document);
    LuminaBlueprintClass? graphClass;
    final graph = document.blueprint;
    if (graph != null) {
      final widget = LuminaWidgetBlueprintDocument(
        widgetClass: entry.className,
        variables: UmgWidgetCodegen.variablesOf(document),
        blueprint: BlueprintEditorNodes.forEngine(graph),
      );
      if (!widget.isEmpty) {
        final capabilities = {for (final c in (entry.info?.capabilities ?? const <LuminaEditorPanelCapability>{})) c.name};
        graphClass = LuminaBlueprintClass.forEditorPanel(widget, capabilities: capabilities);
        for (final d in graphClass.diagnostics) {
          final where = d.nodeId == null ? '' : ' (node ${d.nodeId})';
          (d.isError ? errors : warnings).add('${d.message}$where');
        }
      }
    }
    // Choosing an asset goes through the Asset Picker element, never a
    // text field holding a path.
    for (final n in document.allNodes) {
      final textField = n.type == UmgWidgetType.editableText || n.type == UmgWidgetType.shadcnTextField;
      if (textField && RegExp(r'asset|path', caseSensitive: false).hasMatch('${n.name} ${n.props['hint'] ?? ''}')) {
        warnings.add("'${n.name}' looks like an asset path typed into a text field: use Asset Picker.");
      }
    }
    return EditorPanelRuntime._(entry, document, widgetClass, graphClass, errors, warnings);
  }

  /// A fresh widget instance map of this panel (one state map per element,
  /// seeded from the designer).
  Map<String, Object?> newInstanceMap(String registryClass) => <String, Object?>{
        'class': registryClass,
        'owner': null,
        'inViewport': false,
        'zOrder': 0,
        'visibility': 'Visible',
        'elements': <String, Object?>{for (final e in widgetClass.elements) e.name: LuminaWidgetClassRegistry.newElementState(e)},
      };
}

/// One open editor panel: its instance map (what the renderer and the graph
/// share), the binding that rebuilds changed elements, and its script in the
/// editor's VM.
class EditorPanelInstance {
  EditorPanelInstance(this.runtime, this.map, this.serial) : binding = LuminaUmgInstanceBinding(map);

  EditorPanelRuntime runtime;
  Map<String, Object?> map;
  LuminaUmgInstanceBinding binding;
  final int serial;
  LuminaBlueprintUserWidget? script;

  /// The message of the last event the step budget stopped; the panel shows
  /// it with a Reload button until it is reloaded.
  String? stoppedMessage;

  /// The last compile of a saved version that failed: the previous version
  /// keeps running under this banner.
  List<String>? reloadErrors;

  /// How often the panel's elements were asked to rebuild.
  int rebuilds = 0;

  /// Whether Construct ran (and Destruct has not).
  bool constructed = false;

  /// The panel's mounted view, for dialogs, toasts and popovers.
  BuildContext? viewContext;

  /// An open `Pick Asset`: the asset picker popup shown over the panel, and
  /// what completes when an asset is chosen (null: dismissed).
  ({Set<AssetType>? types, Completer<String?> done})? pickRequest;

  /// A `dialog` panel: completes with Close This Panel's Result Json, or
  /// null when dismissed.
  Completer<Object?>? dialogResult;

  /// Menu items the graph added (Add Panel Menu Item): command id → custom event.
  final Map<String, String> menuEvents = {};

  /// Progress bars the graph shows (Show Progress), by id.
  final Map<String, ({String text, double value})> progress = {};

  /// The last pointer position over the panel (where a context menu opens).
  Offset? lastPointer;

  /// The Project Settings working copy when the panel is a plugin's
  /// `projectSettings` section.
  PluginSettingsHandle? settings;

  String get panelId => runtime.id;

  /// The state map of element [name].
  Map<String, Object?>? element(String name) {
    final elements = map['elements'];
    final e = elements is Map ? elements[name] : null;
    return e is Map<String, Object?> ? e : null;
  }

  Map<String, Object?> get elements {
    final e = map['elements'];
    return e is Map<String, Object?> ? e : <String, Object?>{};
  }

  /// Rebuilds the elements whose state changed.
  void refresh() {
    rebuilds++;
    binding.refresh();
  }
}

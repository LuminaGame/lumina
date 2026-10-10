import 'dart:ui' show Offset;

import 'package:lumina_editor_data/lumina_editor.dart';

import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_editor_nodes.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_graph_clipboard.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_graph_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/material_graph_editor.dart';

/// What a paste did: the placed nodes (now the selection) and why the
/// others were left out.
class BlueprintPasteResult {
  final List<LuminaBlueprintNode> pasted;
  final List<String> skipped;

  /// Variables the paste declared because the graph's Blueprint lacked them.
  final List<String> declaredVariables;

  const BlueprintPasteResult({this.pasted = const [], this.skipped = const [], this.declaredVariables = const []});

  static const BlueprintPasteResult nothing = BlueprintPasteResult();
}

/// Copy, cut, paste and duplicate for every graph that edits through a
/// [BlueprintGraphEditor] (Blueprint, Level, Widget and Anim Blueprint
/// graphs, the material graph). The clipboard text itself is the canvas's
/// business; these work on [BlueprintGraphClipboard]s.
extension BlueprintGraphClipboardOps on BlueprintGraphEditor {
  /// The graph family of this editor, written into copies so a material
  /// copy never pastes into a Blueprint and back.
  String get clipboardGraphKind =>
      this is MaterialGraphEditor ? BlueprintGraphClipboard.materialKind : BlueprintGraphClipboard.blueprintKind;

  /// The selected nodes as a clipboard; null when nothing is selected.
  BlueprintGraphClipboard? copySelection() {
    final ids = selectedNodeIds;
    if (ids.isEmpty) return null;
    return BlueprintGraphClipboard.copy(graph, ids, graphKind: clipboardGraphKind, variableOf: context.variable);
  }

  /// Removes the selection after copying it, as one undo step `Cut N nodes`.
  BlueprintGraphClipboard? cutSelection() {
    final copy = copySelection();
    if (copy == null) return null;
    final ids = {for (final n in copy.nodes) n.id};
    final removed = host.mutate(ids.length == 1 ? 'Cut node' : 'Cut ${ids.length} nodes', () {
      final before = graph.nodes.length;
      graph.wires.removeWhere((w) => ids.contains(w.fromNodeId) || ids.contains(w.toNodeId));
      graph.nodes.removeWhere((n) => ids.contains(n.id));
      return graph.nodes.length < before;
    });
    if (removed != true) return null;
    clearSelection();
    return copy;
  }

  /// Pastes [clipboard] with its top-left node at [at] (canvas units), as
  /// one undo step `Paste N nodes`: fresh ids, the copied wires between the
  /// pasted nodes, missing variables declared with the copied type, and
  /// the pasted nodes selected. Left out (and named in
  /// [BlueprintPasteResult.skipped]): nodes this graph does not accept and
  /// events the graph already has (one node per event).
  BlueprintPasteResult pasteClipboard(BlueprintGraphClipboard clipboard, Offset at) {
    if (clipboard.isEmpty) return BlueprintPasteResult.nothing;
    if (clipboard.graphKind != clipboardGraphKind) {
      return BlueprintPasteResult(skipped: [
        clipboard.graphKind == BlueprintGraphClipboard.materialKind
            ? 'Material nodes cannot be pasted into a Blueprint graph'
            : 'Blueprint nodes cannot be pasted into a material graph',
      ]);
    }
    final skipped = <String>[];
    final events = <String>{
      for (final n in nodes) ?BlueprintGraphClipboard.singleInstanceKey(n),
    };
    bool keep(LuminaBlueprintNode n) {
      if (BlueprintEditorNodes.isEditorOnly(n.registryId)) return true;
      if (!accepts(n.registryId)) {
        skipped.add('${n.title}: not allowed in this graph');
        return false;
      }
      final key = BlueprintGraphClipboard.singleInstanceKey(n);
      if (key != null && !events.add(key)) {
        skipped.add('${n.title}: this graph already has it (an event can have one node)');
        return false;
      }
      return true;
    }

    final made = clipboard.instantiate(at: at, newId: BlueprintGraphEditor.newId, keep: keep);
    if (made.nodes.isEmpty) return BlueprintPasteResult(skipped: skipped);
    final declared = <String>[];
    final pasted = host.mutate<List<LuminaBlueprintNode>?>(made.nodes.length == 1 ? 'Paste node' : 'Paste ${made.nodes.length} nodes', () {
      for (final n in made.nodes) {
        final name = BlueprintGraphClipboard.memberVariableOf(n);
        if (name == null || declared.contains(name) || context.variable(name) != null) continue;
        final source = clipboard.variables.where((v) => v.name == name).firstOrNull;
        if (source == null) continue;
        host.declareVariable(LuminaBlueprintVariable.fromJson(source.toJson()));
        declared.add(name);
      }
      graph.nodes.addAll(made.nodes);
      graph.wires.addAll(made.wires);
      return made.nodes;
    });
    if (pasted == null) return BlueprintPasteResult(skipped: skipped);
    selectMany({for (final n in pasted) n.id});
    return BlueprintPasteResult(pasted: pasted, skipped: skipped, declaredVariables: declared);
  }

  /// Copies the selection and pastes it 30 units down and right, without
  /// touching the system clipboard.
  BlueprintPasteResult duplicateSelection() {
    final copy = copySelection();
    if (copy == null) return BlueprintPasteResult.nothing;
    return pasteClipboard(copy, copy.origin + const Offset(30, 30));
  }
}

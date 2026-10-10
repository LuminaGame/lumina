import 'dart:convert';
import 'dart:ui' show Color, Offset, Rect;

import 'package:flutter/widgets.dart' show BuildContext, Widget;

import 'package:flutter/foundation.dart';
import 'package:lumina_editor_data/lumina_editor.dart';

import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_editor_nodes.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_palette.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_pin_style.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/blueprint_debugger.dart';

part 'blueprint_graph_editor/conversion_wiring.dart';
part 'blueprint_graph_editor/core.dart';
part 'blueprint_graph_editor/presentation.dart';
part 'blueprint_graph_editor/selection.dart';
part 'blueprint_graph_editor/editing.dart';
part 'blueprint_graph_editor/annotations.dart';

/// What a [BlueprintGraphEditor] edits against: the document's variables and
/// input actions, and its undo history. The Blueprint editor, the Animation
/// Blueprint editor's event graph and each transition rule share one canvas
/// through this seam (one graph canvas).
abstract interface class BlueprintGraphHost implements Listenable {
  LuminaBlueprintTypeContext get typeContext;

  /// Available widget classes in the project (UMG widgets).
  List<String> get availableWidgetClasses;

  /// Adds [variable] to the document without recording an undo step: called
  /// inside [mutate] by Promote to Variable, so the
  /// variable and its Set node are one step. Hosts without variables ignore it.
  void declareVariable(LuminaBlueprintVariable variable);

  /// Runs [mutation] as one undoable step labelled [label]. A mutation that
  /// returns null or false changes nothing and records nothing.
  T mutate<T>(String label, T Function() mutation);

  /// Starts a coalesced interaction (a node drag): edits between this and
  /// [endInteraction] become one undo step.
  void beginInteraction(String label);

  /// Ends the interaction. [layoutOnly] edits (moving nodes) do not make the
  /// compiled code stale.
  void endInteraction({bool layoutOnly = false});
}

/// A live problem on a node, drawn as the node's banner.
class BlueprintNodeProblem {
  final String message;
  final bool isError;
  const BlueprintNodeProblem(this.message, {this.isError = true});
}

typedef BlueprintResolvedPins = ({List<LuminaBlueprintPinSpec> inputs, List<LuminaBlueprintPinSpec> outputs});

/// Edits one [LuminaBlueprintGraph] through lumina's node library: placing
/// nodes, wiring typed pins, literals, input actions and variables, with
/// every change an undoable step on the [host]. Selection lives here; the
/// document lives in the host.
class BlueprintGraphEditor extends _BlueprintGraphEditorCore
    with _BlueprintGraphPresentation, _BlueprintGraphSelection, _BlueprintGraphEditing, _BlueprintGraphAnnotations {
  static int _ids = 0;

  BlueprintGraphEditor({
    required super.host,
    required super.graphSource,
    super.nodeFilter,
    super.diagnosticsSource,
    super.contextSource,
    super.pinOptionsProvider,
    super.pinnedEntriesSource,
  });

  static String newId(String prefix) => '${prefix}_${DateTime.now().microsecondsSinceEpoch}_${_ids++}';

  /// Node settings that are also pins (`class` of Cast To, `element` of Get
  /// Element, `component` of Get Component): editing them retitles and
  /// re-types the node, so [setLiteral] routes them to [setNodeSetting].
  static const Map<String, Set<String>> settingPins = {
    LuminaBlueprintNodeLibrary.castTo: {'class'},
    'get_component_by_class': {'class'},
    'add_component': {'class'},
    LuminaBlueprintNodeLibrary.getWidgetElement: {'element'},
    LuminaBlueprintNodeLibrary.getComponent: {'component'},
  };

  /// Nodes whose `Key` pin names an engine input key.
  static const Set<String> inputKeyNodes = {'is_input_key_down', 'get_input_key_time_down', 'was_input_key_just_pressed'};

  /// The Timeline node's tracks as stored.
  static List<LuminaTimelineTrack> timelineTracks(LuminaBlueprintNode node) {
    final stored = node.literals['tracks'];
    if (stored is! List) return const [];
    return [for (final t in stored) if (t is Map) LuminaTimelineTrack.fromJson(t)];
  }

  // ---------------------------------------------------------------------------
  // Moving
  // ---------------------------------------------------------------------------

  void beginMove() => host.beginInteraction('Move nodes');

  void moveNodes(Iterable<String> ids, Offset delta) {
    for (final id in ids) {
      final n = node(id);
      if (n == null) continue;
      n.x += delta.dx;
      n.y += delta.dy;
    }
    notifyListeners();
  }

  void endMove() => host.endInteraction(layoutOnly: true);

  @override
  void dispose() {
    focusRequest.dispose();
    super.dispose();
  }
}

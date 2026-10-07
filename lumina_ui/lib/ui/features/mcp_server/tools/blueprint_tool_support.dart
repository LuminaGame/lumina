import 'package:lumina_editor_data/lumina_editor.dart';

import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_graph_ref.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_pin_style.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_graph_editor.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_protocol.dart';

// The node / pin / wire JSON moved to graph_json.dart.
export 'graph_json.dart' show mcpPinSpec, mcpNodeJson, mcpWireJson;

/// Shared by the Blueprint tool sets.

/// `asset` for every Blueprint tool.
const String kBlueprintAssetArg = 'The Blueprint: its project-relative .lmas path (list_assets with type "actor") or unique '
    'file name; "level" for the active level\'s Level Blueprint, or a level .lmas for that level\'s.';

/// `graph` for the graph tools.
const String kBlueprintGraphArg = 'The graph: "event" (default), "function:<name>" or "macro:<name>" (get_blueprint lists '
    'them). The Construction Script is not a node graph.';

/// A mutation refused while Play-In-Editor runs (the editor freezes edits).
McpToolResult? mcpRefuseWhilePlaying(EditorViewModel vm) {
  if (vm.isPlaying || vm.transactions.isFrozen) {
    return McpToolResult.error('Stop Play first (stop_pie): the editor does not take edits while Play-In-Editor runs.');
  }
  return null;
}

/// The graph [name] names on [editor], and its editor. Throws a -32602 for a
/// graph that is not a node graph or does not exist; never falls back to the
/// event graph.
(BlueprintGraphRef, BlueprintGraphEditor) mcpResolveGraph(BlueprintEditorViewModel editor, String? name) {
  final ref = mcpGraphRef(editor, name);
  return (ref, editor.graphEditor(ref));
}

BlueprintGraphRef mcpGraphRef(BlueprintEditorViewModel editor, String? name) {
  final doc = editor.document;
  final available = [
    'event',
    for (final f in doc.functions) 'function:${f.name}',
    for (final m in doc.macros) 'macro:${m.name}',
  ];
  Never unknown(String why) => throw JsonRpcException(JsonRpcErrorCode.invalidParams, '$why Graphs: ${available.join(', ')}.');
  if (name == null || name == 'event' || name == 'EventGraph') return BlueprintGraphRef.eventGraph;
  if (name == 'construction' || name == 'construction_script') {
    unknown('The Construction Script has no node graph (its steps are the Components and Class Defaults).');
  }
  if (name.startsWith('function:')) {
    final fn = name.substring('function:'.length);
    if (doc.function(fn) == null) unknown('No function "$fn".');
    return BlueprintGraphRef.function(fn);
  }
  if (name.startsWith('macro:')) {
    final m = name.substring('macro:'.length);
    if (doc.macro(m) == null) unknown('No macro "$m".');
    return BlueprintGraphRef.macro(m);
  }
  unknown('Unknown graph "$name".');
}

String mcpGraphName(BlueprintGraphRef ref) => switch (ref.kind) {
      BlueprintGraphKind.function => 'function:${ref.name}',
      BlueprintGraphKind.macro => 'macro:${ref.name}',
      _ => 'event',
    };

Map<String, Object?> mcpBlueprintUndo(BlueprintEditorViewModel editor) => {
      'can_undo': editor.transactions.canUndo,
      'undo_label': editor.transactions.canUndo ? editor.transactions.undoLabel : null,
      'can_redo': editor.transactions.canRedo,
    };

Map<String, Object?> mcpVariableJson(LuminaBlueprintVariable v) => {'name': v.name, 'type': v.typeName, 'default': v.defaultValue};

/// `[{name, type, default?}]` as Blueprint variables; a type lumina cannot
/// parse is a -32602 naming the accepted forms.
List<LuminaBlueprintVariable> mcpParseParams(Object? raw, String argName) {
  if (raw is! List) throw JsonRpcException(JsonRpcErrorCode.invalidParams, '"$argName" must be an array of {name, type, default?}');
  return [
    for (final item in raw)
      if (item is Map && item['name'] is String && item['type'] is String)
        LuminaBlueprintVariable(
          name: (item['name'] as String).trim(),
          typeName: mcpCheckType(item['type'] as String),
          defaultValue: item['default'] ?? BlueprintPinStyle.defaultValueFor(item['type'] as String),
        )
      else
        throw JsonRpcException(JsonRpcErrorCode.invalidParams, 'Each entry of "$argName" needs a string name and type: $item'),
  ];
}

/// [type] when lumina can store it as a variable type, else a -32602.
String mcpCheckType(String type) {
  final parsed = LuminaPinType.parseVariableType(type);
  if (parsed == null || parsed == LuminaPinType.exec || parsed == LuminaPinType.delegate) {
    throw JsonRpcException(
      JsonRpcErrorCode.invalidParams,
      'Unknown variable type "$type". Types: Bool, Integer, Float, Name, String, Vector, Vector2D, Rotator, Color, '
      'Transform, Object, Actor, Actor:<BP>, Widget:<WBP>, Component:<type>, Enum:<name>, Array:<type>.',
    );
  }
  return type;
}

import 'dart:convert';
import 'dart:ui' show Offset;

import 'package:lumina_editor_data/lumina_editor.dart';

import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_editor_nodes.dart';

/// Graph nodes on the clipboard: copied nodes, the wires between them, and
/// the declarations of the member variables their Get / Set nodes read, so
/// a paste into a Blueprint without the variable can declare it.
///
/// On the system clipboard it is a JSON object whose `format` is
/// [format] and whose `version` is at most [version]; any other text
/// decodes to null, so pasting text that is not graph nodes does nothing.
class BlueprintGraphClipboard {
  static const String format = 'lumina.graph-nodes';
  static const int version = 1;

  /// The graph family the nodes come from: [blueprintKind] (Blueprint,
  /// Level, Widget and Anim Blueprint graphs share one node library) or
  /// [materialKind].
  static const String blueprintKind = 'blueprint';
  static const String materialKind = 'material';

  final String graphKind;
  final List<LuminaBlueprintNode> nodes;

  /// Only wires whose both ends are in [nodes].
  final List<LuminaBlueprintWire> wires;
  final List<LuminaBlueprintVariable> variables;

  BlueprintGraphClipboard({
    required this.graphKind,
    required this.nodes,
    required this.wires,
    this.variables = const [],
  });

  /// Copies nodes [ids] of [graph]: deep copies of the nodes, the wires
  /// between them (wires to other nodes are dropped) and, through
  /// [variableOf], the variables their own-class Get / Set nodes name.
  factory BlueprintGraphClipboard.copy(
    LuminaBlueprintGraph graph,
    Set<String> ids, {
    required String graphKind,
    LuminaBlueprintVariable? Function(String name)? variableOf,
  }) {
    final nodes = [
      for (final n in graph.nodes)
        if (ids.contains(n.id)) _clone(n),
    ];
    final kept = {for (final n in nodes) n.id};
    final wires = [
      for (final w in graph.wires)
        if (kept.contains(w.fromNodeId) && kept.contains(w.toNodeId)) LuminaBlueprintWire.fromJson(w.toJson()),
    ];
    final variables = <String, LuminaBlueprintVariable>{};
    if (variableOf != null) {
      for (final n in nodes) {
        final name = memberVariableOf(n);
        if (name == null || variables.containsKey(name)) continue;
        final v = variableOf(name);
        if (v != null) variables[name] = LuminaBlueprintVariable.fromJson(v.toJson());
      }
    }
    return BlueprintGraphClipboard(graphKind: graphKind, nodes: nodes, wires: wires, variables: variables.values.toList());
  }

  bool get isEmpty => nodes.isEmpty;

  /// The variable a Get / Set node of this Blueprint's own variables names;
  /// null for other nodes and for another class's variable (`class` set).
  static String? memberVariableOf(LuminaBlueprintNode node) {
    if (node.registryId != LuminaBlueprintNodeLibrary.variableGet && node.registryId != LuminaBlueprintNodeLibrary.variableSet) {
      return null;
    }
    final cls = node.literals['class'];
    if (cls is String && cls.isNotEmpty) return null;
    final name = node.literals['variable'];
    return name is String && name.isNotEmpty ? name : null;
  }

  /// The key under which a graph allows one node of an event: the same key
  /// the compiler's "an event can have one node" rule uses. Null for nodes
  /// that are not events.
  static String? singleInstanceKey(LuminaBlueprintNode node) {
    final spec = LuminaBlueprintNodeLibrary.spec(node.registryId);
    if (spec == null || spec.kind != LuminaBlueprintNodeKind.event) return null;
    return switch (spec.id) {
      LuminaBlueprintNodeLibrary.enhancedInputAction => '${spec.id}:${node.literals['action']}',
      LuminaBlueprintNodeLibrary.customEvent => '${spec.id}:${node.literals['name']}',
      LuminaBlueprintNodeLibrary.eventInterfaceFunction => '${spec.id}:${node.literals['function']}',
      LuminaBlueprintNodeLibrary.eventWidgetElement => '${spec.id}:${node.literals['element']}:${node.literals['event']}',
      _ => LuminaBlueprintNodeLibrary.levelEvents[spec.id] ?? spec.id,
    };
  }

  /// The top-left corner of the copied nodes, in canvas units.
  Offset get origin {
    if (nodes.isEmpty) return Offset.zero;
    var left = double.infinity;
    var top = double.infinity;
    for (final n in nodes) {
      if (n.x < left) left = n.x;
      if (n.y < top) top = n.y;
    }
    return Offset(left, top);
  }

  /// The clipboard text.
  String encode() => jsonEncode({
        'format': format,
        'version': version,
        'graph': graphKind,
        'nodes': [for (final n in nodes) n.toJson()],
        'wires': [for (final w in wires) w.toJson()],
        'variables': [for (final v in variables) v.toJson()],
      });

  /// Parses clipboard [text]; null for anything that is not Lumina graph
  /// nodes (plain text, other JSON, a newer version, no nodes).
  static BlueprintGraphClipboard? decode(String? text) {
    if (text == null) return null;
    final trimmed = text.trimLeft();
    if (!trimmed.startsWith('{')) return null;
    try {
      final map = jsonDecode(trimmed);
      if (map is! Map || map['format'] != format) return null;
      final v = map['version'];
      if (v is! int || v < 1 || v > version) return null;
      final kind = map['graph'];
      final rawNodes = map['nodes'];
      if (kind is! String || rawNodes is! List || rawNodes.isEmpty) return null;
      final nodes = [
        for (final n in rawNodes)
          if (n is Map) LuminaBlueprintNode.fromJson(Map<String, dynamic>.from(n)),
      ];
      if (nodes.isEmpty || nodes.any((n) => n.id.isEmpty || n.registryId.isEmpty)) return null;
      final ids = {for (final n in nodes) n.id};
      final wires = [
        for (final w in map['wires'] as List? ?? const [])
          if (w is Map) LuminaBlueprintWire.fromJson(Map<String, dynamic>.from(w)),
      ].where((w) => ids.contains(w.fromNodeId) && ids.contains(w.toNodeId)).toList();
      final variables = [
        for (final x in map['variables'] as List? ?? const [])
          if (x is Map) LuminaBlueprintVariable.fromJson(Map<String, dynamic>.from(x)),
      ].where((x) => x.name.isNotEmpty).toList();
      return BlueprintGraphClipboard(graphKind: kind, nodes: nodes, wires: wires, variables: variables);
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  /// Fresh copies of the nodes for a paste: new ids from [newId], moved so
  /// [origin] lands on [at], the wires re-pointed at the new ids. Only
  /// nodes whose old id [keep] accepts are made, and only wires between
  /// them.
  ({List<LuminaBlueprintNode> nodes, List<LuminaBlueprintWire> wires}) instantiate({
    required Offset at,
    required String Function(String prefix) newId,
    bool Function(LuminaBlueprintNode node)? keep,
  }) {
    final delta = at - origin;
    final ids = <String, String>{};
    final out = <LuminaBlueprintNode>[];
    for (final n in nodes) {
      if (keep != null && !keep(n)) continue;
      final prefix = BlueprintEditorNodes.isComment(n)
          ? 'comment'
          : BlueprintEditorNodes.isReroute(n)
              ? 'reroute'
              : 'node';
      final id = newId(prefix);
      ids[n.id] = id;
      final json = n.toJson()
        ..['id'] = id
        ..['position'] = {'x': n.x + delta.dx, 'y': n.y + delta.dy};
      out.add(LuminaBlueprintNode.fromJson(jsonDecode(jsonEncode(json)) as Map<String, dynamic>));
    }
    final wires = [
      for (final w in this.wires)
        if (ids.containsKey(w.fromNodeId) && ids.containsKey(w.toNodeId))
          LuminaBlueprintWire(
            id: newId('wire'),
            fromNodeId: ids[w.fromNodeId]!,
            fromPinId: w.fromPinId,
            toNodeId: ids[w.toNodeId]!,
            toPinId: w.toPinId,
          ),
    ];
    return (nodes: out, wires: wires);
  }

  static LuminaBlueprintNode _clone(LuminaBlueprintNode n) =>
      LuminaBlueprintNode.fromJson(jsonDecode(jsonEncode(n.toJson())) as Map<String, dynamic>);
}

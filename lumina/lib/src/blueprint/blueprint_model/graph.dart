part of '../blueprint_model.dart';

/// A pin as stored on a placed node.
class LuminaBlueprintPin {
  final String id;
  final String name;

  /// Null when the stored type name is unknown.
  final LuminaPinType? type;
  final bool isOutput;
  final dynamic defaultValue;

  /// The class of an object pin; null is any object. Stored as
  /// `"class"`.
  final String? objectClass;

  /// The element type of an array pin; stored as `"of"`.
  final LuminaPinType? elementType;

  /// The enum of an [LuminaPinType.enumeration] pin; stored
  /// as `"enum"`.
  final String? enumName;

  const LuminaBlueprintPin({
    required this.id,
    required this.name,
    required this.type,
    this.isOutput = false,
    this.defaultValue,
    this.objectClass,
    this.elementType,
    this.enumName,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type?.jsonName ?? 'exec',
        if (elementType != null) 'of': elementType!.jsonName,
        if (objectClass != null) 'class': objectClass,
        if (enumName != null) 'enum': enumName,
        'isOutput': isOutput,
        if (defaultValue != null) 'defaultValue': defaultValue,
      };

  factory LuminaBlueprintPin.fromJson(Map<String, dynamic> json) => LuminaBlueprintPin(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        type: LuminaPinType.parse(json['type'] as String?),
        isOutput: json['isOutput'] as bool? ?? false,
        defaultValue: json['defaultValue'],
        objectClass: json['class'] as String?,
        elementType: LuminaPinType.parse(json['of'] as String?),
        enumName: json['enum'] as String?,
      );
}

/// A node placed in a graph: which library node it is ([registryId]), its
/// pins, its literal pin values and where the editor draws it.
class LuminaBlueprintNode {
  final String id;
  final String registryId;
  String title;
  String category;
  double x;
  double y;

  /// ARGB header colour the editor stored; kept for round-tripping only.
  final int? headerColor;
  final List<LuminaBlueprintPin> inputs;
  final List<LuminaBlueprintPin> outputs;

  /// Pin id → literal value for pins without a wire, plus node settings such
  /// as an input action's `action` or a variable node's `variable`.
  final Map<String, dynamic> literals;

  LuminaBlueprintNode({
    required this.id,
    required this.registryId,
    required this.title,
    this.category = 'General',
    this.x = 0.0,
    this.y = 0.0,
    this.headerColor,
    List<LuminaBlueprintPin>? inputs,
    List<LuminaBlueprintPin>? outputs,
    Map<String, dynamic>? literals,
  })  : inputs = inputs ?? <LuminaBlueprintPin>[],
        outputs = outputs ?? <LuminaBlueprintPin>[],
        literals = literals ?? <String, dynamic>{};

  LuminaBlueprintPin? pin(String pinId) {
    for (final p in inputs) {
      if (p.id == pinId) return p;
    }
    for (final p in outputs) {
      if (p.id == pinId) return p;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'registryId': registryId,
        'title': title,
        'category': category,
        'position': {'x': x, 'y': y},
        if (headerColor != null) 'headerColor': headerColor,
        'inputs': inputs.map((p) => p.toJson()).toList(),
        'outputs': outputs.map((p) => p.toJson()).toList(),
        'literals': literals,
      };

  factory LuminaBlueprintNode.fromJson(Map<String, dynamic> json) {
    final pos = json['position'] as Map? ?? const {};
    List<LuminaBlueprintPin> pins(Object? list) => (list as List? ?? const [])
        .map((p) => LuminaBlueprintPin.fromJson(Map<String, dynamic>.from(p as Map)))
        .toList();
    return LuminaBlueprintNode(
      id: json['id'] as String? ?? '',
      registryId: json['registryId'] as String? ?? '',
      title: json['title'] as String? ?? 'Node',
      category: json['category'] as String? ?? 'General',
      x: (pos['x'] as num?)?.toDouble() ?? 0.0,
      y: (pos['y'] as num?)?.toDouble() ?? 0.0,
      headerColor: json['headerColor'] as int?,
      inputs: pins(json['inputs']),
      outputs: pins(json['outputs']),
      literals: Map<String, dynamic>.from(json['literals'] as Map? ?? const {}),
    );
  }
}

/// A wire from an output pin to an input pin.
class LuminaBlueprintWire {
  final String id;
  final String fromNodeId;
  final String fromPinId;
  final String toNodeId;
  final String toPinId;

  const LuminaBlueprintWire({
    required this.id,
    required this.fromNodeId,
    required this.fromPinId,
    required this.toNodeId,
    required this.toPinId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'fromNodeId': fromNodeId,
        'fromPinId': fromPinId,
        'toNodeId': toNodeId,
        'toPinId': toPinId,
      };

  factory LuminaBlueprintWire.fromJson(Map<String, dynamic> json) => LuminaBlueprintWire(
        id: json['id'] as String? ?? '',
        fromNodeId: json['fromNodeId'] as String? ?? '',
        fromPinId: json['fromPinId'] as String? ?? '',
        toNodeId: json['toNodeId'] as String? ?? '',
        toPinId: json['toPinId'] as String? ?? '',
      );
}

/// One node graph (the event graph today).
class LuminaBlueprintGraph {
  final List<LuminaBlueprintNode> nodes;
  final List<LuminaBlueprintWire> wires;

  LuminaBlueprintGraph({List<LuminaBlueprintNode>? nodes, List<LuminaBlueprintWire>? wires})
      : nodes = nodes ?? <LuminaBlueprintNode>[],
        wires = wires ?? <LuminaBlueprintWire>[];

  LuminaBlueprintNode? node(String id) {
    for (final n in nodes) {
      if (n.id == id) return n;
    }
    return null;
  }

  /// Wires leaving [nodeId]'s output [pinId].
  Iterable<LuminaBlueprintWire> wiresFrom(String nodeId, String pinId) =>
      wires.where((w) => w.fromNodeId == nodeId && w.fromPinId == pinId);

  /// The wire into [nodeId]'s input [pinId], if any.
  LuminaBlueprintWire? wireInto(String nodeId, String pinId) {
    for (final w in wires) {
      if (w.toNodeId == nodeId && w.toPinId == pinId) return w;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'nodes': nodes.map((n) => n.toJson()).toList(),
        'connections': wires.map((w) => w.toJson()).toList(),
      };

  factory LuminaBlueprintGraph.fromJson(Map<String, dynamic>? json) => LuminaBlueprintGraph(
        nodes: (json?['nodes'] as List? ?? const [])
            .map((n) => LuminaBlueprintNode.fromJson(Map<String, dynamic>.from(n as Map)))
            .toList(),
        wires: (json?['connections'] as List? ?? const [])
            .map((w) => LuminaBlueprintWire.fromJson(Map<String, dynamic>.from(w as Map)))
            .toList(),
      );
}

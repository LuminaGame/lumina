import 'dart:ui' show Color, Offset;

import 'package:flutter/widgets.dart' show BuildContext, Widget, ValueKey, Padding, EdgeInsets;

import 'package:lumina/lumina.dart';

import '../models/blueprint_palette.dart';
import '../models/material_graph.dart';
import '../services/material_graph_parser.dart';
import '../services/material_graph_types.dart';
import '../../../core/property_editors/asset_picker_select.dart';
import '../../../core/theme/editor_theme.dart';
import 'blueprint_graph_editor.dart';

/// Edits a material graph through the shared Blueprint graph canvas:
/// material expressions instead of lumina's Blueprint
/// node library, float1–float4 and texture pins instead of Blueprint pin
/// types, and the material wiring rule — a wire is refused only for a
/// loop or a texture/number mix-up; any other mismatch is drawn red and
/// reported by the type checker.
class MaterialGraphEditor extends BlueprintGraphEditor {
  final MaterialGraphAnalysis Function() analysis;
  final MaterialSurface Function() surface;

  /// The project's textures, the one bound to a sampler parameter, and the
  /// undoable rebind, for the Texture Sample node's thumbnail picker.
  final List<RealAssetInfo> Function() textures;
  final RealAssetInfo? Function(String parameter) textureFor;
  final bool Function(String parameter, RealAssetInfo? asset) bindTexture;

  MaterialGraphEditor({
    required super.host,
    required super.graphSource,
    required this.analysis,
    required this.surface,
    required this.textures,
    required this.textureFor,
    required this.bindTexture,
  });

  /// The `.mat` sampler a Texture Sample / TextureParameter node reads: its
  /// own parameter, or the TextureParameter wired into Tex.
  String? samplerOf(LuminaBlueprintNode node) {
    if (node.registryId == MaterialNodes.textureParameter) return node.literals['name'] as String?;
    if (node.registryId != MaterialNodes.textureSample) return null;
    final tex = graph.wireInto(node.id, 'tex');
    if (tex != null) return graph.node(tex.fromNodeId)?.literals['name'] as String?;
    return node.literals['parameter'] as String?;
  }

  static const double textureBodyHeight = MaterialGraphLayout.textureBodyHeight;

  @override
  double nodeBodyHeight(LuminaBlueprintNode node) => samplerOf(node) == null ? 0 : textureBodyHeight;

  /// The Texture Sample node: the bound texture's thumbnail and name;
  /// a click opens the searchable picker.
  @override
  Widget? nodeBody(BuildContext context, LuminaBlueprintNode node) {
    final parameter = samplerOf(node);
    if (parameter == null) return null;
    final bound = textureFor(parameter);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: AssetPickerSelect(
        key: ValueKey('node_texture_${node.id}'),
        keyPrefix: 'texture_picker',
        assets: textures(),
        selectedPath: bound?.lmasPath,
        placeholder: 'Unassigned',
        thumbnailSize: 32,
        valueThumbnailSize: 40,
        onSelected: (a) => bindTexture(parameter, a),
        onCleared: () => bindTexture(parameter, null),
      ),
    );
  }

  /// The Blueprint pin type the canvas uses to pick an inline editor.
  static LuminaPinType displayType(MaterialValueType? t) => switch (t) {
        MaterialValueType.float2 => LuminaPinType.vector2D,
        MaterialValueType.float3 => LuminaPinType.vector,
        MaterialValueType.float4 => LuminaPinType.structEnum,
        MaterialValueType.texture => LuminaPinType.object,
        _ => LuminaPinType.float,
      };

  // Material pin colours by component count, a taxonomy of the graph (as
  // Blueprint pin colours are); the values are EditorColors tokens.
  static Color colorFor(MaterialValueType? t) => switch (t) {
        MaterialValueType.float1 => EditorColors.materialPinFloat1,
        MaterialValueType.float2 => EditorColors.materialPinFloat2,
        MaterialValueType.float3 => EditorColors.materialPinFloat3,
        MaterialValueType.float4 => EditorColors.materialPinFloat4,
        MaterialValueType.texture => EditorColors.materialPinTexture,
        null => EditorColors.materialPinUnknown,
      };

  MaterialPinDef? _def(LuminaBlueprintNode node, String pinId, {required bool output}) {
    final pins = output ? MaterialNodes.outputsOf(node) : MaterialNodes.inputsOf(node, surface());
    for (final p in pins) {
      if (p.id == pinId) return p;
    }
    return null;
  }

  /// The resolved type of a pin: its fixed type, else what flows through it.
  MaterialValueType? typeOf(String nodeId, String pinId, {required bool output}) {
    final n = node(nodeId);
    if (n == null) return null;
    final def = _def(n, pinId, output: output);
    if (def?.type != null) return def!.type;
    final a = analysis();
    return output ? a.outputType(nodeId, pinId) : a.inputType(nodeId, pinId);
  }

  @override
  BlueprintResolvedPins pinsOf(LuminaBlueprintNode node) {
    LuminaBlueprintPinSpec spec(MaterialPinDef p, {required bool output}) => LuminaBlueprintPinSpec(
          p.id,
          p.name,
          displayType(typeOf(node.id, p.id, output: output) ?? p.type),
          defaultValue: p.defaultValue,
        );
    return (
      inputs: [for (final p in MaterialNodes.inputsOf(node, surface())) spec(p, output: false)],
      outputs: [for (final p in MaterialNodes.outputsOf(node)) spec(p, output: true)],
    );
  }

  // ---------------------------------------------------------------------------
  // Presentation seams
  // ---------------------------------------------------------------------------

  @override
  Color pinColor(LuminaBlueprintNode node, LuminaBlueprintPinSpec pin, {required bool output}) {
    final def = _def(node, pin.id, output: output);
    if (def?.unused == true) return const Color(0x66B0BEC5); // unused pins are greyed
    return colorFor(typeOf(node.id, pin.id, output: output));
  }

  @override
  String pinTypeLabel(LuminaBlueprintNode node, LuminaBlueprintPinSpec pin, {required bool output}) =>
      typeOf(node.id, pin.id, output: output)?.label ?? 'any float';

  /// Only inputs with a "Const" fallback (Multiply's B, Lerp's Alpha,
  /// Fresnel's exponent) edit a constant on the node.
  @override
  bool showsInlineLiteral(LuminaBlueprintNode node, LuminaBlueprintPinSpec pin) =>
      _def(node, pin.id, output: false)?.defaultValue != null;

  @override
  bool wireHasProblem(LuminaBlueprintWire wire) =>
      analysis().inputHasError(wire.toNodeId, wire.toPinId) || super.wireHasProblem(wire);

  @override
  List<BlueprintPaletteEntry> compatibleEntries(List<BlueprintPaletteEntry> entries, BlueprintPinRef from) {
    final texture = from.type == LuminaPinType.object;
    return [
      for (final e in entries)
        if (_compatiblePin(e.registryId, texture: texture, wantInput: from.isOutput) != null) e,
    ];
  }

  /// The pin of a new [registryId] node that joins a wire carrying a texture
  /// (or a number): an input when the wire comes from an output.
  static String? _compatiblePin(String registryId, {required bool texture, required bool wantInput}) {
    final spec = MaterialNodes.spec(registryId);
    if (spec == null) return null;
    final pins = wantInput ? spec.inputs : spec.outputs;
    for (final p in pins) {
      if ((p.type == MaterialValueType.texture) == texture) return p.id;
    }
    // A Custom node's inputs are named per node; a new one gets 'In'.
    if (wantInput && !texture && registryId == MaterialNodes.custom) return 'In';
    return null;
  }

  // ---------------------------------------------------------------------------
  // Reading
  // ---------------------------------------------------------------------------

  @override
  List<BlueprintPaletteEntry> paletteEntries() => [
        for (final s in MaterialNodes.all)
          if (accepts(s.id))
            BlueprintPaletteEntry(
              registryId: s.id,
              title: s.title,
              category: s.category,
              keywords: s.keywords,
              headerColor: s.headerColor,
              kind: LuminaBlueprintNodeKind.pure,
              tooltip: s.tooltip.isEmpty ? null : s.tooltip,
            ),
      ];

  @override
  List<BlueprintNodeProblem> problems(LuminaBlueprintNode node) => [
        for (final d in analysis().diagnosticsFor(node.id)) BlueprintNodeProblem(d.message, isError: d.isError),
      ];

  @override
  Set<String> get errorNodeIds => analysis().errorNodeIds;

  @override
  String? whyNotConnect(String fromNodeId, String fromPinId, String toNodeId, String toPinId) {
    if (fromNodeId == toNodeId) return 'A node cannot connect to itself';
    final from = node(fromNodeId);
    final to = node(toNodeId);
    if (from == null || to == null) return 'No such pin';
    final out = _def(from, fromPinId, output: true);
    final inp = _def(to, toPinId, output: false);
    if (out == null || inp == null) return 'No such pin';
    final outTexture = out.type == MaterialValueType.texture;
    final inTexture = inp.type == MaterialValueType.texture;
    if (outTexture && !inTexture) return 'A Texture2D goes into a TextureSample\'s Tex input';
    if (!outTexture && inTexture) return 'Tex takes a TextureParameter';
    if (_reaches(toNodeId, fromNodeId)) return 'This wire would make a loop';
    return null;
  }

  /// Whether [from] feeds [to] through existing wires.
  bool _reaches(String from, String to) {
    final stack = [to];
    final seen = <String>{};
    while (stack.isNotEmpty) {
      final id = stack.removeLast();
      if (id == from) return true;
      if (!seen.add(id)) continue;
      for (final w in wires) {
        if (w.toNodeId == id) stack.add(w.fromNodeId);
      }
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // Editing
  // ---------------------------------------------------------------------------

  @override
  bool accepts(String registryId) =>
      MaterialNodes.spec(registryId) != null &&
      registryId != MaterialNodes.output &&
      registryId != MaterialNodes.customFragment;

  /// A parameter name no node uses yet: [base], `base_1`, `base_2`, …
  String uniqueParameterName(String base) {
    final taken = {for (final n in nodes) ?MaterialNodes.parameterName(n)};
    if (!taken.contains(base)) return base;
    var k = 1;
    while (taken.contains('${base}_$k')) {
      k++;
    }
    return '${base}_$k';
  }

  LuminaBlueprintNode _create(String registryId, Offset position, Map<String, dynamic>? literals) {
    final spec = MaterialNodes.spec(registryId)!;
    final settings = <String, dynamic>{...?literals};
    if (MaterialNodes.isParameter(registryId) && settings['name'] == null) {
      settings['name'] = uniqueParameterName(spec.defaults['name'] as String);
    }
    if (registryId == MaterialNodes.textureSample && settings['parameter'] == null) {
      settings['parameter'] = uniqueParameterName('Texture');
    }
    if (registryId == MaterialNodes.custom && settings['inputs'] == null) {
      settings['inputs'] = <String>['In'];
      settings['code'] = 'return In;';
      settings['outputType'] = 'float3';
    }
    return MaterialNodes.create(
      registryId,
      id: BlueprintGraphEditor.newId('node'),
      x: position.dx,
      y: position.dy,
      literals: settings,
    );
  }

  void _wire(String fromNodeId, String fromPinId, String toNodeId, String toPinId) {
    graph.wires.removeWhere((w) => w.toNodeId == toNodeId && w.toPinId == toPinId);
    graph.wires.add(LuminaBlueprintWire(
      id: BlueprintGraphEditor.newId('wire'),
      fromNodeId: fromNodeId,
      fromPinId: fromPinId,
      toNodeId: toNodeId,
      toPinId: toPinId,
    ));
  }

  @override
  LuminaBlueprintNode? addNode(String registryId, Offset position, {Map<String, dynamic>? literals}) {
    if (!accepts(registryId)) return null;
    return host.mutate('Add ${MaterialNodes.spec(registryId)!.title}', () {
      final n = _create(registryId, position, literals);
      graph.nodes.add(n);
      return n;
    });
  }

  @override
  LuminaBlueprintNode? placeEntry(BlueprintPaletteEntry entry, Offset position, {BlueprintPinRef? from}) {
    if (!accepts(entry.registryId)) return null;
    return host.mutate('Add ${entry.title}', () {
      final n = _create(entry.registryId, position, entry.literals.isEmpty ? null : entry.literals);
      graph.nodes.add(n);
      if (from != null) {
        final texture = from.type == LuminaPinType.object;
        final pin = _compatiblePin(entry.registryId, texture: texture, wantInput: from.isOutput);
        if (pin != null) {
          if (from.isOutput) {
            if (whyNotConnect(from.nodeId, from.pinId, n.id, pin) == null) _wire(from.nodeId, from.pinId, n.id, pin);
          } else if (whyNotConnect(n.id, pin, from.nodeId, from.pinId) == null) {
            _wire(n.id, pin, from.nodeId, from.pinId);
          }
        }
      }
      return n;
    });
  }

  /// Every node but the Material output can be deleted.
  @override
  bool removeNodes(Set<String> ids) => super.removeNodes({...ids}..remove(MaterialNodes.outputNodeId));

  /// Sets node setting [key] (a constant's value, a parameter's name, a
  /// Custom node's code) as one undo step. Renaming a Custom input keeps its
  /// wire; removing one drops it.
  bool setProperty(String nodeId, String key, Object? value) {
    final n = node(nodeId);
    if (n == null) return false;
    if ('${n.literals[key]}' == '$value' && n.literals.containsKey(key)) return false;
    final label = switch (key) {
      'value' => 'Edit ${MaterialNodes.spec(n.registryId)?.title ?? 'value'}',
      'name' || 'parameter' => 'Rename parameter',
      'code' => 'Edit Custom code',
      _ => 'Edit $key',
    };
    return host.mutate(label, () {
      final target = node(nodeId)!;
      if (key == 'inputs' && target.registryId == MaterialNodes.custom && value is List) {
        final before = MaterialNodes.customInputs(target);
        final after = [for (final v in value) '$v'];
        // Same position, new name: carry the wire over.
        for (var k = 0; k < before.length && k < after.length; k++) {
          if (before[k] == after[k]) continue;
          for (final w in graph.wires.where((w) => w.toNodeId == nodeId && w.toPinId == before[k]).toList()) {
            graph.wires.remove(w);
            graph.wires.add(LuminaBlueprintWire(
                id: w.id, fromNodeId: w.fromNodeId, fromPinId: w.fromPinId, toNodeId: nodeId, toPinId: after[k]));
          }
        }
        graph.wires.removeWhere((w) => w.toNodeId == nodeId && !after.contains(w.toPinId));
        target.literals[key] = after;
      } else {
        target.literals[key] = value;
      }
      target.title = MaterialNodes.titleOf(target);
      return true;
    });
  }
}

import 'dart:ui' show Offset;

// Enum types only (the Material editor's shading / blending selects).
import 'package:flutter_filament/flutter_filament.dart' show BlendingMode, FilamatShading;
import 'package:lumina_editor_data/lumina_editor.dart' show AssetType, LuminaBlueprintNode, LuminaBlueprintWire;

import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/material_graph.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/mat_source.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/material_editor_view_model.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_editor_sessions.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_protocol.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_tool.dart';

/// The Material editor's node graph as MCP tools: the
/// expression catalog, the graph with typed pins, wires, the output pins the
/// shading model uses and the type checker's diagnostics; node / wire /
/// setting edits through the graph's own editor, each one `MCP: …` step on
/// the graph's stack that regenerates the `.mat` source as a mouse edit does;
/// parameter values, sampler texture bindings and the
/// header settings. The graph and the source tools always
/// agree: a source edit re-parses into the graph when it is next read.
void registerMaterialGraphTools(McpToolRegistry registry, EditorViewModel vm, McpEditorSessions sessions) {
  const graphGroup = {McpToolGroups.materialGraph};
  const assetArg = 'The material\'s project-relative .lmas path (list_assets with type "filamat"), or its file name when unique.';
  const nodeArg = 'A node id of the graph (get_material_graph); the output node is "material_output".';
  const shadings = {'lit': FilamatShading.lit, 'unlit': FilamatShading.unlit, 'cloth': FilamatShading.cloth, 'subsurface': FilamatShading.subsurface};
  const blendings = {
    'opaque': BlendingMode.opaque,
    'masked': BlendingMode.masked,
    'transparent': BlendingMode.transparent,
    'add': BlendingMode.add,
  };

  Future<MaterialEditorViewModel> editorFor(McpArgs args) async {
    final editor = await sessions.material(sessions.resolveAsset(args.string('asset'), type: AssetType.filamat));
    editor.graph.ensureSynced();
    return editor;
  }

  LuminaBlueprintNode nodeFor(MaterialEditorViewModel editor, String id) =>
      editor.graph.editor.node(id) ??
      (throw JsonRpcException(JsonRpcErrorCode.invalidParams,
          'No node "$id" in the graph. Nodes: ${editor.graph.graph.nodes.map((n) => '${n.id} (${n.registryId})').join(', ')} (get_material_graph).'));

  Map<String, Object?> sync(MaterialEditorViewModel editor) => {
        'ahead': editor.graph.isAhead,
        'fallback_reason': editor.graph.fallbackReason,
        'notes': editor.graph.notes,
      };

  List<Map<String, Object?>> diagnostics(MaterialEditorViewModel editor) => [
        for (final d in editor.graph.analysis.diagnostics)
          {'severity': d.isError ? 'error' : 'warning', 'message': d.message, 'node_id': d.nodeId, 'pin_id': d.pinId},
      ];

  /// What every graph edit returns: the regenerated source's state.
  Map<String, Object?> state(MaterialEditorViewModel editor, [Map<String, Object?> extra = const {}]) => {
        ...extra,
        'is_dirty': editor.isDirty,
        'sync': sync(editor),
        'diagnostics': diagnostics(editor),
        'undo_label': editor.graph.transactions.canUndo ? editor.graph.transactions.undoLabel : null,
      };

  Map<String, Object?> pin(MaterialEditorViewModel editor, LuminaBlueprintNode n, MaterialPinDef p, {required bool output}) {
    final graph = editor.graph.editor;
    return {
      'id': p.id,
      'name': p.name,
      'type': graph.typeOf(n.id, p.id, output: output)?.label ?? p.type?.label ?? 'any float',
      if (!output) 'optional': p.optional,
      if (!output && p.defaultValue != null) 'default': p.defaultValue,
      if (!output && p.unused) 'unused': true,
      'connected': graph.isConnected(n.id, p.id, output: output),
    };
  }

  Map<String, Object?> nodeJson(MaterialEditorViewModel editor, LuminaBlueprintNode n) {
    final surface = editor.graph.surface;
    final sampler = editor.graph.editor.samplerOf(n);
    return {
      'id': n.id,
      'node': n.registryId,
      'title': n.title,
      'category': n.category,
      'x': n.x,
      'y': n.y,
      'settings': n.literals,
      'sampler': ?sampler,
      if (sampler != null) 'texture': editor.graph.editor.textureFor(sampler)?.relativePath,
      'inputs': [for (final p in MaterialNodes.inputsOf(n, surface)) pin(editor, n, p, output: false)],
      'outputs': [for (final p in MaterialNodes.outputsOf(n)) pin(editor, n, p, output: true)],
    };
  }

  Map<String, Object?> wireJson(LuminaBlueprintWire w) => {
        'id': w.id,
        'from_node': w.fromNodeId,
        'from_pin': w.fromPinId,
        'to_node': w.toNodeId,
        'to_pin': w.toPinId,
      };

  /// The settings keys a node of [spec] takes.
  Set<String> settingKeys(MaterialNodeSpec spec) => {
        ...spec.defaults.keys,
        for (final p in spec.inputs)
          if (p.defaultValue != null) p.id,
      };

  String typeName(MaterialParamType t) => switch (t) {
        MaterialParamType.floatType => 'float',
        MaterialParamType.vec2Type => 'float2',
        MaterialParamType.vec3Type => 'float3',
        MaterialParamType.vec4Type => 'float4',
        MaterialParamType.colorType => 'float4 (color)',
        MaterialParamType.boolType => 'bool',
        MaterialParamType.sampler2dType => 'sampler2d',
      };

  registry.registerAll([
    McpTool(
      name: 'list_material_nodes',
      risk: McpToolRisk.readOnly,
      groups: graphGroup,
      title: 'List material nodes',
      description: 'The Material editor\'s expression catalog: id (pass it as `node` to '
          'add_material_node, e.g. mat_scalar_parameter, mat_texture_sample, mat_lerp), title, category, keywords, '
          'tooltip, typed pins (float, float2, float3, float4, Texture2D, bool; "any float" takes its type from the '
          'wire) and the default settings. The Material output node is not listed: every material has exactly one. '
          'Logic category: mat_compare (A, B floats; setting `op` one of > >= < <= == !=) yields a bool, mat_and / '
          'mat_or / mat_not combine bools, mat_if picks Then where its bool Condition holds, else Else (inputs condition / then / else, output Result; written as `c ? t : f`; '
          'an if / else chain that only assigns locals reads back as mat_if nodes). '
          'Vertex category: mat_set_vertex_variable computes its Value once per vertex (the .mat vertex block) '
          'and hands it to the fragment as a float4 interpolant named by its `name` setting (a `variables` '
          'entry); mat_vertex_variable reads it in the fragment (RGBA outputs). Only vertex-available '
          'expressions (constants, parameters, TexCoord, VertexColor, Time, mat_world_position, math, Custom) '
          'may feed a setter, and a material has at most 5 variables (4 when it reads the vertex colour).',
      inputSchema: McpSchema.object({
        'category': McpSchema.string('Only this category (Constants, Parameters, Texture, Math, Utility, Logic, Vertex, Custom, …).'),
        'query': McpSchema.string('Case-insensitive match on id, title or keywords.'),
      }),
      handler: (args) {
        final category = args.optionalString('category');
        final query = args.optionalString('query')?.toLowerCase();
        final entries = [
          for (final s in MaterialNodes.all)
            if (s.id != MaterialNodes.output && s.id != MaterialNodes.customFragment)
              if (category == null || s.category == category)
                if (query == null || '${s.id} ${s.title} ${s.keywords.join(' ')}'.toLowerCase().contains(query)) s,
        ];
        String label(MaterialPinDef p) => p.type?.label ?? 'any float';
        return McpToolResult.json({
          'nodes': [
            for (final s in entries)
              {
                'id': s.id,
                'title': s.title,
                'category': s.category,
                'keywords': s.keywords,
                'tooltip': s.tooltip,
                'inputs': [
                  for (final p in s.inputs) {'id': p.id, 'name': p.name, 'type': label(p), 'optional': p.optional, 'default': ?p.defaultValue},
                ],
                'outputs': [for (final p in s.outputs) {'id': p.id, 'name': p.name, 'type': label(p)}],
                'settings': s.defaults,
              },
          ],
          'categories': {for (final s in MaterialNodes.all) if (s.id != MaterialNodes.output) s.category}.toList(),
        });
      },
    ),
    McpTool(
      name: 'get_material_graph',
      risk: McpToolRisk.readOnly,
      groups: graphGroup,
      title: 'Get material graph',
      description: 'The material as the Material editor\'s node graph (opens its tab): nodes (id, node, title, x, y, '
          'settings, typed inputs / outputs with their connection state, the sampler and bound texture of texture '
          'nodes), wires, the output node\'s pins with `used` for the current shading model and blending, the type '
          'checker\'s diagnostics (with node_id), and sync: ahead is true when the graph has type errors, so the '
          '.mat source was not regenerated and compile_material refuses; fallback_reason when the fragment is one '
          'Custom (Fragment) node. `variables`: each vertex → fragment interpolant with the Set Vertex Variable '
          'nodes writing it (set_by) and the Vertex Variable nodes reading it (read_by); `vertex_block`: "graph" '
          'when the setters are the .mat vertex block, "hand_written" when the source has one the graph keeps as '
          'written (then vertex_block_reason when it cannot be read as nodes; a setter would then be an error), '
          '"none" otherwise.',
      inputSchema: McpSchema.object({'asset': McpSchema.string(assetArg)}, required: ['asset']),
      handler: (args) async {
        final editor = await editorFor(args);
        final graph = editor.graph.graph;
        final output = graph.node(MaterialNodes.outputNodeId);
        final surface = editor.graph.surface;
        final handWritten = output?.literals['vertexVerbatim'];
        final vertexBlock = graph.nodes.any((n) => n.registryId == MaterialNodes.setVertexVariable)
            ? 'graph'
            : MatSource.tryParse(editor.currentCode)?.block('vertex') != null
                ? 'hand_written'
                : 'none';
        return McpToolResult.json({
          'asset': editor.assetPath,
          'shading_model': editor.shading.name,
          'blending': editor.blending.name,
          'double_sided': editor.doubleSided,
          'nodes': [for (final n in graph.nodes) nodeJson(editor, n)],
          'wires': [for (final w in graph.wires) wireJson(w)],
          'output_pins': [
            if (output != null)
              for (final p in MaterialNodes.inputsOf(output, surface))
                {
                  'id': p.id,
                  'name': p.name.replaceAll(' (unused)', ''),
                  'type': p.type?.label,
                  'used': !p.unused,
                  'connected': editor.graph.editor.isConnected(output.id, p.id, output: false),
                },
          ],
          'variables': [
            for (final name in editor.graph.editor.declaredVariables)
              {
                'name': name,
                'set_by': [
                  for (final n in graph.nodes)
                    if (n.registryId == MaterialNodes.setVertexVariable && n.literals['name'] == name) n.id,
                ],
                'read_by': [
                  for (final n in graph.nodes)
                    if (n.registryId == MaterialNodes.vertexVariable && n.literals['name'] == name) n.id,
                ],
              },
          ],
          'vertex_block': vertexBlock,
          'vertex_block_reason': ?(handWritten is String ? handWritten : null),
          'diagnostics': diagnostics(editor),
          'sync': sync(editor),
          'is_dirty': editor.isDirty,
        });
      },
    ),
    McpTool(
      name: 'add_material_node',
      risk: McpToolRisk.mutating,
      groups: graphGroup,
      title: 'Add material node',
      description: 'Places an expression node at x, y (graph units) with optional `settings` (keys from '
          'list_material_nodes: a constant\'s value, a parameter\'s name and default, a Texture Sample\'s sampler '
          '`parameter`, a Set Vertex Variable\'s or Vertex Variable\'s variable `name`, a WorldPosition\'s `space` '
          'absolute | camera_relative, …). A new parameter or Set Vertex Variable without a name gets a unique one; '
          'a new Vertex Variable reads the first variable the material has. One graph undo step; the .mat source '
          'regenerates (a Set Vertex Variable adds the vertex block and the `variables` entry). mat_output and '
          'mat_custom_fragment are refused.',
      inputSchema: McpSchema.object({
        'asset': McpSchema.string(assetArg),
        'node': McpSchema.string('The expression id (list_material_nodes).'),
        'x': McpSchema.number('Graph x.'),
        'y': McpSchema.number('Graph y.'),
        'settings': {'type': 'object', 'description': 'Initial settings {key: value}.'},
      }, required: ['asset', 'node', 'x', 'y']),
      handler: (args) async {
        final id = args.string('node');
        if (id == MaterialNodes.output) {
          return McpToolResult.error('mat_output is the Material output node: every material has exactly one '
              '("material_output"); wire into its pins instead.');
        }
        if (id == MaterialNodes.customFragment) {
          return McpToolResult.error('mat_custom_fragment is the parser\'s stand-in for a fragment it cannot read as '
              'nodes; edit such code with set_material_source, or use a mat_custom node.');
        }
        final spec = MaterialNodes.spec(id);
        if (spec == null) return McpToolResult.error('Unknown material node "$id" (list_material_nodes).');
        final editor = await editorFor(args);
        final settings = args.optionalObject('settings') ?? const {};
        final keys = settingKeys(spec);
        final unknown = settings.keys.where((k) => !keys.contains(k)).toList();
        if (unknown.isNotEmpty) {
          return McpToolResult.error('${spec.title} has no setting ${unknown.join(', ')}. Settings: ${keys.isEmpty ? 'none' : keys.join(', ')}.');
        }
        final name = settings['name'];
        if (MaterialNodes.isParameter(id) && name is String && editor.graph.editor.uniqueParameterName(name) != name) {
          return McpToolResult.error('A node already declares the parameter "$name"; parameter names are unique.');
        }
        final node = editor.graph.editor.addNode(id, Offset(args.number('x'), args.number('y')), literals: settings.isEmpty ? null : Map.of(settings));
        if (node == null) return McpToolResult.error('The graph did not take a ${spec.title}.');
        return McpToolResult.json(state(editor, {'node': nodeJson(editor, editor.graph.editor.node(node.id) ?? node)}));
      },
    ),
    McpTool(
      name: 'connect_material_pins',
      risk: McpToolRisk.mutating,
      groups: graphGroup,
      title: 'Connect material pins',
      description: 'Wires output from_pin of from_node into input to_pin of to_node (an input keeps one wire: an '
          'existing one is replaced). Refused, with the reason, only for a loop or a texture / number mix-up (a '
          'Texture2D goes into a Texture Sample\'s Tex); any other type mismatch is accepted and reported in '
          'diagnostics with sync.ahead true, as the editor draws it red. Pin ids: get_material_graph (outputs '
          '`out`, `rgb`, `r`…; output node pins `base_color`, `roughness`, …). One graph undo step.',
      inputSchema: McpSchema.object({
        'asset': McpSchema.string(assetArg),
        'from_node': McpSchema.string(nodeArg),
        'from_pin': McpSchema.string('The output pin id.'),
        'to_node': McpSchema.string(nodeArg),
        'to_pin': McpSchema.string('The input pin id.'),
      }, required: ['asset', 'from_node', 'from_pin', 'to_node', 'to_pin']),
      handler: (args) async {
        final editor = await editorFor(args);
        final from = nodeFor(editor, args.string('from_node'));
        final to = nodeFor(editor, args.string('to_node'));
        final fromPin = args.string('from_pin');
        final toPin = args.string('to_pin');
        final outs = MaterialNodes.outputsOf(from).map((p) => p.id).toList();
        final ins = MaterialNodes.inputsOf(to, editor.graph.surface).map((p) => p.id).toList();
        if (!outs.contains(fromPin)) return McpToolResult.error('${from.title} has no output "$fromPin". Outputs: ${outs.join(', ')}.');
        if (!ins.contains(toPin)) return McpToolResult.error('${to.title} has no input "$toPin". Inputs: ${ins.join(', ')}.');
        final why = editor.graph.editor.whyNotConnect(from.id, fromPin, to.id, toPin);
        if (why != null) return McpToolResult.error(why);
        final wire = editor.graph.editor.addWire(fromNodeId: from.id, fromPinId: fromPin, toNodeId: to.id, toPinId: toPin);
        if (wire == null) return McpToolResult.error('The wire was not added.');
        final added = editor.graph.graph.wireInto(to.id, toPin);
        return McpToolResult.json(state(editor, {'wire': wireJson(added ?? wire)}));
      },
    ),
    McpTool(
      name: 'remove_material_node',
      risk: McpToolRisk.mutating,
      groups: graphGroup,
      removesContent: true,
      title: 'Remove material node',
      description: 'Deletes a node and its wires. The Material output node is never removed. One graph undo step.',
      inputSchema: McpSchema.object({'asset': McpSchema.string(assetArg), 'node': McpSchema.string(nodeArg)}, required: ['asset', 'node']),
      handler: (args) async {
        final editor = await editorFor(args);
        final id = args.string('node');
        if (id == MaterialNodes.outputNodeId) return McpToolResult.error('The Material output node is never removed.');
        final node = nodeFor(editor, id);
        if (!editor.graph.editor.removeNodes({node.id})) return McpToolResult.error('${node.title} was not removed.');
        return McpToolResult.json(state(editor, {'removed': node.id}));
      },
    ),
    McpTool(
      name: 'remove_material_wire',
      risk: McpToolRisk.mutating,
      groups: graphGroup,
      removesContent: true,
      title: 'Remove material wire',
      description: 'Deletes one wire by id (get_material_graph, or connect_material_pins\' result). One graph undo step.',
      inputSchema: McpSchema.object({'asset': McpSchema.string(assetArg), 'wire': McpSchema.string('The wire id.')},
          required: ['asset', 'wire']),
      handler: (args) async {
        final editor = await editorFor(args);
        final id = args.string('wire');
        if (!editor.graph.graph.wires.any((w) => w.id == id)) {
          return McpToolResult.error('No wire "$id". Wires: ${editor.graph.graph.wires.map((w) => w.id).join(', ')}.');
        }
        editor.graph.editor.removeWire(id);
        return McpToolResult.json(state(editor, {'removed': id}));
      },
    ),
    McpTool(
      name: 'set_material_node_setting',
      risk: McpToolRisk.mutating,
      groups: graphGroup,
      idempotent: true,
      title: 'Set material node setting',
      description: 'Sets one node setting, as the node\'s Details do: a constant\'s `value` (number or [2–4 '
          'numbers]), a parameter\'s `name` / `default`, a Texture Sample\'s sampler `parameter`, a mask\'s r/g/b/a, a '
          'Custom node\'s code / inputs / outputType, a variable `name` (renaming the only Set Vertex Variable of a '
          'variable renames its Vertex Variable readers too), a WorldPosition\'s `space`, a Compare\'s `op` (> >= < <= == !=), or an unconnected '
          'input\'s '
          'constant (Multiply\'s B, Lerp\'s Alpha). Keys: list_material_nodes settings. One graph undo step.',
      inputSchema: McpSchema.object({
        'asset': McpSchema.string(assetArg),
        'node': McpSchema.string(nodeArg),
        'key': McpSchema.string('The setting key.'),
        'value': McpSchema.any('The new value.'),
      }, required: ['asset', 'node', 'key', 'value']),
      handler: (args) async {
        final editor = await editorFor(args);
        final node = nodeFor(editor, args.string('node'));
        final spec = MaterialNodes.spec(node.registryId)!;
        final key = args.string('key');
        final keys = settingKeys(spec);
        if (!keys.contains(key)) {
          return McpToolResult.error('${spec.title} has no setting "$key". Settings: ${keys.isEmpty ? 'none' : keys.join(', ')}.');
        }
        final value = args['value'];
        if (key == 'name' && MaterialNodes.isParameter(node.registryId) && value is String && value != node.literals['name'] &&
            editor.graph.editor.uniqueParameterName(value) != value) {
          return McpToolResult.error('A node already declares the parameter "$value"; parameter names are unique.');
        }
        final changed = editor.graph.editor.setProperty(node.id, key, value);
        return McpToolResult.json(state(editor, {'changed': changed, 'node': nodeJson(editor, editor.graph.editor.node(node.id)!)}));
      },
    ),
    McpTool(
      name: 'arrange_material_graph',
      risk: McpToolRisk.mutating,
      groups: graphGroup,
      idempotent: true,
      title: 'Arrange material graph',
      description: 'The graph toolbar\'s Arrange: lays the nodes out again, right to left from the output. One '
          'graph undo step (none when nothing moved).',
      inputSchema: McpSchema.object({'asset': McpSchema.string(assetArg)}, required: ['asset']),
      handler: (args) async {
        final editor = await editorFor(args);
        editor.graph.arrange();
        return McpToolResult.json(state(editor, {
          'positions': {for (final n in editor.graph.graph.nodes) n.id: [n.x, n.y]},
        }));
      },
    ),
    McpTool(
      name: 'set_material_parameter',
      risk: McpToolRisk.mutating,
      groups: graphGroup,
      idempotent: true,
      title: 'Set material parameter',
      description: 'Sets a declared parameter\'s value, as the Parameters panel does (the preview follows): a number '
          'for float, [2 / 3 / 4 numbers] for float2 / float3 / float4 and colours, a boolean for bool. Samplers take '
          'a texture: set_material_texture. Not a graph undo step (the panel\'s edits are not either): it marks the '
          'material dirty, and the tab\'s Discard reverts it; compile_material with save: true stores it.',
      inputSchema: McpSchema.object({
        'asset': McpSchema.string(assetArg),
        'name': McpSchema.string('The parameter name (get_material_source parameters).'),
        'value': McpSchema.any('The value.'),
      }, required: ['asset', 'name', 'value']),
      handler: (args) async {
        final editor = await editorFor(args);
        final name = args.string('name');
        final param = editor.parameters.where((p) => p.name == name).firstOrNull;
        if (param == null) {
          return McpToolResult.error('No parameter "$name". Parameters: ${editor.parameters.map((p) => p.name).join(', ')}.');
        }
        if (param.isSampler) {
          return McpToolResult.error('$name is a sampler2d: bind a texture with set_material_texture.');
        }
        final raw = args['value'];
        final width = switch (param.type) {
          MaterialParamType.vec2Type => 2,
          MaterialParamType.vec3Type => 3,
          MaterialParamType.vec4Type || MaterialParamType.colorType => 4,
          _ => 1,
        };
        final Object value;
        if (param.type == MaterialParamType.boolType) {
          if (raw is! bool) return McpToolResult.error('$name is a bool: pass true or false.');
          value = raw;
        } else if (width == 1) {
          if (raw is! num) return McpToolResult.error('$name is a float: pass a number, not $raw.');
          value = raw.toDouble();
        } else {
          if (raw is! List || raw.length != width || raw.any((e) => e is! num)) {
            return McpToolResult.error('$name is a ${typeName(param.type)}: pass $width numbers, not $raw.');
          }
          value = [for (final e in raw) (e as num).toDouble()];
        }
        editor.setParam(name, value);
        return McpToolResult.json({'name': name, 'type': typeName(param.type), 'value': editor.getParamValue(name), 'is_dirty': editor.isDirty});
      },
    ),
    McpTool(
      name: 'set_material_texture',
      risk: McpToolRisk.mutating,
      groups: graphGroup,
      idempotent: true,
      title: 'Set material texture',
      description: 'Binds a sampler parameter (a Texture Sample\'s or TextureParameter\'s sampler) to a texture asset '
          '(list_assets type "texture"), as the node\'s thumbnail picker does; no `texture` clears it. One graph '
          'undo step.',
      inputSchema: McpSchema.object({
        'asset': McpSchema.string(assetArg),
        'parameter': McpSchema.string('The sampler parameter name.'),
        'texture': McpSchema.string('The texture asset; omit to clear.'),
      }, required: ['asset', 'parameter']),
      handler: (args) async {
        final editor = await editorFor(args);
        final name = args.string('parameter');
        final param = editor.parameters.where((p) => p.name == name && p.isSampler).firstOrNull;
        if (param == null) {
          final samplers = editor.parameters.where((p) => p.isSampler).map((p) => p.name);
          return McpToolResult.error('No sampler parameter "$name". Samplers: ${samplers.isEmpty ? 'none' : samplers.join(', ')}.');
        }
        final wanted = args.optionalString('texture');
        final texture = wanted == null ? null : sessions.resolveAsset(wanted, type: AssetType.texture);
        final changed = editor.graph.bindTexture(name, texture);
        final bound = editor.parameters.firstWhere((p) => p.name == name).textureRef?.assetPath;
        return McpToolResult.json(state(editor, {'parameter': name, 'texture': bound, 'changed': changed}));
      },
    ),
    McpTool(
      name: 'set_material_settings',
      risk: McpToolRisk.mutating,
      groups: graphGroup,
      idempotent: true,
      title: 'Set material settings',
      description: 'The Material editor\'s header settings: shading_model (${shadings.keys.join(', ')}), blending '
          '(${blendings.keys.join(', ')}) and double_sided. Rewrites the .mat header and recompiles, as the '
          'toolbar does; output pins the new shading model ignores are then marked unused in get_material_graph.',
      inputSchema: McpSchema.object({
        'asset': McpSchema.string(assetArg),
        'shading_model': McpSchema.string('The shading model.', enumValues: shadings.keys.toList()),
        'blending': McpSchema.string('The blend mode.', enumValues: blendings.keys.toList()),
        'double_sided': McpSchema.boolean('Render both faces.'),
      }, required: ['asset']),
      handler: (args) async {
        if (!args.has('shading_model') && !args.has('blending') && !args.has('double_sided')) {
          return McpToolResult.error('Pass shading_model, blending and / or double_sided.');
        }
        final editor = await editorFor(args);
        await editor.updateHeaderSettings(
          shading: shadings[args.optionalString('shading_model')],
          blending: blendings[args.optionalString('blending')],
          doubleSided: args.has('double_sided') ? args.boolean('double_sided') : null,
        );
        return McpToolResult.json(state(editor, {
          'shading_model': editor.shading.name,
          'blending': editor.blending.name,
          'double_sided': editor.doubleSided,
          'compile_status': editor.syntaxStatus,
          'issues': [for (final i in editor.issues) {'line': i.line, 'severity': i.severity.name, 'message': i.message}],
        }));
      },
    ),
  ]);
}

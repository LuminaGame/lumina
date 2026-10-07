import 'dart:io';

import 'package:lumina_editor_data/lumina_editor.dart';

import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_compile_status.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_graph_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/level_blueprint_editor_view_model.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_editor_sessions.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_protocol.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_tool.dart';
import 'package:lumina_ui/ui/features/mcp_server/tools/blueprint_tool_support.dart';
import 'package:lumina_ui/ui/features/mcp_server/tools/graph_json.dart';
import 'package:lumina_ui/ui/features/mcp_server/tools/rotation_convention.dart';

/// The Blueprint editor as MCP tools: the node library,
/// a Blueprint's components, members and graphs (the event graph, function
/// and macro graphs, the Level Blueprint), node / wire / literal edits
/// through the graph's editor (each one undo step on the Blueprint tab),
/// compile with lumina's validator and code generator, diagnostics.
void registerBlueprintTools(McpToolRegistry registry, EditorViewModel vm, McpEditorSessions sessions) {
  Future<BlueprintEditorViewModel> editorFor(McpArgs args) => sessions.blueprintEditor(args.string('asset'));

  /// The editor and the graph [args] name, the graph's tab in front.
  Future<(BlueprintEditorViewModel, BlueprintGraphEditor, String)> graphFor(McpArgs args) async {
    final editor = await editorFor(args);
    final (ref, graph) = mcpResolveGraph(editor, args.optionalString('graph'));
    editor.showGraph(ref);
    return (editor, graph, mcpGraphName(ref));
  }

  List<Map<String, Object?>> diagnosticsOf(BlueprintEditorViewModel editor) => [
        for (final d in editor.diagnostics)
          {
            'severity': d.severity.name,
            'message': d.message,
            'node_id': d.nodeId,
            'node_title': editor.diagnosticNodeTitle(d),
            'pin_id': d.pinId,
          },
      ];

  List<Map<String, Object?>> timelinesOf(BlueprintEditorViewModel editor) => [
        for (final g in editor.allGraphs)
          for (final n in g.nodes)
            if (n.registryId == LuminaBlueprintNodeLibrary.timeline)
              {
                'node': n.id,
                'length': editor.timelineLength(n.id),
                'loop': editor.timelineLoop(n.id),
                'auto_play': editor.timelineAutoPlay(n.id),
                'tracks': [
                  for (final t in editor.timelineTracks(n.id))
                    {
                      'name': t.name,
                      'type': t.type,
                      'keys': [for (final k in t.keys) {'time': k.time, 'value': k.value, 'interp': k.interp.name}],
                    },
                ],
              },
      ];

  const nodeIdArg = 'A node id from get_blueprint (e.g. "node_…"), not the library id.';
  final graphArg = McpSchema.string(kBlueprintGraphArg);
  final assetArg = McpSchema.string(kBlueprintAssetArg);
  const bp = {McpToolGroups.blueprint};

  registry.registerAll([
    McpTool(
      name: 'list_blueprint_nodes',
      risk: McpToolRisk.readOnly,
      groups: bp,
      title: 'List Blueprint nodes',
      description: 'The Blueprint node library (the editor\'s palette): every node\'s library id (what add_blueprint_node '
          'takes, e.g. "print_string", "branch", "event_beginplay"), title, category, kind (event / impure / pure / flow / '
          'latent) and its input and output pins with ids and types. Pin types: exec, boolean, integer, float, string, '
          'name, vector, vector2D, rotator, object. Filter by category or a title/keyword substring.',
      inputSchema: McpSchema.object({
        'category': McpSchema.string('Only nodes of this category, e.g. "Events", "Flow Control", "Math", "Development".'),
        'query': McpSchema.string('Only nodes whose id, title or keywords contain this text (case-insensitive).'),
      }),
      handler: (args) {
        final category = args.optionalString('category')?.toLowerCase();
        final query = args.optionalString('query')?.toLowerCase();
        final specs = LuminaBlueprintNodeLibrary.all.where((s) {
          if (s.deprecation != null) return false;
          if (category != null && s.category.toLowerCase() != category) return false;
          if (query != null &&
              !s.id.toLowerCase().contains(query) &&
              !s.title.toLowerCase().contains(query) &&
              !s.keywords.any((k) => k.toLowerCase().contains(query))) {
            return false;
          }
          return true;
        }).toList();
        return McpToolResult.json({
          'count': specs.length,
          'categories': LuminaBlueprintNodeLibrary.all.map((s) => s.category).toSet().toList(),
          'nodes': [
            for (final s in specs)
              {
                'id': s.id,
                'title': s.title,
                'category': s.category,
                'kind': s.kind.name,
                'inputs': s.inputs.map(mcpPinSpec).toList(),
                'outputs': s.outputs.map(mcpPinSpec).toList(),
                'unsupported': s.unsupported,
                'tooltip': s.tooltip,
              },
          ],
        });
      },
    ),
    McpTool(
      name: 'get_blueprint',
      risk: McpToolRisk.readOnly,
      groups: bp,
      title: 'Get Blueprint',
      description: 'A Blueprint as its editor shows it: parent class, class defaults, components (id, type, name, '
          'parent, properties), variables, functions (signature, pure, category, local variables), macros, event '
          'dispatchers, implemented interfaces, timelines (node, length, loop, auto play, tracks with keys), the graphs, '
          'and one graph\'s nodes (id, library id, position, pins with literals and connection state) and wires — the '
          'event graph unless `graph` names a function or macro. asset "level" is the Level Blueprint. Opens its tab.',
      inputSchema: McpSchema.object({'asset': assetArg, 'graph': graphArg}, required: ['asset']),
      handler: (args) async {
        final (editor, graph, graphName) = await graphFor(args);
        final doc = editor.document;
        return McpToolResult.json({
          'asset': editor.assetPath,
          'class_name': editor.fileBasename,
          'is_level_blueprint': McpEditorSessions.isLevelBlueprint(editor),
          'parent_class': doc.parentClass,
          'class_defaults': doc.classDefaults,
          'components': [
            for (final c in doc.components)
              {'id': c.id, 'type': c.type, 'name': c.name, 'parent_id': c.parentId, 'properties': c.properties, 'is_scene_component': c.isSceneComponent},
          ],
          'variables': [for (final v in doc.variables) mcpVariableJson(v)],
          'functions': [
            for (final f in doc.functions)
              {
                'name': f.name,
                'inputs': [for (final v in f.inputs) mcpVariableJson(v)],
                'outputs': [for (final v in f.outputs) mcpVariableJson(v)],
                'pure': f.pure,
                'category': f.category,
                'local_variables': [for (final v in f.localVariables) mcpVariableJson(v)],
              },
          ],
          'macros': [
            for (final m in doc.macros)
              {
                'name': m.name,
                'inputs': [for (final v in m.inputs) mcpVariableJson(v)],
                'outputs': [for (final v in m.outputs) mcpVariableJson(v)],
              },
          ],
          'dispatchers': [
            for (final d in doc.dispatchers) {'name': d.name, 'parameters': [for (final v in d.parameters) mcpVariableJson(v)]},
          ],
          'interfaces': List<String>.from(doc.interfaces),
          'timelines': timelinesOf(editor),
          'graphs': ['event', for (final f in doc.functions) 'function:${f.name}', for (final m in doc.macros) 'macro:${m.name}'],
          'graph': graphName,
          'nodes': [for (final n in graph.nodes) mcpNodeJson(graph, n)],
          'wires': graph.wires.map(mcpWireJson).toList(),
          'compile_status': editor.compileStatus.name,
          'diagnostics': diagnosticsOf(editor),
          'is_dirty': editor.isDirty,
          'undo': mcpBlueprintUndo(editor),
        });
      },
    ),
    McpTool(
      name: 'add_blueprint_node',
      risk: McpToolRisk.mutating,
      groups: bp,
      idempotent: false,
      title: 'Add Blueprint node',
      description: 'Places a library node (list_blueprint_nodes id) on a graph (the event graph unless `graph` names a '
          'function or macro) at canvas position (x, y), as one undo step on the Blueprint tab. Returns the new node '
          'with its pin ids. Optional literals set unconnected input pins ({pin id: value}) and node settings (an input '
          'action node\'s "action", a variable node\'s "variable", a custom event\'s "name", a widget graph\'s Get Widget '
          '(get_widget_variable) and a Get Element\'s "element" — the element\'s designer name, e.g. "ScoreText" — and the '
          '"class" of Create Widget ("WBP_HUD") and Cast To ("Widget:WBP_HUD", "Actor:BP_Door", '
          '"Component:LuminaCameraComponent", "WidgetElement:text" for a Text Block)).',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'graph': graphArg,
        'node': McpSchema.string('The library id, e.g. "print_string".'),
        'x': McpSchema.number('Canvas x position. Default 400.'),
        'y': McpSchema.number('Canvas y position. Default 200.'),
        'literals': {'type': 'object', 'description': 'Initial pin literals and node settings, by pin id.'},
      }, required: ['asset', 'node']),
      handler: (args) async {
        final refusal = mcpRefuseWhilePlaying(vm);
        if (refusal != null) return refusal;
        final (editor, graph, graphName) = await graphFor(args);
        return mcpGraphAddNode(graph, graphName, args,
            rejected: 'a function graph takes no events or latent nodes; a macro takes no events, entries or local variables.',
            extra: () => {'undo': mcpBlueprintUndo(editor)});
      },
    ),
    McpTool(
      name: 'connect_blueprint_pins',
      risk: McpToolRisk.mutating,
      groups: bp,
      idempotent: false,
      title: 'Connect Blueprint pins',
      description: 'Wires an output pin to an input pin of another node of the same graph (one undo step). Exec pins '
          'connect only to exec pins and data pins only to the same type; an exec output or a data input keeps one '
          'wire, so wiring replaces what was there. Pin ids come from get_blueprint (e.g. "exec_out" → "exec_in").',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'graph': graphArg,
        'from_node': McpSchema.string('The source node id (get_blueprint).'),
        'from_pin': McpSchema.string('The source node\'s output pin id.'),
        'to_node': McpSchema.string('The target node id.'),
        'to_pin': McpSchema.string('The target node\'s input pin id.'),
      }, required: ['asset', 'from_node', 'from_pin', 'to_node', 'to_pin']),
      handler: (args) async {
        final refusal = mcpRefuseWhilePlaying(vm);
        if (refusal != null) return refusal;
        final (editor, graph, graphName) = await graphFor(args);
        return mcpGraphConnect(graph, graphName, args, extra: () => {'undo': mcpBlueprintUndo(editor)});
      },
    ),
    McpTool(
      name: 'set_blueprint_pin_literal',
      risk: McpToolRisk.mutating,
      groups: bp,
      idempotent: true,
      title: 'Set Blueprint pin literal',
      description: 'Sets the literal value of an unconnected input pin (one undo step): a string, number, boolean, '
          '[x, y, z] for a vector pin, or a rotator pin\'s $kMcpRotationConvention.',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'graph': graphArg,
        'node': McpSchema.string(nodeIdArg),
        'pin': McpSchema.string('The input pin id, e.g. "in_string".'),
        'value': McpSchema.any('The literal, of the pin\'s type.'),
      }, required: ['asset', 'node', 'pin', 'value']),
      handler: (args) async {
        final refusal = mcpRefuseWhilePlaying(vm);
        if (refusal != null) return refusal;
        final (editor, graph, graphName) = await graphFor(args);
        return mcpGraphSetLiteral(graph, graphName, args, extra: () => {'undo': mcpBlueprintUndo(editor)});
      },
    ),
    McpTool(
      name: 'remove_blueprint_node',
      risk: McpToolRisk.mutating,
      groups: bp,
      idempotent: false,
      removesContent: true,
      title: 'Remove Blueprint node',
      description: 'Deletes a node and its wires from a graph (one undo step).',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'graph': graphArg,
        'node': McpSchema.string(nodeIdArg),
      }, required: ['asset', 'node']),
      handler: (args) async {
        final refusal = mcpRefuseWhilePlaying(vm);
        if (refusal != null) return refusal;
        final (editor, graph, graphName) = await graphFor(args);
        return mcpGraphRemoveNode(graph, graphName, args, extra: () => {'undo': mcpBlueprintUndo(editor)});
      },
    ),
    McpTool(
      name: 'remove_blueprint_wire',
      risk: McpToolRisk.mutating,
      groups: bp,
      idempotent: false,
      removesContent: true,
      title: 'Remove Blueprint wire',
      description: 'Deletes a wire (one undo step). Wire ids come from get_blueprint.',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'graph': graphArg,
        'wire': McpSchema.string('The wire id.'),
      }, required: ['asset', 'wire']),
      handler: (args) async {
        final refusal = mcpRefuseWhilePlaying(vm);
        if (refusal != null) return refusal;
        final (editor, graph, graphName) = await graphFor(args);
        return mcpGraphRemoveWire(graph, graphName, args, extra: () => {'undo': mcpBlueprintUndo(editor)});
      },
    ),
    McpTool(
      name: 'compile_blueprint',
      risk: McpToolRisk.mutating,
      groups: bp,
      idempotent: true,
      title: 'Compile Blueprint',
      description: 'Compiles the Blueprint (the editor\'s Compile button): lumina\'s validator and Dart code generator '
          'run on the document as it is; a clean result is written to lib/actors/<blueprint>.dart, snake_case (BP_Door → bp_door.dart; a Level Blueprint: '
          'lib/levels/<level>.dart when the level is saved; the script is returned as generated_code). Returns the status (upToDate / warning / error), diagnostics '
          '[{severity, message, node_id, node_title}] and the generated file. With save: true the .lmas (a Level '
          'Blueprint: the level file) is written afterwards.',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'save': McpSchema.boolean('Write the .lmas after compiling. Default false.'),
      }, required: ['asset']),
      handler: (args) async {
        final refusal = mcpRefuseWhilePlaying(vm);
        if (refusal != null) return refusal;
        final editor = await editorFor(args);
        final ok = await editor.compile();
        var saved = false;
        if (args.boolean('save')) saved = await editor.save();
        final projectDir = editor.projectDir;
        final generated = editor is LevelBlueprintEditorViewModel
            ? 'lib/${editor.generatedFileName}'
            : 'lib/actors/${dartFileName(editor.fileBasename)}';
        final data = <String, Object?>{
          'ok': ok,
          'status': editor.compileStatus.name,
          'status_label': editor.compileStatus.label,
          'diagnostics': diagnosticsOf(editor),
          'generated_file': projectDir == null ? null : '$projectDir/$generated',
          'generated_file_exists': projectDir != null && File('$projectDir/$generated').existsSync(),
          // A Level Blueprint's script reaches lib/levels/ on Save Level; the
          // agent sees what it will be now.
          if (editor is LevelBlueprintEditorViewModel) 'generated_code': editor.generatedDartCode,
          'saved': saved,
          'is_dirty': editor.isDirty,
        };
        return McpToolResult(McpToolResult.json(data).content,
            structuredContent: data, isError: editor.compileStatus == BlueprintCompileStatus.error);
      },
    ),
    McpTool(
      name: 'get_blueprint_diagnostics',
      risk: McpToolRisk.readOnly,
      groups: bp,
      title: 'Get Blueprint diagnostics',
      description: 'The Blueprint editor\'s compile status and the last compile\'s diagnostics.',
      inputSchema: McpSchema.object({'asset': assetArg}, required: ['asset']),
      handler: (args) async {
        final editor = await editorFor(args);
        return McpToolResult.json({
          'status': editor.compileStatus.name,
          'status_label': editor.compileStatus.label,
          'diagnostics': diagnosticsOf(editor),
        });
      },
    ),
  ]);
}

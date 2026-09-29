import 'package:lumina/lumina.dart';

import '../../main_editor/view_models/editor_view_model.dart';
import '../../sub_editors/models/blueprint_graph_ref.dart';
import '../../sub_editors/view_models/blueprint_editor_view_model.dart';
import '../services/mcp_editor_sessions.dart';
import '../services/mcp_protocol.dart';
import '../services/mcp_tool.dart';
import 'blueprint_tool_support.dart';

/// My Blueprint as MCP tools: variables, functions and their
/// signatures and local variables, macros, event dispatchers, implemented
/// interfaces, custom event parameters, timelines, and collapse / expand.
/// Each edit is one undo step on the Blueprint tab (the Level Blueprint's
/// too) and selects or shows what it touched. Names are made unique: every
/// add returns the name it used. There is no "expose" / Instance Editable
/// flag on variables (lumina's variables have name, type and default only).
void registerBlueprintMemberTools(McpToolRegistry registry, EditorViewModel vm, McpEditorSessions sessions) {
  const bp = {McpToolGroups.blueprint};
  final assetArg = McpSchema.string(kBlueprintAssetArg);
  final paramsSchema = {
    'type': 'array',
    'description': '[{name, type, default?}] — types as for variables (Float, Bool, Integer, String, Vector, Actor, Actor:<BP>, …).',
    'items': {'type': 'object'},
  };

  Never refuse(String message) => throw JsonRpcException(JsonRpcErrorCode.invalidParams, message);

  /// Every wire id in the document, to report what a signature edit dropped.
  Set<String> wireIds(BlueprintEditorViewModel editor) => {
        for (final g in editor.allGraphs)
          for (final w in g.wires) w.id,
      };

  LuminaBlueprintFunctionGraph functionOf(BlueprintEditorViewModel editor, String name) =>
      editor.document.function(name) ??
      refuse('No function "$name". Functions: ${editor.document.functions.map((f) => f.name).join(', ')}.');

  LuminaBlueprintMacroGraph macroOf(BlueprintEditorViewModel editor, String name) =>
      editor.document.macro(name) ?? refuse('No macro "$name". Macros: ${editor.document.macros.map((m) => m.name).join(', ')}.');

  LuminaBlueprintDispatcher dispatcherOf(BlueprintEditorViewModel editor, String name) =>
      editor.document.dispatchers.where((d) => d.name == name).firstOrNull ??
      refuse('No event dispatcher "$name". Dispatchers: ${editor.document.dispatchers.map((d) => d.name).join(', ')}.');

  LuminaBlueprintVariable variableOf(BlueprintEditorViewModel editor, String name) =>
      editor.document.variables.where((v) => v.name == name).firstOrNull ??
      refuse('No variable "$name". Variables: ${editor.document.variables.map((v) => v.name).join(', ')}.');

  LuminaBlueprintNode timelineOf(BlueprintEditorViewModel editor, String nodeId) =>
      editor.timelineNode(nodeId) ?? refuse('No timeline node "$nodeId"; place one with add_blueprint_node {node: "timeline"}.');

  List<Map<String, Object?>> tracksOf(BlueprintEditorViewModel editor, String nodeId) => [
        for (final t in editor.timelineTracks(nodeId))
          {
            'name': t.name,
            'type': t.type,
            'keys': [for (final k in t.keys) {'time': k.time, 'value': k.value, 'interp': k.interp.name}],
          },
      ];

  Map<String, Object?> functionJson(LuminaBlueprintFunctionGraph f) => {
        'name': f.name,
        'inputs': [for (final v in f.inputs) mcpVariableJson(v)],
        'outputs': [for (final v in f.outputs) mcpVariableJson(v)],
        'pure': f.pure,
        'category': f.category,
        'local_variables': [for (final v in f.localVariables) mcpVariableJson(v)],
      };

  /// A tool over a Blueprint editor, refused while Play runs.
  McpTool tool({
    required String name,
    required String title,
    required String description,
    required Map<String, Object?> properties,
    required List<String> required,
    required Map<String, Object?> Function(McpArgs args, BlueprintEditorViewModel editor) run,
    McpToolRisk risk = McpToolRisk.mutating,
    bool idempotent = false,
    bool removesContent = false,
  }) =>
      McpTool(
        name: name,
        title: title,
        description: description,
        inputSchema: McpSchema.object({'asset': assetArg, ...properties}, required: ['asset', ...required]),
        risk: risk,
        groups: bp,
        idempotent: idempotent,
        removesContent: removesContent,
        handler: (args) async {
          final refusal = mcpRefuseWhilePlaying(vm);
          if (refusal != null) return refusal;
          final editor = await sessions.blueprintEditor(args.string('asset'));
          final data = run(args, editor);
          return McpToolResult.json({...data, 'undo': mcpBlueprintUndo(editor)});
        },
      );

  final name = McpSchema.string('The name.');
  final newName = McpSchema.string('The new name.');
  final typeArg = McpSchema.string('The type: Float, Bool, Integer, String, Name, Vector, Rotator, Color, Transform, '
      'Object, Actor, Actor:<BP>, Widget:<WBP>, Component:<type>, Enum:<name>, Array:<type>.');
  final functionArg = McpSchema.string('The function name.');

  registry.registerAll([
    // --- Variables -----------------------------------------------------------
    tool(
      name: 'add_blueprint_variable',
      title: 'Add Blueprint variable',
      description: 'My Blueprint → + Variable. The name is made unique (OpenAngle, OpenAngle2, …): use the returned name. '
          'There is no Instance Editable / expose flag.',
      properties: {'name': name, 'type': typeArg, 'default': McpSchema.any('The default value (the type\'s own default when omitted).')},
      required: ['name', 'type'],
      run: (args, editor) {
        final type = mcpCheckType(args.string('type'));
        final used = editor.addVariable(args.string('name').trim(), type, args['default']);
        editor.selectVariable(used);
        return {'variable': mcpVariableJson(variableOf(editor, used))};
      },
    ),
    tool(
      name: 'rename_blueprint_variable',
      title: 'Rename Blueprint variable',
      idempotent: true,
      description: 'Renames a variable; its Get / Set nodes follow.',
      properties: {'variable': McpSchema.string('The current name.'), 'name': newName},
      required: ['variable', 'name'],
      run: (args, editor) {
        final v = variableOf(editor, args.string('variable'));
        final to = args.string('name').trim();
        if (!editor.renameVariable(v.name, to)) refuse('"$to" is taken or not a valid name.');
        editor.selectVariable(to);
        return {'variable': mcpVariableJson(variableOf(editor, to))};
      },
    ),
    tool(
      name: 'set_blueprint_variable_type',
      title: 'Set Blueprint variable type',
      idempotent: true,
      description: 'Changes a variable\'s type (its default resets to the type\'s; wires the new type cannot carry drop).',
      properties: {'variable': McpSchema.string('The variable.'), 'type': typeArg},
      required: ['variable', 'type'],
      run: (args, editor) {
        final v = variableOf(editor, args.string('variable'));
        final before = wireIds(editor);
        editor.setVariableType(v.name, mcpCheckType(args.string('type')));
        return {'variable': mcpVariableJson(variableOf(editor, v.name)), 'removed_wires': before.difference(wireIds(editor)).toList()};
      },
    ),
    tool(
      name: 'set_blueprint_variable_default',
      title: 'Set Blueprint variable default',
      idempotent: true,
      description: 'Sets a variable\'s default value.',
      properties: {'variable': McpSchema.string('The variable.'), 'value': McpSchema.any('The default value, of its type.')},
      required: ['variable', 'value'],
      run: (args, editor) {
        final v = variableOf(editor, args.string('variable'));
        editor.setVariableDefault(v.name, args['value']);
        return {'variable': mcpVariableJson(variableOf(editor, v.name))};
      },
    ),
    tool(
      name: 'delete_blueprint_variable',
      title: 'Delete Blueprint variable',
      risk: McpToolRisk.destructive,
      removesContent: true,
      description: 'Deletes a variable and every Get / Set node of it (listed in removed_nodes).',
      properties: {'variable': McpSchema.string('The variable.')},
      required: ['variable'],
      run: (args, editor) {
        final v = variableOf(editor, args.string('variable'));
        final nodes = [for (final n in editor.nodesUsingVariable(v.name)) n.id];
        editor.deleteVariable(v.name);
        return {'deleted': v.name, 'removed_nodes': nodes};
      },
    ),
    // --- Functions -----------------------------------------------------------
    tool(
      name: 'add_blueprint_function',
      title: 'Add Blueprint function',
      description: 'My Blueprint → + Function: a function graph with its entry node. The name is made unique: use the '
          'returned name; its graph is "function:<name>".',
      properties: {'name': name},
      required: ['name'],
      run: (args, editor) {
        final used = editor.addFunction(args.string('name').trim());
        editor.selectFunction(used);
        editor.showGraph(BlueprintGraphRef.function(used));
        return {'function': functionJson(functionOf(editor, used)), 'graph': 'function:$used'};
      },
    ),
    tool(
      name: 'rename_blueprint_function',
      title: 'Rename Blueprint function',
      idempotent: true,
      description: 'Renames a function; its call nodes follow.',
      properties: {'function': functionArg, 'name': newName},
      required: ['function', 'name'],
      run: (args, editor) {
        final f = functionOf(editor, args.string('function'));
        final to = args.string('name').trim();
        if (!editor.renameFunction(f.name, to)) refuse('"$to" is taken or not a valid name.');
        editor.selectFunction(to);
        return {'function': functionJson(functionOf(editor, to))};
      },
    ),
    tool(
      name: 'delete_blueprint_function',
      title: 'Delete Blueprint function',
      risk: McpToolRisk.destructive,
      removesContent: true,
      description: 'Deletes a function, its graph and every call node of it (listed in removed_nodes).',
      properties: {'function': functionArg},
      required: ['function'],
      run: (args, editor) {
        final f = functionOf(editor, args.string('function'));
        final nodes = [for (final n in editor.nodesCallingFunction(f.name)) n.id];
        editor.deleteFunction(f.name);
        return {'deleted': f.name, 'removed_nodes': nodes};
      },
    ),
    tool(
      name: 'set_blueprint_function_signature',
      title: 'Set Blueprint function signature',
      idempotent: true,
      description: 'The function\'s Details: inputs and outputs [{name, type, default?}], pure, category. The entry, '
          'result and call nodes follow; wires the new pins cannot carry are dropped (removed_wires).',
      properties: {
        'function': functionArg,
        'inputs': paramsSchema,
        'outputs': paramsSchema,
        'pure': McpSchema.boolean('A pure function has no exec pins.'),
        'category': McpSchema.string('The palette category.'),
      },
      required: ['function'],
      run: (args, editor) {
        final f = functionOf(editor, args.string('function'));
        final before = wireIds(editor);
        if (args.has('inputs')) editor.setFunctionInputs(f.name, mcpParseParams(args['inputs'], 'inputs'));
        if (args.has('outputs')) editor.setFunctionOutputs(f.name, mcpParseParams(args['outputs'], 'outputs'));
        if (args.has('pure')) editor.setFunctionPure(f.name, args.boolean('pure'));
        if (args.has('category')) editor.setFunctionCategory(f.name, args.string('category'));
        editor.selectFunction(f.name);
        return {'function': functionJson(functionOf(editor, f.name)), 'removed_wires': before.difference(wireIds(editor)).toList()};
      },
    ),
    // --- Local variables -----------------------------------------------------
    tool(
      name: 'add_blueprint_local_variable',
      title: 'Add local variable',
      description: 'A local variable of a function (made unique: use the returned name).',
      properties: {'function': functionArg, 'name': name, 'type': typeArg},
      required: ['function', 'name', 'type'],
      run: (args, editor) {
        final f = functionOf(editor, args.string('function'));
        final used = editor.addLocalVariable(f.name, args.string('name').trim(), mcpCheckType(args.string('type')));
        return {'function': functionJson(functionOf(editor, f.name)), 'local_variable': used};
      },
    ),
    tool(
      name: 'rename_blueprint_local_variable',
      title: 'Rename local variable',
      idempotent: true,
      description: 'Renames a local variable of a function; its nodes follow.',
      properties: {'function': functionArg, 'variable': McpSchema.string('The current name.'), 'name': newName},
      required: ['function', 'variable', 'name'],
      run: (args, editor) {
        final f = functionOf(editor, args.string('function'));
        if (!editor.renameLocalVariable(f.name, args.string('variable'), args.string('name').trim())) {
          refuse('No local variable "${args.string('variable')}" in ${f.name}, or the new name is taken.');
        }
        return {'function': functionJson(functionOf(editor, f.name))};
      },
    ),
    tool(
      name: 'set_blueprint_local_variable_type',
      title: 'Set local variable type',
      idempotent: true,
      description: 'Changes a local variable\'s type.',
      properties: {'function': functionArg, 'variable': McpSchema.string('The local variable.'), 'type': typeArg},
      required: ['function', 'variable', 'type'],
      run: (args, editor) {
        final f = functionOf(editor, args.string('function'));
        if (!editor.setLocalVariableType(f.name, args.string('variable'), mcpCheckType(args.string('type')))) {
          refuse('No local variable "${args.string('variable')}" in ${f.name}.');
        }
        return {'function': functionJson(functionOf(editor, f.name))};
      },
    ),
    tool(
      name: 'delete_blueprint_local_variable',
      title: 'Delete local variable',
      risk: McpToolRisk.destructive,
      removesContent: true,
      description: 'Deletes a local variable of a function and its nodes.',
      properties: {'function': functionArg, 'variable': McpSchema.string('The local variable.')},
      required: ['function', 'variable'],
      run: (args, editor) {
        final f = functionOf(editor, args.string('function'));
        final nodes = [for (final n in editor.nodesUsingLocalVariable(f.name, args.string('variable'))) n.id];
        if (!editor.deleteLocalVariable(f.name, args.string('variable'))) refuse('No local variable "${args.string('variable')}" in ${f.name}.');
        return {'function': functionJson(functionOf(editor, f.name)), 'removed_nodes': nodes};
      },
    ),
    // --- Macros --------------------------------------------------------------
    tool(
      name: 'add_blueprint_macro',
      title: 'Add Blueprint macro',
      description: 'My Blueprint → + Macro: a macro graph with its Inputs and Outputs nodes (made unique: use the '
          'returned name; its graph is "macro:<name>").',
      properties: {'name': name},
      required: ['name'],
      run: (args, editor) {
        final used = editor.addMacro(args.string('name').trim());
        editor.showGraph(BlueprintGraphRef.macro(used));
        return {'macro': used, 'graph': 'macro:$used'};
      },
    ),
    tool(
      name: 'rename_blueprint_macro',
      title: 'Rename Blueprint macro',
      idempotent: true,
      description: 'Renames a macro; its call nodes follow.',
      properties: {'macro': McpSchema.string('The macro.'), 'name': newName},
      required: ['macro', 'name'],
      run: (args, editor) {
        final m = macroOf(editor, args.string('macro'));
        final to = args.string('name').trim();
        if (!editor.renameMacro(m.name, to)) refuse('"$to" is taken or not a valid name.');
        return {'macro': to};
      },
    ),
    tool(
      name: 'delete_blueprint_macro',
      title: 'Delete Blueprint macro',
      risk: McpToolRisk.destructive,
      removesContent: true,
      description: 'Deletes a macro, its graph and its call nodes (removed_nodes).',
      properties: {'macro': McpSchema.string('The macro.')},
      required: ['macro'],
      run: (args, editor) {
        final m = macroOf(editor, args.string('macro'));
        final nodes = [for (final n in editor.nodesCallingMacro(m.name)) n.id];
        editor.deleteMacro(m.name);
        return {'deleted': m.name, 'removed_nodes': nodes};
      },
    ),
    tool(
      name: 'set_blueprint_macro_signature',
      title: 'Set Blueprint macro signature',
      idempotent: true,
      description: 'A macro\'s inputs and outputs [{name, type}] (Exec pins too: type "Exec" is not a variable type, so '
          'a macro\'s exec pins are the ones its Inputs / Outputs nodes carry). Wires the new pins cannot carry drop.',
      properties: {'macro': McpSchema.string('The macro.'), 'inputs': paramsSchema, 'outputs': paramsSchema},
      required: ['macro'],
      run: (args, editor) {
        final m = macroOf(editor, args.string('macro'));
        final before = wireIds(editor);
        if (args.has('inputs')) editor.setMacroInputs(m.name, mcpParseParams(args['inputs'], 'inputs'));
        if (args.has('outputs')) editor.setMacroOutputs(m.name, mcpParseParams(args['outputs'], 'outputs'));
        final after = macroOf(editor, m.name);
        return {
          'macro': m.name,
          'inputs': [for (final v in after.inputs) mcpVariableJson(v)],
          'outputs': [for (final v in after.outputs) mcpVariableJson(v)],
          'removed_wires': before.difference(wireIds(editor)).toList(),
        };
      },
    ),
    // --- Event dispatchers -----------------------------------------------------
    tool(
      name: 'add_blueprint_dispatcher',
      title: 'Add event dispatcher',
      description: 'My Blueprint → + Event Dispatcher (made unique: use the returned name).',
      properties: {'name': name},
      required: ['name'],
      run: (args, editor) {
        final used = editor.addDispatcher(args.string('name').trim());
        return {'dispatcher': used};
      },
    ),
    tool(
      name: 'rename_blueprint_dispatcher',
      title: 'Rename event dispatcher',
      idempotent: true,
      description: 'Renames an event dispatcher; its Call / Bind / Assign nodes follow.',
      properties: {'dispatcher': McpSchema.string('The dispatcher.'), 'name': newName},
      required: ['dispatcher', 'name'],
      run: (args, editor) {
        final d = dispatcherOf(editor, args.string('dispatcher'));
        final to = args.string('name').trim();
        if (!editor.renameDispatcher(d.name, to)) refuse('"$to" is taken or not a valid name.');
        return {'dispatcher': to};
      },
    ),
    tool(
      name: 'delete_blueprint_dispatcher',
      title: 'Delete event dispatcher',
      risk: McpToolRisk.destructive,
      removesContent: true,
      description: 'Deletes an event dispatcher and its nodes (removed_nodes).',
      properties: {'dispatcher': McpSchema.string('The dispatcher.')},
      required: ['dispatcher'],
      run: (args, editor) {
        final d = dispatcherOf(editor, args.string('dispatcher'));
        final nodes = [for (final n in editor.nodesUsingDispatcher(d.name)) n.id];
        editor.deleteDispatcher(d.name);
        return {'deleted': d.name, 'removed_nodes': nodes};
      },
    ),
    tool(
      name: 'set_blueprint_dispatcher_parameters',
      title: 'Set event dispatcher parameters',
      idempotent: true,
      description: 'An event dispatcher\'s parameters [{name, type}]; its nodes follow, wires they cannot carry drop.',
      properties: {'dispatcher': McpSchema.string('The dispatcher.'), 'parameters': paramsSchema},
      required: ['dispatcher', 'parameters'],
      run: (args, editor) {
        final d = dispatcherOf(editor, args.string('dispatcher'));
        final before = wireIds(editor);
        editor.setDispatcherParameters(d.name, mcpParseParams(args['parameters'], 'parameters'));
        final after = dispatcherOf(editor, d.name);
        return {
          'dispatcher': d.name,
          'parameters': [for (final v in after.parameters) mcpVariableJson(v)],
          'removed_wires': before.difference(wireIds(editor)).toList(),
        };
      },
    ),
    // --- Interfaces ------------------------------------------------------------
    tool(
      name: 'implement_blueprint_interface',
      title: 'Implement interface',
      description: 'Class Defaults → Interfaces → Add: implements a project Blueprint Interface (contents/interfaces/'
          'BPI_*.lmas); its functions become "Event <Function>" nodes in the palette.',
      properties: {'interface': McpSchema.string('The interface name, e.g. "BPI_Interactable".')},
      required: ['interface'],
      run: (args, editor) {
        final wanted = args.string('interface');
        final known = [for (final i in editor.projectInterfaces) i.name];
        if (!known.contains(wanted)) {
          refuse('No Blueprint Interface "$wanted" in the project. Interfaces: ${known.isEmpty ? '(none)' : known.join(', ')}.');
        }
        if (!editor.addInterface(wanted)) refuse('${editor.fileBasename} already implements $wanted.');
        return {'interfaces': List<String>.from(editor.document.interfaces)};
      },
    ),
    tool(
      name: 'remove_blueprint_interface',
      title: 'Remove interface',
      risk: McpToolRisk.destructive,
      removesContent: true,
      description: 'Stops implementing an interface; its interface event nodes are removed.',
      properties: {'interface': McpSchema.string('The interface name.')},
      required: ['interface'],
      run: (args, editor) {
        if (!editor.removeInterface(args.string('interface'))) {
          refuse('${editor.fileBasename} does not implement ${args.string('interface')}. Implemented: ${editor.document.interfaces.join(', ')}.');
        }
        return {'interfaces': List<String>.from(editor.document.interfaces)};
      },
    ),
    // --- Custom events -----------------------------------------------------------
    tool(
      name: 'set_custom_event_parameters',
      title: 'Set custom event parameters',
      idempotent: true,
      description: 'A Custom Event node\'s parameters [{name, type}] (place one with add_blueprint_node {node: '
          '"custom_event", literals: {name}}): they become its output pins and its call nodes\' inputs.',
      properties: {
        'graph': McpSchema.string(kBlueprintGraphArg),
        'node': McpSchema.string('The custom event node id.'),
        'parameters': paramsSchema,
      },
      required: ['node', 'parameters'],
      run: (args, editor) {
        final (ref, graph) = mcpResolveGraph(editor, args.optionalString('graph'));
        final nodeId = args.string('node');
        final node = graph.node(nodeId);
        if (node == null || node.registryId != LuminaBlueprintNodeLibrary.customEvent) {
          refuse('"$nodeId" is not a Custom Event node in the ${mcpGraphName(ref)} graph.');
        }
        graph.setCustomEventParameters(nodeId, mcpParseParams(args['parameters'], 'parameters'));
        editor.showGraph(ref);
        return {'node': mcpNodeJson(graph, graph.node(nodeId)!)};
      },
    ),
    // --- Timelines ---------------------------------------------------------------
    tool(
      name: 'set_blueprint_timeline',
      title: 'Set timeline',
      idempotent: true,
      description: 'A Timeline node\'s settings (the Timeline editor\'s toolbar): length (seconds), loop, auto_play. '
          'Place the node with add_blueprint_node {node: "timeline"}.',
      properties: {
        'node': McpSchema.string('The timeline node id.'),
        'length': McpSchema.number('Length in seconds.'),
        'loop': McpSchema.boolean('Loop.'),
        'auto_play': McpSchema.boolean('Auto Play.'),
      },
      required: ['node'],
      run: (args, editor) {
        final node = timelineOf(editor, args.string('node'));
        if (args.has('length')) editor.setTimelineLength(node.id, args.number('length'));
        if (args.has('loop')) editor.setTimelineLoop(node.id, args.boolean('loop'));
        if (args.has('auto_play')) editor.setTimelineAutoPlay(node.id, args.boolean('auto_play'));
        return {
          'node': node.id,
          'length': editor.timelineLength(node.id),
          'loop': editor.timelineLoop(node.id),
          'auto_play': editor.timelineAutoPlay(node.id),
          'tracks': tracksOf(editor, node.id),
        };
      },
    ),
    tool(
      name: 'add_timeline_track',
      title: 'Add timeline track',
      description: 'A float, vector or color track on a Timeline (made unique: use the returned name); it becomes the '
          'node\'s output pin.',
      properties: {
        'node': McpSchema.string('The timeline node id.'),
        'name': name,
        'type': McpSchema.string('"float", "vector" or "color".', enumValues: const ['float', 'vector', 'color']),
      },
      required: ['node', 'name', 'type'],
      run: (args, editor) {
        final node = timelineOf(editor, args.string('node'));
        final used = editor.addTimelineTrack(node.id, args.string('name').trim(), type: args.string('type'));
        return {'node': node.id, 'track': used, 'tracks': tracksOf(editor, node.id)};
      },
    ),
    tool(
      name: 'remove_timeline_track',
      title: 'Remove timeline track',
      risk: McpToolRisk.destructive,
      removesContent: true,
      description: 'Removes a track (and its keys) from a Timeline.',
      properties: {'node': McpSchema.string('The timeline node id.'), 'track': McpSchema.string('The track name.')},
      required: ['node', 'track'],
      run: (args, editor) {
        final node = timelineOf(editor, args.string('node'));
        if (!editor.removeTimelineTrack(node.id, args.string('track'))) refuse('No track "${args.string('track')}" on ${node.id}.');
        return {'node': node.id, 'tracks': tracksOf(editor, node.id)};
      },
    ),
    tool(
      name: 'rename_timeline_track',
      title: 'Rename timeline track',
      idempotent: true,
      description: 'Renames a track (its output pin follows).',
      properties: {'node': McpSchema.string('The timeline node id.'), 'track': McpSchema.string('The track.'), 'name': newName},
      required: ['node', 'track', 'name'],
      run: (args, editor) {
        final node = timelineOf(editor, args.string('node'));
        if (!editor.renameTimelineTrack(node.id, args.string('track'), args.string('name').trim())) {
          refuse('No track "${args.string('track')}" on ${node.id}, or the new name is taken.');
        }
        return {'node': node.id, 'tracks': tracksOf(editor, node.id)};
      },
    ),
    tool(
      name: 'set_timeline_keys',
      title: 'Set timeline keys',
      idempotent: true,
      description: 'Replaces a track\'s keys: [{time, value, interp?}] — value a number or [x] for a float track, '
          '[x, y, z] for vector, [r, g, b, a] for color; interp linear (default), cubic or constant.',
      properties: {
        'node': McpSchema.string('The timeline node id.'),
        'track': McpSchema.string('The track name.'),
        'keys': {'type': 'array', 'description': '[{time, value, interp?}]', 'items': {'type': 'object'}},
      },
      required: ['node', 'track', 'keys'],
      run: (args, editor) {
        final node = timelineOf(editor, args.string('node'));
        final track = args.string('track');
        final tracks = editor.timelineTracks(node.id);
        if (!tracks.any((t) => t.name == track)) {
          refuse('No track "$track" on ${node.id}. Tracks: ${tracks.map((t) => t.name).join(', ')}.');
        }
        final raw = args['keys'];
        if (raw is! List) refuse('"keys" must be an array of {time, value, interp?}.');
        final keys = <LuminaTimelineKey>[];
        for (final k in raw) {
          if (k is! Map || k['time'] is! num || k['value'] == null) refuse('Each key needs a number time and a value: $k');
          final value = k['value'];
          final list = value is num
              ? [value.toDouble()]
              : value is List && value.every((e) => e is num)
                  ? [for (final e in value) (e as num).toDouble()]
                  : refuse('A key value is a number or a list of numbers: $value');
          final interp = LuminaTimelineInterp.values.where((i) => i.name == (k['interp'] ?? 'linear')).firstOrNull ??
              refuse('interp is linear, cubic or constant: ${k['interp']}');
          keys.add(LuminaTimelineKey((k['time'] as num).toDouble(), list, interp));
        }
        editor.setTimelineKeys(node.id, track, keys);
        return {'node': node.id, 'tracks': tracksOf(editor, node.id)};
      },
    ),
    // --- Collapse / expand ----------------------------------------------------------
    tool(
      name: 'collapse_blueprint_nodes',
      title: 'Collapse nodes',
      description: 'The graph\'s context menu → Collapse to Function / Macro: the nodes move into a new function or '
          'macro graph and one call node takes their place, wired as they were. Returns the call node and the new graph.',
      properties: {
        'graph': McpSchema.string(kBlueprintGraphArg),
        'nodes': McpSchema.stringArray('The node ids to collapse.'),
        'to': McpSchema.string('"function" or "macro".', enumValues: const ['function', 'macro']),
        'name': McpSchema.string('The new function or macro name (made unique).'),
      },
      required: ['nodes', 'to'],
      run: (args, editor) {
        final (ref, graph) = mcpResolveGraph(editor, args.optionalString('graph'));
        final ids = args.stringList('nodes').toSet();
        final missing = ids.where((id) => graph.node(id) == null).toList();
        if (missing.isNotEmpty) refuse('No node(s) ${missing.join(', ')} in the ${mcpGraphName(ref)} graph.');
        graph.selectMany(ids);
        final call = editor.collapseSelection(toMacro: args.string('to') == 'macro', name: args.optionalString('name'), graph: ref);
        if (call == null) refuse('The nodes cannot be collapsed: ${editor.collapseRefusal ?? 'unknown reason'}.');
        final created = (call.literals['function'] ?? call.literals['macro']) as String?;
        return {
          'call_node': mcpNodeJson(graph, call),
          'graph': mcpGraphName(ref),
          'created': created == null ? null : '${args.string('to')}:$created',
        };
      },
    ),
    tool(
      name: 'expand_blueprint_node',
      title: 'Expand node',
      description: 'The graph\'s context menu → Expand Node on a function or macro call: the body comes back where the '
          'call was, wired as it was; the function or macro is deleted when nothing else calls it.',
      properties: {'graph': McpSchema.string(kBlueprintGraphArg), 'node': McpSchema.string('The call node id.')},
      required: ['node'],
      run: (args, editor) {
        final (ref, graph) = mcpResolveGraph(editor, args.optionalString('graph'));
        final nodeId = args.string('node');
        if (graph.node(nodeId) == null) refuse('No node "$nodeId" in the ${mcpGraphName(ref)} graph.');
        final restored = editor.expandNode(nodeId, graph: ref);
        if (restored == null) refuse('"$nodeId" is not a function or macro call node.');
        return {'restored_nodes': restored.toList(), 'graph': mcpGraphName(ref)};
      },
    ),
  ]);
}

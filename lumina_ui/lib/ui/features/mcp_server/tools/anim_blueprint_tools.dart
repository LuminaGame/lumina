import 'dart:io';
import 'dart:ui' show Offset;

import 'package:lumina_editor_data/lumina_editor.dart';

import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_compile_status.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/anim_blueprint_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_graph_editor.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_editor_sessions.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_protocol.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_tool.dart';
import 'package:lumina_ui/ui/features/mcp_server/tools/blueprint_tool_support.dart' show mcpCheckType, mcpVariableJson;
import 'package:lumina_ui/ui/features/mcp_server/tools/core_tools.dart' show mcpUndoState;
import 'package:lumina_ui/ui/features/mcp_server/tools/graph_json.dart';

/// The Animation Blueprint editor as MCP tools: the
/// document (target mesh, clips, blend spaces, variables, the state
/// machine, the compile rows), states and their poses, transitions and
/// their rule graphs, the Update event graph (node / wire / literal edits
/// aimed by `graph`), variables, Compile to `lib/anim/<ABP>.dart` and the
/// Anim Preview Editor. Every edit goes through the tab's
/// `AnimBlueprintEditorViewModel` (opened when needed), so the graph canvas
/// updates live and each call is one `MCP: …` step on the tab's own stack.
void registerAnimBlueprintTools(McpToolRegistry registry, EditorViewModel vm, McpEditorSessions sessions) {
  const groups = {McpToolGroups.animation};
  final assetArg = McpSchema.string('The Animation Blueprint: its project-relative .lmas path (list_assets with type '
      '"animBlueprint") or its file name when unique.');
  final graphArg = McpSchema.string('The graph: "event" (default, the Update event graph) or "transition:<id>" (a '
      'transition\'s rule; get_anim_blueprint lists them under graphs).');
  final stateArg = McpSchema.string('A state of the state machine, by name (get_anim_blueprint).');
  final poseArg = {
    'type': 'object',
    'description': 'A state\'s pose: {kind: "clip", clip, rate?, loop?} (a clip of the target mesh, get_anim_blueprint '
        'clips), {kind: "blend_space", blend_space, x_variable, y_variable?, rate?} (a Blend Space of blend_spaces '
        'sampled by float variables), or {kind: "hold"} (the current pose held still).',
  };

  Future<AnimBlueprintEditorViewModel> editorFor(McpArgs args) async {
    final asset = sessions.resolveAsset(args.string('asset'));
    if (asset.type != AssetType.animBlueprint) {
      throw JsonRpcException(JsonRpcErrorCode.invalidParams,
          '${asset.relativePath} is a ${asset.type.name}, not an Animation Blueprint. Call list_assets with type "animBlueprint".');
    }
    return sessions.animBlueprint(asset);
  }

  LuminaAnimStateMachine machineOf(AnimBlueprintEditorViewModel editor) =>
      editor.machine ?? (throw JsonRpcException(JsonRpcErrorCode.invalidParams, '${editor.name} has no state machine yet; add a state first.'));

  String stateOf(AnimBlueprintEditorViewModel editor, String name) {
    final m = machineOf(editor);
    if (m.state(name) == null) {
      throw JsonRpcException(
          JsonRpcErrorCode.invalidParams, 'No state "$name" in ${m.name}. States: ${m.states.map((s) => s.name).join(', ')}.');
    }
    return name;
  }

  String transitionOf(AnimBlueprintEditorViewModel editor, String id) {
    if (editor.transition(id) == null) {
      final ids = machineOf(editor).transitions.map((t) => t.id).join(', ');
      throw JsonRpcException(JsonRpcErrorCode.invalidParams, 'No transition "$id". Transitions: ${ids.isEmpty ? 'none' : ids}.');
    }
    return id;
  }

  List<String> graphNames(AnimBlueprintEditorViewModel editor) =>
      ['event', for (final t in editor.machine?.transitions ?? const <LuminaAnimTransition>[]) 'transition:${t.id}'];

  /// The graph [args] name (shown in the tab), its editor and its name.
  (BlueprintGraphEditor, String) graphOf(AnimBlueprintEditorViewModel editor, McpArgs args) {
    final name = args.optionalString('graph') ?? 'event';
    if (name == 'event' || name == 'EventGraph') {
      editor.open(const AnimGraphLocation.eventGraph());
      return (editor.eventGraph, 'event');
    }
    if (name.startsWith('transition:')) {
      final id = name.substring('transition:'.length);
      final m = editor.machine;
      if (m != null && editor.transition(id) != null) {
        editor.open(AnimGraphLocation.transition(m.name, id));
        return (editor.ruleEditor(id), name);
      }
    }
    throw JsonRpcException(JsonRpcErrorCode.invalidParams, 'No graph "$name". Graphs: ${graphNames(editor).join(', ')}.');
  }

  Map<String, Object?> poseJson(LuminaAnimPose p) => {
        'kind': switch (p.kind) {
          LuminaAnimPoseKind.clip => 'clip',
          LuminaAnimPoseKind.blendSpace => 'blend_space',
          _ => 'hold',
        },
        'clip': p.clip,
        if (p.isRandom) 'clips': p.clips,
        'blend_space': p.blendSpace,
        'x_variable': p.xVariable,
        'y_variable': p.yVariable,
        'rate': p.rate,
        'loop': p.loop,
      };

  /// [raw] as a pose the editor can play; a clip or blend space the target
  /// mesh does not have is an error listing the ones it has.
  LuminaAnimPose parsePose(AnimBlueprintEditorViewModel editor, Object? raw) {
    if (raw is! Map) throw JsonRpcException(JsonRpcErrorCode.invalidParams, '"pose" must be an object {kind, …}.');
    final kind = raw['kind'];
    final rate = (raw['rate'] as num?)?.toDouble() ?? 1.0;
    switch (kind) {
      case 'clip':
        final clip = raw['clip'];
        if (clip is! String || !editor.clips.contains(clip)) {
          throw JsonRpcException(JsonRpcErrorCode.invalidParams,
              'No clip "$clip" on ${editor.targetMesh}. Clips: ${editor.clips.join(', ')}.');
        }
        return LuminaAnimPose.clip(clip, rate: rate, loop: raw['loop'] as bool? ?? true);
      case 'blend_space':
        final path = raw['blend_space'];
        if (path is! String || !editor.blendSpacePaths.contains(path)) {
          throw JsonRpcException(JsonRpcErrorCode.invalidParams,
              'No Blend Space "$path" for ${editor.targetMesh}. Blend spaces: ${editor.blendSpacePaths.isEmpty ? 'none' : editor.blendSpacePaths.join(', ')}.');
        }
        final names = editor.document.variables.map((v) => v.name).toList();
        final x = raw['x_variable'], y = raw['y_variable'];
        for (final v in [x, ?y]) {
          if (v is! String || !names.contains(v)) {
            throw JsonRpcException(JsonRpcErrorCode.invalidParams,
                'A blend space pose samples variables: "$v" is not one. Variables: ${names.isEmpty ? 'none (add_anim_variable)' : names.join(', ')}.');
          }
        }
        return LuminaAnimPose.blendSpace(path, xVariable: x as String, yVariable: y as String?, rate: rate);
      case 'hold':
        return const LuminaAnimPose.hold();
      default:
        throw JsonRpcException(JsonRpcErrorCode.invalidParams, 'pose.kind must be "clip", "blend_space" or "hold"; got "$kind".');
    }
  }

  String? rowGraph(AnimCompileRow r) {
    final at = r.location;
    if (at == null) return null;
    return switch (at.view) {
      AnimGraphView.eventGraph => 'event',
      AnimGraphView.transition => 'transition:${at.transition}',
      AnimGraphView.state => 'state:${at.state}',
      AnimGraphView.stateMachine => 'state_machine',
      AnimGraphView.animGraph => 'anim_graph',
    };
  }

  List<Map<String, Object?>> rowsOf(AnimBlueprintEditorViewModel editor) => [
        for (final r in editor.compileRows)
          {
            'severity': r.diagnostic.severity.name,
            'message': r.diagnostic.message,
            'graph': rowGraph(r),
            'node_id': r.diagnostic.nodeId,
            'node_title': r.nodeTitle,
          },
      ];

  Map<String, Object?> machineJson(LuminaAnimStateMachine? m) => m == null
      ? const {'name': null, 'entry_state': null, 'states': [], 'transitions': []}
      : {
          'name': m.name,
          'entry_state': m.entryState,
          'states': [for (final s in m.states) {'name': s.name, 'x': s.x, 'y': s.y, 'pose': poseJson(s.pose)}],
          'transitions': [
            for (final t in m.transitions)
              {'id': t.id, 'from': t.from, 'to': t.to, 'blend_duration': t.blendDuration, 'priority': t.priority},
          ],
        };

  Map<String, Object?> edited(AnimBlueprintEditorViewModel editor, [Map<String, Object?> extra = const {}]) => {
        ...extra,
        'is_dirty': editor.isDirty,
        'undo': mcpUndoState(editor.transactions),
      };

  McpToolResult unchanged(String what) => McpToolResult.error('$what: nothing changed (the editor refused or the value is the same).');

  registry.registerAll([
    McpTool(
      name: 'get_anim_blueprint',
      risk: McpToolRisk.readOnly,
      groups: groups,
      title: 'Get Animation Blueprint',
      description: 'An Animation Blueprint as its editor shows it: target_mesh, the mesh\'s clips, the Blend Spaces made '
          'for it, variables [{name, type, default}], the state machine {name, entry_state, states [{name, x, y, pose}], '
          'transitions [{id, from, to, blend_duration, priority}]}, the node graphs ("event", "transition:<id>"), the '
          'compile status and rows [{severity, message, graph, node_id, node_title}], is_dirty, and the preview\'s active '
          'state. One AnimGraph with one state machine is what the document holds. Opens its tab on the state machine.',
      inputSchema: McpSchema.object({'asset': assetArg}, required: ['asset']),
      handler: (args) async {
        final e = await editorFor(args);
        final m = e.machine;
        if (m != null) e.open(AnimGraphLocation.stateMachine(m.name));
        return McpToolResult.json({
          'asset': e.relativePath,
          'target_mesh': e.targetMesh,
          'clips': e.clips,
          'blend_spaces': e.blendSpacePaths,
          'variables': [for (final v in e.document.variables) mcpVariableJson(v)],
          'state_machine': machineJson(e.machine),
          'graphs': graphNames(e),
          'compile_status': e.compileStatus.name,
          'compile_rows': rowsOf(e),
          'is_dirty': e.isDirty,
          'preview_state': e.previewState,
          'preview_clip': e.previewClip,
          'undo': mcpUndoState(e.transactions),
        });
      },
    ),
    McpTool(
      name: 'add_anim_state',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: false,
      title: 'Add Anim state',
      description: 'Adds a state to the state machine at canvas (x, y), optionally with its pose, as one undo step. The '
          'first state of an empty machine becomes the entry state. A name already used is refused.',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'name': McpSchema.string('The state name (letters, digits, spaces, underscores).'),
        'x': McpSchema.number('State machine canvas x.'),
        'y': McpSchema.number('State machine canvas y.'),
        'pose': poseArg,
      }, required: ['asset', 'name', 'x', 'y']),
      handler: (args) async {
        final e = await editorFor(args);
        final name = args.string('name').trim();
        if (e.machine?.state(name) != null) return McpToolResult.error('A state "$name" already exists; pick another name.');
        final pose = args.has('pose') ? parsePose(e, args['pose']) : null;
        final added = e.addState(Offset(args.number('x'), args.number('y')), base: name);
        if (added == null || added != name) {
          if (added != null) e.undo();
          return McpToolResult.error('"$name" is not a valid state name (letters, digits, spaces and underscores).');
        }
        if (pose != null) e.setStatePose(name, pose);
        e.open(AnimGraphLocation.stateMachine(e.machine!.name));
        return McpToolResult.json(edited(e, {'state': name, 'state_machine': machineJson(e.machine)}));
      },
    ),
    McpTool(
      name: 'rename_anim_state',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: false,
      title: 'Rename Anim state',
      description: 'Renames a state; its transitions and the entry state follow (one undo step).',
      inputSchema: McpSchema.object({'asset': assetArg, 'state': stateArg, 'name': McpSchema.string('The new name.')},
          required: ['asset', 'state', 'name']),
      handler: (args) async {
        final e = await editorFor(args);
        final old = stateOf(e, args.string('state'));
        if (!e.renameState(old, args.string('name'))) {
          return McpToolResult.error('Cannot rename "$old" to "${args.string('name')}": the name is taken, empty or not an identifier.');
        }
        return McpToolResult.json(edited(e, {'state_machine': machineJson(e.machine)}));
      },
    ),
    McpTool(
      name: 'delete_anim_state',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: false,
      removesContent: true,
      title: 'Delete Anim state',
      description: 'Deletes a state and its transitions (one undo step). Deleting the entry state makes the first '
          'remaining state the entry.',
      inputSchema: McpSchema.object({'asset': assetArg, 'state': stateArg}, required: ['asset', 'state']),
      handler: (args) async {
        final e = await editorFor(args);
        final name = stateOf(e, args.string('state'));
        if (!e.deleteState(name)) return unchanged('delete_anim_state');
        return McpToolResult.json(edited(e, {'deleted': name, 'state_machine': machineJson(e.machine)}));
      },
    ),
    McpTool(
      name: 'move_anim_state',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: true,
      title: 'Move Anim state',
      description: 'Moves a state to canvas (x, y) as one undo step, as dragging its node does.',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'state': stateArg,
        'x': McpSchema.number('Canvas x.'),
        'y': McpSchema.number('Canvas y.'),
      }, required: ['asset', 'state', 'x', 'y']),
      handler: (args) async {
        final e = await editorFor(args);
        final name = stateOf(e, args.string('state'));
        final s = e.machine!.state(name)!;
        e.beginInteraction('Move state $name');
        e.moveState(name, Offset(args.number('x') - s.x, args.number('y') - s.y));
        e.endInteraction(layoutOnly: true);
        final moved = e.machine!.state(name)!;
        return McpToolResult.json(edited(e, {'state': name, 'x': moved.x, 'y': moved.y}));
      },
    ),
    McpTool(
      name: 'set_anim_entry_state',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: true,
      title: 'Set Anim entry state',
      description: 'Makes a state the state machine\'s entry state (one undo step).',
      inputSchema: McpSchema.object({'asset': assetArg, 'state': stateArg}, required: ['asset', 'state']),
      handler: (args) async {
        final e = await editorFor(args);
        final name = stateOf(e, args.string('state'));
        e.setEntryState(name);
        return McpToolResult.json(edited(e, {'entry_state': e.machine!.entryState}));
      },
    ),
    McpTool(
      name: 'set_anim_state_pose',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: true,
      title: 'Set Anim state pose',
      description: 'Sets what a state plays: a clip of the target mesh, a Blend Space sampled by variables, or hold '
          '(one undo step). A clip or Blend Space the mesh does not have is an error listing the ones it has.',
      inputSchema: McpSchema.object({'asset': assetArg, 'state': stateArg, 'pose': poseArg}, required: ['asset', 'state', 'pose']),
      handler: (args) async {
        final e = await editorFor(args);
        final name = stateOf(e, args.string('state'));
        e.setStatePose(name, parsePose(e, args['pose']));
        return McpToolResult.json(edited(e, {'state': name, 'pose': poseJson(e.machine!.state(name)!.pose)}));
      },
    ),
    McpTool(
      name: 'add_anim_transition',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: false,
      title: 'Add Anim transition',
      description: 'Adds a transition between two states (one undo step). Its rule graph starts as an unconnected '
          'Result: author it with the anim graph tools on graph "transition:<id>" and wire a boolean into the Result\'s '
          '"can_enter". Returns the id (Idle → Moving is "idle_to_moving") and the Result node.',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'from': McpSchema.string('The source state.'),
        'to': McpSchema.string('The target state.'),
        'blend_duration': McpSchema.number('Cross-fade seconds (default 0.2 as the editor makes it).'),
        'priority': McpSchema.integer('Lower is checked first.'),
      }, required: ['asset', 'from', 'to']),
      handler: (args) async {
        final e = await editorFor(args);
        final from = stateOf(e, args.string('from')), to = stateOf(e, args.string('to'));
        final id = e.addTransition(from, to);
        if (id == null) return McpToolResult.error('Cannot add $from → $to: a state cannot transition to itself and a pair has one transition.');
        if (args.has('blend_duration') || args.has('priority')) {
          e.updateTransition(id, blendDuration: args.optionalNumber('blend_duration'), priority: args.has('priority') ? args.integer('priority') : null);
        }
        final rule = e.ruleEditor(id);
        final result = e.transition(id)!.resultNode;
        e.open(AnimGraphLocation.transition(e.machine!.name, id));
        return McpToolResult.json(edited(e, {
          'id': id,
          'graph': 'transition:$id',
          'result_node': result == null ? null : mcpNodeJson(rule, result),
          'transition': (machineJson(e.machine)['transitions'] as List).cast<Map>().firstWhere((t) => t['id'] == id),
        }));
      },
    ),
    McpTool(
      name: 'delete_anim_transition',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: false,
      removesContent: true,
      title: 'Delete Anim transition',
      description: 'Deletes a transition and its rule graph (one undo step).',
      inputSchema: McpSchema.object({'asset': assetArg, 'id': McpSchema.string('The transition id.')}, required: ['asset', 'id']),
      handler: (args) async {
        final e = await editorFor(args);
        final id = transitionOf(e, args.string('id'));
        if (!e.deleteTransition(id)) return unchanged('delete_anim_transition');
        return McpToolResult.json(edited(e, {'deleted': id}));
      },
    ),
    McpTool(
      name: 'set_anim_transition',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: true,
      title: 'Set Anim transition',
      description: 'Sets a transition\'s blend duration (seconds, at least 0) and priority (one undo step).',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'id': McpSchema.string('The transition id.'),
        'blend_duration': McpSchema.number('Cross-fade seconds.'),
        'priority': McpSchema.integer('Lower is checked first.'),
      }, required: ['asset', 'id']),
      handler: (args) async {
        final e = await editorFor(args);
        final id = transitionOf(e, args.string('id'));
        e.updateTransition(id, blendDuration: args.optionalNumber('blend_duration'), priority: args.has('priority') ? args.integer('priority') : null);
        return McpToolResult.json(edited(e, {
          'transition': (machineJson(e.machine)['transitions'] as List).cast<Map>().firstWhere((t) => t['id'] == id),
        }));
      },
    ),
    McpTool(
      name: 'get_anim_graph',
      risk: McpToolRisk.readOnly,
      groups: groups,
      title: 'Get Anim graph',
      description: 'One node graph of the Animation Blueprint — the Update event graph ("event") or a transition\'s '
          'rule ("transition:<id>") — with its nodes (id, library id, position, pins with literals and connection state) '
          'and wires. Shows that graph in the tab.',
      inputSchema: McpSchema.object({'asset': assetArg, 'graph': graphArg}, required: ['asset']),
      handler: (args) async {
        final e = await editorFor(args);
        final (graph, name) = graphOf(e, args);
        return McpToolResult.json({'graph': name, 'graphs': graphNames(e), ...mcpGraphJson(graph)});
      },
    ),
    McpTool(
      name: 'add_anim_graph_node',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: false,
      title: 'Add Anim graph node',
      description: 'Places a library node (list_blueprint_nodes id) on the Update event graph or a transition rule at '
          '(x, y), one undo step. A rule graph takes pure nodes only (math, comparisons, Get variable); the event graph '
          'takes no events but Blueprint Update Animation and no latent nodes. Optional literals set input pins and '
          'node settings (a variable node\'s "variable").',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'graph': graphArg,
        'node': McpSchema.string('The library id, e.g. "variable_get", "float_greater".'),
        'x': McpSchema.number('Canvas x. Default 400.'),
        'y': McpSchema.number('Canvas y. Default 200.'),
        'literals': {'type': 'object', 'description': 'Initial pin literals and node settings, by pin id.'},
      }, required: ['asset', 'node']),
      handler: (args) async {
        final e = await editorFor(args);
        final (graph, name) = graphOf(e, args);
        return mcpGraphAddNode(graph, name, args,
            rejected: name == 'event'
                ? 'the Update event graph takes no events but Blueprint Update Animation, and no latent nodes.'
                : 'transition rule graphs take pure nodes only (no exec pins).',
            extra: () => edited(e));
      },
    ),
    McpTool(
      name: 'connect_anim_graph_pins',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: false,
      title: 'Connect Anim graph pins',
      description: 'Wires an output pin to an input pin of the same graph (one undo step); data pins of the same type '
          'only. A rule\'s boolean goes into the Result\'s "can_enter".',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'graph': graphArg,
        'from_node': McpSchema.string('The source node id (get_anim_graph).'),
        'from_pin': McpSchema.string('The source output pin id.'),
        'to_node': McpSchema.string('The target node id.'),
        'to_pin': McpSchema.string('The target input pin id.'),
      }, required: ['asset', 'from_node', 'from_pin', 'to_node', 'to_pin']),
      handler: (args) async {
        final e = await editorFor(args);
        final (graph, name) = graphOf(e, args);
        return mcpGraphConnect(graph, name, args, extra: () => edited(e));
      },
    ),
    McpTool(
      name: 'set_anim_graph_pin_literal',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: true,
      title: 'Set Anim graph pin literal',
      description: 'Sets the literal of an unconnected input pin (one undo step).',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'graph': graphArg,
        'node': McpSchema.string('The node id (get_anim_graph).'),
        'pin': McpSchema.string('The input pin id, e.g. "b".'),
        'value': McpSchema.any('The literal, of the pin\'s type.'),
      }, required: ['asset', 'node', 'pin', 'value']),
      handler: (args) async {
        final e = await editorFor(args);
        final (graph, name) = graphOf(e, args);
        return mcpGraphSetLiteral(graph, name, args, extra: () => edited(e));
      },
    ),
    McpTool(
      name: 'remove_anim_graph_node',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: false,
      removesContent: true,
      title: 'Remove Anim graph node',
      description: 'Deletes a node and its wires (one undo step). A rule\'s Result and the Update event cannot be removed.',
      inputSchema: McpSchema.object({'asset': assetArg, 'graph': graphArg, 'node': McpSchema.string('The node id.')},
          required: ['asset', 'node']),
      handler: (args) async {
        final e = await editorFor(args);
        final (graph, name) = graphOf(e, args);
        return mcpGraphRemoveNode(graph, name, args, extra: () => edited(e));
      },
    ),
    McpTool(
      name: 'remove_anim_graph_wire',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: false,
      removesContent: true,
      title: 'Remove Anim graph wire',
      description: 'Deletes a wire (one undo step). Wire ids come from get_anim_graph.',
      inputSchema: McpSchema.object({'asset': assetArg, 'graph': graphArg, 'wire': McpSchema.string('The wire id.')},
          required: ['asset', 'wire']),
      handler: (args) async {
        final e = await editorFor(args);
        final (graph, name) = graphOf(e, args);
        return mcpGraphRemoveWire(graph, name, args, extra: () => edited(e));
      },
    ),
    McpTool(
      name: 'add_anim_variable',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: false,
      title: 'Add Anim variable',
      description: 'Adds a variable (one undo step); a taken name gets a numeric suffix, which the result reports. '
          'Types: float, bool, integer, name, string, vector, …',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'name': McpSchema.string('The variable name.'),
        'type': McpSchema.string('The type, e.g. "float" or "bool".'),
        'default': McpSchema.any('The default value, of the type.'),
      }, required: ['asset', 'name', 'type']),
      handler: (args) async {
        final e = await editorFor(args);
        final type = mcpCheckType(args.string('type'));
        final name = e.addVariable(args.string('name').trim(), type, args['default']);
        return McpToolResult.json(edited(e, {
          'variable': mcpVariableJson(e.document.variables.firstWhere((v) => v.name == name)),
        }));
      },
    ),
    McpTool(
      name: 'rename_anim_variable',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: false,
      title: 'Rename Anim variable',
      description: 'Renames a variable; its Get / Set nodes and the blend space poses that sample it follow (one undo step).',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'name': McpSchema.string('The variable.'),
        'new_name': McpSchema.string('The new name (an identifier not in use).'),
      }, required: ['asset', 'name', 'new_name']),
      handler: (args) async {
        final e = await editorFor(args);
        final name = args.string('name'), next = args.string('new_name');
        if (!e.document.variables.any((v) => v.name == name)) {
          return McpToolResult.error('No variable "$name". Variables: ${e.document.variables.map((v) => v.name).join(', ')}.');
        }
        if (!e.renameVariable(name, next)) return McpToolResult.error('Cannot rename "$name" to "$next": the name is taken or not an identifier.');
        return McpToolResult.json(edited(e, {'variables': [for (final v in e.document.variables) mcpVariableJson(v)]}));
      },
    ),
    McpTool(
      name: 'set_anim_variable',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: true,
      title: 'Set Anim variable',
      description: 'Changes a variable\'s type (its nodes re-pin; the default resets to the type\'s) and / or its '
          'default value, one undo step each.',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'name': McpSchema.string('The variable.'),
        'type': McpSchema.string('A new type.'),
        'default': McpSchema.any('A new default value.'),
      }, required: ['asset', 'name']),
      handler: (args) async {
        final e = await editorFor(args);
        final name = args.string('name');
        if (!e.document.variables.any((v) => v.name == name)) {
          return McpToolResult.error('No variable "$name". Variables: ${e.document.variables.map((v) => v.name).join(', ')}.');
        }
        if (args.has('type')) e.setVariableType(name, mcpCheckType(args.string('type')));
        if (args.has('default')) e.setVariableDefault(name, args['default']);
        return McpToolResult.json(edited(e, {
          'variable': mcpVariableJson(e.document.variables.firstWhere((v) => v.name == name)),
        }));
      },
    ),
    McpTool(
      name: 'delete_anim_variable',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: false,
      removesContent: true,
      title: 'Delete Anim variable',
      description: 'Deletes a variable, its Get / Set nodes and their wires (one undo step).',
      inputSchema: McpSchema.object({'asset': assetArg, 'name': McpSchema.string('The variable.')}, required: ['asset', 'name']),
      handler: (args) async {
        final e = await editorFor(args);
        final name = args.string('name');
        if (!e.deleteVariable(name)) {
          return McpToolResult.error('No variable "$name". Variables: ${e.document.variables.map((v) => v.name).join(', ')}.');
        }
        return McpToolResult.json(edited(e, {'deleted': name}));
      },
    ),
    McpTool(
      name: 'compile_anim_blueprint',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: true,
      title: 'Compile Animation Blueprint',
      description: 'The editor\'s Compile: lumina\'s Anim Blueprint validator and Dart generator plus the check that '
          'every transition\'s Result is connected. A clean result is written to lib/anim/<abp>.dart, snake_case (ABP_Character → abp_character.dart). Returns the status '
          '(upToDate / warning / error) and the rows [{severity, message, graph, node_id, node_title}]; an error status '
          'is a tool error. save: true writes the .lmas afterwards.',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'save': McpSchema.boolean('Write the .lmas after compiling. Default false.'),
      }, required: ['asset']),
      handler: (args) async {
        final e = await editorFor(args);
        final ok = await e.compile();
        var saved = false;
        if (args.boolean('save')) saved = await e.save();
        final generated = 'lib/anim/${dartFileName(e.name)}';
        final data = <String, Object?>{
          'ok': ok,
          'status': e.compileStatus.name,
          'status_label': e.compileStatus.label,
          'compile_rows': rowsOf(e),
          'generated_file': generated,
          'generated_file_exists': e.projectDir != null && File('${e.projectDir}/$generated').existsSync(),
          'saved': saved,
          'is_dirty': e.isDirty,
        };
        return McpToolResult(McpToolResult.json(data).content,
            structuredContent: data, isError: e.compileStatus == BlueprintCompileStatus.error);
      },
    ),
    McpTool(
      name: 'anim_blueprint_preview',
      risk: McpToolRisk.editorState,
      groups: groups,
      idempotent: false,
      title: 'Anim Blueprint preview',
      description: 'Drives the Anim Preview Editor, which runs the Blueprint on its target mesh: the stand-in owner\'s '
          'speed (cm/s), direction (degrees, right positive) and falling state; variable overrides pinned to a value '
          '(the update graph no longer writes them) or cleared; then steps `frames` frames of 1/60 s (default 30). '
          'Returns the active state and clip. Changes what the tab shows, never the document.',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'speed': McpSchema.number('Owner ground speed in cm/s.'),
        'direction': McpSchema.number('Owner walk direction in degrees.'),
        'falling': McpSchema.boolean('Owner is falling.'),
        'overrides': {'type': 'object', 'description': '{variable: value} to pin.'},
        'clear_overrides': McpSchema.stringArray('Variables to unpin.'),
        'frames': McpSchema.integer('Frames of 1/60 s to step (default 30, at most 600).'),
      }, required: ['asset']),
      handler: (args) async {
        final e = await editorFor(args);
        final names = e.document.variables.map((v) => v.name).toSet();
        final overrides = args.optionalObject('overrides') ?? const {};
        for (final k in [...overrides.keys, if (args.has('clear_overrides')) ...args.stringList('clear_overrides')]) {
          if (!names.contains(k)) {
            return McpToolResult.error('No variable "$k". Variables: ${names.isEmpty ? 'none' : names.join(', ')}.');
          }
        }
        final frames = args.integer('frames', fallback: 30);
        if (frames < 0 || frames > 600) throw const JsonRpcException(JsonRpcErrorCode.invalidParams, 'frames must be 0..600');
        if (!e.preview.isAttached) e.startHeadlessPreview(ticker: false);
        e.setOwner(speed: args.optionalNumber('speed'), direction: args.optionalNumber('direction'), falling: args.has('falling') ? args.boolean('falling') : null);
        if (args.has('clear_overrides')) args.stringList('clear_overrides').forEach(e.clearOverride);
        overrides.forEach(e.setOverride);
        e.stepPreview(frames);
        return McpToolResult.json({
          'preview_state': e.previewState,
          'preview_clip': e.previewClip,
          'preview_error': e.previewError,
          'overrides': e.overrides,
          'owner': {'speed': e.ownerSpeed, 'direction': e.ownerDirection, 'falling': e.ownerFalling},
        });
      },
    ),
  ]);
}

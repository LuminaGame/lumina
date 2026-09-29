import 'package:lumina/lumina.dart' show AssetType;

import '../../main_editor/commands/editor_transaction.dart';
import '../../main_editor/view_models/editor_view_model.dart';
import '../../sub_editors/services/blueprint_asset_catalog.dart';
import '../../sub_editors/view_models/landscape_editor_view_model.dart';
import '../services/mcp_editor_sessions.dart';
import '../services/mcp_protocol.dart';
import '../services/mcp_tool.dart';

/// Undo state of [stack] as the tools report it: labels, who
/// made the steps, how many own steps are on top, and the recent history.
Map<String, Object?> mcpUndoState(TransactionManager stack) {
  final me = TransactionManager.currentOrigin?.sessionId;
  final history = stack.history();
  var agentDepth = 0;
  if (me != null) {
    for (final h in history) {
      if (h.origin.sessionId != me) break;
      agentDepth++;
    }
  }
  return {
    'can_undo': stack.canUndo,
    'undo_label': stack.canUndo ? stack.undoLabel : null,
    'undo_origin': stack.undoTopOrigin?.toJson(),
    'can_redo': stack.canRedo,
    'redo_label': stack.canRedo ? stack.redoLabel : null,
    'redo_origin': stack.redoTopOrigin?.toJson(),
    'agent_depth': agentDepth,
    'history': [for (final h in history) {'label': h.label, 'origin': h.origin.toJson()}],
  };
}

/// One undo stack the core tools act on: a [TransactionManager], or
/// the Landscape editor's own height / foliage stack.
abstract class _UndoStack {
  bool get isFrozen;
  bool get canUndo;
  bool get canRedo;
  String get undoLabel;
  String get redoLabel;
  TransactionOrigin? get undoTopOrigin;
  TransactionOrigin? get redoTopOrigin;
  void undo();
  void redo();
  Map<String, Object?> state();
}

class _ManagerStack implements _UndoStack {
  _ManagerStack(this.m);
  final TransactionManager m;
  @override
  bool get isFrozen => m.isFrozen;
  @override
  bool get canUndo => m.canUndo;
  @override
  bool get canRedo => m.canRedo;
  @override
  String get undoLabel => m.undoLabel;
  @override
  String get redoLabel => m.redoLabel;
  @override
  TransactionOrigin? get undoTopOrigin => m.undoTopOrigin;
  @override
  TransactionOrigin? get redoTopOrigin => m.redoTopOrigin;
  @override
  void undo() => m.undo();
  @override
  void redo() => m.redo();
  @override
  Map<String, Object?> state() => mcpUndoState(m);
}

/// The Landscape editor's stack: one entry per sculpt or foliage stroke,
/// each carrying who made it, so `scope: "agent"` works as on a manager.
class _LandscapeStack implements _UndoStack {
  _LandscapeStack(this.e);
  final LandscapeEditorViewModel e;
  @override
  bool get isFrozen => false;
  @override
  bool get canUndo => e.canUndo;
  @override
  bool get canRedo => e.canRedo;
  @override
  String get undoLabel => canUndo ? 'Undo ${e.undoLabel}' : 'Undo';
  @override
  String get redoLabel => canRedo ? 'Redo ${e.redoLabel}' : 'Redo';
  @override
  TransactionOrigin? get undoTopOrigin => e.undoTopOrigin;
  @override
  TransactionOrigin? get redoTopOrigin => e.redoTopOrigin;
  @override
  void undo() => e.undo();
  @override
  void redo() => e.redo();
  @override
  Map<String, Object?> state() {
    final me = TransactionManager.currentOrigin?.sessionId;
    final history = e.undoHistory;
    var agentDepth = 0;
    if (me != null) {
      for (final h in history) {
        if (h.origin.sessionId != me) break;
        agentDepth++;
      }
    }
    return {
      'can_undo': canUndo,
      'undo_label': canUndo ? undoLabel : null,
      'undo_origin': undoTopOrigin?.toJson(),
      'can_redo': canRedo,
      'redo_label': canRedo ? redoLabel : null,
      'redo_origin': redoTopOrigin?.toJson(),
      'agent_depth': agentDepth,
      'history': [for (final h in history.take(20)) {'label': h.label, 'origin': h.origin.toJson()}],
    };
  }
}

/// The tools every session lists (group `core`): the project,
/// undo / redo on the level or on a Blueprint / Material tab, and the tool
/// catalogue.
void registerCoreTools(
  McpToolRegistry registry,
  EditorViewModel vm,
  McpEditorSessions sessions, {
  required Set<String>? Function() activeGroups,
  required McpToolRisk Function() maxRisk,
}) {
  const units = 'Units: centimetres, degrees, Z up (the editor\'s authoring space, as the Details panel shows them).';
  const core = {McpToolGroups.core};

  final assetArg = McpSchema.string('A Blueprint, Widget Blueprint, Material, Animation Blueprint, Blend Space, Level '
      'Sequence, Landscape, Enumeration or Blueprint Interface asset (project-relative path or unique '
      'file name), or "level" / a level .lmas for its Level Blueprint: '
      'undo on its editor tab\'s own stack instead of the level\'s. The tab opens if needed.');
  // A Widget Blueprint and a material each have two stacks.
  final stackArg = McpSchema.string('With a Widget Blueprint or Material `asset`: "graph" acts on its node graph\'s '
      'stack (the widget\'s Blueprint graph; the material\'s node graph, whose undo restores the source too). '
      'Without it: the widget designer\'s stack, or the material source\'s.', enumValues: const ['graph']);
  final scopeArg = McpSchema.string('"any" (default) reverts whatever is on top; "agent" only a step this session '
      'made, and refuses otherwise.', enumValues: const ['any', 'agent']);

  /// The stack [args] target — a [TransactionManager], or
  /// the Landscape editor's own stack — and what to call it in messages.
  Future<(_UndoStack, String)> stackFor(McpArgs args) async {
    final wanted = args.optionalString('asset');
    if (wanted == null) return (_ManagerStack(vm.transactions), 'level');
    if (wanted == 'level') return (_ManagerStack((await sessions.blueprintEditor(wanted)).transactions), 'Level Blueprint');
    final asset = sessions.resolveAsset(wanted);
    final graph = args.optionalString('stack') == 'graph';
    (_UndoStack, String) of(TransactionManager m, [String? where]) => (_ManagerStack(m), where ?? asset.relativePath);
    if (sessions.isWidget(asset)) {
      final designer = await sessions.widget(asset);
      return graph ? of(designer.graphEditor.transactions, '${asset.relativePath} graph') : of(designer.transactions);
    }
    if (graph && asset.type != AssetType.filamat) {
      throw JsonRpcException(JsonRpcErrorCode.invalidParams,
          'stack "graph" is for a Widget Blueprint or a Material; ${asset.relativePath} is a ${asset.type.name}.');
    }
    switch (asset.type) {
      // An Enumeration and a Blueprint Interface are actor
      // assets with their own editors and stacks.
      case AssetType.actor when BlueprintAssetCatalog.isEnumLmas(asset.lmasPath):
        return of((await sessions.blueprintEnum(asset)).transactions);
      case AssetType.actor when BlueprintAssetCatalog.isInterfaceLmas(asset.lmasPath):
        return of((await sessions.blueprintInterface(asset)).transactions);
      case AssetType.actor:
        return of((await sessions.blueprint(asset)).transactions);
      case AssetType.filamat:
        final editor = await sessions.material(asset);
        if (!graph) return of(editor.transactions);
        editor.graph.ensureSynced();
        return of(editor.graph.transactions, '${asset.relativePath} graph');
      case AssetType.level:
        return of((await sessions.blueprintEditor(asset.relativePath)).transactions, 'Level Blueprint');
      // The Anim Blueprint, Blend Space and Sequencer tabs.
      case AssetType.animBlueprint:
        return of((await sessions.animBlueprint(asset)).transactions);
      case AssetType.blendSpace:
        return of((await sessions.blendSpace(asset)).transactions);
      case AssetType.sequencer:
        return of((await sessions.sequencer(asset)).transactions);
      // The landscape's stroke stack.
      case AssetType.landscape:
        return (_LandscapeStack(await sessions.landscape(asset)), asset.relativePath);
      default:
        throw JsonRpcException(JsonRpcErrorCode.invalidParams,
            '${asset.relativePath} is a ${asset.type.name}; only Blueprint, Level Blueprint, Widget Blueprint, Material, '
            'Animation Blueprint, Blend Space, Level Sequence, Landscape, Enumeration and Blueprint Interface tabs have '
            'their own undo stack (the Animation, Skeletal Mesh, Particle, Static Mesh, Texture, Physics Asset and Sound '
            'editors keep only a dirty flag: not saving is their revert).');
    }
  }

  String whose(TransactionOrigin o) => o.isAgent
      ? (o.sessionId == TransactionManager.currentOrigin?.sessionId ? 'yours' : "another agent's (${o.clientName}: ${o.tool})")
      : "the user's";

  /// Null when this session may revert the step, else the refusal.
  String? refuseForScope(McpArgs args, TransactionOrigin? top, String label, String where, String verb) {
    if ((args.optionalString('scope') ?? 'any') != 'agent' || top == null) return null;
    if (top.isAgent && top.sessionId == TransactionManager.currentOrigin?.sessionId) return null;
    final what = label.replaceFirst(RegExp(r'^(Undo|Redo) '), '');
    return 'The last $where edit is ${whose(top)} ($what); nothing of yours is on top. '
        'Pass scope: "any" to $verb it anyway.';
  }

  registry.registerAll([
    McpTool(
      name: 'project_info',
      title: 'Project info',
      risk: McpToolRisk.readOnly,
      groups: core,
      description: 'The open project: name, engine version, project directory, active level, units and axes, '
          'whether the level has unsaved changes, actor count and Play-In-Editor state. Call this first. $units',
      inputSchema: McpSchema.object(const {}),
      handler: (args) => McpToolResult.json({
        'project_name': vm.project.projectName,
        'engine_version': vm.engineVersion,
        'project_dir': vm.projectDirPath,
        'active_level': vm.project.activeLevel,
        'active_level_name': vm.activeLevelName,
        'world_units': 'cm',
        'up_axis': 'z',
        'is_dirty': vm.project.isDirty,
        'actor_count': vm.actorCount,
        'selected_actor_ids': vm.selectedActorIds.toList(),
        'pie': {'playing': vm.isPlaying, 'paused': vm.isPaused},
        'undo': mcpUndoState(vm.transactions),
      }),
    ),
    McpTool(
      name: 'undo',
      title: 'Undo',
      risk: McpToolRisk.mutating,
      groups: core,
      idempotent: false,
      description: 'Edit → Undo: reverts the last level edit, or with `asset` the last edit on that Blueprint, '
          'Widget Blueprint or Material tab (stack "graph": its node graph), or any asset tab with its own stack '
          '(see `asset`; a Landscape\'s steps are its strokes). Every edit call of an agent is one step labelled "MCP: …". scope "agent" refuses when '
          'the step on top is not this session\'s. Returns what was undone and who made it.',
      inputSchema: McpSchema.object({'scope': scopeArg, 'asset': assetArg, 'stack': stackArg}),
      handler: (args) async {
        final (stack, where) = await stackFor(args);
        if (stack.isFrozen) return McpToolResult.error('Undo is unavailable while Play runs; call stop_pie first.');
        if (!stack.canUndo) return McpToolResult.error(where == 'level' ? 'Nothing to undo.' : 'Nothing to undo on the $where stack.');
        final label = stack.undoLabel;
        final origin = stack.undoTopOrigin!;
        final refusal = refuseForScope(args, origin, label, where, 'undo');
        if (refusal != null) return McpToolResult.error(refusal);
        try {
          stack.undo();
        } on TransactionRefused catch (e) {
          return McpToolResult.error('Undo refused on the $where stack: ${e.message}.');
        }
        vm.notifyListeners();
        return McpToolResult.json({'undone': label, 'origin': origin.kind, 'undo': stack.state()});
      },
    ),
    McpTool(
      name: 'redo',
      title: 'Redo',
      risk: McpToolRisk.mutating,
      groups: core,
      idempotent: false,
      description: 'Edit → Redo: re-applies the last undone level edit, or with `asset` the last undone edit on '
          'that Blueprint, Widget Blueprint or Material tab (stack "graph": its node graph). scope "agent" refuses when that step is not this session\'s.',
      inputSchema: McpSchema.object({'scope': scopeArg, 'asset': assetArg, 'stack': stackArg}),
      handler: (args) async {
        final (stack, where) = await stackFor(args);
        if (stack.isFrozen) return McpToolResult.error('Redo is unavailable while Play runs; call stop_pie first.');
        if (!stack.canRedo) return McpToolResult.error(where == 'level' ? 'Nothing to redo.' : 'Nothing to redo on the $where stack.');
        final label = stack.redoLabel;
        final origin = stack.redoTopOrigin!;
        final refusal = refuseForScope(args, origin, label, where, 'redo');
        if (refusal != null) return McpToolResult.error(refusal);
        try {
          stack.redo();
        } on TransactionRefused catch (e) {
          return McpToolResult.error('Redo refused on the $where stack: ${e.message}.');
        }
        vm.notifyListeners();
        return McpToolResult.json({'redone': label, 'origin': origin.kind, 'undo': stack.state()});
      },
    ),
    McpTool(
      name: 'undo_state',
      title: 'Undo state',
      risk: McpToolRisk.readOnly,
      groups: core,
      description: 'Whether undo / redo are available on the level (or, with `asset`, a Blueprint / Material tab), '
          'what they would revert and who made it (undo_origin), how many of this session\'s steps are on top '
          '(agent_depth), and the recent history.',
      inputSchema: McpSchema.object({'asset': assetArg, 'stack': stackArg}),
      handler: (args) async {
        final (stack, _) = await stackFor(args);
        return McpToolResult.json(stack.state());
      },
    ),
    McpTool(
      name: 'list_tool_groups',
      title: 'List tool groups',
      risk: McpToolRisk.readOnly,
      groups: core,
      description: 'The tool groups (connect with /mcp?groups=a,b or pass tools/list params.groups to list only '
          'some), their tools and how many of each risk; this session\'s active groups and the editor\'s risk '
          'ceiling (tools above it are neither listed nor run).',
      inputSchema: McpSchema.object(const {}),
      handler: (args) {
        final byGroup = <String, List<McpTool>>{};
        for (final t in registry.tools) {
          for (final g in t.groups) {
            (byGroup[g] ??= []).add(t);
          }
        }
        final groups = byGroup.keys.toList()..sort();
        return McpToolResult.json({
          'groups': [
            for (final g in groups)
              {
                'group': g,
                'tools': [for (final t in byGroup[g]!) t.name],
                'risks': {
                  for (final r in McpToolRisk.values)
                    if (byGroup[g]!.any((t) => t.risk == r)) r.name: byGroup[g]!.where((t) => t.risk == r).length,
                },
              },
          ],
          'tool_count': registry.tools.length,
          'active_groups': (activeGroups()?.toList()?..sort()),
          'max_risk': maxRisk().name,
        });
      },
    ),
  ]);
}

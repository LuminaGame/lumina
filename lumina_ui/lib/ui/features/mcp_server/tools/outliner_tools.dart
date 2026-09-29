import '../../main_editor/view_models/editor_view_model.dart';
import '../services/mcp_protocol.dart';
import '../services/mcp_tool.dart';
import 'blueprint_tool_support.dart' show mcpRefuseWhilePlaying;
import 'core_tools.dart' show mcpUndoState;

/// The World Outliner as MCP tools: folders, Move to Folder,
/// attach (a drop on an actor row), detach and solo — over the view-model
/// methods the Outliner widget calls, each call one undo step. Renaming and
/// deleting a folder are `rename_actor` / `delete_actor` (a folder is an
/// actor of type "Folder").
void registerOutlinerTools(McpToolRegistry registry, EditorViewModel vm) {
  const outliner = {McpToolGroups.outliner};

  EditorActorNode nodeOrThrow(String id, {String what = 'actor'}) {
    final node = vm.actors.where((a) => a.id == id).firstOrNull;
    if (node == null) {
      throw JsonRpcException(JsonRpcErrorCode.invalidParams, 'No $what with id "$id". Call list_actors for the ids in the level.');
    }
    return node;
  }

  EditorActorNode? node(String? id) => id == null ? null : vm.actors.where((a) => a.id == id).firstOrNull;

  bool isAncestorOrSelf(String ancestorId, String? id) {
    for (var current = id; current != null; current = node(current)?.parentId) {
      if (current == ancestorId) return true;
    }
    return false;
  }

  /// The id among [ids] that already carries [id] along (its ancestor).
  String? carriedBy(String id, Set<String> ids) {
    for (var current = node(id)?.parentId; current != null; current = node(current)?.parentId) {
      if (ids.contains(current)) return current;
    }
    return null;
  }

  /// Why [id] cannot move into [target] (null: the root), or null when it can.
  String? moveRefusal(String id, String? target, Set<String> ids) {
    final n = node(id);
    if (n == null) return 'no actor with this id';
    final carrier = carriedBy(id, ids);
    if (carrier != null) return 'moves with its ancestor $carrier';
    if (n.parentId == target) return target == null ? 'already at the root' : 'already in that folder';
    if (target != null && isAncestorOrSelf(id, target)) return 'would create a cycle: the folder is inside it';
    return null;
  }

  /// Why [id] cannot be attached under actor [parentId], or null.
  String? attachRefusal(String id, String parentId, Set<String> ids) {
    final n = node(id);
    if (n == null) return 'no actor with this id';
    final carrier = carriedBy(id, ids);
    if (carrier != null) return 'moves with its ancestor $carrier';
    if (n.parentId == parentId) return 'already attached to it';
    if (n.type == 'Folder') return 'a folder lives under folders or the root; use move_to_folder';
    if (isAncestorOrSelf(id, parentId)) return 'would create a cycle: the parent is attached below it';
    if (!vm.canAttachToActor(id, parentId)) return 'the Outliner refuses this attach';
    return null;
  }

  void selectAndReveal(Iterable<String> ids) {
    if (ids.isEmpty) return;
    vm.clearSelection();
    vm.selectActors(ids.toList());
  }

  Map<String, Object?> summary(String id) {
    final n = node(id)!;
    return {'id': n.id, 'name': n.name, 'type': n.type, 'parent_id': n.parentId, 'location': n.location};
  }

  List<String> visibleIds() => [for (final a in vm.actors) if (a.isVisible) a.id];

  /// Moves [ids] into folder [target] (null: the root) as the Outliner's
  /// Move to Folder does.
  McpToolResult move(List<String> ids, String? target) {
    if (target != null && nodeOrThrow(target, what: 'folder').type != 'Folder') {
      return McpToolResult.error('"$target" is not a folder (it is a ${node(target)!.type}); attach_actors puts actors under an '
          'actor, move_to_folder under a Folder.');
    }
    final set = ids.toSet();
    final skipped = <Map<String, Object?>>[];
    final movable = <String>[];
    for (final id in ids) {
      final why = moveRefusal(id, target, set);
      why == null ? movable.add(id) : skipped.add({'id': id, 'reason': why});
    }
    if (movable.isNotEmpty) {
      vm.moveToFolder(movable, target);
      selectAndReveal(movable);
    }
    return McpToolResult.json({
      'moved': movable,
      'skipped': skipped,
      'folder_id': target,
      'actors': movable.map(summary).toList(),
      'undo': mcpUndoState(vm.transactions),
    });
  }

  registry.registerAll([
    McpTool(
      name: 'create_folder',
      risk: McpToolRisk.mutating,
      groups: outliner,
      idempotent: false,
      title: 'Create Outliner folder',
      description: 'Outliner → New Folder: a folder (an editor-only grouping node, type "Folder") in the root or in '
          'another folder, optionally wrapping actors (they move in and keep their world locations). The name is '
          'made unique among its siblings ("Props" → "Props_1"). One undo step; returns the folder id and its final '
          'name. Rename or delete a folder with rename_actor / delete_actor (keep_children keeps its contents).',
      inputSchema: McpSchema.object({
        'name': McpSchema.string('The folder name. Default "NewFolder".'),
        'parent_folder_id': McpSchema.string('A folder to create it in; default the root.'),
        'wrap_ids': McpSchema.stringArray('Actors (or folders) to move into the new folder.'),
      }),
      handler: (args) {
        final refusal = mcpRefuseWhilePlaying(vm);
        if (refusal != null) return refusal;
        final parent = args.optionalString('parent_folder_id');
        if (parent != null && nodeOrThrow(parent, what: 'folder').type != 'Folder') {
          return McpToolResult.error('"$parent" is not a folder; a folder lives in a folder or the root.');
        }
        final wrap = args.has('wrap_ids') ? args.stringList('wrap_ids') : const <String>[];
        for (final id in wrap) {
          nodeOrThrow(id);
        }
        final name = args.optionalString('name')?.trim();
        final id = vm.createFolder(name: (name == null || name.isEmpty) ? null : name, parentFolderId: parent, wrapIds: wrap);
        // The Outliner starts an inline rename for a user; the agent named it.
        vm.endOutlinerRename();
        final folder = node(id)!;
        final children = [for (final a in vm.actors) if (a.parentId == id) a.id];
        return McpToolResult.json({
          'folder_id': id,
          'name': folder.name,
          'parent_id': folder.parentId,
          'children': children,
          'skipped': [for (final w in wrap) if (!children.contains(w)) {'id': w, 'reason': 'not moved (carried by an ancestor, or a cycle)'}],
          'undo': mcpUndoState(vm.transactions),
        });
      },
    ),
    McpTool(
      name: 'move_to_folder',
      risk: McpToolRisk.mutating,
      groups: outliner,
      idempotent: true,
      title: 'Move to folder',
      description: 'The Outliner\'s "Move to Folder ▸ <folder> / (Root)": moves actors or folders into a folder (or '
          'the root when folder_id is omitted), keeping world locations, as one undo step. Returns moved and '
          'skipped [{id, reason}] (already there, carried by a moved ancestor, or a folder moved into itself). The '
          'moved nodes become the selection and the folder expands.',
      inputSchema: McpSchema.object({
        'ids': McpSchema.stringArray('The actor or folder ids.'),
        'folder_id': McpSchema.string('The target folder\'s id; omit for the root.'),
      }, required: ['ids']),
      handler: (args) => mcpRefuseWhilePlaying(vm) ?? move(args.stringList('ids'), args.optionalString('folder_id')),
    ),
    McpTool(
      name: 'attach_actors',
      risk: McpToolRisk.mutating,
      groups: outliner,
      idempotent: true,
      title: 'Attach actors',
      description: 'Attaches actors under another actor, as dropping them on its Outliner row does, in one undo step. '
          'Keeps each actor\'s world location only (its stored location becomes relative to the parent); rotation '
          'and scale are not composed, and there is no relative attach, because the editor has neither. Returns '
          'attached and skipped [{id, reason}]: a folder as the parent (use move_to_folder), a cycle, or already '
          'attached.',
      inputSchema: McpSchema.object({
        'ids': McpSchema.stringArray('The actors to attach.'),
        'parent_id': McpSchema.string('The actor to attach them to.'),
      }, required: ['ids', 'parent_id']),
      handler: (args) {
        final refusal = mcpRefuseWhilePlaying(vm);
        if (refusal != null) return refusal;
        final parentId = args.string('parent_id');
        final parent = nodeOrThrow(parentId);
        final ids = args.stringList('ids');
        final set = ids.toSet();
        final skipped = <Map<String, Object?>>[];
        final movable = <String>[];
        for (final id in ids) {
          final why = parent.type == 'Folder'
              ? 'the parent is a folder; use move_to_folder'
              : attachRefusal(id, parentId, set);
          why == null ? movable.add(id) : skipped.add({'id': id, 'reason': why});
        }
        if (movable.isNotEmpty) {
          vm.attachToActor(movable, parentId);
          selectAndReveal(movable);
        }
        return McpToolResult.json({
          'attached': movable,
          'skipped': skipped,
          'parent_id': parentId,
          'actors': movable.map(summary).toList(),
          'undo': mcpUndoState(vm.transactions),
        });
      },
    ),
    McpTool(
      name: 'detach_actors',
      risk: McpToolRisk.mutating,
      groups: outliner,
      idempotent: true,
      title: 'Detach actors',
      description: 'Detaches actors from their parent into the root or a folder: the Outliner\'s "Move to Folder ▸ '
          '(Root) / <folder>" (the UI has no separate Detach). Keeps world locations; one undo step. Returns moved '
          'and skipped [{id, reason}].',
      inputSchema: McpSchema.object({
        'ids': McpSchema.stringArray('The actors to detach.'),
        'folder_id': McpSchema.string('A folder to put them in; omit for the root.'),
      }, required: ['ids']),
      handler: (args) => mcpRefuseWhilePlaying(vm) ?? move(args.stringList('ids'), args.optionalString('folder_id')),
    ),
    McpTool(
      name: 'solo_actor',
      risk: McpToolRisk.mutating,
      groups: outliner,
      idempotent: true,
      title: 'Solo actor',
      description: 'Outliner → Solo: hides everything but the actor, its ancestors and its descendants. When a solo '
          'is already active it is cleared first (as a second click does), then the new actor is soloed. One undo '
          'step; clear_solo restores the exact visibility the solo replaced. Visibility is saved with the level. '
          'Returns solo_active and the ids left visible.',
      inputSchema: McpSchema.object({'id': McpSchema.string('The actor to solo.')}, required: ['id']),
      handler: (args) {
        final refusal = mcpRefuseWhilePlaying(vm);
        if (refusal != null) return refusal;
        final id = nodeOrThrow(args.string('id')).id;
        if (vm.isSoloActive) vm.toggleSoloWithTransaction(id);
        vm.toggleSoloWithTransaction(id);
        return McpToolResult.json({'solo_active': vm.isSoloActive, 'visible_ids': visibleIds(), 'undo': mcpUndoState(vm.transactions)});
      },
    ),
    McpTool(
      name: 'clear_solo',
      risk: McpToolRisk.mutating,
      groups: outliner,
      idempotent: false,
      title: 'Clear solo',
      description: 'Outliner → Clear Solo: restores the visibility of every actor exactly as it was before solo_actor. '
          'One undo step. A tool error when no solo is active.',
      inputSchema: McpSchema.object(const {}),
      handler: (args) {
        final refusal = mcpRefuseWhilePlaying(vm);
        if (refusal != null) return refusal;
        if (!vm.isSoloActive) return McpToolResult.error('No solo is active; solo_actor starts one.');
        vm.toggleSoloWithTransaction('');
        return McpToolResult.json({'solo_active': vm.isSoloActive, 'visible_ids': visibleIds(), 'undo': mcpUndoState(vm.transactions)});
      },
    ),
  ]);
}

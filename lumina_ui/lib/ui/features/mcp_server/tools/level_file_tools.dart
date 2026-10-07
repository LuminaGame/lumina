import 'dart:io';

import 'package:lumina_core/lumina_core.dart';

import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_protocol.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_tool.dart';
import 'package:lumina_ui/ui/features/mcp_server/tools/blueprint_tool_support.dart' show mcpRefuseWhilePlaying;
import 'package:lumina_ui/ui/features/mcp_server/tools/core_tools.dart' show mcpUndoState;

/// The `if_dirty` choices of the level-switching tools.
const List<String> kMcpIfDirtyChoices = ['refuse', 'save', 'discard'];

/// `if_dirty` for every tool that leaves the open level.
Map<String, Object?> mcpIfDirtySchema() => McpSchema.string(
      'What to do when the open level has unsaved changes: "refuse" (default: a tool error naming the level), '
      '"save" (Save Level first) or "discard" (drop them; reviewed as a destructive call).',
      enumValues: kMcpIfDirtyChoices,
    );

/// `open_level` / `open_asset_editor` with `if_dirty: "discard"` drops unsaved
/// work: the approval chain reviews such a call as destructive.
McpToolRisk? mcpDiscardRisk(Map<String, Object?> arguments) =>
    arguments['if_dirty'] == 'discard' ? McpToolRisk.destructive : null;

/// Leaves the open level only as a user would: a clean level
/// always; a dirty one per [ifDirty] — `refuse` (null) returns the tool
/// error, `save` saves it first, `discard` drops the changes. Returns null
/// when the level may be left.
Future<McpToolResult?> mcpLeaveLevel(EditorViewModel vm, String? ifDirty) async {
  if (!vm.project.isDirty) return null;
  switch (ifDirty ?? 'refuse') {
    case 'save':
      final ok = await vm.confirmLeavingLevel(ifDirty: UnsavedLevelChoice.save);
      return ok ? null : McpToolResult.error('Saving ${vm.project.activeLevel} failed; see the Output Log.');
    case 'discard':
      return null;
    default:
      return McpToolResult.error('${vm.project.activeLevel} has unsaved changes. Call save_level first, or pass '
          'if_dirty "save" (save them) or "discard" (drop them).');
  }
}

/// Level files as MCP tools: the levels File → Open Level
/// lists, the New Level templates, and creating and opening levels with a
/// guard for unsaved work — the UI's own `createLevelFromTemplate` and
/// `openLevelGuarded`.
void registerLevelFileTools(McpToolRegistry registry, EditorViewModel vm) {
  String nameOf(String path) {
    final file = path.split('/').last;
    return file.endsWith('.lmas') ? file.substring(0, file.length - 5) : file;
  }

  List<Map<String, Object?>> levels() => [
        for (final path in vm.levelFiles)
          {
            'path': path,
            'name': nameOf(path),
            'active': path == vm.project.activeLevel,
            if (path == vm.project.activeLevel) 'is_dirty': vm.project.isDirty,
          },
      ];

  registry.registerAll([
    McpTool(
      name: 'list_levels',
      risk: McpToolRisk.readOnly,
      groups: const {McpToolGroups.level},
      title: 'List levels',
      description: 'The project\'s levels, as File → Open Level lists them (contents/levels/*.lmas): path, name and '
          'whether it is the open level, plus is_dirty (unsaved changes) for the open one. Renaming or deleting a '
          'level is a Content Browser asset operation, not a level tool.',
      inputSchema: McpSchema.object(const {}),
      handler: (args) => McpToolResult.json({'active_level': vm.project.activeLevel, 'levels': levels()}),
    ),
    McpTool(
      name: 'list_level_templates',
      risk: McpToolRisk.readOnly,
      groups: const {McpToolGroups.level},
      title: 'List level templates',
      description: 'The templates File → New Level offers (new_level\'s template): id, title, what it seeds, how many '
          'actors and whether it enables World Partition.',
      inputSchema: McpSchema.object(const {}),
      handler: (args) => McpToolResult.json({
        'templates': [
          for (final t in LevelTemplateCatalog.all)
            {
              'id': t.id,
              'title': t.title,
              'description': t.description,
              'actor_count': t.levelActors.length,
              'world_partition': t.worldPartition != null,
            },
        ],
      }),
    ),
    McpTool(
      name: 'new_level',
      risk: McpToolRisk.mutating,
      groups: const {McpToolGroups.level},
      idempotent: false,
      riskForArguments: mcpDiscardRisk,
      title: 'New level',
      description: 'File → New Level: writes contents/levels/<name>.lmas from a template (list_level_templates; '
          'default "default") and opens it, as one undo step "New Level <name>" whose undo deletes the file and '
          'returns to the previous level. A name that already exists is refused (nothing is overwritten). Leaving '
          'an open level with unsaved changes follows if_dirty.',
      inputSchema: McpSchema.object({
        'name': McpSchema.string('The level name, e.g. "L_Yard" (no extension).'),
        'template': McpSchema.string('The template id: "empty", "default" (default) or "open_world".'),
        'if_dirty': mcpIfDirtySchema(),
      }, required: ['name']),
      handler: (args) async {
        final refusal = mcpRefuseWhilePlaying(vm);
        if (refusal != null) return refusal;
        final name = args.string('name').trim();
        if (name.isEmpty || !RegExp(r'^[A-Za-z0-9_\-]+$').hasMatch(name)) {
          return McpToolResult.error('"$name" is not a level name: use letters, digits, _ and - (no extension).');
        }
        final template = args.optionalString('template') ?? kDefaultLevelTemplateId;
        if (!LevelTemplateCatalog.all.any((t) => t.id == template)) {
          return McpToolResult.error(
              'Unknown template "$template". Templates: ${LevelTemplateCatalog.all.map((t) => t.id).join(', ')}.');
        }
        if (vm.levelNameTaken(name)) {
          return McpToolResult.error('contents/levels/$name.lmas already exists; open it with open_level, or pick '
              'another name.');
        }
        final leave = await mcpLeaveLevel(vm, args.optionalString('if_dirty'));
        if (leave != null) return leave;
        if (!await vm.createLevelFromTemplate(name, template)) {
          return McpToolResult.error('The level was not created; see the Output Log.');
        }
        vm.selectTab(0);
        final path = 'contents/levels/$name.lmas';
        return McpToolResult.json({
          'active_level': vm.project.activeLevel,
          'path': path,
          'exists': File('${vm.projectDirPath}/$path').existsSync(),
          'template': template,
          'actor_count': vm.actorCount,
          'undo': mcpUndoState(vm.transactions),
        });
      },
    ),
    McpTool(
      name: 'open_level',
      risk: McpToolRisk.mutating,
      groups: const {McpToolGroups.level},
      idempotent: true,
      riskForArguments: mcpDiscardRisk,
      title: 'Open level',
      description: 'File → Open Level: opens a level (a path or a name from list_levels) in the viewport, Outliner '
          'and title bar. The open level\'s unsaved changes follow if_dirty: "refuse" (default) is a tool error '
          'naming the level, "save" saves it first, "discard" drops them (a destructive call). Not an undo step.',
      inputSchema: McpSchema.object({
        'level': McpSchema.string('"contents/levels/L_Main.lmas" or "L_Main".'),
        'if_dirty': mcpIfDirtySchema(),
      }, required: ['level']),
      handler: (args) async {
        final refusal = mcpRefuseWhilePlaying(vm);
        if (refusal != null) return refusal;
        final wanted = args.string('level');
        final all = vm.levelFiles;
        final path = all.where((p) => p == wanted || nameOf(p) == wanted || p.split('/').last == wanted).firstOrNull;
        if (path == null) {
          return McpToolResult.error('No level "$wanted". Levels: ${all.map(nameOf).join(', ')} (list_levels).');
        }
        final wasDirty = vm.project.isDirty && path != vm.project.activeLevel;
        if (path != vm.project.activeLevel) {
          final leave = await mcpLeaveLevel(vm, args.optionalString('if_dirty'));
          if (leave != null) return leave;
          vm.switchLevel(path);
        }
        vm.selectTab(0);
        return McpToolResult.json({
          'active_level': vm.project.activeLevel,
          'left_unsaved_changes': wasDirty ? args.optionalString('if_dirty') : null,
          'actor_count': vm.actorCount,
          'is_dirty': vm.project.isDirty,
        });
      },
    ),
  ]);
}

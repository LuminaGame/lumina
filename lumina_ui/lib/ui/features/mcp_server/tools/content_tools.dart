import 'dart:io';

import 'package:lumina/lumina.dart';

import 'package:lumina_ui/ui/core/services/content_folders.dart';
import 'package:lumina_ui/ui/features/main_editor/commands/editor_transaction.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/import_asset_folder_dialog.dart' show importFolderTargetError;
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_editor_sessions.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_jobs.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_protocol.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_tool.dart';
import 'package:lumina_ui/ui/features/mcp_server/tools/blueprint_tool_support.dart' show mcpRefuseWhilePlaying;

/// The Content Browser folder tile's rename error (content_browser_folder_tile).
const String kMcpFolderNameError = 'That name is empty, invalid or already taken.';

/// [raw] as a project-relative Content Browser folder: `contents` or a
/// folder under it (`Props` → `contents/Props`). Anything absolute, climbing
/// out or outside `contents/` is `-32602`.
String mcpContentFolder(String raw, {String argument = 'folder'}) {
  final trimmed = raw.trim().replaceAll(r'\', '/');
  if (trimmed.startsWith('/') || RegExp(r'^[A-Za-z]:').hasMatch(trimmed)) {
    throw JsonRpcException(JsonRpcErrorCode.invalidParams,
        '"$argument" must be a project folder under contents/ (e.g. "contents/Props"), not the absolute path "$raw".');
  }
  var f = trimmed.replaceAll(RegExp(r'/+$'), '');
  if (f.isEmpty) f = 'contents';
  if (f != 'contents' && !f.startsWith('contents/')) f = 'contents/$f';
  if (f.split('/').any((s) => s.isEmpty || s == '.' || s == '..')) {
    throw JsonRpcException(JsonRpcErrorCode.invalidParams, '"$argument" "$raw" is not a valid folder under contents/.');
  }
  return f;
}

/// The Content Browser's organisation work as MCP tools (group
/// `content`): the folder tree, New / Rename / Delete folder (to the
/// trash), the drag-to-folder move, asset Rename / Duplicate, collections,
/// Regenerate Thumbnail and File → Import Asset Folder as a job. Every tool
/// shows its result in the Content Browser, as the user's action would.
void registerContentTools(McpToolRegistry registry, EditorViewModel vm, McpEditorSessions sessions, McpJobRegistry jobs) {
  const content = {McpToolGroups.content};

  String rel(String path) {
    final norm = path.replaceAll(r'\', '/');
    final root = '${vm.projectDirPath.replaceAll(r'\', '/')}/';
    return norm.startsWith(root) ? norm.substring(root.length) : norm;
  }

  String parentOf(String path) => ContentFolders.parentOf(path);

  /// Shows [folder] in the Content Browser (the level tab and the browser
  /// come to the front), so the user sees what the agent did.
  void reveal(String folder) {
    vm.showRecentlyModified = false;
    vm.activeCollection = null;
    vm.selectedFolder = folder;
    vm.expandFolderAncestors(folder);
  }

  RealAssetInfo? assetAt(String relativePath) => vm.realAssets.where((a) => a.relativePath == relativePath).firstOrNull;

  /// The level settings naming [levelPath] (the level tools hand level moves
  /// here; set_project_settings owns every manifest write).
  List<String> mapWarnings(String levelPath, String newPath) {
    final m = vm.project.mapsAndModes;
    return [
      if (m.editorStartupMap == levelPath)
        'maps_and_modes.editor_startup_map still names $levelPath; call set_project_settings '
            '{"changes": {"maps_and_modes.editor_startup_map": "$newPath"}} then apply_project_settings.',
      if (m.gameDefaultMap == levelPath)
        'maps_and_modes.game_default_map still names $levelPath; call set_project_settings '
            '{"changes": {"maps_and_modes.game_default_map": "$newPath"}} then apply_project_settings.',
    ];
  }

  McpToolResult? refuseActiveLevel(RealAssetInfo asset, String verb) {
    if (asset.type == AssetType.level && asset.relativePath == vm.project.activeLevel) {
      return McpToolResult.error('${asset.relativePath} is the open level: it cannot be ${verb}d while open. '
          'Open another level first (open_level), then $verb it.');
    }
    return null;
  }

  /// One undo step that restores `contents/.collections.json` to [before].
  void recordCollectionsUndo(String label, String? before) {
    final file = File('${vm.projectDirPath}/contents/.collections.json');
    final after = file.existsSync() ? file.readAsStringSync() : null;
    void write(String? text) {
      if (text == null) {
        if (file.existsSync()) file.deleteSync();
      } else {
        file.writeAsStringSync(text);
      }
      vm.loadCollections();
    }

    vm.transactions.record(EditorTransaction(label: label, undo: () => write(before), redo: () => write(after)));
  }

  String? collectionsText() {
    final file = File('${vm.projectDirPath}/contents/.collections.json');
    return file.existsSync() ? file.readAsStringSync() : null;
  }

  Collection collectionNamed(String name) {
    final hit = vm.collections.where((c) => c.name == name).firstOrNull;
    if (hit == null) {
      throw JsonRpcException(JsonRpcErrorCode.invalidParams,
          'No collection "$name". Collections: ${vm.collections.map((c) => c.name).join(', ')} (list_collections).');
    }
    return hit;
  }

  /// [raw] assets resolved like every asset argument, each with an id.
  List<RealAssetInfo> withIds(List<String> raw) {
    final resolved = [for (final r in raw) sessions.resolveAsset(r)];
    final missing = [for (final a in resolved) if (a.assetId == null || a.assetId!.isEmpty) a.relativePath];
    if (missing.isNotEmpty) {
      throw JsonRpcException(JsonRpcErrorCode.invalidParams,
          'These assets have no asset_id (a legacy import), so a collection cannot hold them: ${missing.join(', ')}. '
          'Re-import them first.');
    }
    return resolved;
  }

  final policies = [for (final c in ImportConflictPolicy.values) c.name];

  registry.registerAll([
    McpTool(
      name: 'list_content_folders',
      risk: McpToolRisk.readOnly,
      groups: content,
      title: 'List content folders',
      description: 'The Content Browser\'s Sources tree under `under` (default "contents"): '
          '{path, name, asset_count (assets directly in it), total_assets (with subfolders), favorite, children[]}; '
          'plus plugin content roots (enabled content-only plugins) as absolute paths.',
      inputSchema: McpSchema.object({
        'under': McpSchema.string('The folder to list from, e.g. "contents/Props"; default "contents".'),
      }),
      handler: (args) {
        final under = mcpContentFolder(args.optionalString('under') ?? 'contents', argument: 'under');
        final all = vm.sourceFolders;
        final project = all.where((f) => f == 'contents' || f.startsWith('contents/')).toSet();
        if (!project.contains(under)) {
          return McpToolResult.error('No folder $under. Call list_content_folders for the tree.');
        }
        final assetsByFolder = <String, int>{};
        for (final a in vm.realAssets) {
          final parent = parentOf(a.relativePath.replaceAll(r'\', '/'));
          assetsByFolder[parent] = (assetsByFolder[parent] ?? 0) + 1;
        }
        Map<String, Object?> node(String path) {
          final children = project.where((f) => f != path && parentOf(f) == path).toList()..sort();
          final kids = [for (final c in children) node(c)];
          return {
            'path': path,
            'name': path.split('/').last,
            'asset_count': assetsByFolder[path] ?? 0,
            'total_assets': (assetsByFolder[path] ?? 0) + kids.fold<int>(0, (n, k) => n + (k['total_assets'] as int)),
            'favorite': vm.favoriteFolders.contains(path),
            'children': kids,
          };
        }

        return McpToolResult.json({
          'folders': [node(under)],
          'plugin_content_roots': [for (final f in all) if (!project.contains(f)) f],
          'selected_folder': vm.selectedFolder,
        });
      },
    ),
    McpTool(
      name: 'create_content_folder',
      risk: McpToolRisk.mutating,
      groups: content,
      idempotent: false,
      title: 'Create content folder',
      description: 'Content Browser → New Folder: creates `name` under `parent` (with its keep-marker). A taken name gets '
          'a `_1`, `_2`… suffix, as the dialog does; returns the path made. The browser shows the parent. One undo step.',
      inputSchema: McpSchema.object({
        'parent': McpSchema.string('The parent folder, "contents" or a folder under it.'),
        'name': McpSchema.string('The new folder\'s name (no slashes).'),
      }, required: ['parent', 'name']),
      handler: (args) {
        final parent = mcpContentFolder(args.string('parent'), argument: 'parent');
        final name = args.string('name').trim();
        if (name.isEmpty || name.contains('/') || name.contains(r'\') || name == '.' || name == '..') {
          throw const JsonRpcException(JsonRpcErrorCode.invalidParams, '"name" must be a plain folder name without slashes.');
        }
        if (!Directory('${vm.projectDirPath}/$parent').existsSync()) {
          return McpToolResult.error('No folder $parent. Create it first (create_content_folder) or pick one from '
              'list_content_folders.');
        }
        final made = vm.createContentFolder(parent, name);
        reveal(parent);
        final dir = '${vm.projectDirPath}/$made';
        vm.transactions.record(EditorTransaction(
          label: 'New Folder ${made.split('/').last}',
          undo: () {
            final d = Directory(dir);
            // Only the folder this call made, while it holds just its marker.
            if (d.existsSync() && d.listSync(recursive: true).every((e) => e is File && e.path.endsWith(ContentFolders.markerFileName))) {
              d.deleteSync(recursive: true);
            }
            vm.refreshAssets();
          },
          redo: () {
            ContentFolders.writeMarker((Directory(dir)..createSync(recursive: true)).path);
            vm.refreshAssets();
          },
        ));
        return McpToolResult.json({'path': made, 'selected_folder': vm.selectedFolder});
      },
    ),
    McpTool(
      name: 'rename_content_folder',
      risk: McpToolRisk.mutating,
      groups: content,
      idempotent: false,
      title: 'Rename content folder',
      description: 'Content Browser → Rename folder: renames `folder` to `new_name`; every reference to an asset inside '
          'follows, and the browser\'s selection, favourites and the open level\'s path move with it. The contents root '
          'cannot be renamed. One undo step.',
      inputSchema: McpSchema.object({
        'folder': McpSchema.string('The folder to rename, e.g. "contents/Props".'),
        'new_name': McpSchema.string('The new name (no slashes).'),
      }, required: ['folder', 'new_name']),
      handler: (args) {
        final folder = mcpContentFolder(args.string('folder'));
        if (folder == 'contents') return McpToolResult.error('The contents root cannot be renamed.');
        if (!Directory('${vm.projectDirPath}/$folder').existsSync()) {
          return McpToolResult.error('No folder $folder. Call list_content_folders for the tree.');
        }
        final refusal = mcpRefuseWhilePlaying(vm);
        if (refusal != null) return refusal;
        reveal(folder);
        final oldName = folder.split('/').last;
        final target = vm.renameContentFolder(folder, args.string('new_name'));
        if (target == null) return McpToolResult.error('Cannot rename $folder to "${args.string('new_name')}": $kMcpFolderNameError');
        if (target != folder) {
          vm.transactions.record(EditorTransaction(
            label: 'Rename Folder $oldName',
            undo: () => vm.renameContentFolder(target, oldName),
            redo: () => vm.renameContentFolder(folder, target.split('/').last),
          ));
        }
        return McpToolResult.json({'path': target, 'selected_folder': vm.selectedFolder});
      },
    ),
    McpTool(
      name: 'delete_content_folder',
      risk: McpToolRisk.destructive,
      groups: content,
      wraps: const {'EditorViewModel.deleteContentFolderToTrash'},
      title: 'Delete content folder',
      description: 'Deletes a Content Browser folder and everything in it to the project trash (.lumina/trash/<trash_id>): '
          'its assets (level actors that use them are removed), keep-markers and companions. One undo step: undo '
          'brings back the folder, the assets and the actors with their ids; restore_asset({trash_id}) later. The '
          'contents root and a folder holding the open level are refused.',
      inputSchema: McpSchema.object({
        'folder': McpSchema.string('The folder to delete, e.g. "contents/Props/Old".'),
      }, required: ['folder']),
      handler: (args) async {
        final folder = mcpContentFolder(args.string('folder'));
        if (folder == 'contents') return McpToolResult.error('The contents root cannot be deleted; name a folder under it.');
        final refusal = mcpRefuseWhilePlaying(vm);
        if (refusal != null) return refusal;
        try {
          final (:entry, :removed, :assets) = await vm.deleteContentFolderToTrash(folder);
          reveal(parentOf(folder));
          return McpToolResult.json({
            'deleted': folder,
            'trash_id': entry.id,
            'trashed_assets': assets,
            'trashed_files': [for (final f in entry.files) f.original],
            'removed_actors': [for (final a in removed) {'id': a.id, 'name': a.name}],
            'exists': Directory('${vm.projectDirPath}/$folder').existsSync(),
          });
        } on ArgumentError catch (e) {
          return McpToolResult.error('Cannot delete $folder: ${e.message}');
        }
      },
    ),
    McpTool(
      name: 'move_asset',
      risk: McpToolRisk.mutating,
      groups: content,
      idempotent: false,
      title: 'Move asset',
      description: 'Moves an asset into a Content Browser folder, as dragging its tile onto the folder does: the .lmas '
          'moves (the folder is created when missing) and references to it are rewritten. The open level cannot be '
          'moved ("Open another level first"); a level named by editor_startup_map / game_default_map moves with '
          'warnings[] naming the setting to update. One undo step.',
      inputSchema: McpSchema.object({
        'asset': McpSchema.string('The asset\'s project-relative path (list_assets), or its file name when unique.'),
        'folder': McpSchema.string('The target folder, e.g. "contents/Props".'),
      }, required: ['asset', 'folder']),
      handler: (args) async {
        final asset = sessions.resolveAsset(args.string('asset'));
        final folder = mcpContentFolder(args.string('folder'));
        final refusal = refuseActiveLevel(asset, 'move') ?? mcpRefuseWhilePlaying(vm);
        if (refusal != null) return refusal;
        final from = parentOf(asset.relativePath);
        if (from == folder) return McpToolResult.error('${asset.relativePath} is already in $folder.');
        final target = '$folder/${asset.fileName}';
        if (File('${vm.projectDirPath}/$target').existsSync()) {
          return McpToolResult.error('$target already exists; rename one of them first (rename_asset).');
        }
        final warnings = asset.type == AssetType.level ? mapWarnings(asset.relativePath, target) : const <String>[];
        await vm.moveAssetToFolder(asset, folder);
        reveal(folder);
        vm.transactions.record(EditorTransaction(
          label: 'Move ${asset.fileName}',
          undo: () {
            final moved = assetAt(target);
            if (moved != null) vm.moveAssetToFolder(moved, from);
          },
          redo: () {
            final back = assetAt(asset.relativePath);
            if (back != null) vm.moveAssetToFolder(back, folder);
          },
        ));
        final now = assetAt(target);
        return McpToolResult.json({
          'from': asset.relativePath,
          'path': target,
          'asset_id': now?.assetId ?? asset.assetId,
          'warnings': warnings,
        });
      },
    ),
    McpTool(
      name: 'rename_asset',
      risk: McpToolRisk.mutating,
      groups: content,
      idempotent: false,
      title: 'Rename asset',
      description: 'Content Browser → Rename (F2): renames the .lmas (and its companions) in place; the asset keeps its '
          'asset_id, the assets and placed actors that reference it follow. Names use letters, digits and underscores. '
          'The open level cannot be renamed ("Open another level first"). One undo step.',
      inputSchema: McpSchema.object({
        'asset': McpSchema.string('The asset\'s project-relative path, or its file name when unique.'),
        'new_name': McpSchema.string('The new name without extension, e.g. "SM_Barrel_Red".'),
      }, required: ['asset', 'new_name']),
      handler: (args) async {
        final asset = sessions.resolveAsset(args.string('asset'));
        final refusal = refuseActiveLevel(asset, 'rename') ?? mcpRefuseWhilePlaying(vm);
        if (refusal != null) return refusal;
        final newName = args.string('new_name').trim();
        final abs = asset.lmasPath ?? '${vm.projectDirPath}/${asset.relativePath}';
        final oldName = asset.fileName.replaceAll(RegExp(r'\.lmas$'), '');
        final folder = parentOf(asset.relativePath);
        final target = '$folder/$newName.lmas';
        final warnings = asset.type == AssetType.level ? mapWarnings(asset.relativePath, target) : const <String>[];
        final error = vm.renameAsset(abs, newName);
        if (error != null) return McpToolResult.error('Cannot rename ${asset.relativePath}: $error');
        reveal(folder);
        if (newName != oldName) {
          vm.transactions.record(EditorTransaction(
            label: 'Rename ${asset.fileName}',
            undo: () => vm.renameAsset('${vm.projectDirPath}/$target', oldName),
            redo: () => vm.renameAsset(abs, newName),
          ));
        }
        final now = assetAt(target);
        return McpToolResult.json({
          'from': asset.relativePath,
          'path': target,
          'asset_id': now?.assetId ?? asset.assetId,
          'warnings': warnings,
        });
      },
    ),
    McpTool(
      name: 'duplicate_asset',
      risk: McpToolRisk.mutating,
      groups: content,
      idempotent: false,
      title: 'Duplicate asset',
      description: 'Content Browser → Duplicate (Ctrl+D): copies the asset beside the original as <name>_1 (_2, …) with '
          'a fresh asset_id. One undo step: undo moves the copy to the project trash.',
      inputSchema: McpSchema.object({
        'asset': McpSchema.string('The asset\'s project-relative path, or its file name when unique.'),
      }, required: ['asset']),
      handler: (args) async {
        final asset = sessions.resolveAsset(args.string('asset'));
        final before = vm.contentsSnapshot();
        final known = {for (final a in vm.realAssets) a.relativePath};
        vm.duplicateAsset(asset.lmasPath ?? '${vm.projectDirPath}/${asset.relativePath}');
        final created = vm.filesCreatedSince(before);
        vm.recordCreatedFilesUndo(created, 'Duplicate ${asset.fileName}');
        final copy = vm.realAssets.where((a) => !known.contains(a.relativePath) && a.type == asset.type).firstOrNull;
        if (copy == null) return McpToolResult.error('Duplicating ${asset.relativePath} produced no asset; see the Output Log.');
        reveal(parentOf(copy.relativePath));
        return McpToolResult.json({'from': asset.relativePath, 'path': copy.relativePath, 'asset_id': copy.assetId, 'created_files': created});
      },
    ),
    McpTool(
      name: 'list_collections',
      risk: McpToolRisk.readOnly,
      groups: content,
      title: 'List collections',
      description: 'The Content Browser\'s collections (contents/.collections.json): {name, assets[{asset_id, path}]}.',
      inputSchema: McpSchema.object(const {}),
      handler: (args) async {
        await vm.loadCollections();
        return McpToolResult.json({
          'collections': [
            for (final c in vm.collections)
              {
                'name': c.name,
                'assets': [for (final a in c.assets) {'asset_id': a.assetId, 'path': a.assetPath}],
              },
          ],
        });
      },
    ),
    McpTool(
      name: 'create_collection',
      risk: McpToolRisk.mutating,
      groups: content,
      idempotent: false,
      title: 'Create collection',
      description: 'Content Browser → Collections → +: a new, empty collection. A name in use is refused. One undo step.',
      inputSchema: McpSchema.object({'name': McpSchema.string('The collection\'s name, e.g. "Hero Props".')}, required: ['name']),
      handler: (args) async {
        final name = args.string('name').trim();
        if (name.isEmpty) throw const JsonRpcException(JsonRpcErrorCode.invalidParams, '"name" must not be empty.');
        await vm.loadCollections();
        if (vm.collections.any((c) => c.name == name)) return McpToolResult.error('A collection "$name" already exists.');
        final before = collectionsText();
        vm.createCollection(name);
        recordCollectionsUndo('New Collection $name', before);
        return McpToolResult.json({'name': name, 'collections': vm.collections.map((c) => c.name).toList()});
      },
    ),
    McpTool(
      name: 'delete_collection',
      risk: McpToolRisk.mutating,
      groups: content,
      removesContent: true,
      title: 'Delete collection',
      description: 'Removes a collection (the list only; its assets stay). One undo step.',
      inputSchema: McpSchema.object({'name': McpSchema.string('The collection\'s name.')}, required: ['name']),
      handler: (args) async {
        await vm.loadCollections();
        final c = collectionNamed(args.string('name'));
        final before = collectionsText();
        vm.deleteCollection(c.name);
        recordCollectionsUndo('Delete Collection ${c.name}', before);
        return McpToolResult.json({'deleted': c.name, 'collections': vm.collections.map((c) => c.name).toList()});
      },
    ),
    McpTool(
      name: 'add_to_collection',
      risk: McpToolRisk.mutating,
      groups: content,
      idempotent: true,
      title: 'Add to collection',
      description: 'Adds assets to a collection by their asset_id (an asset already in it stays once). One undo step.',
      inputSchema: McpSchema.object({
        'collection': McpSchema.string('The collection\'s name.'),
        'assets': McpSchema.stringArray('Project-relative asset paths (or unique file names).'),
      }, required: ['collection', 'assets']),
      handler: (args) async {
        await vm.loadCollections();
        final c = collectionNamed(args.string('collection'));
        final assets = withIds(args.stringList('assets'));
        final before = collectionsText();
        for (final a in assets) {
          vm.addToCollection(c.name, a.assetId!);
        }
        recordCollectionsUndo('Add to Collection ${c.name}', before);
        final now = collectionNamed(c.name);
        return McpToolResult.json({
          'collection': c.name,
          'count': now.assets.length,
          'assets': [for (final a in now.assets) {'asset_id': a.assetId, 'path': a.assetPath}],
        });
      },
    ),
    McpTool(
      name: 'remove_from_collection',
      risk: McpToolRisk.mutating,
      groups: content,
      idempotent: true,
      title: 'Remove from collection',
      description: 'Removes assets from a collection (the assets themselves stay). One undo step.',
      inputSchema: McpSchema.object({
        'collection': McpSchema.string('The collection\'s name.'),
        'assets': McpSchema.stringArray('Project-relative asset paths (or unique file names).'),
      }, required: ['collection', 'assets']),
      handler: (args) async {
        await vm.loadCollections();
        final c = collectionNamed(args.string('collection'));
        final assets = withIds(args.stringList('assets'));
        final before = collectionsText();
        for (final a in assets) {
          vm.removeFromCollection(c.name, a.assetId!);
        }
        recordCollectionsUndo('Remove from Collection ${c.name}', before);
        final now = collectionNamed(c.name);
        return McpToolResult.json({
          'collection': c.name,
          'count': now.assets.length,
          'assets': [for (final a in now.assets) {'asset_id': a.assetId, 'path': a.assetPath}],
        });
      },
    ),
    McpTool(
      name: 'regenerate_thumbnails',
      risk: McpToolRisk.mutating,
      groups: content,
      idempotent: true,
      title: 'Regenerate thumbnails',
      description: 'Content Browser → Regenerate Thumbnail for each asset: queued on the offscreen thumbnail renderer '
          '(Filament), which re-embeds the PNG in the .lmas (png_path; no sidecar file). Returns at once; the tiles '
          'update as each lands.',
      inputSchema: McpSchema.object({
        'assets': McpSchema.stringArray('Project-relative asset paths (or unique file names).'),
      }, required: ['assets']),
      handler: (args) {
        final assets = [for (final r in args.stringList('assets')) sessions.resolveAsset(r)];
        final queued = <Map<String, Object?>>[];
        for (final a in assets) {
          final lmas = a.lmasPath ?? '${vm.projectDirPath}/${a.relativePath}';
          vm.regenerateThumbnail(lmas);
          queued.add({'asset': a.relativePath, 'png_path': rel(lmas), 'embedded': true});
        }
        return McpToolResult.json({'queued': queued.length, 'thumbnails': queued, 'queue_length': vm.thumbnailQueueLength});
      },
    ),
    McpTool(
      name: 'import_asset_folder',
      risk: McpToolRisk.mutating,
      groups: content,
      idempotent: false,
      openWorld: true,
      title: 'Import asset folder',
      description: 'File → Import Asset Folder…: walks a folder on disk (any path) for everything the import pipeline '
          'takes (meshes with their companions, textures, sounds), then imports it on the background import queue as a '
          'job (kind import_folder; wait_job / cancel_job — cancel stops after the files in progress). Options as in the '
          'dialog: target_folder (default "contents"), mirror_folder_structure (subfolders of `path` are recreated under '
          'the target), conflict_policy skip|overwrite|rename, auto_organize (sort by type instead), generate_lods. '
          'Call it with dry_run: true first on an unknown folder: it returns the plan and imports nothing.',
      inputSchema: McpSchema.object({
        'path': McpSchema.string('The absolute folder to import.'),
        'target_folder': McpSchema.string('The Content Browser folder the tree lands in; default "contents".'),
        'mirror_folder_structure': McpSchema.boolean('Recreate the source subfolders under the target. Default true.'),
        'conflict_policy': McpSchema.string('What to do with an asset that exists: skip (default), overwrite (re-import, '
            'keeps its id), rename (import as name_1).', enumValues: policies),
        'auto_organize': McpSchema.boolean('Sort into contents/meshes, contents/textures, … by type. Default false.'),
        'generate_lods': McpSchema.boolean('Generate levels of detail for meshes. Default false.'),
        'dry_run': McpSchema.boolean('Return the plan only. Default false.'),
      }, required: ['path']),
      handler: (args) async {
        final path = args.string('path');
        final target = args.optionalString('target_folder') ?? 'contents';
        final targetError = importFolderTargetError(target);
        if (targetError != null) throw JsonRpcException(JsonRpcErrorCode.invalidParams, '$targetError (got "$target").');
        if (!Directory(path).existsSync()) return McpToolResult.error('No folder at "$path".');
        final options = ImportFolderOptions(
          targetFolder: ImportFolderPlan.normalizeFolder(target),
          mirrorFolderStructure: args.boolean('mirror_folder_structure', fallback: true),
          conflictPolicy: ImportConflictPolicy.values.byName(args.optionalString('conflict_policy') ?? 'skip'),
          autoOrganize: args.boolean('auto_organize'),
          generateLods: args.boolean('generate_lods'),
        );
        final ImportFolderScan scan;
        try {
          scan = await ImportFolderScanner.scanInBackground(path);
        } catch (e) {
          return McpToolResult.error('Cannot read $path: $e');
        }
        final plan = ImportFolderPlan.build(scan, projectPath: vm.projectDirPath, options: options);
        final counts = <String, int>{};
        for (final i in plan.imports) {
          counts[i.file.kind.name] = (counts[i.file.kind.name] ?? 0) + 1;
        }
        final planJson = {
          'root': scan.root,
          'imports': [for (final i in plan.imports) {'source': i.file.relativePath, 'target': i.targetPath, 'conflict': i.conflicted}],
          'skipped_existing': [for (final f in plan.skippedExisting) f.relativePath],
          'unsupported': [for (final s in scan.skipped) {'path': s.relativePath, 'reason': s.reason}],
          'counts': counts,
          'total_bytes': scan.totalBytes,
        };
        if (args.boolean('dry_run')) return McpToolResult.json({'dry_run': true, ...planJson});
        if (vm.isBatchImporting) {
          return McpToolResult.error('An import is already running (the import panel); wait for it or cancel_job its job first.');
        }
        final job = jobs.start(
          'import_folder',
          title: 'Import Asset Folder ${scan.root.split(RegExp(r'[\\/]')).last} → ${options.autoOrganize ? 'auto-organized' : options.targetFolder}',
          exclusive: 'import_queue',
          cancel: () => vm.importJobs.cancel(),
          run: (job) async {
            final panel = vm.importJobs;
            var logged = <int>{};
            void follow() {
              job.update(progress: panel.overallFraction, stage: panel.headline);
              for (final r in panel.rows) {
                if (r.stage.isTerminal && logged.add(r.index)) {
                  job.addLog('${r.request.fileName}: ${r.stage.name}${r.error == null ? '' : ' — ${r.error}'}',
                      level: r.stage == ImportStage.failed ? 'error' : (r.stage == ImportStage.cancelled ? 'warning' : 'info'),
                      source: 'Import');
                }
              }
            }

            panel.addListener(follow);
            try {
              final results = await vm.importAssetFolder(scan, options);
              follow();
              logged = {};
              return {
                'imported': results.where((r) => r.stage == ImportStage.done).length,
                'failed': [
                  for (final r in results.where((r) => r.stage == ImportStage.failed)) {'file': r.request.fileName, 'error': r.error},
                ],
                'cancelled': results.where((r) => r.stage == ImportStage.cancelled).length,
                'skipped': plan.skippedExisting.length,
                'target_folder': options.autoOrganize ? null : options.targetFolder,
              };
            } finally {
              panel.removeListener(follow);
            }
          },
        );
        return McpToolResult.json({'job_id': job.id, 'state': job.state.name, 'planned': plan.imports.length, ...planJson});
      },
    ),
  ]);
}

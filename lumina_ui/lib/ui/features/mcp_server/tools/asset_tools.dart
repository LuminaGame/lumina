import 'dart:io';

import 'package:lumina/lumina.dart';

import '../../main_editor/services/project_trash.dart' show TrashConflict;
import '../../main_editor/view_models/editor_view_model.dart';
import '../../sub_editors/services/anim_graph_asset_service.dart';
import '../../sub_editors/services/blueprint_asset_catalog.dart';
import '../../sub_editors/services/landscape_asset_service.dart';
import '../../sub_editors/view_models/animation_editor_view_model.dart';
import '../../sub_editors/view_models/blueprint_editor_view_model.dart';
import '../../sub_editors/view_models/material_editor_view_model.dart';
import '../../sub_editors/view_models/particle_editor_view_model.dart';
import '../../sub_editors/view_models/sequencer_view_model.dart';
import '../services/mcp_editor_sessions.dart';
import '../services/mcp_protocol.dart';
import '../services/mcp_tool.dart';
import 'blueprint_tool_support.dart' show mcpRefuseWhilePlaying;
import 'level_file_tools.dart' show mcpDiscardRisk, mcpIfDirtySchema, mcpLeaveLevel;

/// The Content Browser as MCP tools: list and search
/// assets, import a file through the real import pipeline, create an asset,
/// open its editor, delete it.
void registerAssetTools(McpToolRegistry registry, EditorViewModel vm, McpEditorSessions sessions) {
  Map<String, Object?> assetSummary(RealAssetInfo a) => {
        'path': a.relativePath,
        'lmas_path': a.lmasPath,
        'file_name': a.fileName,
        'type': a.type.name,
        'bytes': a.bytes,
        'asset_id': a.assetId,
        'references': [for (final r in a.references) {'slot': r.slotName, 'asset_id': r.assetId, 'path': r.assetPath}],
        'last_modified': a.lastModified?.toIso8601String(),
      };

  const parentClasses = ['LuminaActor', 'LuminaPawn', 'LuminaCharacter', BlueprintEditorViewModel.gameModeParent];

  registry.registerAll([
    McpTool(
      name: 'list_assets',
      risk: McpToolRisk.readOnly,
      groups: const {McpToolGroups.asset},
      title: 'List assets',
      description: 'The project\'s assets under contents/ (the Content Browser), with their project-relative path, type '
          '(${AssetType.values.map((t) => t.name).join(', ')}), size and references. Filter by type, by folder '
          '(a contents/ subfolder) and by a case-insensitive name substring.',
      inputSchema: McpSchema.object({
        'type': McpSchema.string('Only assets of this type, e.g. "filamesh" (static mesh), "filamat" (material), "actor" (Blueprint), "texture".'),
        'folder': McpSchema.string('Only assets under this folder, e.g. "contents/meshes" or "meshes".'),
        'query': McpSchema.string('Only assets whose file name contains this text (case-insensitive).'),
      }),
      handler: (args) {
        final typeName = args.optionalString('type');
        AssetType? type;
        if (typeName != null) {
          type = AssetType.values.where((t) => t.name == typeName).firstOrNull;
          if (type == null) {
            return McpToolResult.error('Unknown asset type "$typeName". Types: ${AssetType.values.map((t) => t.name).join(', ')}.');
          }
        }
        var folder = args.optionalString('folder');
        if (folder != null && !folder.startsWith('contents/')) folder = 'contents/$folder';
        final query = args.optionalString('query')?.toLowerCase();
        final assets = vm.realAssets.where((a) {
          if (type != null && a.type != type) return false;
          if (folder != null && !a.relativePath.startsWith('$folder/') && !a.relativePath.startsWith(folder)) return false;
          if (query != null && !a.fileName.toLowerCase().contains(query)) return false;
          return true;
        }).toList();
        return McpToolResult.json({'count': assets.length, 'assets': assets.map(assetSummary).toList()});
      },
    ),
    McpTool(
      name: 'import_asset',
      risk: McpToolRisk.mutating,
      groups: const {McpToolGroups.asset},
      idempotent: false,
      openWorld: true,
      title: 'Import asset',
      description: 'Imports a file from disk through the editor\'s import pipeline (Content Browser → Import): '
          'GLB / glTF / FBX / OBJ / Collada (.dae) / 3DS / PLY / DirectX (.x) / STL meshes (their materials and textures '
          'are extracted alongside; textures the file references are looked up next to it), PNG / JPG / WebP / TGA '
          'textures, WAV / OGG audio. Returns the .lmas assets that appeared and every file written (created_files). '
          'One undo step: undo moves exactly those files to the project trash (.lumina/trash).',
      inputSchema: McpSchema.object({
        'path': McpSchema.string('The absolute path of the file to import.'),
        'folder': McpSchema.string('The contents/ subfolder to import into, e.g. "contents/meshes"; default: by type.'),
        'generate_lods': McpSchema.boolean('Generate levels of detail for a mesh. Default false.'),
        'target_skeleton': McpSchema.string('For an FBX animation: the project skeletal mesh .lmas (relative path) to retarget onto.'),
      }, required: ['path']),
      handler: (args) async {
        final path = args.string('path');
        if (!File(path).existsSync()) return McpToolResult.error('No file at "$path".');
        final before = vm.realAssets.map((a) => a.relativePath).toSet();
        final filesBefore = vm.contentsSnapshot();
        final logsBefore = vm.logs.length;
        await vm.processImportPipeline(
          sourceFilePath: path,
          targetSubFolder: args.optionalString('folder'),
          generateLods: args.boolean('generate_lods'),
          targetSkeletonPath: args.optionalString('target_skeleton'),
        );
        final created = vm.realAssets.where((a) => !before.contains(a.relativePath)).toList();
        if (created.isEmpty) {
          final errors = vm.logs.skip(logsBefore).where((e) => e.level == 'error').map((e) => e.message).join('\n');
          return McpToolResult.error('The import of "$path" produced no asset.${errors.isEmpty ? '' : '\n$errors'}');
        }
        final createdFiles = vm.filesCreatedSince(filesBefore);
        vm.recordCreatedFilesUndo(createdFiles, 'Import ${path.split(RegExp(r'[\\/]')).last}');
        return McpToolResult.json({'imported': created.map(assetSummary).toList(), 'created_files': createdFiles});
      },
    ),
    McpTool(
      name: 'create_asset',
      risk: McpToolRisk.mutating,
      groups: const {McpToolGroups.asset},
      idempotent: false,
      title: 'Create asset',
      description: 'Creates a new asset under contents/ (Content Browser → New): "filamat" writes a material with the '
          'editor\'s default .mat source (it declares flipUV : false, so a texture sampled with getUV0() draws upright); '
          '"actor" a Blueprint class (give parent_class: ${parentClasses.join(', ')}); '
          '"widget" a Widget Blueprint; "animBlueprint" / "blendSpace" an ABP_ / BS_ asset for target_mesh (a skeletal '
          'mesh; the Anim Blueprint starts with an Idle state playing its first clip, the Blend Space as Direction × '
          'Speed), placed beside its clips under contents/animations/<Mesh>/; "sequencer", "particle" and "animation" '
          'the document their editor authors for a new asset (a 30 fps, 120-frame sequence; one default emitter); '
          '"animation" with target_mesh an Animation Sequence authored from scratch for that skeletal mesh '
          '(length_frames or length_seconds, frame_rate default 30; the skeleton root\'s rest pose keyed at frame 0), '
          'stored as a clip in the mesh\'s GLB so Animation Blueprints, Play and the game play it by name — key its '
          'bones in the Animation editor; '
          '"landscape" a real flat terrain (grid_resolution n × 64 + 1, default 129; world_size_cm, default 25 600; '
          'max_height_cm, default 10 000), as New → Landscape; "actor" with blueprint_kind "enum" / "interface" an '
          'Enumeration (contents/enums) / Blueprint Interface (contents/interfaces), as New → Blueprints; a '
          'physicsAsset starts empty (bind_physics_skeletal_mesh), a sound is imported (import_asset a .wav); '
          'other types an empty .lmas. A static mesh ("filamesh") or a texture only comes '
          'from a source file: use import_asset. `folder` places every type; the result is the real path written. One '
          'undo step: undo moves the new files to the project trash (.lumina/trash).',
      inputSchema: McpSchema.object({
        'type': McpSchema.string('The asset type: "filamat", "actor", "widget", "texture", "audio", …', enumValues: AssetType.values.map((t) => t.name).toList()),
        'name': McpSchema.string('The asset name without extension, e.g. "M_Rust" or "BP_Door".'),
        'folder': McpSchema.string('The contents/ subfolder, e.g. "materials"; default by type (materials, blueprints, widgets, …).'),
        'parent_class': McpSchema.string('For "actor": the Blueprint\'s parent class. Default "LuminaActor".', enumValues: parentClasses),
        'target_mesh': McpSchema.string('For "animBlueprint" and "blendSpace" (required): the skeletal mesh .lmas '
            '(project-relative) whose clips it plays. For "animation": the skeletal mesh a new Animation Sequence is '
            'authored for (without it, an empty placeholder is written).'),
        'length_frames': McpSchema.integer('For "animation" with target_mesh: the sequence length in frames; default 60.'),
        'length_seconds': McpSchema.number('For "animation" with target_mesh: the length in seconds, instead of length_frames.'),
        'frame_rate': McpSchema.number('For "animation" with target_mesh: frames per second; default 30.'),
        'blueprint_kind': McpSchema.string('For "actor": "class" (default) a Blueprint class, "enum" an Enumeration, '
            '"interface" a Blueprint Interface.', enumValues: const ['class', 'enum', 'interface']),
        'grid_resolution': McpSchema.integer('For "landscape": vertices per side, n × 64 + 1 (65 … 8129); default 129.'),
        'world_size_cm': McpSchema.number('For "landscape": side length in cm; default 25 600.'),
        'max_height_cm': McpSchema.number('For "landscape": height range in cm; default 10 000.'),
      }, required: ['type', 'name']),
      handler: (args) async {
        final type = AssetType.values.firstWhere((t) => t.name == args.string('type'));
        final name = args.string('name').trim();
        final filesBefore = vm.contentsSnapshot();
        if (name.isEmpty || name.contains('/') || name.endsWith('.lmas')) {
          return McpToolResult.error('"name" must be a plain asset name without a folder or extension.');
        }
        // `folder` is honoured by every branch, and a mesh or a
        // texture — whose content only a source file gives — is an import.
        final folderArg = args.optionalString('folder');
        if (folderArg != null && _folderArg(folderArg, '').split('/').any((s) => s.isEmpty || s == '.' || s == '..')) {
          return McpToolResult.error('"folder" must be a folder under contents/, e.g. "blueprints/doors"; got "$folderArg".');
        }
        if (type == AssetType.filamesh || type == AssetType.texture) {
          return McpToolResult.error('A ${type == AssetType.filamesh ? 'static mesh' : 'texture'} comes from a source file: '
              'call import_asset with the file\'s path (and folder) instead. Nothing was written.');
        }
        String relative;
        switch (type) {
          // An Enumeration / Blueprint Interface, as New →
          // Blueprints → Enumeration / Blueprint Interface writes them.
          case AssetType.actor when (args.optionalString('blueprint_kind') ?? 'class') != 'class':
            final isEnum = args.string('blueprint_kind') == 'enum';
            if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(name)) {
              return McpToolResult.error('"$name" is not an identifier (letters, digits, _; not starting with a digit).');
            }
            final folder = folderArg == null
                ? (isEnum ? BlueprintAssetCatalog.enumsFolder : BlueprintAssetCatalog.interfacesFolder)
                : _folderArg(folderArg, '');
            final dir = vm.projectDirPath;
            final unique = BlueprintAssetCatalog.uniqueName(dir, folder, name);
            final path = '$folder/$unique.lmas';
            relative = isEnum
                ? BlueprintAssetCatalog.writeEnum(dir, LuminaBlueprintEnumDocument(name: unique), path: path)
                : BlueprintAssetCatalog.writeInterface(dir, LuminaBlueprintInterfaceDocument(name: unique), path: path);
            vm.refreshAssets();
          case AssetType.actor:
            final parent = args.optionalString('parent_class') ?? 'LuminaActor';
            if (!parentClasses.contains(parent)) {
              return McpToolResult.error('Unknown parent_class "$parent". Accepted: ${parentClasses.join(', ')}.');
            }
            final folder = _folderArg(folderArg, 'blueprints');
            relative = '$folder/$name.lmas';
            if (File('${vm.projectDirPath}/$relative').existsSync()) return McpToolResult.error('$relative already exists.');
            await vm.createBlueprintWithParent(name: name, parentClass: parent, folder: folder);
          case AssetType.widget:
            relative = await vm.createWidgetBlueprint(name: name, folder: folderArg == null ? null : _folderArg(folderArg, 'widgets'));
          case AssetType.filamat:
            final folder = _folderArg(args.optionalString('folder'), 'materials');
            relative = '$folder/$name.lmas';
            final file = File('${vm.projectDirPath}/$relative');
            if (file.existsSync()) return McpToolResult.error('$relative already exists.');
            // The Material editor opened on a missing file authors the default
            // source; saving it is exactly what New Material then Save does.
            final editor = MaterialEditorViewModel(assetPath: file.path);
            await editor.load();
            final ok = await editor.save();
            editor.dispose();
            if (!ok) return McpToolResult.error('Could not write $relative; see the Output Log.');
            vm.refreshAssets();
          // An Anim Blueprint / Blend Space for its target
          // mesh, as the Content Browser's New dialog makes them.
          case AssetType.animBlueprint || AssetType.blendSpace:
            final meshes = AnimGraphAssetService.skeletalMeshes(vm.projectDirPath);
            final mesh = args.optionalString('target_mesh');
            if (mesh == null || !meshes.any((m) => m.relativePath == mesh)) {
              return McpToolResult.error('${mesh == null ? 'A ${type.name} needs target_mesh' : 'No skeletal mesh "$mesh"'}: '
                  'pass one of the project\'s skeletal meshes: ${meshes.isEmpty ? 'none (import one first)' : meshes.map((m) => m.relativePath).join(', ')}.');
            }
            final abp = type == AssetType.animBlueprint;
            final dir = vm.projectDirPath;
            if (folderArg == null) {
              relative = abp
                  ? AnimGraphAssetService.createAnimBlueprint(dir, name: name, meshRelPath: mesh)
                  : AnimGraphAssetService.createBlendSpace(dir, name: name, meshRelPath: mesh);
            } else {
              relative = '${_folderArg(folderArg, '')}/${AnimGraphAssetService.withPrefix(name, abp ? 'ABP_' : 'BS_')}.lmas';
              if (File('$dir/$relative').existsSync()) return McpToolResult.error('$relative already exists.');
              if (abp) {
                AnimGraphAssetService.writeAnimBlueprint(
                    dir, relative, AnimGraphAssetService.newAnimBlueprint(mesh, AnimGraphAssetService.clipNames(dir, mesh)));
              } else {
                AnimGraphAssetService.writeBlendSpace(dir, relative, AnimGraphAssetService.newBlendSpace(), targetMesh: mesh);
              }
            }
            vm.refreshAssets();
          // A real flat terrain, as New → Landscape.
          case AssetType.landscape:
            final res = args.integer('grid_resolution', fallback: 129);
            if (!LandscapeData.isValidResolution(res)) {
              final (lo, hi) = LandscapeData.nearestValidResolutions(res);
              return McpToolResult.error('grid_resolution $res does not tile into 64-quad sections: it must be n × 64 + 1 '
                  '(65 … ${LandscapeData.maxGridResolution}); the nearest valid ones are $lo and ${hi ?? lo}. Nothing was written.');
            }
            final size = args.number('world_size_cm', fallback: 25600);
            final height = args.number('max_height_cm', fallback: 10000);
            if (size <= 0 || height <= 0) return McpToolResult.error('world_size_cm and max_height_cm must be positive.');
            final folder = _folderArg(folderArg, 'landscapes');
            relative = '$folder/$name.lmas';
            if (File('${vm.projectDirPath}/$relative').existsSync()) return McpToolResult.error('$relative already exists.');
            await LandscapeAssetService.createFlatAsset(
              projectDirPath: vm.projectDirPath,
              subFolder: folder.substring('contents/'.length),
              fileName: '$name.lmas',
              gridResolution: res,
              worldSize: LuminaUnits.toMetres(size),
              maxHeight: LuminaUnits.toMetres(height),
            );
            vm.refreshAssets();
          // An Animation Sequence authored from scratch for a skeletal mesh,
          // as Content Browser → New → Animation Sequence makes it.
          case AssetType.animation when args.optionalString('target_mesh') != null:
            final meshes = AnimGraphAssetService.skeletalMeshes(vm.projectDirPath);
            final mesh = args.optionalString('target_mesh')!;
            if (!meshes.any((m) => m.relativePath == mesh)) {
              return McpToolResult.error('No skeletal mesh "$mesh": pass one of the project\'s skeletal meshes: '
                  '${meshes.isEmpty ? 'none (import one first)' : meshes.map((m) => m.relativePath).join(', ')}.');
            }
            final fps = args.number('frame_rate', fallback: 30);
            if (fps <= 0 || fps > 240) return McpToolResult.error('frame_rate must be in (0, 240]; got $fps.');
            final seconds = args.optionalNumber('length_seconds');
            final frames = seconds != null ? (seconds * fps).round() : args.integer('length_frames', fallback: 60);
            if (frames < 1) return McpToolResult.error('The length must be at least one frame; got $frames.');
            try {
              relative = AnimGraphAssetService.createAnimationSequence(vm.projectDirPath,
                  name: name,
                  meshRelPath: mesh,
                  lengthFrames: frames,
                  frameRate: fps,
                  folder: folderArg == null ? null : _folderArg(folderArg, ''));
            } catch (e) {
              return McpToolResult.error('Could not create the Animation Sequence: $e');
            }
            vm.refreshAssets();
          // What the editor authors on a new asset, saved.
          case AssetType.sequencer || AssetType.particle || AssetType.animation:
            final folder = _folderArg(folderArg, '${type.name}s');
            relative = '$folder/$name.lmas';
            final path = '${vm.projectDirPath}/$relative';
            if (File(path).existsSync()) return McpToolResult.error('$relative already exists.');
            final bool ok;
            switch (type) {
              case AssetType.sequencer:
                final editor = SequencerViewModel(assetPath: path, projectDirPath: vm.projectDirPath);
                await editor.load();
                ok = await editor.save();
                editor.dispose();
              case AssetType.particle:
                final editor = ParticleEditorViewModel(assetPath: path, projectDirPath: vm.projectDirPath)..open();
                ok = await editor.save();
                editor.dispose();
              default:
                final editor = AnimationEditorViewModel(assetPath: path);
                await editor.load();
                ok = await editor.save();
                editor.dispose();
            }
            if (!ok) return McpToolResult.error('Could not write $relative; see the Output Log.');
            vm.refreshAssets();
          default:
            final folder = _folderArg(args.optionalString('folder'), '${type.name}s');
            relative = '$folder/$name.lmas';
            if (File('${vm.projectDirPath}/$relative').existsSync()) return McpToolResult.error('$relative already exists.');
            await vm.createNewAssetOnDisk(folder.substring('contents/'.length), '$name.lmas', type);
        }
        final createdFiles = vm.filesCreatedSince(filesBefore);
        vm.recordCreatedFilesUndo(createdFiles, 'Create $name');
        final asset = vm.realAssets.where((a) => a.relativePath == relative).firstOrNull;
        return McpToolResult.json({
          'path': relative,
          'created_files': createdFiles,
          'exists': File('${vm.projectDirPath}/$relative').existsSync(),
          'asset': asset == null ? null : assetSummary(asset),
        });
      },
    ),
    McpTool(
      name: 'open_asset_editor',
      risk: McpToolRisk.editorState,
      groups: const {McpToolGroups.asset},
      idempotent: true,
      riskForArguments: mcpDiscardRisk,
      title: 'Open asset editor',
      description: 'Opens the asset\'s editor in a workspace tab, as a double-click in the Content Browser does '
          '(Material, Blueprint, Static Mesh, Skeletal Mesh, Animation, Texture, …). Returns the tab id and category. '
          'A level asset opens as the level, guarded like open_level: the open level\'s unsaved changes follow '
          'if_dirty.',
      inputSchema: McpSchema.object({
        'asset': McpSchema.string('The asset\'s project-relative path (list_assets), or its file name when unique.'),
        'if_dirty': mcpIfDirtySchema(),
      }, required: ['asset']),
      handler: (args) async {
        final asset = sessions.resolveAsset(args.string('asset'));
        // Opening a level would drop the open level's
        // unsaved work, and there is no one to ask here: if_dirty decides.
        if (asset.type == AssetType.level && asset.relativePath != vm.project.activeLevel) {
          final refusal = mcpRefuseWhilePlaying(vm) ?? await mcpLeaveLevel(vm, args.optionalString('if_dirty'));
          if (refusal != null) return refusal;
          vm.switchLevel(asset.relativePath);
          vm.selectTab(0);
        } else {
          // The route a Content Browser double-click takes: a
          // plugin asset opens in its plugin's editor.
          vm.openAssetEditorByPath(asset.relativePath);
        }
        return McpToolResult.json({
          'tab_id': vm.currentTab.id,
          'category': vm.currentTab.category,
          'title': vm.currentTab.title,
          'open_tabs': vm.openTabs.map((t) => {'id': t.id, 'title': t.title, 'category': t.category}).toList(),
        });
      },
    ),
    McpTool(
      name: 'delete_asset',
      risk: McpToolRisk.destructive,
      groups: const {McpToolGroups.asset},
      title: 'Delete asset',
      description: 'Deletes an asset (Content Browser → Delete): its files move to the project trash '
          '(.lumina/trash/<trash_id>) and the level actors that reference it are removed (`removed_actors`). One '
          'undo step: undo restores the files byte-identical and the actors; restore_asset brings them back later.',
      inputSchema: McpSchema.object({
        'asset': McpSchema.string('The asset\'s project-relative path (list_assets), or its file name when unique.'),
      }, required: ['asset']),
      handler: (args) async {
        final asset = sessions.resolveAsset(args.string('asset'));
        final (:entry, :removed) = await vm.deleteAssetsToTrash([asset]);
        return McpToolResult.json({
          'deleted': asset.relativePath,
          'trash_id': entry.id,
          'trashed_files': [for (final f in entry.files) f.original],
          'removed_actors': [
            for (final a in removed) {'id': a.id, 'name': a.name},
          ],
          'exists': File('${vm.projectDirPath}/${asset.relativePath}').existsSync(),
          'asset_count': vm.realAssets.length,
        });
      },
    ),
    McpTool(
      name: 'list_trash',
      title: 'List trash',
      risk: McpToolRisk.readOnly,
      groups: const {McpToolGroups.asset},
      description: 'The project trash (.lumina/trash): every deleted asset\'s entry, newest first — id, when, why, who, '
          'its files and the actors it removed. restore_asset({trash_id}) brings one back.',
      inputSchema: McpSchema.object(const {}),
      handler: (args) {
        final entries = vm.projectTrash.list();
        return McpToolResult.json({
          'count': entries.length,
          'bytes': vm.projectTrash.sizeBytes,
          'entries': [
            for (final e in entries)
              {
                'trash_id': e.id,
                'created': e.created.toIso8601String(),
                'reason': e.reason,
                'origin': e.origin,
                'files': [for (final f in e.files) {'path': f.original, 'bytes': f.bytes}],
                'actors': [for (final a in e.actors) {'id': a['id'], 'name': a['name']}],
              },
          ],
        });
      },
    ),
    McpTool(
      name: 'restore_asset',
      title: 'Restore asset',
      risk: McpToolRisk.mutating,
      groups: const {McpToolGroups.asset},
      idempotent: false,
      description: 'Restores a trash entry (list_trash): its files return to their paths and the actors it removed '
          'return to the level. Refused, naming them, when a file of the same path exists again. One undo step.',
      inputSchema: McpSchema.object({
        'trash_id': McpSchema.string('The entry id from delete_asset or list_trash, e.g. "20260927-101500-1".'),
      }, required: ['trash_id']),
      handler: (args) async {
        final id = args.string('trash_id');
        if (vm.projectTrash.entry(id) == null) {
          return McpToolResult.error('No trash entry "$id". Call list_trash for the entries.');
        }
        try {
          final (:entry, :actors) = await vm.restoreFromTrash(id);
          return McpToolResult.json({
            'trash_id': id,
            'restored_files': [for (final f in entry.files) f.original],
            'restored_actors': [for (final a in actors) {'id': a.id, 'name': a.name}],
          });
        } on TrashConflict catch (e) {
          return McpToolResult.error('Cannot restore $id: these paths exist again: ${e.paths.join(', ')}. '
              'Delete or rename them first.');
        }
      },
    ),
  ]);
}

String _folderArg(String? folder, String fallback) {
  var f = (folder == null || folder.trim().isEmpty) ? fallback : folder.trim();
  f = f.replaceAll(RegExp(r'^/+|/+$'), '');
  if (!f.startsWith('contents/')) f = 'contents/$f';
  return f;
}

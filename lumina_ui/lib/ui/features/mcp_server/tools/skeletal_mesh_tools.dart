import 'package:lumina/lumina.dart';

import '../../main_editor/view_models/editor_view_model.dart';
import '../../sub_editors/models/material_slot_binding.dart';
import '../../sub_editors/models/skeletal_mesh_socket.dart';
import '../../sub_editors/view_models/skeletal_mesh_editor_view_model.dart';
import '../services/mcp_editor_sessions.dart';
import '../services/mcp_protocol.dart';
import '../services/mcp_tool.dart';
import 'rotation_convention.dart';

/// The Skeletal Mesh editor as MCP tools: bones and sockets, material slots and their texture
/// bindings, per-bone retargeting, morph-target and RigLogic preview
/// weights, vertex weight sums, Save.
///
/// The Skeletal Mesh editor has no undo stack (a dirty flag only): these
/// edits are reverted by not saving (the tab's Discard), never by `undo`.
void registerSkeletalMeshTools(McpToolRegistry registry, EditorViewModel vm, McpEditorSessions sessions) {
  const groups = {McpToolGroups.animation};
  const noUndo = 'The Skeletal Mesh editor has no undo stack: the edit marks the tab dirty and is reverted only by '
      'not saving (the tab\'s Discard).';
  const space = 'Socket transforms are relative to the parent bone, as the editor\'s socket fields show them: '
      'location in the mesh\'s units, rotation $kMcpBoneRotationConvention, scale factors.';
  const retargetOptions = ['Animation', 'Skeleton', 'AnimationScaled'];
  final assetArg = McpSchema.string('The skeletal mesh: its project-relative .lmas path (list_assets with type '
      '"filameshSk") or its file name when unique.');
  final socketArg = McpSchema.string('A socket name (get_skeleton).');
  final slotArg = McpSchema.integer('The material slot index (get_skeletal_material_slots).');

  Future<SkeletalMeshEditorViewModel> editorFor(McpArgs args) async {
    final asset = sessions.resolveAsset(args.string('asset'));
    final e = await sessions.skeletalMesh(asset);
    if (e.hasError) {
      throw JsonRpcException(JsonRpcErrorCode.invalidParams, '${asset.relativePath} could not be loaded as a skeletal mesh.');
    }
    return e;
  }

  String rel(String? path) {
    if (path == null) return '';
    final p = path.replaceAll('\\', '/');
    final dir = '${vm.projectDirPath.replaceAll('\\', '/')}/';
    return p.startsWith(dir) ? p.substring(dir.length) : p;
  }

  String boneOf(SkeletalMeshEditorViewModel e, String bone) {
    final names = e.allBoneNames;
    if (names.contains(bone)) return bone;
    final key = bone.toLowerCase();
    var near = names.where((n) => n.toLowerCase().contains(key)).toList();
    if (near.isEmpty && key.length > 3) near = names.where((n) => n.toLowerCase().contains(key.substring(0, 3))).toList();
    final hint = near.isEmpty ? 'The first bones: ${names.take(10).join(', ')}' : 'Bones containing it: ${near.take(10).join(', ')}';
    throw JsonRpcException(JsonRpcErrorCode.invalidParams, 'No bone "$bone" in ${e.fileBasename}. $hint (get_skeleton with bone_filter).');
  }

  SkeletalMeshSocket socketOf(SkeletalMeshEditorViewModel e, String name) =>
      e.sockets.where((s) => s.name == name).firstOrNull ??
      (throw JsonRpcException(JsonRpcErrorCode.invalidParams,
          'No socket "$name". Sockets: ${e.sockets.isEmpty ? 'none' : e.sockets.map((s) => s.name).join(', ')}.'));

  MaterialSlotBinding slotOf(SkeletalMeshEditorViewModel e, McpArgs args) {
    final i = args.integer('slot');
    if (i < 0 || i >= e.materialSlots.length) {
      throw JsonRpcException(JsonRpcErrorCode.invalidParams, 'No slot $i; the mesh has ${e.materialSlots.length}.');
    }
    return e.materialSlots[i];
  }

  Map<String, Object?> socketJson(SkeletalMeshSocket s) => {
        'name': s.name,
        'parent_bone': s.parentBone,
        'location': s.relativeLocation,
        'rotation': s.relativeRotation,
        'scale': s.relativeScale,
        'preview_asset': s.previewAssetPath,
      };

  Map<String, Object?> slotJson(SkeletalMeshEditorViewModel e, MaterialSlotBinding s) => {
        'index': s.index,
        'name': s.slotName,
        'source_material': s.sourceMaterialName,
        'material': s.assignedMaterialPath == null ? null : rel(s.assignedMaterialPath),
        'samplers': e.samplerNamesForSlot(s.index),
        'textures': {for (final t in s.textureBindings.entries) t.key: rel(t.value.assetPath)},
      };

  Map<String, String?> parents(SkeletalMeshEditorViewModel e) {
    final out = <String, String?>{};
    void walk(GlbNode n, String? parent) {
      out[n.name] = parent;
      for (final c in n.children) {
        walk(c, n.name);
      }
    }
    for (final r in e.rootBones) {
      walk(r, null);
    }
    return out;
  }

  List<double>? vec(McpArgs args, String key) => args.optionalVector3(key);

  registry.registerAll([
    McpTool(
      name: 'get_skeleton',
      risk: McpToolRisk.readOnly,
      groups: groups,
      title: 'Get skeleton',
      description: 'A skeletal mesh\'s rig as the Skeletal Mesh editor shows it: bones [{name, parent}] (filtered by a '
          'case-insensitive bone_filter), sockets [{name, parent_bone, location, rotation, scale, preview_asset}], '
          'per-bone retargeting, morph targets with their preview weights, the RigLogic DNA and its controls, counts '
          'and is_dirty. $space Opens its tab.',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'bone_filter': McpSchema.string('Only bones whose name contains this text.'),
      }, required: ['asset']),
      handler: (args) async {
        final e = await editorFor(args);
        final filter = args.optionalString('bone_filter')?.toLowerCase();
        final parentOf = parents(e);
        return McpToolResult.json({
          'asset': rel(e.assetPath),
          'bone_count': e.allBoneNames.length,
          'bones': [
            for (final b in e.allBoneNames)
              if (filter == null || b.toLowerCase().contains(filter)) {'name': b, 'parent': parentOf[b]},
          ],
          'sockets': [for (final s in e.sockets) socketJson(s)],
          'retargeting': e.boneRetargeting,
          'morph_targets': [for (final m in e.morphTargets) {'name': m.name, 'weight': e.morphWeights[m.name] ?? 0.0}],
          'rig_logic': {
            'loaded': e.hasRigLogic,
            'dna_path': e.dnaPath,
            'control_count': e.rigLogicControlNames.length,
            'controls': e.rigLogicControlValues,
          },
          'vertex_count': e.vertexCount,
          'triangle_count': e.triangleCount,
          'is_dirty': e.isDirty,
        });
      },
    ),
    McpTool(
      name: 'add_skeletal_socket',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: false,
      title: 'Add skeletal socket',
      description: 'Adds a socket on a bone (at the bone, unrotated, unit scale). A name in use gets a numeric suffix: '
          'the result is the name the editor produced. An unknown bone lists bones with similar names. $noUndo',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'bone': McpSchema.string('The parent bone.'),
        'name': McpSchema.string('The socket name. Default "<bone>_socket".'),
      }, required: ['asset', 'bone']),
      handler: (args) async {
        final e = await editorFor(args);
        final bone = boneOf(e, args.string('bone'));
        final before = e.sockets.map((s) => s.name).toSet();
        e.addSocket(parentBone: bone, name: args.optionalString('name')?.trim());
        final added = e.sockets.firstWhere((s) => !before.contains(s.name));
        return McpToolResult.json({...socketJson(added), 'is_dirty': e.isDirty});
      },
    ),
    McpTool(
      name: 'rename_skeletal_socket',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: false,
      title: 'Rename skeletal socket',
      description: 'Renames a socket; a name in use is refused. $noUndo',
      inputSchema: McpSchema.object({'asset': assetArg, 'socket': socketArg, 'name': McpSchema.string('The new name.')},
          required: ['asset', 'socket', 'name']),
      handler: (args) async {
        final e = await editorFor(args);
        final s = socketOf(e, args.string('socket'));
        final old = s.name;
        if (!e.renameSocket(old, args.string('name'))) {
          return McpToolResult.error('Cannot rename "$old" to "${args.string('name')}": the name is empty or already used.');
        }
        return McpToolResult.json({...socketJson(s), 'is_dirty': e.isDirty});
      },
    ),
    McpTool(
      name: 'reparent_skeletal_socket',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: true,
      title: 'Reparent skeletal socket',
      description: 'Moves a socket to another bone; its relative transform is kept. $noUndo',
      inputSchema: McpSchema.object({'asset': assetArg, 'socket': socketArg, 'bone': McpSchema.string('The new parent bone.')},
          required: ['asset', 'socket', 'bone']),
      handler: (args) async {
        final e = await editorFor(args);
        final s = socketOf(e, args.string('socket'));
        e.reparentSocket(s.name, boneOf(e, args.string('bone')));
        return McpToolResult.json({...socketJson(s), 'is_dirty': e.isDirty});
      },
    ),
    McpTool(
      name: 'set_skeletal_socket',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: true,
      title: 'Set skeletal socket',
      description: 'Sets a socket\'s relative location, rotation and scale, and the asset previewed on it (a mesh '
          '.lmas, project-relative; "" clears it). $space $noUndo',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'socket': socketArg,
        'location': McpSchema.vector3('[x, y, z] relative to the bone.'),
        'rotation': McpSchema.vector3('Rotation $kMcpBoneRotationConvention.'),
        'scale': McpSchema.vector3('[x, y, z] scale factors.'),
        'preview_asset': McpSchema.string('A mesh asset to preview on the socket; "" clears it.'),
      }, required: ['asset', 'socket']),
      handler: (args) async {
        final e = await editorFor(args);
        final s = socketOf(e, args.string('socket'));
        String? preview;
        if (args.has('preview_asset') && args.string('preview_asset').isNotEmpty) {
          final a = sessions.resolveAsset(args.string('preview_asset'));
          if (a.type != AssetType.filamesh && a.type != AssetType.filameshSk) {
            return McpToolResult.error('${a.relativePath} is a ${a.type.name}; a socket previews a mesh (list_assets type "filamesh").');
          }
          preview = a.relativePath;
        }
        if (args.has('location') || args.has('rotation') || args.has('scale')) {
          e.setSocketTransform(s.name, location: vec(args, 'location'), rotation: vec(args, 'rotation'), scale: vec(args, 'scale'));
        }
        if (args.has('preview_asset')) e.setSocketPreviewAsset(s.name, preview);
        return McpToolResult.json({...socketJson(s), 'is_dirty': e.isDirty});
      },
    ),
    McpTool(
      name: 'remove_skeletal_socket',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: false,
      removesContent: true,
      title: 'Remove skeletal socket',
      description: 'Deletes a socket. $noUndo',
      inputSchema: McpSchema.object({'asset': assetArg, 'socket': socketArg}, required: ['asset', 'socket']),
      handler: (args) async {
        final e = await editorFor(args);
        final s = socketOf(e, args.string('socket'));
        e.removeSocket(s.name);
        return McpToolResult.json({'removed': s.name, 'is_dirty': e.isDirty});
      },
    ),
    McpTool(
      name: 'get_skeletal_material_slots',
      risk: McpToolRisk.readOnly,
      groups: groups,
      title: 'Get skeletal material slots',
      description: 'The mesh\'s material slots [{index, name, source_material, material, samplers, textures {param: '
          'texture}}] as the Material Slots panel shows them, plus the project\'s materials and textures to bind.',
      inputSchema: McpSchema.object({'asset': assetArg}, required: ['asset']),
      handler: (args) async {
        final e = await editorFor(args);
        return McpToolResult.json({
          'slots': [for (final s in e.materialSlots) slotJson(e, s)],
          // The project's now (the panel's list was scanned when the tab opened).
          'available_materials': [for (final a in vm.realAssets) if (a.type == AssetType.filamat) a.relativePath],
          'available_textures': [for (final a in vm.realAssets) if (a.type == AssetType.texture) a.relativePath],
          'is_dirty': e.isDirty,
        });
      },
    ),
    McpTool(
      name: 'set_skeletal_material_slot',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: true,
      title: 'Set skeletal material slot',
      description: 'Binds a material to a slot (the slot\'s samplers are re-read and the preview recompiles), or '
          'clears it when material is omitted or null. $noUndo',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'slot': slotArg,
        'material': McpSchema.string('A material .lmas (list_assets type "filamat"); omit to clear the slot.'),
      }, required: ['asset', 'slot']),
      handler: (args) async {
        final e = await editorFor(args);
        final slot = slotOf(e, args);
        if (!args.has('material')) {
          e.clearMaterial(slot.index);
        } else {
          final m = sessions.resolveAsset(args.string('material'), type: AssetType.filamat);
          e.assignMaterial(slot.index, materialAssetPath: m.lmasPath ?? '${vm.projectDirPath}/${m.relativePath}', materialAssetId: m.assetId ?? m.fileName);
          await e.refreshSlotSamplers();
        }
        await e.refreshSlotMaterials();
        return McpToolResult.json({'slot': slotJson(e, e.materialSlots[slot.index]), 'is_dirty': e.isDirty});
      },
    ),
    McpTool(
      name: 'set_skeletal_slot_texture',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: true,
      title: 'Set skeletal slot texture',
      description: 'Binds a texture to a sampler parameter of the slot\'s material, or clears the binding when '
          'texture is omitted. A parameter the material does not declare is an error listing its samplers. $noUndo',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'slot': slotArg,
        'parameter': McpSchema.string('A sampler of the slot\'s material (get_skeletal_material_slots samplers).'),
        'texture': McpSchema.string('A texture .lmas (list_assets type "texture"); omit to clear.'),
      }, required: ['asset', 'slot', 'parameter']),
      handler: (args) async {
        final e = await editorFor(args);
        final slot = slotOf(e, args);
        final samplers = e.samplerNamesForSlot(slot.index);
        final parameter = args.string('parameter');
        if (!samplers.contains(parameter)) {
          return McpToolResult.error(samplers.isEmpty
              ? 'Slot ${slot.index} has no sampler parameters${slot.isBound ? '' : ' (bind a material first: set_skeletal_material_slot)'}.'
              : 'The material of slot ${slot.index} has no sampler "$parameter". Samplers: ${samplers.join(', ')}.');
        }
        if (!args.has('texture')) {
          e.clearTexture(slot.index, parameter);
        } else {
          final t = sessions.resolveAsset(args.string('texture'), type: AssetType.texture);
          e.assignTexture(slot.index, parameter,
              textureAssetPath: t.lmasPath ?? '${vm.projectDirPath}/${t.relativePath}', textureAssetId: t.assetId ?? t.fileName);
        }
        return McpToolResult.json({'slot': slotJson(e, e.materialSlots[slot.index]), 'is_dirty': e.isDirty});
      },
    ),
    McpTool(
      name: 'set_bone_retargeting',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: true,
      title: 'Set bone retargeting',
      description: 'A bone\'s translation retargeting, as the Skeleton tree\'s menu sets it: ${retargetOptions.join(', ')}. '
          'Saved with the mesh. $noUndo',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'bone': McpSchema.string('The bone.'),
        'option': McpSchema.string('The retargeting mode: ${retargetOptions.join(', ')}.'),
      }, required: ['asset', 'bone', 'option']),
      handler: (args) async {
        final e = await editorFor(args);
        final bone = boneOf(e, args.string('bone'));
        final option = args.string('option');
        if (!retargetOptions.contains(option)) {
          return McpToolResult.error('Unknown retargeting option "$option". Options: ${retargetOptions.join(', ')}.');
        }
        e.setBoneRetargeting(bone, option);
        return McpToolResult.json({'bone': bone, 'option': option, 'is_dirty': e.isDirty});
      },
    ),
    McpTool(
      name: 'set_skeletal_preview_weights',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: true,
      title: 'Set skeletal preview weights',
      description: 'The Morph Targets and RigLogic panels\' sliders: morph weights (0…1) by name, RigLogic control values '
          'by name (a DNA the user loaded in the editor), or reset: true to zero both first. They mark the tab dirty '
          'as the sliders do; morph weights are saved as the mesh\'s morph defaults. $noUndo',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'morphs': {'type': 'object', 'description': '{morph target: weight}.'},
        'rig_logic': {'type': 'object', 'description': '{RigLogic control: value}.'},
        'reset': McpSchema.boolean('Zero every morph weight and RigLogic control first.'),
      }, required: ['asset']),
      handler: (args) async {
        final e = await editorFor(args);
        final morphs = args.optionalObject('morphs') ?? const {};
        final rig = args.optionalObject('rig_logic') ?? const {};
        final names = e.morphTargets.map((m) => m.name).toSet();
        if (morphs.isNotEmpty) {
          if (names.isEmpty) return McpToolResult.error('${e.fileBasename} has no morph targets.');
          for (final entry in morphs.entries) {
            if (!names.contains(entry.key)) return McpToolResult.error('No morph target "${entry.key}". Morph targets: ${names.join(', ')}.');
            if (entry.value is! num) return McpToolResult.error('The weight of "${entry.key}" must be a number.');
          }
        }
        if (rig.isNotEmpty) {
          if (!e.hasRigLogic) {
            return McpToolResult.error('${e.fileBasename} has no RigLogic DNA loaded; load one in the Skeletal Mesh '
                'editor\'s RigLogic panel first (loading a DNA file is not an MCP tool).');
          }
          final controls = e.rigLogicControlNames.toSet();
          for (final entry in rig.entries) {
            if (!controls.contains(entry.key)) {
              return McpToolResult.error('No RigLogic control "${entry.key}". Controls include: ${controls.take(10).join(', ')}.');
            }
            if (entry.value is! num) return McpToolResult.error('The value of "${entry.key}" must be a number.');
          }
        }
        if (args.boolean('reset')) {
          e.resetMorphs();
          if (e.hasRigLogic) e.resetRigLogicControls();
        }
        morphs.forEach((k, v) => e.setMorphWeight(k, (v as num).toDouble()));
        rig.forEach((k, v) => e.setRigLogicControl(k, (v as num).toDouble()));
        return McpToolResult.json({
          'morph_weights': e.morphWeights,
          'rig_logic_controls': e.rigLogicControlValues,
          'is_dirty': e.isDirty,
        });
      },
    ),
    McpTool(
      name: 'get_vertex_weights',
      risk: McpToolRisk.readOnly,
      groups: groups,
      title: 'Get vertex weights',
      description: 'The skin weight sum of each given vertex (1.0 when normalised) and its bone influences, as the '
          'weight inspector shows them.',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'vertices': {'type': 'array', 'description': 'Vertex indices.', 'items': {'type': 'integer'}},
      }, required: ['asset', 'vertices']),
      handler: (args) async {
        final e = await editorFor(args);
        final raw = args['vertices'];
        if (raw is! List || raw.any((v) => v is! num)) {
          throw const JsonRpcException(JsonRpcErrorCode.invalidParams, '"vertices" must be an array of vertex indices');
        }
        final out = <Map<String, Object?>>[];
        for (final v in raw.cast<num>().map((n) => n.toInt())) {
          if (v < 0 || v >= e.vertexCount) return McpToolResult.error('Vertex $v is out of range 0..${e.vertexCount - 1}.');
          out.add({'vertex': v, 'weight_sum': e.getVertexWeightSum(v), 'influences': e.getVertexInfluences(v)});
        }
        return McpToolResult.json({'vertices': out, 'vertex_count': e.vertexCount});
      },
    ),
    McpTool(
      name: 'save_skeletal_mesh',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: true,
      title: 'Save skeletal mesh',
      description: 'Writes the skeletal mesh .lmas: sockets, retargeting, morph defaults, material slot and texture '
          'bindings (the tab\'s Save).',
      inputSchema: McpSchema.object({'asset': assetArg}, required: ['asset']),
      handler: (args) async {
        final e = await editorFor(args);
        if (!await e.save()) return McpToolResult.error('The skeletal mesh was not saved; see the Output Log.');
        return McpToolResult.json({'saved': rel(e.assetPath), 'is_dirty': e.isDirty});
      },
    ),
  ]);
}

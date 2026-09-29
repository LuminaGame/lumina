import 'package:lumina/lumina.dart' show AssetType;

import '../../main_editor/view_models/editor_view_model.dart';
import '../../sub_editors/models/static_mesh_collision.dart';
import '../../sub_editors/view_models/static_mesh_editor_view_model.dart';
import '../services/mcp_editor_sessions.dart';
import '../services/mcp_protocol.dart';
import '../services/mcp_tool.dart';

/// The Static Mesh editor as MCP tools: stats, LODs (add,
/// remove, ratio, screen size, material overrides, LOD group, forced preview
/// LOD), simple collision (box, sphere, capsule, convex hull, none,
/// complexity, mass, centre of mass) and material slots, then Save. The
/// editor has no undo stack: every edit is the tab's dirty state.
void registerStaticMeshTools(McpToolRegistry registry, EditorViewModel vm, McpEditorSessions sessions) {
  const groups = {McpToolGroups.staticMesh, McpToolGroups.assetEditors};
  const lodGroups = ['SmallProp', 'LargeProp', 'Foliage', 'Architecture', 'Decal'];
  const shapes = ['box', 'sphere', 'capsule', 'convex', 'none'];
  const complexities = ['default', 'use_complex_as_simple'];
  const noUndo = 'Not undoable (the Static Mesh editor keeps no undo stack); close the tab without saving to discard.';
  final assetArg = McpSchema.string('The static mesh asset (list_assets type "filamesh"): project-relative path or unique file name.');

  Future<StaticMeshEditorViewModel> editorFor(McpArgs args) =>
      sessions.staticMesh(sessions.resolveAsset(args.string('asset'), type: AssetType.filamesh));

  String relativeOf(String? path) => path == null ? '' : sessions.projectRelative(path);

  Map<String, Object?> meshJson(StaticMeshEditorViewModel e, String asset) => {
        'asset': asset,
        'triangles': e.triangleCount,
        'vertices': e.vertexCount,
        'uv_channels': e.uvChannelsCount,
        'sections': e.sectionCount,
        'bounds': {'min_cm': e.minBounds, 'max_cm': e.maxBounds, 'up_axis': 'z'},
        'material_slots': [
          for (final s in e.materialSlots)
            {'index': s.index, 'name': s.slotName, 'material': s.assignedMaterialPath == null ? null : relativeOf(s.assignedMaterialPath)},
        ],
        'lods': [
          for (final l in e.lods)
            {
              'level': l.level,
              'reduction_ratio': l.reductionRatio,
              'screen_size': l.screenSize,
              'triangles': l.triangleCount,
              'vertices': l.vertexCount,
              'material_overrides': {for (final o in l.materialOverrides.entries) o.key: relativeOf(o.value)},
            },
        ],
        'lod_group': e.lodGroup,
        'auto_compute_lod_distances': e.autoComputeLodDistances,
        'forced_lod': e.forcedLod,
        'collision_shapes': [for (final s in e.collisionShapes) s.toJson()],
        'collision_units': 'cm, Z up',
        'complexity': e.collisionComplexity,
        'mass_kg': e.massKg,
        'center_of_mass_cm': e.centerOfMassOffset,
        'is_dirty': e.isDirty,
      };

  McpToolResult ok(StaticMeshEditorViewModel e, McpArgs args) => McpToolResult.json(meshJson(e, args.string('asset')));

  McpToolResult? badLevel(StaticMeshEditorViewModel e, int level, {bool allowZero = false}) {
    if ((allowZero ? level >= 0 : level > 0) && level < e.lods.length) return null;
    return McpToolResult.error('No LOD$level to edit: the mesh has LOD0…LOD${e.lods.length - 1}'
        '${allowZero ? '' : ' and LOD0 is the source mesh'}.');
  }

  registry.registerAll([
    McpTool(
      name: 'get_static_mesh',
      risk: McpToolRisk.readOnly,
      groups: groups,
      title: 'Get static mesh',
      description: 'The Static Mesh editor\'s asset (opens its tab): triangles, vertices, UV channels, sections, '
          'bounds (cm, Z up), material slots with their bound material, LODs (reduction ratio, screen size, '
          'triangles, vertices, material overrides), LOD group, forced preview LOD, simple collision shapes (cm, Z '
          'up), complexity, mass, centre of mass, unsaved changes.',
      inputSchema: McpSchema.object({'asset': assetArg}, required: ['asset']),
      handler: (args) async => ok(await editorFor(args), args),
    ),
    McpTool(
      name: 'add_static_mesh_lod',
      risk: McpToolRisk.mutating,
      groups: groups,
      title: 'Add LOD',
      description: 'LOD Settings → Add LOD: a decimated level after the last (at most LOD3), its triangle count '
          'measured by the real decimator. $noUndo',
      inputSchema: McpSchema.object({'asset': assetArg}, required: ['asset']),
      handler: (args) async {
        final e = await editorFor(args);
        if (e.lods.length >= 4) return McpToolResult.error('The mesh already has LOD0…LOD3, the most the editor offers.');
        e.addLod();
        return ok(e, args);
      },
    ),
    McpTool(
      name: 'remove_static_mesh_lod',
      risk: McpToolRisk.destructive,
      groups: groups,
      title: 'Remove LOD',
      description: 'Removes a LOD level (1…3; LOD0 is the source mesh); the ones after it move up. $noUndo',
      inputSchema: McpSchema.object({'asset': assetArg, 'level': McpSchema.integer('The LOD level, 1…3.')}, required: ['asset', 'level']),
      handler: (args) async {
        final e = await editorFor(args);
        final level = args.integer('level');
        final refusal = badLevel(e, level);
        if (refusal != null) return refusal;
        e.removeLod(level);
        return ok(e, args);
      },
    ),
    McpTool(
      name: 'set_static_mesh_lod',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: true,
      title: 'Set LOD',
      description: 'A LOD level\'s reduction ratio (0.05–1, LOD1…3), screen size (strictly between its neighbours\' '
          'screen sizes) and material overrides {slot name: material asset or null}. $noUndo',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'level': McpSchema.integer('The LOD level.'),
        'reduction_ratio': McpSchema.number('Share of the triangles kept, 0.05–1 (LOD1…3).'),
        'screen_size': McpSchema.number('Screen size below which this LOD shows (LOD1…3).'),
        'material_overrides': McpSchema.any('{"element_0": "contents/materials/M_Low.lmas" or null, …}: per-slot '
            'material for this LOD; null removes the override.'),
      }, required: ['asset', 'level']),
      handler: (args) async {
        final e = await editorFor(args);
        final level = args.integer('level');
        final touchesLod0 = args.has('reduction_ratio') || args.has('screen_size');
        final refusal = badLevel(e, level, allowZero: !touchesLod0);
        if (refusal != null) return refusal;
        final overrides = args['material_overrides'];
        if (overrides != null && overrides is! Map) return McpToolResult.error('material_overrides must be an object {slot: material}.');
        final resolved = <String, String?>{};
        for (final entry in (overrides as Map? ?? const {}).entries) {
          final slot = '${entry.key}';
          if (!e.materialSlots.any((s) => s.slotName == slot)) {
            return McpToolResult.error('No material slot "$slot"; slots: ${e.materialSlots.map((s) => s.slotName).join(', ')}.');
          }
          final value = entry.value;
          resolved[slot] = value == null ? null : (sessions.resolveAsset('$value', type: AssetType.filamat).lmasPath);
        }
        if (args.has('screen_size')) {
          final size = args.number('screen_size');
          if (!e.setLodScreenSize(level, size)) {
            final prev = e.lods[level - 1].screenSize;
            final next = level + 1 < e.lods.length ? e.lods[level + 1].screenSize : null;
            return McpToolResult.error('LOD$level\'s screen size must sit strictly between its neighbours\': below '
                'LOD${level - 1}\'s $prev${next == null ? '' : ' and above LOD${level + 1}\'s $next'}; $size does not. '
                'Nothing was changed.');
          }
        }
        if (args.has('reduction_ratio')) e.setLodRatio(level, args.number('reduction_ratio'));
        for (final o in resolved.entries) {
          e.setLodMaterialOverride(level, o.key, o.value);
        }
        return ok(e, args);
      },
    ),
    McpTool(
      name: 'set_static_mesh_lod_group',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: true,
      title: 'Set LOD group',
      description: 'LOD Group preset (${lodGroups.join(', ')}): sets the LODs\' screen sizes from the preset '
          '(Architecture: LOD1 0.7, LOD2 0.4, LOD3 0.2); auto_compute_distances derives them from the bounds '
          'instead. $noUndo',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'group': McpSchema.string('The LOD group.', enumValues: lodGroups),
        'auto_compute_distances': McpSchema.boolean('Auto Compute LOD Distances.'),
      }, required: ['asset']),
      handler: (args) async {
        final e = await editorFor(args);
        final group = args.optionalString('group');
        if (group != null) e.setLodGroup(group);
        if (args.has('auto_compute_distances')) e.setAutoComputeLodDistances(args.boolean('auto_compute_distances'));
        return ok(e, args);
      },
    ),
    McpTool(
      name: 'set_static_mesh_preview_lod',
      risk: McpToolRisk.editorState,
      groups: groups,
      idempotent: true,
      title: 'Set preview LOD',
      description: 'The viewport\'s forced LOD: the level to preview, or no level (null) for LOD0 / auto. A view '
          'setting: the asset is not changed.',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'level': McpSchema.integer('The LOD level to show; omit or null for auto.'),
      }, required: ['asset']),
      handler: (args) async {
        final e = await editorFor(args);
        final level = args.has('level') ? args.integer('level') : null;
        if (level != null) {
          final refusal = badLevel(e, level, allowZero: true);
          if (refusal != null) return refusal;
        }
        e.setForcedLod(level);
        return ok(e, args);
      },
    ),
    McpTool(
      name: 'set_static_mesh_collision',
      risk: McpToolRisk.mutating,
      groups: groups,
      title: 'Set collision',
      description: 'Collision → Add simple collision: box, sphere or capsule fitted to the bounds, convex (one hull over '
          'the mesh\'s vertices), or none (removes it); complexity (${complexities.join(', ')}), mass_kg and '
          'center_of_mass_cm [x, y, z] (cm, Z up). The shape replaces the current one. $noUndo',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'shape': McpSchema.string('The simple collision shape.', enumValues: shapes),
        'complexity': McpSchema.string('Collision complexity.', enumValues: complexities),
        'mass_kg': McpSchema.number('Mass in kg (≥ 0).'),
        'center_of_mass_cm': McpSchema.vector3('Centre of mass offset [x, y, z] in cm.'),
      }, required: ['asset']),
      handler: (args) async {
        final e = await editorFor(args);
        final mass = args.optionalNumber('mass_kg');
        if (mass != null && mass < 0) return McpToolResult.error('mass_kg must be ≥ 0.');
        final shape = args.optionalString('shape');
        if (shape == 'none') {
          e.removeCollision();
        } else if (shape != null) {
          e.generateCollision(StaticMeshCollisionShapeType.values.byName(shape));
        }
        final complexity = args.optionalString('complexity');
        if (complexity != null) e.setCollisionComplexity(complexity);
        if (mass != null) e.setMass(mass);
        final com = args.optionalVector3('center_of_mass_cm');
        if (com != null) e.setCenterOfMassOffset(com);
        return ok(e, args);
      },
    ),
    McpTool(
      name: 'set_static_mesh_material_slot',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: true,
      title: 'Set material slot',
      description: 'Binds a material asset (list_assets type "filamat") to a material slot by index, as the slot\'s '
          'picker does, or clears it (material null: the mesh\'s own material shows). $noUndo',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'slot': McpSchema.integer('The slot index (get_static_mesh material_slots).'),
        'material': McpSchema.string('The material asset (path or unique file name); null clears the slot.'),
      }, required: ['asset', 'slot']),
      handler: (args) async {
        final e = await editorFor(args);
        final slot = args.integer('slot');
        if (slot < 0 || slot >= e.materialSlots.length) {
          return McpToolResult.error('No material slot $slot: the mesh has slots 0…${e.materialSlots.length - 1}.');
        }
        final wanted = args.optionalString('material');
        if (wanted == null) {
          e.clearMaterial(slot);
        } else {
          final material = sessions.resolveAsset(wanted, type: AssetType.filamat);
          final path = material.lmasPath;
          if (path == null) return McpToolResult.error('${material.relativePath} has no .lmas on disk.');
          e.assignMaterial(slot, materialAssetPath: path, materialAssetId: material.assetId ?? material.fileName);
        }
        return ok(e, args);
      },
    ),
    McpTool(
      name: 'save_static_mesh',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: true,
      title: 'Save static mesh',
      description: 'The tab\'s Save: writes LODs, collision (cm, Z up), physics and material slots to the .lmas, '
          'keeping the import\'s payload, thumbnail and other references.',
      inputSchema: McpSchema.object({'asset': assetArg}, required: ['asset']),
      handler: (args) async {
        final e = await editorFor(args);
        if (!await e.save()) return McpToolResult.error('Save failed; see the Output Log.');
        vm.refreshAssets();
        return ok(e, args);
      },
    ),
  ]);
}

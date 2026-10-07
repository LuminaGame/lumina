import 'dart:io';

import 'package:lumina_ui/ui/features/main_editor/services/camera_actor_properties.dart';
import 'package:lumina_ui/ui/features/main_editor/models/editor_actor_catalog.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_protocol.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_tool.dart';
import 'package:lumina_ui/ui/features/mcp_server/tools/core_tools.dart' show mcpUndoState;
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina/lumina.dart' show AssetType, LuminaLevelActorMaterial;
import 'package:lumina_ui/ui/features/mcp_server/tools/rotation_convention.dart';

/// The project and level tools: what the Outliner, the
/// Details panel and the Edit menu let a user do, as MCP tools over the real
/// [EditorViewModel]. Every mutation goes through the view model's own
/// transaction-recording methods, so Edit → Undo reverts it.
void registerLevelTools(McpToolRegistry registry, EditorViewModel vm) {
  const units = 'Units: centimetres, degrees, Z up (the editor\'s authoring space, as the Details panel shows them).';

  EditorActorNode actorOrThrow(String id) {
    final actor = vm.actors.where((a) => a.id == id).firstOrNull;
    if (actor == null) {
      throw JsonRpcException(
        JsonRpcErrorCode.invalidParams,
        'No actor with id "$id". Call list_actors for the ids in the level.',
      );
    }
    return actor;
  }

  /// A level edit while Play runs is refused: the runtime world owns the
  /// level until Stop restores the editor's snapshot.
  McpToolResult? refuseWhilePlaying() {
    if (vm.isPlaying || vm.transactions.isFrozen) {
      return McpToolResult.error('The level cannot be edited while Play-In-Editor runs. Call stop_pie first.');
    }
    return null;
  }

  Map<String, Object?> actorSummary(EditorActorNode a) => {
        'id': a.id,
        'name': a.name,
        'type': a.type,
        'parent_id': a.parentId,
        'location': a.location,
        'rotation': a.rotation,
        'scale': a.scale,
        'visible': a.isVisible,
        'locked': a.isLocked,
        'selected': vm.selectedActorIds.contains(a.id),
      };

  Map<String, Object?> undoState() => mcpUndoState(vm.transactions);

  registry.registerAll([
    McpTool(
      name: 'list_actors',
      risk: McpToolRisk.readOnly,
      groups: const {McpToolGroups.level},
      title: 'List actors',
      description: 'The actors of the open level (the World Outliner), with id, name, type, parent, transform, '
          'visibility, lock and selection. Filter by exact type (see list_actor_types) or a case-insensitive '
          'name substring. $units',
      inputSchema: McpSchema.object({
        'type': McpSchema.string('Only actors of this type, e.g. "PointLight", "Mesh", "Blueprint", "Folder".'),
        'name_contains': McpSchema.string('Only actors whose name contains this text (case-insensitive).'),
      }),
      handler: (args) {
        final type = args.optionalString('type');
        final needle = args.optionalString('name_contains')?.toLowerCase();
        final actors = vm.actors.where((a) {
          if (type != null && a.type != type) return false;
          if (needle != null && !a.name.toLowerCase().contains(needle)) return false;
          return true;
        }).toList();
        return McpToolResult.json({
          'count': actors.length,
          'actors': actors.map(actorSummary).toList(),
        });
      },
    ),
    McpTool(
      name: 'get_actor',
      risk: McpToolRisk.readOnly,
      groups: const {McpToolGroups.level},
      title: 'Get actor',
      description: 'Everything the editor knows about one actor: transform, mobility, light settings, material, '
          'mesh asset path, Blueprint class and its components with their properties (a Camera\'s field of view, '
          'projection, clip planes and exposure are its LuminaCameraComponent properties). $units',
      inputSchema: McpSchema.object({'id': McpSchema.string('The actor id from list_actors.')}, required: ['id']),
      handler: (args) {
        final a = actorOrThrow(args.string('id'));
        final map = Map<String, Object?>.from(a.toMap());
        map['selected'] = vm.selectedActorIds.contains(a.id);
        map['children'] = vm.childrenOf(a.id).map((c) => c.id).toList();
        if (a.meshData != null) {
          map['mesh'] = {
            'vertices': a.meshData!.vertexCount,
            'triangles': a.meshData!.triangleCount,
            'bounds_min': a.meshData!.minBounds,
            'bounds_max': a.meshData!.maxBounds,
          };
        }
        return McpToolResult.json(map);
      },
    ),
    McpTool(
      name: 'list_actor_types',
      risk: McpToolRisk.readOnly,
      groups: const {McpToolGroups.level},
      title: 'List actor types',
      description: 'The actor types spawn_actor accepts (the editor\'s Place Actors catalog): id, label, category, '
          'what placing one does, and whether a level may hold only one.',
      inputSchema: McpSchema.object(const {}),
      handler: (args) => McpToolResult.json({
        'types': [
          for (final t in EditorActorCatalog.all)
            {
              'id': t.id,
              'label': t.label,
              'category': t.category,
              'description': t.description,
              'unique': t.unique,
            },
        ],
      }),
    ),
    McpTool(
      name: 'spawn_actor',
      risk: McpToolRisk.mutating,
      groups: const {McpToolGroups.level},
      idempotent: false,
      title: 'Spawn actor',
      description: 'Places a new actor of a catalog type (list_actor_types) in the level, optionally named and '
          'transformed, as one undo step. For a mesh from an asset use spawn_actor_from_asset. $units',
      inputSchema: McpSchema.object({
        'type': McpSchema.string('The type id, e.g. "Primitive" (a basic shape: a 100 cm cube; change its shape and '
            'size with set_actor_property "LuminaProceduralMeshComponent.shape" / ".sizeX" / ".sizeY" / ".sizeZ", in cm), '
            '"PointLight", "DirectionalLight", "PlayerStart".'),
        'name': McpSchema.string('A name for the actor; a name already used by a sibling is refused.'),
        'location': McpSchema.vector3('[x, y, z] in centimetres, Z up. Default [0, 0, 0].'),
        'rotation': McpSchema.vector3('Rotation $kMcpRotationConvention. Default [0, 0, 0].'),
        'scale': McpSchema.vector3('[x, y, z] scale factors. Default [1, 1, 1].'),
        'parent_id': McpSchema.string('The id of a Folder or actor to place it under.'),
      }, required: ['type']),
      handler: (args) {
        final refusal = refuseWhilePlaying();
        if (refusal != null) return refusal;
        final type = args.string('type');
        if (EditorActorCatalog.byId(type) == null) {
          return McpToolResult.error(
            'Unknown actor type "$type". Types: ${EditorActorCatalog.all.map((t) => t.id).join(', ')}.',
          );
        }
        final spawnRefusal = vm.spawnRefusalFor(type);
        if (spawnRefusal != null) return McpToolResult.error(spawnRefusal);
        final parentId = args.optionalString('parent_id');
        if (parentId != null) actorOrThrow(parentId);
        final before = vm.actors.map((a) => a.id).toSet();
        vm.spawnNewActor(type, parentId: parentId);
        final node = vm.actors.where((a) => !before.contains(a.id)).firstOrNull;
        if (node == null) return McpToolResult.error('The editor did not spawn a "$type"; see the Output Log.');
        // The spawn is the undo step; its initial pose belongs to it, so the
        // pose is set on the node before anyone can undo, not as extra steps.
        final location = args.optionalVector3('location');
        final rotation = args.optionalVector3('rotation');
        final scale = args.optionalVector3('scale');
        if (location != null) node.location = location;
        if (rotation != null) node.rotation = rotation;
        if (scale != null) node.scale = scale;
        final name = args.optionalString('name');
        if (name != null && name.trim().isNotEmpty) {
          vm.renameActor(node.id, name);
          if (node.name != name) {
            vm.transactions.undo();
            return McpToolResult.error('The name "$name" is already used by a sibling actor; nothing was spawned.');
          }
        }
        vm.selectActor(node);
        return McpToolResult.json({'actor': actorSummary(node), 'undo': undoState()});
      },
    ),
    McpTool(
      name: 'spawn_actor_from_asset',
      risk: McpToolRisk.mutating,
      groups: const {McpToolGroups.level},
      idempotent: false,
      title: 'Spawn actor from asset',
      description: 'Places a project asset in the level as the Content Browser\'s "Place in 3D Scene" does: a mesh '
          '.lmas becomes a Mesh actor drawing that mesh, a Blueprint .lmas an instance of that class, a landscape '
          '.lmas a Landscape actor. One undo step. $units',
      inputSchema: McpSchema.object({
        'asset': McpSchema.string('The asset\'s project-relative path, e.g. "contents/meshes/fuel_barrel_red.lmas" '
            '(list_assets shows them), or just its file name when unique.'),
        'location': McpSchema.vector3('[x, y, z] in centimetres, Z up. Default [0, 0, 0].'),
      }, required: ['asset']),
      handler: (args) async {
        final refusal = refuseWhilePlaying();
        if (refusal != null) return refusal;
        final wanted = args.string('asset');
        final asset = vm.realAssets.where((a) => a.relativePath == wanted || a.lmasPath == wanted).firstOrNull ??
            vm.realAssets.where((a) => a.fileName == wanted || a.fileName == '$wanted.lmas').firstOrNull;
        if (asset == null) {
          return McpToolResult.error('No asset "$wanted" in the project. Call list_assets for the project\'s assets.');
        }
        final before = vm.actors.map((a) => a.id).toSet();
        await vm.spawnActorFromAsset(asset, location: args.optionalVector3('location'));
        final node = vm.actors.where((a) => !before.contains(a.id)).firstOrNull;
        if (node == null) {
          return McpToolResult.error('${asset.fileName} was not placed (a GameMode Blueprint cannot be placed); see the Output Log.');
        }
        return McpToolResult.json({
          'actor': actorSummary(node),
          'mesh_asset_path': node.meshAssetPath,
          'has_geometry': node.meshData != null,
          'undo': undoState(),
        });
      },
    ),
    McpTool(
      name: 'set_actor_transform',
      risk: McpToolRisk.mutating,
      groups: const {McpToolGroups.level},
      idempotent: true,
      title: 'Set actor transform',
      description: 'Sets an actor\'s location, rotation and/or scale (absolute values), as typing them into the '
          'Details panel does. Each vector given is one undo step. The actor becomes the selection. While the Sequencer '
          'editor is open, an actor its sequence animates is keyed at the playhead there instead (Auto Key; the level '
          'is unchanged). $units',
      inputSchema: McpSchema.object({
        'id': McpSchema.string('The actor id.'),
        'location': McpSchema.vector3('[x, y, z] in centimetres, Z up.'),
        'rotation': McpSchema.vector3('Rotation $kMcpRotationConvention.'),
        'scale': McpSchema.vector3('[x, y, z] scale factors.'),
      }, required: ['id']),
      handler: (args) {
        final refusal = refuseWhilePlaying();
        if (refusal != null) return refusal;
        final actor = actorOrThrow(args.string('id'));
        if (actor.isLocked) return McpToolResult.error('Actor "${actor.name}" is locked; set_actor_property locked=false first.');
        final location = args.optionalVector3('location');
        final rotation = args.optionalVector3('rotation');
        final scale = args.optionalVector3('scale');
        if (location == null && rotation == null && scale == null) {
          return McpToolResult.error('Give at least one of location, rotation, scale.');
        }
        vm.selectActor(actor);
        if (location != null) vm.updateActorLocation(location);
        if (rotation != null) vm.updateActorRotation(rotation);
        if (scale != null) vm.updateActorScale(scale);
        return McpToolResult.json({'actor': actorSummary(actor), 'undo': undoState()});
      },
    ),
    McpTool(
      name: 'set_actor_property',
      risk: McpToolRisk.mutating,
      groups: const {McpToolGroups.level},
      idempotent: true,
      title: 'Set actor property',
      description: 'Sets one property of an actor, as the Details panel does, in one undo step. Actor properties: '
          '"mobility" ("Static" | "Stationary" | "Movable"), "visible" (bool), "locked" (bool), '
          '"light_intensity" (number, lights), "cast_shadows" (bool, lights), "light_color" ("#RRGGBB", lights), '
          '"material" (a material .lmas path or unique name, drawn on every section of a placed mesh or basic shape; '
          'null gives the mesh its own back). A component property is "<component id or type>.<property id>", '
          'e.g. "LuminaProceduralMeshComponent.sizeX"; get_actor lists the components and their properties. A basic '
          'shape (Primitive) has "LuminaProceduralMeshComponent.shape" ("box" | "plane" | "sphere" | "cylinder"), '
          '".colorHex" and ".sizeX" / ".sizeY" / ".sizeZ" in cm, Z up like its location: sizeX along X, sizeY along Y '
          '(depth), sizeZ is the height (a plane uses sizeX and sizeY). A placed Camera has '
          '"LuminaCameraComponent.fieldOfView" (vertical, degrees, 5-170), ".projectionMode" ("Perspective" | '
          '"Orthographic"), ".orthoWidth" (cm), ".nearClipPlane" / ".farClipPlane" (cm), ".autoActivateForPlayer" '
          '(bool: Play looks through it as the player view target), ".autoExposure" (bool), ".aperture" (f-stops), '
          '".shutterSpeed" (seconds) and ".sensitivity" (ISO), the names a Blueprint camera component uses; the '
          'Sequencer camera lock, Play and the generated game look through them.',
      inputSchema: McpSchema.object({
        'id': McpSchema.string('The actor id.'),
        'property': McpSchema.string('The property, as listed in the description.'),
        'value': McpSchema.any('The new value, of the property\'s type.'),
      }, required: ['id', 'property', 'value']),
      handler: (args) {
        final refusal = refuseWhilePlaying();
        if (refusal != null) return refusal;
        final actor = actorOrThrow(args.string('id'));
        final property = args.string('property');
        final value = args['value'];
        String wrongType(String expected) => 'Property "$property" takes $expected; got ${value.runtimeType}.';
        switch (property) {
          case 'mobility':
            if (value is! String || !const ['Static', 'Stationary', 'Movable'].contains(value)) {
              return McpToolResult.error(wrongType('"Static", "Stationary" or "Movable"'));
            }
            vm.selectActor(actor);
            vm.updateActorMobility(value);
          case 'visible':
            if (value is! bool) return McpToolResult.error(wrongType('a boolean'));
            vm.setActorVisibilityWithTransaction(actor.id, value);
          case 'locked':
            if (value is! bool) return McpToolResult.error(wrongType('a boolean'));
            vm.setActorLockedWithTransaction(actor.id, value);
          case 'light_intensity':
            if (value is! num) return McpToolResult.error(wrongType('a number'));
            vm.selectActor(actor);
            vm.updateActorLightIntensity(value.toDouble());
          case 'cast_shadows':
            if (value is! bool) return McpToolResult.error(wrongType('a boolean'));
            vm.selectActor(actor);
            vm.updateActorCastShadows(value);
          case 'light_color':
            if (value is! String || !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(value)) {
              return McpToolResult.error(wrongType('a "#RRGGBB" colour'));
            }
            vm.selectActor(actor);
            vm.updateActorLightColor(value.toUpperCase());
          case 'material':
            if (value != null && value is! String) return McpToolResult.error(wrongType('a material path or null'));
            if (!LuminaLevelActorMaterial.actorTypes.contains(actor.type) || actor.blueprintClass != null) {
              return McpToolResult.error(
                'Actor "${actor.name}" (${actor.type}) draws no assigned material: only placed meshes and basic shapes do. '
                'A Blueprint sets its Static Mesh component\'s materialOverride.',
              );
            }
            String? path;
            if (value is String && value.isNotEmpty) {
              final wanted = value.replaceAll(r'\', '/');
              final material = vm.realAssets
                      .where((a) => a.type == AssetType.filamat && (a.relativePath == wanted || a.lmasPath?.replaceAll(r'\', '/') == wanted))
                      .firstOrNull ??
                  vm.realAssets.where((a) => a.type == AssetType.filamat && (a.fileName == wanted || a.fileName == '$wanted.lmas')).firstOrNull;
              if (material == null) {
                return McpToolResult.error('No material asset "$value" in the project. Call list_assets with type "filamat".');
              }
              path = material.relativePath;
            }
            vm.selectActor(actor);
            vm.updateActorMaterial(path);
            final problem = path == null ? null : LuminaLevelActorMaterial.problem(path, projectDir: vm.projectDirPath);
            if (problem != null) {
              return McpToolResult.json({
                'actor': actorSummary(actor),
                'material_warning': '$problem; the mesh draws its own materials until it is compiled (compile_material with save: true).',
                'undo': undoState(),
              });
            }
          default:
            final dot = property.indexOf('.');
            if (dot <= 0) {
              return McpToolResult.error(
                'Unknown property "$property". Actor properties: mobility, visible, locked, light_intensity, '
                'cast_shadows, light_color, material; or "<component>.<property>".',
              );
            }
            final componentKey = property.substring(0, dot);
            final propertyId = property.substring(dot + 1);
            // A Camera from an older level gets its camera component first.
            if (componentKey == CameraActorProperties.componentType) vm.ensureCameraComponent(actor.id);
            final component = actor.components.where((c) => c.id == componentKey || c.type == componentKey).firstOrNull;
            if (component == null) {
              return McpToolResult.error(
                'Actor "${actor.name}" has no component "$componentKey". Components: '
                '${actor.components.map((c) => '${c.id} (${c.type})').join(', ')}.',
              );
            }
            vm.selectActor(actor);
            vm.updateComponentPropertyWithTransaction(actor.id, component.id, propertyId, value);
        }
        return McpToolResult.json({'actor': actorSummary(actor), 'undo': undoState()});
      },
    ),
    McpTool(
      name: 'rename_actor',
      risk: McpToolRisk.mutating,
      groups: const {McpToolGroups.level},
      idempotent: true,
      title: 'Rename actor',
      description: 'Renames an actor or an Outliner folder (type "Folder") as one undo step. A name already used by a '
          'sibling is refused.',
      inputSchema: McpSchema.object({
        'id': McpSchema.string('The actor id.'),
        'name': McpSchema.string('The new name.'),
      }, required: ['id', 'name']),
      handler: (args) {
        final refusal = refuseWhilePlaying();
        if (refusal != null) return refusal;
        final actor = actorOrThrow(args.string('id'));
        final name = args.string('name');
        vm.renameActorWithTransaction(actor.id, name);
        if (actor.name != name) {
          return McpToolResult.error('Could not rename to "$name": empty, or a sibling already has that name.');
        }
        return McpToolResult.json({'actor': actorSummary(actor), 'undo': undoState()});
      },
    ),
    McpTool(
      name: 'delete_actor',
      risk: McpToolRisk.mutating,
      groups: const {McpToolGroups.level},
      idempotent: false,
      removesContent: true,
      title: 'Delete actor',
      description: 'Deletes an actor or an Outliner folder (type "Folder") and, by default, its children, as one undo '
          'step; undo brings them back with the same ids. keep_children moves them to the deleted node\'s parent (a '
          'folder\'s contents keep their world locations).',
      inputSchema: McpSchema.object({
        'id': McpSchema.string('The actor id.'),
        'keep_children': McpSchema.boolean('Reparent the children to the deleted actor\'s parent instead of deleting them. Default false.'),
      }, required: ['id']),
      handler: (args) {
        final refusal = refuseWhilePlaying();
        if (refusal != null) return refusal;
        final actor = actorOrThrow(args.string('id'));
        final before = vm.actors.map((a) => a.id).toSet();
        vm.deleteActorSubtreeWithTransaction(actor.id, keepChildren: args.boolean('keep_children'));
        final after = vm.actors.map((a) => a.id).toSet();
        return McpToolResult.json({
          'deleted_ids': before.difference(after).toList(),
          'actor_count': vm.actorCount,
          'undo': undoState(),
        });
      },
    ),
    McpTool(
      name: 'duplicate_actor',
      risk: McpToolRisk.mutating,
      groups: const {McpToolGroups.level},
      idempotent: false,
      title: 'Duplicate actor',
      description: 'Duplicates an actor and its children (Edit → Duplicate), as one undo step. Returns the new ids.',
      inputSchema: McpSchema.object({'id': McpSchema.string('The actor id.')}, required: ['id']),
      handler: (args) {
        final refusal = refuseWhilePlaying();
        if (refusal != null) return refusal;
        final actor = actorOrThrow(args.string('id'));
        final before = vm.actors.map((a) => a.id).toSet();
        vm.selectActor(actor);
        vm.duplicateSelectedActor();
        final created = vm.actors.where((a) => !before.contains(a.id)).toList();
        return McpToolResult.json({
          'actors': created.map(actorSummary).toList(),
          'undo': undoState(),
        });
      },
    ),
    McpTool(
      name: 'select_actors',
      risk: McpToolRisk.editorState,
      groups: const {McpToolGroups.level},
      idempotent: true,
      title: 'Select actors',
      description: 'Selects actors in the Outliner, viewport and Details panel (replaces the selection unless additive).',
      inputSchema: McpSchema.object({
        'ids': McpSchema.stringArray('The actor ids to select.'),
        'additive': McpSchema.boolean('Add to the current selection instead of replacing it. Default false.'),
      }, required: ['ids']),
      handler: (args) {
        final ids = args.stringList('ids');
        for (final id in ids) {
          actorOrThrow(id);
        }
        if (!args.boolean('additive')) vm.clearSelection();
        vm.selectActors(ids);
        return McpToolResult.json({'selected_actor_ids': vm.selectedActorIds.toList()});
      },
    ),
    McpTool(
      name: 'clear_selection',
      risk: McpToolRisk.editorState,
      groups: const {McpToolGroups.level},
      idempotent: true,
      title: 'Clear selection',
      description: 'Deselects every actor.',
      inputSchema: McpSchema.object(const {}),
      handler: (args) {
        vm.clearSelection();
        return McpToolResult.json({'selected_actor_ids': const <String>[]});
      },
    ),
    McpTool(
      name: 'save_level',
      risk: McpToolRisk.mutating,
      groups: const {McpToolGroups.level},
      idempotent: true,
      title: 'Save level',
      description: 'Saves the open level (File → Save Level): writes the level .lmas, regenerates the game\'s Dart '
          'code (lib/main.dart, lib/levels/<level>.dart, snake_case) and clears the dirty flag.',
      inputSchema: McpSchema.object(const {}),
      handler: (args) async {
        final refusal = refuseWhilePlaying();
        if (refusal != null) return refusal;
        await vm.saveLevelAndGenerateCode();
        final dir = vm.projectDirPath;
        final level = '$dir/contents/levels/${vm.activeLevelName}.lmas';
        final dart = '$dir/lib/levels/${dartFileName(vm.activeLevelName)}';
        return McpToolResult.json({
          'level_file': level,
          'level_file_exists': File(level).existsSync(),
          'generated_level_dart': dart,
          'generated_main_dart': '$dir/lib/main.dart',
          'is_dirty': vm.project.isDirty,
        });
      },
    ),
  ]);
}

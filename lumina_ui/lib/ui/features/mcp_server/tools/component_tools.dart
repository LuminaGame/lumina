import 'package:lumina/lumina.dart';

import 'package:lumina_ui/ui/core/property_editors/collision_section_editor.dart';
import 'package:lumina_ui/ui/features/details/models/component_property_registry.dart';
import 'package:lumina_ui/ui/features/details/models/editor_component_node.dart';
import 'package:lumina_ui/ui/features/details/services/blueprint_collision_overrides.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_component_registry.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_protocol.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_tool.dart';
import 'package:lumina_ui/ui/features/mcp_server/tools/blueprint_tool_support.dart';

/// The Physics section's keys, shared with the Blueprint
/// component tools.
const Set<String> kMcpPhysicsKeys = {
  'simulate',
  'overrideMass',
  'massKg',
  'enableGravity',
  'centerOfMassOffset',
  'friction',
  'restitution',
  'linearDamping',
  'angularDamping',
  'locks',
};

/// A collision edit as the Collision section makes it: a preset first (its
/// table), then object type, per-channel responses, Generate Overlap Events
/// and Collision Enabled on top.
Map<String, dynamic> mcpApplyCollision(McpArgs args, Map<String, dynamic> current, {LuminaCollisionProfile? base}) {
  var json = Map<String, dynamic>.from(current);
  final presetName = args.optionalString('preset');
  if (presetName != null) {
    final norm = presetName.toLowerCase().replaceAll('_', '').replaceAll(' ', '');
    final preset = LuminaCollisionPreset.values.where((p) => p.name.toLowerCase() == norm).firstOrNull;
    if (preset == null) {
      throw JsonRpcException(JsonRpcErrorCode.invalidParams,
          'Unknown preset "$presetName". Presets: NoCollision, BlockAll, OverlapAll, BlockAllDynamic, OverlapAllDynamic, Pawn, Trigger, Custom.');
    }
    json = CollisionJson.withPreset(json, preset, base: base);
  }
  final objectType = args.optionalString('object_type');
  if (objectType != null) {
    final t = CollisionJson.parseObjectType(objectType);
    if (t == null) {
      throw JsonRpcException(JsonRpcErrorCode.invalidParams,
          'Unknown object_type "$objectType". Types: ${CollisionObjectType.values.map((v) => v.name).join(', ')}.');
    }
    json = CollisionJson.withObjectType(json, t, base: base);
  }
  final responses = args.optionalObject('responses');
  if (responses != null) {
    for (final e in responses.entries) {
      final channel = CollisionJson.parseObjectType(e.key);
      final response = CollisionResponse.values.where((r) => r.name == e.value).firstOrNull;
      if (channel == null || response == null) {
        throw JsonRpcException(JsonRpcErrorCode.invalidParams,
            'responses maps a channel (${CollisionObjectType.values.map((v) => v.name).join(', ')}) to '
            '${CollisionResponse.values.map((v) => v.name).join(' / ')}; got ${e.key}: ${e.value}.');
      }
      json = CollisionJson.withResponse(json, channel, response, base: base);
    }
  }
  if (args.has('generate_overlap_events')) {
    json = CollisionJson.withGenerateOverlapEvents(json, args.boolean('generate_overlap_events'), base: base);
  }
  if (args.has('collision_enabled')) {
    json = CollisionJson.withCollisionEnabled(json, args.boolean('collision_enabled'), base: base);
  }
  return json;
}

/// The Physics section's keys of [raw], checked; merged over [current].
Map<String, dynamic> mcpApplyPhysics(Map<String, Object?> raw, Map<String, dynamic> current) {
  final unknown = raw.keys.where((k) => !kMcpPhysicsKeys.contains(k)).toList();
  if (unknown.isNotEmpty) {
    throw JsonRpcException(JsonRpcErrorCode.invalidParams,
        'Unknown physics key(s) ${unknown.join(', ')}. Keys: ${kMcpPhysicsKeys.join(', ')}.');
  }
  return {...current, ...raw};
}

/// Components of level actors: what the Details panel's Add
/// Component popover, the component header's remove button and the
/// Collision and Physics sections do. Each edit is one level undo step and
/// selects the actor, so Details shows it. Level-actor components are a flat
/// list without rename or reparent (the Details panel offers neither).
void registerComponentTools(McpToolRegistry registry, EditorViewModel vm) {
  const both = {McpToolGroups.component, McpToolGroups.blueprint};
  const component = {McpToolGroups.component};

  EditorActorNode actorOrThrow(String id) {
    final actor = vm.actors.where((a) => a.id == id).firstOrNull;
    if (actor == null) {
      throw JsonRpcException(JsonRpcErrorCode.invalidParams, 'No actor with id "$id". Call list_actors for the ids in the level.');
    }
    return actor;
  }

  /// An actor's own component by id, or by type when it has exactly one.
  EditorComponentNode componentOf(EditorActorNode actor, String wanted) {
    final own = actor.components.where((c) => !BlueprintCollisionOverrides.isOverride(c)).toList();
    final byId = own.where((c) => c.id == wanted).firstOrNull;
    if (byId != null) return byId;
    final byType = own.where((c) => c.type == wanted).toList();
    if (byType.length == 1) return byType.single;
    throw JsonRpcException(
      JsonRpcErrorCode.invalidParams,
      byType.length > 1
          ? '${actor.name} has ${byType.length} $wanted components; pass the id: ${byType.map((c) => c.id).join(', ')}.'
          : '${actor.name} has no component "$wanted". Components: ${own.map((c) => '${c.id} (${c.type})').join(', ')}.',
    );
  }

  /// A placed Blueprint's class component by id, name or unique type.
  LuminaBlueprintComponent? classComponentOf(List<LuminaBlueprintComponent> pool, String wanted) {
    final exact = pool.where((c) => c.id == wanted || c.name == wanted).firstOrNull;
    if (exact != null) return exact;
    final byType = pool.where((c) => c.type == wanted).toList();
    return byType.length == 1 ? byType.single : null;
  }

  Map<String, Object?> componentJson(EditorComponentNode c) =>
      {'id': c.id, 'type': c.type, 'name': c.name, 'enabled': c.enabled, 'properties': c.properties};

  void focus(EditorActorNode actor) {
    vm.clearSelection();
    vm.selectActors([actor.id]);
  }

  final actorIdArg = McpSchema.string('The actor id (list_actors).');
  final componentArg = McpSchema.string('The component: its id (get_actor), or its type when the actor has one of that type. '
      'For a placed Blueprint: the Blueprint class\'s component id or name.');

  registry.registerAll([
    McpTool(
      name: 'list_component_types',
      risk: McpToolRisk.readOnly,
      groups: both,
      title: 'List component types',
      description: 'The component types a user can add. context "actor" (default): the Details panel\'s Add Component '
          'popover — each type\'s sections, note and properties [{id, label, group, editor, unit, min, max, default, '
          'enum_values}] (set_actor_property "<component id>.<property id>" edits them). context "blueprint": the '
          'Blueprint editor\'s Components panel — display name, category, scene component, availability (with the gap '
          'reason when greyed out), collision capability and properties [{name, dart_field, type, default, min, max, '
          'enum_options}].',
      inputSchema: McpSchema.object({
        'context': McpSchema.string('"actor" (default) or "blueprint".', enumValues: const ['actor', 'blueprint']),
      }),
      handler: (args) {
        if ((args.optionalString('context') ?? 'actor') == 'blueprint') {
          final types = BlueprintComponentRegistry.registeredComponents;
          return McpToolResult.json({
            'count': types.length,
            'types': [
              for (final t in types)
                {
                  'type': t.typeName,
                  'display_name': t.displayName,
                  'category': t.category,
                  'is_scene_component': t.isSceneComponent,
                  'is_available': t.isAvailable,
                  'gap_reason': t.gapReason,
                  'collision_capable': t.collisionCapable,
                  'properties': [
                    for (final p in t.properties)
                      {
                        'name': p.name,
                        'dart_field': p.dartField,
                        'type': p.type.name,
                        'default': p.defaultValue,
                        'min': p.min,
                        'max': p.max,
                        'enum_options': p.enumOptions,
                      },
                  ],
                },
            ],
          });
        }
        final types = ComponentPropertyRegistry.descriptors.values.toList();
        return McpToolResult.json({
          'count': types.length,
          'types': [
            for (final d in types)
              {
                'type': d.type,
                'sections': d.sections,
                'note': d.note,
                'collision_capable': BlueprintComponentRegistry.isCollisionCapable(d.type),
                'properties': [
                  for (final p in d.properties)
                    {
                      'id': p.id,
                      'label': p.label,
                      'group': p.group,
                      'editor': p.editor.name,
                      'unit': p.unit,
                      'min': p.min,
                      'max': p.max,
                      'default': p.defaultValue,
                      'enum_values': p.enumValues,
                    },
                ],
              },
          ],
        });
      },
    ),
    McpTool(
      name: 'add_actor_component',
      risk: McpToolRisk.mutating,
      groups: component,
      idempotent: false,
      title: 'Add actor component',
      description: 'Details → Add Component on a level actor (one undo step). type is a list_component_types (context '
          '"actor") type. Returns the component with its new id; set its properties with set_actor_property '
          '"<id>.<property>". A level actor\'s components cannot be renamed or reparented (the Details panel offers '
          'neither); a Blueprint\'s can (rename_/reparent_blueprint_component).',
      inputSchema: McpSchema.object({
        'actor_id': actorIdArg,
        'type': McpSchema.string('The component type, e.g. "LuminaPointLightComponent".'),
      }, required: ['actor_id', 'type']),
      handler: (args) {
        final refusal = mcpRefuseWhilePlaying(vm);
        if (refusal != null) return refusal;
        final actor = actorOrThrow(args.string('actor_id'));
        final type = args.string('type');
        if (!ComponentPropertyRegistry.descriptors.containsKey(type)) {
          return McpToolResult.error('Unknown component type "$type". Types: ${ComponentPropertyRegistry.descriptors.keys.join(', ')}.');
        }
        final added = vm.addComponentWithTransaction(actor.id, type);
        if (added == null) return McpToolResult.error('The component was not added.');
        focus(actor);
        return McpToolResult.json({'actor_id': actor.id, 'component': componentJson(added)});
      },
    ),
    McpTool(
      name: 'remove_actor_component',
      risk: McpToolRisk.destructive,
      groups: component,
      title: 'Remove actor component',
      description: 'Details → × on one component of a level actor: removes exactly that component (one undo step that '
          'puts it back at its position with its id and properties).',
      inputSchema: McpSchema.object({'actor_id': actorIdArg, 'component': componentArg}, required: ['actor_id', 'component']),
      handler: (args) {
        final refusal = mcpRefuseWhilePlaying(vm);
        if (refusal != null) return refusal;
        final actor = actorOrThrow(args.string('actor_id'));
        final comp = componentOf(actor, args.string('component'));
        vm.removeComponentWithTransaction(actor.id, comp.id);
        focus(actor);
        return McpToolResult.json({'actor_id': actor.id, 'removed': componentJson(comp)});
      },
    ),
    McpTool(
      name: 'set_actor_component_enabled',
      risk: McpToolRisk.mutating,
      groups: component,
      idempotent: true,
      title: 'Enable / disable actor component',
      description: 'Turns one component of a level actor on or off (Details shows "Component Disabled"); one undo step.',
      inputSchema: McpSchema.object({
        'actor_id': actorIdArg,
        'component': componentArg,
        'enabled': McpSchema.boolean('true to enable, false to disable.'),
      }, required: ['actor_id', 'component', 'enabled']),
      handler: (args) {
        final refusal = mcpRefuseWhilePlaying(vm);
        if (refusal != null) return refusal;
        final actor = actorOrThrow(args.string('actor_id'));
        final comp = componentOf(actor, args.string('component'));
        vm.setComponentEnabledWithTransaction(actor.id, comp.id, args.boolean('enabled'));
        focus(actor);
        return McpToolResult.json({'actor_id': actor.id, 'component': componentJson(comp)});
      },
    ),
    McpTool(
      name: 'set_actor_collision',
      risk: McpToolRisk.mutating,
      groups: component,
      idempotent: true,
      title: 'Set actor collision',
      description: 'The Collision section of a collision-capable component (one undo step): a preset (NoCollision, '
          'BlockAll, OverlapAll, BlockAllDynamic, OverlapAllDynamic, Pawn, Trigger, Custom) fills object type and '
          'responses from its table, then object_type, responses {channel: ignore|overlap|block}, '
          'generate_overlap_events and collision_enabled override it. On a placed Blueprint the component is the '
          'class\'s, and the edit is this instance\'s override (saved in the level).',
      inputSchema: McpSchema.object({
        'actor_id': actorIdArg,
        'component': componentArg,
        'preset': McpSchema.string('The collision preset.'),
        'object_type': McpSchema.string('worldStatic, worldDynamic, pawn, physicsBody, vehicle, destructible, … (makes it Custom).'),
        'responses': {'type': 'object', 'description': '{channel: "ignore" | "overlap" | "block"} (makes it Custom).'},
        'generate_overlap_events': McpSchema.boolean('Generate Overlap Events.'),
        'collision_enabled': McpSchema.boolean('Collision Enabled (makes it Custom).'),
      }, required: ['actor_id', 'component']),
      handler: (args) {
        final refusal = mcpRefuseWhilePlaying(vm);
        if (refusal != null) return refusal;
        final actor = actorOrThrow(args.string('actor_id'));
        final wanted = args.string('component');
        if (actor.blueprintClass != null) {
          final pool = BlueprintCollisionOverrides.collisionComponentsOf(actor, vm.projectDirPath);
          final c = classComponentOf(pool, wanted);
          if (c == null) {
            return McpToolResult.error('${actor.name}\'s Blueprint has no collision component "$wanted". '
                'Collision components: ${pool.map((c) => '${c.id} (${c.name}, ${c.type})').join(', ')}.');
          }
          final doc = BlueprintCollisionOverrides.documentOf(vm.projectDirPath, actor.blueprintClass!);
          final json = mcpApplyCollision(args, BlueprintCollisionOverrides.collisionOf(actor, c),
              base: BlueprintCollisionOverrides.baseOf(doc, c));
          vm.setActorComponentCollision(actor.id, c.id, json, blueprintComponent: c);
          focus(actor);
          final override = BlueprintCollisionOverrides.overrideOf(actor, c.id);
          return McpToolResult.json({
            'actor_id': actor.id,
            'blueprint_component': c.id,
            'override_component': override == null ? null : componentJson(override),
            'collision': json,
          });
        }
        final comp = componentOf(actor, wanted);
        if (!BlueprintComponentRegistry.isCollisionCapable(comp.type)) {
          return McpToolResult.error('${comp.type} has no Collision section (not a collision component).');
        }
        final json = mcpApplyCollision(args, CollisionJson.of(comp.properties));
        vm.setActorComponentCollision(actor.id, comp.id, json);
        focus(actor);
        return McpToolResult.json({'actor_id': actor.id, 'component': componentJson(comp), 'collision': json});
      },
    ),
    McpTool(
      name: 'set_actor_physics',
      risk: McpToolRisk.mutating,
      groups: component,
      idempotent: true,
      title: 'Set actor physics',
      description: 'The Physics section of a placed Blueprint\'s collision shape or static mesh (one undo step, the '
          'instance\'s override saved in the level): physics {simulate, overrideMass, massKg, enableGravity, '
          'centerOfMassOffset, friction, restitution, linearDamping, angularDamping, locks{position, rotation}}. Other '
          'actors have no Physics section.',
      inputSchema: McpSchema.object({
        'actor_id': actorIdArg,
        'component': componentArg,
        'physics': {'type': 'object', 'description': 'The Physics section\'s keys to set.'},
      }, required: ['actor_id', 'component', 'physics']),
      handler: (args) {
        final refusal = mcpRefuseWhilePlaying(vm);
        if (refusal != null) return refusal;
        final actor = actorOrThrow(args.string('actor_id'));
        final pool = actor.blueprintClass == null
            ? const <LuminaBlueprintComponent>[]
            : BlueprintCollisionOverrides.physicsComponentsOf(actor, vm.projectDirPath);
        if (pool.isEmpty) {
          return McpToolResult.error('The Details panel has no Physics section for this actor (${actor.name}, ${actor.type}): '
              'only a placed Blueprint\'s collision shapes and static meshes have one.');
        }
        final wanted = args.string('component');
        final c = classComponentOf(pool, wanted);
        if (c == null) {
          return McpToolResult.error('No physics component "$wanted". Physics components: '
              '${pool.map((c) => '${c.id} (${c.name}, ${c.type})').join(', ')}.');
        }
        final json = mcpApplyPhysics(args.optionalObject('physics')!, BlueprintCollisionOverrides.physicsOf(actor, c));
        vm.setActorComponentPhysics(actor.id, c, json);
        focus(actor);
        final override = BlueprintCollisionOverrides.overrideOf(actor, c.id);
        return McpToolResult.json({
          'actor_id': actor.id,
          'blueprint_component': c.id,
          'override_component': override == null ? null : componentJson(override),
          'physics': json,
        });
      },
    ),
  ]);
}

import '../../details/models/component_property_registry.dart';
import '../../details/services/multi_edit_service.dart';
import '../../main_editor/view_models/editor_view_model.dart';
import '../services/mcp_protocol.dart';
import '../services/mcp_tool.dart';
import 'blueprint_tool_support.dart' show mcpRefuseWhilePlaying;
import 'core_tools.dart' show mcpUndoState;

/// The multi-select Details panel as MCP tools: several
/// actors selected and edited at once — shared transform rows (absolute, or
/// relative per axis as a scrub is), a shared component's property and
/// enabled state, and the × that removes a component type from all of them.
/// Every call selects the actors, so the panel shows the result, and is one
/// undo step.
void registerDetailsTools(McpToolRegistry registry, EditorViewModel vm) {
  const details = {McpToolGroups.details};
  const units = 'Units: centimetres, degrees, Z up.';

  List<EditorActorNode> actorsOrThrow(List<String> ids) {
    if (ids.isEmpty) throw const JsonRpcException(JsonRpcErrorCode.invalidParams, 'ids must name at least one actor');
    return [
      for (final id in ids)
        vm.actors.where((a) => a.id == id).firstOrNull ??
            (throw JsonRpcException(JsonRpcErrorCode.invalidParams, 'No actor with id "$id". Call list_actors for the ids.')),
    ];
  }

  /// Selects [actors] as a click with Ctrl on each Outliner row does.
  void select(List<EditorActorNode> actors) {
    vm.clearSelection();
    vm.selectActors([for (final a in actors) a.id]);
  }

  List<Map<String, Object?>> lockedOf(List<EditorActorNode> actors) => [
        for (final a in actors)
          if (a.isLocked) {'id': a.id, 'reason': 'locked (set_actor_property locked=false first)'},
      ];

  Map<String, Object?> vector(List<double> common, List<bool> mixed) => {
        'common': [for (var i = 0; i < 3; i++) mixed[i] ? null : common[i]],
        'mixed': mixed,
      };

  Map<String, Object?> multiEdit(List<EditorActorNode> actors) {
    final view = MultiEditService.computeMultiEditView(actors);
    return {
      'ids': [for (final a in actors) a.id],
      'count': actors.length,
      'location': vector(view.locationCommon, view.locationMixed),
      'rotation': vector(view.rotationCommon, view.rotationMixed),
      'scale': vector(view.scaleCommon, view.scaleMixed),
      'visible': view.isMixedVisible ? 'mixed' : view.commonVisible,
      'locked': view.isMixedLocked ? 'mixed' : view.commonLocked,
      'components': [
        for (final block in view.components)
          {
            'component_type': block.componentType,
            'name': block.componentName,
            'enabled': block.isMixedEnabled ? 'mixed' : block.commonEnabled,
            'properties': [
              for (final p in block.properties)
                {
                  'id': p.propertyId,
                  'label': p.descriptor.label,
                  'mixed': p.isMixed,
                  'value': p.isMixed ? null : (p.commonVector ?? p.commonValue),
                  if (p.isMixedPerAxis != null) 'mixed_per_axis': p.isMixedPerAxis,
                },
            ],
          },
      ],
    };
  }

  /// Checks [type] is a component type some of [actors] have; returns the
  /// actors that have it, or a tool error naming the types they share.
  (List<EditorActorNode>, McpToolResult?) withComponent(List<EditorActorNode> actors, String type) {
    final having = actors.where((a) => a.components.any((c) => c.type == type)).toList();
    if (having.isEmpty) {
      final shared = MultiEditService.computeMultiEditView(actors).components.map((b) => b.componentType).toList();
      return (
        having,
        McpToolResult.error('None of these actors has a "$type" component. Types they all share: '
            '${shared.isEmpty ? '(none)' : shared.join(', ')}; get_actor lists each actor\'s components.'),
      );
    }
    return (having, null);
  }

  registry.registerAll([
    McpTool(
      name: 'get_multi_edit',
      risk: McpToolRisk.readOnly,
      groups: details,
      title: 'Get multi-edit view',
      description: 'Selects the actors and returns what the multi-select Details panel shows: location, rotation and '
          'scale per axis (common value, or null where mixed), visibility and lock, and the component types every '
          'actor has, with each property\'s common value or mixed and the enabled state. $units',
      inputSchema: McpSchema.object({'ids': McpSchema.stringArray('The actor ids (two or more for a multi-edit).')},
          required: ['ids']),
      handler: (args) {
        final actors = actorsOrThrow(args.stringList('ids'));
        select(actors);
        return McpToolResult.json(multiEdit(actors));
      },
    ),
    McpTool(
      name: 'set_actors_transform',
      risk: McpToolRisk.mutating,
      groups: details,
      idempotent: false,
      title: 'Set actors transform',
      description: 'The multi-select Details transform rows: sets location, rotation and/or scale on every actor at '
          'once — absolute, or added to each actor\'s own value with relative (a scrub), on one axis only with axis '
          '(0 = X, 1 = Y, 2 = Z; the other axes keep each actor\'s values). One undo step for the call. Locked '
          'actors are skipped and listed. $units',
      inputSchema: McpSchema.object({
        'ids': McpSchema.stringArray('The actor ids.'),
        'location': McpSchema.vector3('[x, y, z] in cm.'),
        'rotation': McpSchema.vector3('[roll, pitch, yaw] in degrees.'),
        'scale': McpSchema.vector3('[x, y, z] factors.'),
        'relative': McpSchema.boolean('Add the values to each actor\'s own instead of setting them. Default false.'),
        'axis': McpSchema.integer('Only this axis (0, 1 or 2) of the vectors given.'),
      }, required: ['ids']),
      handler: (args) {
        final refusal = mcpRefuseWhilePlaying(vm);
        if (refusal != null) return refusal;
        final actors = actorsOrThrow(args.stringList('ids'));
        final location = args.optionalVector3('location');
        final rotation = args.optionalVector3('rotation');
        final scale = args.optionalVector3('scale');
        if (location == null && rotation == null && scale == null) {
          return McpToolResult.error('Give at least one of location, rotation, scale.');
        }
        final axis = args.has('axis') ? args.integer('axis') : null;
        if (axis != null && (axis < 0 || axis > 2)) return McpToolResult.error('axis must be 0 (X), 1 (Y) or 2 (Z).');
        final relative = args.boolean('relative');
        final skipped = lockedOf(actors);
        final changed = [for (final a in actors) if (!a.isLocked) a.id];
        select(actors);
        if (changed.isNotEmpty) {
          if (location != null) vm.updateActorLocation(location, relative: relative, axis: axis);
          if (rotation != null) vm.updateActorRotation(rotation, relative: relative, axis: axis);
          if (scale != null) vm.updateActorScale(scale, relative: relative, axis: axis);
        }
        return McpToolResult.json({
          'changed': changed,
          'skipped': skipped,
          'actors': [
            for (final a in actors) {'id': a.id, 'location': a.location, 'rotation': a.rotation, 'scale': a.scale},
          ],
          'undo': mcpUndoState(vm.transactions),
        });
      },
    ),
    McpTool(
      name: 'set_actors_component_property',
      risk: McpToolRisk.mutating,
      groups: details,
      idempotent: true,
      title: 'Set actors component property',
      description: 'A shared component\'s property row in the multi-select Details panel: sets the property on every '
          'actor that has a component of that type (list_component_types lists types and properties), in one undo '
          'step. For a vector property, axis sets one axis and relative adds to each actor\'s own value. Locked '
          'actors, and actors without the component, are skipped and listed.',
      inputSchema: McpSchema.object({
        'ids': McpSchema.stringArray('The actor ids.'),
        'component_type': McpSchema.string('The component type, e.g. "LuminaPointLightComponent".'),
        'property': McpSchema.string('The property id, e.g. "intensity".'),
        'value': McpSchema.any('The new value, of the property\'s type ([x, y, z] for a vector).'),
        'relative': McpSchema.boolean('Vector properties with axis: add to each actor\'s value. Default false.'),
        'axis': McpSchema.integer('Vector properties: only this axis (0, 1 or 2).'),
      }, required: ['ids', 'component_type', 'property', 'value']),
      handler: (args) {
        final refusal = mcpRefuseWhilePlaying(vm);
        if (refusal != null) return refusal;
        final actors = actorsOrThrow(args.stringList('ids'));
        final type = args.string('component_type');
        final property = args.string('property');
        final (having, missing) = withComponent(actors, type);
        if (missing != null) return missing;
        final descriptor = ComponentPropertyRegistry.descriptors[type];
        if (descriptor != null && !descriptor.properties.any((p) => p.id == property)) {
          return McpToolResult.error('"$type" has no property "$property". Properties: '
              '${descriptor.properties.map((p) => p.id).join(', ')}.');
        }
        final axis = args.has('axis') ? args.integer('axis') : null;
        final value = args['value'];
        if (axis != null && (axis < 0 || axis > 2 || value is! List || value.length != 3)) {
          return McpToolResult.error('With axis (0, 1 or 2) the value is a vector [x, y, z].');
        }
        select(actors);
        vm.applyPropertyToSelection(type, property, value, relative: args.boolean('relative'), axis: axis);
        return McpToolResult.json({
          'changed': [for (final a in having) if (!a.isLocked) a.id],
          'skipped': [
            ...lockedOf(having),
            for (final a in actors)
              if (!having.contains(a)) {'id': a.id, 'reason': 'has no $type component'},
          ],
          'undo': mcpUndoState(vm.transactions),
        });
      },
    ),
    McpTool(
      name: 'set_actors_component_enabled',
      risk: McpToolRisk.mutating,
      groups: details,
      idempotent: true,
      title: 'Set actors component enabled',
      description: 'The enabled checkbox of a shared component in the multi-select Details panel: enables or disables '
          'the component of that type on every actor that has one, in one undo step.',
      inputSchema: McpSchema.object({
        'ids': McpSchema.stringArray('The actor ids.'),
        'component_type': McpSchema.string('The component type.'),
        'enabled': McpSchema.boolean('Whether the component is enabled.'),
      }, required: ['ids', 'component_type', 'enabled']),
      handler: (args) {
        final refusal = mcpRefuseWhilePlaying(vm);
        if (refusal != null) return refusal;
        final actors = actorsOrThrow(args.stringList('ids'));
        final type = args.string('component_type');
        final (having, missing) = withComponent(actors, type);
        if (missing != null) return missing;
        select(actors);
        final first = having.first.components.firstWhere((c) => c.type == type);
        vm.toggleComponentEnabledWithTransaction('', first.id, args.boolean('enabled'));
        // The method does not notify (the panel's checkbox rebuilds itself).
        vm.notifyListeners();
        return McpToolResult.json({
          'changed': [for (final a in having) a.id],
          'enabled': args.boolean('enabled'),
          'undo': mcpUndoState(vm.transactions),
        });
      },
    ),
    McpTool(
      name: 'remove_actors_component',
      risk: McpToolRisk.destructive,
      groups: details,
      idempotent: false,
      removesContent: true,
      title: 'Remove actors component',
      description: 'The × of a shared component in the multi-select Details panel: removes every component of that '
          'type from every actor (remove_actor_component removes one component of one actor). One undo step that '
          'puts each back where it was.',
      inputSchema: McpSchema.object({
        'ids': McpSchema.stringArray('The actor ids.'),
        'component_type': McpSchema.string('The component type to remove.'),
      }, required: ['ids', 'component_type']),
      handler: (args) {
        final refusal = mcpRefuseWhilePlaying(vm);
        if (refusal != null) return refusal;
        final actors = actorsOrThrow(args.stringList('ids'));
        final type = args.string('component_type');
        final (having, missing) = withComponent(actors, type);
        if (missing != null) return missing;
        final count = [for (final a in actors) ...a.components.where((c) => c.type == type)].length;
        select(actors);
        vm.removeComponentTypeFromSelectionWithTransaction(type);
        return McpToolResult.json({
          'removed_from': [for (final a in having) a.id],
          'removed_count': count,
          'undo': mcpUndoState(vm.transactions),
        });
      },
    ),
  ]);
}

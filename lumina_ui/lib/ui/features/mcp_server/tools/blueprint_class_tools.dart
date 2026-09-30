import 'package:lumina/lumina.dart';

import '../../../core/property_editors/collision_section_editor.dart';
import '../../main_editor/view_models/editor_view_model.dart';
import '../../sub_editors/models/blueprint_component_registry.dart';
import '../../sub_editors/view_models/blueprint_editor_view_model.dart';
import '../services/mcp_editor_sessions.dart';
import '../services/mcp_protocol.dart';
import '../services/mcp_tool.dart';
import 'blueprint_tool_support.dart';
import 'component_tools.dart' show mcpApplyCollision, mcpApplyPhysics;
import 'rotation_convention.dart';

/// A Blueprint class's Components panel, Class Defaults and parent class as
/// MCP tools. Each edit is one undo step on the Blueprint
/// tab and selects the component it touched. The Level Blueprint has no
/// components, class defaults or parent class.
void registerBlueprintClassTools(McpToolRegistry registry, EditorViewModel vm, McpEditorSessions sessions) {
  const component = {McpToolGroups.component};
  const parentClasses = ['LuminaActor', 'LuminaPawn', 'LuminaCharacter', BlueprintEditorViewModel.gameModeParent];

  Future<BlueprintEditorViewModel> classEditor(McpArgs args) async {
    final editor = await sessions.blueprintEditor(args.string('asset'));
    if (McpEditorSessions.isLevelBlueprint(editor)) {
      throw const JsonRpcException(JsonRpcErrorCode.invalidParams,
          'The Level Blueprint has no components, class defaults or parent class (its editor has no Components panel).');
    }
    return editor;
  }

  LuminaBlueprintComponent componentOf(BlueprintEditorViewModel editor, String wanted) {
    final comps = editor.document.components;
    final found = comps.where((c) => c.id == wanted || c.name == wanted).firstOrNull;
    if (found != null) return found;
    throw JsonRpcException(JsonRpcErrorCode.invalidParams,
        'No component "$wanted" in ${editor.fileBasename}. Components: ${comps.map((c) => '${c.id} (${c.name}, ${c.type})').join(', ')}.');
  }

  Map<String, Object?> componentJson(LuminaBlueprintComponent c) =>
      {'id': c.id, 'type': c.type, 'name': c.name, 'parent_id': c.parentId, 'properties': c.properties};

  Map<String, Object?> treeOf(BlueprintEditorViewModel editor) => {
        'components': [for (final c in editor.document.components) componentJson(c)],
        'undo': mcpBlueprintUndo(editor),
      };

  /// [value] checked against [schema]'s type, limits and options.
  Object? checkValue(ComponentPropertySchema schema, Object? value) {
    Never bad(String what) =>
        throw JsonRpcException(JsonRpcErrorCode.invalidParams, '${schema.name} (${schema.dartField}) takes $what; got ${value.runtimeType} $value.');
    switch (schema.type) {
      case ComponentPropertyType.number:
        if (value is! num) bad('a number');
        final v = value.toDouble();
        if (v < schema.lowerLimit || v > schema.upperLimit) bad('a number in ${schema.lowerLimit}–${schema.upperLimit}');
        return v;
      case ComponentPropertyType.boolean:
        if (value is! bool) bad('true or false');
        return value;
      case ComponentPropertyType.string:
      case ComponentPropertyType.assetReference:
        if (value is! String) bad('a string');
        return value;
      case ComponentPropertyType.enumType:
        if (value is! String || (schema.enumOptions.isNotEmpty && !schema.enumOptions.contains(value))) {
          bad('one of ${schema.enumOptions.join(', ')}');
        }
        return value;
      case ComponentPropertyType.vector3:
        if (value is! List || value.length != 3 || value.any((e) => e is! num)) bad('[x, y, z]');
        return [for (final e in value) (e as num).toDouble()];
      case ComponentPropertyType.color:
        if (value is! String || !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(value.trim())) bad('a colour "#RRGGBB"');
        return value.trim().toUpperCase();
    }
  }

  final assetArg = McpSchema.string(kBlueprintAssetArg);
  final componentArg = McpSchema.string('The component id or name (get_blueprint).');

  McpTool tool({
    required String name,
    required String title,
    required String description,
    required Map<String, Object?> schema,
    required Future<Map<String, Object?>> Function(McpArgs args, BlueprintEditorViewModel editor) run,
    McpToolRisk risk = McpToolRisk.mutating,
    bool idempotent = false,
    bool removesContent = false,
  }) =>
      McpTool(
        name: name,
        title: title,
        description: description,
        inputSchema: schema,
        risk: risk,
        groups: component,
        idempotent: idempotent,
        removesContent: removesContent,
        handler: (args) async {
          final refusal = mcpRefuseWhilePlaying(vm);
          if (refusal != null) return refusal;
          final editor = await classEditor(args);
          return McpToolResult.json(await run(args, editor));
        },
      );

  registry.registerAll([
    tool(
      name: 'add_blueprint_component',
      title: 'Add Blueprint component',
      description: 'Components panel → Add: a component of type (list_component_types context "blueprint") under '
          'parent (a scene component id; default the root). A greyed-out type is refused with its gap reason. One undo '
          'step on the Blueprint tab; returns the component with its id.',
      schema: McpSchema.object({
        'asset': assetArg,
        'type': McpSchema.string('The component type, e.g. "LuminaStaticMeshComponent".'),
        'parent': McpSchema.string('The parent scene component id or name. Default: the root.'),
      }, required: ['asset', 'type']),
      run: (args, editor) async {
        final type = args.string('type');
        final desc = BlueprintComponentRegistry.getDescriptor(type);
        if (desc == null) {
          throw JsonRpcException(JsonRpcErrorCode.invalidParams,
              'Unknown component type "$type". Types: ${BlueprintComponentRegistry.registeredComponents.map((t) => t.typeName).join(', ')}.');
        }
        if (!desc.isAvailable) {
          throw JsonRpcException(JsonRpcErrorCode.invalidParams, '$type is not available in Blueprints yet: ${desc.gapReason}.');
        }
        final parent = args.optionalString('parent');
        final parentId = parent == null ? null : componentOf(editor, parent).id;
        final added = editor.addComponent(type, parentId: parentId);
        if (added == null) throw const JsonRpcException(JsonRpcErrorCode.invalidParams, 'The component was not added.');
        editor.selectComponent(added.id);
        return {'component': componentJson(added), ...treeOf(editor)};
      },
    ),
    tool(
      name: 'remove_blueprint_component',
      title: 'Remove Blueprint component',
      risk: McpToolRisk.destructive,
      removesContent: true,
      description: 'Components panel → Delete: removes the component; its children move to its parent. One undo step.',
      schema: McpSchema.object({'asset': assetArg, 'component': componentArg}, required: ['asset', 'component']),
      run: (args, editor) async {
        final c = componentOf(editor, args.string('component'));
        if (!editor.removeComponent(c.id)) {
          throw JsonRpcException(JsonRpcErrorCode.invalidParams, '${c.name} cannot be removed (the root stays).');
        }
        return {'removed': componentJson(c), ...treeOf(editor)};
      },
    ),
    tool(
      name: 'rename_blueprint_component',
      title: 'Rename Blueprint component',
      idempotent: true,
      description: 'Renames a component. The name is a Dart identifier (letters, digits, _; not starting with a digit), '
          'unique case-insensitively in the Blueprint. One undo step.',
      schema: McpSchema.object({'asset': assetArg, 'component': componentArg, 'name': McpSchema.string('The new name.')},
          required: ['asset', 'component', 'name']),
      run: (args, editor) async {
        final c = componentOf(editor, args.string('component'));
        final name = args.string('name').trim();
        if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(name)) {
          throw JsonRpcException(JsonRpcErrorCode.invalidParams, '"$name" is not an identifier (letters, digits, _; no spaces).');
        }
        if (editor.document.components.any((o) => o.id != c.id && o.name.toLowerCase() == name.toLowerCase())) {
          throw JsonRpcException(JsonRpcErrorCode.invalidParams, 'A component is already named "$name".');
        }
        editor.renameComponent(c.id, name);
        editor.selectComponent(c.id);
        return {'component': componentJson(editor.getComponent(c.id)!), ...treeOf(editor)};
      },
    ),
    tool(
      name: 'reparent_blueprint_component',
      title: 'Reparent Blueprint component',
      idempotent: true,
      description: 'Attaches a scene component to another scene component (drag in the Components panel); parent null '
          'attaches it to the root. Refused when it would make a cycle or the parent is not a scene component.',
      schema: McpSchema.object({
        'asset': assetArg,
        'component': componentArg,
        'parent': {'type': ['string', 'null'], 'description': 'The new parent id or name, or null for the root.'},
      }, required: ['asset', 'component']),
      run: (args, editor) async {
        final c = componentOf(editor, args.string('component'));
        final parentArg = args['parent'];
        final parentId = parentArg == null ? null : componentOf(editor, parentArg as String).id;
        if (!editor.canReparent(c.id, parentId)) {
          throw JsonRpcException(JsonRpcErrorCode.invalidParams,
              '${c.name} cannot be attached to ${parentId ?? 'the root'} (a cycle, the same parent, or not a scene component).');
        }
        editor.reparent(c.id, parentId);
        editor.selectComponent(c.id);
        return {'component': componentJson(editor.getComponent(c.id)!), ...treeOf(editor)};
      },
    ),
    tool(
      name: 'duplicate_blueprint_component',
      title: 'Duplicate Blueprint component',
      description: 'Components panel → Duplicate: a copy of the component (and its properties) beside it. One undo step.',
      schema: McpSchema.object({'asset': assetArg, 'component': componentArg}, required: ['asset', 'component']),
      run: (args, editor) async {
        final c = componentOf(editor, args.string('component'));
        final copy = editor.duplicateComponent(c.id);
        if (copy == null) throw JsonRpcException(JsonRpcErrorCode.invalidParams, '${c.name} cannot be duplicated.');
        editor.selectComponent(copy.id);
        return {'component': componentJson(copy), ...treeOf(editor)};
      },
    ),
    tool(
      name: 'set_blueprint_component_property',
      title: 'Set Blueprint component property',
      idempotent: true,
      description: 'Details → a component property (one undo step). property is the schema\'s dart_field or name '
          '(list_component_types context "blueprint"); value is checked against its type, limits and options '
          '(asset references are project-relative .lmas paths).',
      schema: McpSchema.object({
        'asset': assetArg,
        'component': componentArg,
        'property': McpSchema.string('The dart_field (e.g. "staticMeshAsset") or display name.'),
        'value': McpSchema.any('The value.'),
      }, required: ['asset', 'component', 'property', 'value']),
      run: (args, editor) async {
        final c = componentOf(editor, args.string('component'));
        final prop = args.string('property');
        final schemas = BlueprintComponentRegistry.getSchema(c.type);
        final schema = schemas.where((s) => s.dartField == prop || s.name == prop).firstOrNull;
        if (schema == null) {
          throw JsonRpcException(JsonRpcErrorCode.invalidParams,
              '${c.type} has no property "$prop". Properties: ${schemas.map((s) => s.dartField).join(', ')}.');
        }
        editor.commitProperty(c.id, schema.dartField, checkValue(schema, args['value']));
        editor.selectComponent(c.id);
        return {'component': componentJson(editor.getComponent(c.id)!), 'undo': mcpBlueprintUndo(editor)};
      },
    ),
    tool(
      name: 'set_blueprint_component_transform',
      title: 'Set Blueprint component transform',
      idempotent: true,
      description: 'Moves a scene component relative to its parent (cm, degrees), as the viewport gizmo does: one undo step.',
      schema: McpSchema.object({
        'asset': assetArg,
        'component': componentArg,
        'location': McpSchema.vector3('Relative location [x, y, z] in cm.'),
        'rotation': McpSchema.vector3('Relative rotation $kMcpRotationConvention (the same triple as a level '
            'actor).'),
        'scale': McpSchema.vector3('Relative scale [x, y, z].'),
      }, required: ['asset', 'component']),
      run: (args, editor) async {
        final c = componentOf(editor, args.string('component'));
        if (!editor.canTransformComponent(c.id)) {
          throw JsonRpcException(JsonRpcErrorCode.invalidParams, '${c.name} (${c.type}) is not a scene component; it has no transform.');
        }
        editor.beginComponentTransformDrag(c.id);
        editor.updateComponentTransform(c.id,
            location: args.optionalVector3('location'), rotation: args.optionalVector3('rotation'), scale: args.optionalVector3('scale'));
        editor.endComponentTransformDrag();
        editor.selectComponent(c.id);
        return {'component': componentJson(editor.getComponent(c.id)!), 'undo': mcpBlueprintUndo(editor)};
      },
    ),
    tool(
      name: 'set_blueprint_component_collision',
      title: 'Set Blueprint component collision',
      idempotent: true,
      description: 'A collision component\'s Collision section in the Blueprint (one undo step): preset, then '
          'object_type, responses {channel: ignore|overlap|block}, generate_overlap_events, collision_enabled.',
      schema: McpSchema.object({
        'asset': assetArg,
        'component': componentArg,
        'preset': McpSchema.string('NoCollision, BlockAll, OverlapAll, BlockAllDynamic, OverlapAllDynamic, Pawn, Trigger, Custom.'),
        'object_type': McpSchema.string('The object type (makes it Custom).'),
        'responses': {'type': 'object', 'description': '{channel: "ignore" | "overlap" | "block"}.'},
        'generate_overlap_events': McpSchema.boolean('Generate Overlap Events.'),
        'collision_enabled': McpSchema.boolean('Collision Enabled.'),
      }, required: ['asset', 'component']),
      run: (args, editor) async {
        final c = componentOf(editor, args.string('component'));
        if (!BlueprintComponentRegistry.isCollisionCapable(c.type)) {
          throw JsonRpcException(JsonRpcErrorCode.invalidParams, '${c.type} has no Collision section.');
        }
        final json = mcpApplyCollision(args, CollisionJson.of(c.properties), base: editor.collisionBase(c.id));
        editor.setComponentCollision(c.id, json);
        editor.selectComponent(c.id);
        return {'component': componentJson(editor.getComponent(c.id)!), 'undo': mcpBlueprintUndo(editor)};
      },
    ),
    tool(
      name: 'set_blueprint_component_physics',
      title: 'Set Blueprint component physics',
      idempotent: true,
      description: 'A collision shape\'s or static mesh\'s Physics section in the Blueprint (one undo step): physics '
          '{simulate, overrideMass, massKg, enableGravity, centerOfMassOffset, friction, restitution, linearDamping, '
          'angularDamping, locks{position, rotation}}.',
      schema: McpSchema.object({
        'asset': assetArg,
        'component': componentArg,
        'physics': {'type': 'object', 'description': 'The Physics section\'s keys to set.'},
      }, required: ['asset', 'component', 'physics']),
      run: (args, editor) async {
        final c = componentOf(editor, args.string('component'));
        if (!BlueprintComponentRegistry.isCollisionCapable(c.type) && c.type != 'LuminaStaticMeshComponent') {
          throw JsonRpcException(JsonRpcErrorCode.invalidParams, '${c.type} has no Physics section.');
        }
        final current = c.properties['physics'];
        final json = mcpApplyPhysics(args.optionalObject('physics')!, current is Map ? Map<String, dynamic>.from(current) : {});
        editor.setComponentPhysics(c.id, json);
        editor.selectComponent(c.id);
        return {'component': componentJson(editor.getComponent(c.id)!), 'undo': mcpBlueprintUndo(editor)};
      },
    ),
    tool(
      name: 'set_blueprint_class_default',
      title: 'Set Blueprint class default',
      idempotent: true,
      description: 'Class Defaults (one undo step): initialHealth (a number); a GameMode Blueprint also takes '
          'defaultPawnClass (a Blueprint .lmas path, "" for none) and playerControllerClass.',
      schema: McpSchema.object({
        'asset': assetArg,
        'key': McpSchema.string('initialHealth, defaultPawnClass or playerControllerClass.'),
        'value': McpSchema.any('The value.'),
      }, required: ['asset', 'key', 'value']),
      run: (args, editor) async {
        final key = args.string('key');
        final isGameMode = editor.document.parentClass == BlueprintEditorViewModel.gameModeParent;
        final keys = ['initialHealth', if (isGameMode) ...['defaultPawnClass', 'playerControllerClass']];
        if (!keys.contains(key)) {
          throw JsonRpcException(JsonRpcErrorCode.invalidParams,
              'Unknown class default "$key". Keys: ${keys.join(', ')}${isGameMode ? '' : ' (GameMode Blueprints add defaultPawnClass, playerControllerClass)'}.');
        }
        final value = args['value'];
        if (key == 'initialHealth') {
          if (value is! num) throw const JsonRpcException(JsonRpcErrorCode.invalidParams, 'initialHealth takes a number.');
          editor.setClassDefault(key, value.toDouble());
        } else {
          if (value is! String) throw JsonRpcException(JsonRpcErrorCode.invalidParams, '$key takes a string.');
          editor.setGameModeDefault(key, value);
        }
        return {'class_defaults': editor.document.classDefaults, 'undo': mcpBlueprintUndo(editor)};
      },
    ),
    tool(
      name: 'set_blueprint_parent_class',
      title: 'Set Blueprint parent class',
      idempotent: true,
      description: 'Class Settings → Parent Class (one undo step): ${parentClasses.join(', ')}.',
      schema: McpSchema.object({
        'asset': assetArg,
        'parent_class': McpSchema.string('The parent class.', enumValues: parentClasses),
      }, required: ['asset', 'parent_class']),
      run: (args, editor) async {
        editor.setParentClass(args.string('parent_class'));
        return {'parent_class': editor.document.parentClass, 'undo': mcpBlueprintUndo(editor)};
      },
    ),
    tool(
      name: 'reset_blueprint_components',
      title: 'Reset Blueprint components',
      risk: McpToolRisk.destructive,
      removesContent: true,
      description: 'Resets the Components panel to the parent class\'s default components, discarding the authored '
          'ones (one undo step).',
      schema: McpSchema.object({'asset': assetArg}, required: ['asset']),
      run: (args, editor) async {
        editor.resetToDefaultComponents();
        return treeOf(editor);
      },
    ),
  ]);
}

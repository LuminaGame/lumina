import 'package:lumina_editor_data/lumina_editor.dart' show AssetType, LuminaBlueprintVariable;

import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/blueprint_asset_catalog.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_enum_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_interface_view_model.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_editor_sessions.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_protocol.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_tool.dart';
import 'package:lumina_ui/ui/features/mcp_server/tools/blueprint_tool_support.dart' show mcpParseParams;
import 'package:lumina_ui/ui/features/mcp_server/tools/core_tools.dart' show mcpUndoState;

/// The Enumeration and Blueprint Interface editors as MCP tools:
/// an enum's ordered values, an interface's function
/// signatures. Every edit is one step on the asset's own undo stack, which
/// 04's `undo` reaches with the asset.
void registerBlueprintTypeTools(McpToolRegistry registry, EditorViewModel vm, McpEditorSessions sessions) {
  const groups = {McpToolGroups.blueprintTypes, McpToolGroups.assetEditors};
  final identifier = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');
  final enumArg = McpSchema.string('The Enumeration asset (create_asset type "actor", blueprint_kind "enum"; '
      'contents/enums/…): project-relative path or unique file name.');
  final ifaceArg = McpSchema.string('The Blueprint Interface asset (create_asset type "actor", blueprint_kind '
      '"interface"; contents/interfaces/…): project-relative path or unique file name.');
  final paramsSchema = {
    'type': 'array',
    'description': '[{name, type}] — type: Bool, Integer, Float, Name, String, Vector, Vector2D, Rotator, Color, '
        'Transform, Object, Actor, Actor:<BP>, Widget:<WBP>, Component:<type>, Enum:<name>, Array:<type>.',
    'items': McpSchema.object({'name': McpSchema.string('Parameter name.'), 'type': McpSchema.string('Parameter type.')}, required: ['name', 'type']),
  };

  Never bad(String message) => throw JsonRpcException(JsonRpcErrorCode.invalidParams, message);

  Future<BlueprintEnumViewModel> enumFor(McpArgs args) {
    final asset = sessions.resolveAsset(args.string('asset'), type: AssetType.actor);
    if (!BlueprintAssetCatalog.isEnumLmas(asset.lmasPath)) {
      bad('${asset.relativePath} is not an Enumeration. Enumerations live in contents/enums (list_assets folder "enums").');
    }
    return sessions.blueprintEnum(asset);
  }

  Future<BlueprintInterfaceViewModel> interfaceFor(McpArgs args) {
    final asset = sessions.resolveAsset(args.string('asset'), type: AssetType.actor);
    if (!BlueprintAssetCatalog.isInterfaceLmas(asset.lmasPath)) {
      bad('${asset.relativePath} is not a Blueprint Interface. Interfaces live in contents/interfaces (list_assets folder "interfaces").');
    }
    return sessions.blueprintInterface(asset);
  }

  Map<String, Object?> enumJson(BlueprintEnumViewModel e, String asset) => {
        'asset': asset,
        'name': e.name,
        'values': e.values,
        'selected': e.selectedIndex,
        'is_dirty': e.isDirty,
        'undo': mcpUndoState(e.transactions),
      };

  List<Map<String, Object?>> params(List<LuminaBlueprintVariable> vars) => [for (final v in vars) {'name': v.name, 'type': v.typeName}];

  Map<String, Object?> ifaceJson(BlueprintInterfaceViewModel e, String asset) => {
        'asset': asset,
        'name': e.name,
        'functions': [
          for (final f in e.functions)
            {'name': f.name, 'inputs': params(f.inputs), 'outputs': params(f.outputs), 'kind': f.outputs.isEmpty ? 'event' : 'function'},
        ],
        'selected': e.selectedFunction,
        'is_dirty': e.isDirty,
        'undo': mcpUndoState(e.transactions),
      };

  int indexOf(BlueprintEnumViewModel e, McpArgs args, String key) {
    final i = args.integer(key);
    if (i < 0 || i >= e.values.length) {
      bad('No value at $key $i: ${e.name} has ${e.values.length} values (${e.values.join(', ')}).');
    }
    return i;
  }

  String functionOf(BlueprintInterfaceViewModel e, String name) {
    if (e.function(name) != null) return name;
    bad('No function "$name" in ${e.name}. Functions: ${e.functions.isEmpty ? 'none' : e.functions.map((f) => f.name).join(', ')}.');
  }

  registry.registerAll([
    // --- Enumeration --------------------------------------------------------
    McpTool(
      name: 'get_enum',
      risk: McpToolRisk.readOnly,
      groups: groups,
      title: 'Get enumeration',
      description: 'The Enumeration editor\'s document (opens its tab): its values in order, the selected one, '
          'unsaved changes and its undo stack.',
      inputSchema: McpSchema.object({'asset': enumArg}, required: ['asset']),
      handler: (args) async => McpToolResult.json(enumJson(await enumFor(args), args.string('asset'))),
    ),
    McpTool(
      name: 'add_enum_value',
      risk: McpToolRisk.mutating,
      groups: groups,
      title: 'Add enum value',
      description: 'Adds a value at the end (+ Add Enumerator): the given identifier (a taken one gets a number), or '
          'the next NewEnumerator<n>. One undo step on the enum\'s stack.',
      inputSchema: McpSchema.object({'asset': enumArg, 'name': McpSchema.string('The value\'s identifier.')}, required: ['asset']),
      handler: (args) async {
        final name = args.optionalString('name')?.trim();
        if (name != null && !identifier.hasMatch(name)) bad('"$name" is not an identifier (letters, digits, _; not starting with a digit).');
        final e = await enumFor(args);
        final used = e.addValue(name);
        return McpToolResult.json({'added': used, ...enumJson(e, args.string('asset'))});
      },
    ),
    McpTool(
      name: 'rename_enum_value',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: true,
      title: 'Rename enum value',
      description: 'Renames the value at index to a new identifier not used by another value. Saving follows it in '
          'every Switch on this enum. One undo step.',
      inputSchema: McpSchema.object({
        'asset': enumArg,
        'index': McpSchema.integer('The value\'s index (0-based).'),
        'name': McpSchema.string('The new identifier.'),
      }, required: ['asset', 'index', 'name']),
      handler: (args) async {
        final e = await enumFor(args);
        final i = indexOf(e, args, 'index');
        final name = args.string('name').trim();
        if (!identifier.hasMatch(name)) return McpToolResult.error('"$name" is not an identifier (letters, digits, _; not starting with a digit).');
        if (e.values[i] != name && e.values.contains(name)) return McpToolResult.error('${e.name} already has a value "$name".');
        e.renameValue(i, name);
        return McpToolResult.json(enumJson(e, args.string('asset')));
      },
    ),
    McpTool(
      name: 'remove_enum_value',
      risk: McpToolRisk.destructive,
      groups: groups,
      title: 'Remove enum value',
      description: 'Deletes the value at index. Saving drops the case wires of every Switch on this enum that used it. '
          'One undo step (until saved).',
      inputSchema: McpSchema.object({'asset': enumArg, 'index': McpSchema.integer('The value\'s index (0-based).')}, required: ['asset', 'index']),
      handler: (args) async {
        final e = await enumFor(args);
        final i = indexOf(e, args, 'index');
        final removed = e.values[i];
        e.removeValue(i);
        return McpToolResult.json({'removed': removed, ...enumJson(e, args.string('asset'))});
      },
    ),
    McpTool(
      name: 'move_enum_value',
      risk: McpToolRisk.mutating,
      groups: groups,
      title: 'Move enum value',
      description: 'Reorders: moves the value at index from to index to. Switch case wires follow their value by name '
          'when saved. One undo step.',
      inputSchema: McpSchema.object({
        'asset': enumArg,
        'from': McpSchema.integer('The value\'s current index.'),
        'to': McpSchema.integer('Its new index.'),
      }, required: ['asset', 'from', 'to']),
      handler: (args) async {
        final e = await enumFor(args);
        final from = indexOf(e, args, 'from');
        final to = indexOf(e, args, 'to');
        if (from != to) e.moveValue(from, to);
        return McpToolResult.json(enumJson(e, args.string('asset')));
      },
    ),
    McpTool(
      name: 'save_enum',
      risk: McpToolRisk.destructive,
      groups: groups,
      idempotent: true,
      title: 'Save enumeration',
      description: 'The tab\'s Save: writes the values and — project-wide — rewires the case pins of every '
          '"Switch on <enum>" node in every Blueprint of the project so each case keeps its value by name (cases of '
          'removed values lose their wires). Those Blueprint files are rewritten.',
      inputSchema: McpSchema.object({'asset': enumArg}, required: ['asset']),
      handler: (args) async {
        final e = await enumFor(args);
        if (!await e.save()) return McpToolResult.error('Save failed; see the Output Log.');
        vm.refreshAssets();
        return McpToolResult.json(enumJson(e, args.string('asset')));
      },
    ),
    // --- Blueprint Interface ------------------------------------------------
    McpTool(
      name: 'get_interface',
      risk: McpToolRisk.readOnly,
      groups: groups,
      title: 'Get Blueprint Interface',
      description: 'The Blueprint Interface editor\'s document (opens its tab): its functions with their typed inputs '
          'and outputs (a function without outputs is implemented as an event), unsaved changes, its undo stack.',
      inputSchema: McpSchema.object({'asset': ifaceArg}, required: ['asset']),
      handler: (args) async => McpToolResult.json(ifaceJson(await interfaceFor(args), args.string('asset'))),
    ),
    McpTool(
      name: 'add_interface_function',
      risk: McpToolRisk.mutating,
      groups: groups,
      title: 'Add interface function',
      description: 'Adds a function without parameters (+ Function), made unique with a number: use the returned name. '
          'One undo step.',
      inputSchema: McpSchema.object({'asset': ifaceArg, 'name': McpSchema.string('The function name; default NewFunction.')}, required: ['asset']),
      handler: (args) async {
        final name = args.optionalString('name')?.trim() ?? 'NewFunction';
        if (!identifier.hasMatch(name)) bad('"$name" is not an identifier (letters, digits, _; not starting with a digit).');
        final e = await interfaceFor(args);
        final used = e.addFunction(name);
        return McpToolResult.json({'function': used, ...ifaceJson(e, args.string('asset'))});
      },
    ),
    McpTool(
      name: 'rename_interface_function',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: true,
      title: 'Rename interface function',
      description: 'Renames a function to an identifier no other function uses. One undo step.',
      inputSchema: McpSchema.object({
        'asset': ifaceArg,
        'function': McpSchema.string('The function\'s current name.'),
        'name': McpSchema.string('The new name.'),
      }, required: ['asset', 'function', 'name']),
      handler: (args) async {
        final e = await interfaceFor(args);
        final f = functionOf(e, args.string('function'));
        final name = args.string('name').trim();
        if (!identifier.hasMatch(name)) return McpToolResult.error('"$name" is not an identifier (letters, digits, _; not starting with a digit).');
        if (name != f && e.function(name) != null) return McpToolResult.error('${e.name} already has a function "$name".');
        e.renameFunction(f, name);
        return McpToolResult.json(ifaceJson(e, args.string('asset')));
      },
    ),
    McpTool(
      name: 'remove_interface_function',
      risk: McpToolRisk.destructive,
      groups: groups,
      title: 'Remove interface function',
      description: 'Deletes a function from the interface. One undo step (until saved).',
      inputSchema: McpSchema.object({'asset': ifaceArg, 'function': McpSchema.string('The function.')}, required: ['asset', 'function']),
      handler: (args) async {
        final e = await interfaceFor(args);
        final f = functionOf(e, args.string('function'));
        e.removeFunction(f);
        return McpToolResult.json({'removed': f, ...ifaceJson(e, args.string('asset'))});
      },
    ),
    McpTool(
      name: 'set_interface_function_params',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: true,
      title: 'Set interface function parameters',
      description: 'A function\'s Inputs and / or Outputs lists, replaced whole: [{name, type}] with the types the '
          'signature editor offers. One undo step for the call.',
      inputSchema: McpSchema.object({
        'asset': ifaceArg,
        'function': McpSchema.string('The function.'),
        'inputs': paramsSchema,
        'outputs': paramsSchema,
      }, required: ['asset', 'function']),
      handler: (args) async {
        final inputs = args.has('inputs') ? mcpParseParams(args['inputs'], 'inputs') : null;
        final outputs = args.has('outputs') ? mcpParseParams(args['outputs'], 'outputs') : null;
        for (final p in [...?inputs, ...?outputs]) {
          if (!identifier.hasMatch(p.name)) bad('Parameter "${p.name}" is not an identifier.');
        }
        final e = await interfaceFor(args);
        final f = functionOf(e, args.string('function'));
        if (inputs != null) e.setInputs(f, inputs);
        if (outputs != null) e.setOutputs(f, outputs);
        e.select(f);
        return McpToolResult.json(ifaceJson(e, args.string('asset')));
      },
    ),
    McpTool(
      name: 'save_interface',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: true,
      title: 'Save Blueprint Interface',
      description: 'The tab\'s Save: writes the function signatures to the .lmas.',
      inputSchema: McpSchema.object({'asset': ifaceArg}, required: ['asset']),
      handler: (args) async {
        final e = await interfaceFor(args);
        if (!await e.save()) return McpToolResult.error('Save failed; see the Output Log.');
        vm.refreshAssets();
        return McpToolResult.json(ifaceJson(e, args.string('asset')));
      },
    ),
  ]);
}

import 'dart:ui' show Offset, Size;

import 'package:lumina_editor_data/lumina_editor.dart' show AssetType, LuminaBlueprintNodeLibrary, RealAssetInfo, kUmgWidgetLibraryShadcn;

import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/umg_document.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/umg_widget_codegen.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/umg_editor_view_model.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_editor_sessions.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_protocol.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_tool.dart';

/// The UMG designer as MCP tools: the palette, the widget
/// tree, add / remove / move / wrap / replace, names and Is Variable, slots,
/// props (textures through the designer's texture binding), designer
/// settings, bound widget events, Save and Compile to
/// `lib/widgets/WBP_<Name>.dart`. Every edit goes through the Widget tab's
/// `UmgEditorViewModel` (opened when needed), so the canvas and hierarchy
/// update live and each call is one `MCP: …` step on the tab's own stack.
/// The widget's graph is edited with the Blueprint tools (`asset` = the
/// Widget Blueprint).
void registerUmgTools(McpToolRegistry registry, EditorViewModel vm, McpEditorSessions sessions) {
  const umg = {McpToolGroups.umg};
  const assetArg = 'The Widget Blueprint: its project-relative .lmas path (list_assets with type "widget") or its '
      'file name when unique.';
  const widgetArg = 'A widget of the tree: its id, name or field name (get_widget_tree); "root" for the root panel.';
  final typeNames = [for (final t in UmgWidgetType.values) t.name];

  Future<UmgEditorViewModel> editorFor(McpArgs args) async {
    final asset = sessions.resolveAsset(args.string('asset'));
    if (!sessions.isWidget(asset)) {
      throw JsonRpcException(JsonRpcErrorCode.invalidParams,
          '${asset.relativePath} is a ${asset.type.name}, not a Widget Blueprint. Call list_assets with type "widget".');
    }
    return sessions.widget(asset);
  }

  /// [editorFor] with the designer shown: the canvas the edit lands on.
  Future<UmgEditorViewModel> designerFor(McpArgs args) async {
    final editor = await editorFor(args);
    editor.setMode(UmgEditorMode.designer);
    return editor;
  }

  UmgNode nodeFor(UmgEditorViewModel editor, String ref) {
    final doc = editor.document;
    if (ref == 'root') return doc.root;
    final node = doc.findNode(ref) ??
        doc.allNodes.where((n) => n.name == ref).firstOrNull ??
        doc.allNodes.where((n) => n.fieldName == ref).firstOrNull;
    if (node == null) {
      throw JsonRpcException(JsonRpcErrorCode.invalidParams,
          'No widget "$ref" in ${editor.fileBasename}. Widgets: ${doc.allNodes.map((n) => n.name).join(', ')} (get_widget_tree).');
    }
    return node;
  }

  UmgWidgetType typeFor(String name) => UmgWidgetType.values.where((t) => t.name == name).firstOrNull ??
      (throw JsonRpcException(JsonRpcErrorCode.invalidParams, 'Unknown widget type "$name" (list_widget_types).'));

  Map<String, Object?> result(UmgEditorViewModel editor, [UmgNode? node, Map<String, Object?> extra = const {}]) => {
        'asset': editor.assetPath,
        'widget': ?(node == null ? null : _nodeJson(node, recursive: false)),
        ...extra,
        'is_dirty': editor.isDirty,
        'undo_label': editor.transactions.canUndo ? editor.transactions.undoLabel : null,
      };

  McpToolResult refuse(UmgEditorViewModel editor, String fallback) => McpToolResult.error(editor.lastRejectionReason ?? fallback);

  final numbers2 = _numberArray('Two numbers [x, y].', 2);

  registry.registerAll([
    McpTool(
      name: 'list_widget_types',
      risk: McpToolRisk.readOnly,
      groups: umg,
      title: 'List widget types',
      description: 'The UMG designer\'s palette: each widget type\'s id (pass it as `type`), display name, category '
          '(panels, common, shadcn), child capacity (none, one, many), the slot kind its children get (canvas, box, '
          'overlay, single), default props (the keys set_widget_properties accepts), its bindable events, whether it '
          'is a variable by default, and requires_widget_library "shadcn" for shadcn components (a project on the '
          '"flutter" library cannot compile them). Also the project\'s widget_library.',
      inputSchema: McpSchema.object({
        'category': McpSchema.string('Only this palette category.', enumValues: [for (final c in UmgWidgetCategory.values) c.name]),
      }),
      handler: (args) {
        final category = args.optionalString('category');
        return McpToolResult.json({
          'widget_library': UmgWidgetCodegen.libraryFor(vm.projectDirPath),
          'types': [
            for (final t in UmgWidgetType.values)
              if (category == null || t.category.name == category)
                {
                  'id': t.name,
                  'display_name': t.displayName,
                  'category': t.category.name,
                  'capacity': t.capacity.name,
                  'child_slot_kind': t.childSlotKind.name,
                  'default_props': t.defaultProps(),
                  'events': t.availableEvents,
                  'is_variable_by_default': t.isVariableByDefault,
                  if (t.isShadcn) 'requires_widget_library': kUmgWidgetLibraryShadcn,
                },
          ],
        });
      },
    ),
    McpTool(
      name: 'get_widget_tree',
      risk: McpToolRisk.readOnly,
      groups: umg,
      title: 'Get widget tree',
      description: 'A Widget Blueprint as the designer holds it (opens its tab): design resolution, DPI scale, the '
          'project\'s widget library, the tree from the root panel (id, name, field_name, type, is_variable, slot with '
          'the fields of its kind, props, events, children), validation_errors (what stops Compile), is_dirty, the '
          'last compile and the mode (designer or graph). The graph is read with get_blueprint.',
      inputSchema: McpSchema.object({'asset': McpSchema.string(assetArg)}, required: ['asset']),
      handler: (args) async {
        final editor = await editorFor(args);
        final last = editor.lastCompile;
        return McpToolResult.json({
          'asset': editor.assetPath,
          'class_name': editor.className,
          'design_resolution': {'label': editor.resolution.label, 'width': editor.resolution.width, 'height': editor.resolution.height},
          'dpi_scale': editor.dpiScale,
          'widget_library': editor.widgetLibrary,
          'mode': editor.mode.name,
          'root': _nodeJson(editor.document.root),
          'validation_errors': editor.validationErrors,
          'is_dirty': editor.isDirty,
          'last_compile': last == null && editor.compileError == null
              ? null
              : {'ok': editor.compileError == null, 'file_path': last?.filePath, 'written': last?.written, 'error': editor.compileError},
        });
      },
    ),
    McpTool(
      name: 'add_widget',
      risk: McpToolRisk.mutating,
      groups: umg,
      title: 'Add widget',
      description: 'Places a new widget, as a drop from the palette does: `type` from list_widget_types under `parent` '
          '(at `index`, else last). Under a Canvas Panel, x / y are its position in design pixels. Optional `name` '
          '(a Dart identifier, unique) and initial `props`. One undo step for all of it. A parent that cannot take '
          'the child (a leaf, a full single-child panel) is a tool error with the designer\'s reason.',
      inputSchema: McpSchema.object({
        'asset': McpSchema.string(assetArg),
        'type': McpSchema.string('The widget type id (list_widget_types).', enumValues: typeNames),
        'parent': McpSchema.string(widgetArg),
        'index': McpSchema.integer('Child index to insert at; default: last.'),
        'x': McpSchema.number('Canvas Panel parent only: x in design pixels.'),
        'y': McpSchema.number('Canvas Panel parent only: y in design pixels.'),
        'name': McpSchema.string('The widget\'s name (its generated field).'),
        'props': _objectSchema('Initial props {key: value}; keys from the type\'s default_props.'),
      }, required: ['asset', 'type', 'parent']),
      handler: (args) async {
        final editor = await designerFor(args);
        final type = typeFor(args.string('type'));
        final parent = nodeFor(editor, args.string('parent'));
        final name = args.optionalString('name');
        if (name != null) {
          final problem = _nameProblem(editor, name, null);
          if (problem != null) return McpToolResult.error(problem);
        }
        final props = args.optionalObject('props') ?? const {};
        final prepared = _prepareProps(type, props, sessions);
        if (prepared.error != null) return McpToolResult.error(prepared.error!);
        final position = parent.type.isCanvas && (args.has('x') || args.has('y'))
            ? Offset(args.optionalNumber('x') ?? 0, args.optionalNumber('y') ?? 0)
            : null;
        final node = editor.addWidget(type, parentId: parent.id, canvasPosition: position, index: args.has('index') ? args.integer('index') : null);
        if (node == null) return refuse(editor, '${parent.name} did not take the ${type.displayName}.');
        if (name != null && name != node.name && !editor.rename(node.id, name)) return refuse(editor, 'Could not name it "$name".');
        _applyProps(editor, node, prepared);
        return McpToolResult.json(result(editor, editor.document.findNode(node.id)));
      },
    ),
    McpTool(
      name: 'remove_widget',
      risk: McpToolRisk.mutating,
      groups: umg,
      removesContent: true,
      title: 'Remove widget',
      description: 'Deletes a widget and its children (Delete in the hierarchy). The root panel cannot be removed. '
          'One undo step.',
      inputSchema: McpSchema.object({'asset': McpSchema.string(assetArg), 'widget': McpSchema.string(widgetArg)},
          required: ['asset', 'widget']),
      handler: (args) async {
        final editor = await designerFor(args);
        final node = nodeFor(editor, args.string('widget'));
        if (!editor.deleteNode(node.id)) return refuse(editor, '${node.name} was not removed.');
        return McpToolResult.json(result(editor, null, {'removed': node.id}));
      },
    ),
    McpTool(
      name: 'move_widget',
      risk: McpToolRisk.mutating,
      groups: umg,
      title: 'Move widget',
      description: 'Reparents and / or reorders a widget, as a drag in the hierarchy does: under `parent` at `index` '
          '(default last; the same parent reorders). Its slot becomes the new parent\'s kind. Refused into itself, '
          'a descendant, a leaf or a full single-child panel. One undo step.',
      inputSchema: McpSchema.object({
        'asset': McpSchema.string(assetArg),
        'widget': McpSchema.string(widgetArg),
        'parent': McpSchema.string(widgetArg),
        'index': McpSchema.integer('Child index; default: last.'),
      }, required: ['asset', 'widget', 'parent']),
      handler: (args) async {
        final editor = await designerFor(args);
        final node = nodeFor(editor, args.string('widget'));
        final parent = nodeFor(editor, args.string('parent'));
        if (!editor.moveNode(node.id, parent.id, index: args.has('index') ? args.integer('index') : null)) {
          return refuse(editor, '${node.name} was not moved.');
        }
        return McpToolResult.json(result(editor, editor.document.findNode(node.id), {'parent': parent.id}));
      },
    ),
    for (final wrap in [true, false])
      McpTool(
        name: wrap ? 'wrap_widget' : 'replace_widget',
        risk: McpToolRisk.mutating,
        groups: umg,
        title: wrap ? 'Wrap widget' : 'Replace widget',
        description: wrap
            ? 'Wrap With… in the hierarchy: a new panel of `type` takes the widget\'s place and slot, the widget '
                'becomes its child. One undo step; returns the wrapper.'
            : 'Replace With… in the hierarchy: the widget becomes `type`, keeping its id, name, slot and the props '
                'both types share; refused when the new type cannot hold its children. One undo step.',
        inputSchema: McpSchema.object({
          'asset': McpSchema.string(assetArg),
          'widget': McpSchema.string(widgetArg),
          'type': McpSchema.string(wrap ? 'A panel type (list_widget_types, capacity one or many).' : 'The new type.', enumValues: typeNames),
        }, required: ['asset', 'widget', 'type']),
        handler: (args) async {
          final editor = await designerFor(args);
          final node = nodeFor(editor, args.string('widget'));
          final type = typeFor(args.string('type'));
          final done = wrap ? editor.wrapWith(node.id, type) : editor.replaceWith(node.id, type);
          if (done == null) return refuse(editor, '${node.name} was not changed.');
          return McpToolResult.json(result(editor, editor.document.findNode(done.id)));
        },
      ),
    McpTool(
      name: 'rename_widget',
      risk: McpToolRisk.mutating,
      groups: umg,
      idempotent: true,
      title: 'Rename widget',
      description: 'Renames a widget; the name becomes its generated Dart field, so it must make a Dart identifier '
          'no other widget uses. Graph references (Get <Element>, bound events) follow. One undo step.',
      inputSchema: McpSchema.object({
        'asset': McpSchema.string(assetArg),
        'widget': McpSchema.string(widgetArg),
        'name': McpSchema.string('The new name.'),
      }, required: ['asset', 'widget', 'name']),
      handler: (args) async {
        final editor = await designerFor(args);
        final node = nodeFor(editor, args.string('widget'));
        final name = args.string('name');
        if (name.trim() == node.name) return McpToolResult.json(result(editor, node, {'changed': false}));
        if (!editor.rename(node.id, name)) return refuse(editor, '${node.name} was not renamed.');
        return McpToolResult.json(result(editor, editor.document.findNode(node.id), {'changed': true}));
      },
    ),
    McpTool(
      name: 'set_widget_is_variable',
      risk: McpToolRisk.mutating,
      groups: umg,
      idempotent: true,
      title: 'Set widget Is Variable',
      description: 'Is Variable: whether the widget is a member of the Widget Blueprint\'s graph (Get '
          '<Element>, bound events). Not for the root. One undo step.',
      inputSchema: McpSchema.object({
        'asset': McpSchema.string(assetArg),
        'widget': McpSchema.string(widgetArg),
        'value': McpSchema.boolean('Is Variable.'),
      }, required: ['asset', 'widget', 'value']),
      handler: (args) async {
        final editor = await designerFor(args);
        final node = nodeFor(editor, args.string('widget'));
        if (node.id == editor.document.root.id) return McpToolResult.error('The root panel is never a variable.');
        final changed = editor.setIsVariable(node.id, args.boolean('value'));
        return McpToolResult.json(result(editor, editor.document.findNode(node.id), {'changed': changed}));
      },
    ),
    McpTool(
      name: 'set_widget_slot',
      risk: McpToolRisk.mutating,
      groups: umg,
      idempotent: true,
      title: 'Set widget slot',
      description: 'Edits the widget\'s slot, as the Details panel\'s Slot section does. A Canvas Panel child (slot '
          '"canvas"): anchor_preset (applied first; ${UmgAnchorPreset.values.map((p) => p.name).join(', ')}), '
          'anchor_min / anchor_max [x, y] in 0…1, position and size in design pixels, alignment [x, y] (the pivot, '
          '0…1), size_to_content, z_order. A box child ("box": Horizontal / Vertical Box, Grid, Scroll Box): padding '
          '[left, top, right, bottom], fill, flex, h_align / v_align (fill, start, center, end). Overlay and '
          'single-child slots: padding, h_align, v_align. A field of another kind is a tool error naming the kind. '
          'One undo step.',
      inputSchema: McpSchema.object({
        'asset': McpSchema.string(assetArg),
        'widget': McpSchema.string(widgetArg),
        'anchor_preset': McpSchema.string('An anchor preset.', enumValues: [for (final p in UmgAnchorPreset.values) p.name]),
        'anchor_min': numbers2,
        'anchor_max': numbers2,
        'position': numbers2,
        'size': _numberArray('[width, height] in design pixels.', 2),
        'alignment': numbers2,
        'size_to_content': McpSchema.boolean('Size to content.'),
        'z_order': McpSchema.integer('Z-order among the canvas children.'),
        'padding': _numberArray('[left, top, right, bottom] in design pixels.', 4),
        'fill': McpSchema.boolean('Fill the box\'s main axis.'),
        'flex': McpSchema.number('Flex factor when filling.'),
        'h_align': McpSchema.string('Horizontal alignment.', enumValues: [for (final a in UmgAlign.values) a.name]),
        'v_align': McpSchema.string('Vertical alignment.', enumValues: [for (final a in UmgAlign.values) a.name]),
      }, required: ['asset', 'widget']),
      handler: (args) async {
        final editor = await designerFor(args);
        final node = nodeFor(editor, args.string('widget'));
        final kind = node.slot.kind;
        final allowed = _slotFields[kind]!;
        final given = [for (final f in _slotFields.values.expand((f) => f).toSet()) if (args.has(f)) f];
        final foreign = [for (final f in given) if (!allowed.contains(f)) f];
        if (foreign.isNotEmpty) {
          final parent = editor.document.parentOf(node.id);
          return McpToolResult.error('${node.name} has a ${kind.name} slot${parent == null ? ' (it is the root)' : ' (its parent is a ${parent.type.displayName})'}: '
              '${allowed.isEmpty ? 'it has no slot fields' : 'its fields are ${allowed.join(', ')}'}. Not ${foreign.join(', ')}.');
        }
        final Map<String, List<double>> vectors = {};
        for (final f in ['anchor_min', 'anchor_max', 'position', 'size', 'alignment', 'padding']) {
          if (!args.has(f)) continue;
          final v = _numbers(args[f], f == 'padding' ? 4 : 2);
          if (v == null) return McpToolResult.error('$f must be an array of ${f == 'padding' ? 4 : 2} numbers.');
          vectors[f] = v;
        }
        final preset = args.optionalString('anchor_preset');
        if (preset != null) editor.applyAnchorPreset(node.id, UmgAnchorPreset.values.byName(preset));
        final rest = given.where((f) => f != 'anchor_preset' && f != 'z_order').toList();
        if (rest.isNotEmpty) {
          editor.setSlot(node.id, (slot) {
            Offset o(String f) => Offset(vectors[f]![0], vectors[f]![1]);
            if (vectors.containsKey('anchor_min')) slot.anchorMin = o('anchor_min');
            if (vectors.containsKey('anchor_max')) slot.anchorMax = o('anchor_max');
            if (vectors.containsKey('position')) slot.position = o('position');
            if (vectors.containsKey('size')) slot.size = Size(vectors['size']![0], vectors['size']![1]);
            if (vectors.containsKey('alignment')) slot.alignment = o('alignment');
            if (args.has('size_to_content')) slot.sizeToContent = args.boolean('size_to_content');
            final p = vectors['padding'];
            if (p != null) {
              slot
                ..paddingLeft = p[0]
                ..paddingTop = p[1]
                ..paddingRight = p[2]
                ..paddingBottom = p[3];
            }
            if (args.has('fill')) slot.fill = args.boolean('fill');
            if (args.has('flex')) slot.flex = args.number('flex');
            if (args.has('h_align')) slot.hAlign = UmgAlign.values.byName(args.string('h_align'));
            if (args.has('v_align')) slot.vAlign = UmgAlign.values.byName(args.string('v_align'));
          });
        }
        if (args.has('z_order')) editor.setZOrder(node.id, args.integer('z_order'));
        return McpToolResult.json(result(editor, editor.document.findNode(node.id)));
      },
    ),
    McpTool(
      name: 'set_widget_properties',
      risk: McpToolRisk.mutating,
      groups: umg,
      idempotent: true,
      title: 'Set widget properties',
      description: 'Sets props of a widget, as the Details panel does: `props` {key: value} with keys from the type\'s '
          'default_props (list_widget_types) — text, fontSize, colours as "#RRGGBB" / "#RRGGBBAA", percent, … An '
          'Image\'s `texture` / a Container\'s `backgroundImage` takes a texture asset (list_assets type "texture"; '
          '"" clears it), bound as the designer\'s texture picker binds it. One undo step for the call. There are '
          'no per-property bindings: runtime updates go through the Widget Blueprint graph.',
      inputSchema: McpSchema.object({
        'asset': McpSchema.string(assetArg),
        'widget': McpSchema.string(widgetArg),
        'props': _objectSchema('{key: value} to set.'),
      }, required: ['asset', 'widget', 'props']),
      handler: (args) async {
        final editor = await designerFor(args);
        final node = nodeFor(editor, args.string('widget'));
        final prepared = _prepareProps(node.type, args.optionalObject('props')!, sessions, name: node.name);
        if (prepared.error != null) return McpToolResult.error(prepared.error!);
        _applyProps(editor, node, prepared);
        return McpToolResult.json(result(editor, editor.document.findNode(node.id)));
      },
    ),
    McpTool(
      name: 'bind_widget_event',
      risk: McpToolRisk.mutating,
      groups: umg,
      title: 'Bind widget event',
      description: 'The green + beside a Widget Event in Details: makes the widget a variable, records the binding '
          'and creates (or finds) the bound "On <Event> (<widget>)" node in the Widget Blueprint\'s event graph, '
          'showing the graph. Returns node_id and exec_pin: wire it with connect_blueprint_pins and add nodes with '
          'add_blueprint_node (asset = this Widget Blueprint). Events per type: list_widget_types.',
      inputSchema: McpSchema.object({
        'asset': McpSchema.string(assetArg),
        'widget': McpSchema.string(widgetArg),
        'event': McpSchema.string('The event, e.g. "OnClicked".'),
      }, required: ['asset', 'widget', 'event']),
      handler: (args) async {
        final editor = await editorFor(args);
        final node = nodeFor(editor, args.string('widget'));
        final event = args.string('event');
        if (!node.type.availableEvents.contains(event)) {
          return McpToolResult.error('A ${node.type.displayName} has no event "$event". Events: '
              '${node.type.availableEvents.isEmpty ? 'none' : node.type.availableEvents.join(', ')}.');
        }
        final bound = editor.bindWidgetEvent(node.id, event);
        if (bound == null) return McpToolResult.error('Could not bind $event on ${node.name}.');
        return McpToolResult.json(result(editor, editor.document.findNode(node.id), {
          'node_id': bound.id,
          'node': LuminaBlueprintNodeLibrary.eventWidgetElement,
          'title': bound.title,
          'exec_pin': 'exec_out',
          'graph': 'event',
        }));
      },
    ),
    McpTool(
      name: 'unbind_widget_event',
      risk: McpToolRisk.mutating,
      groups: umg,
      title: 'Unbind widget event',
      description: 'Removes a widget event binding and its bound node from the graph (one step on each stack it '
          'touches).',
      inputSchema: McpSchema.object({
        'asset': McpSchema.string(assetArg),
        'widget': McpSchema.string(widgetArg),
        'event': McpSchema.string('The bound event.'),
      }, required: ['asset', 'widget', 'event']),
      handler: (args) async {
        final editor = await editorFor(args);
        final node = nodeFor(editor, args.string('widget'));
        final event = args.string('event');
        if (!editor.isEventBound(node.id, event)) return McpToolResult.error('$event is not bound on ${node.name}.');
        editor.removeEvent(node.id, event);
        return McpToolResult.json(result(editor, editor.document.findNode(node.id)));
      },
    ),
    McpTool(
      name: 'set_widget_designer',
      risk: McpToolRisk.editorState,
      groups: umg,
      idempotent: true,
      title: 'Set widget designer',
      description: 'The designer\'s view: the simulated screen `resolution` (a preset label or "<w>x<h>": '
          '${UmgResolution.presets.map((r) => r.key).join(', ')}) or a custom width / height, the DPI scale '
          '(0.25–4) and the mode (designer or graph). View settings, not undo steps; Save stores the last ones.',
      inputSchema: McpSchema.object({
        'asset': McpSchema.string(assetArg),
        'resolution': McpSchema.string('A preset label or its "<w>x<h>" key.'),
        'width': McpSchema.integer('Custom width (with height).'),
        'height': McpSchema.integer('Custom height (with width).'),
        'dpi_scale': McpSchema.number('DPI scale, 0.25–4.'),
        'mode': McpSchema.string('The center panel.', enumValues: [for (final m in UmgEditorMode.values) m.name]),
      }, required: ['asset']),
      handler: (args) async {
        final editor = await editorFor(args);
        final wanted = args.optionalString('resolution');
        if (wanted != null) {
          final preset = UmgResolution.presets.where((r) => r.label == wanted || r.key == wanted).firstOrNull;
          if (preset == null) {
            return McpToolResult.error('Unknown resolution "$wanted". Presets: ${UmgResolution.presets.map((r) => '${r.key} (${r.label})').join(', ')}; '
                'or pass width and height.');
          }
          editor.setResolution(preset);
        }
        if (args.has('width') != args.has('height')) return McpToolResult.error('Pass width and height together.');
        if (args.has('width')) editor.setCustomResolution(args.integer('width'), args.integer('height'));
        final dpi = args.optionalNumber('dpi_scale');
        if (dpi != null) editor.setDpiScale(dpi);
        final mode = args.optionalString('mode');
        if (mode != null) editor.setMode(UmgEditorMode.values.byName(mode));
        return McpToolResult.json({
          'asset': editor.assetPath,
          'design_resolution': {'label': editor.resolution.label, 'width': editor.resolution.width, 'height': editor.resolution.height},
          'dpi_scale': editor.dpiScale,
          'mode': editor.mode.name,
          'is_dirty': editor.isDirty,
        });
      },
    ),
    McpTool(
      name: 'save_widget',
      risk: McpToolRisk.mutating,
      groups: umg,
      idempotent: true,
      title: 'Save widget',
      description: 'Writes the Widget Blueprint\'s .lmas (tree, graph, designer settings, texture references) — the '
          'tab\'s Save.',
      inputSchema: McpSchema.object({'asset': McpSchema.string(assetArg)}, required: ['asset']),
      handler: (args) async {
        final editor = await editorFor(args);
        if (!await editor.save()) return McpToolResult.error('Could not write ${editor.assetPath}; see the Output Log.');
        return McpToolResult.json({'asset': editor.assetPath, 'saved': true, 'is_dirty': editor.isDirty});
      },
    ),
    McpTool(
      name: 'compile_widget',
      risk: McpToolRisk.mutating,
      groups: umg,
      idempotent: true,
      title: 'Compile widget',
      description: 'The designer\'s Compile: saves the .lmas, checks the tree for the project\'s widget library and '
          'the graph, then writes lib/widgets/wbp_<name>.dart (snake_case; it writes both files). ok is false (a tool error) '
          'with the error lines when validation or the graph fails; then no Dart file is written.',
      inputSchema: McpSchema.object({'asset': McpSchema.string(assetArg)}, required: ['asset']),
      handler: (args) async {
        final editor = await editorFor(args);
        final compiled = await editor.compile();
        final error = editor.compileError;
        final data = {
          'ok': error == null,
          'file_path': compiled.filePath,
          'written': compiled.written,
          'warnings': compiled.warnings,
          'errors': error == null ? const <String>[] : error.split('\n'),
          'validation_errors': editor.validationErrors,
          'is_dirty': editor.isDirty,
        };
        return McpToolResult(McpToolResult.json(data).content, structuredContent: data, isError: error != null);
      },
    ),
  ]);
}

const Map<UmgSlotKind, List<String>> _slotFields = {
  UmgSlotKind.canvas: ['anchor_preset', 'anchor_min', 'anchor_max', 'position', 'size', 'alignment', 'size_to_content', 'z_order'],
  UmgSlotKind.box: ['padding', 'fill', 'flex', 'h_align', 'v_align'],
  UmgSlotKind.overlay: ['padding', 'h_align', 'v_align'],
  UmgSlotKind.single: ['padding', 'h_align', 'v_align'],
  UmgSlotKind.none: [],
};

Map<String, Object?> _numberArray(String description, int n) =>
    {'type': 'array', 'description': description, 'items': {'type': 'number'}, 'minItems': n, 'maxItems': n};

Map<String, Object?> _objectSchema(String description) => {'type': 'object', 'description': description};

List<double>? _numbers(Object? v, int n) {
  if (v is! List || v.length != n || v.any((e) => e is! num)) return null;
  return [for (final e in v) (e as num).toDouble()];
}

List<double> _pair(Offset o) => [o.dx, o.dy];

Map<String, Object?> _slotJson(UmgSlot s) => {
      'kind': s.kind.name,
      if (s.kind == UmgSlotKind.canvas) ...{
        'anchor_min': _pair(s.anchorMin),
        'anchor_max': _pair(s.anchorMax),
        'position': _pair(s.position),
        'size': [s.size.width, s.size.height],
        'alignment': _pair(s.alignment),
        'size_to_content': s.sizeToContent,
        'z_order': s.zOrder,
      },
      if (s.kind != UmgSlotKind.canvas && s.kind != UmgSlotKind.none) ...{
        'padding': [s.paddingLeft, s.paddingTop, s.paddingRight, s.paddingBottom],
        if (s.kind == UmgSlotKind.box) ...{'fill': s.fill, 'flex': s.flex},
        'h_align': s.hAlign.name,
        'v_align': s.vAlign.name,
      },
    };

Map<String, Object?> _nodeJson(UmgNode n, {bool recursive = true}) => {
      'id': n.id,
      'name': n.name,
      'field_name': n.fieldName,
      'type': n.type.name,
      'is_variable': n.isVariable,
      'slot': _slotJson(n.slot),
      'props': n.props,
      'events': [for (final e in n.events) e.name],
      if (recursive) 'children': [for (final c in n.children) _nodeJson(c)] else 'child_ids': [for (final c in n.children) c.id],
    };

/// Why [name] cannot name a widget, or null.
String? _nameProblem(UmgEditorViewModel editor, String name, String? exclude) {
  final field = UmgNaming.toFieldName(name.trim());
  if (name.trim().isEmpty || field.isEmpty) {
    return 'Name must produce a Dart identifier (letters, digits, underscores; not starting with a digit)';
  }
  if (editor.document.isFieldNameTaken(field, exclude: exclude)) return 'Another element already generates the field "$field"';
  return null;
}

typedef _Props = ({Map<String, Object?> values, Map<String, RealAssetInfo?> textures, String? error});

/// Checks [props] against [type]'s default props (keys and value types) and
/// resolves texture keys to texture assets.
_Props _prepareProps(UmgWidgetType type, Map<String, Object?> props, McpEditorSessions sessions, {String? name}) {
  final defaults = type.defaultProps();
  final textureKey = UmgEditorViewModel.textureKeyOf(type);
  final values = <String, Object?>{};
  final textures = <String, RealAssetInfo?>{};
  _Props fail(String error) => (values: const {}, textures: const {}, error: error);
  for (final e in props.entries) {
    final key = e.key;
    final value = e.value;
    if (!defaults.containsKey(key)) {
      return fail('${name ?? 'A'} ${type.displayName} has no property "$key". Properties: ${defaults.keys.join(', ')}.');
    }
    if (key == textureKey) {
      if (value == null || value == '') {
        textures[key] = null;
        continue;
      }
      if (value is! String) return fail('$key takes a texture asset path (list_assets type "texture").');
      try {
        textures[key] = sessions.resolveAsset(value, type: AssetType.texture);
      } on JsonRpcException catch (err) {
        return fail(err.message);
      }
      continue;
    }
    final d = defaults[key];
    final Object coerced = switch (d) {
      double() when value is num => value.toDouble(),
      int() when value is num && value == value.roundToDouble() => value.toInt(),
      bool() when value is bool => value,
      String() when value is String => value,
      List() when value is List => value,
      _ => _invalid,
    };
    if (identical(coerced, _invalid)) {
      final kind = switch (d) { num() => 'a number', bool() => 'a boolean', String() => 'a string', List() => 'an array', _ => 'a value' };
      return fail('$key of a ${type.displayName} takes $kind (default ${d is String ? '"$d"' : d}), not $value.');
    }
    values[key] = coerced;
  }
  return (values: values, textures: textures, error: null);
}

const Object _invalid = Object();

void _applyProps(UmgEditorViewModel editor, UmgNode node, _Props prepared) {
  for (final e in prepared.values.entries) {
    editor.setProp(node.id, e.key, e.value);
  }
  for (final e in prepared.textures.entries) {
    editor.bindTexture(node.id, e.value);
  }
}

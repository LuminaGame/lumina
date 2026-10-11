import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/scheduler.dart' show SchedulerBinding;
import 'package:lumina_editor_data/lumina_editor.dart'
    show LuminaBlueprintNodeLibrary, LuminaBlueprintVariable, LuminaEditorPanelCapability, LuminaEditorWidgetEvents, LuminaJsonBlueprintNodes, LuminaPinType, LuminaUmgElementBinding, LuminaWidgetEvents;

import 'package:lumina_ui/ui/core/editor_panels/editor_panel_host.dart';
import 'package:lumina_ui/ui/core/editor_panels/editor_panel_runtime.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_frame_capture.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_protocol.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_tool.dart';

/// Editor panel Widget Blueprints over MCP: list, open, close, read the
/// state of, interact with (the path a user's click takes) and screenshot
/// the docked panels; and every custom event a trusted panel with the `mcp`
/// capability marks "Expose to MCP" as its own tool,
/// `panel_<owner>_<event>`, typed from the event's inputs.
void registerEditorPanelTools(McpToolRegistry registry, EditorViewModel vm) {
  EditorPanelHost host() => vm.editorPanels;

  EditorPanelRuntime panel(McpArgs args) {
    final id = args.string('panel');
    final rt = host().panel(id);
    if (rt == null) {
      throw StateError("No editor panel '$id'. editor_panels_list names them: ${host().panels.keys.join(', ')}");
    }
    return rt;
  }

  Map<String, Object?> describe(EditorPanelRuntime rt) => {
        'id': rt.id,
        'title': rt.title,
        'dock': rt.info.dock.name,
        'owner': rt.entry.owner,
        'asset': rt.entry.assetPath,
        'capabilities': [for (final c in rt.info.capabilities) c.name],
        'trusted': host().isTrusted(rt.id),
        'running': host().instancesOf(rt.id).any((i) => i.script != null),
        'open': host().isOpen(rt.id),
        'errors': rt.errors,
        'warnings': rt.warnings,
      };

  Map<String, Object?> state(EditorPanelInstance i) => {
        'panel': i.panelId,
        'elements': LuminaJsonBlueprintNodes.plain(i.elements),
        'variables': LuminaJsonBlueprintNodes.plain(i.script?.variables ?? const {}),
        if (i.stoppedMessage != null) 'stopped': i.stoppedMessage,
        if (i.reloadErrors != null) 'reloadErrors': i.reloadErrors,
      };

  EditorPanelInstance running(EditorPanelRuntime rt) {
    if (!host().isTrusted(rt.id)) throw StateError('${rt.title} is a project panel the user has not trusted yet.');
    if (!host().isOpen(rt.id)) vm.editorPanelDocking.open(rt.id);
    final instance = host().instancesOf(rt.id).firstOrNull;
    if (instance == null || instance.script == null && rt.graphClass != null) {
      throw StateError('${rt.title} does not run${rt.hasErrors ? ': ${rt.errors.first}' : ''}.');
    }
    return instance;
  }

  McpToolResult guarded(McpToolResult Function() body) {
    try {
      return body();
    } on StateError catch (e) {
      return McpToolResult.error(e.message);
    }
  }

  final panelArg = McpSchema.string('The panel id (editor_panels_list), `<plugin>/<asset path>` or `project/<asset path>`.');

  registry.registerAll([
    McpTool(
      name: 'editor_panels_list',
      risk: McpToolRisk.readOnly,
      groups: const {McpToolGroups.plugin, McpToolGroups.umg},
      title: 'List editor panels',
      description: 'The editor panel Widget Blueprints the editor found in the enabled content plugins and the project: '
          'id, title, dock, owner, declared capabilities, whether it is trusted, open and running, and its compile errors.',
      inputSchema: McpSchema.object({}),
      handler: (_) => McpToolResult.json({
        'panels': [for (final rt in host().panels.values) describe(rt)],
      }),
    ),
    McpTool(
      name: 'editor_panel_open',
      risk: McpToolRisk.editorState,
      groups: const {McpToolGroups.plugin, McpToolGroups.umg},
      title: 'Open editor panel',
      description: 'Opens an editor panel where it docks (right dock, bottom tab, workspace tab; a dialog modally) and '
          'answers its state.',
      inputSchema: McpSchema.object({'panel': panelArg}, required: ['panel']),
      handler: (args) => guarded(() {
        final rt = panel(args);
        vm.editorPanelDocking.open(rt.id);
        final i = host().instancesOf(rt.id).firstOrNull;
        return McpToolResult.json({...describe(rt), if (i != null) 'state': state(i)});
      }),
    ),
    McpTool(
      name: 'editor_panel_close',
      risk: McpToolRisk.editorState,
      groups: const {McpToolGroups.plugin, McpToolGroups.umg},
      title: 'Close editor panel',
      description: 'Closes an editor panel (its Destruct runs).',
      inputSchema: McpSchema.object({'panel': panelArg}, required: ['panel']),
      handler: (args) => guarded(() {
        final rt = panel(args);
        vm.editorPanelDocking.close(rt.id);
        return McpToolResult.json(describe(rt));
      }),
    ),
    McpTool(
      name: 'editor_panel_state',
      risk: McpToolRisk.readOnly,
      groups: const {McpToolGroups.plugin, McpToolGroups.umg},
      title: 'Editor panel state',
      description: "An open editor panel's element states (text, value, percent, selected, visibility, isEnabled, …) and "
          'graph variables as JSON.',
      inputSchema: McpSchema.object({'panel': panelArg}, required: ['panel']),
      handler: (args) => guarded(() {
        final rt = panel(args);
        final i = host().instancesOf(rt.id).firstOrNull;
        if (i == null) return McpToolResult.error('${rt.title} is not open: editor_panel_open it first.');
        return McpToolResult.json(state(i));
      }),
    ),
    McpTool(
      name: 'editor_panel_interact',
      risk: McpToolRisk.mutating,
      groups: const {McpToolGroups.plugin, McpToolGroups.umg},
      title: 'Interact with editor panel',
      description: 'Fires an element event of a running editor panel, the same path a user\'s click takes: action '
          '"click" (On Clicked), "value" (On Value Changed with value), "text_commit" (On Text Committed with value) or '
          '"select" (a Tree / List View\'s On Item Selected with value as the item id); or any event by name with args. '
          'Answers the panel\'s state afterwards. Edits it makes are undoable.',
      inputSchema: McpSchema.object({
        'panel': panelArg,
        'element': McpSchema.string('The element\'s designer name.'),
        'action': McpSchema.string('click, value, text_commit, select or event.', enumValues: ['click', 'value', 'text_commit', 'select', 'event']),
        'value': McpSchema.any('The value, text or item id.'),
        'event': McpSchema.string('With action "event": the event name (OnItemDoubleClicked, OnAssetPicked, …).'),
        'args': McpSchema.any('With action "event": the event\'s outputs as an object.'),
      }, required: ['panel', 'element', 'action']),
      handler: (args) => guarded(() {
        final rt = panel(args);
        final i = running(rt);
        final element = args.string('element');
        if (i.element(element) == null) return McpToolResult.error("${rt.title} has no element '$element'.");
        final value = args['value'];
        switch (args.string('action')) {
          case 'click':
            host().fire(i, element, LuminaWidgetEvents.onClicked);
          case 'value':
            LuminaUmgElementBinding.write(i.map, element, 'value', value);
            host().fire(i, element, LuminaWidgetEvents.onValueChanged, {'value': value});
          case 'text_commit':
            LuminaUmgElementBinding.write(i.map, element, 'text', '$value');
            host().fire(i, element, LuminaWidgetEvents.onTextCommitted, {'text': '$value', 'commit_method': 'OnEnter'});
          case 'select':
            LuminaUmgElementBinding.write(i.map, element, 'selected', ['$value']);
            host().fire(i, element, LuminaEditorWidgetEvents.onItemSelected, {'item_id': '$value', 'selected_ids': ['$value']});
          default:
            final extra = args['args'];
            host().fire(i, element, args.string('event'), extra is Map ? {for (final e in extra.entries) '${e.key}': e.value} : const {});
        }
        return McpToolResult.json(state(i));
      }),
    ),
    McpTool(
      name: 'editor_panel_screenshot',
      risk: McpToolRisk.readOnly,
      groups: const {McpToolGroups.plugin, McpToolGroups.umg, McpToolGroups.view},
      title: 'Editor panel screenshot',
      description: 'A PNG of a docked editor panel as it is on screen, returned as MCP image content. The panel must '
          'be open and shown.',
      inputSchema: McpSchema.object({
        'panel': panelArg,
        'max_width': McpSchema.integer('Largest width in pixels; default 1280.'),
      }, required: ['panel']),
      handler: (args) async {
        final EditorPanelRuntime rt;
        try {
          rt = panel(args);
        } on StateError catch (e) {
          return McpToolResult.error(e.message);
        }
        final i = host().instancesOf(rt.id).firstOrNull;
        if (i == null) return McpToolResult.error('${rt.title} is not open: editor_panel_open it first.');
        final binding = SchedulerBinding.instance;
        for (var n = 0; n < 20; n++) {
          final render = i.boundaryKey.currentContext?.findRenderObject();
          if (render is RenderRepaintBoundary && render.attached && !render.debugNeedsPaint) break;
          binding.scheduleFrame();
          await binding.endOfFrame.timeout(const Duration(milliseconds: 100), onTimeout: () {});
        }
        try {
          final frame = await McpFrameCapture.capture(i.boundaryKey, maxWidth: args.integer('max_width', fallback: 1280), what: rt.title);
          return McpToolResult([
            McpContent.image(frame.png),
            McpContent.text('${frame.width}×${frame.height} PNG of the editor panel ${rt.title}.'),
          ], structuredContent: {'width': frame.width, 'height': frame.height, 'panel': rt.id});
        } on StateError catch (e) {
          return McpToolResult.error(e.message);
        }
      },
    ),
  ]);

  // "Expose to MCP" custom events, kept in step with the panels.
  final exposed = <String>{};
  void sync() {
    final next = <String, McpTool>{};
    for (final rt in host().panels.values) {
      if (!rt.info.allows(LuminaEditorPanelCapability.mcp) || !host().isTrusted(rt.id) || rt.graphClass == null) continue;
      for (final node in rt.graphClass!.document.eventGraph.nodes) {
        if (node.registryId != LuminaBlueprintNodeLibrary.customEvent || node.literals['exposeToMcp'] != true) continue;
        final event = '${node.literals['name'] ?? ''}';
        if (event.isEmpty) continue;
        final name = editorPanelToolName(rt.entry.owner, event);
        final params = LuminaBlueprintNodeLibrary.customEventParameters(node);
        next[name] = McpTool(
          name: name,
          risk: McpToolRisk.mutating,
          groups: const {McpToolGroups.plugin},
          title: '${rt.title}: ${LuminaBlueprintNodeLibrary.displayTitle(event)}',
          description: 'Runs the custom event $event of the editor panel ${rt.title} (${rt.id}) and answers the panel\'s '
              'state afterwards. ${node.literals['mcpDescription'] ?? ''}'.trim(),
          inputSchema: McpSchema.object({
            for (final p in params) p.name: _schemaOf(p),
          }, required: [for (final p in params) p.name]),
          handler: (args) => guarded(() {
            final i = running(rt);
            i.script!.callBlueprint(event, {for (final p in params) p.name: args[p.name]});
            host().eventFinished(i);
            return McpToolResult.json(state(i));
          }),
        );
      }
    }
    for (final old in exposed.difference(next.keys.toSet())) {
      registry.unregister(old);
    }
    for (final t in next.values) {
      registry.register(t);
    }
    exposed
      ..clear()
      ..addAll(next.keys);
  }

  host().addListener(sync);
  sync();
}

/// `panel_<owner>_<event>` with anything outside `[A-Za-z0-9_]` as `_`.
String editorPanelToolName(String owner, String event) =>
    'panel_${owner}_$event'.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_');

Map<String, Object?> _schemaOf(LuminaBlueprintVariable p) => switch (p.type) {
      LuminaPinType.string || LuminaPinType.name || LuminaPinType.enumeration => McpSchema.string(p.name),
      LuminaPinType.integer => McpSchema.integer(p.name),
      LuminaPinType.float => McpSchema.number(p.name),
      LuminaPinType.boolean => McpSchema.boolean(p.name),
      _ => McpSchema.any(p.name),
    };

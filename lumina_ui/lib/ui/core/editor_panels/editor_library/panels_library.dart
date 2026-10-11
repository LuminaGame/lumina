import 'dart:async';

import 'package:lumina_editor_data/lumina_editor.dart';

import 'package:lumina_ui/ui/core/editor_panels/editor_library/editor_library.dart';
import 'package:lumina_ui/ui/core/editor_panels/editor_panel_host.dart';
import 'package:lumina_ui/ui/core/editor_panels/editor_panel_runtime.dart';

const String _panels = 'Editor|Panels';

/// Panels and the project: open another panel of the same owner (a dialog
/// answers with its Result Json), close this one, the project's name, the
/// plugin's own settings (PluginStorage) and its project settings
/// (`.lmproject`), whether Play is running.
final List<EditorLibraryNode> panelsLibraryNodes = [
  EditorLibraryNode(
    latentNode('editor_open_editor_panel', 'Open Editor Panel', _panels,
        inputs: [strPin('panel', 'Panel')],
        results: [exec('closed', 'Closed')],
        outputs: [jsonPin('result', 'Result')],
        tooltip: 'Opens another editor panel of the same plugin (or project) by its asset path (EPW_Settings.lmas or '
            'content/EPW_Settings.lmas). A dialog panel is modal: Closed fires when it closes, with the Json it passed to '
            'Close This Panel (null when dismissed).'),
    latent: (c, i, resume) {
      final call = editorPanelCall(c);
      if (call == null) return;
      final r = resumer(call.host, call.instance, resume);
      final target = call.host.resolvePanel(call.instance.runtime, inStr(i, 'panel'));
      if (target == null) {
        call.host.vm.logger.log("Editor panel ${call.instance.runtime.title}: no panel '${inStr(i, 'panel')}' of its owner.",
            level: 'warning', source: 'Editor Panels');
        scheduleMicrotask(() => r('closed', {'result': null}));
        return;
      }
      call.host.openFromGraph(target).then((result) => r('closed', {'result': result}));
    },
  ),
  EditorLibraryNode(
    impureNode('editor_close_this_panel', 'Close This Panel', _panels,
        inputs: [jsonPin('result', 'Result')], tooltip: 'Closes this panel (Destruct); a dialog answers its opener with Result.'),
    function: (c, i) {
      final call = editorPanelCall(c);
      if (call != null) {
        final result = i['result'];
        // After this event finishes: closing destroys the running script.
        scheduleMicrotask(() => call.host.closeFromGraph(call.instance, result));
      }
      return const {};
    },
  ),
  EditorLibraryNode(
    pureNode('editor_get_project_name', 'Get Project Name', _panels, outputs: [ret(LuminaPinType.string)]),
    function: (c, _) => {'return_value': editorPanelCall(c)?.host.vm.project.projectName ?? ''},
  ),
  EditorLibraryNode(
    pureNode('editor_is_play_active', 'Is Play Active', _panels, outputs: [ret(LuminaPinType.boolean)]),
    function: (c, _) => {'return_value': editorPanelCall(c)?.host.vm.isPlaying ?? false},
  ),
  EditorLibraryNode(
    latentNode('editor_get_plugin_setting', 'Get Plugin Setting', _panels,
        inputs: [strPin('key', 'Key'), boolPin('project', 'Per Project')],
        results: [exec('completed', 'Completed'), exec('failed', 'Failed')],
        outputs: [jsonPin('value', 'Value'), strPin('error', 'Error')],
        tooltip: 'The plugin\'s own stored value (PluginStorage, per user or per project). Plugin panels only.'),
    latent: (c, i, resume) => _storage(c, i, resume, write: false),
  ),
  EditorLibraryNode(
    latentNode('editor_set_plugin_setting', 'Set Plugin Setting', _panels,
        inputs: [strPin('key', 'Key'), jsonPin('value', 'Value'), boolPin('project', 'Per Project')],
        results: [exec('completed', 'Completed'), exec('failed', 'Failed')],
        outputs: [strPin('error', 'Error')],
        tooltip: 'Stores a value in the plugin\'s PluginStorage (secrets belong here, never in the project). Plugin panels only.'),
    latent: (c, i, resume) => _storage(c, i, resume, write: true),
  ),
  EditorLibraryNode(
    pureNode('editor_get_project_plugin_setting', 'Get Project Plugin Setting', _panels,
        inputs: [strPin('key', 'Key')], outputs: [ret(LuminaPinType.json), boolPin('found', 'Found')],
        tooltip: 'The plugin\'s project settings in the .lmproject (what its process receives as pluginSettings). Plugin panels only.'),
    function: (c, i) {
      final call = editorPanelCall(c);
      final plugin = call?.instance.runtime.entry.isProjectPanel == false ? call!.instance.runtime.entry.owner : null;
      final values = plugin == null ? null : call!.host.vm.project.pluginSettings[plugin];
      final key = inStr(i, 'key');
      return {'return_value': LuminaJsonBlueprintNodes.plain(values?[key]), 'found': values?.containsKey(key) ?? false};
    },
  ),
  EditorLibraryNode(
    latentNode('editor_set_project_plugin_setting', 'Set Project Plugin Setting', _panels,
        inputs: [strPin('key', 'Key'), jsonPin('value', 'Value')],
        results: [exec('completed', 'Completed'), exec('failed', 'Failed')],
        outputs: [strPin('error', 'Error')],
        tooltip: 'Writes the plugin\'s project setting into the .lmproject (null removes it); the plugin process receives '
            'it as pluginSettings. Secret-looking keys are refused. Plugin panels only.'),
    latent: (c, i, resume) {
      final call = editorPanelCall(c);
      if (call == null) return;
      final r = resumer(call.host, call.instance, resume);
      final entry = call.instance.runtime.entry;
      if (entry.isProjectPanel) {
        scheduleMicrotask(() => r('failed', {'error': 'Project plugin settings belong to a plugin; this is a project panel.'}));
        return;
      }
      final value = i['value'];
      call.instance.settings?.set(inStr(i, 'key'), value);
      call.host.vm.setProjectPluginSetting(entry.owner, inStr(i, 'key'), value).then((_) => r('completed'),
          onError: (Object e) => r('failed', {'error': e is ArgumentError ? '${e.message}' : '$e'}));
    },
  ),
];

void _storage(LuminaBlueprintCallContext c, Map<String, Object?> i, void Function(String, Map<String, Object?>) resume,
    {required bool write}) {
  final call = editorPanelCall(c);
  if (call == null) return;
  final r = resumer(call.host, call.instance, resume);
  final entry = call.instance.runtime.entry;
  if (entry.isProjectPanel) {
    scheduleMicrotask(() => r('failed', {'error': 'Plugin settings belong to a plugin; this is a project panel.'}));
    return;
  }
  final storage = call.host.vm.extensionRegistry.storageFor(entry.owner);
  final project = i['project'] == true;
  const file = 'editor_panels';
  final key = inStr(i, 'key');
  () async {
    try {
      final data = Map<String, Object?>.of(await storage.readJson(file, project: project) ?? const {});
      if (!write) {
        r('completed', {'value': data[key]});
        return;
      }
      final value = i['value'];
      if (value == null) {
        data.remove(key);
      } else {
        data[key] = LuminaJsonBlueprintNodes.plain(value);
      }
      await storage.writeJson(file, data, project: project);
      r('completed');
    } on Object catch (e) {
      r('failed', {'error': '$e'});
    }
  }();
}

/// The menu items an instance added go when it closes.
void panelsLibraryClosed(EditorPanelHost host, EditorPanelInstance instance) => host.removeMenuItems(instance);

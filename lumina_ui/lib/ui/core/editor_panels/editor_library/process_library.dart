import 'dart:async';

import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:lumina_editor_data/lumina_editor.dart';

import 'package:lumina_ui/ui/core/editor_panels/editor_library/editor_library.dart';

const String _process = 'Editor|Plugin Process';
const String _processCap = 'process';

/// The owning plugin's process: call a method of its `core.call` handlers
/// (30 s timeout; a process that is down fails at once with `unavailable`,
/// never hangs) and read its state. Its events and state changes reach the
/// graph as `On Plugin Process Event` / `On Plugin Process State Changed`.
final List<EditorLibraryNode> processLibraryNodes = [
  EditorLibraryNode(
    latentNode('editor_call_plugin_process', 'Call Plugin Process', _process,
        inputs: [strPin('method', 'Method'), jsonPin('args', 'Args')],
        results: [exec('completed', 'Completed'), exec('failed', 'Failed')],
        outputs: [jsonPin('result', 'Result'), strPin('error_code', 'Error Code'), strPin('error_message', 'Error Message')],
        capability: _processCap,
        tooltip: 'Calls Method in the panel\'s plugin process with Args (a Json object). Plugin panels only.'),
    latent: (c, i, resume) {
      final call = editorPanelCall(c);
      if (call == null) return;
      final r = resumer(call.host, call.instance, resume);
      final entry = call.instance.runtime.entry;
      void fail(String code, String message) => r('failed', {'error_code': code, 'error_message': message});
      if (entry.isProjectPanel) {
        scheduleMicrotask(() => fail(PluginErrorCodes.unavailable, 'A project panel has no plugin process.'));
        return;
      }
      final channel = call.host.vm.extensionRegistry.processChannel(entry.owner);
      if (!channel.state.value.isAvailable) {
        scheduleMicrotask(() => fail(PluginErrorCodes.unavailable, 'The plugin process is ${channel.state.value.status.name}.'));
        return;
      }
      final args = i['args'];
      channel
          .call(inStr(i, 'method'), args is Map ? {for (final e in args.entries) '${e.key}': e.value} : const {})
          .then((result) => r('completed', {'result': LuminaJsonBlueprintNodes.plain(result)}), onError: (Object e) {
        if (e is PluginRemoteError) {
          fail(e.code, e.message);
        } else {
          fail(PluginErrorCodes.internal, '$e');
        }
      });
    },
  ),
  EditorLibraryNode(
    latentNode('editor_restart_plugin_process', 'Restart Plugin Process', _process,
        results: [exec('completed', 'Completed'), exec('failed', 'Failed')],
        outputs: [strPin('error_message', 'Error Message')],
        capability: _processCap,
        tooltip: "Restarts the panel's plugin process (a manual restart: the automatic restart count starts again). "
            'Completed once it runs again. Plugin panels only.'),
    latent: (c, i, resume) {
      final call = editorPanelCall(c);
      if (call == null) return;
      final r = resumer(call.host, call.instance, resume);
      final entry = call.instance.runtime.entry;
      if (entry.isProjectPanel) {
        scheduleMicrotask(() => r('failed', {'error_message': 'A project panel has no plugin process.'}));
        return;
      }
      call.host.vm.extensionRegistry
          .processChannel(entry.owner)
          .restart()
          .then((_) => r('completed', {'error_message': ''}), onError: (Object e) => r('failed', {'error_message': '$e'}));
    },
  ),
  EditorLibraryNode(
    pureNode('editor_get_plugin_process_state', 'Get Plugin Process State', _process,
        outputs: [ret(LuminaPinType.string)], capability: _processCap, tooltip: 'running, stopped, crashed or restarting.'),
    function: (c, _) {
      final call = editorPanelCall(c);
      final entry = call?.instance.runtime.entry;
      if (call == null || entry == null || entry.isProjectPanel) return {'return_value': 'stopped'};
      return {'return_value': processStateName(call.host.vm.extensionRegistry.processChannel(entry.owner).state.value)};
    },
  ),
];

/// The state a graph sees: running, stopped, crashed or restarting.
String processStateName(PluginProcessState state) => switch (state.status) {
      PluginProcessStatus.running || PluginProcessStatus.inProcess => 'running',
      PluginProcessStatus.crashed || PluginProcessStatus.hung => 'crashed',
      PluginProcessStatus.starting => state.restarts > 0 ? 'restarting' : 'starting',
      PluginProcessStatus.stopped || PluginProcessStatus.disabled => 'stopped',
    };

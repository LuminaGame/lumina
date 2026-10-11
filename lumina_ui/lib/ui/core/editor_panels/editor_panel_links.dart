import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:lumina_editor_data/lumina_editor.dart';

import 'package:lumina_ui/ui/core/editor_panels/editor_library/process_library.dart';
import 'package:lumina_ui/ui/core/editor_panels/editor_panel_host.dart';
import 'package:lumina_ui/ui/core/services/plugin_process/plugin_process_supervisor.dart';

/// What reaches running panels from outside their own graph: the editor's
/// events (selection, level edits, Content Browser selection), the plugin
/// sources changing (a plugin enabled or disabled), and the owning plugin's
/// process (its events, its state, and `host.panelState` patches, applied
/// to the element states directly at most 30 times a second per panel).
class EditorPanelLinks {
  EditorPanelLinks(this.host);

  final EditorPanelHost host;

  /// The fastest a panel is patched: under 30 times a second, bursts coalesced.
  static const Duration patchInterval = Duration(milliseconds: 34);

  List<String> _selection = const [];
  List<String> _browserSelection = const [];
  String _sources = '';
  bool _levelPending = false;
  final Map<String, _ProcessLink> _processes = {};
  final Map<String, PluginPanelStatePatch> _pending = {};
  final Map<String, DateTime> _lastFlush = {};
  final Set<String> _unknownLogged = {};
  Timer? _flush;

  void start() {
    _selection = host.vm.selectedActorIds.toList();
    _browserSelection = host.vm.contentBrowserSelection.toList();
    _sources = _sourceSignature();
    host.vm.addListener(_onEditor);
    host.vm.transactions.addListener(_onLevelEdit);
    host.addListener(_syncProcesses);
    _syncProcesses();
  }

  void dispose() {
    host.vm.removeListener(_onEditor);
    host.vm.transactions.removeListener(_onLevelEdit);
    host.removeListener(_syncProcesses);
    for (final l in _processes.values) {
      l.cancel();
    }
    _processes.clear();
    _flush?.cancel();
  }

  String _sourceSignature() => [for (final s in host.vm.editorPanelSources()) '${s.owner}|${s.scanDir}'].join(';');

  void _onEditor() {
    final sel = host.vm.selectedActorIds.toList();
    if (!listEquals(sel, _selection)) {
      _selection = sel;
      host.dispatch(LuminaEditorEventNodes.selectionChanged, {'selected_ids': sel});
    }
    final browser = host.vm.contentBrowserSelection.toList();
    if (!listEquals(browser, _browserSelection)) {
      _browserSelection = browser;
      host.dispatch(LuminaEditorEventNodes.contentBrowserSelectionChanged, {'asset_paths': browser});
    }
    final sources = _sourceSignature();
    if (sources != _sources) {
      _sources = sources;
      unawaited(host.refreshSources());
    }
  }

  void _onLevelEdit() {
    if (_levelPending) return;
    _levelPending = true;
    scheduleMicrotask(() {
      _levelPending = false;
      host.dispatch(LuminaEditorEventNodes.levelChanged, const {});
    });
  }

  // --- The plugin process -------------------------------------------------------

  void _syncProcesses() {
    final owners = {
      for (final rt in host.panels.values)
        if (!rt.entry.isProjectPanel) rt.entry.owner,
    };
    for (final owner in _processes.keys.toList()) {
      if (!owners.contains(owner)) _processes.remove(owner)!.cancel();
    }
    for (final owner in owners) {
      final channel = host.vm.extensionRegistry.processChannel(owner);
      final existing = _processes[owner];
      if (existing != null && identical(existing.channel, channel)) continue;
      existing?.cancel();
      _processes[owner] = _ProcessLink(owner, channel, this);
    }
  }

  void _processEvent(String owner, PluginProcessEvent event) {
    for (final rt in host.panels.values) {
      if (rt.entry.owner != owner || !rt.info.allows(LuminaEditorPanelCapability.process)) continue;
      host.dispatch(LuminaEditorEventNodes.pluginProcessEvent, {'name': event.name, 'data': LuminaJsonBlueprintNodes.plain(event.data)},
          panelId: rt.id, where: (node) {
        final filter = node.literals['event'];
        return filter is! String || filter.isEmpty || filter == event.name;
      });
    }
  }

  void _processState(String owner, PluginProcessState state) {
    for (final rt in host.panels.values) {
      if (rt.entry.owner != owner || !rt.info.allows(LuminaEditorPanelCapability.process)) continue;
      host.dispatch(LuminaEditorEventNodes.pluginProcessStateChanged, {'state': processStateName(state)}, panelId: rt.id);
    }
  }

  /// Queues [patch] from [owner]'s process; applied on the next flush.
  void patch(String owner, PluginPanelStatePatch patch) {
    final key = '$owner|${_normalise(patch.panel)}';
    final queued = _pending[key];
    _pending[key] = queued == null ? patch : queued.merge(patch);
    _schedule();
  }

  void _schedule() {
    if (_flush != null) return;
    _flush = Timer(patchInterval, _apply);
  }

  void _apply() {
    _flush = null;
    final now = DateTime.now();
    for (final key in _pending.keys.toList()) {
      final last = _lastFlush[key];
      if (last != null && now.difference(last) < patchInterval) continue;
      final patch = _pending.remove(key)!;
      _lastFlush[key] = now;
      final owner = key.substring(0, key.indexOf('|'));
      _applyPatch(owner, patch);
    }
    if (_pending.isNotEmpty) _schedule();
  }

  void _applyPatch(String owner, PluginPanelStatePatch patch) {
    final path = _normalise(patch.panel);
    for (final instance in host.openInstances) {
      final entry = instance.runtime.entry;
      if (entry.owner != owner || _normalise(entry.assetPath) != path) continue;
      for (final op in patch.ops) {
        final element = instance.element(op.element);
        if (element == null) {
          if (_unknownLogged.add('${instance.panelId}|${op.element}')) {
            host.vm.logger.log("Editor panel ${instance.runtime.title}: the plugin process patched an unknown element '${op.element}'.",
                level: 'warning', source: 'Editor Panels');
          }
          continue;
        }
        element.addAll(op.set);
      }
      instance.refresh();
    }
  }

  /// `content/EPW_X.lmas` and `EPW_X.lmas` name the same panel.
  static String _normalise(String path) {
    final p = path.replaceAll(r'\', '/');
    return p.startsWith('content/') ? p.substring('content/'.length) : p;
  }
}

class _ProcessLink {
  _ProcessLink(this.owner, this.channel, EditorPanelLinks links) {
    _events = channel.events().listen((e) => links._processEvent(owner, e));
    final self = channel;
    if (self is PluginProcessSupervisor) _patches = self.panelStates.listen((p) => links.patch(owner, p));
    _last = channel.state.value.status;
    void onState() {
      final s = channel.state.value;
      if (s.status == _last) return;
      _last = s.status;
      links._processState(owner, s);
    }

    _onState = onState;
    channel.state.addListener(onState);
  }

  final String owner;
  final PluginProcessChannel channel;
  late final StreamSubscription<PluginProcessEvent> _events;
  StreamSubscription<PluginPanelStatePatch>? _patches;
  late PluginProcessStatus _last;
  late final VoidCallback _onState;

  void cancel() {
    unawaited(_events.cancel());
    unawaited(_patches?.cancel());
    channel.state.removeListener(_onState);
  }
}

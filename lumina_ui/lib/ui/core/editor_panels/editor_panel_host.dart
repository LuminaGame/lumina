import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart' show EditorCommand;
import 'package:lumina_editor_data/lumina_editor.dart';

import 'package:lumina_ui/ui/core/editor_panels/editor_library/editor_library.dart';
import 'package:lumina_ui/ui/core/editor_panels/editor_panel_links.dart';
import 'package:lumina_ui/ui/core/editor_panels/editor_panel_runtime.dart';
import 'package:lumina_ui/ui/core/editor_panels/editor_panel_transactions.dart';
import 'package:lumina_ui/ui/core/editor_panels/editor_panel_trust.dart';
import 'package:lumina_ui/ui/core/editor_panels/editor_panel_world.dart';
import 'package:lumina_ui/ui/core/plugin_extension_registry.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';

/// Opens and closes a panel where it docks ([EditorPanelDocking]).
abstract interface class EditorPanelDockingTarget {
  void open(String panelId);
  void close(String panelId);
}

/// Where a panel stands with the user's trust.
enum EditorPanelTrust {
  /// A plugin's panel: trusted with its plugin.
  plugin,

  /// A project panel the user trusted with its current capabilities.
  trusted,

  /// A project panel not trusted yet (or whose capabilities grew).
  untrusted,
}

/// Runs editor panel Widget Blueprints in the editor: finds them
/// ([EditorPanelCatalog]), compiles each into the Blueprint VM in memory,
/// keeps their scripts in the editor registry (`LuminaUserWidgets.editor`)
/// inside a private headless world, and opens, closes and live-reloads
/// their instances. No Dart compile, no project editor build, no restart.
///
/// Docking (Window menu, right dock, bottom tabs, workspace tabs, dialogs,
/// Project Settings sections) is [EditorPanelDocking]'s; the editor
/// function library their graphs call is [EditorPanelLibrary]'s.
class EditorPanelHost extends ChangeNotifier {
  EditorPanelHost(this.vm, {EditorPanelCatalog? catalog, EditorPanelTrustStore? trust, EditorPanelWorld? world})
      : catalog = catalog ?? EditorPanelCatalog(),
        trust = trust ?? EditorPanelTrustStore(),
        world = world ?? EditorPanelWorld();

  final EditorViewModel vm;
  final EditorPanelCatalog catalog;
  final EditorPanelTrustStore trust;
  final EditorPanelWorld world;

  final Map<String, EditorPanelRuntime> _panels = {};
  final Map<String, List<EditorPanelInstance>> _open = {};
  final Set<String> _shown = {};
  late final EditorPanelTransactions transactions = EditorPanelTransactions(this);
  late final EditorPanelLinks links = EditorPanelLinks(this);

  /// Opens and closes panels where they dock (set by the docking).
  EditorPanelDockingTarget? docking;
  final Map<String, List<Completer<Object?>>> _closeWaiters = {};
  StreamSubscription<List<EditorPanelEntry>>? _changes;
  bool _started = false;
  bool _disposed = false;
  int _serial = 0;

  /// Called after every reload with how long the swap took (live reload
  /// is within 500 ms of the save).
  void Function(String panelId, Duration took)? onReloaded;

  /// Every compiled panel, by id.
  Map<String, EditorPanelRuntime> get panels => Map.unmodifiable(_panels);

  EditorPanelRuntime? panel(String id) => _panels[id];

  /// The open instances of [id] (a panel open in two tabs has two).
  List<EditorPanelInstance> instancesOf(String id) => List.unmodifiable(_open[id] ?? const []);

  /// Every open instance.
  Iterable<EditorPanelInstance> get openInstances => _open.values.expand((l) => l);

  bool isOpen(String id) => (_open[id] ?? const []).isNotEmpty;

  bool get isStarted => _started;

  /// Starts discovery: the enabled content plugins' `content/` and the
  /// project's `contents/`, watched for live reload.
  Future<void> start() async {
    if (_started || _disposed) return;
    _started = true;
    EditorPanelLibrary.ensureRegistered();
    await trust.load();
    _changes = catalog.changes.listen(_onCatalog);
    links.start();
    await refreshSources();
  }

  /// Rescans with the current sources (plugins enabled or disabled).
  Future<void> refreshSources() async {
    if (!_started || _disposed) return;
    final sources = vm.editorPanelSources();
    final same = listEquals([for (final s in sources) '${s.owner}|${s.scanDir}'],
        [for (final s in catalog.sources) '${s.owner}|${s.scanDir}']);
    if (same && catalog.sources.isNotEmpty) {
      await catalog.refresh();
    } else {
      await catalog.setSources(sources);
    }
  }

  // --- Catalog → compiled panels -------------------------------------------

  void _onCatalog(List<EditorPanelEntry> entries) {
    if (_disposed) return;
    final seen = <String>{};
    for (final entry in entries) {
      seen.add(entry.id);
      final previous = _panels[entry.id];
      if (previous != null && previous.entry.modified == entry.modified && previous.entry.displayTitle == entry.displayTitle) {
        continue;
      }
      final watch = Stopwatch()..start();
      final next = EditorPanelRuntime.compile(entry);
      if (previous != null && next.hasErrors && !previous.hasErrors && isOpen(entry.id)) {
        // A broken save: the last good version keeps running, under a banner.
        for (final i in _open[entry.id]!) {
          i.reloadErrors = next.errors;
        }
        vm.logger.log('Editor panel ${entry.displayTitle}: the saved version has errors; the last good one keeps running:\n'
            '${next.errors.join('\n')}', level: 'error', source: 'Editor Panels');
        continue;
      }
      _panels[entry.id] = next;
      if (previous != null) _swap(previous, next);
      onReloaded?.call(entry.id, watch.elapsed);
    }
    for (final id in _panels.keys.toList()) {
      if (seen.contains(id)) continue;
      close(id);
      _panels.remove(id);
    }
    notifyListeners();
  }

  /// Recompiles [id] from disk now (the designer's Compile of an open
  /// panel asset, a Reload button).
  Future<void> reload(String id) async {
    await catalog.refresh();
    final rt = _panels[id];
    if (rt == null) return;
    for (final i in List.of(_open[id] ?? const <EditorPanelInstance>[])) {
      if (i.stoppedMessage != null) {
        i.stoppedMessage = null;
        _restart(i, rt);
      }
    }
    notifyListeners();
  }

  // --- Trust -----------------------------------------------------------------

  EditorPanelTrust trustOf(String id) {
    final rt = _panels[id];
    if (rt == null || !rt.entry.isProjectPanel) return EditorPanelTrust.plugin;
    return trust.isTrusted(vm.projectDirPath, rt.entry.assetPath, rt.info.capabilityHash)
        ? EditorPanelTrust.trusted
        : EditorPanelTrust.untrusted;
  }

  bool isTrusted(String id) => trustOf(id) != EditorPanelTrust.untrusted;

  /// The project panels not trusted yet.
  List<EditorPanelRuntime> get untrustedProjectPanels =>
      [for (final rt in _panels.values) if (trustOf(rt.id) == EditorPanelTrust.untrusted) rt];

  /// "Trust and run": stores the decision for [ids] (default: every
  /// untrusted project panel) and starts those already open.
  Future<void> trustProjectPanels([Iterable<String>? ids]) async {
    final targets = [for (final rt in ids == null ? untrustedProjectPanels : ids.map((i) => _panels[i]).nonNulls) rt];
    if (targets.isEmpty) return;
    await trust.trust(vm.projectDirPath, {for (final rt in targets) rt.entry.assetPath: rt.info.capabilityHash});
    for (final rt in targets) {
      for (final i in _open[rt.id] ?? const <EditorPanelInstance>[]) {
        if (i.script == null) _restart(i, rt);
      }
    }
    notifyListeners();
  }

  // --- Instances -------------------------------------------------------------

  /// Opens a new instance of [id] (Pre Construct + Construct when it can
  /// run), or returns the open one unless [another] is set.
  EditorPanelInstance? open(String id, {bool another = false}) {
    final rt = _panels[id];
    if (rt == null) return null;
    final existing = _open[id];
    if (!another && existing != null && existing.isNotEmpty) return existing.first;
    final instance = EditorPanelInstance(rt, rt.newInstanceMap(id), ++_serial);
    (_open[id] ??= []).add(instance);
    _start(instance);
    setShown(id, true);
    instance.map['inViewport'] = instance.constructed;
    notifyListeners();
    return instance;
  }

  /// Closes every instance of [id]: Destruct, then the script leaves the
  /// world; menu items it added go too.
  void close(String id, {EditorPanelInstance? only}) {
    final list = _open[id];
    if (list == null) return;
    for (final i in List.of(list)) {
      if (only != null && !identical(i, only)) continue;
      _stop(i);
      list.remove(i);
      if (i.dialogResult != null && !i.dialogResult!.isCompleted) i.dialogResult!.complete(null);
    }
    if (list.isEmpty) {
      _open.remove(id);
      setShown(id, false);
      for (final w in _closeWaiters.remove(id) ?? const <Completer<Object?>>[]) {
        if (!w.isCompleted) w.complete(null);
      }
    }
    notifyListeners();
  }

  // --- Opened and closed by a graph ---------------------------------------------

  /// The panel [name] names for a graph of [from]: an asset path of the same
  /// owner (`EPW_Settings.lmas`, `content/EPW_Settings.lmas`, without
  /// `.lmas` too), or a full panel id.
  EditorPanelRuntime? resolvePanel(EditorPanelRuntime from, String name) {
    final n = name.replaceAll(r'\', '/').trim();
    if (_panels[n] != null) return _panels[n];
    final file = n.endsWith('.lmas') ? n : '$n.lmas';
    for (final rt in _panels.values) {
      if (rt.entry.owner != from.entry.owner) continue;
      final path = rt.entry.assetPath;
      if (path == file || path.endsWith('/$file')) return rt;
    }
    return null;
  }

  /// Opens [target] where it docks and completes when it closes: with a
  /// dialog's Result Json, null otherwise (or when dismissed).
  Future<Object?> openFromGraph(EditorPanelRuntime target) {
    final waiter = Completer<Object?>();
    (_closeWaiters[target.id] ??= []).add(waiter);
    final docking = this.docking;
    if (docking == null) {
      open(target.id);
    } else {
      docking.open(target.id);
    }
    return waiter.future;
  }

  /// `Close This Panel`: closes [instance] answering [result] to whoever
  /// opened it.
  void closeFromGraph(EditorPanelInstance instance, Object? result) {
    final id = instance.panelId;
    for (final w in _closeWaiters.remove(id) ?? const <Completer<Object?>>[]) {
      if (!w.isCompleted) w.complete(result);
    }
    final dialog = instance.dialogResult;
    if (dialog != null && !dialog.isCompleted) dialog.complete(result);
    final docking = this.docking;
    if (docking == null) {
      close(id, only: instance);
    } else {
      docking.close(id);
    }
  }

  /// The panel's view should rebuild (progress, banners).
  void panelChanged(EditorPanelInstance instance) {
    if (!_disposed) notifyListeners();
  }

  // --- Menu items a graph adds ------------------------------------------------------

  /// `Add Panel Menu Item`: [label] under the owner's plugin menu (project
  /// panels: `Plugins/Project Panels/…`) runs custom event [event].
  void addMenuItem(EditorPanelInstance instance, String path, String label, String event) {
    final entry = instance.runtime.entry;
    final group = entry.isProjectPanel ? 'Project Panels' : vm.extensionRegistry.pluginTitle(entry.owner);
    final segments = ['Plugins', group, ...path.split('/').map((s) => s.trim()).where((s) => s.isNotEmpty), label.trim()];
    final commandId = 'editorPanel.menu.${instance.panelId}#${instance.serial}.${segments.join('/')}';
    instance.menuEvents[commandId] = event;
    _registerMenus(instance);
  }

  void removeMenuItems(EditorPanelInstance instance) {
    if (instance.menuEvents.isEmpty) return;
    instance.menuEvents.clear();
    vm.extensionRegistry.removeEditorPanelContributions(_menuOwner(instance));
  }

  static String _menuOwner(EditorPanelInstance i) => 'menus#${i.panelId}#${i.serial}';

  void _registerMenus(EditorPanelInstance instance) {
    vm.extensionRegistry.setEditorPanelContributions(_menuOwner(instance), (ctx) {
      for (final e in instance.menuEvents.entries) {
        final path = e.key.substring(e.key.indexOf('.Plugins/') + 1);
        ctx.registerMenuItem(
          path,
          EditorCommand(
            id: e.key,
            label: path.split('/').last,
            canExecute: () => instance.script != null,
            execute: (_) {
              instance.script?.callBlueprint(e.value, const {});
              _afterEvent(instance);
            },
          ),
        );
      }
    });
  }

  /// Whether [id] is on screen: the world ticks while any panel is, and a
  /// hidden panel gets no Event Tick.
  void setShown(String id, bool shown) {
    final changed = shown ? _shown.add(id) : _shown.remove(id);
    if (!changed) return;
    for (final i in _open[id] ?? const <EditorPanelInstance>[]) {
      i.map['inViewport'] = shown && i.constructed;
    }
    world.setActive(_shown.isNotEmpty && openInstances.isNotEmpty);
  }

  /// The instance a script belongs to (the editor library's way back from
  /// `self`).
  static EditorPanelInstance? instanceOfScript(Object? script) => script == null ? null : _byScript[script];
  static final Expando<EditorPanelInstance> _byScript = Expando('editor panel instance');

  /// The host of an instance.
  static EditorPanelHost? hostOf(EditorPanelInstance instance) => _hosts[instance];
  static final Expando<EditorPanelHost> _hosts = Expando('editor panel host');

  bool _canRun(EditorPanelRuntime rt) => !rt.hasErrors && isTrusted(rt.id);

  void _start(EditorPanelInstance instance) {
    _hosts[instance] = this;
    final rt = instance.runtime;
    final cls = rt.graphClass;
    if (!_canRun(rt) || cls == null) {
      instance.constructed = !rt.hasErrors && isTrusted(rt.id);
      return;
    }
    final registryClass = '${rt.id}#${instance.serial}';
    instance.map['class'] = registryClass;
    LuminaUserWidgets.editor.register(registryClass, cls.instantiateUserWidget);
    final script = LuminaUserWidgets.editor.attach(world.world, instance.map) as LuminaBlueprintUserWidget?;
    LuminaUserWidgets.editor.unregister(registryClass);
    if (script == null) return;
    instance.script = script;
    _byScript[script] = instance;
    script
      ..maxNodesPerEvent = kEditorPanelMaxNodes
      ..maxEventDuration = kEditorPanelMaxEventDuration
      ..onEventStopped = (event, message) {
        _stopped(instance, event, message);
      }
      ..trace = (e) {
        _traced(instance, e);
      };
    instance.map['inViewport'] = true;
    LuminaUserWidgets.addedToViewport(instance.map);
    instance.constructed = true;
    instance.map['inViewport'] = _shown.contains(rt.id);
    _afterEvent(instance);
  }

  void _stop(EditorPanelInstance instance) {
    final script = instance.script;
    if (script != null) {
      LuminaUserWidgets.removedFromParent(instance.map);
      _afterEvent(instance);
      if (script.world != null) world.world.destroyActor(script);
    }
    instance
      ..script = null
      ..constructed = false;
    EditorPanelLibrary.panelClosed(this, instance);
  }

  void _restart(EditorPanelInstance instance, EditorPanelRuntime rt) {
    _stop(instance);
    instance
      ..runtime = rt
      ..map = rt.newInstanceMap(rt.id)
      ..binding = LuminaUmgInstanceBinding(instance.map);
    _start(instance);
    instance.refresh();
  }

  /// Live reload: Destruct on the old script, element states kept where an
  /// element's name and type are unchanged (only what the panel changed at
  /// run time overrides the new designer values), graph variables kept where
  /// name and type match, Construct on the new script.
  void _swap(EditorPanelRuntime previous, EditorPanelRuntime next) {
    for (final instance in List.of(_open[next.id] ?? const <EditorPanelInstance>[])) {
      final oldElements = instance.elements;
      final oldDesign = {for (final e in previous.widgetClass.elements) e.name: e};
      final oldVars = {for (final v in previous.graphClass?.document.variables ?? const <LuminaBlueprintVariable>[]) v.name: v};
      final oldValues = Map<String, Object?>.of(instance.script?.variables ?? const {});
      _stop(instance);
      final map = next.newInstanceMap(next.id);
      final elements = map['elements'] as Map<String, Object?>;
      for (final e in next.widgetClass.elements) {
        final old = oldElements[e.name];
        final design = oldDesign[e.name];
        if (old is! Map || design == null || design.typeName != e.typeName) continue;
        final seeded = LuminaWidgetClassRegistry.newElementState(design);
        final state = elements[e.name] as Map<String, Object?>;
        for (final kv in old.entries) {
          if (!mapEquals({'v': seeded[kv.key]}, {'v': kv.value})) state['${kv.key}'] = kv.value;
        }
      }
      instance
        ..runtime = next
        ..map = map
        ..binding = LuminaUmgInstanceBinding(map)
        ..reloadErrors = null
        ..stoppedMessage = null;
      _start(instance);
      final script = instance.script;
      if (script != null) {
        for (final v in next.graphClass?.document.variables ?? const <LuminaBlueprintVariable>[]) {
          final old = oldVars[v.name];
          if (old != null && old.typeName == v.typeName && oldValues.containsKey(v.name)) {
            script.variables[v.name] = oldValues[v.name];
          }
        }
      }
      instance.refresh();
    }
  }

  // --- Events and rebuilds -----------------------------------------------------

  final Set<EditorPanelInstance> _pendingAfterEvent = {};

  void _traced(EditorPanelInstance instance, LuminaBlueprintTraceEvent e) {
    final printed = e.printed;
    if (printed != null) vm.logger.log(printed, level: 'info', source: 'Editor Panel ${instance.runtime.title}');
    if (_pendingAfterEvent.add(instance)) scheduleMicrotask(() => _afterEvent(instance));
  }

  /// After a run of the panel's graph: a transaction it left open is ended
  /// (with a warning), and the elements whose state changed rebuild.
  void _afterEvent(EditorPanelInstance instance) {
    _pendingAfterEvent.remove(instance);
    transactions.endLeftOpen(instance);
    if (!_disposed) instance.refresh();
  }

  void _stopped(EditorPanelInstance instance, String event, String message) {
    instance.stoppedMessage = 'Stopped: $event ran too long';
    vm.logger.log('Editor panel ${instance.runtime.title}: $message', level: 'error', source: 'Editor Panels');
    scheduleMicrotask(() {
      if (!_disposed) notifyListeners();
    });
  }

  /// Raises editor event [registryId] in every running instance (of
  /// [panelId] only, when given) whose node [where] accepts.
  void dispatch(String registryId, Map<String, Object?> outputs,
      {String? panelId, bool Function(LuminaBlueprintNode node)? where}) {
    for (final instance in List.of(openInstances)) {
      if (panelId != null && instance.panelId != panelId) continue;
      final script = instance.script;
      if (script == null || instance.stoppedMessage != null) continue;
      script.dispatchEvent(registryId, outputs, where: where);
      _afterEvent(instance);
    }
  }

  /// Fires element [event] of [element] in [instance], the path a click
  /// takes (MCP's `editor_panel_interact` too).
  void fire(EditorPanelInstance instance, String element, String event, [Map<String, Object?> args = const {}]) {
    LuminaUserWidgets.fire(instance.map, element, event, args);
    _afterEvent(instance);
  }

  /// A run of [instance]'s graph the host did not start (an MCP tool calling a
  /// custom event) has finished: open transactions end, elements rebuild.
  void eventFinished(EditorPanelInstance instance) => _afterEvent(instance);

  /// Runs a latent result into [instance]'s graph and ends its event.
  void resume(EditorPanelInstance instance, void Function() run) {
    if (instance.script == null) return;
    run();
    _afterEvent(instance);
  }

  @override
  void dispose() {
    _disposed = true;
    if (_started) links.dispose();
    for (final id in _open.keys.toList()) {
      close(id);
    }
    _changes?.cancel();
    catalog.dispose();
    world.dispose();
    super.dispose();
  }
}

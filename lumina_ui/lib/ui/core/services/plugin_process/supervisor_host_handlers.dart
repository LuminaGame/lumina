part of 'plugin_process_supervisor.dart';

/// A level transaction a plugin process opened (`beginTransaction`): the
/// editor's `runTransaction` body waits on [end]; edits the process makes
/// meanwhile run in its [zone], so they are one undo step.
class _Transaction {
  _Transaction(this.id);

  final int id;
  final Completer<void> end = Completer<void>();
  Zone? zone;
  Future<void>? done;
}

PluginRemoteError _badArgs(String message) => PluginRemoteError(code: PluginErrorCodes.badArguments, message: message);

String _str(Map<String, Object?> args, String key) {
  final v = args[key];
  if (v is String && v.isNotEmpty) return v;
  throw _badArgs('"$key" must be a non-empty string');
}

/// A JSON-safe copy (non-JSON values in component properties as text).
Object? _jsonSafe(Object? v) => switch (v) {
      null || bool() || num() || String() => v,
      List() => [for (final e in v) _jsonSafe(e)],
      Map() => {for (final e in v.entries) '${e.key}': _jsonSafe(e.value)},
      _ => '$v',
    };

extension _HostHandlers on PluginProcessSupervisor {
  void _bindHostHandlers(_Run run, PluginConnection conn) {
    conn
      ..onRequest(PluginMethods.register, (args) {
        _registered(run, PluginContributions.fromJson(args));
        return null;
      })
      ..onNotification(PluginMethods.event, (args) {
        if (!_events.isClosed) _events.add(PluginProcessEvent(args['name'] as String? ?? '', args['data']));
      })
      ..onNotification(PluginMethods.progress, (args) {
        if (!_progress.isClosed) _progress.add(PluginProgress.fromJson(args));
      })
      ..onNotification(PluginMethods.log, (args) {
        final level = args['level'] as String? ?? 'info';
        final message = args['message'] as String? ?? '';
        final source = args['source'] as String?;
        _appendLog('[$level] $message');
        host.logPlugin(source == null || source.isEmpty ? pluginName : source, message, level: level);
      })
      ..onNotification(PluginMethods.view, _onView)
      ..onNotification(PluginMethods.slotState, (args) {
        final id = args['id'] as String?;
        final slot = id == null ? null : _slots[id];
        final state = args['state'];
        if (slot == null || state is! Map) return;
        slot.spec = PluginButtonStateSpec.fromJson(state.cast());
        slot.notifier.value = _buttonState(slot.spec);
      })
      ..onNotification(PluginMethods.menuChecked, (args) {
        final path = args['path'] as String?;
        if (path != null) _checkedNotifier(path, args['checked'] == true);
      })
      ..onRequest(PluginMethods.level, (args) => _level(run, args))
      ..onRequest(PluginMethods.saveAsset, (args) async {
        final b64 = args['bytesBase64'] as String?;
        await host.saveAsset(
          relativePath: _str(args, 'relativePath'),
          bytes: b64 == null ? null : base64Decode(b64),
          generateThumbnail: args['generateThumbnail'] != false,
        );
        return null;
      })
      ..onRequest(PluginMethods.panels, (args) {
        final id = _str(args, 'panelId');
        switch (args['op']) {
          case 'show':
            host.panels.show(id);
            return null;
          case 'hide':
            host.panels.hide(id);
            return null;
          case 'isVisible':
            return host.panels.isVisible(id);
        }
        throw _badArgs('unknown panels op ${args['op']}');
      })
      ..onRequest(PluginMethods.tabs, (args) {
        if (args['op'] != 'openTab') throw _badArgs('unknown tabs op ${args['op']}');
        host.openTab(_str(args, 'tabId'), title: args['title'] as String?);
        return null;
      })
      ..onRequest(PluginMethods.mcpCall, (args) async {
        final result = await host.mcpFor(pluginName).callTool(
              _str(args, 'tool'),
              (args['arguments'] as Map?)?.cast<String, Object?>() ?? const {},
              caller: pluginName,
            );
        return result.toJson();
      });
  }

  void _onView(Map<String, Object?> args) {
    final viewId = args['viewId'] as String?;
    if (viewId == null) return;
    final notifier = _viewNotifier(viewId);
    final spec = args['spec'];
    final patch = args['patch'];
    if (spec is Map) {
      notifier.value = PluginViewSpec.fromJson(spec.cast());
    } else if (patch is Map) {
      notifier.value = notifier.value.apply(PluginViewPatch.fromJson(patch.cast()));
    }
  }

  Future<Object?> _level(_Run run, Map<String, Object?> args) async {
    final level = host.levelAccess;
    final op = args['op'];
    if (level == null) {
      if (op == 'snapshot') return null;
      throw const PluginRemoteError(code: PluginErrorCodes.unavailable, message: 'no level is open in the editor');
    }
    final label = args['label'] as String?;
    switch (op) {
      case 'beginTransaction':
        final tx = _Transaction(++_txSeq);
        final ready = Completer<void>();
        tx.done = level.runTransaction(label ?? pluginName, () async {
          tx.zone = Zone.current;
          ready.complete();
          await tx.end.future;
        });
        await ready.future;
        run.transactions.add(tx);
        return {'tx': tx.id};
      case 'endTransaction':
        final id = args['tx'];
        final i = run.transactions.indexWhere((t) => t.id == id);
        if (i < 0) throw _badArgs('no open transaction $id');
        final tx = run.transactions.removeAt(i);
        tx.end.complete();
        await tx.done;
        return null;
    }
    // Edits made inside an open transaction join its undo step: the one
    // named by "tx", else the innermost open one.
    final txId = args['tx'];
    final named = txId == null ? null : run.transactions.where((t) => t.id == txId).firstOrNull;
    final zone = named?.zone ?? (run.transactions.isEmpty ? null : run.transactions.last.zone);
    Future<Object?> body() => _levelOp(level, op, args, label);
    return zone == null ? body() : zone.run(body);
  }

  Future<Object?> _levelOp(EditorLevelAccess level, Object? op, Map<String, Object?> args, String? label) async {
    switch (op) {
      case 'snapshot':
        return {
          'projectDirPath': level.projectDirPath,
          'activeLevelPath': level.activeLevelPath,
          'actors': [for (final a in level.actors) _jsonSafe(EditorLevelJson.snapshotToJson(a))],
          'selectedActorIds': level.selectedActorIds,
          'undoTopLabel': level.undoTopLabel,
        };
      case 'addActors':
        final specs = [for (final a in (args['actors'] as List?) ?? const []) EditorLevelJson.specFromJson((a as Map).cast())];
        return level.addActors(specs, label: label);
      case 'removeActors':
        level.removeActors(((args['ids'] as List?) ?? const []).cast<String>(), label: label);
        return null;
      case 'setComponentProperty':
        level.setComponentProperty(
          _str(args, 'actorId'),
          (args['componentType'] ?? args['componentId']) as String? ?? (throw _badArgs('"componentType" is missing')),
          _str(args, 'name'),
          args['value'],
          label: label,
        );
        return null;
      case 'selectActors':
        level.selectActors(((args['ids'] as List?) ?? const []).cast<String>());
        return null;
      case 'undoIfTop':
        // Advisory from the process: the host checks its own top label.
        return level.undoIfTop(_str(args, 'label'));
      case 'saveLevel':
        await level.saveLevel();
        return true;
      case 'openLevel':
        return level.openLevel(_str(args, 'path'), show: args['show'] != false);
      case 'openAssetEditor':
        level.openAssetEditor(_str(args, 'path'));
        return true;
      case 'log':
        level.log(args['message'] as String? ?? '', level: args['level'] as String? ?? 'info', source: pluginName);
        return null;
    }
    throw _badArgs('unknown level op $op');
  }

  void _endTransactions(_Run run) {
    for (final tx in run.transactions) {
      if (!tx.end.isCompleted) tx.end.complete();
    }
    run.transactions.clear();
  }

  /// Settings and level changes go to the running process as
  /// notifications (`core.settings`, `core.levelChanged`, debounced).
  void _watchEditor(_Run run) {
    final settings = host.settingsFor(pluginName);
    void onSettings() => run.connection?.notify(PluginMethods.settings, {'settings': settings.value});
    settings.addListener(onSettings);
    final level = host.levelAccess;
    void onLevel() {
      run.levelDebounce?.cancel();
      run.levelDebounce = Timer(timings.levelChangeDebounce, () {
        if (run.exited) return;
        run.connection?.notify(PluginMethods.levelChanged, {
          'activeLevelPath': level!.activeLevelPath,
          'actorCount': level.actors.length,
        });
      });
    }

    level?.changes.addListener(onLevel);
    run.unwatch = () {
      settings.removeListener(onSettings);
      level?.changes.removeListener(onLevel);
    };
  }
}

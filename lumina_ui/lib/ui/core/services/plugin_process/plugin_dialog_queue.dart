import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart';

/// One dialog a plugin process opened (`host.showDialog`), shown or
/// waiting.
class PendingPluginDialog {
  PendingPluginDialog._(this.plugin, this.spec, this.serial) : values = _initialValues(spec.body);

  final String plugin;
  final PluginDialogSpec spec;

  /// Increases with every request; keys the widget so a new dialog never
  /// reuses the previous one's fields.
  final int serial;

  /// The body controls' current values by control id: their `value` props
  /// first, then what the user changed.
  final Map<String, Object?> values;

  final Completer<PluginDialogResult> _done = Completer();

  bool get isClosed => _done.isCompleted;

  static Map<String, Object?> _initialValues(List<PluginControl> controls) {
    final out = <String, Object?>{};
    void walk(List<PluginControl> list) {
      for (final c in list) {
        if (c.kind != PluginControlKind.text && c.props.containsKey('value')) out[c.id] = c['value'];
        walk(c.children);
      }
    }

    walk(controls);
    return out;
  }
}

/// The modal dialogs plugin processes opened, in request order: the editor
/// shows [current] (`PluginDialogLayer`), one at a time, so a plugin never
/// has two open and a second request waits. Answering never blocks the UI
/// isolate: [request] completes when the user (or [close], or the plugin's
/// process stopping) closes the dialog.
class PluginDialogQueue extends ChangeNotifier {
  /// The editor's queue (the one its window shows).
  static final PluginDialogQueue shared = PluginDialogQueue();

  final List<PendingPluginDialog> _queue = [];
  int _serial = 0;

  /// The dialog on screen, or null.
  PendingPluginDialog? get current => _queue.isEmpty ? null : _queue.first;

  /// Every open or waiting dialog, the shown one first.
  List<PendingPluginDialog> get pending => List.unmodifiable(_queue);

  /// Whether [plugin] has a dialog open or waiting (its request timeouts
  /// pause meanwhile: the user decides how long it takes).
  bool hasDialog(String plugin) => _queue.any((d) => d.plugin == plugin);

  /// Shows [spec] for [plugin] once the dialogs before it closed;
  /// completes with the user's answer.
  Future<PluginDialogResult> request(String plugin, PluginDialogSpec spec) {
    final d = PendingPluginDialog._(plugin, spec, ++_serial);
    _queue.add(d);
    notifyListeners();
    return d._done.future;
  }

  /// The user changed control [controlId] of [dialog] to [value].
  void setValue(PendingPluginDialog dialog, String controlId, Object? value) => dialog.values[controlId] = value;

  /// Closes [dialog] with [action] (null: dismissed) and its values.
  void answer(PendingPluginDialog dialog, String? action) {
    if (!_queue.remove(dialog)) return;
    dialog._done.complete(
      action == null ? PluginDialogResult.dismissed : PluginDialogResult(action: action, values: Map.of(dialog.values)),
    );
    notifyListeners();
  }

  /// Closes [plugin]'s dialog [dialogId] (open or waiting), answered
  /// dismissed. False when there is none.
  bool close(String plugin, String dialogId) {
    final d = _queue.where((d) => d.plugin == plugin && d.spec.id == dialogId).firstOrNull;
    if (d == null) return false;
    answer(d, null);
    return true;
  }

  /// Closes every dialog of [plugin] (its process stopped or crashed).
  void closeAllOf(String plugin) {
    for (final d in _queue.where((d) => d.plugin == plugin).toList()) {
      answer(d, null);
    }
  }
}

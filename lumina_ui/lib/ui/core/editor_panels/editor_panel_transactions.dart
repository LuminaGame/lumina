import 'dart:async';

import 'package:lumina_ui/ui/core/editor_panels/editor_panel_host.dart';
import 'package:lumina_ui/ui/core/editor_panels/editor_panel_runtime.dart';
import 'package:lumina_ui/ui/features/main_editor/commands/editor_transaction.dart';

/// One transaction an editor panel's graph opened (`Begin Transaction`):
/// every level or asset edit the panel makes until `End Transaction` runs in
/// its [zone], so they are one Edit ▸ Undo step named [label].
class EditorPanelTransaction {
  EditorPanelTransaction(this.id, this.label);

  final int id;
  final String label;
  final Completer<void> end = Completer<void>();
  late final Zone zone;
  bool edited = false;
}

/// The panels' open transactions, one at most per instance.
class EditorPanelTransactions {
  EditorPanelTransactions(this.host);

  final EditorPanelHost host;
  final Map<EditorPanelInstance, EditorPanelTransaction> _open = {};
  int _next = 0;

  EditorPanelTransaction? openOf(EditorPanelInstance instance) => _open[instance];

  /// Begins [label] for [instance] (ending one it left open first). Returns
  /// the transaction id the graph passes to End / Cancel.
  int begin(EditorPanelInstance instance, String label) {
    final previous = _open[instance];
    if (previous != null) end(instance, previous.id);
    final tx = EditorPanelTransaction(++_next, label.trim().isEmpty ? 'Editor Panel Edit' : label.trim());
    _open[instance] = tx;
    unawaited(TransactionManager.runGrouped(tx.label, () {
      tx.zone = Zone.current;
      return tx.end.future;
    }));
    return tx.id;
  }

  /// Ends transaction [id] of [instance]; false when it is not the open one.
  bool end(EditorPanelInstance instance, int id) {
    final tx = _open[instance];
    if (tx == null || tx.id != id) return false;
    _open.remove(instance);
    if (!tx.end.isCompleted) tx.end.complete();
    return true;
  }

  /// Ends and undoes transaction [id]: its edits are reverted and leave no
  /// undo step.
  bool cancel(EditorPanelInstance instance, int id) {
    final tx = _open[instance];
    if (tx == null || tx.id != id) return false;
    end(instance, id);
    if (tx.edited) {
      final manager = host.vm.transactions;
      if (manager.canUndo && manager.undoLabel == 'Undo ${tx.label}') manager.undo();
    }
    return true;
  }

  /// Runs an edit of [instance]: inside its open transaction's zone (one undo
  /// step with the others), else on its own (its own step).
  T edit<T>(EditorPanelInstance instance, T Function() body) {
    final tx = _open[instance];
    if (tx == null) return body();
    tx.edited = true;
    return tx.zone.run(body);
  }

  /// A transaction the event left open is ended, with a warning.
  void endLeftOpen(EditorPanelInstance instance) {
    final tx = _open[instance];
    if (tx == null) return;
    end(instance, tx.id);
    host.vm.logger.log(
      "Editor panel ${instance.runtime.title}: transaction '${tx.label}' was left open when the event finished; "
      'the editor ended it (call End Transaction).',
      level: 'warning',
      source: 'Editor Panels',
    );
  }
}

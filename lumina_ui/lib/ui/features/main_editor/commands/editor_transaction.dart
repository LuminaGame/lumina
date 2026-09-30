import 'dart:async';

import 'package:flutter/widgets.dart';

/// Who made an undo step: the user, or an MCP agent call.
class TransactionOrigin {
  /// `user` or `mcp`.
  final String kind;
  final String? sessionId;
  final String? clientName;
  final String? tool;

  /// The caller the call was made for: an in-process caller, or the one an
  /// external client's tagged session is bound to.
  final String? caller;

  const TransactionOrigin.user()
      : kind = 'user',
        sessionId = null,
        clientName = null,
        tool = null,
        caller = null;

  const TransactionOrigin.mcp({required String this.sessionId, required String this.clientName, required String this.tool, this.caller})
      : kind = 'mcp';

  bool get isAgent => kind == 'mcp';

  Map<String, Object?> toJson() => {
        'kind': kind,
        'session_id': ?sessionId,
        'client': ?clientName,
        'tool': ?tool,
        'caller': ?caller,
      };

  @override
  String toString() => isAgent ? '$clientName: $tool' : 'user';
}

/// Thrown by a step's undo or redo that cannot apply any more (the state it
/// would restore was changed since); the step stays where it was.
class TransactionRefused implements Exception {
  final String message;
  const TransactionRefused(this.message);

  @override
  String toString() => message;
}

class EditorTransaction {
  final String label;
  final String? coalesceKey;
  final void Function() undo;
  final void Function() redo;
  final TransactionOrigin origin;

  const EditorTransaction({
    required this.label,
    this.coalesceKey,
    required this.undo,
    required this.redo,
    this.origin = const TransactionOrigin.user(),
  });
}

/// Every record one agent call made on one stack, as one undo step: undone
/// in reverse, redone in order, labelled `MCP: <first> (+n)`.
class _CompositeTransaction extends EditorTransaction {
  final List<EditorTransaction> parts;

  /// A plugin's `runTransaction` label; null for an agent call.
  final String? groupLabel;

  _CompositeTransaction(EditorTransaction first, TransactionOrigin origin, {this.groupLabel})
      : parts = [first],
        super(label: '', undo: _noop, redo: _noop, origin: origin);

  static void _noop() {}

  @override
  String get label => groupLabel ?? 'MCP: ${parts.first.label}${parts.length > 1 ? ' (+${parts.length - 1})' : ''}';

  @override
  void Function() get undo => () {
        for (final p in parts.reversed) {
          p.undo();
        }
      };

  @override
  void Function() get redo => () {
        for (final p in parts) {
          p.redo();
        }
      };
}

/// The zone value of an attributed call: its origin and the composite it
/// opened on each stack.
class _AttributionScope {
  final TransactionOrigin origin;
  final Map<TransactionManager, _CompositeTransaction> composites = {};
  _AttributionScope(this.origin);
}

/// The zone value of [TransactionManager.runGrouped].
class _GroupScope {
  final String label;
  final Map<TransactionManager, _CompositeTransaction> composites = {};
  _GroupScope(this.label);
}

class TransactionManager extends ChangeNotifier {
  final List<EditorTransaction> _undoStack = [];
  final List<EditorTransaction> _redoStack = [];
  final int maxDepth = 200;

  bool _isApplying = false;
  bool isFrozen = false;
  bool get isApplying => _isApplying;

  EditorTransaction? _openTransaction;
  void Function()? _openUndo;

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  String get undoLabel => canUndo ? 'Undo ${_undoStack.last.label}' : 'Undo';
  String get redoLabel => canRedo ? 'Redo ${_redoStack.last.label}' : 'Redo';

  /// Who made the step Undo / Redo would revert or re-apply.
  TransactionOrigin? get undoTopOrigin => canUndo ? _undoStack.last.origin : null;
  TransactionOrigin? get redoTopOrigin => canRedo ? _redoStack.last.origin : null;

  /// The undo stack, newest first: label and origin of each step.
  List<({String label, TransactionOrigin origin})> history({int limit = 20}) => [
        for (final t in _undoStack.reversed.take(limit)) (label: t.label, origin: t.origin),
      ];

  static final Object _zoneKey = Object();

  /// The origin of the attributed call the current code runs in, if any.
  static TransactionOrigin? get currentOrigin => (Zone.current[_zoneKey] as _AttributionScope?)?.origin;

  /// Runs [body] as one attributed call: every record it
  /// makes — on **any** manager (the level's, a Blueprint or Material tab's)
  /// — goes into one composite step per manager, labelled `MCP: …` and
  /// carrying [origin].
  ///
  /// The mark is a [Zone] value, so it travels only with [body]'s own async
  /// continuations: a user edit made while the call awaits (a slow import)
  /// runs in the root zone and stays an ordinary user step. A composite is
  /// pushed at its first record; when a user edit lands between two parts of
  /// one agent call, undo reverts the user's edit first, then the whole
  /// agent step — faithful unless both touched the same property.
  static Future<T> runAttributed<T>(TransactionOrigin origin, Future<T> Function() body) {
    final scope = _AttributionScope(origin);
    return runZoned(body, zoneValues: {_zoneKey: scope});
  }

  void beginTransaction(String label, {String? coalesceKey}) {
    assert(_openTransaction == null, 'A transaction is already open');
    _openTransaction = EditorTransaction(
      label: label,
      coalesceKey: coalesceKey,
      undo: () {},
      redo: () {},
    );
    _openUndo = null;
  }

  void endTransaction() {
    if (_openTransaction != null && _openUndo != null) {
      _pushTransaction(_openTransaction!);
    }
    _openTransaction = null;
    _openUndo = null;
  }

  void record(EditorTransaction transaction) {
    if (_isApplying) return;

    if (_openTransaction != null) {
      // Coalescing logic
      if (_openTransaction!.coalesceKey != null &&
          _openTransaction!.coalesceKey == transaction.coalesceKey) {
        _openUndo ??= transaction.undo; // Keep the first undo
        _openTransaction = EditorTransaction(
          label: _openTransaction!.label,
          coalesceKey: _openTransaction!.coalesceKey,
          undo: _openUndo!,
          redo: transaction.redo,
        );
        return;
      }
    }
    _pushTransaction(transaction);
  }

  static final Object _groupKey = Object();

  /// Runs [body] so that every record it makes — on any manager —
  /// is one step per manager labelled [label] (a plugin's
  /// `EditorLevelAccess.runTransaction`). Zone-based like [runAttributed]:
  /// only [body]'s own async continuations are grouped. Inside an attributed
  /// agent call the call's grouping applies; a group inside a group joins
  /// the outer one; an attributed call inside a group (MiniAI's turn calling
  /// MCP tools in process) joins the group, so the turn is one step.
  static Future<T> runGrouped<T>(String label, Future<T> Function() body) {
    if (Zone.current[_groupKey] != null || Zone.current[_zoneKey] != null) return body();
    return runZoned(body, zoneValues: {_groupKey: _GroupScope(label)});
  }

  void _pushTransaction(EditorTransaction transaction) {
    final group = Zone.current[_groupKey] as _GroupScope?;
    if (group != null) {
      final open = group.composites[this];
      if (open != null && _undoStack.contains(open)) {
        open.parts.add(transaction);
        _redoStack.clear();
        notifyListeners();
        return;
      }
      // An attributed call inside the group lends the step its origin.
      final attributed = Zone.current[_zoneKey] as _AttributionScope?;
      final composite = _CompositeTransaction(transaction, attributed?.origin ?? const TransactionOrigin.user(), groupLabel: group.label);
      group.composites[this] = composite;
      transaction = composite;
    }
    final scope = group == null ? Zone.current[_zoneKey] as _AttributionScope? : null;
    if (scope != null) {
      final open = scope.composites[this];
      if (open != null && _undoStack.contains(open)) {
        open.parts.add(transaction);
        _redoStack.clear();
        notifyListeners();
        return;
      }
      final composite = _CompositeTransaction(transaction, scope.origin);
      scope.composites[this] = composite;
      transaction = composite;
    }
    _undoStack.add(transaction);
    if (_undoStack.length > maxDepth) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
    notifyListeners();
  }

  void undo() {
    if (isFrozen) return;
    if (!canUndo || _isApplying) return;
    _isApplying = true;
    try {
      final tx = _undoStack.removeLast();
      try {
        tx.undo();
      } on TransactionRefused {
        _undoStack.add(tx);
        rethrow;
      }
      _redoStack.add(tx);
      notifyListeners();
    } finally {
      _isApplying = false;
    }
  }

  void redo() {
    if (isFrozen) return;
    if (!canRedo || _isApplying) return;
    _isApplying = true;
    try {
      final tx = _redoStack.removeLast();
      try {
        tx.redo();
      } on TransactionRefused {
        _redoStack.add(tx);
        rethrow;
      }
      _undoStack.add(tx);
      notifyListeners();
    } finally {
      _isApplying = false;
    }
  }

  void clear() {
    _undoStack.clear();
    _redoStack.clear();
    _openTransaction = null;
    _openUndo = null;
    notifyListeners();
  }
}

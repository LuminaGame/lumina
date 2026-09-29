import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:lumina/lumina.dart';

/// What the import progress panel shows: the batch the
/// editor's [ImportQueue] is running — every file's latest state, counts,
/// elapsed and remaining time — and whether the panel is open, collapsed to
/// its status-bar chip or dismissed.
///
/// Listens to the queue only; the Content Browser learns about new assets
/// through [onAssetsLanded], once per written file, never by a rescan.
class ImportJobsViewModel extends ChangeNotifier {
  ImportJobsViewModel(this.queue, {this.onAssetsLanded, this.onBatchFinished}) {
    _progressSub = queue.progress.listen(_onProgress);
    _summarySub = queue.summaries.listen(_onSummary);
  }

  final ImportQueue queue;

  /// A file was written and indexed: its assets, for the Content Browser.
  final void Function(List<RealAssetInfo> assets)? onAssetsLanded;

  /// The batch ended.
  final void Function(ImportBatchSummary summary)? onBatchFinished;

  /// How long a batch that imported everything stays on screen.
  static const Duration autoDismissAfter = Duration(seconds: 5);

  late final StreamSubscription<ImportProgress> _progressSub;
  late final StreamSubscription<ImportBatchSummary> _summarySub;
  final Set<int> _landed = {};
  int _batch = 0;
  ImportBatchSummary? _summary;
  bool _visible = false;
  bool _collapsed = false;
  bool _showDetails = false;
  Timer? _dismissTimer;
  bool _disposed = false;

  /// Every file of the batch, in queue order (read from the queue, which
  /// is always current; the events only say when to redraw).
  List<ImportProgress> get rows => queue.files;

  bool get isRunning => queue.isRunning;
  bool get isCancelling => queue.isCancelling;
  int get total => queue.total;
  int get finished => queue.finished;
  int get imported => queue.imported;
  int get failed => queue.failed;
  int get cancelled => queue.cancelled;

  double get overallFraction => queue.overallFraction;

  /// The file being worked on (the earliest one past `queued`), if any.
  ImportProgress? get current {
    for (final r in rows) {
      if (!r.stage.isTerminal && r.stage != ImportStage.queued) return r;
    }
    for (final r in rows) {
      if (!r.stage.isTerminal) return r;
    }
    return null;
  }

  /// The failed files and why.
  List<ImportProgress> get failures => [for (final r in rows) if (r.stage == ImportStage.failed) r];

  ImportBatchSummary? get summary => _summary;

  Duration get elapsed => queue.elapsed;

  /// Remaining time from the pace so far — per finished file once one is
  /// finished, from the batch fraction before — null until there is a pace.
  Duration? get remaining {
    if (!isRunning) return null;
    final done = finished;
    if (done > 0) return elapsed * ((total - done) / done);
    final f = overallFraction;
    if (f <= 0.02) return null;
    return elapsed * ((1 - f) / f);
  }

  /// `Importing 12 / 51 · SM_AmmoBoxMetal.glb` while running, the outcome
  /// afterwards.
  String get headline {
    if (isRunning) {
      final n = (finished + 1).clamp(1, total);
      final name = current?.fileName;
      return 'Importing $n / $total${name == null ? '' : ' · $name'}';
    }
    final s = _summary;
    if (s == null) return 'Import';
    final parts = <String>['Imported ${s.imported} of ${s.total}'];
    if (s.failed > 0) parts.add('${s.failed} failed');
    if (s.cancelled > 0) parts.add('${s.cancelled} cancelled');
    return parts.join(' · ');
  }

  /// The status-bar chip: `Importing 12/51`.
  String get chipLabel => isRunning ? 'Importing ${(finished + 1).clamp(1, total)}/$total' : headline;

  bool get visible => _visible;
  bool get collapsed => _collapsed;
  bool get showDetails => _showDetails;

  void collapse() => _set(() => _collapsed = true);
  void expand() => _set(() {
        _collapsed = false;
        _visible = true;
      });
  void toggleDetails() => _set(() => _showDetails = !_showDetails);

  /// Hides the panel (the batch keeps running; the chip stays while it does).
  void dismiss() => _set(() {
        _dismissTimer?.cancel();
        if (isRunning) {
          _collapsed = true;
        } else {
          _visible = false;
          _collapsed = false;
        }
      });

  /// Stops after the files in progress (they finish and are kept).
  void cancel() {
    queue.cancel();
    _notify();
  }

  void _onProgress(ImportProgress p) {
    if (p.batch != _batch) {
      _batch = p.batch;
      _landed.clear();
      _summary = null;
      _dismissTimer?.cancel();
      _visible = true;
      _collapsed = false;
    }
    if (p.assets.isNotEmpty && _landed.add(p.index)) onAssetsLanded?.call(p.assets);
    _notify();
  }

  void _onSummary(ImportBatchSummary s) {
    if (s.batch != _batch) return;
    _summary = s;
    onBatchFinished?.call(s);
    _dismissTimer?.cancel();
    if (s.failed == 0 && s.cancelled == 0) {
      _dismissTimer = Timer(autoDismissAfter, () => _set(() {
            _visible = false;
            _collapsed = false;
          }));
    }
    _notify();
  }

  void _set(void Function() change) {
    if (_disposed) return;
    change();
    notifyListeners();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _dismissTimer?.cancel();
    _progressSub.cancel();
    _summarySub.cancel();
    super.dispose();
  }
}

import 'dart:io';

/// This process's peak resident set size since [PeakRss.start], read from
/// Linux's `VmHWM` after resetting it through `/proc/self/clear_refs`.
///
/// [start] returns null where `/proc` is unavailable, so callers skip the
/// memory assertion instead of failing on another platform.
class PeakRss {
  final int baselineKb;
  PeakRss._(this.baselineKb);

  static PeakRss? start() {
    try {
      File('/proc/self/clear_refs').writeAsStringSync('5');
      return PeakRss._(_statusKb('VmRSS'));
    } catch (_) {
      return null;
    }
  }

  /// Megabytes the peak RSS rose above the RSS at [start].
  int grownMb() => (_statusKb('VmHWM') - baselineKb) ~/ 1024;

  static int _statusKb(String field) {
    final line = File('/proc/self/status').readAsLinesSync().firstWhere((l) => l.startsWith('$field:'));
    return int.parse(line.split(RegExp(r'\s+'))[1]);
  }
}

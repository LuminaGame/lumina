import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

/// A JSON file in the editor's config directory ([LuminaConfigDir]) that
/// several writers share: the editor, a second editor window, a test run —
/// each in its own process or isolate.
///
/// * [write] replaces the file atomically: the new content is written and
///   flushed to a temp file in the same directory, which is then renamed over
///   the file. A reader sees the old content or the new one, never a
///   truncated file.
/// * [update] is a read-modify-write under an exclusive lock (`<name>.lock`,
///   created exclusively, so it holds across processes and isolates alike):
///   two writers never overwrite each other's change.
/// * Content that does not parse is never taken for an empty value. [read]
///   tries again for a moment (a writer that still rewrites the file in place
///   may be half-way through), then throws [ConfigFileUnreadableException].
///   [update] moves such a file aside as `<name>.unreadable-<timestamp>`
///   before it writes, so the content is kept.
class ConfigJsonFile {
  ConfigJsonFile(this.file);

  final File file;

  /// How often a read that does not parse is tried, and how far apart.
  static const int readAttempts = 10;
  static const Duration readRetryDelay = Duration(milliseconds: 50);

  /// A lock older than this was left behind by a writer that died.
  static const Duration staleLockAge = Duration(seconds: 10);

  /// How long [update] waits for another writer's lock.
  static const Duration lockTimeout = Duration(seconds: 30);

  static final math.Random _random = math.Random();

  /// The lock [update] holds while it reads, changes and writes the file.
  File get lockFile => File('${file.path}.lock');

  /// The decoded content; null when the file is missing or stays blank.
  Object? read() {
    Object? error;
    for (var attempt = 0; attempt < readAttempts; attempt++) {
      if (attempt > 0) sleep(readRetryDelay);
      if (!file.existsSync()) return null;
      try {
        final content = file.readAsStringSync();
        // Blank is what a writer that truncates first leaves mid-write.
        if (content.trim().isEmpty) {
          error = null;
          continue;
        }
        return jsonDecode(content);
      } on FormatException catch (e) {
        error = e;
      } on FileSystemException catch (e) {
        error = e;
      }
    }
    if (error == null) return null;
    throw ConfigFileUnreadableException(file, error);
  }

  /// Replaces the file with [value], atomically.
  void write(Object? value, {bool pretty = false}) {
    file.parent.createSync(recursive: true);
    final text = pretty ? const JsonEncoder.withIndent('  ').convert(value) : jsonEncode(value);
    final temp = File('${file.path}.tmp-$pid-${_random.nextInt(1 << 32)}');
    try {
      temp.writeAsStringSync(text, flush: true);
      temp.renameSync(file.path);
    } catch (_) {
      try {
        if (temp.existsSync()) temp.deleteSync();
      } on FileSystemException catch (_) {}
      rethrow;
    }
  }

  /// Reads the file, lets [change] turn its content (null when there is none)
  /// into the new content, and writes that — all under [lockFile].
  ///
  /// Content that does not parse, or that [isValid] rejects, is moved aside
  /// first ([onUnreadable] is told where) and [change] gets null.
  Object? update(
    Object? Function(Object? current) change, {
    bool Function(Object value)? isValid,
    bool pretty = false,
    void Function(File keptAside, Object error)? onUnreadable,
  }) {
    return _locked(() {
      Object? current;
      try {
        current = read();
        if (current != null && isValid != null && !isValid(current)) {
          throw ConfigFileUnreadableException(file, FormatException('unexpected content: ${current.runtimeType}'));
        }
      } on ConfigFileUnreadableException catch (e) {
        final keptAside = file.renameSync(
          '${file.path}.unreadable-${DateTime.now().toUtc().toIso8601String().replaceAll(':', '-')}',
        );
        onUnreadable?.call(keptAside, e.cause);
        current = null;
      }
      final next = change(current);
      write(next, pretty: pretty);
      return next;
    });
  }

  T _locked<T>(T Function() body) {
    file.parent.createSync(recursive: true);
    final lock = lockFile;
    final deadline = DateTime.now().add(lockTimeout);
    while (true) {
      try {
        lock.createSync(exclusive: true);
        break;
      } on FileSystemException {
        // Another writer holds it. One that died leaves it behind: a lock
        // older than [staleLockAge] is broken.
        try {
          if (DateTime.now().difference(lock.lastModifiedSync()) > staleLockAge) {
            lock.deleteSync();
            continue;
          }
        } on FileSystemException {
          continue; // released in the meantime
        }
        if (DateTime.now().isAfter(deadline)) {
          throw FileSystemException('Timed out waiting for another writer', lock.path);
        }
        sleep(const Duration(milliseconds: 2));
      }
    }
    try {
      return body();
    } finally {
      try {
        lock.deleteSync();
      } on FileSystemException catch (_) {}
    }
  }
}

/// A config file whose content does not parse as the JSON it should hold,
/// even after [ConfigJsonFile.read] tried again.
class ConfigFileUnreadableException implements Exception {
  ConfigFileUnreadableException(this.file, this.cause);

  final File file;
  final Object cause;

  @override
  String toString() => 'ConfigFileUnreadableException: ${file.path} is not readable JSON ($cause)';
}

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// A complete cached project editor build.
class EditorBuildEntry {
  final String hash;
  final Directory dir;

  /// The stamp written at install: `{hash, inputs, engineRevision,
  /// flutterVersion, platform, mode, builtAt, executable}`.
  final Map<String, dynamic> stamp;

  const EditorBuildEntry(this.hash, this.dir, this.stamp);

  Directory get bundle => Directory(p.join(dir.path, 'bundle'));

  /// The editor executable inside [bundle] (`stamp.executable` is relative).
  String get executable => p.join(bundle.path, (stamp['executable'] as String?) ?? '');
}

/// The machine-wide, content-addressed cache of compiled project editors:
/// `<root>/<hash>/{bundle/, stamp.json, complete}`. Projects with
/// the same plugin set on the same engine share one entry.
///
/// Crash-safe: an install copies into `<hash>.tmp/` and renames, and only an
/// entry with its `complete` marker is ever returned. Two launchers building
/// the same hash serialize on `<hash>.lock` ([RandomAccessFile.lock]).
class EditorBuildCache {
  final Directory root;

  /// flutter_filament's native library cache, swept alongside by [evict].
  final Directory nativeRoot;

  EditorBuildCache({Directory? root, Directory? nativeRoot})
      : root = root ?? defaultRoot(),
        nativeRoot = nativeRoot ?? Directory(p.join(cacheBase(), 'native'));

  /// `%LOCALAPPDATA%\lumina` on Windows, `~/Library/Caches/lumina` on macOS,
  /// else `$XDG_CACHE_HOME/lumina` or `~/.cache/lumina`.
  static String cacheBase({Map<String, String>? environment, String? operatingSystem}) {
    final env = environment ?? Platform.environment;
    final os = operatingSystem ?? Platform.operatingSystem;
    if (os == 'windows') {
      final base = env['LOCALAPPDATA'] ?? p.join(env['USERPROFILE'] ?? '.', 'AppData', 'Local');
      return p.join(base, 'lumina');
    }
    final xdg = env['XDG_CACHE_HOME'];
    if (os != 'macos' && xdg != null && xdg.isNotEmpty) return p.join(xdg, 'lumina');
    final home = env['HOME'] ?? '.';
    return os == 'macos' ? p.join(home, 'Library', 'Caches', 'lumina') : p.join(home, '.cache', 'lumina');
  }

  static Directory defaultRoot({Map<String, String>? environment, String? operatingSystem}) =>
      Directory(p.join(cacheBase(environment: environment, operatingSystem: operatingSystem), 'editor-builds'));

  Directory _entryDir(String hash) => Directory(p.join(root.path, hash));
  Directory _tmpDir(String hash) => Directory(p.join(root.path, '$hash.tmp'));
  File lockFile(String hash) => File(p.join(root.path, '$hash.lock'));
  File logFile(String hash) => File(p.join(root.path, '$hash.log'));

  EditorBuildEntry? lookup(String hash) {
    final dir = _entryDir(hash);
    final stampFile = File(p.join(dir.path, 'stamp.json'));
    if (!File(p.join(dir.path, 'complete')).existsSync() ||
        !Directory(p.join(dir.path, 'bundle')).existsSync() ||
        !stampFile.existsSync()) {
      return null;
    }
    try {
      return EditorBuildEntry(hash, dir, jsonDecode(stampFile.readAsStringSync()) as Map<String, dynamic>);
    } on FormatException {
      return null;
    }
  }

  /// Every complete entry's hash.
  List<String> hashes() {
    if (!root.existsSync()) return const [];
    return [
      for (final d in root.listSync().whereType<Directory>())
        if (!d.path.endsWith('.tmp') && lookup(p.basename(d.path)) != null) p.basename(d.path),
    ]..sort();
  }

  /// Copies [builtBundle] into `<hash>.tmp/` with [stamp], marks it complete
  /// and renames it into place. A leftover `<hash>.tmp/` from a crashed
  /// install is removed first. The caller holds `<hash>.lock` ([obtain] does).
  Future<EditorBuildEntry> install(String hash, Directory builtBundle, {Map<String, dynamic> stamp = const {}}) async {
    final existing = lookup(hash);
    if (existing != null) return existing;
    await root.create(recursive: true);
    final tmp = _tmpDir(hash);
    if (tmp.existsSync()) await tmp.delete(recursive: true);
    await _copyDir(builtBundle, Directory(p.join(tmp.path, 'bundle')));
    await File(p.join(tmp.path, 'stamp.json')).writeAsString(const JsonEncoder.withIndent('  ').convert({'hash': hash, ...stamp}), flush: true);
    await File(p.join(tmp.path, 'last_used')).writeAsString(DateTime.now().toUtc().toIso8601String());
    await File(p.join(tmp.path, 'complete')).writeAsString('complete\n', flush: true);
    final dir = _entryDir(hash);
    if (dir.existsSync()) await dir.delete(recursive: true);
    await tmp.rename(dir.path);
    return lookup(hash)!;
  }

  /// Marks [hash] used now (eviction keeps recently used entries).
  Future<void> touch(String hash) async {
    final f = File(p.join(_entryDir(hash).path, 'last_used'));
    if (!f.parent.existsSync()) return;
    await f.writeAsString(DateTime.now().toUtc().toIso8601String());
    await f.setLastModified(DateTime.now());
  }

  DateTime _lastUsed(String hash) {
    final f = File(p.join(_entryDir(hash).path, 'last_used'));
    return f.existsSync() ? f.lastModifiedSync() : _entryDir(hash).statSync().modified;
  }

  /// Locks `<hash>.lock` exclusively (waiting for another holder), runs
  /// [body], then releases it.
  Future<T> withLock<T>(String hash, Future<T> Function() body) async {
    await root.create(recursive: true);
    final raf = await lockFile(hash).open(mode: FileMode.append);
    try {
      await raf.lock(FileLock.blockingExclusive);
      _heldHere.add(lockFile(hash).absolute.path);
      try {
        return await body();
      } finally {
        _heldHere.remove(lockFile(hash).absolute.path);
        await raf.unlock();
      }
    } finally {
      await raf.close();
    }
  }

  /// The entry for [hash], building it with [build] only when it is not
  /// cached. Two callers for one hash serialize on its lock: the second finds
  /// the first one's entry and does not build.
  Future<EditorBuildEntry> obtain(String hash, Future<({Directory bundle, Map<String, dynamic> stamp})> Function() build) =>
      withLock(hash, () async {
        final hit = lookup(hash);
        if (hit != null) return hit;
        final built = await build();
        return install(hash, built.bundle, stamp: built.stamp);
      });

  /// Lock files held by this isolate. POSIX record locks are per process, so
  /// a same-process probe would succeed on a held lock; this closes that gap.
  static final Set<String> _heldHere = {};

  bool _isLocked(String hash) {
    final f = lockFile(hash);
    if (_heldHere.contains(f.absolute.path)) return true;
    if (!f.existsSync()) return false;
    RandomAccessFile? raf;
    try {
      raf = f.openSync(mode: FileMode.append);
      raf.lockSync(FileLock.exclusive);
      raf.unlockSync();
      return false;
    } on FileSystemException {
      return true;
    } finally {
      raf?.closeSync();
    }
  }

  /// Bytes freed by the last [evict].
  int lastEvictedBytes = 0;

  /// Removes entries beyond the [keep] most recently used that were unused
  /// for [unusedFor], never one whose lock is held, plus any crashed
  /// `*.tmp` install. Also sweeps the native library cache the same way per
  /// package. Returns what was removed (`<hash>`, `native/<pkg>/<key>`).
  Future<List<String>> evict({int keep = 5, Duration unusedFor = const Duration(days: 30)}) async {
    final removed = <String>[];
    var bytes = 0;
    final now = DateTime.now();
    if (root.existsSync()) {
      for (final d in root.listSync().whereType<Directory>()) {
        final name = p.basename(d.path);
        if (name.endsWith('.tmp') && !_isLocked(name.substring(0, name.length - 4))) {
          bytes += _size(d);
          await d.delete(recursive: true);
          removed.add(name);
        }
      }
      final all = hashes()..sort((a, b) => _lastUsed(b).compareTo(_lastUsed(a)));
      for (final hash in all.skip(keep)) {
        if (now.difference(_lastUsed(hash)) < unusedFor) continue;
        if (_isLocked(hash)) continue;
        bytes += _size(_entryDir(hash));
        await _entryDir(hash).delete(recursive: true);
        for (final f in [logFile(hash), lockFile(hash)]) {
          if (f.existsSync()) {
            try {
              bytes += f.lengthSync();
              f.deleteSync();
            } on FileSystemException {
              // A lock file another process just opened: harmless to keep.
            }
          }
        }
        removed.add(hash);
      }
    }
    if (nativeRoot.existsSync()) {
      for (final pkg in nativeRoot.listSync().whereType<Directory>()) {
        final entries = pkg.listSync().whereType<Directory>().toList();
        for (final tmp in entries.where((e) => p.basename(e.path).contains('.tmp-'))) {
          if (now.difference(tmp.statSync().modified) < const Duration(hours: 1)) continue; // may be publishing
          bytes += _size(tmp);
          await tmp.delete(recursive: true);
          removed.add('native/${p.basename(pkg.path)}/${p.basename(tmp.path)}');
        }
        final complete = entries.where((e) => File(p.join(e.path, 'complete')).existsSync()).toList()
          ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
        for (final e in complete.skip(keep)) {
          if (now.difference(e.statSync().modified) < unusedFor) continue;
          bytes += _size(e);
          await e.delete(recursive: true);
          removed.add('native/${p.basename(pkg.path)}/${p.basename(e.path)}');
        }
      }
    }
    lastEvictedBytes = bytes;
    return removed;
  }

  static int _size(FileSystemEntity e) {
    if (e is File) return e.lengthSync();
    if (e is! Directory || !e.existsSync()) return 0;
    var total = 0;
    for (final f in e.listSync(recursive: true).whereType<File>()) {
      total += f.lengthSync();
    }
    return total;
  }

  /// Total size of every entry (for the preferences' cache line).
  int totalBytes() => root.existsSync() ? _size(root) : 0;

  static Future<void> _copyDir(Directory from, Directory to) async {
    await to.create(recursive: true);
    await for (final e in from.list(recursive: false, followLinks: false)) {
      final target = p.join(to.path, p.basename(e.path));
      if (e is Directory) {
        await _copyDir(e, Directory(target));
      } else if (e is File) {
        await e.copy(target);
      } else if (e is Link) {
        await Link(target).create(await e.target());
      }
    }
  }
}

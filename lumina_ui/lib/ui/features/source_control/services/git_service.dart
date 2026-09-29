import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:lumina/lumina.dart';

/// Injectable process seam: production spawns the real `git` binary, tests
/// either record argv while delegating to real git, or throw
/// [ProcessException] to simulate a host without git.
typedef GitProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
});

/// Working-tree state of one path, derived from `git status --porcelain=v2`.
enum GitFileState { modified, added, untracked, deleted, renamed, conflicted }

extension GitFileStateBadge on GitFileState {
  /// Single-letter badge label used on Content Browser tiles.
  String get badgeLabel => switch (this) {
        GitFileState.modified => 'M',
        GitFileState.added => 'A',
        GitFileState.untracked => '?',
        GitFileState.deleted => 'D',
        GitFileState.renamed => 'R',
        GitFileState.conflicted => 'C',
      };

  String get description => switch (this) {
        GitFileState.modified => 'Modified',
        GitFileState.added => 'Added',
        GitFileState.untracked => 'Untracked',
        GitFileState.deleted => 'Deleted',
        GitFileState.renamed => 'Renamed',
        GitFileState.conflicted => 'Conflict',
      };
}

/// One entry of `git status`, with paths relative to the project root.
class GitFileStatus {
  final String path;
  final String? origPath;
  final GitFileState state;

  const GitFileStatus({required this.path, required this.state, this.origPath});

  @override
  String toString() => 'GitFileStatus(${state.name} $path${origPath != null ? ' <- $origPath' : ''})';
}

/// `git diff --numstat` result for one path.
class GitDiffSummary {
  final String path;
  final bool isBinary;
  final int added;
  final int removed;
  final int? oldSize;
  final int? newSize;

  /// An untracked file (its size is read with `stat`, not
  /// `git diff --no-index`).
  final bool isNew;

  const GitDiffSummary({
    required this.path,
    required this.isBinary,
    this.added = 0,
    this.removed = 0,
    this.oldSize,
    this.newSize,
    this.isNew = false,
  });

  static String formatBytes(int? bytes) {
    if (bytes == null) return '—';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// `+12 −4` for text, `binary · 1.2 KB → 1.3 KB` for binary files,
  /// `new file · 1.2 KB` for an untracked one.
  String get label => isNew
      ? 'new file · ${formatBytes(newSize)}'
      : isBinary
          ? 'binary · ${formatBytes(oldSize)} → ${formatBytes(newSize)}'
          : '+$added −$removed';
}

/// One row of `git log --follow` for a path.
class GitLogEntry {
  final String hash;
  final String author;
  final DateTime date;
  final String subject;

  const GitLogEntry({required this.hash, required this.author, required this.date, required this.subject});

  String get abbrevHash => hash.length > 7 ? hash.substring(0, 7) : hash;
}

/// A git invocation that exited non-zero.
class GitException implements Exception {
  final String command;
  final int exitCode;
  final String stderr;

  const GitException({required this.command, required this.exitCode, required this.stderr});

  /// True when git refused because `user.name`/`user.email` are unset.
  bool get isIdentityError {
    final s = stderr.toLowerCase();
    return s.contains('author identity unknown') ||
        s.contains('please tell me who you are') ||
        s.contains('empty ident name') ||
        s.contains('unable to auto-detect email address');
  }

  @override
  String toString() => 'GitException: `$command` exited with $exitCode: ${stderr.trim()}';
}

/// Thin, porcelain-only wrapper over the real `git` CLI.
///
/// Every call goes through [Process.run] (or the injected [GitProcessRunner])
/// with `workingDirectory` = [projectRoot]; machine-readable flags only
/// (`--porcelain=v2 -z`, `--numstat -z`, `--format` with unit separators) so
/// parsing never depends on locale or git's human output.
class GitService {
  final String projectRoot;
  final GitProcessRunner _runner;
  final EngineLoggerService _logger;

  /// Extra leading args, e.g. `['-c', 'user.name=…']` — tests use it to pin
  /// an identity; production leaves it empty.
  final List<String> configOverrides;

  bool? _availableCache;
  String? _prefixCache;

  /// Echo every git command into the Output Log (debugging aid; off by
  /// default, on with `LUMINA_GIT_VERBOSE=1`).
  static bool verboseLogging = Platform.environment['LUMINA_GIT_VERBOSE'] == '1';

  /// git processes this service has run (tests count them).
  int invocationCount = 0;

  /// Path lists longer than this go to git through `--pathspec-from-file`
  /// instead of the command line.
  static const int pathspecFileThreshold = 100;

  GitService({
    required this.projectRoot,
    GitProcessRunner? runner,
    this.configOverrides = const [],
    EngineLoggerService? logger,
  })  : _runner = runner ?? _defaultRunner,
        _logger = logger ?? EngineLoggerService();

  /// Exit code of the synthetic [ProcessResult] the default runner returns
  /// when git could not be spawned at all (ENOENT etc.).
  static const int spawnFailedExitCode = -0xE0F;

  /// Spawns in the root zone and never lets an error cross zones:
  /// `Process.run` registers a zero-duration timer while starting, and inside
  /// a FakeAsync zone (widget tests that build the editor) that fake timer
  /// would outlive the test, while an error raised in the root zone and
  /// awaited from the fake zone is reported as unhandled. Spawn failures are
  /// therefore returned as a [spawnFailedExitCode] result and re-raised as a
  /// [ProcessException] by [_run] in the caller's zone.
  static Future<ProcessResult> _defaultRunner(String executable, List<String> arguments, {String? workingDirectory}) =>
      Zone.root.run(() async {
        try {
          return await Process.run(executable, arguments, workingDirectory: workingDirectory);
        } on ProcessException catch (e) {
          return ProcessResult(-1, spawnFailedExitCode, '', e.message);
        }
      });

  /// `.gitignore` written by [init]; stack-appropriate for a Flutter project
  /// driven by Lumina Studio (`saved/` holds movie renders and editor scratch).
  static const String defaultGitignore = '''
# Lumina Studio
saved/
.lumina/
# Thumbnails live inside the .lmas; older builds wrote sidecars
**/.thumbnails/
# Derived data: rebuilt on demand, never committed
DerivedDataCache/

# Flutter / Dart
build/
.dart_tool/
.flutter-plugins
.flutter-plugins-dependencies
.packages
.pub-cache/
.pub/
**/doc/api/

# IDE
*.iml
*.ipr
*.iws
.idea/

# OS
.DS_Store
*.swp
*.log
''';

  /// `.lmas` is protobuf — always binary to git regardless of heuristics.
  static const String defaultGitattributes = '''
*.lmas binary
*.glb binary
*.filamesh binary
*.filamat binary
*.png binary
*.tga binary
''';

  // ---------------------------------------------------------------------------
  // Low-level runner

  /// Runs git and returns the raw result (never throws on non-zero exit).
  /// Throws [ProcessException] only when git itself cannot be spawned.
  Future<ProcessResult> _run(List<String> args) async {
    final full = [...configOverrides, ...args];
    final display = 'git ${args.join(' ')}';
    final isVersionProbe = args.length == 1 && args.single == '--version';
    final rootExists = Directory(projectRoot).existsSync();
    if (!rootExists && !isVersionProbe) {
      // Never run a repository command against a missing (or wrong) cwd.
      _logger.log('$display skipped: project root does not exist ($projectRoot)', level: 'warning', source: 'SourceControl');
      return ProcessResult(-1, 128, '', 'fatal: project root does not exist: $projectRoot');
    }
    try {
      final result = await _runner('git', full, workingDirectory: rootExists ? projectRoot : null);
      if (result.pid == -1 && result.exitCode == spawnFailedExitCode) {
        throw ProcessException('git', full, (result.stderr as String?) ?? 'could not start git', result.exitCode);
      }
      invocationCount++;
      // One Output Log line per operation (the callers'),
      // not one per git process; the per-command echo is debug output.
      if (verboseLogging) {
        final level = result.exitCode == 0 ? 'info' : 'warning';
        _logger.log('$display → exit ${result.exitCode}', level: level, source: 'SourceControl');
      }
      return result;
    } on ProcessException catch (e) {
      _availableCache = false;
      _logger.log('$display could not start: ${e.message}', level: 'error', source: 'SourceControl');
      rethrow;
    }
  }

  /// Runs git and throws [GitException] on non-zero exit.
  Future<ProcessResult> _runOrThrow(List<String> args) async {
    final result = await _run(args);
    if (result.exitCode != 0) {
      final err = (result.stderr as String?)?.trim() ?? '';
      final out = (result.stdout as String?)?.trim() ?? '';
      throw GitException(
        command: 'git ${args.join(' ')}',
        exitCode: result.exitCode,
        stderr: err.isNotEmpty ? err : out,
      );
    }
    return result;
  }

  String _stdout(ProcessResult r) => (r.stdout as String?) ?? '';

  // ---------------------------------------------------------------------------
  // Probes

  /// Probes `git --version` once and caches the answer.
  Future<bool> isGitAvailable() async {
    final cached = _availableCache;
    if (cached != null) return cached;
    try {
      final r = await _run(['--version']);
      _availableCache = r.exitCode == 0;
    } on ProcessException {
      _availableCache = false;
    } catch (_) {
      _availableCache = false;
    }
    return _availableCache!;
  }

  /// True when [projectRoot] is inside a git work tree.
  Future<bool> isRepository() async {
    if (!await isGitAvailable()) return false;
    try {
      final r = await _run(['rev-parse', '--is-inside-work-tree']);
      return r.exitCode == 0 && _stdout(r).trim() == 'true';
    } on ProcessException {
      return false;
    }
  }

  /// True when `.git` lives directly in [projectRoot] (vs. a parent repo).
  bool hasOwnRepository() => Directory('$projectRoot/.git').existsSync() || File('$projectRoot/.git').existsSync();

  /// Path of [projectRoot] relative to the repository top-level ('' at root).
  Future<String> _prefix() async {
    final cached = _prefixCache;
    if (cached != null) return cached;
    final r = await _run(['rev-parse', '--show-prefix']);
    _prefixCache = r.exitCode == 0 ? _stdout(r).trim() : '';
    return _prefixCache!;
  }

  String _stripPrefix(String repoPath, String prefix) =>
      prefix.isNotEmpty && repoPath.startsWith(prefix) ? repoPath.substring(prefix.length) : repoPath;

  // ---------------------------------------------------------------------------
  // Init

  /// `git init` + generated `.gitignore`/`.gitattributes` + `git add -A` +
  /// initial commit. Identity failures surface as [GitException] with
  /// [GitException.isIdentityError] — the repo stays initialised and staged so
  /// [commitAll] can finish once an identity is configured.
  Future<void> init({required String gitignoreContent, String? initialCommitMessage}) async {
    await _runOrThrow(['init', '-q']);
    _prefixCache = null;
    File('$projectRoot/.gitignore').writeAsStringSync(gitignoreContent);
    final attrs = File('$projectRoot/.gitattributes');
    if (!attrs.existsSync()) attrs.writeAsStringSync(defaultGitattributes);
    await _runOrThrow(['add', '-A']);
    if (initialCommitMessage != null) {
      await _runOrThrow(['commit', '-q', '-m', initialCommitMessage]);
    }
  }

  /// Commits everything currently staged (used to finish [init] after an
  /// identity has been configured).
  Future<String> commitAll(String message) async {
    await _runOrThrow(['add', '-A']);
    await _runOrThrow(['commit', '-q', '-m', message]);
    return headHash();
  }

  // ---------------------------------------------------------------------------
  // Status

  /// `git status --porcelain=v2 -z --untracked-files=all -- .` parsed into
  /// project-relative [GitFileStatus] entries. Rename records (`2`) carry
  /// two NUL-separated paths; untracked (`?`) and unmerged (`u`) records are
  /// mapped to their own states.
  Future<List<GitFileStatus>> status() async {
    if (!await isRepository()) return const [];
    final prefix = await _prefix();
    final ProcessResult r;
    try {
      r = await _run(['status', '--porcelain=v2', '-z', '--untracked-files=all', '--', '.']);
    } on ProcessException {
      return const [];
    }
    if (r.exitCode != 0) return const [];
    final raw = _stdout(r);
    if (raw.length < isolateParseBytes) return parsePorcelainV2(raw, prefix: prefix);
    // A huge change set: parsed off the UI isolate.
    return _parseStatusOffThread(raw, prefix);
  }

  /// A static helper so the isolate closure captures only its arguments.
  static Future<List<GitFileStatus>> _parseStatusOffThread(String raw, String prefix) =>
      Zone.root.run(() => Isolate.run(() => GitService(projectRoot: '').parsePorcelainV2(raw, prefix: prefix)));

  /// Pure parser for NUL-terminated porcelain v2 output (testable without git).
  List<GitFileStatus> parsePorcelainV2(String raw, {String prefix = ''}) {
    final tokens = raw.split(' ');
    final out = <GitFileStatus>[];
    var i = 0;
    while (i < tokens.length) {
      final record = tokens[i++];
      if (record.isEmpty) continue;
      final type = record[0];
      switch (type) {
        case '?':
          out.add(GitFileStatus(path: _stripPrefix(record.substring(2), prefix), state: GitFileState.untracked));
        case '!':
          break; // ignored files are never listed without --ignored; skip defensively
        case '1':
          {
            final parts = record.split(' ');
            if (parts.length < 9) break;
            final xy = parts[1];
            final path = parts.sublist(8).join(' ');
            out.add(GitFileStatus(path: _stripPrefix(path, prefix), state: _stateFromXy(xy)));
          }
        case '2':
          {
            final parts = record.split(' ');
            if (parts.length < 10) break;
            final xy = parts[1];
            final path = parts.sublist(9).join(' ');
            final orig = i < tokens.length ? tokens[i++] : null;
            final state = xy.contains('R') || xy.contains('C') ? GitFileState.renamed : _stateFromXy(xy);
            out.add(GitFileStatus(
              path: _stripPrefix(path, prefix),
              origPath: orig == null ? null : _stripPrefix(orig, prefix),
              state: state,
            ));
          }
        case 'u':
          {
            final parts = record.split(' ');
            if (parts.length < 11) break;
            final path = parts.sublist(10).join(' ');
            out.add(GitFileStatus(path: _stripPrefix(path, prefix), state: GitFileState.conflicted));
          }
        case '#':
          break;
        default:
          break;
      }
    }
    return out;
  }

  GitFileState _stateFromXy(String xy) {
    final x = xy.isNotEmpty ? xy[0] : '.';
    final y = xy.length > 1 ? xy[1] : '.';
    if (x == 'U' || y == 'U' || (x == 'A' && y == 'A') || (x == 'D' && y == 'D')) return GitFileState.conflicted;
    if (y == 'D' || x == 'D') return GitFileState.deleted;
    if (x == 'R' || y == 'R') return GitFileState.renamed;
    if (x == 'A') return GitFileState.added;
    return GitFileState.modified;
  }

  // ---------------------------------------------------------------------------
  // Diff summary

  /// `git diff HEAD --numstat -z -- <path>`; `-\t-` means binary, in which
  /// case sizes come from disk and `git cat-file -s HEAD:<path>`. Untracked
  /// files are diffed against `/dev/null` with `--no-index`.
  Future<GitDiffSummary> diffSummary(String path) async {
    final file = File('$projectRoot/$path');
    final prefix = await _prefix();
    final inHead = await headHashOf(path) != null;

    ProcessResult r;
    if (inHead) {
      r = await _run(['diff', 'HEAD', '--numstat', '-z', '--', path]);
    } else if (!Platform.isWindows && file.existsSync()) {
      r = await _run(['diff', '--no-index', '--numstat', '-z', '--', '/dev/null', path]);
    } else {
      return GitDiffSummary(path: path, isBinary: true, oldSize: null, newSize: file.existsSync() ? file.lengthSync() : null);
    }

    final out = _stdout(r);
    if (out.trim().isEmpty) {
      final newSize = file.existsSync() ? file.lengthSync() : null;
      return GitDiffSummary(path: path, isBinary: false, added: 0, removed: 0, newSize: newSize);
    }
    final firstRecord = out.split(' ').first;
    final fields = firstRecord.split('\t');
    final addedRaw = fields.isNotEmpty ? fields[0] : '-';
    final removedRaw = fields.length > 1 ? fields[1] : '-';
    if (addedRaw == '-' || removedRaw == '-') {
      int? oldSize;
      if (inHead) {
        final cat = await _run(['cat-file', '-s', 'HEAD:$prefix$path']);
        if (cat.exitCode == 0) oldSize = int.tryParse(_stdout(cat).trim());
      }
      return GitDiffSummary(
        path: path,
        isBinary: true,
        oldSize: oldSize,
        newSize: file.existsSync() ? file.lengthSync() : null,
      );
    }
    return GitDiffSummary(
      path: path,
      isBinary: false,
      added: int.tryParse(addedRaw) ?? 0,
      removed: int.tryParse(removedRaw) ?? 0,
      newSize: file.existsSync() ? file.lengthSync() : null,
    );
  }

  /// Diff summaries of [paths] in two git processes at most, whatever their
  /// number: one `git diff HEAD --numstat -z` over the
  /// project (`git diff --cached` before the first commit) and, when a
  /// binary file changed, one `git ls-tree -r -l -z HEAD` for the old sizes.
  /// [untracked] paths are not asked of git: their size comes from `stat`
  /// ("new file"). Paths git reports no change for get `+0 −0`.
  Future<Map<String, GitDiffSummary>> diffSummaries(Iterable<String> paths, {Set<String> untracked = const {}}) async {
    final wanted = paths.toList();
    final out = <String, GitDiffSummary>{};
    for (final p in wanted) {
      if (untracked.contains(p)) out[p] = _newFileSummary(p);
    }
    final tracked = [for (final p in wanted) if (!untracked.contains(p)) p];
    if (tracked.isEmpty) return out;
    final snapshot = await diffSnapshot() ?? const GitDiffSnapshot({}, {});
    for (final p in tracked) {
      out[p] = snapshot.summaryFor(p, projectRoot);
    }
    return out;
  }

  GitDiffSummary _newFileSummary(String path) {
    final stat = FileStat.statSync('$projectRoot/$path');
    return GitDiffSummary(
      path: path,
      isBinary: false,
      isNew: true,
      newSize: stat.type == FileSystemEntityType.notFound ? null : stat.size,
    );
  }

  /// The project's working tree against HEAD as numstat records, plus the
  /// HEAD sizes of the binary files among them — the data behind
  /// [diffSummaries], fetched once for any number of paths.
  ///
  /// [cancelled] is asked between the git processes: once it answers true no
  /// further process starts and the result is null. Outputs larger than
  /// [isolateParseBytes] are parsed in a background isolate.
  Future<GitDiffSnapshot?> diffSnapshot({bool Function()? cancelled}) async {
    bool stop() => cancelled?.call() ?? false;
    var r = await _run(['diff', 'HEAD', '--numstat', '-z', '--relative', '--', '.']);
    if (stop()) return null;
    var unborn = false;
    if (r.exitCode != 0) {
      // No commit yet: what is staged is all there is to compare.
      r = await _run(['diff', '--cached', '--numstat', '-z', '--relative', '--', '.']);
      if (stop()) return null;
      unborn = true;
      if (r.exitCode != 0) return const GitDiffSnapshot({}, {});
    }
    final numstat = _stdout(r);
    final records = await _parse(numstat, parseNumstatZ);
    final oldSizes = <String, int>{};
    if (!unborn && records.values.any((n) => n.binary)) {
      if (stop()) return null;
      final tree = await _run(['ls-tree', '-r', '-l', '-z', 'HEAD', '--', '.']);
      if (stop()) return null;
      if (tree.exitCode == 0) oldSizes.addAll(await _parse(_stdout(tree), parseLsTreeSizesZ));
    }
    return GitDiffSnapshot(records, oldSizes);
  }

  /// Git outputs at least this large are parsed off the UI isolate.
  static const int isolateParseBytes = 1024 * 1024;

  /// [parser] over [raw]: here for small outputs, in a background isolate
  /// (started from the root zone, like the git processes) for large ones.
  static Future<T> _parse<T>(String raw, T Function(String) parser) {
    if (raw.length < isolateParseBytes) return Future.value(parser(raw));
    return Zone.root.run(() => Isolate.run(() => parser(raw)));
  }

  /// Pure parser for `git diff --numstat -z` (renames carry an empty path
  /// field followed by the old and the new path).
  static Map<String, GitNumstat> parseNumstatZ(String raw) {
    final tokens = raw.split('\x00');
    final out = <String, GitNumstat>{};
    var i = 0;
    while (i < tokens.length) {
      final record = tokens[i++];
      if (record.isEmpty) continue;
      final fields = record.split('\t');
      if (fields.length < 3) continue;
      var path = fields.sublist(2).join('\t');
      if (path.isEmpty) {
        // rename: `added\tremoved\t\0old\0new\0`
        if (i + 1 >= tokens.length) break;
        i++; // old path
        path = tokens[i++];
      }
      final binary = fields[0] == '-' || fields[1] == '-';
      out[path] = GitNumstat(
        binary: binary,
        added: binary ? 0 : int.tryParse(fields[0]) ?? 0,
        removed: binary ? 0 : int.tryParse(fields[1]) ?? 0,
      );
    }
    return out;
  }

  /// Pure parser for `git ls-tree -r -l -z` (`<mode> blob <sha> <size>\t<path>`).
  static Map<String, int> parseLsTreeSizesZ(String raw) {
    final out = <String, int>{};
    for (final record in raw.split('\x00')) {
      final tab = record.indexOf('\t');
      if (tab < 0) continue;
      final meta = record.substring(0, tab).split(RegExp(r' +'));
      if (meta.length < 4) continue;
      final size = int.tryParse(meta[3]);
      if (size != null) out[record.substring(tab + 1)] = size;
    }
    return out;
  }

  // ---------------------------------------------------------------------------
  // Commit

  /// Stages exactly [paths] (`git add --` for present files, `git rm --cached
  /// --` for deletions) and commits only those paths. Returns the new HEAD
  /// hash. Validation errors ([ArgumentError]) are raised before any git call.
  Future<String> commit({
    required List<String> paths,
    required String message,
    void Function(String step, double progress)? onStep,
  }) async {
    if (message.trim().isEmpty) {
      throw ArgumentError.value(message, 'message', 'Commit message must not be empty');
    }
    if (paths.isEmpty) {
      throw ArgumentError.value(paths, 'paths', 'Select at least one file to commit');
    }
    final present = <String>[];
    final missing = <String>[];
    for (final p in paths) {
      (File('$projectRoot/$p').existsSync() || Directory('$projectRoot/$p').existsSync() ? present : missing).add(p);
    }
    // Long path lists go through --pathspec-from-file:
    // one process each, whatever the count, and no argv length limit.
    final temp = <File>[];
    Future<List<String>> pathspec(List<String> list) async {
      if (list.length <= pathspecFileThreshold) return ['--', ...list];
      final f = File('${Directory.systemTemp.path}/lumina_git_pathspec_${DateTime.now().microsecondsSinceEpoch}_${temp.length}.txt');
      await f.writeAsString('${list.join('\x00')}\x00');
      temp.add(f);
      return ['--pathspec-from-file=${f.path}', '--pathspec-file-nul'];
    }

    try {
      onStep?.call('Staging', 0.0);
      if (present.isNotEmpty) await _runOrThrow(['add', ...await pathspec(present)]);
      if (missing.isNotEmpty) {
        onStep?.call('Staging deletions', 0.33);
        await _runOrThrow(['rm', '--cached', '--quiet', '--ignore-unmatch', ...await pathspec(missing)]);
      }
      onStep?.call('Committing', 0.66);
      await _runOrThrow(['commit', '-q', '-m', message, '--only', ...await pathspec(paths)]);
      onStep?.call('Committed', 1.0);
    } finally {
      for (final f in temp) {
        try {
          f.deleteSync();
        } catch (_) {}
      }
    }
    return headHash();
  }

  Future<String> headHash() async {
    final r = await _runOrThrow(['rev-parse', 'HEAD']);
    return _stdout(r).trim();
  }

  /// Hash of the last commit touching [path], or null when HEAD has no such path.
  Future<String?> headHashOf(String path) async {
    final r = await _run(['rev-list', '-1', 'HEAD', '--', path]);
    if (r.exitCode != 0) return null;
    final hash = _stdout(r).trim();
    if (hash.isEmpty) return null;
    // rev-list also matches deleted paths; make sure the blob exists in HEAD.
    final prefix = await _prefix();
    final cat = await _run(['cat-file', '-e', 'HEAD:$prefix$path']);
    return cat.exitCode == 0 ? hash : null;
  }

  // ---------------------------------------------------------------------------
  // History

  /// `git log --follow -z --format=%H%x1f%an%x1f%aI%x1f%s -n <limit> -- <path>`.
  Future<List<GitLogEntry>> fileHistory(String path, {int limit = 50}) async {
    final r = await _run(['log', '--follow', '-z', '--format=%H%x1f%an%x1f%aI%x1f%s', '-n', '$limit', '--', path]);
    if (r.exitCode != 0) return const [];
    final entries = <GitLogEntry>[];
    for (final record in _stdout(r).split(' ')) {
      if (record.trim().isEmpty) continue;
      final f = record.split('');
      if (f.length < 4) continue;
      entries.add(GitLogEntry(
        hash: f[0].trim(),
        author: f[1],
        date: DateTime.tryParse(f[2]) ?? DateTime.fromMillisecondsSinceEpoch(0),
        subject: f.sublist(3).join(''),
      ));
    }
    return entries;
  }

  // ---------------------------------------------------------------------------
  // Restore

  /// Discards index + working-tree changes of [path] back to HEAD.
  Future<void> restoreFile(String path) async {
    await _runOrThrow(['restore', '--source=HEAD', '--staged', '--worktree', '--', path]);
  }

  // ---------------------------------------------------------------------------
  // Identity

  Future<bool> hasIdentity() async {
    try {
      final name = await _run(['config', 'user.name']);
      final email = await _run(['config', 'user.email']);
      return name.exitCode == 0 && email.exitCode == 0 && _stdout(name).trim().isNotEmpty && _stdout(email).trim().isNotEmpty;
    } on ProcessException {
      return false;
    }
  }

  /// Writes a repo-local identity (never global, never the Studio user's mail).
  Future<void> configureIdentity({required String name, required String email}) async {
    await _runOrThrow(['config', 'user.name', name]);
    await _runOrThrow(['config', 'user.email', email]);
  }
}

/// One `git diff --numstat` record.
class GitNumstat {
  final bool binary;
  final int added;
  final int removed;
  const GitNumstat({required this.binary, this.added = 0, this.removed = 0});
}

/// The working tree against HEAD for every changed path, fetched once
/// ([GitService.diffSnapshot]).
class GitDiffSnapshot {
  /// Project-relative path → numstat.
  final Map<String, GitNumstat> numstat;

  /// Project-relative path → size in HEAD (binary files only).
  final Map<String, int> headSizes;

  const GitDiffSnapshot(this.numstat, this.headSizes);

  GitDiffSummary summaryFor(String path, String projectRoot) {
    final stat = FileStat.statSync('$projectRoot/$path');
    final newSize = stat.type == FileSystemEntityType.notFound ? null : stat.size;
    final n = numstat[path];
    if (n == null) return GitDiffSummary(path: path, isBinary: false, newSize: newSize);
    if (n.binary) return GitDiffSummary(path: path, isBinary: true, oldSize: headSizes[path], newSize: newSize);
    return GitDiffSummary(path: path, isBinary: false, added: n.added, removed: n.removed, newSize: newSize);
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:lumina/lumina.dart';

import 'package:lumina_ui/ui/features/source_control/services/git_service.dart';

/// One entry of the `Tools → Source Control` submenu model. The menu bar
/// renders [enabled] as the item's enabled state and [tooltip] as a label
/// above the entries when git is unavailable.
class SourceControlMenuEntry {
  final String id;
  final String label;
  final bool enabled;
  final String? tooltip;

  const SourceControlMenuEntry({required this.id, required this.label, required this.enabled, this.tooltip});
}

/// The changed files of one folder inside a changelist (commit dialog).
class ChangeFolderGroup {
  /// Project-relative folder (`''` for the project root).
  final String folder;
  final List<GitFileStatus> entries;

  const ChangeFolderGroup({required this.folder, required this.entries});

  /// Folders with more changes than this start collapsed.
  static const int collapseThreshold = 50;

  String get label => folder.isEmpty ? '(project root)' : '$folder/';
}

/// Changed files grouped under one commit-dialog header.
class ChangelistGroup {
  final String title;
  final List<GitFileStatus> entries;

  const ChangelistGroup({required this.title, required this.entries});
}

/// Editor-side state over [GitService]: caches the `git status` map the
/// Content Browser badges read (O(1) lookups, no git call per tile), exposes
/// availability / repository probes, the init-prompt state, the changelist
/// grouping for the commit dialog, and revert/commit/history operations.
///
/// `refresh()` is single-flight: concurrent callers join the in-flight
/// future, so a burst of save/asset events costs one `git status`.
class SourceControlViewModel extends ChangeNotifier with WidgetsBindingObserver {
  static const String installHint =
      'Git is not installed or not on PATH. Install git (https://git-scm.com) and restart Lumina Studio.';

  static const String commitCommandId = 'sourceControl.commit';
  static const String historyCommandId = 'sourceControl.history';
  static const String refreshCommandId = 'sourceControl.refresh';
  static const String initCommandId = 'sourceControl.initRepository';

  final GitService service;
  final EngineLoggerService _logger;

  /// Fired after a successful revert/delete so the editor reloads the asset or
  /// level from disk (in-memory state must match the working tree).
  final void Function(String path)? onFileRestored;

  bool _available = false;
  bool _repo = false;
  bool _probed = false;
  bool _initPromptDismissed = false;
  bool _identityRequired = false;
  bool _disposed = false;
  String? _lastError;
  String? _lastCommitHash;
  Map<String, GitFileStatus> _statusByPath = const {};
  final Map<String, GitDiffSummary> _summaries = {};
  Future<void>? _inFlightRefresh;
  final Set<Future<void>> _pendingOps = {};

  SourceControlViewModel({
    required String projectRoot,
    GitService? service,
    GitProcessRunner? runner,
    List<String> configOverrides = const [],
    EngineLoggerService? logger,
    this.onFileRestored,
  })  : service = service ??
            GitService(projectRoot: projectRoot, runner: runner, configOverrides: configOverrides, logger: logger),
        _logger = logger ?? EngineLoggerService() {
    _initPromptDismissed = _readDismissal();
    try {
      WidgetsBinding.instance.addObserver(this);
    } catch (_) {
      // No binding (plain unit test / headless) — window-focus refresh is optional.
    }
  }

  String get projectRoot => service.projectRoot;

  bool get isAvailable => _available;
  bool get isRepo => _repo;
  bool get isProbed => _probed;
  bool get identityRequired => _identityRequired;
  bool get initPromptDismissed => _initPromptDismissed;
  String? get lastError => _lastError;
  String? get lastCommitHash => _lastCommitHash;
  bool get isBusy => _pendingOps.isNotEmpty || _inFlightRefresh != null;

  /// True when the project has no repository of its own and the user has not
  /// dismissed the init banner (git must be present for the prompt to matter).
  bool get shouldPromptInit => _probed && _available && !_repo && !_initPromptDismissed;

  List<GitFileStatus> get changes => _statusByPath.values.toList(growable: false);
  bool get hasChanges => _statusByPath.isNotEmpty;

  /// Completes when every in-flight refresh/commit/init/revert has settled.
  Future<void> get whenIdle async {
    while (_inFlightRefresh != null || _pendingOps.isNotEmpty) {
      final waits = <Future<void>>[?_inFlightRefresh, ..._pendingOps];
      await Future.wait(waits.map((f) => f.catchError((_) {})));
    }
  }

  // ---------------------------------------------------------------------------
  // Lookups

  GitFileState? stateFor(String path) => _statusByPath[path]?.state;

  GitFileStatus? statusFor(String path) => _statusByPath[path];

  /// First matching state across several candidate paths (an asset tile may
  /// represent a `.lmas` plus its raw payload sibling).
  GitFileState? stateForAny(Iterable<String> paths) {
    for (final p in paths) {
      final s = _statusByPath[p]?.state;
      if (s != null) return s;
    }
    return null;
  }

  /// Aggregated state for a folder: conflict > deleted > modified > added/untracked.
  GitFileState? folderState(String folder) {
    final prefix = folder.endsWith('/') ? folder : '$folder/';
    GitFileState? best;
    for (final s in _statusByPath.values) {
      if (!s.path.startsWith(prefix)) continue;
      if (best == null || _rank(s.state) > _rank(best)) best = s.state;
    }
    return best;
  }

  int _rank(GitFileState s) => switch (s) {
        GitFileState.conflicted => 5,
        GitFileState.deleted => 4,
        GitFileState.modified => 3,
        GitFileState.renamed => 2,
        GitFileState.added => 1,
        GitFileState.untracked => 1,
      };

  /// The active level is dirty when its `.lmas` or generated
  /// `lib/levels/<level>.dart` (snake_case) differs from HEAD.
  bool isLevelDirty(String levelName) =>
      _statusByPath.containsKey('contents/levels/$levelName.lmas') ||
      _statusByPath.containsKey('lib/levels/${dartFileName(levelName)}');

  GitDiffSummary? summaryFor(String path) => _summaries[path];

  /// Changelists in commit-dialog order: Assets / Levels / Generated code / Project.
  List<ChangelistGroup> get groupedChanges {
    final assets = <GitFileStatus>[];
    final levels = <GitFileStatus>[];
    final code = <GitFileStatus>[];
    final project = <GitFileStatus>[];
    final sorted = changes..sort((a, b) => a.path.compareTo(b.path));
    for (final s in sorted) {
      if (s.path.startsWith('contents/levels/')) {
        levels.add(s);
      } else if (s.path.endsWith('.lmas') || s.path.startsWith('contents/')) {
        assets.add(s);
      } else if (s.path.startsWith('lib/')) {
        code.add(s);
      } else {
        project.add(s);
      }
    }
    return [
      ChangelistGroup(title: 'Assets (.lmas)', entries: assets),
      ChangelistGroup(title: 'Levels', entries: levels),
      ChangelistGroup(title: 'Generated code (lib/)', entries: code),
      ChangelistGroup(title: 'Project', entries: project),
    ];
  }

  List<SourceControlMenuEntry> get menuEntries {
    final hint = _probed && !_available ? installHint : null;
    final ready = _available && _repo;
    return [
      SourceControlMenuEntry(
        id: commitCommandId,
        label: 'Commit…',
        enabled: ready,
        tooltip: hint ?? (ready ? null : 'Initialize a repository first'),
      ),
      SourceControlMenuEntry(
        id: historyCommandId,
        label: 'History for Active Level',
        enabled: ready,
        tooltip: hint ?? (ready ? null : 'Initialize a repository first'),
      ),
      SourceControlMenuEntry(id: refreshCommandId, label: 'Refresh Status', enabled: _available, tooltip: hint),
      SourceControlMenuEntry(
        id: initCommandId,
        label: 'Initialize Repository',
        enabled: _available && !_repo,
        tooltip: hint ?? (_repo ? 'This project is already a git repository' : null),
      ),
    ];
  }

  // ---------------------------------------------------------------------------
  // Refresh

  /// Re-probes git availability + repository state and reloads the status
  /// map. Concurrent callers share the in-flight future (single-flight).
  /// Completes when no refresh (and so no git process in the project
  /// folder) is running; never starts one.
  Future<void> get idle => _inFlightRefresh ?? Future<void>.value();

  Future<void> refresh() {
    final running = _inFlightRefresh;
    if (running != null) return running;
    final f = _doRefresh().whenComplete(() {
      _inFlightRefresh = null;
    });
    _inFlightRefresh = f;
    return f;
  }

  Future<void> _doRefresh() async {
    try {
      _available = await service.isGitAvailable();
      _repo = _available && await service.isRepository();
      if (_repo) {
        final list = await service.status();
        _statusByPath = {for (final s in list) s.path: s};
        _summaries.removeWhere((path, _) => !_statusByPath.containsKey(path));
      } else {
        _statusByPath = const {};
        _summaries.clear();
      }
    } on ProcessException catch (e) {
      _available = false;
      _repo = false;
      _statusByPath = const {};
      _logger.log('git unavailable: ${e.message}', level: 'warning', source: 'SourceControl');
    } catch (e) {
      _lastError = 'Status refresh failed: $e';
      _logger.log(_lastError!, level: 'error', source: 'SourceControl');
    } finally {
      _probed = true;
      _notify();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _available) {
      refresh();
    }
  }

  /// Paths per summary batch: the dialog updates after each one.
  static const int summaryChunkSize = 500;

  int _summaryGeneration = 0;
  bool _summariesLoading = false;
  int _summariesDone = 0;
  int _summariesTotal = 0;

  /// Whether [loadSummaries] is still filling rows in.
  bool get summariesLoading => _summariesLoading;

  /// Rows filled in / rows to fill by the running (or last) [loadSummaries]:
  /// the dialog's "Loading changes 340 / 955".
  int get summariesDone => _summariesDone;
  int get summariesTotal => _summariesTotal;

  /// Whether a `git status` refresh is running (the dialog's indeterminate bar).
  bool get statusLoading => _inFlightRefresh != null;

  /// What the commit dialog does on open: the status
  /// (the list shows as soon as it is there), then the diff summaries — all
  /// async git processes, the UI isolate never waits on one.
  Future<void> loadChanges() {
    final token = ++_summaryGeneration;
    return _track(() async {
      await refresh();
      // Closed (cancelSummaries) while the status ran: nothing more to load.
      if (token != _summaryGeneration || _disposed) return;
      await loadSummaries();
    });
  }

  /// Stops an in-flight [loadSummaries] (the commit dialog closed): no more
  /// git processes are started for it and no more rows are filled in.
  void cancelSummaries() {
    _summaryGeneration++;
    if (_summariesLoading) {
      _summariesLoading = false;
      _notify();
    }
  }

  /// Loads diff summaries for every current change (commit dialog rows) —
  /// untracked files' sizes come from `stat` at once; the
  /// tracked files' numbers from one batched `git diff --numstat` snapshot
  /// (plus one `git ls-tree` when a binary file changed). Rows are filled in
  /// [summaryChunkSize] at a time, the dialog notified after each chunk, one
  /// git process at a time, and [cancelSummaries] stops it between any two
  /// steps. One Output Log line per load.
  Future<Map<String, GitDiffSummary>> loadSummaries() {
    final generation = ++_summaryGeneration;
    final op = _track(() async {
      final pending = [for (final s in changes) if (!_summaries.containsKey(s.path)) s];
      if (pending.isEmpty) return;
      final sw = Stopwatch()..start();
      _summariesLoading = true;
      _summariesTotal = pending.length;
      _summariesDone = 0;
      _notify();
      bool cancelled() => generation != _summaryGeneration || _disposed;
      try {
        final untracked = [for (final s in pending) if (s.state == GitFileState.untracked) s];
        final tracked = [for (final s in pending) if (s.state != GitFileState.untracked) s];
        Future<void> fill(List<GitFileStatus> list, GitDiffSummary Function(GitFileStatus) summarize) async {
          for (var start = 0; start < list.length; start += summaryChunkSize) {
            if (cancelled()) return;
            final end = (start + summaryChunkSize).clamp(0, list.length);
            for (final s in list.sublist(start, end)) {
              _summaries[s.path] = summarize(s);
            }
            _summariesDone += end - start;
            _notify();
            // Let the dialog paint the chunk before the next one.
            await Future<void>.delayed(Duration.zero);
          }
        }

        await fill(untracked, (s) => _untrackedSummary(s.path));
        if (tracked.isNotEmpty && !cancelled()) {
          final snapshot = await service.diffSnapshot(cancelled: cancelled);
          if (snapshot != null && !cancelled()) {
            await fill(tracked, (s) => snapshot.summaryFor(s.path, projectRoot));
          }
        }
        if (!cancelled()) {
          _logger.log('SourceControl: diff summaries for ${pending.length} files (${sw.elapsedMilliseconds} ms)',
              level: 'info', source: 'SourceControl');
        }
      } catch (e) {
        _logger.log('Diff summaries failed: $e', level: 'warning', source: 'SourceControl');
      } finally {
        if (generation == _summaryGeneration) {
          _summariesLoading = false;
          _notify();
        }
      }
    });
    return op.then((_) => Map.unmodifiable(_summaries));
  }

  GitDiffSummary _untrackedSummary(String path) {
    final stat = FileStat.statSync('$projectRoot/$path');
    return GitDiffSummary(
      path: path,
      isBinary: false,
      isNew: true,
      newSize: stat.type == FileSystemEntityType.notFound ? null : stat.size,
    );
  }

  /// [entries] grouped by folder (their parent directory), folders sorted,
  /// files sorted within each — the commit dialog's second level.
  static List<ChangeFolderGroup> foldersOf(List<GitFileStatus> entries) {
    final byFolder = <String, List<GitFileStatus>>{};
    for (final e in entries) {
      final slash = e.path.lastIndexOf('/');
      (byFolder[slash < 0 ? '' : e.path.substring(0, slash)] ??= []).add(e);
    }
    final folders = byFolder.keys.toList()..sort();
    return [
      for (final f in folders) ChangeFolderGroup(folder: f, entries: byFolder[f]!..sort((a, b) => a.path.compareTo(b.path))),
    ];
  }

  // ---------------------------------------------------------------------------
  // Operations

  Future<T> _track<T>(Future<T> Function() body) {
    final f = body();
    final tracked = f.then((_) {}, onError: (_) {});
    _pendingOps.add(tracked);
    tracked.whenComplete(() => _pendingOps.remove(tracked));
    return f;
  }

  int _committingCount = 0;
  String? _commitStep;
  double _commitProgress = 0;

  /// Files the running commit covers (0 when none is running).
  int get committingCount => _committingCount;

  /// The running commit's step (`Staging`, `Committing`, `Refreshing status`)
  /// and its progress 0…1, for the dialog's "Committing 955 files…" bar.
  String? get commitStep => _commitStep;
  double get commitProgress => _commitProgress;

  void _commitStage(String step, double progress) {
    _commitStep = step;
    _commitProgress = progress;
    _notify();
  }

  /// Commits exactly [paths]; returns the new hash or null (see [lastError]).
  /// The staging and the commit are async git processes (`--pathspec-from-file`
  /// for long lists), reported step by step through [commitStep] /
  /// [commitProgress].
  Future<String?> commit({required List<String> paths, required String message}) {
    return _track(() async {
      _lastError = null;
      _lastCommitHash = null;
      if (!_available) {
        _lastError = installHint;
        _notify();
        return null;
      }
      _committingCount = paths.length;
      try {
        final sw = Stopwatch()..start();
        final hash = await service.commit(
          paths: paths,
          message: message,
          onStep: (step, progress) => _commitStage(step, progress * 0.9),
        );
        _lastCommitHash = hash;
        _identityRequired = false;
        _commitStage('Refreshing status', 0.9);
        await refresh();
        _logger.log('Committed ${paths.length} file(s) as ${hash.substring(0, 7)} in ${sw.elapsedMilliseconds} ms: $message',
            level: 'success', source: 'SourceControl');
        return hash;
      } on ArgumentError catch (e) {
        _lastError = e.message?.toString() ?? 'Invalid commit';
      } on GitException catch (e) {
        _identityRequired = e.isIdentityError;
        _lastError = e.toString();
        _logger.log(_lastError!, level: 'error', source: 'SourceControl');
      } on ProcessException catch (e) {
        _available = false;
        _lastError = '${e.message} ($installHint)';
      } finally {
        _committingCount = 0;
        _commitStep = null;
        _commitProgress = 0;
      }
      _notify();
      return null;
    });
  }

  /// `git init` + `.gitignore` + initial commit. Returns true on success.
  /// An identity failure leaves the repo initialised & staged and flips
  /// [identityRequired] so the UI can collect a repo-local identity.
  Future<bool> initRepository() {
    return _track(() async {
      _lastError = null;
      if (!_available) {
        _lastError = installHint;
        _notify();
        return false;
      }
      try {
        await service.init(gitignoreContent: GitService.defaultGitignore, initialCommitMessage: 'Initial Lumina project');
        _logger.log('Initialized git repository in $projectRoot', level: 'success', source: 'SourceControl');
        await refresh();
        return _repo;
      } on GitException catch (e) {
        _identityRequired = e.isIdentityError;
        _lastError = e.toString();
        _logger.log(_lastError!, level: 'error', source: 'SourceControl');
        await refresh();
        return false;
      } on ProcessException catch (e) {
        _available = false;
        _lastError = '${e.message} ($installHint)';
        _notify();
        return false;
      }
    });
  }

  /// Writes a repo-local identity, then finishes whatever the identity error
  /// interrupted (initial commit when the repo has no HEAD yet).
  Future<bool> configureIdentity({required String name, required String email}) {
    return _track(() async {
      _lastError = null;
      try {
        await service.configureIdentity(name: name.trim(), email: email.trim());
        _identityRequired = false;
        if (_repo && await service.headHashOf('.gitignore') == null) {
          await service.commitAll('Initial Lumina project');
        }
        await refresh();
        return true;
      } on GitException catch (e) {
        _lastError = e.toString();
        _notify();
        return false;
      }
    });
  }

  /// Discards working-tree changes of [path] (`git restore`), or deletes an
  /// untracked file when [deleteUntracked] is set; fires [onFileRestored].
  Future<bool> revert(String path, {bool deleteUntracked = false}) {
    return _track(() async {
      _lastError = null;
      final state = stateFor(path);
      try {
        if (state == GitFileState.untracked || (state == GitFileState.added && await service.headHashOf(path) == null)) {
          if (!deleteUntracked) {
            _lastError = '$path is untracked; delete it instead of reverting.';
            _notify();
            return false;
          }
          final f = File('$projectRoot/$path');
          if (f.existsSync()) f.deleteSync();
          final unstage = await service.headHashOf(path);
          if (unstage == null && state == GitFileState.added) {
            // staged-new file: drop it from the index as well
            await service.restoreFile(path).catchError((_) {});
          }
          _logger.log('Deleted untracked $path', level: 'info', source: 'SourceControl');
        } else {
          await service.restoreFile(path);
          _logger.log('Reverted $path to HEAD', level: 'success', source: 'SourceControl');
        }
        await refresh();
        onFileRestored?.call(path);
        return true;
      } on GitException catch (e) {
        _lastError = e.toString();
        _logger.log(_lastError!, level: 'error', source: 'SourceControl');
        _notify();
        return false;
      }
    });
  }

  Future<List<GitLogEntry>> history(String path, {int limit = 50}) {
    return _track(() async {
      try {
        return await service.fileHistory(path, limit: limit);
      } on ProcessException {
        return const <GitLogEntry>[];
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Init-prompt dismissal (persisted next to the project)

  File get _dismissalFile => File('$projectRoot/.lumina/source_control.json');

  bool _readDismissal() {
    try {
      final f = _dismissalFile;
      if (!f.existsSync()) return false;
      final map = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      return map['init_prompt_dismissed'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> dismissInitPrompt() async {
    _initPromptDismissed = true;
    try {
      final f = _dismissalFile;
      f.parent.createSync(recursive: true);
      f.writeAsStringSync(jsonEncode({'init_prompt_dismissed': true}));
    } catch (e) {
      _logger.log('Could not persist init-prompt dismissal: $e', level: 'warning', source: 'SourceControl');
    }
    _notify();
  }

  void clearError() {
    _lastError = null;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    try {
      WidgetsBinding.instance.removeObserver(this);
    } catch (_) {}
    super.dispose();
  }
}

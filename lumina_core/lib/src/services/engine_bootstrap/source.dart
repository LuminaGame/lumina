part of '../engine_bootstrap.dart';

/// The engine source: the git clone and checkout, and running git.
extension _EngineBootstrapSource on EngineBootstrap {
  // ---------------------------------------------------------------------------
  // Source

  Future<String> _ensureSource(String git, void Function(EngineBootstrapEvent) emit) async {
    const step = EngineBootstrapStep.source;
    final dir = checkoutDir;
    if (dir.existsSync() && !await _isOwnRepo(git)) {
      emit(EngineBootstrapLog(step, '${dir.path} is not a complete clone of $repo: downloading it again'));
      await _wipe(dir);
    }
    if (!dir.existsSync()) {
      emit(EngineBootstrapProgress(step, 'Cloning $repo', fraction: 0));
      final r = await _git(git, [
        'clone', '--filter=blob:none', '--no-checkout', '--progress', //
        if (_windows) ...['-c', 'core.longpaths=true'],
        repo, dir.path,
      ], step: step, emit: emit, workingDirectory: engineRoot.path);
      if (r != 0) {
        await _wipe(dir);
        throw EngineBootstrapException('Could not clone $repo (git exited with $r). Check the network connection and retry.', step: step);
      }
    }

    final target = commit.isNotEmpty ? commit : 'refs/tags/$version';
    var resolved = await _revParse(git, '$target^{commit}');
    if (resolved == null) {
      emit(EngineBootstrapProgress(step, 'Fetching $target'));
      if (commit.isNotEmpty) {
        await _git(git, ['fetch', '--filter=blob:none', '--progress', 'origin', commit], step: step, emit: emit);
        resolved = await _revParse(git, '$target^{commit}');
      }
      if (resolved == null) {
        await _git(git, ['fetch', '--filter=blob:none', '--progress', '--tags', 'origin'], step: step, emit: emit);
        resolved = await _revParse(git, '$target^{commit}');
      }
      if (resolved == null) {
        throw EngineBootstrapException('$repo has no commit ${commit.isNotEmpty ? commit : 'for tag $version'}.', step: step);
      }
    }

    final head = await _revParse(git, 'HEAD');
    final dirty = await _gitOutput(git, ['status', '--porcelain', '--untracked-files=no']);
    if (head != resolved || dirty == null || dirty.trim().isNotEmpty) {
      emit(EngineBootstrapProgress(step, 'Checking out $resolved', fraction: 0.8));
      final r = await _git(git, ['-c', 'advice.detachedHead=false', 'checkout', '--force', '--progress', '--detach', resolved],
          step: step, emit: emit);
      if (r != 0) {
        throw EngineBootstrapException('Could not check out $resolved (git exited with $r). Check the network connection and retry.',
            step: step);
      }
    } else {
      emit(EngineBootstrapLog(step, 'Already at $resolved'));
    }
    emit(EngineBootstrapProgress(step, 'Engine source at $resolved', fraction: 1));
    return resolved;
  }

  /// Whether [checkoutDir] holds its own `.git` (not a parent's) whose
  /// origin is [repo].
  Future<bool> _isOwnRepo(String git) async {
    final gitDir = Directory(p.join(checkoutDir.path, '.git'));
    if (!File(p.join(gitDir.path, 'HEAD')).existsSync()) return false;
    final top = await _gitOutput(git, ['rev-parse', '--absolute-git-dir']);
    if (top == null || !p.equals(p.normalize(top.trim()), p.normalize(gitDir.absolute.path))) return false;
    final origin = await _gitOutput(git, ['config', '--get', 'remote.origin.url']);
    return origin != null && origin.trim() == repo;
  }

  Future<String?> _revParse(String git, String rev) async {
    final out = await _gitOutput(git, ['rev-parse', '--verify', '--quiet', rev]);
    final sha = out?.trim();
    return sha == null || sha.isEmpty ? null : sha;
  }

  Map<String, String> get _gitEnvironment => {...environment, 'GIT_TERMINAL_PROMPT': '0'};

  Future<String?> _gitOutput(String git, List<String> args) async {
    try {
      final r = await Process.run(git, args,
          workingDirectory: checkoutDir.path, environment: _gitEnvironment, includeParentEnvironment: false, stdoutEncoding: utf8);
      return r.exitCode == 0 ? '${r.stdout}' : null;
    } on ProcessException {
      return null;
    }
  }

  static final RegExp _gitPercent = RegExp(r'^(Receiving objects|Resolving deltas|Updating files|remote: [^:]+):\s+(\d+)%');

  /// Runs git, streaming its output; `%` progress lines become progress
  /// events. Returns the exit code.
  Future<int> _git(String git, List<String> args,
      {required EngineBootstrapStep step, required void Function(EngineBootstrapEvent) emit, String? workingDirectory}) {
    return _stream(git, args, step: step, emit: emit, workingDirectory: workingDirectory ?? checkoutDir.path, environment: _gitEnvironment,
        progress: (line) {
      final m = _gitPercent.firstMatch(line);
      if (m == null) return null;
      final pct = int.parse(m.group(2)!) / 100;
      final phase = m.group(1)!;
      // Clone: objects to 70%, deltas to 80%; checkout: files to 100%.
      final fraction = switch (phase) {
        'Receiving objects' => pct * 0.7,
        'Resolving deltas' => 0.7 + pct * 0.1,
        'Updating files' => 0.8 + pct * 0.2,
        _ => null,
      };
      return EngineBootstrapProgress(step, line, fraction: fraction);
    });
  }

  Future<int> _stream(String exe, List<String> args,
      {required EngineBootstrapStep step,
      required void Function(EngineBootstrapEvent) emit,
      required String workingDirectory,
      required Map<String, String> environment,
      bool runInShell = false,
      EngineBootstrapProgress? Function(String line)? progress}) async {
    final Process process;
    try {
      process = await Process.start(exe, args,
          workingDirectory: workingDirectory, environment: environment, includeParentEnvironment: false, runInShell: runInShell);
    } on ProcessException catch (e) {
      emit(EngineBootstrapLog(step, 'Could not start $exe: ${e.message}'));
      return -1;
    }
    String? lastProgress;
    void onLine(String raw) {
      final line = raw.trimRight();
      if (line.isEmpty) return;
      final pr = progress?.call(line);
      if (pr != null) {
        // Throttle: one event per distinct line, and a log line when a phase ends.
        if (pr.message == lastProgress) return;
        lastProgress = pr.message;
        emit(pr);
        if (line.contains('100%') || line.contains('done')) emit(EngineBootstrapLog(step, line));
        return;
      }
      emit(EngineBootstrapLog(step, line));
    }

    Future<void> pump(Stream<List<int>> s) =>
        s.transform(const Utf8Decoder(allowMalformed: true)).transform(const _CrLfSplitter()).forEach(onLine);
    await Future.wait([pump(process.stdout), pump(process.stderr)]);
    return process.exitCode;
  }
}

/// Splits text on `\n`, `\r\n` and bare `\r` (git redraws progress lines
/// with `\r`).
class _CrLfSplitter extends StreamTransformerBase<String, String> {
  const _CrLfSplitter();

  @override
  Stream<String> bind(Stream<String> stream) async* {
    var carry = '';
    await for (final chunk in stream) {
      final parts = (carry + chunk).split(RegExp(r'\r\n|\r|\n'));
      carry = parts.removeLast();
      yield* Stream.fromIterable(parts);
    }
    if (carry.isNotEmpty) yield carry;
  }
}

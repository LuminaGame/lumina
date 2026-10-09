import 'dart:io';

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

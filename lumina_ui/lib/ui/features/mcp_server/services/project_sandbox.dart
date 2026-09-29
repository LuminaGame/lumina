import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// What a file tool wants to do with a path.
enum SandboxAccess { read, write, delete }

/// A path a file tool may not touch; [message] is what the agent sees.
class SandboxViolation implements Exception {
  final String message;
  const SandboxViolation(this.message);

  @override
  String toString() => message;
}

/// A path inside the project: its real [absolute] path and its
/// project-relative, `/`-separated form (`.` for the root itself).
class SandboxPath {
  final String absolute;
  final String relative;
  const SandboxPath(this.absolute, this.relative);

  bool get isRoot => relative == '.';
}

/// The open project's root as the file tools see it: every
/// path is resolved (symlinks and `..` included) and must stay inside the
/// resolved root; writes and deletes are further denied where the editor,
/// the build or another tool owns the files.
class ProjectSandbox {
  ProjectSandbox(String projectDir) : root = Directory(projectDir).resolveSymbolicLinksSync();

  /// The project directory with its symlinks resolved.
  final String root;

  /// The directories a recursive listing or search skips unless the
  /// listed / searched path is inside them.
  static const Set<String> skippedDirs = {'build', '.dart_tool', '.git'};

  /// Paths compare case-insensitively where the file system does.
  static final bool _caseInsensitive = Platform.isWindows || Platform.isMacOS;

  /// [path] (project-relative or absolute) resolved inside the project;
  /// throws a [SandboxViolation] when it leaves the project or [access] is
  /// denied there.
  SandboxPath resolve(String path, {required SandboxAccess access}) {
    if (path.isEmpty) throw const SandboxViolation('An empty path names no file; pass a project-relative path.');
    if (path.contains('\u0000')) throw const SandboxViolation('A path may not contain a NUL byte.');
    final joined = p.isAbsolute(path) ? path : p.join(root, path);
    final normalized = p.normalize(p.absolute(joined));
    final real = _real(normalized, path);
    if (!_inside(real)) throw SandboxViolation('$path is outside the project ($root).');
    final relative = p.equals(real, root) ? '.' : p.relative(real, from: root).replaceAll(r'\', '/');
    final resolved = SandboxPath(real, relative);
    if (access != SandboxAccess.read) _checkWritable(resolved, access);
    return resolved;
  }

  bool _inside(String real) => p.equals(real, root) || p.isWithin(root, real);

  /// The real path of [normalized]: an existing path with its links
  /// resolved; a new one through its deepest existing ancestor.
  String _real(String normalized, String original) {
    if (FileSystemEntity.typeSync(normalized, followLinks: false) != FileSystemEntityType.notFound) {
      try {
        return p.normalize(File(normalized).resolveSymbolicLinksSync());
      } on FileSystemException catch (e) {
        throw SandboxViolation('$original cannot be resolved (${e.osError?.message ?? e.message}); a broken link?');
      }
    }
    var ancestor = normalized;
    final rest = <String>[];
    while (FileSystemEntity.typeSync(ancestor, followLinks: false) == FileSystemEntityType.notFound) {
      final parent = p.dirname(ancestor);
      if (parent == ancestor) throw SandboxViolation('$original is outside the project ($root).');
      rest.insert(0, p.basename(ancestor));
      ancestor = parent;
    }
    String base;
    try {
      base = File(ancestor).resolveSymbolicLinksSync();
    } on FileSystemException {
      throw SandboxViolation('$original cannot be resolved; a broken link?');
    }
    return p.normalize(p.joinAll([base, ...rest]));
  }

  void _checkWritable(SandboxPath path, SandboxAccess access) {
    final verb = access == SandboxAccess.delete ? 'deleted' : 'written';
    if (path.isRoot) throw SandboxViolation('The project root cannot be $verb.');
    final rel = _caseInsensitive ? path.relative.toLowerCase() : path.relative;
    final first = rel.split('/').first;
    final reason = switch (first) {
      '.lumina' => 'editor state — trash, snapshots, layout (fs_history / fs_restore read the snapshots)',
      'build' => 'build output, rewritten by every build',
      '.dart_tool' => 'package resolution (.dart_tool/), owned by `flutter pub get`',
      '.git' => 'the Git repository (.git/); use the source control tools',
      'contents' => 'assets: use import_asset / create_asset / delete_asset',
      _ => null,
    };
    String? fileReason;
    if (reason == null) {
      if (rel.endsWith('.lmproject')) {
        fileReason = 'project settings: use the settings tools (the editor holds the parsed .lmproject)';
      } else if (rel.endsWith('.lmas')) {
        fileReason = 'a .lmas asset: use the asset, Blueprint and material tools';
      } else if (p.posix.basename(rel) == 'pubspec.lock') {
        fileReason = 'pubspec.lock is written by `flutter pub get`';
      } else {
        final file = File(path.absolute);
        if (file.existsSync() && isBinaryFile(file)) {
          fileReason = 'a binary file (${file.lengthSync()} bytes); the file tools edit text only';
        }
      }
    }
    final why = reason ?? fileReason;
    if (why != null) throw SandboxViolation('${path.relative} cannot be $verb: $why.');
  }

  /// Whether [file] holds a NUL byte in its first 8 KiB.
  bool isBinaryFile(File file) {
    RandomAccessFile? raf;
    try {
      raf = file.openSync();
      final head = raf.readSync(8192);
      return head.contains(0);
    } on FileSystemException {
      return false;
    } finally {
      raf?.closeSync();
    }
  }

  /// Refuses [bytes] that are not UTF-8 text without NUL bytes.
  static void checkContent(List<int> bytes) {
    if (bytes.contains(0)) throw const SandboxViolation('binary content: the text contains a NUL byte; the file tools write text only.');
    try {
      utf8.decode(bytes);
    } on FormatException {
      throw const SandboxViolation('binary content: the bytes are not valid UTF-8; the file tools write text only.');
    }
  }

  /// The tool that regenerates [relative] (a file the editor writes), or
  /// null for a hand-written file.
  static String? generatedBy(String relative) {
    final r = relative.replaceAll(r'\', '/');
    if (r == 'lib/main.dart') return 'run_codegen / save_level';
    if (RegExp(r'^lib/levels/[^/]+\.dart$').hasMatch(r)) return 'run_codegen / save_level';
    if (r.startsWith('lib/actors/')) return 'compile_blueprint';
    if (r.startsWith('lib/widgets/')) return 'compile_blueprint (Widget Blueprints)';
    if (r.startsWith('lib/anim/')) return 'compile_blueprint (Animation Blueprints)';
    if (r.startsWith('lib/input/')) return 'the input settings (save_level / compile_blueprint)';
    if (r.startsWith('lib/blueprint/')) return 'the Blueprint function scanner (on every lib/ change)';
    if (r.endsWith('.g.dart')) return 'the code generator';
    return null;
  }
}

/// A glob over `/`-separated relative paths: `*` (not `/`),
/// `**` (anything; `**/` also matches no directory), `?`, `{a,b}` and
/// `[...]` / `[!...]` classes. Kept in this file so `package:glob` stays a
/// transitive dependency.
class SandboxGlob {
  SandboxGlob(this.pattern) : _re = RegExp('^${_translate(pattern)}\$');

  final String pattern;
  final RegExp _re;

  bool matches(String path) => _re.hasMatch(path);

  static String _translate(String glob) {
    final b = StringBuffer();
    var braces = 0;
    for (var i = 0; i < glob.length; i++) {
      final c = glob[i];
      switch (c) {
        case '*':
          if (i + 1 < glob.length && glob[i + 1] == '*') {
            if (i + 2 < glob.length && glob[i + 2] == '/') {
              b.write('(?:.*/)?');
              i += 2;
            } else {
              b.write('.*');
              i += 1;
            }
          } else {
            b.write('[^/]*');
          }
        case '?':
          b.write('[^/]');
        case '{':
          braces++;
          b.write('(?:');
        case '}' when braces > 0:
          braces--;
          b.write(')');
        case ',' when braces > 0:
          b.write('|');
        case '[':
          final end = glob.indexOf(']', i + 2);
          if (end < 0) {
            b.write(r'\[');
          } else {
            var body = glob.substring(i + 1, end);
            if (body.startsWith('!')) body = '^${body.substring(1)}';
            b.write('[${body.replaceAll(r'\', r'\\')}]');
            i = end;
          }
        default:
          b.write(RegExp.escape(c));
      }
    }
    return b.toString();
  }
}

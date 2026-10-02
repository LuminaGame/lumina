import 'dart:io';

import 'package:path/path.dart' as p;

/// Starts a process that shows a path in the platform file manager. The
/// default starts it detached; tests swap [FileReveal.runner] to record the
/// call instead of opening a window.
typedef FileRevealRunner = Future<void> Function(String executable, List<String> arguments);

/// The command line that shows one path in the platform file manager.
class FileRevealCommand {
  const FileRevealCommand(this.executable, this.arguments);

  final String executable;
  final List<String> arguments;

  @override
  bool operator ==(Object other) =>
      other is FileRevealCommand &&
      other.executable == executable &&
      other.arguments.length == arguments.length &&
      Iterable<int>.generate(arguments.length).every((i) => other.arguments[i] == arguments[i]);

  @override
  int get hashCode => Object.hash(executable, Object.hashAll(arguments));

  @override
  String toString() => '$executable ${arguments.join(' ')}';
}

/// "Show in Explorer" / "Reveal in Finder" / "Show in File Manager": opens
/// the platform file manager at a file (selected) or a folder (opened).
///
/// - Windows: `explorer.exe /select, <file>` selects a file in its folder;
///   `explorer.exe <folder>` opens a folder.
/// - macOS: `open -R <file>` reveals a file in Finder; `open <folder>` opens
///   a folder.
/// - Linux and others: `xdg-open <folder>`, the file's own folder for a file
///   (the freedesktop opener has no "select" form).
abstract final class FileReveal {
  /// Runs the command. Replaced in tests.
  static FileRevealRunner runner = _startDetached;

  /// The menu label for this platform; [subject] names what is revealed
  /// (`Asset` gives "Show Asset in Explorer").
  static String menuLabel({String? subject, String? os}) {
    final what = subject == null ? '' : '$subject ';
    switch (os ?? Platform.operatingSystem) {
      case 'windows':
        return 'Show ${what}in Explorer';
      case 'macos':
        return 'Reveal ${what}in Finder';
      default:
        return 'Show ${what}in File Manager';
    }
  }

  /// The command that shows [path] on [os] (`Platform.operatingSystem`
  /// values). [isDirectory] picks "open the folder" over "select the file".
  static FileRevealCommand commandFor(String path, {required bool isDirectory, String? os}) {
    switch (os ?? Platform.operatingSystem) {
      case 'windows':
        // Explorer only understands backslashes. `/select,` and the path are
        // two arguments: Dart quotes an argument with spaces as a whole, and
        // Explorer does not parse a quoted `"/select,C:\a b\c"`, while
        // `/select, "C:\a b\c"` works.
        final win = path.replaceAll('/', r'\');
        return isDirectory
            ? FileRevealCommand('explorer.exe', [win])
            : FileRevealCommand('explorer.exe', ['/select,', win]);
      case 'macos':
        return isDirectory ? FileRevealCommand('open', [path]) : FileRevealCommand('open', ['-R', path]);
      default:
        return FileRevealCommand('xdg-open', [isDirectory ? path : p.dirname(path)]);
    }
  }

  /// [path] as an absolute path: a project-relative path
  /// (`contents/props/barrels`) is resolved against [projectDir]; an
  /// absolute one (a plugin's content folder, an actor's mesh file) is kept.
  static String resolve(String projectDir, String path) {
    final normalized = path.replaceAll(r'\', '/');
    if (p.isAbsolute(normalized) || p.isAbsolute(path)) return p.normalize(path);
    return p.normalize(p.join(projectDir, normalized));
  }

  /// Shows [path] (absolute) in the file manager. Returns false when it does
  /// not exist on disk or the file manager could not be started.
  static Future<bool> reveal(String path, {String? os}) async {
    final type = FileSystemEntity.typeSync(path);
    if (type == FileSystemEntityType.notFound) return false;
    final command = commandFor(path, isDirectory: type == FileSystemEntityType.directory, os: os);
    try {
      await runner(command.executable, command.arguments);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _startDetached(String executable, List<String> arguments) async {
    await Process.start(executable, arguments, mode: ProcessStartMode.detached);
  }
}

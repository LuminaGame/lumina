import 'dart:io';

import 'package:path/path.dart' as p;

/// Directory links that need no special rights: a directory junction on
/// Windows (`mklink /J`; `Link.create` makes a symbolic link there, which
/// needs Developer Mode or admin rights), a symbolic link elsewhere. `Link`
/// reads and deletes both.
abstract final class DirectoryLink {
  /// Links [path] to the directory [target] (both made absolute).
  static void createSync(String path, String target) {
    final from = p.normalize(p.absolute(path));
    final to = p.normalize(p.absolute(target));
    if (!Platform.isWindows) {
      Link(from).createSync(to);
      return;
    }
    final cmd = p.join(Platform.environment['SystemRoot'] ?? r'C:\Windows', 'System32', 'cmd.exe');
    final r = Process.runSync(cmd, ['/c', 'mklink', '/J', from, to]);
    if (r.exitCode != 0) {
      throw FileSystemException('Could not link to $to: ${'${r.stderr}'.trim()} ${'${r.stdout}'.trim()}'.trim(), from);
    }
  }
}

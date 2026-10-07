import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

/// Where `flutter pub get` / `flutter build` run for a folder on Windows: a
/// junction to it under a space-free root, so the native-assets hooks never
/// see a path with a space.
///
/// native_toolchain_c runs `cl.exe` through `cmd.exe`, and `cl.exe` lives
/// under "C:\Program Files", so one more quoted argument (an output dir,
/// include or library under "…\Lumina Projects\…") breaks cmd's quoting
/// ("'C:\Program' is not recognized"). The alias also keeps every path short.
/// The files stay where they are; only the path the build sees changes.
abstract final class SpaceFreeBuildDir {
  /// The build folder for [dir]: [dir] itself off Windows (or when
  /// [platform] is not `windows`), else a stable junction to it under
  /// [aliasRoot] (default [defaultAliasRoot]), one per folder. A path at the
  /// alias that is not a link is never touched: [dir] is used as it is.
  static String of(String dir, {Directory? aliasRoot, String? platform}) {
    if ((platform ?? Platform.operatingSystem) != 'windows' || !Platform.isWindows) return dir;
    final target = p.normalize(p.absolute(dir));
    final root = aliasRoot?.path ?? defaultAliasRoot();
    final id = sha1.convert(utf8.encode(target.toLowerCase())).toString().substring(0, 10);
    final alias = p.join(root, id);
    final link = Link(alias);
    final type = FileSystemEntity.typeSync(alias, followLinks: false);
    if (type == FileSystemEntityType.link) {
      if (p.equals(p.normalize(link.targetSync()), target)) return alias;
      link.deleteSync();
    } else if (type != FileSystemEntityType.notFound) {
      return dir;
    }
    Directory(root).createSync(recursive: true);
    // Aliases of folders that were deleted or moved.
    for (final stale in Directory(root).listSync(followLinks: false).whereType<Link>()) {
      try {
        if (!Directory(stale.targetSync()).existsSync()) stale.deleteSync();
      } on FileSystemException {
        // Another launcher's; left for it.
      }
    }
    link.createSync(target);
    return alias;
  }

  /// `%LOCALAPPDATA%\lumina\hosts`, or `<SystemDrive>\lumina-hosts` when
  /// `%LOCALAPPDATA%` itself has a space (a user name with a space).
  static String defaultAliasRoot() {
    final local = Platform.environment['LOCALAPPDATA'];
    if (local != null && !local.contains(' ')) return p.join(local, 'lumina', 'hosts');
    return p.join('${Platform.environment['SystemDrive'] ?? 'C:'}\\', 'lumina-hosts');
  }
}

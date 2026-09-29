import 'dart:io';

/// Installs a folder transactionally: a previous install at the destination
/// is set aside (renamed beside it, on the same file system) until the new
/// one is written, then dropped; if writing fails, the new files are removed
/// and the previous install is put back. The Marketplace installer and the
/// Plugin Manager's folder / zip import write into the user plugin directory
/// through it.
abstract final class FolderInstall {
  /// Writes [dest] with [write], replacing what was there. [tag] names the
  /// set-aside folder (`.<name>.<tag>`), so an interrupted install is
  /// recognisable.
  static T replace<T>(Directory dest, T Function() write, {String tag = 'previous'}) {
    final aside = moveAside(dest, tag: tag);
    try {
      final result = write();
      dropAside(aside);
      return result;
    } catch (_) {
      restore(dest, aside);
      rethrow;
    }
  }

  /// Renames an existing [dest] to `.<name>.<tag>` beside it and returns the
  /// renamed folder; null when [dest] does not exist.
  static Directory? moveAside(Directory dest, {String tag = 'previous'}) {
    if (!dest.existsSync()) return null;
    final name = dest.uri.pathSegments.where((s) => s.isNotEmpty).last;
    final aside = Directory('${dest.parent.path}/.$name.$tag');
    if (aside.existsSync()) aside.deleteSync(recursive: true);
    return dest.renameSync(aside.path);
  }

  /// Deletes a folder [moveAside] set aside, once the new install is in.
  static void dropAside(Directory? aside) {
    try {
      aside?.deleteSync(recursive: true);
    } catch (_) {}
  }

  /// Removes a half-written [dest] and puts [aside] back in its place.
  static void restore(Directory dest, Directory? aside) {
    try {
      if (dest.existsSync()) dest.deleteSync(recursive: true);
      aside?.renameSync(dest.path);
    } catch (_) {}
  }

  /// Copies every file under [from] to the same relative path under [to].
  static void copyTree(Directory from, Directory to) {
    to.createSync(recursive: true);
    for (final f in from.listSync(recursive: true).whereType<File>()) {
      final out = File('${to.path}/${f.path.substring(from.path.length + 1)}');
      out.parent.createSync(recursive: true);
      f.copySync(out.path);
    }
  }

  /// Copies [files] (`/`-separated relative path → source file) under [to].
  static void copyFiles(Map<String, File> files, Directory to) {
    to.createSync(recursive: true);
    for (final MapEntry(key: rel, value: source) in files.entries) {
      final out = File('${to.path}/$rel');
      out.parent.createSync(recursive: true);
      source.copySync(out.path);
    }
  }
}

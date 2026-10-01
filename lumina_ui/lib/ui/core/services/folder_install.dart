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

  /// Removes the folder [dir] without ever leaving half of it in place:
  ///
  /// * a symbolic link or a Windows junction is deleted as a link; it is
  ///   never followed, so the folder it points to keeps every file;
  /// * a folder is first renamed to `.<name>.<tag>` beside it (a plugin scan
  ///   root skips dot folders) and only then deleted. When the rename fails
  ///   (on Windows, a file inside is open, e.g. a loaded DLL), nothing was
  ///   removed and [FolderRemoval.removed] is false. When some files of the
  ///   renamed folder cannot be deleted, the folder is gone from its place
  ///   and [FolderRemoval.leftovers] lists what is left in the set-aside
  ///   folder.
  ///
  /// A [dir] that does not exist counts as removed.
  static FolderRemoval remove(Directory dir, {String tag = 'removing'}) {
    final path = dir.path;
    final type = FileSystemEntity.typeSync(path, followLinks: false);
    if (type == FileSystemEntityType.notFound) return FolderRemoval(path: path, removed: true);
    if (type == FileSystemEntityType.link) {
      try {
        Link(path).deleteSync();
        return FolderRemoval(path: path, removed: true, link: true);
      } on FileSystemException catch (e) {
        return FolderRemoval(path: path, removed: false, link: true, error: describe(e));
      }
    }
    if (type != FileSystemEntityType.directory) {
      return FolderRemoval(path: path, removed: false, error: '$path is not a folder.');
    }
    final Directory? aside;
    try {
      aside = moveAside(dir, tag: tag);
    } on FileSystemException catch (e) {
      return FolderRemoval(path: path, removed: false, error: describe(e));
    }
    if (aside == null) return FolderRemoval(path: path, removed: true);
    try {
      aside.deleteSync(recursive: true);
      return FolderRemoval(path: path, removed: true);
    } on FileSystemException catch (e) {
      final left = <String>[];
      try {
        if (aside.existsSync()) {
          for (final f in aside.listSync(recursive: true, followLinks: false)) {
            if (f is! Directory) left.add(f.path);
          }
        }
      } on FileSystemException catch (_) {}
      return FolderRemoval(path: path, removed: true, leftovers: left, asidePath: aside.path, error: describe(e));
    }
  }

  /// A file-system error in one line: the OS message, then the path.
  static String describe(FileSystemException e) {
    final os = e.osError?.message.trim();
    final what = os == null || os.isEmpty ? e.message : os;
    return e.path == null ? what : '$what (${e.path})';
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

/// What [FolderInstall.remove] did.
class FolderRemoval {
  const FolderRemoval({
    required this.path,
    required this.removed,
    this.link = false,
    this.leftovers = const [],
    this.asidePath,
    this.error,
  });

  /// The folder (or link) that was to be removed.
  final String path;

  /// Nothing is left at [path] (it may have leftovers set aside).
  final bool removed;

  /// [path] was a symbolic link or a junction; only the link was deleted.
  final bool link;

  /// Files that could not be deleted once the folder was set aside, under
  /// [asidePath].
  final List<String> leftovers;

  /// The set-aside folder holding [leftovers].
  final String? asidePath;

  /// Why the removal stopped (null when it went through).
  final String? error;

  /// Removed with nothing left behind.
  bool get complete => removed && leftovers.isEmpty && error == null;
}

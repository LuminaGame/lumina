import 'dart:io';

/// Content folders on disk: the standard folders a
/// new project arrives with, and the keep-marker that lets an empty folder
/// survive git and project copies.
///
/// The content browser never lists the marker: assets are `.lmas` files only.
class ContentFolders {
  const ContentFolders._();

  /// Marker that keeps an otherwise empty content folder in version control.
  static const String markerFileName = '.lumina_folder';

  /// Folders every new project gets beyond the ones its template's assets
  /// already live in: Widget Blueprints go to `contents/widgets/`, Input
  /// Actions and Mapping Contexts to `contents/input/`.
  static const List<String> projectFolders = ['contents/widgets', 'contents/input'];

  /// Creates [projectFolders] (with markers) under [projectDir]; existing
  /// folders and their files are left alone. Returns the folders it created.
  static List<String> ensureProjectFolders(String projectDir) {
    final created = <String>[];
    for (final folder in projectFolders) {
      final dir = Directory('$projectDir/$folder');
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
        created.add(folder);
      }
      writeMarker(dir.path);
    }
    return created;
  }

  /// Writes the keep-marker into [dirPath] unless it is already there.
  static void writeMarker(String dirPath) {
    final marker = File('$dirPath/$markerFileName');
    if (!marker.existsSync()) {
      marker.writeAsStringSync('Lumina content folder: kept in version control while empty.\n');
    }
  }

  /// The folder an asset at [relativePath] sits in (`contents/a/b.lmas` →
  /// `contents/a`), with separators normalised to `/`.
  static String parentOf(String relativePath) {
    final p = relativePath.replaceAll(r'\', '/');
    final i = p.lastIndexOf('/');
    return i < 0 ? '' : p.substring(0, i);
  }
}

import 'dart:io';

/// The hook dependencies that make fetching (or deleting) the NGX SDK under
/// [sdkDir] re-run the build once, given the [markers] whose presence
/// switches the DLSS path on.
///
/// The hooks runner records a hash per dependency and re-runs the hook when
/// one changes, but it treats a missing *file* as modified just now: its
/// timestamp is "now", later than the build's start, so it is stored with the
/// "modified during build" hash ("File modified during build. Build must be
/// rerun.") and the next build re-runs the hook again, every time. A
/// *directory* dependency (a URI ending in `/`) is hashed by the names of its
/// direct children and dated by the newest file below it, so an existing
/// directory is a stable dependency that still changes when an entry appears
/// or disappears (a missing one cannot be dated at all).
///
/// So every returned path exists: a present marker is a file dependency (its
/// content), a missing one is replaced by its deepest existing ancestor
/// directory up to [sdkDir], which is created empty when it is missing. When
/// the SDK lands, the name the marker path needs next appears in that
/// directory; when it goes, the file dependency hashes as absent.
/// Empty when [sdkDir] cannot be created (a read-only package root): the
/// build then does not follow later SDK changes.
List<Uri> dlssSdkDependencies(String sdkDir, List<String> markers) {
  if (markers.isEmpty) return const [];
  final root = Directory(sdkDir);
  try {
    root.createSync(recursive: true);
  } on FileSystemException {
    return const [];
  }
  final rootPath = root.absolute.path;
  final dependencies = <Uri>{};
  for (final marker in markers) {
    final file = File(marker);
    if (file.existsSync()) {
      dependencies.add(file.absolute.uri);
      continue;
    }
    var dir = file.absolute.parent;
    while (!dir.existsSync() && dir.path.length > rootPath.length) {
      dir = dir.parent;
    }
    dependencies.add(Uri.directory(dir.existsSync() ? dir.path : rootPath));
  }
  return dependencies.toList();
}

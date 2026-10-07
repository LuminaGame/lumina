import 'dart:io';

import 'package:archive/archive.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina_marketplace_shared/lumina_marketplace_shared.dart'
    show PluginPackageProblem, PluginPackageProblemCode, checkPluginPackage, isSafeRelativePath, singleTopFolder;
import 'package:path/path.dart' as p;

import 'package:lumina_ui/ui/core/services/folder_install.dart';
import 'package:lumina_ui/ui/core/services/user_plugin_dir.dart';

/// Where an imported plugin comes from.
enum PluginImportSource { folder, zip }

/// What an import did.
enum PluginImportStatus {
  /// Validated and ready for [PluginImporter.install]; nothing written yet.
  ready,

  /// Copied into the user plugin directory.
  installed,

  /// The user plugin directory already has a plugin of that name; nothing
  /// was written. [PluginImporter.install] with `replace: true` replaces it.
  alreadyInstalled,

  /// A project plugin has that name; nothing was written.
  conflict,

  /// The folder or archive is not a valid plugin package; nothing was written.
  invalid,

  /// Writing failed; a previous install was put back.
  failed,
}

/// A validated plugin, ready to be copied: its files (`/`-separated path
/// relative to the plugin root → source file) and what the checks found.
class PluginImportCandidate {
  PluginImportCandidate._({
    required this.source,
    required this.sourcePath,
    required this.name,
    required this.version,
    required this.friendlyName,
    required this.files,
    required this.warnings,
    this.stagingDir,
  });

  final PluginImportSource source;

  /// The folder or zip the user picked.
  final String sourcePath;
  final String name;
  final String version;
  final String? friendlyName;
  final Map<String, File> files;

  /// Findings that do not stop an import (a folder's license or changelog,
  /// symbolic links left out of a folder copy).
  final List<String> warnings;

  /// The zip's extraction folder under the staging root; null for a folder.
  final Directory? stagingDir;

  String get displayName => friendlyName ?? name;
}

/// The outcome of an import step.
class PluginImportResult {
  const PluginImportResult._(this.status, {this.candidate, this.installedDir, this.existingDir, this.messages = const [], this.warnings = const []});

  final PluginImportStatus status;

  /// The validated plugin (null when validation refused it).
  final PluginImportCandidate? candidate;

  /// `<user plugin dir>/<name>` after an install.
  final Directory? installedDir;

  /// The plugin already installed under that name (already installed, or a
  /// conflicting project or built-in plugin).
  final Directory? existingDir;

  /// Why the import stopped, one line per problem.
  final List<String> messages;
  final List<String> warnings;
}

/// Installs a plugin into the user plugin directory from a plugin folder or
/// from a plugin package zip (the marketplace plugin package format that
/// `tool/pack_plugin.dart` writes). The plugin is validated first and
/// **copied** (a plugin is a Dart package that a project's editor host
/// compiles from its folder; it is never linked from elsewhere):
///
/// * the manifest by the marketplace's rules (`checkPluginPackage`) and by
///   the editor's own loader (`PluginRepository.loadInternal`);
/// * a zip's every entry: a safe relative path (`isSafeRelativePath`), no
///   symbolic links, the marketplace's file allow-list, no duplicates, an
///   entry-count and unpacked-size cap; its single top folder, when it has
///   one, is named after the plugin;
/// * a folder is copied without generated folders (`.dart_tool/`, `.git/`,
///   `build/`, …) and local overrides, as `pack_plugin.dart` leaves them out.
///
/// The copy goes through [FolderInstall], like the Marketplace installer.
class PluginImporter {
  PluginImporter({Directory? userPluginDir, Directory? stagingRoot, this.existing = const []})
      : userPluginDir = userPluginDir ?? UserPluginDir.resolve(),
        stagingRoot = stagingRoot ?? Directory.systemTemp;

  final Directory userPluginDir;

  /// Where a zip is extracted before it is copied (a temp folder per import,
  /// removed afterwards).
  final Directory stagingRoot;

  /// The plugins the editor knows (every scan root), for name conflicts.
  final List<LuminaPluginDescriptor> existing;

  /// The most entries a plugin zip may hold.
  static const int maxEntries = 10000;

  /// The most bytes a plugin zip may unpack to.
  static const int maxUnpackedBytes = 1024 * 1024 * 1024;

  /// Folder names a copy leaves out wherever they are.
  static const Set<String> excludedFolders = {'.dart_tool', '.git', '.idea', '.vscode', 'node_modules', '.svn', '.hg'};

  /// Folder names a copy leaves out at the plugin root.
  static const Set<String> excludedRootFolders = {'build', 'coverage'};

  /// File names (lower case) a folder copy leaves out.
  static const Set<String> excludedFiles = {
    'pubspec_overrides.yaml', '.packages', '.flutter-plugins', '.flutter-plugins-dependencies', //
    '.ds_store', 'thumbs.db', 'desktop.ini',
  };

  // What the marketplace accepts in a plugin upload (its server's
  // ZipValidator, and pack_plugin.dart's copy); keep in step with it.
  static const Set<String> _allowedExtensions = {
    'glb', 'gltf', 'bin', 'obj', 'mtl', 'fbx', 'dae', 'lmas', 'filamesh', //
    'png', 'jpg', 'jpeg', 'tga', 'webp', 'ktx', 'ktx2', 'hdr', 'exr', 'svg',
    'wav', 'ogg', 'mp3', 'flac', 'ttf', 'otf',
    'dart', 'c', 'cc', 'cpp', 'h', 'hpp', 'js', 'glsl', 'vert', 'frag', 'comp', 'mat',
    'json', 'yaml', 'yml', 'md', 'txt', 'lmproject', 'lmplugin', 'csv', 'lock',
  };
  static const Set<String> _allowedBareNames = {'license', 'licence', 'readme', 'notice', 'changelog', 'copying', 'authors'};
  static const Set<String> _allowedDotNames = {'.gitignore', '.gitattributes', '.metadata', '.pubignore'};

  /// Manifest problems that refuse a folder too; the license and changelog
  /// findings only warn there (a plugin under development may have neither).
  static const Set<String> _folderFatal = {
    PluginPackageProblemCode.noManifest,
    PluginPackageProblemCode.multipleManifests,
    PluginPackageProblemCode.manifestInvalid,
    PluginPackageProblemCode.nameInvalid,
    PluginPackageProblemCode.nameMismatch,
    PluginPackageProblemCode.engineVersionInvalid,
  };

  /// Validates the plugin folder at [path] and installs it (see [install]).
  Future<PluginImportResult> importFolder(String path) async {
    final checked = await inspectFolder(path);
    return checked.candidate == null ? checked : install(checked.candidate!);
  }

  /// Validates the plugin zip at [path] and installs it (see [install]).
  Future<PluginImportResult> importZip(String path) async {
    final checked = await inspectZip(path);
    return checked.candidate == null ? checked : install(checked.candidate!);
  }

  /// Validates a plugin folder. The result carries the candidate, or
  /// [PluginImportStatus.invalid] with every problem.
  Future<PluginImportResult> inspectFolder(String path) async {
    final root = Directory(path).absolute;
    if (!root.existsSync()) return _invalid(['$path is not a folder.']);
    final files = <String, File>{};
    final warnings = <String>[];
    void walk(Directory dir, String rel) {
      final entries = dir.listSync(followLinks: false)..sort((a, b) => a.path.compareTo(b.path));
      for (final e in entries) {
        final name = p.basename(e.path);
        final childRel = rel.isEmpty ? name : '$rel/$name';
        if (e is Link) {
          warnings.add('$childRel is a symbolic link and was left out.');
        } else if (e is Directory) {
          if (excludedFolders.contains(name) || (rel.isEmpty && excludedRootFolders.contains(name))) continue;
          walk(e, childRel);
        } else if (e is File) {
          if (excludedFiles.contains(name.toLowerCase())) continue;
          files[childRel] = e;
        }
      }
    }

    try {
      walk(root, '');
    } on FileSystemException catch (e) {
      return _invalid(['$path cannot be read: ${e.message}']);
    }
    if (files.isEmpty) return _invalid(['$path is empty.']);

    final check = checkPluginPackage(files.keys, read: (rel) => _readSmall(files[rel]));
    final problems = <String>[];
    for (final problem in check.problems) {
      (_folderFatal.contains(problem.code) ? problems : warnings).add(_describe(problem));
    }
    if (problems.isNotEmpty) return _invalid(problems);
    final manifestRel = files.keys.firstWhere((k) => !k.contains('/') && k.toLowerCase().endsWith('.lmplugin'));
    final loaded = await _loadManifest(files[manifestRel]!);
    if (loaded.$2 != null) return _invalid([loaded.$2!]);
    final descriptor = loaded.$1!;
    return _checked(PluginImportCandidate._(
      source: PluginImportSource.folder,
      sourcePath: root.path,
      name: descriptor.name,
      version: descriptor.version.toString(),
      friendlyName: descriptor.friendlyName,
      files: files,
      warnings: warnings,
    ));
  }

  /// Validates a plugin zip and extracts it into a staging folder. The
  /// result carries the candidate, or [PluginImportStatus.invalid] with every
  /// problem (nothing is left in the staging root then).
  Future<PluginImportResult> inspectZip(String path) async {
    final file = File(path);
    if (!file.existsSync()) return _invalid(['$path does not exist.']);
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(file.readAsBytesSync(), verify: true);
    } catch (_) {
      return _invalid(['${p.basename(path)} is not a valid zip archive.']);
    }
    if (archive.isEmpty) return _invalid(['${p.basename(path)} is not a valid zip archive, or it holds no files.']);
    if (archive.length > maxEntries) return _invalid(['${p.basename(path)} has more than $maxEntries entries.']);
    var declared = 0;
    for (final entry in archive) {
      declared += entry.size;
      if (declared > maxUnpackedBytes) return _invalid(['${p.basename(path)} unpacks to more than $maxUnpackedBytes bytes.']);
    }

    final problems = <String>[];
    final safe = <(ArchiveFile, String)>[];
    for (final entry in archive) {
      final name = entry.name;
      final rel = entry.isDirectory && name.endsWith('/') ? name.substring(0, name.length - 1) : name;
      if (!isSafeRelativePath(rel)) {
        problems.add('The archive path "$name" is not safe (a relative path without "..", a drive or a backslash).');
      } else if (entry.isSymbolicLink) {
        problems.add('"$name" is a symbolic link; a plugin package holds regular files only.');
      } else if (!entry.isDirectory) {
        safe.add((entry, rel));
      }
    }
    if (problems.isNotEmpty) return _invalid(problems);

    final packageTop = singleTopFolder([for (final (_, rel) in safe) rel]);
    final entries = <String, ArchiveFile>{};
    final seen = <String>{};
    for (final (entry, rel) in safe) {
      if (_generatedFolderOf(rel, packageTop) != null) continue;
      final disallowed = _disallowed(rel);
      if (disallowed != null) {
        problems.add('$disallowed: $rel');
        continue;
      }
      if (!seen.add(rel.toLowerCase())) {
        problems.add('"$rel" is in the archive twice.');
        continue;
      }
      entries[rel] = entry;
    }
    if (problems.isNotEmpty) return _invalid(problems);
    if (entries.isEmpty) return _invalid(['${p.basename(path)} holds no files.']);

    final check = checkPluginPackage(entries.keys, read: (rel) => entries[rel]?.readBytes());
    if (!check.isValid) return _invalid([for (final pr in check.problems) _describe(pr)]);
    final top = singleTopFolder(entries.keys);
    final prefix = top == null ? '' : '$top/';

    final staging = stagingRoot.createTempSync('lm_plugin_');
    try {
      final files = <String, File>{};
      var unpacked = 0;
      for (final MapEntry(key: rel, value: entry) in entries.entries) {
        final bytes = entry.readBytes();
        if (bytes == null) throw _Refused('"$rel" is unreadable.');
        unpacked += bytes.length;
        if (unpacked > maxUnpackedBytes) throw _Refused('${p.basename(path)} unpacks to more than $maxUnpackedBytes bytes.');
        final inPlugin = rel.substring(prefix.length);
        final out = File(p.joinAll([staging.path, ...inPlugin.split('/')]));
        // isSafeRelativePath already refused anything that could leave the
        // staging folder; this keeps that true whatever the path library does.
        if (!p.isWithin(staging.path, out.path)) throw _Refused('The archive path "$rel" is not safe.');
        out.parent.createSync(recursive: true);
        out.writeAsBytesSync(bytes);
        files[inPlugin] = out;
      }
      final manifestRel = files.keys.firstWhere((k) => !k.contains('/') && k.toLowerCase().endsWith('.lmplugin'));
      final loaded = await _loadManifest(files[manifestRel]!);
      if (loaded.$2 != null) throw _Refused(loaded.$2!);
      final descriptor = loaded.$1!;
      return _checked(PluginImportCandidate._(
        source: PluginImportSource.zip,
        sourcePath: file.absolute.path,
        name: descriptor.name,
        version: descriptor.version.toString(),
        friendlyName: descriptor.friendlyName,
        files: files,
        warnings: const [],
        stagingDir: staging,
      ));
    } on _Refused catch (e) {
      _deleteQuietly(staging);
      return _invalid([e.message]);
    } catch (e) {
      _deleteQuietly(staging);
      return _invalid(['${p.basename(path)} could not be unpacked: $e']);
    }
  }

  /// Copies [candidate] into `<user plugin dir>/<name>/`. A plugin of that
  /// name already there is [PluginImportStatus.alreadyInstalled] unless
  /// [replace]; a project plugin of that name is a
  /// [PluginImportStatus.conflict] (see [_conflictFor]). The candidate's staging folder is removed
  /// once the import is final (installed, refused or failed); an
  /// already-installed result keeps it for the replace, or [discard].
  Future<PluginImportResult> install(PluginImportCandidate candidate, {bool replace = false}) async {
    final dest = Directory(p.join(userPluginDir.path, candidate.name));
    final conflict = _conflictFor(candidate, dest);
    if (conflict != null) {
      discardCandidate(candidate);
      return conflict;
    }
    final warnings = [...candidate.warnings, ..._builtInWarnings(candidate)];
    if (dest.existsSync() && !replace) {
      return PluginImportResult._(PluginImportStatus.alreadyInstalled,
          candidate: candidate,
          existingDir: dest,
          warnings: warnings,
          messages: ['${candidate.displayName} is already installed in ${dest.path}.']);
    }
    if (candidate.source == PluginImportSource.folder && p.equals(p.normalize(candidate.sourcePath), p.normalize(dest.absolute.path))) {
      return PluginImportResult._(PluginImportStatus.conflict,
          candidate: candidate, existingDir: dest, messages: ['${candidate.sourcePath} is the installed copy itself.']);
    }
    try {
      userPluginDir.createSync(recursive: true);
      FolderInstall.replace(dest, () => FolderInstall.copyFiles(candidate.files, dest), tag: 'import-previous');
      return PluginImportResult._(PluginImportStatus.installed, candidate: candidate, installedDir: dest, warnings: warnings);
    } catch (e) {
      return PluginImportResult._(PluginImportStatus.failed,
          candidate: candidate,
          existingDir: dest.existsSync() ? dest : null,
          messages: ['Installing ${candidate.displayName} into ${dest.path} failed: $e'],
          warnings: warnings);
    } finally {
      discardCandidate(candidate);
    }
  }

  /// Drops what an unfinished import staged (Cancel on "already installed").
  void discard(PluginImportResult result) {
    final c = result.candidate;
    if (c != null) discardCandidate(c);
  }

  static void discardCandidate(PluginImportCandidate candidate) {
    final staging = candidate.stagingDir;
    if (staging != null) _deleteQuietly(staging);
  }

  /// A project plugin of the same name refuses the import: the project's
  /// copy would hide the user one. A built-in of the same name does not: the
  /// user copy takes its place (the user root is scanned before the
  /// built-ins), which is how a newer version of a built-in is installed; the
  /// result warns about it.
  PluginImportResult? _conflictFor(PluginImportCandidate candidate, Directory dest) {
    for (final d in existing) {
      if (d.name != candidate.name || d.origin != PluginOrigin.project) continue;
      return PluginImportResult._(PluginImportStatus.conflict, candidate: candidate, existingDir: d.pluginDir, messages: [
        '${candidate.name} is already a project plugin (${d.pluginDir.path}), which would hide a user plugin of the '
            'same name; remove or rename one of them first.',
      ]);
    }
    return null;
  }

  List<String> _builtInWarnings(PluginImportCandidate candidate) => [
        for (final d in existing)
          if (d.name == candidate.name && d.origin == PluginOrigin.engine)
            '${candidate.name} is also a built-in plugin (${d.pluginDir.path}); the imported copy takes its place.',
      ];

  PluginImportResult _checked(PluginImportCandidate candidate) =>
      PluginImportResult._(PluginImportStatus.ready, candidate: candidate, warnings: candidate.warnings);

  static PluginImportResult _invalid(List<String> messages) => PluginImportResult._(PluginImportStatus.invalid, messages: messages);

  static String _describe(PluginPackageProblem problem) => problem.message;

  /// The editor's own manifest rules (module types, version, engine range).
  static Future<(LuminaPluginDescriptor?, String?)> _loadManifest(File manifest) async {
    try {
      return (await PluginRepository(roots: const []).loadInternal(manifest, PluginOrigin.user), null);
    } on PluginManifestException catch (e) {
      return (null, e.error.message);
    }
  }

  static List<int>? _readSmall(File? f) {
    if (f == null) return null;
    try {
      return f.readAsBytesSync();
    } on FileSystemException {
      return null;
    }
  }

  /// The generated folder [rel] lives in (`.dart_tool/`, `.git/`, `.idea/`,
  /// `.vscode/` anywhere, `build/` at the package root), as the marketplace
  /// leaves them out of a plugin upload; null otherwise.
  static String? _generatedFolderOf(String rel, String? top) {
    final prefix = top == null ? '' : '$top/';
    final segments = rel.substring(prefix.length).split('/');
    for (var i = 0; i < segments.length - 1; i++) {
      if (_generatedFolderNames.contains(segments[i]) || (i == 0 && segments[i] == 'build')) {
        return '$prefix${segments.take(i + 1).join('/')}/';
      }
    }
    return null;
  }

  static const Set<String> _generatedFolderNames = {'.dart_tool', '.git', '.idea', '.vscode'};

  /// Why [rel] is not allowed in a marketplace plugin package, or null.
  static String? _disallowed(String rel) {
    final name = rel.split('/').last;
    if (_allowedDotNames.contains(name.toLowerCase())) return null;
    final dot = name.lastIndexOf('.');
    if (dot <= 0) {
      return _allowedBareNames.contains(name.toLowerCase()) ? null : 'Files without an allowed extension are not allowed';
    }
    final ext = name.substring(dot + 1).toLowerCase();
    return _allowedExtensions.contains(ext) ? null : '.$ext files are not allowed';
  }

  static void _deleteQuietly(Directory dir) {
    try {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    } catch (_) {}
  }
}

class _Refused implements Exception {
  const _Refused(this.message);
  final String message;
}

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:lumina/lumina.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina_editor_data/src/services/derived_data_cache.dart';
import 'package:lumina_editor_data/src/services/thumbnail_sidecar_migration.dart';
import 'package:lumina_editor_data/src/services/base_eye_height_migration.dart';
import 'package:lumina_editor_data/src/services/code_generator_service.dart';
import 'package:lumina_editor_data/src/services/glb_parser_service.dart';
import 'package:lumina_editor_data/src/repositories/asset_repository.dart';

part 'project_repository/project_creation.dart';
part 'project_repository/project_creation_types.dart';


class ProjectRepository with _ProjectCreation {
  @override
  final EngineLoggerService _logger = EngineLoggerService();
  final Directory? configDir;

  
  @override
  final ProcessRunner processRunner;

  /// The lumina package the template content is read from; defaults to
  /// [luminaPackagePath], the same engine the new project's pubspec points at.
  @override
  final String? enginePackageDir;

  ProjectRepository({this.configDir, ProcessRunner? processRunner, this.enginePackageDir})
      : processRunner = processRunner ?? ((String exec, List<String> args, {String? workingDirectory, bool runInShell = false}) => Process.run(exec, args, workingDirectory: workingDirectory, runInShell: runInShell || Platform.isWindows));


  /// [configDir], else the editor's config directory ([LuminaConfigDir]).
  Directory get resolvedConfigDir => LuminaConfigDir.resolve(explicit: configDir);

  /// `recent_projects.json`, shared with every other editor process.
  ConfigJsonFile get _recentProjectsFile => ConfigJsonFile(File('${resolvedConfigDir.path}/recent_projects.json'));

  static List<RecentProjectEntry> _recentEntriesFrom(Object? json) => [
        if (json is List)
          for (final j in json) RecentProjectEntry.fromMap(Map<String, dynamic>.from(j as Map)),
      ];

  /// Changes the recent list under its lock and writes it back atomically.
  /// A list that does not parse is kept aside, never overwritten.
  void _updateRecentProjects(void Function(List<RecentProjectEntry> entries) change) {
    _recentProjectsFile.update(
      (current) {
        final entries = _recentEntriesFrom(current);
        change(entries);
        return [for (final e in entries) e.toMap()];
      },
      isValid: (value) => value is List,
      onUnreadable: (keptAside, error) => _logger.log(
        'recent_projects.json is not a readable list ($error); kept it as ${keptAside.path} and started a new one',
        level: 'error',
        source: 'ProjectRepository',
      ),
    );
  }

  Future<List<RecentProjectEntry>> getRecentProjects() async {
    try {
      return _recentEntriesFrom(_recentProjectsFile.read());
    } catch (e) {
      _logger.log('Failed to read recent projects: $e', level: 'error', source: 'ProjectRepository');
      return [];
    }
  }

  Future<List<LuminaProject>> getRecentProjectsFlat() async {
    final entries = await getRecentProjects();
    return entries.map((e) => e.project).toList();
  }

  @override
  Future<void> addRecentProject(
    LuminaProject project, {
    required String projectDir,
    String? coverImage,
  }) async {
    try {
      final normalizedPath = Directory(projectDir).absolute.path;
      _updateRecentProjects((currentList) {
        currentList.removeWhere((entry) => Directory(entry.projectDir).absolute.path == normalizedPath);
        currentList.insert(
          0,
          RecentProjectEntry(
            project: project,
            projectDir: normalizedPath,
            lastOpened: DateTime.now(),
            coverImage: coverImage,
            isMissing: false,
          ),
        );
      });
      _logger.log('Saved recent project "${project.projectName}" ($normalizedPath) to ${_recentProjectsFile.file.path}', level: 'info', source: 'ProjectRepository');
    } catch (e) {
      _logger.log('Failed to update recent projects: $e', level: 'error', source: 'ProjectRepository');
    }
  }

  Future<void> removeRecentProject(String projectDir) async {
    try {
      final normalizedPath = Directory(projectDir).absolute.path;
      _updateRecentProjects(
        (currentList) => currentList.removeWhere((entry) => Directory(entry.projectDir).absolute.path == normalizedPath),
      );
      _logger.log('Removed project at $normalizedPath from recent projects', level: 'info', source: 'ProjectRepository');
    } catch (e) {
      _logger.log('Failed to remove recent project: $e', level: 'error', source: 'ProjectRepository');
    }
  }

  Future<bool> validateProject(String projectDir) async {
    try {
      final dir = Directory(projectDir);
      if (!dir.existsSync()) return false;
      final manifestFiles = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.lmproject')).toList();
      if (manifestFiles.isEmpty) return false;
      for (final f in manifestFiles) {
        final content = f.readAsStringSync();
        if (content.trim().isNotEmpty) {
          final decoded = jsonDecode(content) as Map<String, dynamic>;
          if (decoded.containsKey('project_name')) {
            return true;
          }
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<LuminaProject?> locateProject({
    required String oldProjectDir,
    required String newLmprojectPath,
  }) async {
    try {
      final newFile = File(newLmprojectPath);
      if (!newFile.existsSync()) return null;
      final content = newFile.readAsStringSync();
      final jsonMap = jsonDecode(content) as Map<String, dynamic>;
      final project = LuminaProject.fromMap(jsonMap);

      final newProjectDir = newFile.parent.absolute.path;
      final oldNormalized = Directory(oldProjectDir).absolute.path;
      final updatedEntry = RecentProjectEntry(
        project: project,
        projectDir: newProjectDir,
        lastOpened: DateTime.now(),
        isMissing: false,
      );
      _updateRecentProjects((currentList) {
        final index = currentList.indexWhere((e) => Directory(e.projectDir).absolute.path == oldNormalized);
        if (index != -1) {
          currentList[index] = updatedEntry;
        } else {
          currentList.insert(0, updatedEntry);
        }
      });
      _logger.log('Repaired and relocated project "${project.projectName}" to $newProjectDir', level: 'success', source: 'ProjectRepository');
      return project;
    } catch (e) {
      _logger.log('Failed to locate project: $e', level: 'error', source: 'ProjectRepository');
      return null;
    }
  }

  Future<LuminaProject> renameProject({
    required String oldProjectDir,
    required String newProjectName,
  }) async {
    final sanitizedName = newProjectName.trim();
    if (sanitizedName.isEmpty || !RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(sanitizedName)) {
      throw ArgumentError('Invalid project name: "$sanitizedName". Names must be alphanumeric.');
    }

    final oldDir = Directory(oldProjectDir);
    if (!oldDir.existsSync()) {
      throw StateError('Source project directory does not exist: $oldProjectDir');
    }

    final parentPath = oldDir.parent.absolute.path;
    final newDir = Directory('$parentPath/$sanitizedName');
    if (newDir.existsSync()) {
      throw StateError('Target project directory already exists: ${newDir.path}');
    }

    // Step 1: Rename project folder
    oldDir.renameSync(newDir.path);

    // Step 2: Locate and update .lmproject manifest
    final manifestFiles = newDir.listSync().whereType<File>().where((f) => f.path.endsWith('.lmproject')).toList();
    LuminaProject updatedProject;

    if (manifestFiles.isNotEmpty) {
      final oldManifest = manifestFiles.first;
      final content = oldManifest.readAsStringSync();
      final map = jsonDecode(content) as Map<String, dynamic>;
      final original = LuminaProject.fromMap(map);
      updatedProject = original.copyWith(
        projectName: sanitizedName,
        lastModifiedTimestamp: DateTime.now().toIso8601String(),
      );
      if (oldManifest.path != '${newDir.path}/$sanitizedName.lmproject') {
        oldManifest.deleteSync();
      }
    } else {
      updatedProject = LuminaProject(
        projectName: sanitizedName,
        lastModifiedTimestamp: DateTime.now().toIso8601String(),
      );
    }

    final newManifestFile = File('${newDir.path}/$sanitizedName.lmproject');
    newManifestFile.writeAsStringSync(jsonEncode(updatedProject.toMap()));

    // Step 3: Update recents
    await removeRecentProject(oldProjectDir);
    await addRecentProject(updatedProject, projectDir: newDir.path);

    _logger.log('Renamed project from "$oldProjectDir" to "${newDir.path}"', level: 'success', source: 'ProjectRepository');
    return updatedProject;
  }

  Future<String> duplicateProject({
    required String sourceProjectDir,
    String? newProjectName,
  }) async {
    final sourceDir = Directory(sourceProjectDir);
    if (!sourceDir.existsSync()) {
      throw StateError('Source project directory does not exist: $sourceProjectDir');
    }

    final parentPath = sourceDir.parent.absolute.path;
    final sourceDirName = sourceDir.uri.pathSegments.where((s) => s.isNotEmpty).last;

    String targetName = newProjectName?.trim() ?? '${sourceDirName}_Copy';
    String targetPath = '$parentPath/$targetName';
    int counter = 1;
    while (Directory(targetPath).existsSync()) {
      targetName = '${sourceDirName}_Copy_$counter';
      targetPath = '$parentPath/$targetName';
      counter++;
    }

    final targetDir = Directory(targetPath);
    targetDir.createSync(recursive: true);

    // Recursively copy contents
    _copyDirectorySync(sourceDir, targetDir);

    // Update manifest in duplicated folder
    final manifestFiles = targetDir.listSync().whereType<File>().where((f) => f.path.endsWith('.lmproject')).toList();
    LuminaProject duplicatedProject;

    if (manifestFiles.isNotEmpty) {
      final oldManifest = manifestFiles.first;
      final content = oldManifest.readAsStringSync();
      final map = jsonDecode(content) as Map<String, dynamic>;
      final original = LuminaProject.fromMap(map);
      duplicatedProject = original.copyWith(
        projectName: targetName,
        lastModifiedTimestamp: DateTime.now().toIso8601String(),
      );
      if (oldManifest.path != '${targetDir.path}/$targetName.lmproject') {
        oldManifest.deleteSync();
      }
    } else {
      duplicatedProject = LuminaProject(
        projectName: targetName,
        lastModifiedTimestamp: DateTime.now().toIso8601String(),
      );
    }

    final newManifestFile = File('${targetDir.path}/$targetName.lmproject');
    newManifestFile.writeAsStringSync(jsonEncode(duplicatedProject.toMap()));

    await addRecentProject(duplicatedProject, projectDir: targetDir.path);
    _logger.log('Duplicated project "$sourceProjectDir" to "${targetDir.path}"', level: 'success', source: 'ProjectRepository');
    return targetDir.path;
  }

  void _copyDirectorySync(Directory source, Directory destination) {
    for (final entity in source.listSync(recursive: false)) {
      final name = entity.uri.pathSegments.where((s) => s.isNotEmpty).last;
      if (entity is Directory) {
        final newSubDir = Directory('${destination.path}/$name');
        newSubDir.createSync(recursive: true);
        _copyDirectorySync(entity, newSubDir);
      } else if (entity is File) {
        entity.copySync('${destination.path}/$name');
      }
    }
  }

  Future<void> deleteProjectFromDisk(String projectDir) async {
    await removeRecentProject(projectDir);
    final dir = Directory(projectDir);
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
      _logger.log('Deleted project directory from disk: ${dir.path}', level: 'warning', source: 'ProjectRepository');
    }
  }

  
  static const Set<String> _dartReservedWords = {
    'assert', 'break', 'case', 'catch', 'class', 'const', 'continue', 'default',
    'do', 'else', 'enum', 'extends', 'false', 'final', 'finally', 'for', 'if',
    'in', 'is', 'new', 'null', 'rethrow', 'return', 'super', 'switch', 'this',
    'throw', 'true', 'try', 'var', 'void', 'while', 'with', 'yield',
    'abstract', 'as', 'covariant', 'deferred', 'dynamic', 'export', 'external',
    'factory', 'Function', 'get', 'implements', 'import', 'interface', 'late',
    'library', 'mixin', 'operator', 'part', 'required', 'set', 'static', 'typedef',
  };

  /// Validates a candidate project name against Dart package naming rules.
  static String? validateProjectName(String? name) {
    if (name == null || name.trim().isEmpty) {
      return 'Project name cannot be empty';
    }
    final trimmed = name.trim();
    if (!RegExp(r'^[a-z_][a-z0-9_]*$').hasMatch(trimmed)) {
      return 'Project name must be lowercase with underscores (e.g. my_game)';
    }
    if (_dartReservedWords.contains(trimmed)) {
      return '"$trimmed" is a reserved Dart keyword';
    }
    return null;
  }

  /// Validates the target project parent directory.
  static String? validateLocation(String? location) {
    if (location == null || location.trim().isEmpty) {
      return 'Project location cannot be empty';
    }
    final dir = Directory(location.trim());
    if (!dir.existsSync()) {
      return 'Location directory does not exist';
    }
    return null;
  }

  /// Resolves the engine package path for pubspec dependency injection.
  static String get luminaPackagePath {
    final envPath = Platform.environment['LUMINA_PACKAGE_PATH'];
    if (envPath != null && envPath.isNotEmpty) return envPath;
    return LuminaWorkspace.package('lumina');
  }

  @override
  Future<LuminaProject?> loadProject(String lmprojectPath) async {
    try {
      final file = File(lmprojectPath);
      if (!file.existsSync()) return null;
      final jsonMap = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final proj = LuminaProject.fromMap(jsonMap);
      await addRecentProject(proj, projectDir: file.parent.absolute.path);
      ensurePubspecAssets(file.parent.absolute.path);
      await prepareAssetIndex(file.parent.absolute.path);
      _logger.log('Loaded project ${proj.projectName} from disk', level: 'info', source: 'ProjectRepository');
      return proj;
    } catch (e) {
      _logger.log('Failed to load .lmproject: $e', level: 'error', source: 'ProjectRepository');
      return null;
    }
  }

  /// Where the project's cover image lives (it used to be
  /// `contents/.thumbnails/cover.png`).
  static String coverImagePath(String projectDir) => '$projectDir/${ThumbnailSidecarMigration.coverPath}';

  /// The project's cover image file: `.lumina/cover.png`, else the legacy
  /// sidecar location of a project not opened since thumbnails moved into the `.lmas`; null
  /// when it has none.
  static File? coverImageFile(String projectDir) {
    for (final path in [coverImagePath(projectDir), '$projectDir/${ThumbnailSidecarMigration.legacyCoverPath}']) {
      final f = File(path);
      if (f.existsSync()) return f;
    }
    return null;
  }

  /// Once per project: re-embeds any thumbnail only a
  /// `.thumbnails/` sidecar held, deletes every `contents/**/.thumbnails/`
  /// and moves the cover to `.lumina/cover.png` — in a background isolate.
  /// Cheap when there is nothing left to migrate.
  Future<ThumbnailSidecarMigrationReport> migrateThumbnailSidecars(String projectDir) async {
    if (ThumbnailSidecarMigration.sidecarDirectories(projectDir).isEmpty &&
        !File('$projectDir/${ThumbnailSidecarMigration.legacyCoverPath}').existsSync() &&
        !_gitignoreNeedsRules(projectDir)) {
      return const ThumbnailSidecarMigrationReport();
    }
    // A real project's legacy .lmas are read in a background isolate; a small
    // one is cheaper to migrate here than an isolate is to start.
    final bytes = _lmasBytes(projectDir);
    final report = LuminaAssetIndex.shouldSummarizeOffThread(bytes)
        ? ThumbnailSidecarMigrationReport.fromJson(await _migrateOffThread(projectDir))
        : ThumbnailSidecarMigration.run(projectDir);
    if (report.didAnything) {
      _logger.log('Thumbnail sidecars migrated (${report.elapsed.inMilliseconds} ms): $report', level: 'info', source: 'ProjectRepository');
    }
    return report;
  }

  static int _lmasBytes(String projectDir) {
    final contents = Directory('$projectDir/contents');
    if (!contents.existsSync()) return 0;
    var total = 0;
    for (final e in contents.listSync(recursive: true, followLinks: false)) {
      if (e is File && e.path.endsWith('.lmas')) total += e.lengthSync();
    }
    return total;
  }

  /// A static helper so the isolate closure captures nothing but [dir].
  static Future<Map<String, dynamic>> _migrateOffThread(String dir) =>
      Isolate.run(() => ThumbnailSidecarMigration.run(dir).toJson());

  static bool _gitignoreNeedsRules(String projectDir) {
    final f = File('$projectDir/.gitignore');
    if (!f.existsSync()) return false;
    final text = f.readAsStringSync();
    return !text.contains('.lumina') || !text.contains('.thumbnails');
  }

  /// Once per project: BP_ThirdPersonCharacter's stored
  /// feet-based Base Eye Height (160) becomes the capsule-centre one
  /// ([BaseEyeHeightMigration]). Logged when it changed anything.
  BaseEyeHeightMigrationReport migrateBaseEyeHeight(String projectDir) {
    final report = BaseEyeHeightMigration.run(projectDir);
    if (report.didAnything) {
      _logger.log('Migrated to the capsule-centre Base Eye Height: $report', level: 'info', source: 'ProjectRepository');
    }
    return report;
  }

  /// Once per project: generated Dart written by earlier versions is brought
  /// to the current generator's names, engine keys and game library import
  /// (and the pubspec gains `lumina_widgets`) ([LuminaGeneratedCodeMigration]),
  /// off the UI isolate. Logged when it
  /// changed anything.
  Future<void> migrateGeneratedCode(String projectDir) async {
    final changed = await _migrateGeneratedCodeOffThread(projectDir);
    if (changed.isNotEmpty) {
      _logger.log('Generated code migrated: ${changed.join(', ')}', level: 'info', source: 'ProjectRepository');
    }
  }

  /// A static helper so the isolate closure captures nothing but [dir].
  static Future<List<String>> _migrateGeneratedCodeOffThread(String dir) => Isolate.run(() {
        final keys = LuminaGeneratedCodeMigration.migrateObjectKeys(dir);
        final imports = LuminaGeneratedCodeMigration.migrateGameImports(dir);
        final pubspec = LuminaGeneratedCodeMigration.migratePubspecGameDependency(dir);
        final renamed = LuminaGeneratedCodeMigration.migrate(dir);
        return {...keys, ...imports, if (pubspec) 'pubspec.yaml', ...renamed.values}.toList();
      });

  /// What opening a project does before the editor scans it: the sidecar,
  /// Base Eye Height and generated-code migrations, then the asset index brought up to date
  /// off the UI isolate (a cold index of a large project is summarised by an
  /// isolate pool), so every later scan only stats files.
  Future<void> prepareAssetIndex(String projectDir) async {
    try {
      await migrateThumbnailSidecars(projectDir);
    } catch (e) {
      _logger.log('Thumbnail sidecar migration failed: $e', level: 'warning', source: 'ProjectRepository');
    }
    try {
      migrateBaseEyeHeight(projectDir);
    } catch (e) {
      _logger.log('Base Eye Height migration failed: $e', level: 'warning', source: 'ProjectRepository');
    }
    try {
      await migrateGeneratedCode(projectDir);
    } catch (e) {
      _logger.log('Generated code migration failed: $e', level: 'warning', source: 'ProjectRepository');
    }
    try {
      final sw = Stopwatch()..start();
      final index = LuminaAssetIndex.open(projectDir);
      await index.refresh();
      _logger.log(
        'Asset index ready: ${index.entries.length} assets (${index.lastRefreshStats.decoded} summarised, ${sw.elapsedMilliseconds} ms)',
        level: 'info',
        source: 'ProjectRepository',
      );
    } catch (e) {
      _logger.log('Asset index refresh failed: $e', level: 'warning', source: 'ProjectRepository');
    }
  }

  /// Sets the `engine_version` of the `.lmproject` in [projectDir] to
  /// [version], leaving every other field as it is. Returns the previous
  /// value when it changed; null when it already was [version] or the folder
  /// holds no readable manifest.
  Future<String?> updateEngineVersion(String projectDir, String version) async {
    final dir = Directory(projectDir);
    if (!dir.existsSync()) return null;
    final manifests = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.lmproject')).toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    if (manifests.isEmpty) return null;
    final file = manifests.first;
    try {
      final text = await file.readAsString();
      final map = jsonDecode(text) as Map<String, dynamic>;
      final previous = map['engine_version'] as String? ?? '';
      if (previous == version) return null;
      map['engine_version'] = version;
      // In the manifest's own layout (the editor writes it compact).
      final pretty = text.contains('\n  "');
      await file.writeAsString(pretty ? const JsonEncoder.withIndent('  ').convert(map) : jsonEncode(map));
      return previous;
    } on FormatException catch (e) {
      _logger.log('Could not update engine_version in ${file.path}: $e', level: 'warning', source: 'ProjectRepository');
      return null;
    } on FileSystemException catch (e) {
      _logger.log('Could not update engine_version in ${file.path}: $e', level: 'warning', source: 'ProjectRepository');
      return null;
    }
  }

  Future<void> saveProject(LuminaProject project, String projectDirPath) async {
    try {
      final file = File('$projectDirPath/${project.projectName}.lmproject');
      file.writeAsStringSync(jsonEncode(project.toMap()));
      ensurePubspecAssets(projectDirPath);
      _logger.log('Saved project manifest to ${file.path}', level: 'info', source: 'ProjectRepository');
    } catch (e) {
      _logger.log('Failed to write .lmproject: $e', level: 'error', source: 'ProjectRepository');
    }
  }

  /// Ensures that all standard content directories and any subdirectories
  /// found inside `contents/` are registered in the project's `pubspec.yaml`
  /// under `flutter: assets:`.
  static void ensurePubspecAssets(String projectDirPath) {
    final pubspecFile = File('$projectDirPath/pubspec.yaml');
    if (!pubspecFile.existsSync()) return;

    var content = pubspecFile.readAsStringSync();

    // Standard folders that should always be registered
    final requiredAssets = <String>{
      'contents/',
      'contents/meshes/static/',
      'contents/meshes/skeletal/',
      'contents/materials/',
      'contents/textures/',
      'contents/animations/',
      'contents/audio/',
      'contents/particles/',
      'contents/levels/',
      'contents/ui/',
      'contents/landscapes/',
      'contents/blueprints/',
      'contents/widgets/',
    };

    // Also scan existing subdirectories under contents/
    final contentsDir = Directory('$projectDirPath/contents');
    if (contentsDir.existsSync()) {
      try {
        final prefix = contentsDir.parent.path.replaceAll('\\', '/');
        for (final entity in contentsDir.listSync(recursive: true)) {
          if (entity is Directory) {
            var fullPath = entity.path.replaceAll('\\', '/');
            if (fullPath.startsWith(prefix)) {
              var rel = fullPath.substring(prefix.length);
              if (rel.startsWith('/')) rel = rel.substring(1);
              // Ignore hidden folders like .thumbnails
              if (!rel.split('/').any((seg) => seg.startsWith('.'))) {
                final formatted = rel.endsWith('/') ? rel : '$rel/';
                requiredAssets.add(formatted);
              }
            }
          }
        }
      } catch (_) {}
    }

    // Check if flutter: section exists
    final flutterRegex = RegExp(r'^flutter:\s*$', multiLine: true);
    final flutterMatch = flutterRegex.firstMatch(content);

    if (flutterMatch == null) {
      final buffer = StringBuffer('\nflutter:\n  assets:\n');
      for (final a in requiredAssets) {
        buffer.writeln('    - $a');
      }
      content += buffer.toString();
      pubspecFile.writeAsStringSync(content);
      return;
    }

    // Check if assets: section exists under flutter:
    final assetsRegex = RegExp(r'^\s*assets:\s*$', multiLine: true);
    final assetsMatch = assetsRegex.firstMatch(content);

    if (assetsMatch == null) {
      final insertPos = flutterMatch.end;
      final buffer = StringBuffer('\n  assets:\n');
      for (final a in requiredAssets) {
        buffer.writeln('    - $a');
      }
      content = content.substring(0, insertPos) + buffer.toString() + content.substring(insertPos);
      pubspecFile.writeAsStringSync(content);
      return;
    }

    // Both flutter: and assets: exist. Find which entries are missing.
    final missing = <String>[];
    for (final a in requiredAssets) {
      final pattern = RegExp('-\\s+${RegExp.escape(a)}');
      if (!pattern.hasMatch(content)) {
        missing.add(a);
      }
    }

    if (missing.isNotEmpty) {
      final insertPos = assetsMatch.end;
      final buffer = StringBuffer('\n');
      for (final a in missing) {
        buffer.writeln('    - $a');
      }
      content = content.substring(0, insertPos) + buffer.toString() + content.substring(insertPos);
      pubspecFile.writeAsStringSync(content);
    }
  }
}

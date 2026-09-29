import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import '../../src/game/template_content.dart';
import '../models/lumina_asset.dart';
import '../models/lumina_project.dart';
import '../models/recent_project_entry.dart';
import '../services/asset_index.dart';
import '../services/derived_data_cache.dart';
import '../services/thumbnail_sidecar_migration.dart';
import '../services/base_eye_height_migration.dart';
import '../services/engine_logger_service.dart';
import '../services/config_json_file.dart';
import '../services/lumina_config_dir.dart';
import '../services/code_generator_service.dart';
import '../services/dart_identifiers.dart';
import '../services/umg_widget_library_service.dart';
import '../services/game_template_service.dart';
import '../services/glb_parser_service.dart';
import '../services/project_input_binder.dart';
import '../services/project_engine_link.dart';
import '../services/workspace_paths.dart';
import 'asset_repository.dart';

enum ProjectCreationStep {
  folderSetup,
  flutterCreate,
  contentsTree,
  pubspecPatch,
  pubGet,
  manifestAndLevel,
  openingEditor,
}

class ProjectCreationProgress {
  final ProjectCreationStep step;
  final double progress;
  final String message;

  ProjectCreationProgress(this.step, this.progress, this.message);
}

class ProjectCreationException implements Exception {
  final ProjectCreationStep step;
  final String message;

  ProjectCreationException(this.step, this.message);
  
  @override
  String toString() => 'ProjectCreationException(step: $step, message: $message)';
}

typedef ProcessRunner = Future<ProcessResult> Function(String executable, List<String> arguments, {String? workingDirectory, bool runInShell});


class ProjectRepository {
  final EngineLoggerService _logger = EngineLoggerService();
  final Directory? configDir;

  
  final ProcessRunner processRunner;

  /// The lumina package the template content is read from; defaults to
  /// [luminaPackagePath], the same engine the new project's pubspec points at.
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

  /// Executes the 7-step project creation pipeline, streaming live progress events.
  Stream<ProjectCreationProgress> createProjectStream({
    required String projectName,
    required String projectLocation,
    String template = kBlank3dTemplateId,
    String widgetLibrary = kUmgWidgetLibraryShadcn,
  }) async* {
    final nameError = validateProjectName(projectName);
    if (nameError != null) {
      throw ProjectCreationException(ProjectCreationStep.folderSetup, nameError);
    }
    final locError = validateLocation(projectLocation);
    if (locError != null) {
      throw ProjectCreationException(ProjectCreationStep.folderSetup, locError);
    }

    final targetDir = Directory('$projectLocation/$projectName');
    if (targetDir.existsSync()) {
      throw ProjectCreationException(ProjectCreationStep.folderSetup, 'Project directory already exists at ${targetDir.path}');
    }

    bool createdDirectory = false;

    try {
      // Step 1: folderSetup
      yield ProjectCreationProgress(ProjectCreationStep.folderSetup, 0.1, 'Setting up project folders...');
      targetDir.createSync(recursive: true);
      createdDirectory = true;

      // Step 2: flutterCreate
      yield ProjectCreationProgress(ProjectCreationStep.flutterCreate, 0.2, 'Running flutter create...');
      final createResult = await processRunner('flutter', ['create', '--no-pub', '--project-name', projectName, targetDir.path], workingDirectory: projectLocation);
      if (createResult.exitCode != 0) {
        throw ProjectCreationException(ProjectCreationStep.flutterCreate, 'flutter create failed: ${createResult.stderr}');
      }
      // The project's DerivedDataCache/ never reaches git.
      DerivedDataCache.ensureIgnoredBy(targetDir.path);
      // The asset index (.lumina/) and legacy thumbnail
      // sidecars never reach git either.
      ThumbnailSidecarMigration.ensureGitignoreRules(targetDir.path);

      // Step 3: contentsTree
      yield ProjectCreationProgress(ProjectCreationStep.contentsTree, 0.4, 'Creating contents asset directory tree...');
      final contentsDir = Directory('${targetDir.path}/contents');
      for (final sub in [
        'meshes/static',
        'meshes/skeletal',
        'materials',
        'textures',
        'animations',
        'audio',
        'particles',
        'levels',
        'ui',
        'landscapes',
        'blueprints',
        'widgets',
      ]) {
        Directory('${contentsDir.path}/$sub').createSync(recursive: true);
      }

      // Step 4: pubspecPatch
      yield ProjectCreationProgress(ProjectCreationStep.pubspecPatch, 0.5, 'Patching pubspec.yaml with Lumina dependencies and assets...');
      final pubspecFile = File('${targetDir.path}/pubspec.yaml');
      if (!pubspecFile.existsSync()) {
        throw ProjectCreationException(ProjectCreationStep.pubspecPatch, 'pubspec.yaml not found at ${pubspecFile.path}');
      }
      String pubspecContent = pubspecFile.readAsStringSync();

      // The engine as a git dependency (committable); a local checkout comes
      // from the gitignored pubspec_overrides.yaml ProjectEngineLink writes.
      pubspecContent = ProjectEngineLink.withGitEngineDependency(pubspecContent);

      // Merge asset folders into single flutter: mapping
      const assetList = '''  assets:
    - contents/
    - contents/meshes/static/
    - contents/meshes/skeletal/
    - contents/materials/
    - contents/textures/
    - contents/animations/
    - contents/audio/
    - contents/particles/
    - contents/levels/
    - contents/ui/
    - contents/landscapes/
    - contents/blueprints/
    - contents/widgets/
''';

      if (!pubspecContent.contains('contents/')) {
        final flutterRegex = RegExp(r'^flutter:\s*$', multiLine: true);
        final match = flutterRegex.firstMatch(pubspecContent);
        if (match != null) {
          final insertPos = match.end;
          pubspecContent = '${pubspecContent.substring(0, insertPos)}\n$assetList${pubspecContent.substring(insertPos)}';
        } else {
          pubspecContent += '\nflutter:\n$assetList';
        }
      }
      pubspecFile.writeAsStringSync(pubspecContent);
      // When the editor runs from a local engine checkout: its packages as
      // path overrides, and where this machine's Filament build is for the
      // native-assets hooks.
      final link = ProjectEngineLink.apply(targetDir.path,
          luminaPackageDir: enginePackageDir ?? luminaPackagePath,
          onLog: (m) => _logger.log(m, level: 'warning', source: 'ProjectRepository'));
      if (link.isLocal) {
        _logger.log('Linked $projectName to the local engine at ${link.engineRoot} (pubspec_overrides.yaml)',
            level: 'info', source: 'ProjectRepository');
      }
      // The UMG widget library's dependency, before pub get resolves it.
      UmgWidgetLibraryService.apply(targetDir.path, widgetLibrary);

      // Step 5: pubGet
      yield ProjectCreationProgress(ProjectCreationStep.pubGet, 0.6, 'Running flutter pub get...');
      final pubGetResult = await processRunner('flutter', ['pub', 'get'], workingDirectory: targetDir.path);
      if (pubGetResult.exitCode != 0) {
        throw ProjectCreationException(ProjectCreationStep.pubGet, 'flutter pub get failed: ${pubGetResult.stderr}');
      }

      // Step 6: manifestAndLevel
      final gameTemplate = GameTemplateCatalog.byId(template);
      final templateSteps = gameTemplate.manifestStepMessages(projectName);
      yield ProjectCreationProgress(ProjectCreationStep.manifestAndLevel, 0.75, templateSteps.first);

      final codeGenService = DartCodeGeneratorService();
      final gameModeClass = gameTemplate.gameModeClass(projectName);
      final characterClass = gameTemplate.characterClass(projectName);
      // The Third Person template's character, game mode and
      // animation are Blueprints the user can open, compiled into the game.
      final blueprintGame = gameTemplate.generatesGameSource && gameTemplate.kind == GameTemplateKind.thirdPerson;

      // The seeded actors carry the game mode binding on their PlayerStart, so
      // an editor save — which regenerates the level from `metadata.actors`
      // alone — cannot unwire the template.
      final seededActors = gameTemplate.levelActors;
      if (gameTemplate.generatesGameSource) {
        for (final actor in seededActors) {
          if (actor['type'] != 'PlayerStart') continue;
          final components = (actor['components'] as List).cast<Map<String, dynamic>>();
          components.add(<String, dynamic>{
            'id': '${actor['id']}_gamemode',
            'type': 'LuminaGameModeBinding',
            'name': 'Game Mode',
            'enabled': true,
            'properties': blueprintGame
                ? <String, dynamic>{'gameModeBlueprint': LuminaThirdPersonContent.gameModeBlueprintPath}
                : <String, dynamic>{
                    'gameModeClass': gameModeClass,
                    'gameModeImport': '../game/${dartFileName(gameModeClass)}',
                  },
          });
        }
      }

      if (templateSteps.length > 1) {
        yield ProjectCreationProgress(ProjectCreationStep.manifestAndLevel, 0.8, templateSteps[1]);
      }

      // The level asset is written as the same JSON container the editor's
      // Save Level produces, with the template's actors already in place, so
      // opening the project shows the template's outliner tree immediately.
      final initialLevelFile = File('${contentsDir.path}/levels/L_DefaultLevel.lmas');
      initialLevelFile.writeAsStringSync(jsonEncode(<String, dynamic>{
        'assetId': 'level_L_DefaultLevel',
        'name': 'L_DefaultLevel',
        'type': 'level',
        'relativePath': 'contents/levels/L_DefaultLevel.lmas',
        'rawPayload': null,
        'metadata': <String, dynamic>{'actors': seededActors},
      }));

      final libDir = Directory('${targetDir.path}/lib');
      if (!libDir.existsSync()) libDir.createSync(recursive: true);

      final mainCode = codeGenService.generateMainDart(
        projectName: projectName,
        widgetLibrary: widgetLibrary,
        gravityZ: const ProjectPhysicsSettings().gravityZ,
        gameModeClass: gameTemplate.generatesGameSource && !blueprintGame ? gameModeClass : null,
        gameModeImport: gameTemplate.generatesGameSource && !blueprintGame ? 'game/${dartFileName(gameModeClass)}' : null,
        mapsAndModes: blueprintGame
            ? const ProjectMapsAndModes(defaultGameMode: LuminaThirdPersonContent.gameModeBlueprintPath)
            : null,
        hasBlueprints: blueprintGame,
        projectInput: blueprintGame,
        // Compiling the template's Blueprints below writes
        // lib/blueprint_registry.g.dart.
        blueprintRegistry: blueprintGame,
      );
      File('${libDir.path}/main.dart').writeAsStringSync(mainCode);

      final levelCode = codeGenService.generateLevelDart(
        levelName: 'L_DefaultLevel',
        actors: [],
        actorMaps: seededActors,
      );
      final levelCodeDir = Directory('${targetDir.path}/lib/levels');
      levelCodeDir.createSync(recursive: true);
      File('${levelCodeDir.path}/${dartFileName('L_DefaultLevel')}').writeAsStringSync(levelCode);

      if (gameTemplate.shipsMannequin) {
        yield ProjectCreationProgress(
          ProjectCreationStep.manifestAndLevel,
          0.85,
          'Copying the ${LuminaThirdPersonContent.meshAssetName} character and its '
          '${LuminaThirdPersonContent.clipNames.length} animations into contents...',
        );
        await _writeMannequinContent(targetDir.path);
      }

      if (blueprintGame) {
        if (templateSteps.length > 2) {
          yield ProjectCreationProgress(ProjectCreationStep.manifestAndLevel, 0.9, templateSteps[2]);
        }
        await _writeThirdPersonBlueprints(targetDir.path, gameTemplate.input, codeGenService);
      } else if (gameTemplate.generatesGameSource) {
        if (templateSteps.length > 2) {
          yield ProjectCreationProgress(ProjectCreationStep.manifestAndLevel, 0.9, templateSteps[2]);
        }
        final pawnsDir = Directory('${libDir.path}/pawns')..createSync(recursive: true);
        File('${pawnsDir.path}/${dartFileName(characterClass)}').writeAsStringSync(
          codeGenService.generateCharacterDart(
            projectName: projectName,
            thirdPerson: gameTemplate.kind == GameTemplateKind.thirdPerson,
          ),
        );
        final gameDir = Directory('${libDir.path}/game')..createSync(recursive: true);
        File('${gameDir.path}/${dartFileName(gameModeClass)}').writeAsStringSync(
          codeGenService.generateGameModeDart(projectName: projectName),
        );
      }

      final project = LuminaProject(
        projectName: projectName,
        engineVersion: kLuminaEngineVersion,
        activeLevel: 'contents/levels/L_DefaultLevel.lmas',
        template: gameTemplate.id,
        ui: ProjectUiSettings(widgetLibrary: widgetLibrary),
        isDirty: false,
        lastModifiedTimestamp: DateTime.now().toIso8601String(),
        lastCodeGeneratedTimestamp: DateTime.now().toIso8601String(),
        input: gameTemplate.input,
        mapsAndModes: ProjectMapsAndModes(
          editorStartupMap: 'contents/levels/L_DefaultLevel.lmas',
          gameDefaultMap: 'contents/levels/L_DefaultLevel.lmas',
          defaultGameMode: blueprintGame ? LuminaThirdPersonContent.gameModeBlueprintPath : gameModeClass,
        ),
        settings: EngineScalabilitySettings(
          targetFps: 60,
          vsyncEnabled: true,
          qualityPreset: 'epic',
          scalability: ScalabilitySettings(
            viewDistance: 'epic',
            shadowQuality: 'high',
            antiAliasing: 'fxaa',
            postProcessing: 'epic',
            textureQuality: 'high',
            shadingQuality: 'epic',
          ),
          autoOrganizeFiles: true,
          autoSaveIntervalSeconds: 60,
        ),
      );
      final lmprojectFile = File('${targetDir.path}/$projectName.lmproject');
      lmprojectFile.writeAsStringSync(jsonEncode(project.toMap()));

      // Step 7: openingEditor
      yield ProjectCreationProgress(ProjectCreationStep.openingEditor, 1.0, 'Opening editor...');
      await addRecentProject(project, projectDir: targetDir.path);

    } catch (e) {
      if (createdDirectory && targetDir.existsSync()) {
        targetDir.deleteSync(recursive: true);
      }
      if (e is ProjectCreationException) {
        rethrow;
      }
      throw ProjectCreationException(ProjectCreationStep.folderSetup, e.toString());
    }
  }

  /// Writes the Third Person template's Blueprints into [projectDir]'s
  /// `contents/` — the character, its game mode, the character mesh's Animation
  /// Blueprint, its walk blend space and walk / jog locomotion
  /// blend space — compiles them into
  /// `lib/actors/` and `lib/anim/`, and writes the project's input as code
  /// (`lib/input/project_input.g.dart`) for the Blueprint character to bind.
  Future<void> _writeThirdPersonBlueprints(
      String projectDir, ProjectInputSettings input, DartCodeGeneratorService codegen) async {
    final actions = ProjectInputBinder.bind(input).actions.values.toList();
    void write(String path, AssetType type, Map<String, dynamic> document) {
      final name = path.split('/').last.replaceAll('.lmas', '');
      final animation = type == AssetType.animBlueprint || type == AssetType.blendSpace;
      File('$projectDir/$path')
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(LuminaAsset(
          assetId: _uuidV4(),
          name: name,
          type: type,
          rawPayload: Uint8List.fromList(utf8.encode(jsonEncode(document))),
          metadata: {
            'source': 'template:$kThirdPersonTemplateId',
            // The skeletal mesh an Animation Blueprint or Blend Space animates,
            // as the editor's anim-graph assets record it.
            if (animation) 'target_mesh': LuminaThirdPersonContent.projectMeshAssetPath,
          },
        ).toProtoBufferBytes());
    }

    write(LuminaThirdPersonContent.projectWalkBlendSpacePath, AssetType.blendSpace,
        LuminaThirdPersonContent.walkBlendSpace.toJson());
    // The Walk state's Direction × Speed walk / jog blend space.
    write(LuminaThirdPersonContent.projectLocomotionBlendSpacePath, AssetType.blendSpace,
        LuminaThirdPersonContent.locomotionBlendSpace.toJson());
    write(LuminaThirdPersonContent.projectAnimBlueprintPath, AssetType.animBlueprint,
        LuminaThirdPersonContent.animBlueprint.toJson());
    write(LuminaThirdPersonContent.characterBlueprintPath, AssetType.actor,
        LuminaThirdPersonContent.characterBlueprint(inputActions: actions).toJson());
    final gameMode = LuminaThirdPersonContent.gameModeBlueprint.toJson();
    write(LuminaThirdPersonContent.gameModeBlueprintPath, AssetType.actor, gameMode);

    final compiled = await codegen.compileAndWriteActor(
      projectDir,
      LuminaThirdPersonContent.gameModeBlueprintName,
      gameMode,
      assetPath: LuminaThirdPersonContent.gameModeBlueprintPath,
      inputActions: actions,
    );
    if (!compiled) {
      throw ProjectCreationException(
        ProjectCreationStep.manifestAndLevel,
        'The Third Person Blueprints did not compile (${LuminaThirdPersonContent.gameModeBlueprintPath}).',
      );
    }
    File('$projectDir/lib/input/project_input.g.dart')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(codegen.generateProjectInputDart(input));
  }

  /// Copies the Third Person template's character into [projectDir]'s
  /// `contents/`: the merged GLB (mesh + clips) as the companion of a
  /// skeletal mesh asset, and one animation asset per clip that points at it.
  ///
  /// The GLB goes through the same skinning/texture sanitizer an import does,
  /// so the project holds what gltfio can draw (four influences per vertex).
  /// The mesh `.lmas` carries no payload and the clip assets no GLB copy: every
  /// reader falls back to the `.entity.glb`, and a copy per clip would dwarf
  /// the rest of the project.
  Future<void> _writeMannequinContent(String projectDir) async {
    final bundle = File('${enginePackageDir ?? luminaPackagePath}/${LuminaThirdPersonContent.bundledMeshPath}');
    if (!bundle.existsSync()) {
      throw ProjectCreationException(
        ProjectCreationStep.manifestAndLevel,
        'Third Person template content is missing: ${bundle.path}. Build it with '
        '`dart run tool/build_third_person_content.dart` in the lumina package.',
      );
    }

    final glb = await GlbParserService.convertGlbTgaToPngAsync(bundle.readAsBytesSync());
    final glbFile = File('$projectDir/${LuminaThirdPersonContent.projectMeshGlbPath}');
    glbFile.parent.createSync(recursive: true);
    glbFile.writeAsBytesSync(glb);

    final assets = AssetRepository();
    final meshThumbnail = await assets.generateThumbnailBytes(AssetType.filameshSk, rawPayload: glb);
    final meshAsset = LuminaAsset(
      assetId: _uuidV4(),
      name: LuminaThirdPersonContent.meshAssetName,
      type: AssetType.filameshSk,
      hasThumbnail: meshThumbnail != null,
      thumbnailPng: meshThumbnail,
      metadata: {
        'payload_format': 'glb',
        'animation_clips': LuminaThirdPersonContent.clipNames.join(','),
        'source': 'template:$kThirdPersonTemplateId',
      },
    );
    File('$projectDir/${LuminaThirdPersonContent.projectMeshAssetPath}')
        .writeAsBytesSync(meshAsset.toProtoBufferBytes());

    final animationThumbnail = await assets.generateThumbnailBytes(AssetType.animation);
    final animationDir = Directory('$projectDir/${LuminaThirdPersonContent.projectAnimationDir}')
      ..createSync(recursive: true);
    final clips = LuminaThirdPersonContent.clipNames;
    for (var i = 0; i < clips.length; i++) {
      final clip = LuminaAsset(
        assetId: _uuidV4(),
        name: clips[i],
        type: AssetType.animation,
        hasThumbnail: animationThumbnail != null,
        thumbnailPng: animationThumbnail,
        references: [
          AssetReference(
            slotName: 'skeletal_mesh',
            assetId: meshAsset.assetId,
            assetPath: LuminaThirdPersonContent.projectMeshAssetPath,
          ),
        ],
        metadata: {
          'source_mesh': LuminaThirdPersonContent.projectMeshAssetPath,
          'clip_name': clips[i],
          'clip_index': '$i',
          'anim_properties': jsonEncode({
            'rate_scale': 1.0,
            'interpolation': 'Linear',
            'additive_type': 'No Additive',
            'frame_rate': 30.0,
            'default_clip': i,
            'preview_mesh_path': LuminaThirdPersonContent.projectMeshAssetPath,
          }),
        },
      );
      File('${animationDir.path}/${clips[i]}.lmas').writeAsBytesSync(clip.toProtoBufferBytes());
    }
  }

  static String _uuidV4() {
    final random = math.Random.secure();
    final bytes = Uint8List.fromList(List<int>.generate(16, (_) => random.nextInt(256)));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  /// Convenience method to create a project, awaiting all pipeline steps.
  Future<LuminaProject> createProject({
    required String projectName,
    required String projectLocation,
    String template = kBlank3dTemplateId,
    String widgetLibrary = kUmgWidgetLibraryShadcn,
    void Function(ProjectCreationProgress)? onProgress,
  }) async {
    await for (final progress in createProjectStream(
      projectName: projectName,
      projectLocation: projectLocation,
      template: template,
      widgetLibrary: widgetLibrary,
    )) {
      onProgress?.call(progress);
    }
    final manifestPath = '$projectLocation/$projectName/$projectName.lmproject';
    final project = await loadProject(manifestPath);
    if (project == null) {
      throw ProjectCreationException(ProjectCreationStep.manifestAndLevel, 'Failed to load created project manifest at $manifestPath');
    }
    return project;
  }

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

  /// What opening a project does before the editor scans it: the sidecar
  /// and Base Eye Height migrations, then the asset index brought up to date
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

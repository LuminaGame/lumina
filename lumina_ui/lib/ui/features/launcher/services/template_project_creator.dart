import 'dart:convert';
import 'dart:io';

import 'package:lumina/lumina.dart';

import 'package:lumina_ui/ui/features/marketplace/services/marketplace_license_records.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/umg_widget_codegen.dart';
import 'package:lumina_ui/ui/features/launcher/services/installed_template_repository.dart';

/// Creates a project from an installed folder template, the
/// way [ProjectRepository.createProjectStream] creates one from a built-in
/// template:
///
/// 1. `flutter create` into `<location>/<name>/` (the platform folders a
///    template archive does not carry);
/// 2. the template's project tree — `contents/`, `lib/` and the rest, minus
///    its own manifests and notice — copied over it;
/// 3. its `pubspec.yaml` (dependencies, assets) renamed to the new package,
///    with the engine as a git dependency, linked to this machine's engine
///    checkout by [ProjectEngineLink] (a gitignored `pubspec_overrides.yaml`
///    and the native hooks' settings);
/// 4. every `package:<template>/` import in `lib/` renamed;
/// 5. `flutter pub get`;
/// 6. the manifest written as `<name>.lmproject` (the source project's
///    settings, input, maps and modes under the new name), and the normal
///    code generation: `lib/main.dart` (its game class is named after the
///    project), the Blueprint registry and any level without generated code;
/// 7. the template's license notice kept in `contents/Marketplace/`
///    (`LICENSE-<Listing>.txt` and a `licenses.json` entry), and the project
///    added to the recent projects.
///
/// A failure removes the half-created folder, as the built-in pipeline does.
class TemplateProjectCreator {
  TemplateProjectCreator(this.projectRepo, {DartCodeGeneratorService? codegen, EngineLoggerService? logger})
      : _codegen = codegen ?? DartCodeGeneratorService(),
        _logger = logger ?? EngineLoggerService();

  final ProjectRepository projectRepo;
  final DartCodeGeneratorService _codegen;
  final EngineLoggerService _logger;

  /// Top-level template entries that are not copied into the project: the
  /// template's own manifests (rewritten instead), its card screenshot and
  /// the installer's notice (kept under `contents/Marketplace/`).
  static bool _isTemplateOnly(String rel, InstalledGameTemplate t) {
    if (rel.contains('/')) return false;
    if (rel == 'template.json' || rel == 'pubspec.yaml' || rel == 'pubspec.lock') return true;
    // The author's local engine overrides: this machine gets its own.
    if (rel == ProjectEngineLink.overridesFileName) return true;
    if (rel.endsWith('.lmproject')) return true;
    if (rel.startsWith('LICENSE-') && rel.endsWith('.txt')) return true;
    return t.thumbnailPath != null && '${t.dir}/$rel' == t.thumbnailPath;
  }

  Stream<ProjectCreationProgress> create({
    required InstalledGameTemplate template,
    required String projectName,
    required String projectLocation,
  }) async* {
    final nameError = ProjectRepository.validateProjectName(projectName);
    if (nameError != null) throw ProjectCreationException(ProjectCreationStep.folderSetup, nameError);
    final locError = ProjectRepository.validateLocation(projectLocation);
    if (locError != null) throw ProjectCreationException(ProjectCreationStep.folderSetup, locError);
    final target = Directory('$projectLocation/$projectName');
    if (target.existsSync()) {
      throw ProjectCreationException(ProjectCreationStep.folderSetup, 'Project directory already exists at ${target.path}');
    }
    if (!Directory(template.dir).existsSync()) {
      throw ProjectCreationException(ProjectCreationStep.folderSetup, 'The template ${template.title} is no longer installed.');
    }

    var created = false;
    var step = ProjectCreationStep.folderSetup;
    try {
      yield ProjectCreationProgress(step, 0.1, 'Setting up project folders from the ${template.title} template...');
      target.createSync(recursive: true);
      created = true;

      step = ProjectCreationStep.flutterCreate;
      yield ProjectCreationProgress(step, 0.2, 'Running flutter create...');
      final createResult = await projectRepo.processRunner(
          'flutter', ['create', '--no-pub', '--project-name', projectName, target.path],
          workingDirectory: projectLocation);
      if (createResult.exitCode != 0) {
        throw ProjectCreationException(step, 'flutter create failed: ${createResult.stderr}');
      }
      DerivedDataCache.ensureIgnoredBy(target.path);
      ThumbnailSidecarMigration.ensureGitignoreRules(target.path);

      step = ProjectCreationStep.contentsTree;
      yield ProjectCreationProgress(step, 0.35, 'Copying the ${template.title} project tree...');
      final sourceProject = _readSourceProject(template);
      final oldPackage = _templatePackageName(template) ?? sourceProject?.projectName ?? '';
      final copied = _copyTemplateTree(template, target);
      yield ProjectCreationProgress(step, 0.45, 'Copied $copied file(s) from the template');

      step = ProjectCreationStep.pubspecPatch;
      yield ProjectCreationProgress(step, 0.5, 'Writing pubspec.yaml for $projectName...');
      final pubspec = File('${target.path}/pubspec.yaml');
      final templatePubspec = File('${template.dir}/pubspec.yaml');
      final base = templatePubspec.existsSync() ? templatePubspec.readAsStringSync() : pubspec.readAsStringSync();
      pubspec.writeAsStringSync(rewritePubspec(base, name: projectName));
      ProjectRepository.ensurePubspecAssets(target.path);
      ProjectEngineLink.apply(target.path,
          luminaPackageDir: projectRepo.enginePackageDir ?? ProjectRepository.luminaPackagePath,
          onLog: (m) => _logger.log(m, level: 'warning', source: 'Templates'));
      final renamed = oldPackage.isEmpty || oldPackage == projectName ? 0 : renamePackageImports(target.path, oldPackage, projectName);
      if (renamed > 0) yield ProjectCreationProgress(step, 0.55, 'Renamed package:$oldPackage/ imports in $renamed file(s)');

      step = ProjectCreationStep.pubGet;
      yield ProjectCreationProgress(step, 0.6, 'Running flutter pub get...');
      final pubGet = await projectRepo.processRunner('flutter', ['pub', 'get'], workingDirectory: target.path);
      if (pubGet.exitCode != 0) throw ProjectCreationException(step, 'flutter pub get failed: ${pubGet.stderr}');

      step = ProjectCreationStep.manifestAndLevel;
      yield ProjectCreationProgress(step, 0.75, 'Writing $projectName.lmproject...');
      final project = _manifestFor(template, sourceProject, projectName, target.path);
      File('${target.path}/$projectName.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
      yield ProjectCreationProgress(step, 0.82, 'Generating Dart code for ${project.activeLevel}...');
      final generated = _generateCode(target.path, project);
      yield ProjectCreationProgress(step, 0.88, 'Generated ${generated.join(', ')}');
      final license = _keepLicense(template, target.path);
      if (license != null) yield ProjectCreationProgress(step, 0.92, 'Kept the template license in $license');

      step = ProjectCreationStep.openingEditor;
      yield ProjectCreationProgress(step, 1.0, 'Opening editor...');
      await projectRepo.addRecentProject(project, projectDir: target.path);
      _logger.log('Created $projectName from the game template ${template.title} (${template.dir})',
          level: 'success', source: 'Templates');
    } catch (e) {
      if (created && target.existsSync()) target.deleteSync(recursive: true);
      if (e is ProjectCreationException) rethrow;
      throw ProjectCreationException(step, e.toString());
    }
  }

  // --- Steps -----------------------------------------------------------------

  static LuminaProject? _readSourceProject(InstalledGameTemplate t) {
    final path = t.lmprojectPath;
    if (path == null) return null;
    return LuminaProject.fromMap(Map<String, dynamic>.from(jsonDecode(File(path).readAsStringSync()) as Map));
  }

  static String? _templatePackageName(InstalledGameTemplate t) {
    final f = File('${t.dir}/pubspec.yaml');
    if (!f.existsSync()) return null;
    return RegExp(r'^name:\s*([A-Za-z_][A-Za-z0-9_]*)\s*$', multiLine: true).firstMatch(f.readAsStringSync())?.group(1);
  }

  /// Copies the template's files over the `flutter create` output; returns
  /// how many.
  static int _copyTemplateTree(InstalledGameTemplate t, Directory target) {
    var count = 0;
    final root = Directory(t.dir);
    for (final f in root.listSync(recursive: true, followLinks: false).whereType<File>()) {
      final rel = f.path.substring(root.path.length + 1);
      if (_isTemplateOnly(rel, t)) continue;
      final out = File('${target.path}/$rel');
      out.parent.createSync(recursive: true);
      f.copySync(out.path);
      count++;
    }
    return count;
  }

  /// [yaml] with `name: [name]` and the `lumina:` dependency in its git form
  /// (replacing a template's `path:` one, added when missing) and no `hooks:`
  /// block; every other dependency and asset entry is kept.
  static String rewritePubspec(String yaml, {required String name}) {
    final out = yaml.contains(RegExp(r'^name:', multiLine: true))
        ? yaml.replaceFirst(RegExp(r'^name:.*$', multiLine: true), 'name: $name')
        : 'name: $name\n$yaml';
    // The template author's hook settings name their machine's paths.
    return ProjectEngineLink.withHookUserDefines(ProjectEngineLink.withGitEngineDependency(out), const {},
        anyBlock: true);
  }

  /// Rewrites `package:[from]/` to `package:[to]/` in every Dart file under
  /// `lib/` and `test/` of [projectDir]; returns how many files changed.
  static int renamePackageImports(String projectDir, String from, String to) {
    var changed = 0;
    final pattern = RegExp('package:${RegExp.escape(from)}/');
    for (final folder in ['lib', 'test']) {
      final dir = Directory('$projectDir/$folder');
      if (!dir.existsSync()) continue;
      for (final f in dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
        final text = f.readAsStringSync();
        if (!pattern.hasMatch(text)) continue;
        f.writeAsStringSync(text.replaceAll(pattern, 'package:$to/'));
        changed++;
      }
    }
    return changed;
  }

  /// The source project's manifest under [projectName], or — for a template
  /// without one — a manifest opening its first level.
  static LuminaProject _manifestFor(InstalledGameTemplate t, LuminaProject? source, String projectName, String projectDir) {
    final now = DateTime.now().toIso8601String();
    if (source != null) {
      return source.copyWith(
        projectName: projectName,
        isDirty: false,
        lastModifiedTimestamp: now,
        lastCodeGeneratedTimestamp: now,
        description: source.description.isEmpty ? t.description : source.description,
      );
    }
    final levels = _levelFiles(projectDir);
    final level = levels.isEmpty ? 'contents/levels/L_DefaultLevel.lmas' : levels.first;
    return LuminaProject(
      projectName: projectName,
      engineVersion: kLuminaEngineVersion,
      activeLevel: level,
      description: t.description,
      isDirty: false,
      lastModifiedTimestamp: now,
      lastCodeGeneratedTimestamp: now,
      mapsAndModes: ProjectMapsAndModes(editorStartupMap: level, gameDefaultMap: level),
    );
  }

  static List<String> _levelFiles(String projectDir) {
    final dir = Directory('$projectDir/contents/levels');
    if (!dir.existsSync()) return const [];
    return [
      for (final f in dir.listSync().whereType<File>())
        if (f.path.endsWith('.lmas')) 'contents/levels/${f.uri.pathSegments.last}',
    ]..sort();
  }

  /// `metadata` of a level `.lmas` (the editor's JSON container, or a binary
  /// asset), or null.
  static Map<String, dynamic>? _levelMetadata(File file) {
    try {
      final j = jsonDecode(file.readAsStringSync());
      if (j is Map && j['metadata'] is Map) return Map<String, dynamic>.from(j['metadata'] as Map);
    } catch (_) {}
    try {
      return LuminaAsset.fromBytes(file.readAsBytesSync()).metadata;
    } catch (_) {
      return null;
    }
  }

  /// What the editor's Save Level generates, for the new project: level code
  /// for any level the template did not ship generated, the Blueprint
  /// registry, and `lib/main.dart`. Returns the files written.
  List<String> _generateCode(String projectDir, LuminaProject project) {
    final written = <String>[];
    final lib = Directory('$projectDir/lib')..createSync(recursive: true);
    final levelsDir = Directory('${lib.path}/levels')..createSync(recursive: true);
    // A template generated by an earlier version ships `lib/levels/L_X.dart`:
    // it becomes `l_x.dart` (class `LX`) before anything is generated.
    LuminaGeneratedCodeMigration.migrate(projectDir);
    for (final rel in _levelFiles(projectDir)) {
      final name = rel.split('/').last.replaceAll('.lmas', '');
      final out = File('${levelsDir.path}/${dartFileName(name)}');
      if (out.existsSync()) continue;
      final meta = _levelMetadata(File('$projectDir/$rel'));
      final actors = [
        for (final a in (meta?['actors'] as List?) ?? const []) Map<String, dynamic>.from(a as Map),
      ];
      out.writeAsStringSync(_codegen.generateLevelDart(
        levelName: name,
        actors: [
          for (final a in actors)
            LuminaAsset(
              assetId: '${a['id'] ?? ''}',
              name: '${a['name'] ?? 'Actor'}',
              type: AssetType.actor,
              metadata: {'type': '${a['type'] ?? 'actor'}'},
            ),
        ],
        actorMaps: actors,
        environment: meta?['environment'] is Map ? Map<String, dynamic>.from(meta!['environment'] as Map) : null,
        projectDir: projectDir,
      ));
      written.add('lib/levels/${dartFileName(name)}');
    }
    final registry = _codegen.writeProjectBlueprintRegistry(projectDir);
    final activeLevel = project.activeLevel.split('/').last.replaceAll('.lmas', '');
    final levelNames = DartCodeGeneratorService.generatedLevelNames(projectDir);
    final gameMode = _gameModeSource(project.mapsAndModes.defaultGameMode, lib);
    File('${lib.path}/main.dart').writeAsStringSync(_codegen.generateMainDart(
      projectName: project.projectName,
      levelName: activeLevel.isEmpty ? 'L_DefaultLevel' : activeLevel,
      gameModeClass: gameMode?.$1,
      gameModeImport: gameMode?.$2,
      widgetLibrary: UmgWidgetLibraryService.effectiveLibrary(projectDir, project),
      gravityZ: project.physics.gravityZ,
      mapsAndModes: project.mapsAndModes,
      hasBlueprints: File('${lib.path}/actors/actors.g.dart').existsSync(),
      projectInput: File('${lib.path}/input/project_input.g.dart').existsSync(),
      blueprintFunctions: File('${lib.path}/blueprint/blueprint_functions.g.dart').existsSync(),
      widgetClasses: File('${lib.path}/widgets/${UmgWidgetCodegen.kWidgetRegistryFileName}').existsSync(),
      blueprintRegistry: registry,
      levelNames: levelNames,
    ));
    written.add('lib/main.dart');
    return written;
  }

  /// The Dart class and `lib/`-relative file of a class-named default game
  /// mode, as the editor's Save Level resolves it; null for the engine
  /// default, a Blueprint game mode, or a class not declared under `lib/`.
  static (String, String)? _gameModeSource(String className, Directory lib) {
    if (className.isEmpty || className == 'LuminaGameMode' || className.endsWith('.lmas')) return null;
    final declaration = RegExp('^\\s*class\\s+${RegExp.escape(className)}\\b', multiLine: true);
    final files = lib.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')).toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final f in files) {
      if (declaration.hasMatch(f.readAsStringSync())) {
        // An import path: '/'-separated on every host.
        return (className, f.path.substring(lib.path.length + 1).replaceAll(r'\', '/'));
      }
    }
    return null;
  }

  /// Copies the template's `LICENSE-<Listing>.txt` into the project's
  /// `contents/Marketplace/` and records the listing in its `licenses.json`;
  /// returns the notice's project path, or null for a template without a
  /// Marketplace record.
  static String? _keepLicense(InstalledGameTemplate t, String projectDir) {
    final record = t.record;
    if (record == null) return null;
    final notice = t.licenseNotice;
    final rel = 'contents/Marketplace/${notice == null ? 'LICENSE-${t.folderName}.txt' : notice.uri.pathSegments.last}';
    final out = File('$projectDir/$rel')..parent.createSync(recursive: true);
    if (notice != null) {
      notice.copySync(out.path);
    } else {
      out.writeAsStringSync('${record.title} ${record.version}\n'
          'Publisher: ${record.publisherDisplayName} (@${record.publisherUsername})\n'
          'Source: ${record.source}\n\n'
          '${record.licenses.map((l) => '${l.kind.label} license: ${l.name} (${l.id})\n  Text: ${l.url}').join('\n')}\n');
    }
    MarketplaceLicenseRecords(File('$projectDir/contents/Marketplace/licenses.json')).upsert(MarketplaceInstallRecord(
      listingId: record.listingId,
      slug: record.slug,
      title: record.title,
      version: record.version,
      category: record.category,
      installKind: record.installKind,
      publisherUsername: record.publisherUsername,
      publisherDisplayName: record.publisherDisplayName,
      // Where the project came from; the project's own licenses.json only
      // carries the notice (the Marketplace window lists asset installs
      // from it, not templates).
      installedTo: t.dir,
      licenseFile: rel,
      licenses: record.licenses,
      installedAt: DateTime.now().toUtc(),
      source: record.source,
    ));
    return rel;
  }
}

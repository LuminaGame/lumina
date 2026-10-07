import 'dart:io';

import 'package:lumina_core/lumina_core.dart';
import 'package:lumina_editor_data/src/repositories/project_repository.dart';
import 'package:lumina_editor_data/src/services/code_generator_service.dart';
import 'package:lumina_editor_data/src/domain/models/use_case_results.dart';
import 'package:lumina_editor_data/src/domain/use_cases/use_case_validation.dart';

/// Generates the live declarative Dart code for a level (`lib/main.dart` +
/// `lib/levels/<level_name>.dart`, [dartFileName]) via [DartCodeGeneratorService] and, when a
/// [LuminaProject] is supplied, clears its dirty flag and stamps
/// `lastCodeGeneratedTimestamp` through [ProjectRepository.saveProject].
class GenerateDartCodeUseCase {
  static const String _source = 'CodeGen';

  final DartCodeGeneratorService _codeGenerator;
  final ProjectRepository _projectRepository;
  final EngineLoggerService _logger;

  GenerateDartCodeUseCase({
    DartCodeGeneratorService? codeGenerator,
    ProjectRepository? projectRepository,
    EngineLoggerService? logger,
  })  : _codeGenerator = codeGenerator ?? DartCodeGeneratorService(),
        _projectRepository = projectRepository ?? ProjectRepository(),
        _logger = logger ?? EngineLoggerService();

  Future<GenerateDartCodeResult> call({
    required String projectDir,
    required String levelName,
    required List<Map<String, dynamic>> actors,
    LuminaProject? project,
    Map<String, dynamic>? environment,
  }) async {
    final validation = validateProjectDir(projectDir) ?? validateLevelName(levelName);
    if (validation != null) {
      _logger.log('Code generation rejected: $validation', level: 'error', source: _source);
      return GenerateDartCodeResult.failure(validation);
    }

    final projectName = project?.projectName ?? Uri.directory(projectDir).pathSegments.where((s) => s.isNotEmpty).last;
    _logger.log('Generating Dart code for level "$levelName" of "$projectName"...', source: _source);

    try {
      final libDir = Directory('$projectDir/lib');
      if (!libDir.existsSync()) libDir.createSync(recursive: true);
      final levelsDir = Directory('${libDir.path}/levels');
      if (!levelsDir.existsSync()) levelsDir.createSync(recursive: true);

      // Enum / interface sources and the project Blueprint
      // registry, before the launcher that registers it (generated files of
      // earlier versions are migrated to snake_case first).
      final blueprintRegistry = _codeGenerator.writeProjectBlueprintRegistry(projectDir);
      _codeGenerator.writeProjectInputDart(projectDir, project?.input);
      // Every level already generated can be opened (Open Level).
      final levelNames = DartCodeGeneratorService.generatedLevelNames(projectDir);

      final mainFile = File('${libDir.path}/main.dart');
      mainFile.writeAsStringSync(_codeGenerator.generateMainDart(
        projectName: projectName,
        levelName: levelName,
        widgetLibrary: UmgWidgetLibraryService.effectiveLibrary(projectDir, project),
        gravityZ: project?.physics.gravityZ ?? const ProjectPhysicsSettings().gravityZ,
        // Registered once the scanner wrote the registration.
        blueprintFunctions: File('${libDir.path}/blueprint/blueprint_functions.g.dart').existsSync(),
        // The compiled widget classes, once the designer wrote them.
        widgetClasses: File('${libDir.path}/widgets/widget_registry.g.dart').existsSync(),
        blueprintRegistry: blueprintRegistry,
        levelNames: levelNames,
      ));

      final assetActors = actors
          .map((a) => LuminaAsset(
                assetId: (a['id'] ?? '').toString(),
                name: (a['name'] ?? 'Actor').toString(),
                type: AssetType.actor,
                metadata: {'type': (a['type'] ?? 'actor').toString()},
              ))
          .toList();
      final levelFile = File('${levelsDir.path}/${dartFileName(levelName)}');
      levelFile.writeAsStringSync(_codeGenerator.generateLevelDart(
        levelName: levelName,
        actors: assetActors,
        actorMaps: actors,
        environment: environment,
        // Mesh assets named by project path resolve here.
        projectDir: projectDir,
      ));

      LuminaProject? updated;
      if (project != null) {
        updated = project.copyWith(
          isDirty: false,
          lastCodeGeneratedTimestamp: DateTime.now().toIso8601String(),
        );
        await _projectRepository.saveProject(updated, projectDir);
        final manifest = File('$projectDir/${updated.projectName}.lmproject');
        if (!manifest.existsSync()) {
          _logger.log('Manifest was not written: ${manifest.path}', level: 'error', source: _source);
          return GenerateDartCodeResult.failure('Failed to write ${manifest.path}');
        }
      }

      _logger.log('Dart code written: ${mainFile.path}, ${levelFile.path}', level: 'success', source: _source);
      return GenerateDartCodeResult.success(
        mainDartPath: mainFile.path,
        levelDartPath: levelFile.path,
        writtenFiles: [mainFile.path, levelFile.path],
        updatedProject: updated,
      );
    } on IOException catch (e) {
      _logger.log('Code generation failed: $e', level: 'error', source: _source);
      return GenerateDartCodeResult.failure('Code generation failed: $e');
    }
  }
}

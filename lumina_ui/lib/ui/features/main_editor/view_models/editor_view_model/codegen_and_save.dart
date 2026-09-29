part of '../editor_view_model.dart';

/// Saving: auto-save + Dart code generation, asset saves, the editor layout,
/// and the Build Manager / cook hooks.
mixin _EditorCodegenAndSave on _EditorViewModelState {
  @override
  Future<void> saveLevelAndGenerateCode() async {
    ProjectRepository.ensurePubspecAssets(projectDirPath);
    // One save. The unawaited second save `clearDirtyFlag()` used to start
    // here finished after this returned and, if the level had changed by
    // then, put the old one back.
    await _autoSaveAndGenerateCode(_project);
  }

  /// Build → Generate Dart Code, awaited: saves the level and
  /// regenerates the game's Dart code; returns the Dart files written (the
  /// ones [cookCodeGenerator] names), absolute.
  @override
  Future<List<String>> generateDartCode() async {
    await _autoSaveAndGenerateCode(_project);
    return [
      '$projectDirPath/lib/main.dart',
      '$projectDirPath/lib/levels/${dartFileName(activeLevelName)}',
    ];
  }

  /// `(className, importPath)` of the project's game mode [className], with the
  /// import relative to [libDir] — or null for the engine's `LuminaGameMode`,
  /// or when no file under `lib/` declares the class any more (so the
  /// launcher still compiles).
  (String, String)? _gameModeSource(String className, Directory libDir) {
    if (className.isEmpty || className == 'LuminaGameMode') return null;
    final declaration = RegExp('^\\s*class\\s+${RegExp.escape(className)}\\b', multiLine: true);
    final libPath = libDir.absolute.path;
    final files = libDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final file in files) {
      try {
        if (declaration.hasMatch(file.readAsStringSync())) {
          final relative = file.absolute.path.substring(libPath.length + 1).replaceAll(r'\', '/');
          return (className, relative);
        }
      } catch (_) {}
    }
    _logger.log(
      'Default game mode $className is not declared under lib/; main.dart falls back to LuminaGameMode.',
      level: 'warning',
      source: 'SaveLevel',
    );
    return null;
  }

  Future<LuminaProject> _autoSaveAndGenerateCode(
    LuminaProject currentProject,
  ) async {
    _logger.log(
      'Executing Save Level & writing live Dart code to disk...',
      level: 'info',
      source: 'SaveLevel',
    );

    final contentsLevelDir = Directory('$projectDirPath/contents/levels');
    if (!contentsLevelDir.existsSync())
      contentsLevelDir.createSync(recursive: true);

    // Ensure all environment actors have a LuminaSkyComponent so both the
    // .lmas metadata and generated Dart code carry the sky and lighting settings.
    for (final actor in _actors) {
      if (EditorSceneEnvironment.isEnvironmentActor(actor.type) &&
          EditorSceneEnvironment.componentOf(actor) == null) {
        final initialProps = _levelEnvironment['sky'] is Map
            ? Map<String, dynamic>.from(_levelEnvironment['sky'] as Map)
            : null;
        actor.components.add(
          EditorSceneEnvironment.seedSkyComponent(actor.id, initialProperties: initialProps),
        );
      }
    }

    // Save contents/levels/$activeLevelName.lmas level asset container on disk.
    // The sections the level editor owns are written from memory; every
    // other key of the level on disk is kept, and the Level Blueprint
    // (`metadata.levelBlueprint`) is the one the editor
    // knows — the disk's when the editor has none.
    final levelFile = File('${contentsLevelDir.path}/$activeLevelName.lmas');
    final previous = levelFile.existsSync()
        ? LuminaLevelDocument.tryParse(levelFile.readAsStringSync(), relativePath: 'contents/levels/$activeLevelName.lmas')
        : null;
    const editorOwned = {'actors', 'environment', 'navigation', 'worldPartition', 'levelBlueprint'};
    final carried = <String, dynamic>{
      for (final e in (previous?.metadata ?? const <String, dynamic>{}).entries)
        if (!editorOwned.contains(e.key)) e.key: e.value,
    };
    final storedBlueprint = _levelBlueprintMeta ?? previous?.metadata[LuminaLevelBlueprintDocument.metadataKey];
    final levelAssetMap = {
      'assetId': 'level_$activeLevelName',
      'name': activeLevelName,
      'type': 'level',
      'relativePath': 'contents/levels/$activeLevelName.lmas',
      'rawPayload': null,
      'metadata': {
        ...carried,
        'actors': _actors.map((a) => a.toMap()).toList(),
        if (_levelEnvironment.isNotEmpty) 'environment': _levelEnvironment,
        if (_levelNavigation.isNotEmpty) 'navigation': _levelNavigation,
        if (_levelWorldPartition.isNotEmpty)
          'worldPartition': _levelWorldPartition,
        if (storedBlueprint is Map) LuminaLevelBlueprintDocument.metadataKey: storedBlueprint,
      },
    };
    levelFile.writeAsStringSync(jsonEncode(levelAssetMap));
    final levelBlueprint = LuminaLevelBlueprintDocument.fromLevelMetadata(
      levelAssetMap['metadata'],
      levelPath: 'contents/levels/$activeLevelName.lmas',
    );

    final libDir = Directory('$projectDirPath/lib');
    if (!libDir.existsSync()) libDir.createSync(recursive: true);
    // Generated files an earlier version named after their assets
    // (`lib/levels/L_Main.dart`) become snake_case first (`l_main.dart`).
    LuminaGeneratedCodeMigration.migrate(projectDirPath);

    // The launcher installs the project's default game mode: without
    // it a Third Person game spawns a bare pawn instead of its character.
    final gameMode = _gameModeSource(
      currentProject.mapsAndModes.defaultGameMode,
      libDir,
    );
    final mainContent = _codeGen.generateMainDart(
      projectName: currentProject.projectName,
      levelName: activeLevelName,
      gameModeClass: gameMode?.$1,
      gameModeImport: gameMode?.$2,
      // Shadcn only when the game's pubspec can build it.
      widgetLibrary: UmgWidgetLibraryService.effectiveLibrary(projectDirPath, currentProject),
      gravityZ: currentProject.physics.gravityZ,
      // 06: a GameMode Blueprint, the Maps & Modes Default
      // Pawn Class, the compiled Blueprint factories and the project input
      // the Blueprint pawns bind to.
      mapsAndModes: currentProject.mapsAndModes,
      hasBlueprints: File('${libDir.path}/actors/actors.g.dart').existsSync(),
      projectInput: File('${libDir.path}/input/project_input.g.dart').existsSync(),
      // the project's exposed Dart
      // functions, registered for the Blueprint VM before the world starts.
      blueprintFunctions: File('${libDir.path}/blueprint/blueprint_functions.g.dart').existsSync(),
      // The compiled widget classes, registered before the
      // world starts so Create Widget renders them over the game.
      widgetClasses: File('${libDir.path}/widgets/${UmgWidgetCodegen.kWidgetRegistryFileName}').existsSync(),
    );
    File('${libDir.path}/main.dart').writeAsStringSync(mainContent);

    final levelDir = Directory('${libDir.path}/levels');
    if (!levelDir.existsSync()) levelDir.createSync(recursive: true);

    final assetActors = _actors
        .map(
          (a) => LuminaAsset(
            assetId: a.id,
            name: a.name,
            type: AssetType.actor,
            metadata: {'type': a.type},
          ),
        )
        .toList();

    final levelContent = _codeGen.generateLevelDart(
      levelName: activeLevelName,
      actors: assetActors,
      // Full editor actor maps (transforms, lights, meshes, sky components) and
      // the Environment Lighting section so the shipped game reproduces the
      // editor's look.
      actorMaps: _actors.map((a) => a.toMap()).toList(),
      environment: _levelEnvironment.isEmpty ? null : _levelEnvironment,
      // Open World levels: the subsystem registration, the authored cell grid
      // and the streaming sources come straight out of this section.
      worldPartition: _levelWorldPartition.isEmpty
          ? null
          : _levelWorldPartition,
      // The level's Blueprint becomes its generated
      // level script, without editor-only nodes; the
      // project resolves its placed Blueprint classes and input actions.
      projectDir: projectDirPath,
      levelBlueprint: LuminaLevelBlueprintDocument(
        levelPath: levelBlueprint.levelPath,
        blueprint: BlueprintEditorNodes.forEngine(levelBlueprint.blueprint),
      ),
    );
    File(
      '${levelDir.path}/${dartFileName(activeLevelName)}',
    ).writeAsStringSync(levelContent);

    final updatedProject = currentProject.copyWith(
      isDirty: false,
      lastCodeGeneratedTimestamp: DateTime.now().toIso8601String(),
    );

    await _projectRepo.saveProject(updatedProject, projectDirPath);
    // A save that finishes after another level was opened must not
    // bring the saved level back or mark the new one clean.
    if (_project.activeLevel == updatedProject.activeLevel) {
      _project = updatedProject;
    } else {
      _projectRepo.saveProject(_project, projectDirPath);
      notifyListeners();
      return updatedProject;
    }
    _refreshAssets();
    _logger.log(
      'Save Level complete. Level asset "$activeLevelName.lmas" and Dart code saved on disk.',
      level: 'success',
      source: 'SaveLevel',
    );
    notifyListeners();
    return updatedProject;
  }

  void _loadLayoutState() {
    try {
      final file = File('$projectDirPath/.lumina/editor_layout.json');
      if (file.existsSync()) {
        final content = file.readAsStringSync();
        final json = jsonDecode(content);
        layoutState = EditorLayoutState.fromJson(json);
      } else {
        layoutState = EditorLayoutState();
      }
    } catch (e) {
      _logger.log(
        'Failed to load layout state, using defaults: $e',
        level: 'warning',
        source: 'Layout',
      );
      layoutState = EditorLayoutState();
    }
  }

  Future<void> saveAsset(LuminaAsset asset) async {
    try {
      // Find the relative path from the actual file structure or use a fallback
      final file = File(
        '$projectDirPath/contents/${asset.type.name}s/${asset.name}.lmas',
      );
      if (!file.parent.existsSync()) file.parent.createSync(recursive: true);
      file.writeAsBytesSync(asset.toProtoBufferBytes());

      final tabIndex = _openTabs.indexWhere((t) => t.asset == asset);
      if (tabIndex != -1) {
        _openTabs[tabIndex].isDirty = false;
        notifyListeners();
      }
      _logger.log(
        'Saved asset ${asset.name} to disk.',
        level: 'success',
        source: 'AssetRepository',
      );
    } catch (e) {
      _logger.log('Failed to save asset ${asset.name}: $e', level: 'error');
    }
  }

  /// Pins the bottom panel into the layout, or unpins it
  /// into a Content Drawer, which closes and is reopened from the status
  /// bar's folder button.
  void setBottomPinned(bool pinned) {
    layoutState.bottomPinned = pinned;
    if (!pinned) layoutState.bottomVisible = false;
    saveLayoutState();
  }

  /// Opens or closes the bottom panel (the Content Drawer
  /// while unpinned).
  void toggleContentDrawer() {
    layoutState.bottomVisible = !layoutState.bottomVisible;
    saveLayoutState();
  }

  /// A splitter drag ended; the pane's new size is persisted
  /// (one write per drag). [outlinerWidth] is the left column, [detailsHeight]
  /// the Details pane under the Outliner, [bottomHeight] the bottom panel,
  /// [sourcesWidth] the Content Browser's Sources rail (all
  /// clamped to their limits).
  void setPaneSize({double? outlinerWidth, double? detailsHeight, double? bottomHeight, double? sourcesWidth, double? rightWidth}) {
    // The right dock's width.
    if (rightWidth != null) layoutState.rightWidth = EditorLayoutState.clampRightWidth(rightWidth);
    if (outlinerWidth != null) layoutState.outlinerWidth = outlinerWidth;
    if (detailsHeight != null) layoutState.detailsHeight = detailsHeight;
    if (bottomHeight != null) layoutState.bottomHeight = bottomHeight;
    if (sourcesWidth != null) layoutState.sourcesWidth = EditorLayoutState.clampSourcesWidth(sourcesWidth);
    _writeLayoutState();
  }

  @override
  void saveLayoutState() {
    notifyListeners();
    _writeLayoutState();
  }

  @override
  void _writeLayoutState() {
    try {
      final dir = Directory('$projectDirPath/.lumina');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final file = File('${dir.path}/editor_layout.json');
      file.writeAsStringSync(jsonEncode(layoutState.toJson()));
    } catch (e) {
      _logger.log(
        'Failed to save layout state: $e',
        level: 'error',
        source: 'Layout',
      );
    }
  }

  void clearDirtyFlag() {
    _autoSaveAndGenerateCode(_project);
  }

  /// One Build Manager view model per editor so the Build menu and the
  /// Build Manager tab drive the same pipeline. Cook's code-gen pass goes
  /// through [saveLevelAndGenerateCode] so unsaved actors are included.
  @override
  BuildManagerViewModel
  get buildManagerViewModel => _buildManagerVm ??= BuildManagerViewModel(
    projectDirPath: projectDirPath,
    projectProvider: () => _project,
    logger: _logger,
    codeGenerator: cookCodeGenerator,
    processStarter: buildProcessStarter,
    hostTargets: buildHostTargets,
    onRevealIssue: (issue) => revealAssetInContentBrowser(issue.assetPath),
    onTargetsChanged: (targets) => unawaited(setPackagingTargets(targets)),
  );

  /// The code-generation pass a cook runs first: the editor saves the open
  /// level (unsaved actors included) and regenerates the game's Dart code.
  /// Shared by the Build Manager and Project Settings' Package Project.
  Future<CookCodeGenOutcome> cookCodeGenerator(BuildStepContext ctx) async {
    await saveLevelAndGenerateCode();
    return CookCodeGenOutcome(
      true,
      'Saved level "$activeLevelName" and generated lib/main.dart + lib/levels/${dartFileName(activeLevelName)}',
      writtenFiles: [
        '$projectDirPath/lib/main.dart',
        '$projectDirPath/lib/levels/${dartFileName(activeLevelName)}',
      ],
    );
  }

  /// Ticks the project's packaging targets (the Build Manager's list) and
  /// saves the `.lmproject`, so Project Settings reads the same selection.
  Future<void> setPackagingTargets(List<String> targets) async {
    _project = _project.copyWith(packaging: _project.packaging.copyWith(targets: targets));
    notifyListeners();
    await _projectRepo.saveProject(_project, projectDirPath);
    _logger.log(
      'Packaging targets: ${targets.isEmpty ? 'none' : targets.map(packagingPlatformLabel).join(', ')}',
      level: 'info',
      source: 'ProjectSettings',
    );
  }

  @override
  Future<void> _cookAndPackageFromMenu() async {
    final vm = buildManagerViewModel;
    if (vm.hostTargets == null) await vm.init();
    await vm.cookAndPackage();
  }
}

part of '../project_repository.dart';

/// Creating a project: the step-by-step pipeline, the Third Person
/// template content and the convenience wrapper that awaits it.
mixin _ProjectCreation {
  EngineLoggerService get _logger;
  ProcessRunner get processRunner;
  String? get enginePackageDir;
  Future<void> addRecentProject(LuminaProject project, {required String projectDir, String? coverImage});
  Future<LuminaProject?> loadProject(String lmprojectPath);

  /// Executes the 7-step project creation pipeline, streaming live progress events.
  Stream<ProjectCreationProgress> createProjectStream({
    required String projectName,
    required String projectLocation,
    String template = kBlank3dTemplateId,
    String widgetLibrary = kUmgWidgetLibraryShadcn,
  }) async* {
    final nameError = ProjectRepository.validateProjectName(projectName);
    if (nameError != null) {
      throw ProjectCreationException(ProjectCreationStep.folderSetup, nameError);
    }
    final locError = ProjectRepository.validateLocation(projectLocation);
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
      // Remove flutter create's counter template test which expects non-existent MyApp
      final defaultWidgetTest = File('${targetDir.path}/test/widget_test.dart');
      if (defaultWidgetTest.existsSync()) {
        try {
          defaultWidgetTest.deleteSync();
        } catch (_) {}
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
          luminaPackageDir: enginePackageDir ?? ProjectRepository.luminaPackagePath,
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
        // No engine checkout here (an installed Studio): the engine comes
        // from git, so say where it was fetched from and how to use a local one.
        final source = link.isLocal
            ? ''
            : ' The engine is fetched from git (${LuminaWorkspace.engineRepo ?? kLuminaGitUrl}) because this Lumina Studio '
                'has no local engine checkout; check the network, or point LUMINA_WORKSPACE at a Lumina checkout.';
        throw ProjectCreationException(ProjectCreationStep.pubGet, 'flutter pub get failed: ${pubGetResult.stderr}$source');
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

      final levelCode = await codeGenService.generateLevelDartAsync(
        levelName: 'L_DefaultLevel',
        actors: [],
        actorMaps: seededActors,
        projectDir: targetDir.path,
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
  ///
  /// The bundle is read from the engine the editor runs from, else from the
  /// `lumina` package the project's own `pub get` resolved (an installed
  /// Studio with no engine checkout: the git dependency's checkout in the
  /// pub cache, which carries the committed template content).
  Future<void> _writeMannequinContent(String projectDir) async {
    final engine = File('${enginePackageDir ?? ProjectRepository.luminaPackagePath}/${LuminaThirdPersonContent.bundledMeshPath}');
    final resolved = LuminaWorkspace.resolvedPackageDir(projectDir, 'lumina');
    final bundle = [
      engine,
      if (resolved != null) File('$resolved/${LuminaThirdPersonContent.bundledMeshPath}'),
    ].firstWhere((f) => f.existsSync(), orElse: () => engine);
    if (!bundle.existsSync()) {
      throw ProjectCreationException(
        ProjectCreationStep.manifestAndLevel,
        'Third Person template content is missing: ${bundle.path}'
        '${resolved == null ? '' : ' (nor in the resolved lumina package at $resolved)'}. Build it with '
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
}

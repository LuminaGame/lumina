part of '../pie_controller.dart';

/// Blueprints in Play: the class registry, the preflight, the game Play
/// mounts, the widget classes, widget graphs and Blueprint assets registered
/// first, and Blueprint debugging (project-code notices, breakpoints that
/// pause Play, the instances handed to the Blueprint debugger).
mixin _PieBlueprintsInPlay {
  // Provided by PieController.
  EditorViewModel get viewModel;
  EditorPieGame? get _game;
  String? get _playingLevel;
  bool get isPlaying;
  bool get isPaused;
  void pause();
  GameTemplateKind templateKindForProject();
  BoundProjectInput boundInputForProject();
  String? mannequinPathForProject();

  // --- Blueprints in Play -----------------------------

  EditorBlueprintClassRegistry? _registry;

  /// The registry the next Play resolves Blueprint classes through: the
  /// project's `.lmas` files, with open Blueprint editors' documents as they
  /// are in the editor.
  EditorBlueprintClassRegistry get registry => _registry ??= EditorBlueprintClassRegistry(
        viewModel.projectDirPath,
        inputActions: boundInputForProject().actions.values.toList(),
        openDocuments: () => viewModel.openBlueprintDocuments,
      );

  /// Play's compile step without the editors: loads and validates every
  /// Blueprint class Play will use. Empty when Play can start.
  List<PlayBlocker> preflight({List<PlayBlocker>? warnings}) {
    _registry = null; // the manifest's input actions may have changed
    registerWidgetClasses();
    registerBlueprintAssets();
    return BlueprintPlayPreflight.validate(
      registry,
      viewModel.project.mapsAndModes,
      [
        for (final a in viewModel.actors)
          if (a.blueprintClass != null && a.blueprintClass!.isNotEmpty) a.blueprintClass!,
      ],
      warnings: warnings,
    );
  }

  EditorPieGame createGame(List<EditorActorNode> actors, {BoundProjectInput? input, String? levelPath}) {
    final templateKind = templateKindForProject();
    final logged = <String>{};
    registerWidgetClasses();
    registerWidgetScripts();
    registerBlueprintAssets();
    // Simulating components inherit their static mesh's
    // mass (the Static Mesh editor's `metadata.physics`), read fresh.
    final projectDir = viewModel.projectDirPath;
    LuminaBlueprintComponents.meshPhysicsResolver = (stored) => MeshPhysicsService.forMeshAsset(stored, projectDir: projectDir);
    // Blueprints name assets project-relative (a Set Material node's
    // `contents/materials/…`); Play reads them from this project.
    LuminaAssets.projectDir = projectDir;
    return EditorPieGame(
      actors,
      templateKind: templateKind,
      input: input ?? boundInputForProject(),
      mannequinMeshPath: templateKind == GameTemplateKind.thirdPerson ? mannequinPathForProject() : null,
      registry: registry,
      mapsAndModes: viewModel.project.mapsAndModes,
      onBlueprintInstance: (instance) => _attachProjectCodeNotice(instance, logged),
      levelScript: levelScriptFor(levelPath ?? _playingLevel ?? viewModel.project.activeLevel, actors),
    );
  }

  /// The script of [levelPath]'s Level Blueprint over
  /// the placed [actors], or null when the level has none. One with compile
  /// errors does not run; the Output Log names them.
  LuminaBlueprintLevelScript? levelScriptFor(String levelPath, List<EditorActorNode> actors) {
    if (levelPath.isEmpty) return null;
    final cls = registry.levelClassFor(levelPath, actorMaps: [for (final a in actors) a.toMap()]);
    if (cls == null) return null;
    if (cls.hasErrors) {
      viewModel.logger.log(
        'The Level Blueprint of ${cls.name} has errors and does not run: '
        '${cls.diagnostics.where((d) => d.isError).map((d) => d.message).join('; ')}',
        level: 'warning',
        source: 'PIE',
      );
      return null;
    }
    viewModel.logger.log('Level Blueprint of ${cls.name} runs in Play', level: 'info', source: 'PIE');
    return cls.instantiateLevelScript(key: LuminaObjectKey('${cls.name}_script'));
  }

  /// Makes the project's widget Blueprints known to the runtime before Play:
  /// `Create Widget` seeds each instance's per-element
  /// state (`elements.FPSCounter.text`) from the class registered here, read
  /// fresh from the `.lmas` files so the designer's last save is what plays.
  void registerWidgetClasses() {
    final classes = WidgetClassCatalog.scanWidgetClasses(viewModel.projectDirPath).toList();
    for (final open in viewModel.openWidgetEditors) {
      if (open.isLoaded) {
        final name = UmgWidgetCodegen.fileBaseName(open.fileBasename);
        final inMemClass = WidgetClassCatalog.fromUmgDocument(name, open.document);
        final index = classes.indexWhere((c) => c.name == name);
        if (index >= 0) {
          classes[index] = inMemClass;
        } else {
          classes.add(inMemClass);
        }
      }
    }
    LuminaWidgetClassRegistry.registerAll(classes);
    if (classes.isNotEmpty) {
      viewModel.logger.log(
        'Registered ${classes.length} widget class${classes.length == 1 ? '' : 'es'}: ${classes.map((c) => c.name).join(', ')}',
        level: 'info',
        source: 'PIE',
      );
    }
  }

  /// Every widget graph plays in the VM (an open designer's
  /// as it is in the editor, the others as saved) — `Create
  /// Widget` gives each instance a `LuminaBlueprintUserWidget` over it, as the
  /// built game's registry gives it the compiled `WBP<Name>Graph`. A graph
  /// with errors does not run; the Output Log names them.
  void registerWidgetScripts() {
    LuminaUserWidgets.clear();
    final input = boundInputForProject().actions.values.toList();
    final names = <String>[];
    final documents = UmgWidgetCodegen.widgetDocuments(viewModel.projectDirPath);
    for (final open in viewModel.openWidgetEditors) {
      if (open.isLoaded) documents[UmgWidgetCodegen.fileBaseName(open.fileBasename)] = open.documentForPlay;
    }
    for (final e in documents.entries) {
      final graph = UmgWidgetCodegen.widgetGraphOf(e.value, e.key);
      if (graph == null) continue;
      final cls = LuminaBlueprintClass.forWidget(graph, inputActions: input);
      if (cls.hasErrors) {
        viewModel.logger.log(
          'The graph of ${e.key} has errors and does not run: ${cls.diagnostics.where((d) => d.isError).map((d) => d.message).join('; ')}',
          level: 'warning',
          source: 'PIE',
        );
        continue;
      }
      LuminaUserWidgets.register(e.key, cls.instantiateUserWidget);
      names.add(e.key);
    }
    if (names.isNotEmpty) {
      viewModel.logger.log('Widget graphs run in Play: ${names.join(', ')}', level: 'info', source: 'PIE');
    }
  }

  // --- Blueprint registries and host hooks -----------

  /// Makes the project's Blueprint assets known to the runtime before Play,
  /// as a built game's `registerProjectBlueprints()` does: enums, interfaces,
  /// save-game classes, montages and particle templates from the `.lmas`
  /// files, and every actor Blueprint class (compiled through [registry], so
  /// an open editor's document plays) for `Spawn Actor from Class`.
  void registerBlueprintAssets() {
    final assets = LuminaProjectBlueprintAssets.scan(viewModel.projectDirPath);
    assets.registerRuntime();
    final spawnable = registry.registerActorClasses(assets.actorClasses);
    final counts = [
      if (spawnable.isNotEmpty) '${spawnable.length} actor class${spawnable.length == 1 ? '' : 'es'}',
      if (assets.enums.isNotEmpty) '${assets.enums.length} enum${assets.enums.length == 1 ? '' : 's'}',
      if (assets.interfaces.isNotEmpty) '${assets.interfaces.length} interface${assets.interfaces.length == 1 ? '' : 's'}',
      if (assets.saveGameClasses.isNotEmpty) '${assets.saveGameClasses.length} save-game class${assets.saveGameClasses.length == 1 ? '' : 'es'}',
      if (assets.montages.isNotEmpty) '${assets.montages.length} montage${assets.montages.length == 1 ? '' : 's'}',
      if (assets.particleTemplates.isNotEmpty) '${assets.particleTemplates.length} particle template${assets.particleTemplates.length == 1 ? '' : 's'}',
    ];
    if (counts.isNotEmpty) {
      viewModel.logger.log('Registered Blueprint assets: ${counts.join(', ')}', level: 'info', source: 'PIE');
    }
  }

  String? _debugSelection;

  /// A Blueprint instance whose graph calls a project
  /// function (declared from the project's manifest, never run in the editor)
  /// says so in the Output Log the first time such a node is reached —
  /// lumina's VM skips it with zero outputs and plays the rest of the graph.
  /// A `breakpoint` node reached by any instance pauses
  /// Play and frames the node. Attached as each instance is created, before
  /// its BeginPlay.
  void _attachProjectCodeNotice(LuminaBlueprintInstance instance, Set<String> logged) {
    final cls = instance.blueprintClass;
    final graph = cls.document.eventGraph;
    final hasDeclaredOnly = graph.nodes.any((n) => LuminaBlueprintFunctionRegistry.isDeclaredOnly(n.registryId));
    final hasBreakpoint = _classHasBreakpoint(cls);
    if (!hasDeclaredOnly && !hasBreakpoint) return;
    instance.trace = (event) {
      if (hasBreakpoint && event.registryId == 'breakpoint') {
        _hitBreakpoint(cls, event.nodeId);
        return;
      }
      if (!hasDeclaredOnly || !LuminaBlueprintFunctionRegistry.isDeclaredOnly(event.registryId)) return;
      if (!logged.add('${cls.name}|${event.nodeId}')) return;
      final title = graph.node(event.nodeId)?.title ?? event.registryId;
      viewModel.logger.log(
        '${cls.name}: $title ${LuminaBlueprintFunctionRegistry.unavailableMessage}; skipped in the editor.',
        level: 'warning',
        source: 'PIE',
      );
    };
  }

  static bool _classHasBreakpoint(LuminaBlueprintClass cls) {
    bool any(LuminaBlueprintGraph g) => g.nodes.any((n) => n.registryId == 'breakpoint');
    final doc = cls.document;
    return any(doc.eventGraph) || doc.functions.any((f) => any(f.graph)) || doc.macros.any((m) => any(m.graph));
  }

  /// The project-relative `.lmas` of Blueprint class [name]
  /// (`contents/blueprints/<name>.lmas`, else the first match under contents/).
  String? _blueprintPathOf(String name) {
    final direct = 'contents/blueprints/$name.lmas';
    if (File('${viewModel.projectDirPath}/$direct').existsSync()) return direct;
    final contents = Directory('${viewModel.projectDirPath}/contents');
    if (!contents.existsSync()) return null;
    for (final f in contents.listSync(recursive: true, followLinks: false)) {
      if (f is File && f.path.replaceAll(r'\', '/').endsWith('/$name.lmas')) {
        return f.path.substring(viewModel.projectDirPath.length + 1).replaceAll(r'\', '/');
      }
    }
    return null;
  }

  /// The breakpoint Play last stopped on (null when none, or after resume).
  BlueprintBreakpointHit? get breakpointHit => BlueprintBreakpoints.instance.current;

  void _hitBreakpoint(LuminaBlueprintClass cls, String nodeId) {
    if (!isPlaying || isPaused) return;
    final path = _blueprintPathOf(cls.name) ?? 'contents/blueprints/${cls.name}.lmas';
    if (!BlueprintBreakpoints.instance.hit(path, nodeId)) return;
    final title = cls.document.eventGraph.node(nodeId)?.title ?? 'Breakpoint';
    viewModel.logger.log('Breakpoint hit in ${cls.name} ($title): Play paused. Resume or step to continue.', level: 'warning', source: 'PIE');
    pause();
    // Frame the node in the Blueprint editor showing this class (or the
    // docked debug panel); the editor opens on demand from the log line.
    BlueprintNavigation.instance.request(path, nodeId);
    viewModel.notifyListeners();
  }

  /// Hands the running Blueprint instances to the Blueprint debugger: the
  /// level's Blueprint script, the possessed pawn's, and the selected placed
  /// Blueprint actor's.
  void _publishDebugTargets() {
    final game = _game;
    if (game == null) return;
    final targets = <String, LuminaBlueprintInstance>{};
    // The level's Blueprint script, beside the pawn.
    final levelScript = game.gameInstance.world?.persistentLevel.scriptActor;
    final levelPath = _playingLevel ?? viewModel.project.activeLevel;
    if (levelScript is LuminaBlueprintLevelScript && levelPath.isNotEmpty) targets[levelPath] = levelScript;
    final pawn = game.possessedPawn;
    final pawnPath = game.registry?.pawnClassPath(game.mapsAndModes);
    if (pawn is LuminaBlueprintInstance && pawnPath != null) targets[pawnPath] = pawn as LuminaBlueprintInstance;
    final selected = viewModel.primarySelectedActor;
    final placedPath = selected?.blueprintClass;
    final world = game.gameInstance.world;
    if (selected != null && placedPath != null && placedPath.isNotEmpty && world != null) {
      final runtime = world.persistentLevel.actors.where((a) => a.key == LuminaObjectKey(selected.id)).firstOrNull;
      if (runtime is LuminaBlueprintInstance) targets[placedPath] = runtime;
    }
    _debugSelection = selected?.id;
    BlueprintPieDebugger.instance.setTargets(targets);
  }
}

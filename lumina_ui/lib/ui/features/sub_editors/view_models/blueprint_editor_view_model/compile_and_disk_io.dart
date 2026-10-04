part of '../blueprint_editor_view_model.dart';

/// Compiling, the project context (project dir, input actions, meshes)
/// and loading/saving the ACTOR `.lmas` with its project asset scan.
mixin _BlueprintEditorCompileAndDiskIo on _BlueprintEditorViewModelState {

  // ---------------------------------------------------------------------------
  // Compile
  // ---------------------------------------------------------------------------

  /// Compile: lumina's validator and `BlueprintDartGenerator` run on
  /// the document as it is now; the result fills Compiler Results and the
  /// badge, and a clean result is written to the project's `lib/actors/`.
  /// Saving is separate.
  Future<bool> compile() async {
    final projectDir = _findProjectDir(assetPath);
    if (projectDir != null) _inputActions = _readInputActions(projectDir);
    // Typed element pins resolve through the widget class registry:
    // re-read the widget files the designer may have
    // saved since the editor opened.
    _catalog?.refresh();
    _assets?.refresh();
    final docJson = engineDocument.toJson();
    final issues = <LuminaBlueprintDiagnostic>[];
    final service = DartCodeGeneratorService();

    // Anim Classes the meshes name compile first, as the project compile does.
    final animRefs = <String, BlueprintAnimClassRef>{};
    if (projectDir != null) {
      for (final c in _document.components) {
        final animClass = c.properties['animClass'];
        if (c.properties['animMode'] != 'Use Animation Blueprint' || animClass is! String || animClass.isEmpty) continue;
        if (!File('$projectDir/$animClass').existsSync()) continue;
        final anim = await service.compileAndWriteAnimBlueprint(projectDir, animClass);
        final abpName = animClass.split('/').last.replaceAll('.lmas', '');
        for (final d in anim.issues) {
          issues.add(LuminaBlueprintDiagnostic(d.severity, 'Mesh ${c.name} → $abpName: ${d.message}'));
        }
        if (anim.ref != null) animRefs[animClass] = anim.ref!;
      }
    }

    // The real `.lmas` path, which generated code names the class by, and a
    // GameMode's pawn class.
    final abs = File(assetPath).absolute.path;
    final rel = projectDir != null && abs.startsWith('$projectDir/') ? abs.substring(projectDir.length + 1) : null;
    final classRefs = <String, BlueprintClassRef>{};
    final pawn = _document.parentClass == BlueprintEditorViewModel.gameModeParent ? _document.classDefaults['defaultPawnClass'] : null;
    if (pawn is String && pawn.isNotEmpty) {
      if (projectDir != null && File('$projectDir/$pawn').existsSync()) {
        final pawnName = pawn.split('/').last.replaceAll('.lmas', '');
        classRefs[pawn] = BlueprintClassRef(AnimBlueprintEditorViewModel.className(pawnName), dartFileName(pawnName));
      } else {
        issues.add(LuminaBlueprintDiagnostic(LuminaBlueprintSeverity.error, "Default Pawn Class '$pawn' does not exist."));
      }
    }

    // A Convex Collision with no hull collides as its box.
    for (final c in convexComponentsWithoutHull) {
      final mesh = c.properties['hullAsset'] as String? ?? '';
      issues.add(LuminaBlueprintDiagnostic(
        LuminaBlueprintSeverity.warning,
        mesh.isEmpty
            ? "Convex component '${c.name}' has no hull asset; it collides as its box."
            : "Convex component '${c.name}': ${mesh.split('/').last.replaceAll('.lmas', '')} has no simple collision hulls; it collides as its box.",
      ));
    }

    final tCtx = _contextFor();
    final result = service.generateBlueprintClass(fileBasename, docJson,
        inputActions: _inputActions,
        animBlueprints: animRefs,
        blueprintClasses: classRefs,
        assetPath: rel,
        typeContext: tCtx);
    issues.addAll(result.issues);
    if (projectDir != null) _explainProjectFunctionErrors(issues, projectDir);
    var written = false;
    if (result.ok && !issues.any((d) => d.isError) && projectDir != null) {
      written = await service.compileAndWriteActor(projectDir, fileBasename, docJson,
          assetPath: rel, typeContext: tCtx);
      if (!written) {
        issues.add(const LuminaBlueprintDiagnostic(
            LuminaBlueprintSeverity.error, 'The generated class could not be written to lib/actors/.'));
      }
    }
    applyCompileResult(issues);
    return !issues.any((d) => d.isError);
  }

  /// The title of the node [diagnostic] points at, for Compiler Results.
  String? diagnosticNodeTitle(LuminaBlueprintDiagnostic diagnostic) =>
      diagnostic.nodeId == null ? null : findNode(diagnostic.nodeId!)?.node.title;

  /// The node [id] in whichever graph holds it, with that graph's ref.
  @override
  ({BlueprintGraphRef graph, LuminaBlueprintNode node})? findNode(String id) {
    final inEvent = _document.eventGraph.node(id);
    if (inEvent != null) return (graph: BlueprintGraphRef.eventGraph, node: inEvent);
    for (final f in _document.functions) {
      final n = f.graph.node(id);
      if (n != null) return (graph: BlueprintGraphRef.function(f.name), node: n);
    }
    for (final m in _document.macros) {
      final n = m.graph.node(id);
      if (n != null) return (graph: BlueprintGraphRef.macro(m.name), node: n);
    }
    return null;
  }

  /// The project directory this Blueprint lives in, or null.
  @override
  String? get projectDir => _findProjectDir(assetPath);

  /// Points a mesh component at [meshRelativePath] (empty: none). The 3D
  /// Viewport's preview loads it the way Play does.
  Future<void> setMeshForComponent(String componentId, String propField, String meshRelativePath) async {
    setProperty(componentId, propField, meshRelativePath);
  }

  // ---------------------------------------------------------------------------
  // Disk I/O
  // ---------------------------------------------------------------------------

  @override
  LuminaBlueprintDocument _documentFromAsset(LuminaAsset asset) {
    final parentClass = asset.metadata['parent_class'];
    if (asset.rawPayload != null && asset.rawPayload!.isNotEmpty) {
      try {
        final decoded = jsonDecode(utf8.decode(asset.rawPayload!));
        final doc = LuminaBlueprintDocument.fromJson(Map<String, dynamic>.from(decoded as Map));
        if (doc.components.isEmpty && doc.eventGraph.nodes.isEmpty && parentClass != null) {
          return BlueprintEditorViewModel.createDefaultDocument(fileBasename, parentClass: parentClass);
        }
        return doc;
      } catch (e) {
        EngineLoggerService().log('Failed to parse Blueprint JSON: $e', level: 'error');
        return BlueprintEditorViewModel.createDefaultDocument(fileBasename, parentClass: parentClass ?? 'LuminaCharacter');
      }
    }
    if (parentClass != null) return BlueprintEditorViewModel.createDefaultDocument(fileBasename, parentClass: parentClass);
    return LuminaBlueprintDocument();
  }

  /// Wildcard nodes wired before they adopted their wire's type (For Each
  /// over hit results) get it on load, in every graph.
  void _adoptWildcardTypes() {
    eventGraph.adoptWildcardTypesFromWires();
    for (final f in _document.functions) {
      graphEditor(BlueprintGraphRef.function(f.name)).adoptWildcardTypesFromWires();
    }
    for (final m in _document.macros) {
      graphEditor(BlueprintGraphRef.macro(m.name)).adoptWildcardTypesFromWires();
    }
  }

  Future<void> load() async {
    final file = File(assetPath);
    if (file.existsSync()) {
      _asset = LuminaAsset.fromBytes(await file.readAsBytes());
      _document = _documentFromAsset(_asset!);
      if (_asset!.rawPayload == null || _asset!.rawPayload!.isEmpty) {
        if (_asset!.metadata['parent_class'] == null) _document = BlueprintEditorViewModel.createDefaultDocument(fileBasename);
      }
    } else {
      // No file yet: the same default graph the constructor shows.
      _document = BlueprintEditorViewModel.createDefaultDocument(fileBasename);
      _seedDefaultGraph();
    }

    final projectDir = _findProjectDir(assetPath);
    if (projectDir != null) {
      _declareProjectFunctions(projectDir);
      _inputActions = _readInputActions(projectDir);
      try {
        _scanProjectAssets(projectDir);
      } catch (e) {
        EngineLoggerService().log('Blueprint asset scan error: $e', level: 'warning');
      }
    }

    _previewProjectDir = projectDir;
    if (projectDir != null && _assets == null) {
      _assets = BlueprintAssetCatalog(projectDir)..addListener(_assetsChanged);
    } else {
      _assets?.refresh();
    }
    _rememberEnumValues();
    for (final e in _graphEditors.values) {
      e.dispose();
    }
    _graphEditors.clear();
    _activeGraph = BlueprintGraphRef.eventGraph;
    _adoptWildcardTypes();
    _syncPreview();

    _onDiskJson = file.existsSync() && (_asset?.rawPayload?.isNotEmpty ?? false) ? _document.toFormattedJson() : '';
    if (!file.existsSync()) _onDiskJson = _document.toFormattedJson();
    transactions.clear();
    _compileStatus = BlueprintCompileStatus.unknown;
    _diagnostics = const [];
    _revision++;
    notifyListeners();
    _graphsChanged();
  }

  @override
  void _scanProjectAssets(String projectDir) {
    final allAssets = AssetRepository().scanProjectContents(projectDir);
    bool isAnimGraphAsset(RealAssetInfo a) => a.type == AssetType.animBlueprint || a.type == AssetType.blendSpace;

    _availableSkeletalMeshes = allAssets.where((a) {
      final lower = a.relativePath.toLowerCase();
      final nameLower = a.fileName.toLowerCase();
      if (a.type == AssetType.filamat || a.type == AssetType.texture || a.type == AssetType.animation) return false;
      if (isAnimGraphAsset(a)) return false;
      if (lower.contains('/materials/') || lower.contains('/textures/') || lower.contains('/animations/')) return false;
      if (nameLower.startsWith('m_') || nameLower.startsWith('mi_') || nameLower.startsWith('t_') || nameLower.startsWith('sm_')) {
        return false;
      }
      return a.type == AssetType.filameshSk ||
          nameLower.startsWith('skm_') ||
          lower.contains('/meshes/skeletal') ||
          lower.contains('/skeletal');
    }).toList()
      ..sort((a, b) {
        bool isSkm(RealAssetInfo x) =>
            x.type == AssetType.filameshSk || x.fileName.toLowerCase().startsWith('skm') || x.relativePath.contains('/skeletal');
        if (isSkm(a) && !isSkm(b)) return -1;
        if (!isSkm(a) && isSkm(b)) return 1;
        return a.fileName.compareTo(b.fileName);
      });

    _availableStaticMeshes = allAssets.where((a) {
      final lower = a.relativePath.toLowerCase();
      final nameLower = a.fileName.toLowerCase();
      if (a.type == AssetType.filamat ||
          a.type == AssetType.texture ||
          a.type == AssetType.animation ||
          a.type == AssetType.filameshSk ||
          isAnimGraphAsset(a)) {
        return false;
      }
      if (lower.contains('/materials/') || lower.contains('/textures/') || lower.contains('/animations/') || lower.contains('/skeletal/')) {
        return false;
      }
      if (nameLower.startsWith('m_') || nameLower.startsWith('mi_') || nameLower.startsWith('t_') || nameLower.startsWith('skm_')) {
        return false;
      }
      return a.type == AssetType.filamesh || lower.contains('/meshes/static') || nameLower.startsWith('sm_');
    }).toList();

    _availableAnimations = allAssets.where((a) {
      final lower = a.relativePath.toLowerCase();
      final nameLower = a.fileName.toLowerCase();
      if (a.type == AssetType.filamat || a.type == AssetType.texture || a.type == AssetType.filamesh || a.type == AssetType.filameshSk) {
        return false;
      }
      if (isAnimGraphAsset(a)) return false;
      if (lower.contains('/materials/') || lower.contains('/textures/') || lower.contains('/meshes/')) return false;
      if (nameLower.startsWith('m_') || nameLower.startsWith('mi_') || nameLower.startsWith('t_') || nameLower.startsWith('sm_') || nameLower.startsWith('skm_')) {
        return false;
      }
      return a.type == AssetType.animation ||
          lower.contains('/animations') ||
          nameLower.startsWith('a_') ||
          nameLower.startsWith('anim_') ||
          nameLower.startsWith('mm_') ||
          nameLower.startsWith('mf_');
    }).toList();

    _availableMaterials = allAssets.where((a) {
      final lower = a.relativePath.toLowerCase();
      final nameLower = a.fileName.toLowerCase();
      if (lower.contains('/textures/') || lower.contains('/animations/') || lower.contains('/meshes/')) return false;
      if (nameLower.startsWith('t_') || nameLower.startsWith('sm_') || nameLower.startsWith('skm_') || nameLower.startsWith('a_')) {
        return false;
      }
      return a.type == AssetType.filamat || lower.contains('/materials') || nameLower.startsWith('m_') || nameLower.startsWith('mi_');
    }).toList();

    _availableAnimBlueprints = [
      for (final a in allAssets)
        if (a.type == AssetType.animBlueprint && a.lmasPath != null) (path: a.relativePath, targetMesh: _abpTarget(a.lmasPath!)),
    ];
    _pawnBlueprints = [
      for (final a in allAssets)
        if (a.type == AssetType.actor && a.lmasPath != null && File(a.lmasPath!).absolute.path != File(assetPath).absolute.path)
          if (const {'LuminaPawn', 'LuminaCharacter'}.contains(_parentClassOf(a.lmasPath!))) a.relativePath,
    ]..sort();

    final widgetNames = <String>{};
    for (final a in allAssets) {
      if (a.type == AssetType.widget ||
          a.relativePath.contains('/widgets/') ||
          a.relativePath.contains('/ui/')) {
        final name = a.fileName.replaceAll('.lmas', '').replaceAll('.dart', '');
        if (name.isNotEmpty) widgetNames.add(name);
      }
    }
    final contentsWidgets = Directory(p.join(projectDir, 'contents', 'widgets'));
    if (contentsWidgets.existsSync()) {
      for (final f in contentsWidgets.listSync(recursive: true)) {
        if (f is File && f.path.endsWith('.lmas')) {
          widgetNames.add(p.basenameWithoutExtension(f.path));
        }
      }
    }
    final libWidgets = Directory(p.join(projectDir, 'lib', 'widgets'));
    if (libWidgets.existsSync()) {
      for (final f in libWidgets.listSync(recursive: true)) {
        if (f is File && f.path.endsWith('.dart')) {
          widgetNames.add(p.basenameWithoutExtension(f.path));
        }
      }
    }
    if (widgetNames.isEmpty) {
      widgetNames.add('WBP_HUD');
    }
    _availableWidgetClasses = widgetNames.toList()..sort();
  }

  @override
  Future<bool> save() async {
    final file = File(assetPath);
    _refreshBakedMeshPhysics();
    final jsonString = _document.toFormattedJson();
    final bytes = utf8.encode(jsonString);

    final updatedMetadata = Map<String, String>.from(_asset?.metadata ?? {});
    updatedMetadata['last_modified'] = DateTime.now().toIso8601String();
    updatedMetadata['parent_class'] = _document.parentClass;

    final updatedAsset = LuminaAsset(
      assetId: _asset?.assetId ?? file.uri.pathSegments.last,
      name: _asset?.name ?? fileBasename,
      type: AssetType.actor,
      rawPayload: Uint8List.fromList(bytes),
      rawMatSource: jsonString,
      metadata: updatedMetadata,
      thumbnailPng: _asset?.thumbnailPng,
      hasThumbnail: _asset?.hasThumbnail ?? false,
      references: _asset?.references ?? const [],
    );

    try {
      await file.parent.create(recursive: true);
      await file.writeAsBytes(updatedAsset.toProtoBufferBytes());
      _asset = updatedAsset;
      _onDiskJson = jsonString;
      EngineLoggerService().log('Saved Blueprint asset to $assetPath', level: 'info');
      notifyListeners();
      return true;
    } catch (e, st) {
      EngineLoggerService().log('Failed to save Blueprint asset: $e\n$st', level: 'error');
      return false;
    }
  }

  /// A node whose project function is not exposed (any more) says why: the
  /// scanner's finding with file and line, or that its annotation is gone.
  void _explainProjectFunctionErrors(List<LuminaBlueprintDiagnostic> issues, String projectDir) {
    BlueprintFunctionManifest? manifest;
    try {
      manifest = BlueprintFunctionManifest.read(Directory(projectDir));
    } catch (_) {}
    for (var i = 0; i < issues.length; i++) {
      final d = issues[i];
      final node = d.nodeId == null ? null : findNode(d.nodeId!)?.node;
      if (node == null || !d.isError) continue;
      if (!node.registryId.startsWith(LuminaBlueprintFunctionRegistry.idPrefix)) continue;
      if (LuminaBlueprintNodeLibrary.spec(node.registryId) != null) continue;
      final name = node.registryId.split('#').last;
      final finding = manifest?.diagnostics.where((x) => x.function == name).firstOrNull;
      issues[i] = LuminaBlueprintDiagnostic(
        LuminaBlueprintSeverity.error,
        finding != null
            ? '${node.title}: $finding'
            : '${node.title}: $name is no longer exposed to Blueprints (no @BlueprintCallable / @BlueprintPure on it under lib/).',
        nodeId: node.id,
      );
    }
  }

  /// Pawn and Character Blueprints of the project (a GameMode's Default Pawn
  /// Class picker, Maps & Modes).
  List<String> get pawnBlueprints => _pawnBlueprints;

  /// Points this GameMode Blueprint's Default Pawn Class (or Player
  /// Controller Class) at [path], one undo step.
  bool setGameModeDefault(String key, String path) {
    if (_document.classDefaults[key] == path) return false;
    return mutate('Set ${key == 'defaultPawnClass' ? 'Default Pawn Class' : 'Player Controller Class'}', () {
      _document.classDefaults[key] = path;
      return true;
    });
  }
}

// ---------------------------------------------------------------------------
// Project and assets
// ---------------------------------------------------------------------------

String? _findProjectDir(String startPath) {
  try {
    final file = File(startPath);
    Directory current =
        file.isAbsolute ? file.parent.absolute : File('${Directory.current.path}/$startPath').parent.absolute;
    while (current.path != current.parent.path) {
      if (Directory('${current.path}/contents').existsSync() || File('${current.path}/pubspec.yaml').existsSync()) {
        return current.path;
      }
      current = current.parent;
    }
  } catch (_) {}

  try {
    final recentFile = LuminaConfigDir.file('recent_projects.json');
    if (recentFile.existsSync()) {
      final decoded = jsonDecode(recentFile.readAsStringSync());
      if (decoded is List && decoded.isNotEmpty) {
        for (final item in decoded) {
          final path = item is Map ? (item['project_dir'] ?? item['project_path'] ?? item['path']) as String? : null;
          if (path != null && Directory('$path/contents').existsSync()) return path;
        }
      }
    }
  } catch (_) {}

  try {
    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '';
    final defaultDir = Directory('$home/Lumina Projects');
    if (defaultDir.existsSync()) {
      for (final dir in defaultDir.listSync().whereType<Directory>()) {
        if (Directory('${dir.path}/contents').existsSync()) return dir.path;
      }
    }
  } catch (_) {}
  return null;
}

/// The Enhanced Input actions of the project's `.lmproject` manifest.
List<LuminaInputAction> _readInputActions(String projectDir) {
  final dir = Directory(projectDir);
  if (!dir.existsSync()) return const [];
  for (final f in dir.listSync().whereType<File>()) {
    if (!f.path.endsWith('.lmproject')) continue;
    try {
      final project = LuminaProject.fromMap(Map<String, dynamic>.from(jsonDecode(f.readAsStringSync()) as Map));
      return ProjectInputBinder.bind(project.input).actions.values.toList();
    } catch (_) {
      return const [];
    }
  }
  return const [];
}

String? _parentClassOf(String lmasPath) {
  try {
    final payload = LuminaAsset.fromBytes(File(lmasPath).readAsBytesSync()).rawPayload;
    if (payload == null || payload.isEmpty) return null;
    final map = jsonDecode(utf8.decode(payload));
    return map is Map ? map['parentClass'] as String? : null;
  } catch (_) {
    return null;
  }
}

String _abpTarget(String lmasPath) {
  try {
    final payload = LuminaAsset.fromBytes(File(lmasPath).readAsBytesSync()).rawPayload;
    if (payload == null) return '';
    final map = jsonDecode(utf8.decode(payload));
    return map is Map ? (map['targetMesh'] as String? ?? '') : '';
  } catch (_) {
    return '';
  }
}

/// The project's exposed Dart functions, as the last
/// scan left them in `project.blueprint_functions.json`, so the palette and
/// the compiler know them in this editor too.
void _declareProjectFunctions(String projectDir) {
  try {
    final manifest = BlueprintFunctionManifest.read(Directory(projectDir));
    if (manifest == null) {
      LuminaBlueprintFunctionRegistry.clearDeclared();
    } else {
      manifest.declareAll();
    }
  } catch (e) {
    EngineLoggerService().log('Could not read the project\'s Blueprint functions: $e', level: 'warning', source: 'Blueprint');
  }
}

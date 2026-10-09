part of '../umg_editor_view_model.dart';

/// Loading, theming, saving and compiling the widget document.
mixin _UmgEditorPersistence on _UmgEditorViewModelState {
  // ---------------------------------------------------------------------------
  // Load / save / compile
  // ---------------------------------------------------------------------------

  void _applyAsset(LuminaAsset asset) {
    final payload = asset.rawPayload;
    if (payload != null && payload.isNotEmpty) {
      try {
        final decoded = jsonDecode(utf8.decode(payload));
        _document = UmgDocument.fromJson(Map<String, dynamic>.from(decoded as Map));
      } catch (e) {
        _logger.log('WIDGET payload of ${asset.name} is not a designer document ($e); starting a fresh canvas', level: 'warning', source: 'UmgEditor');
        _document = UmgDocument.createDefault();
      }
    } else {
      _document = UmgDocument.createDefault();
    }
    _resolution = _document.designResolution;
    _dpiScale = _document.dpiScale;
    _onDiskJson = _document.toFormattedJson(includeBlueprint: false);
    _selectedId = _document.root.id;
    _resetGraphEditor();
  }

  /// A (re)load: the graph editor reopens on the loaded graph when next shown.
  void _resetGraphEditor() {
    final old = _graphEditor;
    if (old == null) return;
    _graphEditor = null;
    old.removeListener(_onGraphChanged);
    old.transactions.removeListener(_onGraphChanged);
    old.dispose();
  }

  Future<void> load() async {
    final file = File(assetPath);
    if (file.existsSync()) {
      try {
        _asset = LuminaAsset.fromBytes(await file.readAsBytes());
      } catch (e) {
        _logger.log('Failed to read $assetPath: $e', level: 'error', source: 'UmgEditor');
        _asset = null;
      }
    }
    if (_asset != null) {
      _applyAsset(_asset!);
    } else {
      _document = UmgDocument.createDefault();
      _onDiskJson = '';
      _selectedId = _document.root.id;
      _resetGraphEditor();
    }
    _loaded = true;
    _refreshTextureAssets();
    await refreshAvailableThemes();
    await loadThemeForDocument();
    transactions.clear();
    notifyListeners();
  }

  LuminaThemeDocument? _findLoadedTheme(String? path) {
    if (path == null || path.isEmpty) return null;
    final norm = path.replaceAll('\\', '/');
    if (_loadedThemes.containsKey(norm)) return _loadedThemes[norm];
    for (final entry in _loadedThemes.entries) {
      final k = entry.key.replaceAll('\\', '/');
      if (k.endsWith(norm) || norm.endsWith(k.split('/').last)) {
        return entry.value;
      }
    }
    return null;
  }

  Future<void> refreshAvailableThemes() async {
    final prj = projectDirPath;
    if (prj == null || prj.isEmpty) return;
    try {
      await LuminaThemeService.ensureDefaultTheme(prj);
      final paths = LuminaThemeService.listThemePaths(prj);
      _availableThemePaths = paths;
      for (final p in paths) {
        if (!_loadedThemes.containsKey(p)) {
          _loadedThemes[p] = await LuminaThemeService.loadTheme(p);
        }
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadThemeForDocument() async {
    final prj = projectDirPath;
    final tPath = _document.themePath;
    if (tPath != null && tPath.isNotEmpty) {
      final found = _findLoadedTheme(tPath);
      if (found != null) {
        _activeTheme = found;
      } else {
        final fullPath = (prj != null && !tPath.startsWith(prj)) ? '$prj/$tPath' : tPath;
        final doc = await LuminaThemeService.loadTheme(fullPath);
        _loadedThemes[tPath] = doc;
        _activeTheme = doc;
      }
    } else if (prj != null) {
      final defaultPath = '$prj/contents/themes/DefaultTheme.lmas'.replaceAll('\\', '/');
      final found = _findLoadedTheme(defaultPath);
      if (found != null) {
        _activeTheme = found;
      } else if (File(defaultPath).existsSync()) {
        final doc = await LuminaThemeService.loadTheme(defaultPath);
        _loadedThemes[defaultPath] = doc;
        _activeTheme = doc;
      } else {
        _activeTheme = LuminaThemeDocument.defaultShadcnDark();
      }
    } else {
      _activeTheme = LuminaThemeDocument.defaultShadcnDark();
    }
    notifyListeners();
  }

  Future<void> setDocumentTheme(String? path) async {
    _mutate<bool>('Set Widget Theme', () {
      _document.themePath = (path == null || path.isEmpty) ? null : path;
      return true;
    });
    await loadThemeForDocument();
    notifyListeners();
  }

  Future<void> setNodeTheme(String nodeId, String? themePath) async {
    final node = _document.findNode(nodeId);
    if (node == null) return;
    _mutate<bool>('Set Component Theme', () {
      if (themePath == null || themePath.isEmpty) {
        node.props.remove('theme');
      } else {
        node.props['theme'] = themePath;
      }
      return true;
    });
    if (themePath != null && themePath.isNotEmpty && _findLoadedTheme(themePath) == null) {
      final prj = projectDirPath;
      final fullPath = (prj != null && !themePath.startsWith(prj)) ? '$prj/$themePath' : themePath;
      _loadedThemes[themePath] = await LuminaThemeService.loadTheme(fullPath);
    }
    notifyListeners();
  }

  LuminaThemeDocument themeForNode(UmgNode node) {
    return UmgThemeHelper.resolveThemeForNode(
      node: node,
      documentTheme: activeTheme,
      loadedThemes: _loadedThemes,
    );
  }

  ThemeData themeDataForNode(UmgNode node) {
    return UmgThemeHelper.themeDataFromLuminaDoc(themeForNode(node));
  }

  @override
  void _refreshTextureAssets() {
    final dir = projectDirPath;
    if (dir == null) {
      _textureAssets = const [];
      return;
    }
    try {
      _textureAssets = AssetRepository().scanProjectContents(dir).where((a) => a.type == AssetType.texture).toList()
        ..sort((a, b) => a.relativePath.compareTo(b.relativePath));
    } catch (_) {
      _textureAssets = const [];
    }
  }

  List<AssetReference> _collectReferences() {
    final refs = <AssetReference>[];
    final dir = projectDirPath;
    _document.root.visit((n, _) {
      final key = UmgEditorViewModel.textureKeyOf(n.type);
      if (key == null) return;
      final texture = n.props[key]?.toString() ?? '';
      if (texture.isEmpty) return;
      String assetId = '';
      if (dir != null) {
        final f = File('$dir/$texture');
        if (f.existsSync()) {
          try {
            assetId = LuminaAsset.fromBytes(f.readAsBytesSync()).assetId;
          } catch (_) {}
        }
      }
      refs.add(AssetReference(slotName: 'image:${n.fieldName}', assetId: assetId, assetPath: texture));
    });
    return refs;
  }

  @override
  Future<bool> save() async {
    _document.designResolution = _resolution;
    _document.dpiScale = _dpiScale;
    _takeGraph();
    final json = _document.toFormattedJson();
    final base = _asset ??
        LuminaAsset(assetId: fileBasename, name: fileBasename, type: AssetType.widget);
    final updated = LuminaAsset(
      assetId: base.assetId.isEmpty ? fileBasename : base.assetId,
      name: base.name.isEmpty ? fileBasename : base.name,
      type: AssetType.widget,
      hasThumbnail: base.hasThumbnail,
      thumbnailPng: base.thumbnailPng,
      rawPayload: Uint8List.fromList(utf8.encode(json)),
      rawMatSource: base.rawMatSource,
      references: _collectReferences(),
      metadata: {
        ...base.metadata,
        'designer_resolution': _resolution.key,
        'dpi_scale': _dpiScale.toString(),
        'generated_class': className,
      },
    );
    try {
      final file = File(assetPath);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(updated.toProtoBufferBytes(), flush: true);
      _asset = updated;
      _onDiskJson = _document.toFormattedJson(includeBlueprint: false);
      _graphEditor?.documentSaved();
      _logger.log('Saved widget ${file.uri.pathSegments.last} (${_document.allNodes.length} elements)', level: 'success', source: 'UmgEditor');
      // Open Blueprint editors re-read the widget classes (`Get <Element>` pin types).
      AssetRepository.notifyAssetsChanged();
      notifyListeners();
      return true;
    } catch (e) {
      _logger.log('Failed to save $assetPath: $e', level: 'error', source: 'UmgEditor');
      return false;
    }
  }

  /// Saves, then writes `lib/widgets/WBP_<Name>.dart` into the project.
  @override
  Future<UmgCompileResult> compile() async {
    await save();
    final dir = projectDirPath;
    final errors = [...validationErrors];
    // The graph compiles first; its errors land on its nodes.
    if (_graphEditor != null || _document.blueprint != null) {
      final graph = graphEditor.compileGraph();
      for (final d in graph.errors) {
        final node = d.nodeId == null ? null : graphEditor.diagnosticNodeTitle(d);
        errors.add('Graph: ${node == null ? '' : '$node: '}${d.message}');
      }
    }
    if (errors.isNotEmpty) {
      // A plain-Flutter game cannot import shadcn_flutter.
      _compileError = errors.join('\n');
      for (final e in errors) {
        _logger.log(e, level: 'error', source: 'UmgEditor');
      }
      notifyListeners();
      return UmgCompileResult(filePath: dir == null ? '' : UmgWidgetCodegen.outputPath(dir, fileBasename), written: false, source: '', warnings: errors);
    }
    if (dir == null) {
      _compileError = 'No project directory found above $assetPath';
      _logger.log(_compileError!, level: 'error', source: 'UmgEditor');
      notifyListeners();
      return UmgCompileResult(filePath: '', written: false, source: generatedSource, warnings: [_compileError!]);
    }
    try {
      final result = await UmgWidgetCodegen.compileAndWrite(projectPath: dir, assetName: fileBasename, document: _document, library: widgetLibrary);
      _lastCompile = result;
      _compileError = null;
      _logger.log(
        result.written ? 'Generated ${result.filePath}' : 'Widget code unchanged: ${result.filePath}',
        level: result.written ? 'success' : 'info',
        source: 'UmgEditor',
      );
      for (final w in result.warnings) {
        _logger.log(w, level: 'warning', source: 'UmgEditor');
      }
      notifyListeners();
      return result;
    } catch (e) {
      _compileError = 'Widget codegen failed: $e';
      _logger.log(_compileError!, level: 'error', source: 'UmgEditor');
      notifyListeners();
      return UmgCompileResult(filePath: UmgWidgetCodegen.outputPath(dir, fileBasename), written: false, source: '', warnings: [_compileError!]);
    }
  }

  void discardChanges() {
    if (_asset != null) {
      _applyAsset(_asset!);
    } else {
      _document = UmgDocument.createDefault();
      _resetGraphEditor();
    }
    transactions.clear();
    notifyListeners();
  }
}

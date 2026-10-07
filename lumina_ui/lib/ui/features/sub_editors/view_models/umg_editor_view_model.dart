import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:lumina/data/models/lumina_asset.dart';
import 'package:lumina/data/repositories/asset_repository.dart';
import 'package:lumina/data/services/engine_logger_service.dart';
import 'package:lumina/lumina.dart'
    show LuminaBlueprintDocument, LuminaBlueprintNode, LuminaBlueprintNodeLibrary, LuminaThemeDocument, LuminaThemeService;
import 'package:shadcn_flutter/shadcn_flutter.dart' show ThemeData;
import 'package:lumina_ui/ui/features/sub_editors/views/umg/umg_theme_helper.dart';

import 'package:lumina_ui/ui/features/main_editor/commands/editor_transaction.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/umg_document.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/umg_widget_codegen.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/umg_widget_validator.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/widget_blueprint_editor_view_model.dart';

/// Designer mode of the center panel.
enum UmgEditorMode { designer, graph }

/// View model of the UMG designer: one persisted [UmgDocument] inside a real
/// WIDGET `.lmas`, every mutation recorded on its own [TransactionManager],
/// `save()` through `LuminaAsset.toProtoBufferBytes()`, `compile()` through
/// [UmgWidgetCodegen] into the project's `lib/widgets/`.
class UmgEditorViewModel extends ChangeNotifier {
  final String assetPath;
  final String? projectDirPathOverride;
  final TransactionManager transactions = TransactionManager();
  final EngineLoggerService _logger = EngineLoggerService();

  LuminaAsset? _asset;
  UmgDocument _document = UmgDocument.createDefault();
  String _onDiskJson = '';
  bool _loaded = false;
  String? _selectedId;
  UmgEditorMode _mode = UmgEditorMode.designer;
  UmgResolution _resolution = UmgResolution.presets.first;
  double _dpiScale = 1.0;
  bool snapToGrid = true;
  double gridSize = 8;
  String? _lastRejectionReason;
  UmgCompileResult? _lastCompile;
  String? _compileError;
  List<RealAssetInfo> _textureAssets = const [];
  final Map<String, Uint8List?> _textureCache = {};
  Map<String, dynamic>? _interactionBefore;
  String? _interactionLabel;
  WidgetBlueprintEditorViewModel? _graphEditor;
  bool _showGeneratedCode = false;
  LuminaThemeDocument? _activeTheme;
  final Map<String, LuminaThemeDocument> _loadedThemes = {};
  List<String> _availableThemePaths = const [];

  UmgEditorViewModel({required this.assetPath, LuminaAsset? initialAsset, this.projectDirPathOverride}) : _asset = initialAsset {
    if (initialAsset != null) {
      _applyAsset(initialAsset);
      _loaded = true;
    }
    _initThemes();
  }

  void _initThemes() {
    refreshAvailableThemes().then((_) => loadThemeForDocument());
  }

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  UmgDocument get document => _document;
  bool get isLoaded => _loaded;
  String? get selectedId => _selectedId;
  UmgNode? get selectedNode => _selectedId == null ? null : _document.findNode(_selectedId!);
  UmgEditorMode get mode => _mode;
  UmgResolution get resolution => _resolution;
  double get dpiScale => _dpiScale;
  Size get logicalSize => Size(_resolution.width / _dpiScale, _resolution.height / _dpiScale);
  String? get lastRejectionReason => _lastRejectionReason;
  UmgCompileResult? get lastCompile => _lastCompile;
  String? get compileError => _compileError;
  List<RealAssetInfo> get textureAssets => List.unmodifiable(_textureAssets);
  List<String> get availableThemePaths => List.unmodifiable(_availableThemePaths);
  String? get activeThemePath => _document.themePath;
  LuminaThemeDocument get activeTheme => _activeTheme ?? LuminaThemeDocument.defaultShadcnDark();
  ThemeData get activeThemeData => UmgThemeHelper.themeDataFromLuminaDoc(activeTheme);
  Map<String, LuminaThemeDocument> get loadedThemes => Map.unmodifiable(_loadedThemes);

  /// The designer tree or the graph differs from the `.lmas` on disk.
  bool get isDirty => _document.toFormattedJson(includeBlueprint: false) != _onDiskJson || (_graphEditor?.isDirty ?? false);

  /// Graph mode shows the generated source instead of the
  /// graph (the source stays one click away).
  bool get showGeneratedCode => _showGeneratedCode;

  void setShowGeneratedCode(bool show) {
    if (_showGeneratedCode == show) return;
    _showGeneratedCode = show;
    notifyListeners();
  }

  /// The widget's own Blueprint graph editor, opened on the
  /// document's graph; a widget designed before graphs existed opens with a
  /// bound event node per event recorded on its elements.
  WidgetBlueprintEditorViewModel get graphEditor => _graphEditor ??= _createGraphEditor();

  /// Whether [graphEditor] was opened (a widget never shown in Graph mode
  /// keeps its stored graph as it is).
  bool get hasGraphEditor => _graphEditor != null;

  WidgetBlueprintEditorViewModel _createGraphEditor() {
    final hadGraph = _document.blueprint != null;
    final editor = WidgetBlueprintEditorViewModel(
      assetPath: assetPath,
      widgetClass: UmgWidgetCodegen.fileBaseName(fileBasename),
      projectDirectory: projectDirPath,
      variablesSource: () => UmgWidgetCodegen.variablesOf(_document),
      initial: _document.blueprint != null
          ? LuminaBlueprintDocument.fromJson(Map<String, dynamic>.from(jsonDecode(jsonEncode(_document.blueprint!.toJson())) as Map))
          : null,
      onSave: save,
      onCompile: () async {
        await compile();
        return _compileError == null;
      },
      generatedSource: () => generatedSource,
    );
    if (!hadGraph) {
      // Migration: the events recorded before graphs existed
      // appear as their bound nodes; their handlers keep the USER CODE.
      editor.adoptRecordedEvents([
        for (final n in _document.variableNodes)
          for (final e in n.events) (element: n.name, event: e.name),
      ]);
      editor.documentSaved();
    }
    editor.addListener(_onGraphChanged);
    editor.transactions.addListener(_onGraphChanged);
    return editor;
  }

  void _onGraphChanged() => notifyListeners();

  /// The document with the graph as it is in the editor now (Play runs it
  /// unsaved, as Blueprint editors' documents play).
  UmgDocument get documentForPlay {
    _takeGraph();
    return _document;
  }

  /// The graph as it is now becomes the document's (what Save and Compile write).
  void _takeGraph() {
    final editor = _graphEditor;
    if (editor != null) _document.blueprint = editor.document;
  }

  @override
  void dispose() {
    _graphEditor?.removeListener(_onGraphChanged);
    _graphEditor?.transactions.removeListener(_onGraphChanged);
    _graphEditor?.dispose();
    super.dispose();
  }

  String get fileBasename {
    final segments = File(assetPath).uri.pathSegments;
    return segments.isNotEmpty ? segments.last.replaceAll('.lmas', '') : 'WBP_Widget';
  }

  String get className => UmgWidgetCodegen.classNameFor(fileBasename);

  String? get projectDirPath => projectDirPathOverride ?? _findProjectDir(assetPath);

  /// The project's UMG widget library: what the codegen emits
  /// and the designer previews. Re-read when the manifest or the pubspec
  /// changes, so an open designer follows a switch in Project Settings.
  String get widgetLibrary {
    final dir = projectDirPath;
    final stamp = _libraryStamp(dir);
    if (_widgetLibrary == null || stamp != _widgetLibraryStamp) {
      _widgetLibrary = UmgWidgetCodegen.libraryFor(dir);
      _widgetLibraryStamp = stamp;
    }
    return _widgetLibrary!;
  }

  String? _widgetLibrary;
  String? _widgetLibraryStamp;

  static String _libraryStamp(String? dir) {
    if (dir == null) return '';
    final files = [
      File('$dir/pubspec.yaml'),
      ...Directory(dir).listSync().whereType<File>().where((f) => f.path.endsWith('.lmproject')),
    ];
    return files.map((f) => f.existsSync() ? f.lastModifiedSync().microsecondsSinceEpoch : 0).join(':');
  }

  /// Generated source for the current document (Graph tab / compile preview).
  String get generatedSource {
    _takeGraph();
    String? existing;
    final dir = projectDirPath;
    if (dir != null) {
      final f = File(UmgWidgetCodegen.outputPath(dir, fileBasename));
      if (f.existsSync()) existing = f.readAsStringSync();
    }
    return UmgWidgetCodegen.generateWidgetDart(_document, assetName: fileBasename, existingContent: existing, library: widgetLibrary);
  }

  static String? _findProjectDir(String startPath) {
    try {
      final file = File(startPath);
      Directory current = file.isAbsolute ? file.parent.absolute : File('${Directory.current.path}/$startPath').parent.absolute;
      while (current.path != current.parent.path) {
        if (Directory('${current.path}/contents').existsSync() || File('${current.path}/pubspec.yaml').existsSync()) {
          return current.path;
        }
        current = current.parent;
      }
    } catch (_) {}
    return null;
  }

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
      final key = textureKeyOf(n.type);
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

  // ---------------------------------------------------------------------------
  // Selection / mode / simulator
  // ---------------------------------------------------------------------------

  void select(String? id) {
    if (_selectedId == id) return;
    _selectedId = id;
    notifyListeners();
  }

  void setMode(UmgEditorMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
  }

  void setResolution(UmgResolution resolution) {
    _resolution = resolution;
    _document.designResolution = resolution;
    notifyListeners();
  }

  void setCustomResolution(int width, int height) {
    setResolution(UmgResolution('Custom ${width}x$height', width.clamp(64, 16384), height.clamp(64, 16384), isCustom: true));
  }

  void setDpiScale(double scale) {
    _dpiScale = scale.clamp(0.25, 4.0);
    _document.dpiScale = _dpiScale;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Transactions
  // ---------------------------------------------------------------------------

  void _restore(Map<String, dynamic> json, {String? reselect}) {
    final graph = _document.blueprint;
    _document = UmgDocument.fromJson(json)..blueprint = graph;
    _graphEditor?.variablesChanged();
    _resolution = _document.designResolution;
    _dpiScale = _document.dpiScale;
    if (reselect != null && _document.findNode(reselect) != null) {
      _selectedId = reselect;
    } else if (_selectedId != null && _document.findNode(_selectedId!) == null) {
      _selectedId = _document.root.id;
    }
    notifyListeners();
  }

  /// Runs [mutation] against the document and records it as one undo step.
  /// Returns the mutation result; a `null`/`false` result records nothing.
  T _mutate<T>(String label, T Function() mutation) {
    final before = _document.toJson(includeBlueprint: false);
    final result = mutation();
    if (result == null || result == false) {
      _restoreSilently(before);
      return result;
    }
    final after = _document.toJson(includeBlueprint: false);
    if (jsonEncode(before) == jsonEncode(after)) return result;
    final selectedAfter = _selectedId;
    transactions.record(EditorTransaction(
      label: label,
      undo: () => _restore(before),
      redo: () => _restore(after, reselect: selectedAfter),
    ));
    _graphEditor?.variablesChanged();
    notifyListeners();
    return result;
  }

  void _restoreSilently(Map<String, dynamic> before) {
    final graph = _document.blueprint;
    _document = UmgDocument.fromJson(before)..blueprint = graph;
  }

  /// Starts a coalesced interaction (canvas drag, scrub): previews mutate
  /// the document live, [endInteraction] records a single transaction.
  void beginInteraction(String label) {
    _interactionBefore ??= _document.toJson(includeBlueprint: false);
    _interactionLabel = label;
  }

  void endInteraction() {
    final before = _interactionBefore;
    _interactionBefore = null;
    if (before == null) return;
    final after = _document.toJson(includeBlueprint: false);
    if (jsonEncode(before) == jsonEncode(after)) return;
    final selectedAfter = _selectedId;
    transactions.record(EditorTransaction(
      label: _interactionLabel ?? 'Edit',
      undo: () => _restore(before),
      redo: () => _restore(after, reselect: selectedAfter),
    ));
    notifyListeners();
  }

  /// Undo / Redo follow the visible mode: the graph's own history in Graph
  /// mode, the designer's otherwise.
  void undo() => _mode == UmgEditorMode.graph && _graphEditor != null ? _graphEditor!.undo() : transactions.undo();
  void redo() => _mode == UmgEditorMode.graph && _graphEditor != null ? _graphEditor!.redo() : transactions.redo();

  /// The history the toolbar's Undo / Redo act on now.
  TransactionManager get activeTransactions =>
      _mode == UmgEditorMode.graph && _graphEditor != null ? _graphEditor!.transactions : transactions;

  // ---------------------------------------------------------------------------
  // Mutations
  // ---------------------------------------------------------------------------

  Offset _snap(Offset p) => snapToGrid ? Offset(UmgLayout.snap(p.dx, gridSize), UmgLayout.snap(p.dy, gridSize)) : p;

  /// Places a new widget of [type] under [parentId]. For Canvas Panel parents
  /// [canvasPosition] (parent-local design px) becomes the slot position.
  /// Returns null and sets [lastRejectionReason] when the parent refuses it.
  UmgNode? addWidget(UmgWidgetType type, {required String parentId, Offset? canvasPosition, int? index}) {
    final parent = _document.findNode(parentId);
    if (parent == null) {
      _lastRejectionReason = 'Drop target no longer exists';
      notifyListeners();
      return null;
    }
    final reason = _document.rejectionReasonFor(parent);
    if (reason != null) {
      _lastRejectionReason = reason;
      _logger.log('Rejected drop of ${type.displayName}: $reason', level: 'warning', source: 'UmgEditor');
      notifyListeners();
      return null;
    }
    _lastRejectionReason = null;
    final node = UmgNode.create(type);
    final result = _mutate<UmgNode?>('Add ${type.displayName}', () {
      final added = _document.addChild(parentId, node, canvasPosition: canvasPosition == null ? null : _snap(canvasPosition), index: index);
      if (added != null) _selectedId = added.id;
      return added;
    });
    return result;
  }

  bool moveNode(String id, String newParentId, {int? index}) {
    if (id == _document.root.id || id == newParentId || _document.isDescendant(id, newParentId)) {
      _lastRejectionReason = 'Cannot move a widget into itself';
      notifyListeners();
      return false;
    }
    final node = _document.findNode(id);
    final target = _document.findNode(newParentId);
    if (node == null || target == null) return false;
    final oldParent = _document.parentOf(id)!;
    final extra = oldParent.id == newParentId ? 0 : 1;
    final reason = _document.rejectionReasonFor(target, extra: extra);
    if (reason != null) {
      _lastRejectionReason = reason;
      notifyListeners();
      return false;
    }
    _lastRejectionReason = null;
    return _mutate<bool>('Move ${node.name}', () {
      final oldIndex = oldParent.children.indexWhere((c) => c.id == id);
      oldParent.children.removeAt(oldIndex);
      var insertAt = index ?? target.children.length;
      if (oldParent.id == newParentId && index != null && oldIndex < index) insertAt = index - 1;
      insertAt = insertAt.clamp(0, target.children.length);
      _document.assignSlotFor(node, target);
      target.children.insert(insertAt, node);
      return true;
    });
  }

  void setCanvasPosition(String id, Offset position) {
    final node = _document.findNode(id);
    if (node == null || node.slot.kind != UmgSlotKind.canvas) return;
    _mutate<bool>('Move ${node.name}', () {
      node.slot.position = _snap(position);
      return true;
    });
  }

  void setCanvasSize(String id, Size size) {
    final node = _document.findNode(id);
    if (node == null || node.slot.kind != UmgSlotKind.canvas) return;
    _mutate<bool>('Resize ${node.name}', () {
      node.slot.size = Size(size.width.clamp(1, 100000), size.height.clamp(1, 100000));
      return true;
    });
  }

  /// Live (un-recorded) canvas position update used inside an interaction.
  void previewCanvasPosition(String id, Offset position) {
    final node = _document.findNode(id);
    if (node == null || node.slot.kind != UmgSlotKind.canvas) return;
    node.slot.position = _snap(position);
    notifyListeners();
  }

  /// Live (un-recorded) rect update used by move/resize handles: rewrites
  /// position/size so the slot resolves to [rect] inside [parentSize].
  void previewCanvasRect(String id, Rect rect, Size parentSize) {
    final node = _document.findNode(id);
    if (node == null || node.slot.kind != UmgSlotKind.canvas) return;
    var r = rect;
    if (snapToGrid) {
      final l = UmgLayout.snap(r.left, gridSize);
      final t = UmgLayout.snap(r.top, gridSize);
      final w = UmgLayout.snap(r.width, gridSize).clamp(gridSize, 100000.0);
      final h = UmgLayout.snap(r.height, gridSize).clamp(gridSize, 100000.0);
      r = Rect.fromLTWH(l, t, w, h);
    }
    UmgLayout.fitSlotToRect(node.slot, r, parentSize);
    notifyListeners();
  }

  /// Live (un-recorded) slot field edit used by inspector scrubbing.
  void previewSlot(String id, void Function(UmgSlot slot) edit) {
    final node = _document.findNode(id);
    if (node == null) return;
    edit(node.slot);
    notifyListeners();
  }

  void setSlot(String id, void Function(UmgSlot slot) edit, {String label = 'Edit Slot'}) {
    final node = _document.findNode(id);
    if (node == null) return;
    _mutate<bool>('$label ${node.name}', () {
      edit(node.slot);
      return true;
    });
  }

  void applyAnchorPreset(String id, UmgAnchorPreset preset) {
    final node = _document.findNode(id);
    if (node == null || node.slot.kind != UmgSlotKind.canvas) return;
    final parentSize = _parentSizeOf(id);
    _mutate<bool>('Anchor ${node.name} ${preset.label}', () {
      UmgLayout.applyPreset(node.slot, preset, parentSize);
      return true;
    });
  }

  /// Size of the canvas panel that owns [id]'s slot (root → simulated size,
  /// nested canvas → its own resolved rect at the design resolution).
  Size _parentSizeOf(String id) {
    final parent = _document.parentOf(id);
    if (parent == null || parent.id == _document.root.id) return logicalSize;
    return canvasSizeOf(parent.id);
  }

  /// Best-effort design-time size of a panel (its own canvas rect if it is a
  /// canvas child, otherwise the simulated screen).
  Size canvasSizeOf(String id) {
    final node = _document.findNode(id);
    if (node == null) return logicalSize;
    if (node.id == _document.root.id) return logicalSize;
    if (node.slot.kind == UmgSlotKind.canvas) {
      return UmgLayout.resolveCanvasRect(node.slot, _parentSizeOf(id)).size;
    }
    return logicalSize;
  }

  void setZOrder(String id, int zOrder) {
    final node = _document.findNode(id);
    if (node == null || node.slot.kind != UmgSlotKind.canvas) return;
    _mutate<bool>('Z-Order ${node.name}', () {
      node.slot.zOrder = zOrder;
      return true;
    });
  }

  void setProp(String id, String key, dynamic value) {
    final node = _document.findNode(id);
    if (node == null) return;
    _mutate<bool>('Set $key on ${node.name}', () {
      node.props[key] = value;
      return true;
    });
  }

  /// Live (un-recorded) prop edit used by inspector scrubbing.
  void previewProp(String id, String key, dynamic value) {
    final node = _document.findNode(id);
    if (node == null) return;
    node.props[key] = value;
    notifyListeners();
  }

  /// Renames the element; the display name becomes the generated identifier
  /// via [UmgNaming.toFieldName]. Rejects empty/non-identifier/duplicate names.
  bool rename(String id, String newName) {
    final node = _document.findNode(id);
    if (node == null) return false;
    final trimmed = newName.trim();
    final field = UmgNaming.toFieldName(trimmed);
    if (trimmed.isEmpty || field.isEmpty) {
      _lastRejectionReason = 'Name must produce a Dart identifier (letters, digits, underscores; not starting with a digit)';
      notifyListeners();
      return false;
    }
    if (_document.isFieldNameTaken(field, exclude: id)) {
      _lastRejectionReason = 'Another element already generates the field "$field"';
      notifyListeners();
      return false;
    }
    _lastRejectionReason = null;
    final oldName = node.name;
    final renamed = _mutate<bool>('Rename ${node.name}', () {
      node.name = trimmed;
      node.fieldName = field;
      return true;
    });
    // The graph's references follow the element.
    if (renamed) {
      final graph = _graphEditor;
      if (graph != null) {
        graph.renameElementReferences(oldName, trimmed);
      } else if (_document.blueprint != null) {
        WidgetBlueprintEditorViewModel.renameIn(_document.blueprint!, oldName, trimmed);
      }
    }
    return renamed;
  }

  /// `Is Variable`: whether [id] is a member of the
  /// widget's graph (`Get <Element>`, bound events).
  bool setIsVariable(String id, bool value) {
    final node = _document.findNode(id);
    if (node == null || node.id == _document.root.id || node.isVariable == value) return false;
    return _mutate<bool>('${value ? 'Mark' : 'Unmark'} ${node.name} as variable', () {
      node.isVariable = value;
      return true;
    });
  }

  /// Whether [eventName] of [id] is bound: recorded on the element, or a
  /// bound `On <Event> (<element>)` node in the graph.
  bool isEventBound(String id, String eventName) {
    final node = _document.findNode(id);
    if (node == null) return false;
    if (node.events.any((e) => e.name == eventName)) return true;
    final graph = _graphEditor?.document ?? _document.blueprint;
    return graph != null &&
        graph.eventGraph.nodes.any((n) =>
            n.registryId == LuminaBlueprintNodeLibrary.eventWidgetElement && n.literals['element'] == node.name && n.literals['event'] == eventName);
  }

  /// Whether the generated handler of [eventName] on [id] holds hand-written
  /// code in its `// BEGIN USER CODE` region (kept and run after the graph).
  bool hasHandWrittenCode(String id, String eventName) {
    final node = _document.findNode(id);
    final dir = projectDirPath;
    if (node == null || dir == null) return false;
    final file = File(UmgWidgetCodegen.outputPath(dir, fileBasename));
    if (!file.existsSync()) return false;
    final tag = '${UmgEvent(name: eventName, handler: '').regionTag}_${node.fieldName}';
    final region = UmgWidgetCodegen.parseUserRegions(file.readAsStringSync())[tag];
    return region != null && region.trim().isNotEmpty;
  }

  /// The green `+` on a Widget Event: records the
  /// binding (a designer undo step), makes the element a variable when it
  /// was not, switches to Graph and creates or focuses the bound
  /// `On <Event> (<element>)` node there (a graph undo step). Returns the
  /// node, or null when the element has no such event.
  LuminaBlueprintNode? bindWidgetEvent(String id, String eventName) {
    final node = _document.findNode(id);
    if (node == null || !node.type.availableEvents.contains(eventName)) return null;
    // Opened first: a legacy widget's recorded events become nodes before
    // this binding is recorded, so the new node is a graph undo step.
    final graph = graphEditor;
    if (!node.isVariable) setIsVariable(id, true);
    addEvent(id, eventName);
    setMode(UmgEditorMode.graph);
    setShowGeneratedCode(false);
    return graph.focusBoundEvent(node.name, eventName);
  }

  /// Inserts a new [type] parent between [id] and its parent, handing the
  /// child's slot to the wrapper.
  UmgNode? wrapWith(String id, UmgWidgetType type) {
    if (!type.isPanel) {
      _lastRejectionReason = '${type.displayName} cannot contain children';
      notifyListeners();
      return null;
    }
    final node = _document.findNode(id);
    final parent = _document.parentOf(id);
    if (node == null || parent == null) {
      _lastRejectionReason = 'The root cannot be wrapped';
      notifyListeners();
      return null;
    }
    _lastRejectionReason = null;
    return _mutate<UmgNode?>('Wrap ${node.name} with ${type.displayName}', () {
      final wrapper = UmgNode.create(type);
      wrapper.fieldName = _document.uniqueFieldName(wrapper.fieldName, exclude: wrapper.id);
      wrapper.slot = node.slot.copy();
      final index = parent.children.indexWhere((c) => c.id == id);
      parent.children.removeAt(index);
      node.slot = UmgSlot(kind: type.childSlotKind, size: node.slot.size);
      if (type.childSlotKind == UmgSlotKind.canvas) {
        node.slot.position = Offset.zero;
      }
      wrapper.children.add(node);
      parent.children.insert(index, wrapper);
      _selectedId = wrapper.id;
      return wrapper;
    });
  }

  /// Swaps the node's type, keeping identity, name, slot and compatible children.
  UmgNode? replaceWith(String id, UmgWidgetType type) {
    final node = _document.findNode(id);
    if (node == null) return null;
    if (node.id == _document.root.id && !type.isPanel) {
      _lastRejectionReason = 'The root must stay a panel';
      notifyListeners();
      return null;
    }
    final needed = node.children.length;
    if (type.capacity == UmgChildCapacity.none && needed > 0) {
      _lastRejectionReason = '${type.displayName} cannot hold the $needed existing child(ren)';
      notifyListeners();
      return null;
    }
    if (type.capacity == UmgChildCapacity.one && needed > 1) {
      _lastRejectionReason = '${type.displayName} accepts exactly one child but "${node.name}" has $needed';
      notifyListeners();
      return null;
    }
    _lastRejectionReason = null;
    return _mutate<UmgNode?>('Replace ${node.name} with ${type.displayName}', () {
      final defaults = type.defaultProps();
      final kept = <String, dynamic>{};
      for (final k in defaults.keys) {
        kept[k] = node.props.containsKey(k) ? node.props[k] : defaults[k];
      }
      node.type = type;
      node.props
        ..clear()
        ..addAll(kept);
      node.events.removeWhere((e) => !type.availableEvents.contains(e.name));
      for (final c in node.children) {
        c.slot.kind = type.childSlotKind;
      }
      return node;
    });
  }

  bool deleteNode(String id) {
    if (id == _document.root.id) {
      _lastRejectionReason = 'The root panel cannot be deleted';
      notifyListeners();
      return false;
    }
    final node = _document.findNode(id);
    if (node == null) return false;
    return _mutate<bool>('Delete ${node.name}', () {
      final removed = _document.removeNode(id);
      if (removed && (_selectedId == id || _document.findNode(_selectedId ?? '') == null)) {
        _selectedId = _document.root.id;
      }
      return removed;
    });
  }

  /// `[+] OnClicked` etc.: records a named handler on the node.
  bool addEvent(String id, String eventName) {
    final node = _document.findNode(id);
    if (node == null || !node.type.availableEvents.contains(eventName)) return false;
    if (node.events.any((e) => e.name == eventName)) return false;
    return _mutate<bool>('Add $eventName to ${node.name}', () {
      final suffix = node.fieldName.isEmpty ? '' : node.fieldName[0].toUpperCase() + node.fieldName.substring(1);
      final handler = '${eventName[0].toLowerCase()}${eventName.substring(1)}$suffix';
      node.events.add(UmgEvent(name: eventName, handler: handler));
      return true;
    });
  }

  bool removeEvent(String id, String eventName) {
    final node = _document.findNode(id);
    if (node == null) return false;
    final removed = _mutate<bool>('Remove $eventName from ${node.name}', () {
      final before = node.events.length;
      node.events.removeWhere((e) => e.name == eventName);
      return node.events.length != before;
    });
    // The bound graph node goes with the binding.
    final graphRemoved = (_graphEditor != null || _document.blueprint != null) && graphEditor.removeBoundEvent(node.name, eventName) > 0;
    return removed || graphRemoved;
  }

  /// The prop holding a texture path: an Image's brush, a Container's
  /// background image; null for other types.
  static String? textureKeyOf(UmgWidgetType type) => switch (type) {
        UmgWidgetType.image => 'texture',
        UmgWidgetType.container => 'backgroundImage',
        _ => null,
      };

  /// Binds a real TEXTURE `.lmas` to an Image element or a Container's
  /// background.
  void bindTexture(String id, RealAssetInfo? texture) {
    final node = _document.findNode(id);
    final key = node == null ? null : textureKeyOf(node.type);
    if (key == null) return;
    _textureCache.remove(id);
    setProp(id, key, texture?.relativePath ?? '');
  }

  /// Turns an old Border into a Container with the same
  /// colour, padding, slot and child, as one undo step.
  bool convertBorderToContainer(String id) {
    final node = _document.findNode(id);
    if (node == null || node.type != UmgWidgetType.border) return false;
    return _mutate<bool>('Convert ${node.name} to Container', () {
      final color = node.props['color']?.toString() ?? '#1B1B22';
      final padding = node.props['padding'] is num ? (node.props['padding'] as num).toDouble() : 8.0;
      node.type = UmgWidgetType.container;
      node.props
        ..clear()
        ..addAll(UmgWidgetType.container.defaultProps())
        ..['backgroundColor'] = color.replaceAll('#', '').length == 6 ? '${color.toUpperCase()}FF' : color
        ..['padding'] = [padding, padding, padding, padding]
        ..['cornerRadius'] = 6.0;
      return true;
    });
  }

  /// What stops this document from compiling for the
  /// project's widget library: a shadcn component in a plain-Flutter
  /// project, named with its element.
  List<String> get validationErrors => UmgWidgetValidator.errors(_document, widgetLibrary);

  /// Raw image bytes of the texture bound to [id] (read from disk, cached).
  Uint8List? textureBytesFor(String id) {
    final node = _document.findNode(id);
    if (node == null) return null;
    final key = textureKeyOf(node.type);
    final rel = key == null ? '' : node.props[key]?.toString() ?? '';
    if (rel.isEmpty) return null;
    final cacheKey = '$id:$rel';
    if (_textureCache.containsKey(cacheKey)) return _textureCache[cacheKey];
    Uint8List? bytes;
    final dir = projectDirPath;
    final file = File(rel).isAbsolute ? File(rel) : (dir == null ? null : File('$dir/$rel'));
    if (file != null && file.existsSync()) {
      try {
        final asset = LuminaAsset.fromBytes(file.readAsBytesSync());
        bytes = asset.rawPayload;
      } catch (e) {
        _logger.log('Texture $rel is not a readable .lmas: $e', level: 'warning', source: 'UmgEditor');
      }
    }
    _textureCache[cacheKey] = bytes;
    return bytes;
  }

  void refreshTextures() {
    _refreshTextureAssets();
    _textureCache.clear();
    notifyListeners();
  }
}

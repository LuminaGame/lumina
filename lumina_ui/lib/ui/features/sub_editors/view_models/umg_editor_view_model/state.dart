part of '../umg_editor_view_model.dart';

/// The state every UmgEditorViewModel domain mixin shares: all instance
/// fields (in their original order), the core accessors, and the
/// cross-domain members the mixins call on one another.
abstract class _UmgEditorViewModelState extends ChangeNotifier {
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

  _UmgEditorViewModelState(LuminaAsset? initialAsset, {required this.assetPath, this.projectDirPathOverride}) : _asset = initialAsset;

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

  // ---------------------------------------------------------------------
  // Members the domain mixins use from one another. Each is implemented
  // (with @override) in exactly one mixin.

  // umg_editor_view_model/persistence.dart
  Future<bool> save();
  Future<UmgCompileResult> compile();
  void _refreshTextureAssets();

  // umg_editor_view_model/editing.dart
  T _mutate<T>(String label, T Function() mutation);
  List<String> get validationErrors;
}

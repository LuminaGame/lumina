part of '../landscape_editor_view_model.dart';

/// State shared by the [LandscapeEditorViewModel] domain mixins: every
/// instance field (in the original order, so initialisers run in the same
/// order) and the members the mixins call on one another.
abstract class _LandscapeEditorViewModelState extends ChangeNotifier {

  final EditorViewModel? editor;
  final String? assetPath;
  final LandscapeTerrainSink sink;

  LandscapeData _data = LandscapeData.flat();
  LandscapeSectionMap _sections = LandscapeSectionMap(gridResolution: 129);
  bool _engineOwnsTerrain = false;
  double _cameraX = 0.0;
  double _cameraZ = 0.0;

  // Brush state.
  LandscapeTool _tool = LandscapeTool.sculpt;
  double _brushRadius = 45.0;
  double _brushStrength = 0.5;
  double _brushFalloff = 0.5;
  LandscapeFalloffType _falloffType = LandscapeFalloffType.smooth;

  // Foliage brush state: its own size and falloff, and
  // Paint Density / Erase Density.
  double _foliageBrushRadius = 10.0;
  double _foliageBrushFalloff = 0.5;
  double _paintDensity = 0.5;
  double _eraseDensity = 0.0;

  // A foliage drag (one undo entry, like a sculpt stroke).
  bool _foliageStrokeActive = false;
  bool _foliageStrokeErase = false;
  int _foliageStrokeLayer = -1;
  Float32List? _foliageStrokeBefore;
  double? _foliageLastX;
  double? _foliageLastZ;

  // A brush input from the 3D viewport that has been pressed and not released.
  bool _viewportBrushDown = false;
  bool _viewportBrushInvert = false;

  // Brush settings are persisted per project once the editor has opened.
  bool _persistBrushes = false;
  LandscapeBrushCursorState? _pushedCursor;

  // New-terrain form state.
  int _newResolution = 129;
  double _newWorldSize = 256.0;
  double _newMaxHeight = 100.0;

  LandscapeEditorTab _tab = LandscapeEditorTab.manage;
  FoliagePaintMode _paintMode = FoliagePaintMode.paint;
  int _selectedLayer = -1;

  // Stroke bookkeeping.
  bool _strokeActive = false;
  bool _strokeInvert = false;
  double? _flattenTarget;
  int _strokeSeed = 0;
  double? _lastStampX;
  double? _lastStampZ;
  HeightRect? _strokeRect;
  final Map<int, double> _preStrokeValues = {};

  final List<LandscapeUndoEntry> _undo = [];
  final List<LandscapeUndoEntry> _redo = [];

  bool _dirty = false;
  bool _opened = false;
  String? _statusMessage;
  double? _cursorX;
  double? _cursorZ;
  final math.Random _random;

  _LandscapeEditorViewModelState({
    this.editor,
    this.assetPath,
    LandscapeTerrainSink? sink,
    int randomSeed = 20260920,
  })  : sink = sink ?? const NullTerrainSink(),
        _random = math.Random(randomSeed);
  double? _importProgress;

  // --- Implemented by the domain mixins or [LandscapeEditorViewModel]. ---

  LandscapeData get data;

  void setPreviewCamera(double worldX, double worldZ);

  LandscapeTool get tool;

  LandscapeFalloffType get falloffType;

  double get eraseDensity;

  LandscapeEditorTab get tab;

  double? get flattenTarget;

  int get sectionCount;

  void _saveBrushPreferences();

  void _syncCursor({bool force = false});

  void beginStroke(double worldX, double worldZ, {bool invert = false});

  void strokeTo(double worldX, double worldZ);

  void endStroke();

  void undo();

  void beginFoliageStroke(double worldX, double worldZ, {bool erase = false});

  void foliageStrokeTo(double worldX, double worldZ);

  void endFoliageStroke();

  void _rebuildFoliage();

  void _rebuildFoliageBatch(int index);

  void _uploadRect(HeightRect edited);

  Vector3? raycast(Vector3 origin, Vector3 direction, {double maxDistance = 100000.0});
}

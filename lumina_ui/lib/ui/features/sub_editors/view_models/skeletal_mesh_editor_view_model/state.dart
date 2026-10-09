part of '../skeletal_mesh_editor_view_model.dart';

/// The fields and read-only getters every Skeletal Mesh Editor domain shares.
abstract class _SkeletalMeshEditorViewModelState extends ChangeNotifier {
  final String assetPath;
  LuminaAsset? _asset;
  GlbMeshData? _glbMesh;

  bool _isLoading = true;
  bool _hasError = false;
  bool _isDirty = false;

  int _triangleCount = 0;
  int _vertexCount = 0;
  int _boneCount = 0;
  final int _maxInfluences = 4;

  List<GlbNode> _allBones = [];
  List<GlbNode> _rootBones = [];
  GlbNode? _selectedBone;
  SkeletalMeshSocket? _selectedSocket;

  List<SkeletalMeshSocket> _sockets = [];
  Map<String, String> _boneRetargeting = {}; // boneName -> 'Animation'|'Skeleton'|'AnimationScaled'
  final Map<String, double> _morphWeights = {};

  RigLogicEvaluator? _rigLogicEvaluator;
  String? _dnaPath;
  final Map<String, double> _rigLogicControlValues = {};
  final Map<String, List<double>> _jointDeltas = {};

  bool _showBones = true;
  bool _displaySockets = true;
  bool _heatmapEnabled = false;
  int? _inspectedVertex;
  String _boneSearchFilter = '';

  Float32List? _reusedDeformedPositions;
  Uint8List? _reusedHeatmapColors;

  List<MaterialSlotBinding> _materialSlots = [];
  List<RealAssetInfo> _availableMaterials = const [];
  List<RealAssetInfo> _availableTextures = const [];
  List<RealAssetInfo> _availablePreviewMeshes = const [];
  final Map<int, Uint8List> _slotCompiledMaterials = {};

  /// Socket preview meshes by `.lmas` path: parsed once, null while loading
  /// or when the file is not a mesh.
  final Map<String, GlbMeshData?> _previewMeshes = {};
  bool _disposed = false;

  _SkeletalMeshEditorViewModelState({
    required this.assetPath,
    LuminaAsset? initialAsset,
  }) : _asset = initialAsset;

  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  bool get isDirty => _isDirty;
  LuminaAsset? get asset => _asset;
  GlbMeshData? get glbMesh => _glbMesh;

  int get triangleCount => _triangleCount;
  int get vertexCount => _vertexCount;
  int get boneCount => _boneCount;
  int get maxInfluences => _glbMesh?.maxInfluences ?? _maxInfluences;

  List<GlbNode> get allBones => List.unmodifiable(_allBones);
  List<GlbNode> get rootBones => List.unmodifiable(_rootBones);
  GlbNode? get selectedBone => _selectedBone;
  SkeletalMeshSocket? get selectedSocket => _selectedSocket;

  List<SkeletalMeshSocket> get sockets => List.unmodifiable(_sockets);
  Map<String, String> get boneRetargeting => Map.unmodifiable(_boneRetargeting);

  List<GlbMorphTarget> get morphTargets => _glbMesh?.morphTargets ?? const [];
  Map<String, double> get morphWeights => Map.unmodifiable(_morphWeights);
  int get activeMorphTargetCount => _morphWeights.values.where((w) => w != 0.0).length;

  bool get hasRigLogic => _rigLogicEvaluator != null;
  RigLogicEvaluator? get rigLogic => _rigLogicEvaluator;
  String? get dnaPath => _dnaPath;
  List<String> get rigLogicControlNames => _rigLogicEvaluator?.rawControlNames ?? const [];
  Map<String, double> get rigLogicControlValues => Map.unmodifiable(_rigLogicControlValues);
  Map<String, List<double>> get jointDeltas => Map.unmodifiable(_jointDeltas);

  bool get showBones => _showBones;
  bool get displaySockets => _displaySockets;
  bool get heatmapEnabled => _heatmapEnabled;
  int? get inspectedVertex => _inspectedVertex;
  String get boneSearchFilter => _boneSearchFilter;

  List<String> get allBoneNames => _allBones.map((b) => b.name).toList();

  /// One entry per geometry section, keyed `element_<i>`.
  List<MaterialSlotBinding> get materialSlots => List.unmodifiable(_materialSlots);

  /// Real FILAMAT `.lmas` in this project, for the slot picker.
  List<RealAssetInfo> get availableMaterials => List.unmodifiable(_availableMaterials);

  /// Real texture `.lmas` in this project, for the sampler pickers.
  List<RealAssetInfo> get availableTextures => List.unmodifiable(_availableTextures);

  /// Real static and skeletal mesh `.lmas` in this project (what MCP
  /// `set_skeletal_socket` accepts), for a socket's Preview Asset picker.
  List<RealAssetInfo> get availablePreviewMeshes => List.unmodifiable(_availablePreviewMeshes);

  /// Project root for this asset: the nearest ancestor that owns a `contents/`
  /// directory. Returns null when the asset lives outside a project.
  String? get projectRoot {
    var dir = File(assetPath).parent;
    for (var i = 0; i < 12; i++) {
      if (Directory('${dir.path}/contents').existsSync()) return dir.path;
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
    return null;
  }
}

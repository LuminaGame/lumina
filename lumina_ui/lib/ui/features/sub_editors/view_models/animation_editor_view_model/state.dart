part of '../animation_editor_view_model.dart';

/// State shared by the [AnimationEditorViewModel] domain mixins: every
/// instance field (in the original order, so initialisers run in the same
/// order) and the members the mixins call on one another.
abstract class _AnimationEditorViewModelState extends ChangeNotifier {
  final String assetPath;
  final LuminaAsset? initialAsset;

  LuminaAsset? _asset;
  GlbMeshData? _glbMesh;
  bool _isLoading = true;
  bool _hasError = false;
  bool _isDirty = false;

  List<GlbAnimationClip> _clips = [];
  int _selectedClip = 0;
  bool _isPlaying = false;
  bool _isLooping = true;
  double _speed = 1.0;
  double _rateScale = 1.0;
  double _positionSeconds = 0.0;
  double _frameRate = 30.0;
  String _interpolation = 'Linear'; // 'Linear' or 'Step'
  String _additiveType = 'No Additive'; // 'No Additive', 'Local Space', 'Mesh Space'

  // Notifies, Curves, BlendSpace & Root Motion
  List<EditorAnimNotify> _notifies = [];
  List<AnimCurveData> _curves = [];
  BlendSpaceData _blendSpace = BlendSpaceData();
  double _blendParamX = 0.0;
  double _blendParamY = 0.0;
  bool _enableRootMotion = false;
  final List<EditorAnimNotify> _recentlyFiredNotifies = [];

  // Preview Mesh & Retargeting
  RealAssetInfo? _previewMeshAsset;
  String? _previewMeshPath;
  List<RealAssetInfo> _availableSkeletalMeshes = [];

  // Dope Sheet & Timeline Keyframing
  double _timelineZoom = 1.0;
  bool _snapToFrames = true;
  int _snapInterval = 1;
  final Set<String> _selectedKeyframeIds = {};

  Ticker? _ticker;
  Duration? _lastElapsed;

  final AnimationPlaybackController playbackController = AnimationPlaybackController();

  _AnimationEditorViewModelState({
    required this.assetPath,
    this.initialAsset,
    TickerProvider? vsync,
  }) {
    if (vsync != null) {
      _ticker = vsync.createTicker(_onTick);
    }
  }

  String _boneSearchQuery = '';

  // --- Implemented by the domain mixins or [AnimationEditorViewModel]. ---

  LuminaAsset? get asset;

  List<GlbAnimationClip> get clips;

  String get interpolation;

  GlbAnimationClip? get activeClip;

  double get duration;

  int get currentFrame;

  EditorBlendSample? get dominantSample;

  void play();

  void selectClip(int index);

  void _onTick(Duration elapsed);

  void _updatePlaybackController();

  void addCurve(String name);

  void addCurveKey(String curveName, double time, double value);

  Future<bool> save();
}

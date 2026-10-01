part of '../sequencer_view_model.dart';

/// State shared by the [SequencerViewModel] domain mixins: every
/// instance field (in the original order, so initialisers run in the same
/// order) and the members the mixins call on one another.
abstract class _SequencerViewModelState extends ChangeNotifier {
  final String assetPath;
  final LuminaAsset? initialAsset;
  final TransactionManager transactions;

  LuminaAsset? _asset;
  SequencerData _data = SequencerData();
  bool _isLoading = true;
  bool _hasError = false;
  bool _isDirty = false;

  /// Playhead as a fractional frame so ticker-driven playback never drifts;
  /// [playheadFrame] is the rounded value used for display and snapping.
  double _playheadPosition = 0.0;
  String? _selectedTrackId;
  SequencerKeyRef? _selectedKey;
  final Set<SequencerKeyRef> _selectedKeys = {};

  // Playback
  bool _isPlaying = false;
  bool _isLooping = false;
  int _rangeStart = 0;
  int? _rangeEnd; // null = end of sequence
  SequencerTimeFormat _timeFormat = SequencerTimeFormat.timecode;
  Ticker? _ticker;
  Duration? _lastElapsed;

  // Live-level binding (the actors the cinematic drives) and the per-channel
  // restore snapshot captured before the first write.
  List<EditorActorNode> Function()? _levelActors;
  VoidCallback? _onLevelChanged;
  final Map<String, _ChannelSnapshot> _snapshot = {};

  /// Selects an actor in the level (the track outliner's click), installed by
  /// [bindLevel].
  void Function(String actorId)? _selectLevelActor;

  // Keying from the viewport: Auto Key, the gizmo edit in progress (actor id
  // → transform before the gesture) and, with Auto Key off, the previews not
  // keyed yet (actor id → transform before the first previewed gesture).
  bool _autoKey;

  /// Called when [SequencerViewModel.setAutoKey] changes Auto Key (the editor
  /// stores it in its preferences).
  ValueChanged<bool>? onAutoKeyChanged;
  final Map<String, _ActorTransform> _editBefore = {};
  final Map<String, _ActorTransform> _pendingPreview = {};

  /// Keys whose in/out tangents are edited independently ("Cubic (Broken)").
  /// Editor-side only: the `.lmas` schema carries the two tangent values, and
  /// unequal tangents survive a reload as-is.
  final Set<String> _brokenTangentKeys = {};

  // Movie render queue
  late final MovieRenderService _renderService;
  String? _projectDirPath;
  bool _isRendering = false;
  bool _renderRequiresSave = false;
  MovieRenderProgress? _renderProgress;
  String? _renderMessage;
  String? _renderError;
  Directory? _lastRenderDir;
  MovieRenderCancellationToken? _renderToken;

  _SequencerViewModelState({
    required this.assetPath,
    this.initialAsset,
    TransactionManager? transactionManager,
    TickerProvider? vsync,
    List<EditorActorNode> Function()? levelActorsProvider,
    VoidCallback? onLevelChanged,
    String? projectDirPath,
    MovieRenderService renderService = const MovieRenderService(),
    bool autoKey = true,
  }) : _autoKey = autoKey, // ignore: prefer_initializing_formals
       transactions = transactionManager ?? TransactionManager() {
    _renderService = renderService;
    _projectDirPath = projectDirPath;
    _levelActors = levelActorsProvider;
    _onLevelChanged = onLevelChanged;
    if (vsync != null) attachTicker(vsync);
  }

  // --- Implemented by the domain mixins or [SequencerViewModel]. ---

  LuminaAsset? get asset;

  int get fps;

  int get lengthFrames;

  int get playheadFrame;

  set playheadFrame(int frame);

  List<SequencerTrack> get tracks;

  int get rangeEnd;

  void undo();

  void redo();

  String get fileBasename;

  void scrubToFrame(int frame);

  void _setPlayhead(double position);

  SequencerTrack? findTrack(String trackId);

  SequencerChannel? findChannel(String trackId, String channelName);

  void setKeyInterpolation(String trackId, String channelName, int keyIndex, KeyInterpolation interp);

  String _keyId(String trackId, String channelName, int keyIndex);

  void restoreLevel();

  void _applyPlayheadToLevel();

  void attachTicker(TickerProvider vsync);

  void pause();

  void stop();

  String get projectDirPath;

  set projectDirPath(String value);

  Future<bool> save();

  void _revertPendingPreviews(List<EditorActorNode> actors);

  EditorActorNode? _findActor(List<EditorActorNode> actors, String id);
}

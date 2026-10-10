part of '../blueprint_preview_scene.dart';

/// The preview's state, shared by its picking and overlay domains.
abstract class _BlueprintPreviewSceneState extends ChangeNotifier {
  LuminaWorld? _world;
  bool _ownsWorld = false;
  Timer? _timer;
  final List<LuminaActor> _environment = [];

  LuminaBlueprintDocument? _document;
  String? _signature;
  String? _projectDir;
  LuminaBlueprintClassRegistry? _registry;

  LuminaActor? _actor;
  Map<String, LuminaActorComponent> _built = const {};
  int _revision = 0;
  String? _selected;
  List<SubEditorLineSet>? _overlays;
  String? _lastState;
  bool _disposed = false;
  bool _notifyScheduled = false;

  /// Frames since the textures were last checked, and what each texture
  /// file was then (modified time and size), by path.
  int _framesSinceTextureCheck = 0;
  Map<String, String> _textureStamps = const {};

  /// Listeners hear about a change after the current frame: the viewport
  /// hands its world over from inside a build, where a rebuild request is
  /// not allowed.
  void _notify() {
    if (_disposed || _notifyScheduled) return;
    _notifyScheduled = true;
    scheduleMicrotask(() {
      _notifyScheduled = false;
      if (!_disposed) notifyListeners();
    });
  }
}

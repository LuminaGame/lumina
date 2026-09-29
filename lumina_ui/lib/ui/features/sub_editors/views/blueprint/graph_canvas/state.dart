part of '../graph_canvas.dart';

/// State shared by the graph canvas's domain mixins: every instance field
/// (in the original order) and the members the mixins call on one another.
abstract class _BlueprintGraphCanvasStateBase extends State<BlueprintGraphCanvas> {
  Offset _pan = const Offset(40, 40);
  double _zoom = 1.0;
  Size _size = Size.zero;
  int _buttons = 0;
  bool _rightDragged = false;

  Offset? _marqueeStart;
  Offset? _marqueeEnd;

  BlueprintPinRef? _dragFrom;
  Offset? _dragPointer;
  String? _dragRefusal;

  final FocusNode _focus = FocusNode(debugLabel: 'BlueprintGraphCanvas');
  final GlobalKey _stackKey = GlobalKey();

  /// Double-click detection without a DoubleTapGestureRecognizer, which
  /// would hold every single tap on the canvas and its nodes for the
  /// double-tap timeout: two taps on the same target within 350 ms.
  DateTime? _lastTapAt;
  Object? _lastTapTarget;

  ({String nodeId, String pinId})? _hoverPin;
  Offset _hoverAt = Offset.zero;

  // --- Implemented by the domain mixins or [BlueprintGraphCanvasState]. ---

  BlueprintGraphEditor get editor;

  bool _isDoubleTap(Object target);

  Offset _toCanvas(Offset local);

  Offset toScreen(Offset canvas);

  Offset _localFromGlobal(Offset global);

  LuminaBlueprintNode? addCommentAroundSelection({Offset? at});

  void _promptName(String title, String initial, ValueChanged<String> onDone);

  void openNodePalette(Offset localPosition, {BlueprintPinRef? from});

  void _startWire(BlueprintPinRef from, Offset global);

  void _updateWire(Offset global);

  void _endWire();

  void _showNodeMenu(LuminaBlueprintNode node, Offset global);
}

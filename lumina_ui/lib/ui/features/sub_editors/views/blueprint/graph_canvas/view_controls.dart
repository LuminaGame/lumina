part of '../graph_canvas.dart';

/// Canvas/screen coordinates, framing, canvas actions, comment creation,
/// the name prompt and the node palette.
mixin _BlueprintGraphCanvasViewControls on _BlueprintGraphCanvasStateBase {
  @override
  bool _isDoubleTap(Object target) {
    final now = DateTime.now();
    final double = _lastTapTarget == target && _lastTapAt != null && now.difference(_lastTapAt!) < const Duration(milliseconds: 350);
    _lastTapAt = double ? null : now;
    _lastTapTarget = double ? null : target;
    return double;
  }

  void _onFocusRequest() {
    final request = editor.focusRequest.value;
    if (request != null) frameNode(request.nodeId);
  }

  @override
  Offset _toCanvas(Offset local) => (local - _pan) / _zoom;
  @override
  Offset toScreen(Offset canvas) => canvas * _zoom + _pan;

  @override
  Offset _localFromGlobal(Offset global) {
    final box = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    return box == null ? global : box.globalToLocal(global);
  }

  /// Screen (canvas-widget local) position of a pin, for tests and drags.
  Offset? pinScreenPosition(String nodeId, String pinId, {required bool output}) {
    final n = editor.node(nodeId);
    if (n == null) return null;
    final c = BlueprintNodeLayout.of(editor, n).pinCenter(pinId, output: output);
    return c == null ? null : toScreen(c);
  }

  /// Centres canvas point [canvas] in the view (tests place nodes at known
  /// canvas coordinates below the existing graph).
  void frameCanvasPoint(Offset canvas) {
    if (!mounted) return;
    setState(() => _pan = Offset(_size.width / 2, _size.height / 2) - canvas * _zoom);
  }

  /// Centres [nodeId] in the view.
  void frameNode(String nodeId) {
    final n = editor.node(nodeId);
    if (n == null || !mounted) return;
    final rect = BlueprintNodeLayout.of(editor, n).rect;
    setState(() => _pan = Offset(_size.width / 2, _size.height / 2) - rect.center * _zoom);
  }

  /// Runs a palette action row at canvas [at].
  void runAction(BlueprintPaletteAction action, Offset at) {
    switch (action) {
      case BlueprintPaletteAction.promoteToVariable:
        return;
      case BlueprintPaletteAction.addCustomEvent:
        _promptName('Add Custom Event', 'CustomEvent', (name) {
          final placed = editor.addCustomEvent(name, at);
          if (placed != null) editor.select(placed.id);
        });
      case BlueprintPaletteAction.addComment:
        addCommentAroundSelection(at: at);
      case BlueprintPaletteAction.collapseNodes:
        widget.actions.onCollapse?.call(toMacro: true, named: false);
      case BlueprintPaletteAction.collapseToFunction:
        widget.actions.onCollapse?.call(toMacro: false, named: true);
      case BlueprintPaletteAction.collapseToMacro:
        widget.actions.onCollapse?.call(toMacro: true, named: true);
    }
  }

  /// `C`: a comment around the selected nodes, or an empty one at
  /// [at] when nothing is selected.
  @override
  LuminaBlueprintNode? addCommentAroundSelection({Offset? at}) {
    final selected = [for (final id in editor.selectedNodeIds) editor.node(id)!];
    if (selected.isEmpty) return editor.addComment(position: at ?? _toCanvas(Offset(_size.width / 2, _size.height / 2)));
    Rect? bounds;
    for (final n in selected) {
      final r = BlueprintNodeLayout.of(editor, n).rect;
      bounds = bounds == null ? r : bounds.expandToInclude(r);
    }
    return editor.addComment(around: bounds);
  }

  /// A one-field dialog for a name (custom events, collapse targets).
  @override
  void _promptName(String title, String initial, ValueChanged<String> onDone) {
    final controller = TextEditingController(text: initial);
    showOverlay(
      context,
      const DialogConfiguration(),
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 280,
          child: TextField(
            key: const ValueKey('graph_name_field'),
            controller: controller,
            autofocus: true,
            onSubmitted: (v) {
              closeOverlay(dialogContext);
              onDone(v);
            },
          ),
        ),
        actions: [
          GhostButton(onPressed: () => closeOverlay(dialogContext), child: const Text('Cancel')),
          PrimaryButton(
            key: const ValueKey('graph_name_ok'),
            onPressed: () {
              closeOverlay(dialogContext);
              onDone(controller.text);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Opens the node palette at [localPosition]; [from] makes it context
  /// sensitive and wires the placed node to that pin.
  @override
  void openNodePalette(Offset localPosition, {BlueprintPinRef? from}) {
    final canvasPos = _toCanvas(localPosition);
    var entries = [
      ...editor.paletteActions(canCollapse: widget.actions.onCollapse != null),
      ...editor.paletteEntries(),
    ];
    String? fromLabel;
    String? fromTypeLabel;
    Color? fromColor;
    if (from != null) {
      entries = editor.paletteEntriesFor(from);
      final fromNode = editor.node(from.nodeId);
      final fromPin = editor.pin(from.nodeId, from.pinId, output: from.isOutput);
      fromLabel = fromPin?.name;
      if (fromNode != null && fromPin != null) {
        fromTypeLabel = editor.pinTypeLabel(fromNode, fromPin, output: from.isOutput);
        fromColor = editor.pinColor(fromNode, fromPin, output: from.isOutput);
      }
    }
    showOverlay(
      context,
      const DialogConfiguration(),
      builder: (dialogContext) => BlueprintNodePalette(
        entries: entries,
        context: editor.context,
        from: from,
        fromLabel: fromLabel,
        fromTypeLabel: fromTypeLabel,
        fromColor: fromColor,
        onSelect: (entry) {
          closeOverlay(dialogContext);
          if (entry.action != null && entry.action != BlueprintPaletteAction.promoteToVariable) {
            runAction(entry.action!, canvasPos);
            return;
          }
          final placed = editor.placeEntry(entry, canvasPos, from: from);
          if (placed != null) editor.select(placed.id);
        },
        onClose: () => closeOverlay(dialogContext),
      ),
    );
  }
}

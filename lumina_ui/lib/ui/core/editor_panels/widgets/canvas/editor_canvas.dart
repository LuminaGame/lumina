import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:lumina_editor_data/lumina_editor.dart' show LuminaAsset, LuminaEditorWidgetEvents;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/editor_panels/widgets/canvas/canvas_geometry.dart';
import 'package:lumina_ui/ui/core/editor_panels/widgets/canvas/canvas_item_painter.dart';
import 'package:lumina_ui/ui/core/editor_panels/widgets/interaction/editor_interaction.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

/// The native canvas of editor panels and JSON specs: a 2D draw list
/// (lines, polylines, rects, circles, SVG paths, text, images) in local
/// pixels or normalised 0–1 space, with hit regions (click, hover), local
/// drags of draggable items (throttled previews, one commit, Escape
/// cancels) and an optional pannable / zoomable view box.
///
/// Each item paints on its own layer and the draw list is diffed by item
/// id: a change to one item repaints only that item.
class EditorCanvas extends StatefulWidget {
  const EditorCanvas({super.key, required this.name, required this.state, required this.onEvent, required this.onState, this.projectDir});

  final String name;
  final Map<String, Object?> state;
  final EditorWidgetEventSink onEvent;
  final EditorWidgetStateSink onState;

  /// Where `image` items' project paths resolve.
  final String? projectDir;

  @override
  State<EditorCanvas> createState() => EditorCanvasState();
}

class EditorCanvasState extends State<EditorCanvas> {
  final EditorStateSnapshot _snapshot = EditorStateSnapshot();
  final EditorPreviewThrottle _throttle = EditorPreviewThrottle();
  final FocusNode _focus = FocusNode(debugLabel: 'Canvas');
  PluginCanvasState _canvas = const PluginCanvasState();
  List<CanvasEntry> _entries = const [];
  final Map<String, CanvasEntry> _byId = {};
  String? _error;
  String? _hover;
  Size _size = Size.zero;

  /// The view box after the user's pan / zoom (null: the state's).
  List<double>? _box;

  // The drag in progress.
  int? _pointer;
  CanvasEntry? _dragEntry;
  Offset _downPixel = Offset.zero;
  bool _moved = false;
  bool _panning = false;

  /// The entries drawn (tests).
  List<CanvasEntry> get entries => _entries;

  @override
  void initState() {
    super.initState();
    _adopt(first: true);
  }

  @override
  void didUpdateWidget(EditorCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    _adopt();
  }

  void _adopt({bool first = false}) {
    final changed = _snapshot.changedKeys(widget.state, PluginCanvasState.stateKeys);
    if (!first && changed.isEmpty) return;
    try {
      _canvas = PluginCanvasState.fromJson(widget.state, path: widget.name);
      if (first || changed.contains('viewBox')) _box = null;
      if (first || changed.contains('items')) _diff();
      _error = null;
    } on FormatException catch (e) {
      _error = e.message;
    }
  }

  /// Keeps the entry of every item whose JSON is unchanged.
  void _diff() {
    final next = <CanvasEntry>[];
    final seen = <String>{};
    for (final item in _canvas.items) {
      if (!seen.add(item.id)) continue;
      final json = item.toJson();
      final old = _byId[item.id];
      final entry = old != null && editorJsonEquals(old.json, json) ? old : CanvasEntry(item, json);
      _byId[item.id] = entry;
      next.add(entry);
      if (entry.item.kind == PluginCanvasItemKind.image && entry.image == null) unawaited(_loadImage(entry));
    }
    _byId.removeWhere((id, _) => !seen.contains(id));
    _entries = next;
  }

  Future<void> _loadImage(CanvasEntry entry) async {
    final path = entry.item.image;
    if (path == null || path.isEmpty) return;
    try {
      final normal = path.replaceAll(r'\', '/');
      final absolute = normal.startsWith('/') || RegExp(r'^[A-Za-z]:/').hasMatch(normal);
      final dir = widget.projectDir;
      final file = File(absolute || dir == null ? normal : '$dir/$normal');
      var bytes = await file.readAsBytes();
      // A texture asset: its payload is the image.
      if (normal.toLowerCase().endsWith('.lmas')) bytes = LuminaAsset.fromBytes(bytes).rawPayload ?? bytes;
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (!mounted || !identical(_byId[entry.item.id], entry)) return;
      setState(() {
        final loaded = entry.withImage(frame.image);
        _byId[entry.item.id] = loaded;
        _entries = [for (final e in _entries) identical(e, entry) ? loaded : e];
      });
    } catch (e) {
      debugPrint('[EditorCanvas] ${widget.name}: cannot load image $path: $e');
    }
  }

  @override
  void dispose() {
    _throttle.dispose();
    _focus.dispose();
    super.dispose();
  }

  // --- View ----------------------------------------------------------------------

  List<double> get _viewBox {
    final b = _box ?? _canvas.viewBox?.map((v) => v.toDouble()).toList();
    if (b != null && b.length == 4 && b[2] > 0 && b[3] > 0) return b;
    if (_canvas.space == PluginCanvasSpace.normalized) return const [0, 0, 1, 1];
    return [0, 0, math.max(1, _size.width), math.max(1, _size.height)];
  }

  CanvasView get _view {
    final b = _viewBox;
    return CanvasView(b[0], b[1], _size.width / b[2], _size.height / b[3]);
  }

  CanvasEntry? _hitAt(Offset p) {
    final view = _view;
    for (final e in _entries.reversed) {
      if ((e.item.hit || e.item.draggable) && canvasHit(e, view, p)) return e;
    }
    return null;
  }

  Map<String, Object?> _pos(Offset item) => {'x': double.parse(item.dx.toStringAsFixed(4)), 'y': double.parse(item.dy.toStringAsFixed(4))};

  // --- Input ---------------------------------------------------------------------

  void _down(PointerDownEvent e) {
    _focus.requestFocus();
    if (_pointer != null) return;
    if (e.buttons == kMiddleMouseButton && _canvas.panZoom) {
      _pointer = e.pointer;
      _panning = true;
      return;
    }
    if (e.buttons != kPrimaryMouseButton) return;
    _pointer = e.pointer;
    _downPixel = e.localPosition;
    _moved = false;
    _dragEntry = _hitAt(e.localPosition);
  }

  void _move(PointerMoveEvent e) {
    if (e.pointer != _pointer) return;
    if (_panning) {
      final b = _viewBox;
      final v = _view;
      setState(() => _box = [b[0] - e.delta.dx / v.scaleX, b[1] - e.delta.dy / v.scaleY, b[2], b[3]]);
      return;
    }
    final entry = _dragEntry;
    if (entry == null || !entry.item.draggable) return;
    if (!_moved && (e.localPosition - _downPixel).distance < 3) return;
    _moved = true;
    final v = _view;
    final d = Offset((e.localPosition.dx - _downPixel.dx) / v.scaleX, (e.localPosition.dy - _downPixel.dy) / v.scaleY);
    final moved = CanvasEntry(PluginCanvasItem.fromJsonMap(canvasMoved(entry.json, d)), canvasMoved(entry.json, d));
    _replace(entry.item.id, moved);
    final at = _pos(canvasAnchor(moved.item));
    _throttle.preview(() => widget.onEvent(EditorWidgetEvent(LuminaEditorWidgetEvents.onItemDragPreview, PluginEditorWidgetEventKind.itemDragged,
        {'item_id': entry.item.id, ...at}, phase: PluginViewEventPhase.preview)));
  }

  void _replace(String id, CanvasEntry entry) {
    setState(() {
      _byId[id] = entry;
      _entries = [for (final x in _entries) x.item.id == id ? entry : x];
    });
  }

  void _up(PointerEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    if (_panning) {
      _panning = false;
      _commitView();
      return;
    }
    final entry = _dragEntry;
    _dragEntry = null;
    _throttle.end();
    final at = _view.toItem(e.localPosition);
    if (entry == null) {
      widget.onEvent(EditorWidgetEvent(LuminaEditorWidgetEvents.onBackgroundClicked, PluginEditorWidgetEventKind.backgroundClicked, _pos(at)));
      return;
    }
    if (!_moved) {
      if (entry.item.hit) {
        widget.onEvent(EditorWidgetEvent(LuminaEditorWidgetEvents.onItemClicked, PluginEditorWidgetEventKind.itemClicked,
            {'item_id': entry.item.id, ..._pos(at)}));
      }
      return;
    }
    final now = _byId[entry.item.id]!;
    widget.onEvent(EditorWidgetEvent(LuminaEditorWidgetEvents.onItemDragCommit, PluginEditorWidgetEventKind.itemDragged,
        {'item_id': entry.item.id, ..._pos(canvasAnchor(now.item))}));
    widget.onState({'items': [for (final x in _entries) x.json]}, edit: true);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent || e.logicalKey != LogicalKeyboardKey.escape) return KeyEventResult.ignored;
    final entry = _dragEntry;
    if (entry == null || !_moved) return KeyEventResult.ignored;
    _throttle.end();
    _dragEntry = null;
    _pointer = null;
    _replace(entry.item.id, entry);
    widget.onEvent(EditorWidgetEvent(LuminaEditorWidgetEvents.onItemDragCancel, PluginEditorWidgetEventKind.itemDragged,
        {'item_id': entry.item.id, ..._pos(canvasAnchor(entry.item))}, phase: PluginViewEventPhase.cancel));
    return KeyEventResult.handled;
  }

  void _hoverAt(Offset p) {
    if (_pointer != null) return;
    final hit = _hitAt(p);
    final id = hit != null && hit.item.hit ? hit.item.id : null;
    if (id == _hover) return;
    setState(() => _hover = id);
    widget.onEvent(EditorWidgetEvent(LuminaEditorWidgetEvents.onItemHover, PluginEditorWidgetEventKind.itemHover, {'item_id': id ?? ''}));
  }

  void _wheel(PointerSignalEvent e) {
    if (e is! PointerScrollEvent || !_canvas.panZoom) return;
    final b = _viewBox;
    final v = _view;
    if (HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed) {
      final f = e.scrollDelta.dy < 0 ? 1 / 1.2 : 1.2;
      final at = v.toItem(e.localPosition);
      setState(() => _box = [at.dx - (at.dx - b[0]) * f, at.dy - (at.dy - b[1]) * f, b[2] * f, b[3] * f]);
    } else {
      setState(() => _box = [b[0] + e.scrollDelta.dx / v.scaleX, b[1] + e.scrollDelta.dy / v.scaleY, b[2], b[3]]);
    }
    _commitView();
  }

  void _commitView() {
    final b = _box;
    if (b == null) return;
    double r(double v) => double.parse(v.toStringAsFixed(4));
    widget.onState({'viewBox': {'x': r(b[0]), 'y': r(b[1]), 'width': r(b[2]), 'height': r(b[3]), 'panZoom': _canvas.panZoom}}, edit: false);
  }

  // --- Build ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null) return EditorWidgetStateError(message: 'Canvas ${widget.name}: $error');
    final hovered = _hover == null ? null : _byId[_hover!];
    return Focus(
      focusNode: _focus,
      onKeyEvent: _onKey,
      child: LayoutBuilder(builder: (context, constraints) {
        _size = Size(constraints.maxWidth.isFinite ? constraints.maxWidth : 300, constraints.maxHeight.isFinite ? constraints.maxHeight : 200);
        final view = _view;
        return MouseRegion(
          cursor: canvasCursor(hovered?.item.cursor ?? (hovered != null ? 'pointer' : null)),
          onHover: (e) => _hoverAt(e.localPosition),
          onExit: (_) => _hoverAt(const Offset(-1e9, -1e9)),
          child: Listener(
            key: ValueKey('editor_canvas_${widget.name}'),
            behavior: HitTestBehavior.opaque,
            onPointerDown: _down,
            onPointerMove: _move,
            onPointerUp: _up,
            onPointerCancel: _up,
            onPointerSignal: _wheel,
            child: ClipRect(
              child: Container(
                width: _size.width,
                height: _size.height,
                color: editorWidgetColor(_canvas.background, EditorColors.graphCanvas),
                child: Stack(children: [
                  for (final e in _entries)
                    Positioned.fill(
                      key: ValueKey('editor_canvas_${widget.name}_item_${e.item.id}'),
                      child: RepaintBoundary(
                        child: CustomPaint(painter: CanvasItemPainter(e, view, hovered: identical(e, hovered))),
                      ),
                    ),
                ]),
              ),
            ),
          ),
        );
      }),
    );
  }
}

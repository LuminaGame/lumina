import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:lumina_editor_data/lumina_editor.dart' show LuminaEditorWidgetEvents;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/editor_panels/widgets/interaction/editor_interaction.dart';
import 'package:lumina_ui/ui/core/editor_panels/widgets/timeline/timeline_chrome.dart';
import 'package:lumina_ui/ui/core/editor_panels/widgets/timeline/timeline_layout.dart';
import 'package:lumina_ui/ui/core/editor_panels/widgets/timeline/timeline_model.dart';
import 'package:lumina_ui/ui/core/editor_panels/widgets/timeline/timeline_playhead_painter.dart';
import 'package:lumina_ui/ui/core/editor_panels/widgets/timeline/timeline_ruler_painter.dart';
import 'package:lumina_ui/ui/core/editor_panels/widgets/timeline/timeline_tracks_painter.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

/// What a timeline's playhead drives besides itself: a Viewport node's
/// animation time ([drive] while playing or scrubbing, [settle] when the
/// playhead stops), set locally with no graph run and no process message.
abstract interface class TimelineViewportDriver {
  void drive(double seconds);
  void settle(double seconds);
}

/// The native timeline of editor panels and JSON specs: tracks with group
/// headers, a frame / seconds ruler, clips (move, resize within their
/// length limits, inline text), keyframes (drag with Shift multi-select or
/// a box, double-click to add, Delete), a scrubbable playhead, a transport
/// bar, Ctrl + wheel zoom around the cursor and wheel / middle-drag pan.
///
/// [state] is the element state or the spec's props
/// ([PluginTimelineState]). Everything per frame stays here: playback
/// advances the playhead at the state's fps on its own layer; only the
/// interaction contract's events leave ([onEvent]) and committed changes go
/// to [onState].
class EditorTimeline extends StatefulWidget {
  const EditorTimeline({super.key, required this.name, required this.state, required this.onEvent, required this.onState, this.viewport});

  /// The element or control name (widget keys).
  final String name;
  final Map<String, Object?> state;
  final EditorWidgetEventSink onEvent;
  final EditorWidgetStateSink onState;
  final TimelineViewportDriver? viewport;

  @override
  State<EditorTimeline> createState() => EditorTimelineState();
}

class EditorTimelineState extends State<EditorTimeline> with SingleTickerProviderStateMixin {
  late final TimelineModel model = TimelineModel(onEvent: (e) => widget.onEvent(e), onState: _onState);
  final EditorStateSnapshot _snapshot = EditorStateSnapshot();
  final FocusNode _focus = FocusNode(debugLabel: 'Timeline');
  late final Ticker _ticker = createTicker(_tick);
  String? _error;
  double _playFrom = 0;
  bool _scrubbing = false;
  bool _panning = false;
  int? _pointer;
  String? _editingClip;
  final TextEditingController _clipText = TextEditingController();

  void _onState(Map<String, Object?> changes, {required bool edit}) => widget.onState(changes, edit: edit);

  @override
  void initState() {
    super.initState();
    _adopt(first: true);
    model.addListener(_changed);
    model.playing.addListener(_syncTicker);
  }

  @override
  void didUpdateWidget(EditorTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    _adopt();
  }

  void _adopt({bool first = false}) {
    final changed = _snapshot.changedKeys(widget.state, PluginTimelineState.stateKeys);
    if (!first && changed.isEmpty) return;
    try {
      model.adopt(PluginTimelineState.fromJson(widget.state, path: widget.name), changed, first: first);
      _error = null;
    } on FormatException catch (e) {
      _error = e.message;
    }
    if (first) _syncTicker();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    model.dispose();
    _focus.dispose();
    _clipText.dispose();
    super.dispose();
  }

  // --- Playback ----------------------------------------------------------------

  void _syncTicker() {
    final on = model.playing.value;
    if (on && !_ticker.isActive) {
      if (!model.loop && model.playhead.value >= model.rangeEnd - 1) model.setPlayhead(model.rangeStart.toDouble());
      _playFrom = model.playhead.value;
      _ticker.start();
    } else if (!on && _ticker.isActive) {
      _ticker.stop();
      widget.viewport?.settle(model.playhead.value.floor() / model.state.fps);
    }
  }

  void _tick(Duration elapsed) {
    final fps = model.state.fps;
    var frame = _playFrom + elapsed.inMicroseconds * fps / 1e6;
    final start = model.rangeStart;
    final end = model.rangeEnd;
    if (frame >= end) {
      if (model.loop && end > start) {
        frame = start + (frame - start) % (end - start);
      } else {
        model.setPlayhead((end - 1).toDouble());
        model.setPlaying(false);
        return;
      }
    }
    model.setPlayhead(frame);
    widget.viewport?.drive(frame.floor() / fps);
  }

  void togglePlay() {
    model.setPlaying(!model.playing.value);
  }

  // --- Input -------------------------------------------------------------------

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.escape) {
      return model.cancelDrag() ? KeyEventResult.handled : KeyEventResult.ignored;
    }
    if (_editingClip != null) return KeyEventResult.ignored;
    if (k == LogicalKeyboardKey.space && e is KeyDownEvent) {
      togglePlay();
    } else if (k == LogicalKeyboardKey.arrowLeft) {
      _stepTo(model.playhead.value.floor() - 1);
    } else if (k == LogicalKeyboardKey.arrowRight) {
      _stepTo(model.playhead.value.floor() + 1);
    } else if (k == LogicalKeyboardKey.home) {
      _stepTo(model.rangeStart);
    } else if (k == LogicalKeyboardKey.end) {
      _stepTo(model.rangeEnd - 1);
    } else if (k == LogicalKeyboardKey.delete || k == LogicalKeyboardKey.backspace) {
      model.deleteSelectedKeys();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  void _stepTo(int frame) {
    if (model.playing.value) model.setPlaying(false);
    model.setPlayhead(frame.toDouble());
    model.commitPlayhead();
    widget.viewport?.settle(model.playhead.value.floor() / model.state.fps);
  }

  void _scrubAt(double x, TimelineLayout l) {
    model.setPlayhead(l.frameAt(x).roundToDouble());
    widget.viewport?.drive(model.playhead.value.floor() / model.state.fps);
  }

  void _rulerDown(PointerDownEvent e, TimelineLayout l) {
    _focus.requestFocus();
    if (model.playing.value) model.setPlaying(false);
    _scrubbing = true;
    _scrubAt(e.localPosition.dx, l);
  }

  void _rulerUp() {
    if (!_scrubbing) return;
    _scrubbing = false;
    model.commitPlayhead();
    widget.viewport?.settle(model.playhead.value.floor() / model.state.fps);
  }

  void _areaDown(PointerDownEvent e, TimelineLayout l) {
    _focus.requestFocus();
    if (_pointer != null) return;
    if (e.buttons == kMiddleMouseButton) {
      _pointer = e.pointer;
      _panning = true;
      return;
    }
    final hit = model.hitAt(e.localPosition, l);
    if (e.buttons == kSecondaryMouseButton) {
      if (hit.track != null) {
        widget.onEvent(EditorWidgetEvent(LuminaEditorWidgetEvents.onTrackContextMenu, PluginEditorWidgetEventKind.trackContextMenu,
            {'track': hit.track!.id, 'frame': hit.frame.floor()}));
      }
      return;
    }
    if (e.buttons != kPrimaryMouseButton) return;
    _pointer = e.pointer;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    model.select(hit, extend: shift);
    if (!(shift && hit.kind == TimelineHitKind.key)) model.beginDrag(hit, e.localPosition);
  }

  void _areaMove(PointerMoveEvent e, TimelineLayout l) {
    if (e.pointer != _pointer) return;
    if (_panning) {
      model.pan(e.delta.dx);
      return;
    }
    model.updateDrag(e.localPosition, l);
  }

  void _areaUp(PointerEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    if (_panning) {
      _panning = false;
      model.commitView();
      return;
    }
    model.endDrag();
  }

  void _wheel(PointerSignalEvent e) {
    if (e is! PointerScrollEvent) return;
    final ctrl = HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed;
    if (ctrl) {
      model.zoomAround(e.localPosition.dx, e.scrollDelta.dy < 0 ? 1.2 : 1 / 1.2);
    } else {
      model.pan(-(e.scrollDelta.dy != 0 ? e.scrollDelta.dy : e.scrollDelta.dx));
    }
    model.commitView();
  }

  void _doubleTap(TapDownDetails d, TimelineLayout l) {
    final hit = model.hitAt(d.localPosition, l);
    if (hit.kind == TimelineHitKind.clip || hit.kind == TimelineHitKind.clipStart || hit.kind == TimelineHitKind.clipEnd) {
      final c = model.clip(hit.id!);
      if (c != null && c.editableText && hit.track?.locked != true) {
        setState(() {
          _editingClip = c.id;
          _clipText.text = c.text ?? '';
        });
      }
      return;
    }
    final track = hit.track;
    if (hit.kind == TimelineHitKind.none && track != null && TimelineLayout.hasKeys(track)) model.addKey(track, hit.frame);
  }

  void _endClipEdit({required bool commit}) {
    final id = _editingClip;
    if (id == null) return;
    setState(() => _editingClip = null);
    if (commit) model.commitClipText(id, _clipText.text);
    _focus.requestFocus();
  }

  // --- Build -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null) return EditorWidgetStateError(message: 'Timeline ${widget.name}: $error');
    final l = model.layout();
    final n = widget.name;
    return Focus(
      focusNode: _focus,
      onKeyEvent: _onKey,
      child: Container(
        key: ValueKey('editor_timeline_$n'),
        color: EditorColors.sidebar,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TimelineTransportBar(name: n, model: model, onTogglePlay: () {
            _focus.requestFocus();
            togglePlay();
          }),
          Expanded(
            child: Stack(children: [
              Positioned.fill(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  SizedBox(
                    height: TimelineLayout.rulerHeight,
                    child: Row(children: [
                      Container(
                        width: TimelineLayout.headerWidth,
                        decoration: const BoxDecoration(
                          color: EditorColors.cardHeader,
                          border: Border(bottom: BorderSide(color: EditorColors.border), right: BorderSide(color: EditorColors.border)),
                        ),
                      ),
                      Expanded(
                        child: Listener(
                          key: ValueKey('editor_timeline_${n}_ruler'),
                          behavior: HitTestBehavior.opaque,
                          onPointerDown: (e) => _rulerDown(e, l),
                          onPointerMove: (e) {
                            if (_scrubbing) _scrubAt(e.localPosition.dx, l);
                          },
                          onPointerUp: (_) => _rulerUp(),
                          onPointerCancel: (_) => _rulerUp(),
                          onPointerSignal: _wheel,
                          child: CustomPaint(
                            painter: TimelineRulerPainter(
                              zoom: l.zoom,
                              scroll: l.scroll,
                              fps: model.state.fps,
                              length: model.frameCount,
                              rangeStart: model.rangeStart,
                              rangeEnd: model.rangeEnd,
                            ),
                            size: Size.infinite,
                          ),
                        ),
                      ),
                    ]),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        TimelineTrackHeaders(name: n, layout: l),
                        Expanded(child: _area(l)),
                      ]),
                    ),
                  ),
                ]),
              ),
              Positioned(
                left: TimelineLayout.headerWidth,
                top: 0,
                right: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      key: ValueKey('editor_timeline_${n}_playhead'),
                      painter: TimelinePlayheadPainter(
                          playhead: model.playhead, zoom: l.zoom, scroll: l.scroll, rulerHeight: TimelineLayout.rulerHeight),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _area(TimelineLayout l) {
    final editing = _editingClip == null ? null : model.clip(_editingClip!);
    final editRow = editing == null ? null : l.rowOf(editing.track);
    return SizedBox(
      height: math.max(l.contentHeight, 24),
      child: GestureDetector(
        onDoubleTapDown: (d) => _doubleTap(d, l),
        onDoubleTap: () {},
        child: Listener(
          key: ValueKey('editor_timeline_${widget.name}_tracks'),
          behavior: HitTestBehavior.opaque,
          onPointerDown: (e) => _areaDown(e, l),
          onPointerMove: (e) => _areaMove(e, l),
          onPointerUp: _areaUp,
          onPointerCancel: _areaUp,
          onPointerSignal: _wheel,
          child: Stack(children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: TimelineTracksPainter(
                    layout: l,
                    clips: model.clips,
                    keys: model.keys,
                    selectedClips: {...model.selectedClips},
                    selectedKeys: {...model.selectedKeys},
                    fps: model.state.fps,
                    length: model.frameCount,
                    box: model.box,
                    editingClip: _editingClip,
                  ),
                ),
              ),
            ),
            if (editing != null && editRow != null)
              Positioned(
                left: math.max(0, l.xOf(editing.start)),
                top: editRow.top + 1,
                width: math.max(80, l.xOf(editing.end) - math.max(0, l.xOf(editing.start))),
                height: editRow.height - 2,
                child: Focus(
                  onKeyEvent: (node, e) {
                    if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.escape) {
                      _endClipEdit(commit: false);
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: TextField(
                    key: ValueKey('editor_timeline_${widget.name}_clip_text_${editing.id}'),
                    controller: _clipText,
                    autofocus: true,
                    style: const TextStyle(fontSize: 10),
                    onSubmitted: (_) => _endClipEdit(commit: true),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

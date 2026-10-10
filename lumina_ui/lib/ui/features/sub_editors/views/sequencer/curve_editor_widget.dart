import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/sequencer_evaluator.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/sequencer_view_model.dart';
import 'package:lumina_ui/ui/core/widgets/editor_context_menu.dart';

part 'curve_editor_widget/curve_painter.dart';

/// The Curves tab: every keyed channel as a coloured curve with draggable
/// keys and bezier tangent handles, box-select, pan/zoom/fit, per-channel
/// visibility and a key context menu.
class SequencerCurveEditorWidget extends StatefulWidget {
  final SequencerViewModel viewModel;
  final CurveView? initialView;

  static const Key canvasKey = ValueKey('sequencer_curve_canvas');

  const SequencerCurveEditorWidget({super.key, required this.viewModel, this.initialView});

  @override
  State<SequencerCurveEditorWidget> createState() => SequencerCurveEditorWidgetState();
}

enum _DragMode { none, key, inHandle, outHandle, box, pan }

class SequencerCurveEditorWidgetState extends State<SequencerCurveEditorWidget> {
  CurveView? _view;
  final Set<String> _hiddenChannels = {};
  final FocusNode _focusNode = FocusNode();

  Size _canvasSize = Size.zero;
  _DragMode _dragMode = _DragMode.none;
  SequencerKeyRef? _dragKey;
  Offset? _dragStartLocal;
  Offset? _boxStart;
  Rect? _boxRect;
  int _activeButtons = 0;
  Offset? _lastPanPointer;
  Axis? _shiftAxis;
  int? _dragStartFrame;
  double? _dragStartValue;

  SequencerViewModel get vm => widget.viewModel;

  CurveView get view => _view ??= widget.initialView ?? CurveView.fit(_allChannels().map((r) => r.channel), lengthFrames: vm.lengthFrames);

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  List<CurveChannelRef> _allChannels() => [
        for (final t in vm.tracks)
          for (final c in t.channels) CurveChannelRef(t, c),
      ];

  List<CurveChannelRef> _visibleChannels() => _allChannels().where((r) => !_hiddenChannels.contains(r.id)).toList();

  bool isChannelVisible(String trackId, String channelName) => !_hiddenChannels.contains('$trackId|$channelName');

  void setChannelVisible(String trackId, String channelName, bool visible) {
    setState(() {
      if (visible) {
        _hiddenChannels.remove('$trackId|$channelName');
      } else {
        _hiddenChannels.add('$trackId|$channelName');
      }
    });
  }

  void fitAll() {
    setState(() {
      _view = CurveView.fit(_visibleChannels().map((r) => r.channel), lengthFrames: vm.lengthFrames);
    });
  }

  /// Zooms both axes by [factor] (< 1 zooms in) around [focusFrame]/[focusValue].
  void zoomBy(double factor, {double? focusFrame, double? focusValue}) {
    final v = view;
    final ff = focusFrame ?? (v.minFrame + v.maxFrame) / 2;
    final fv = focusValue ?? (v.minValue + v.maxValue) / 2;
    final newFrameSpan = (v.frameSpan * factor).clamp(2.0, 100000.0);
    final newValueSpan = (v.valueSpan * factor).clamp(1e-3, 1e9);
    final fRatio = (ff - v.minFrame) / v.frameSpan;
    final vRatio = (fv - v.minValue) / v.valueSpan;
    setState(() {
      _view = CurveView(
        minFrame: ff - newFrameSpan * fRatio,
        maxFrame: ff + newFrameSpan * (1 - fRatio),
        minValue: fv - newValueSpan * vRatio,
        maxValue: fv + newValueSpan * (1 - vRatio),
      );
    });
  }

  void panBy(double dFrames, double dValues) {
    final v = view;
    setState(() {
      _view = v.copyWith(
        minFrame: v.minFrame - dFrames,
        maxFrame: v.maxFrame - dFrames,
        minValue: v.minValue - dValues,
        maxValue: v.maxValue - dValues,
      );
    });
  }

  // ---------------------------------------------------------------------------
  // Hit testing
  // ---------------------------------------------------------------------------

  SequencerKeyRef? _hitKey(Offset local) {
    SequencerKeyRef? best;
    double bestDist = SequencerCurvePainter.hitRadius;
    for (final ref in _visibleChannels()) {
      for (int k = 0; k < ref.channel.keys.length; k++) {
        final p = SequencerCurvePainter.keyScreenPosition(ref.channel.keys[k], view, _canvasSize);
        final d = (p - local).distance;
        if (d <= bestDist) {
          bestDist = d;
          best = (ref.track.id, ref.channel.name, k);
        }
      }
    }
    return best;
  }

  _DragMode _hitHandle(Offset local) {
    final primary = vm.selectedKey;
    if (primary == null) return _DragMode.none;
    final channel = vm.findChannel(primary.$1, primary.$2);
    if (channel == null || primary.$3 >= channel.keys.length) return _DragMode.none;
    if (channel.keys[primary.$3].interpolation != KeyInterpolation.cubic) return _DragMode.none;
    if (_hiddenChannels.contains('${primary.$1}|${primary.$2}')) return _DragMode.none;
    final handles = SequencerCurvePainter.tangentHandlePositions(channel, primary.$3, view, _canvasSize);
    if ((handles.outHandle - local).distance <= SequencerCurvePainter.hitRadius) return _DragMode.outHandle;
    if ((handles.inHandle - local).distance <= SequencerCurvePainter.hitRadius) return _DragMode.inHandle;
    return _DragMode.none;
  }

  // ---------------------------------------------------------------------------
  // Gestures
  // ---------------------------------------------------------------------------

  void _onTapDown(TapDownDetails d) {
    _focusNode.requestFocus();
    final hit = _hitKey(d.localPosition);
    if (hit != null) {
      if (HardwareKeyboard.instance.isControlPressed) {
        final set = Set<SequencerKeyRef>.from(vm.selectedKeys);
        if (!set.remove(hit)) set.add(hit);
        vm.selectKeys(set);
      } else {
        vm.selectKey(hit.$1, hit.$2, hit.$3);
      }
    } else if (_hitHandle(d.localPosition) == _DragMode.none) {
      vm.clearKeySelection();
    }
  }

  void _onPanStart(DragStartDetails d) {
    _focusNode.requestFocus();
    _dragStartLocal = d.localPosition;
    _shiftAxis = null;
    final handle = _hitHandle(d.localPosition);
    if (handle != _DragMode.none) {
      _dragMode = handle;
      _dragKey = vm.selectedKey;
      vm.beginCurveDrag('Drag Tangent', 'curve_tangent_${_dragKey!.$1}_${_dragKey!.$2}_${_dragKey!.$3}');
      return;
    }
    final hit = _hitKey(d.localPosition);
    if (hit != null) {
      if (!vm.isKeySelected(hit.$1, hit.$2, hit.$3)) vm.selectKey(hit.$1, hit.$2, hit.$3);
      _dragMode = _DragMode.key;
      _dragKey = hit;
      final key = vm.findChannel(hit.$1, hit.$2)!.keys[hit.$3];
      _dragStartFrame = key.frame;
      _dragStartValue = key.value;
      vm.beginCurveDrag('Drag Keyframe', 'curve_key_${hit.$1}_${hit.$2}_${hit.$3}');
      return;
    }
    _dragMode = _DragMode.box;
    _boxStart = d.localPosition;
    setState(() => _boxRect = Rect.fromPoints(_boxStart!, _boxStart!));
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final local = d.localPosition;
    switch (_dragMode) {
      case _DragMode.outHandle:
      case _DragMode.inHandle:
        final ref = _dragKey;
        if (ref == null) return;
        final channel = vm.findChannel(ref.$1, ref.$2);
        if (channel == null || ref.$3 >= channel.keys.length) return;
        final key = channel.keys[ref.$3];
        final keyPos = SequencerCurvePainter.keyScreenPosition(key, view, _canvasSize);
        final direction = _dragMode == _DragMode.outHandle ? 1 : -1;
        final slope = SequencerCurvePainter.slopeFromHandle(keyPos, local, direction, view, _canvasSize);
        final broken = vm.isTangentBroken(ref.$1, ref.$2, ref.$3);
        final coalesce = 'curve_tangent_${ref.$1}_${ref.$2}_${ref.$3}';
        if (broken) {
          vm.setKeyTangents(ref.$1, ref.$2, ref.$3,
              inTangent: direction < 0 ? slope : null, outTangent: direction > 0 ? slope : null, coalesceKey: coalesce);
        } else {
          vm.setKeyTangents(ref.$1, ref.$2, ref.$3, inTangent: slope, outTangent: slope, coalesceKey: coalesce);
        }
        break;
      case _DragMode.key:
        final ref = _dragKey;
        final start = _dragStartLocal;
        if (ref == null || start == null) return;
        var delta = local - start;
        if (HardwareKeyboard.instance.isShiftPressed) {
          _shiftAxis ??= delta.dx.abs() >= delta.dy.abs() ? Axis.horizontal : Axis.vertical;
          delta = _shiftAxis == Axis.horizontal ? Offset(delta.dx, 0) : Offset(0, delta.dy);
        } else {
          _shiftAxis = null;
        }
        final dFrames = delta.dx / (_canvasSize.width / view.frameSpan);
        final dValues = -delta.dy / (_canvasSize.height / view.valueSpan);
        vm.updateKey(
          ref.$1,
          ref.$2,
          ref.$3,
          frame: (_dragStartFrame! + dFrames).round(),
          value: _dragStartValue! + dValues,
          coalesceKey: 'curve_key_${ref.$1}_${ref.$2}_${ref.$3}',
        );
        break;
      case _DragMode.box:
        setState(() => _boxRect = Rect.fromPoints(_boxStart!, local));
        break;
      case _DragMode.pan:
      case _DragMode.none:
        break;
    }
  }

  void _onPanEnd() {
    switch (_dragMode) {
      case _DragMode.outHandle:
      case _DragMode.inHandle:
      case _DragMode.key:
        vm.endCurveDrag();
        break;
      case _DragMode.box:
        final box = _boxRect;
        if (box != null) {
          final selected = <SequencerKeyRef>[];
          for (final ref in _visibleChannels()) {
            for (int k = 0; k < ref.channel.keys.length; k++) {
              final p = SequencerCurvePainter.keyScreenPosition(ref.channel.keys[k], view, _canvasSize);
              if (box.inflate(SequencerCurvePainter.keyHalfSize).contains(p)) selected.add((ref.track.id, ref.channel.name, k));
            }
          }
          if (selected.isNotEmpty || box.width > 2 || box.height > 2) vm.selectKeys(selected);
        }
        setState(() => _boxRect = null);
        break;
      case _DragMode.pan:
      case _DragMode.none:
        break;
    }
    _dragMode = _DragMode.none;
    _dragKey = null;
    _dragStartLocal = null;
  }

  void _onPointerDown(PointerDownEvent e) {
    _activeButtons = e.buttons;
    if (e.buttons & kMiddleMouseButton != 0) {
      _lastPanPointer = e.localPosition;
    } else if (e.buttons & kSecondaryMouseButton != 0) {
      // Select the key under the cursor so the context menu acts on it.
      final hit = _hitKey(e.localPosition);
      if (hit != null && !vm.isKeySelected(hit.$1, hit.$2, hit.$3)) {
        vm.selectKey(hit.$1, hit.$2, hit.$3);
      }
    }
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (_activeButtons & kMiddleMouseButton != 0 && _lastPanPointer != null) {
      final delta = e.localPosition - _lastPanPointer!;
      _lastPanPointer = e.localPosition;
      final dFrames = delta.dx / (_canvasSize.width / view.frameSpan);
      final dValues = -delta.dy / (_canvasSize.height / view.valueSpan);
      panBy(dFrames, dValues);
    }
  }

  void _onPointerUp(PointerEvent e) {
    _activeButtons = 0;
    _lastPanPointer = null;
  }

  void _onPointerSignal(PointerSignalEvent e) {
    if (e is PointerScrollEvent) {
      final factor = math.pow(1.0015, e.scrollDelta.dy).toDouble();
      zoomBy(
        factor,
        focusFrame: view.xToFrame(e.localPosition.dx, _canvasSize),
        focusValue: view.yToValue(e.localPosition.dy, _canvasSize),
      );
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.delete || event.logicalKey == LogicalKeyboardKey.backspace) {
      if (vm.selectedKeys.isNotEmpty) {
        vm.deleteSelectedKeys();
        return KeyEventResult.handled;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.keyF) {
      fitAll();
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.keyZ && HardwareKeyboard.instance.isControlPressed) {
      if (HardwareKeyboard.instance.isShiftPressed) {
        vm.redo();
      } else {
        vm.undo();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ---------------------------------------------------------------------------
  // Context menu actions (act on the primary selected key at press time)
  // ---------------------------------------------------------------------------

  void _withPrimary(void Function(SequencerKeyRef ref) action) {
    final ref = vm.selectedKey;
    if (ref == null) return;
    action(ref);
  }

  List<MenuItem> _contextMenuItems() => [
        MenuButton(
          leading: const Icon(LucideIcons.spline, size: 11),
          subMenu: [
            MenuButton(
              onPressed: (_) => _withPrimary((r) => vm.setKeyInterpolation(r.$1, r.$2, r.$3, KeyInterpolation.constant)),
              child: const Text('Constant', style: TextStyle(fontSize: 10)),
            ),
            MenuButton(
              onPressed: (_) => _withPrimary((r) => vm.setKeyInterpolation(r.$1, r.$2, r.$3, KeyInterpolation.linear)),
              child: const Text('Linear', style: TextStyle(fontSize: 10)),
            ),
            MenuButton(
              onPressed: (_) => _withPrimary((r) => vm.setKeyInterpolationCubicAuto(r.$1, r.$2, r.$3)),
              child: const Text('Cubic (Auto)', style: TextStyle(fontSize: 10)),
            ),
            MenuButton(
              onPressed: (_) => _withPrimary((r) => vm.setKeyInterpolationCubicBroken(r.$1, r.$2, r.$3)),
              child: const Text('Cubic (Broken)', style: TextStyle(fontSize: 10)),
            ),
          ],
          child: const Text('Interpolation', style: TextStyle(fontSize: 10)),
        ),
        MenuButton(
          leading: const Icon(LucideIcons.minus, size: 11),
          onPressed: (_) => _withPrimary((r) => vm.flattenTangents(r.$1, r.$2, r.$3)),
          child: const Text('Flatten Tangents', style: TextStyle(fontSize: 10)),
        ),
        MenuButton(
          leading: const Icon(LucideIcons.maximize, size: 11),
          onPressed: (_) => fitAll(),
          child: const Text('Fit All', style: TextStyle(fontSize: 10)),
        ),
        const MenuDivider(),
        MenuButton(
          leading: const Icon(LucideIcons.trash2, size: 11, color: EditorColors.logError),
          onPressed: (_) {
            if (vm.selectedKeys.isNotEmpty) vm.deleteSelectedKeys();
          },
          child: const Text('Delete', style: TextStyle(fontSize: 10, color: EditorColors.logError)),
        ),
      ];

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        return Container(
          color: EditorColors.background,
          child: Column(
            children: [
              _buildHeader(),
              const Divider(height: 1),
              Expanded(
                child: Row(
                  children: [
                    SizedBox(width: 168, child: _buildChannelList()),
                    const VerticalDivider(width: 1),
                    Expanded(child: _buildCanvas()),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    final primary = vm.selectedKey;
    SequencerKey? key;
    if (primary != null) {
      final ch = vm.findChannel(primary.$1, primary.$2);
      if (ch != null && primary.$3 < ch.keys.length) key = ch.keys[primary.$3];
    }
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: EditorColors.cardHeader,
      child: Row(
        children: [
          const Icon(LucideIcons.spline, size: 12, color: Colors.indigo),
          const SizedBox(width: 6),
          const Text('CURVE EDITOR', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.indigo)),
          const SizedBox(width: 12),
          OutlineButton(
            size: ButtonSize.small,
            onPressed: fitAll,
            child: const Text('Fit', style: TextStyle(fontSize: 9)),
          ),
          const SizedBox(width: 4),
          GhostButton(
            size: ButtonSize.small,
            onPressed: () => zoomBy(0.8),
            child: const Icon(LucideIcons.zoomIn, size: 11),
          ),
          GhostButton(
            size: ButtonSize.small,
            onPressed: () => zoomBy(1.25),
            child: const Icon(LucideIcons.zoomOut, size: 11),
          ),
          const SizedBox(width: 12),
          if (key != null && primary != null) ...[
            Text(
              '${primary.$2} · f${key.frame} = ${key.value.toStringAsFixed(3)} · ${key.interpolation.name}'
              '${key.interpolation == KeyInterpolation.cubic ? ' (in ${key.inTangent.toStringAsFixed(2)} / out ${key.outTangent.toStringAsFixed(2)}${vm.isTangentBroken(primary.$1, primary.$2, primary.$3) ? ', broken' : ''})' : ''}',
              style: const TextStyle(fontSize: 9, fontFamily: EditorTypography.monoFamily, color: Colors.amber),
            ),
          ] else
            Text(
              '${vm.selectedKeys.length} selected · scroll: zoom · middle-drag: pan · shift-drag: constrain',
              style: const TextStyle(fontSize: 8.5, color: EditorColors.mutedForeground),
            ),
        ],
      ),
    );
  }

  Widget _buildChannelList() {
    final tracks = vm.tracks;
    return Container(
      color: EditorColors.card,
      child: tracks.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text('No tracks to draw', style: TextStyle(fontSize: 9.5, color: EditorColors.mutedForeground)),
              ),
            )
          : ListView(
              children: [
                for (final track in tracks) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    color: EditorColors.cardHeader,
                    child: Text(
                      '${track.actorName} · ${track.kind.name}',
                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: EditorColors.foreground),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  for (final channel in track.channels)
                    Padding(
                      padding: const EdgeInsets.only(left: 8, right: 4, top: 1, bottom: 1),
                      child: Row(
                        children: [
                          Checkbox(
                            state: isChannelVisible(track.id, channel.name) ? CheckboxState.checked : CheckboxState.unchecked,
                            onChanged: (s) => setChannelVisible(track.id, channel.name, s == CheckboxState.checked),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: SequencerCurvePainter.channelColor(channel.name),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              channel.name,
                              style: TextStyle(
                                fontSize: 9,
                                color: channel.keys.isEmpty ? EditorColors.mutedForeground : EditorColors.foreground,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text('${channel.keys.length}', style: const TextStyle(fontSize: 8, color: EditorColors.mutedForeground)),
                        ],
                      ),
                    ),
                ],
              ],
            ),
    );
  }

  Widget _buildCanvas() {
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _onKey,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
          return EditorContextMenu(
            items: _contextMenuItems(),
            child: Listener(
              onPointerDown: _onPointerDown,
              onPointerMove: _onPointerMove,
              onPointerUp: _onPointerUp,
              onPointerCancel: _onPointerUp,
              onPointerSignal: _onPointerSignal,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                // Report the pointer-down position so handle/key hit tests use
                // where the drag began, not where the touch slop was exceeded.
                dragStartBehavior: DragStartBehavior.down,
                onTapDown: _onTapDown,
                onPanStart: _onPanStart,
                onPanUpdate: _onPanUpdate,
                onPanEnd: (_) => _onPanEnd(),
                onPanCancel: _onPanEnd,
                child: CustomPaint(
                  key: SequencerCurveEditorWidget.canvasKey,
                  painter: SequencerCurvePainter(
                    channels: _visibleChannels(),
                    view: view,
                    selectedKeys: vm.selectedKeys,
                    primaryKey: vm.selectedKey,
                    playheadFrame: vm.playheadPosition,
                    lengthFrames: vm.lengthFrames,
                    boxSelect: _boxRect,
                  ),
                  size: _canvasSize,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

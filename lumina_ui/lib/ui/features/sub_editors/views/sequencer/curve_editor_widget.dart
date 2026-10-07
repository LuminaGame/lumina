import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/sequencer_evaluator.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/sequencer_view_model.dart';
import 'package:lumina_ui/ui/core/widgets/editor_context_menu.dart';

/// The visible window of the curve canvas in data space (frames × values).
class CurveView {
  final double minFrame;
  final double maxFrame;
  final double minValue;
  final double maxValue;

  const CurveView({
    required this.minFrame,
    required this.maxFrame,
    required this.minValue,
    required this.maxValue,
  });

  double get frameSpan => math.max(maxFrame - minFrame, 1e-6);
  double get valueSpan => math.max(maxValue - minValue, 1e-6);

  double frameToX(double frame, Size size) => (frame - minFrame) / frameSpan * size.width;
  double valueToY(double value, Size size) => size.height - (value - minValue) / valueSpan * size.height;
  double xToFrame(double x, Size size) => minFrame + x / math.max(size.width, 1e-6) * frameSpan;
  double yToValue(double y, Size size) => minValue + (size.height - y) / math.max(size.height, 1e-6) * valueSpan;

  CurveView copyWith({double? minFrame, double? maxFrame, double? minValue, double? maxValue}) => CurveView(
        minFrame: minFrame ?? this.minFrame,
        maxFrame: maxFrame ?? this.maxFrame,
        minValue: minValue ?? this.minValue,
        maxValue: maxValue ?? this.maxValue,
      );

  /// Frames every key of [channels] with a 10% margin (or the whole
  /// sequence and a unit value band when nothing is keyed).
  static CurveView fit(Iterable<SequencerChannel> channels, {required int lengthFrames}) {
    double? fMin, fMax, vMin, vMax;
    for (final ch in channels) {
      for (final k in ch.keys) {
        fMin = fMin == null ? k.frame.toDouble() : math.min(fMin, k.frame.toDouble());
        fMax = fMax == null ? k.frame.toDouble() : math.max(fMax, k.frame.toDouble());
        vMin = vMin == null ? k.value : math.min(vMin, k.value);
        vMax = vMax == null ? k.value : math.max(vMax, k.value);
      }
    }
    if (fMin == null || fMax == null || vMin == null || vMax == null) {
      return CurveView(minFrame: 0, maxFrame: math.max(lengthFrames, 1).toDouble(), minValue: -1, maxValue: 1);
    }
    if (fMax - fMin < 1) fMax = fMin + 1;
    if (vMax - vMin < 1e-6) {
      vMin -= 1;
      vMax += 1;
    }
    final fPad = (fMax - fMin) * 0.1;
    final vPad = (vMax - vMin) * 0.15;
    return CurveView(minFrame: fMin - fPad, maxFrame: fMax + fPad, minValue: vMin - vPad, maxValue: vMax + vPad);
  }

  @override
  String toString() => 'CurveView(f $minFrame..$maxFrame, v $minValue..$maxValue)';
}

/// A channel shown on the canvas together with the track that owns it.
class CurveChannelRef {
  final SequencerTrack track;
  final SequencerChannel channel;
  const CurveChannelRef(this.track, this.channel);
  String get id => '${track.id}|${channel.name}';
}

class SequencerCurvePainter extends CustomPainter {
  final List<CurveChannelRef> channels;
  final CurveView view;
  final Set<SequencerKeyRef> selectedKeys;
  final SequencerKeyRef? primaryKey;
  final double playheadFrame;
  final Rect? boxSelect;
  final int lengthFrames;

  SequencerCurvePainter({
    required this.channels,
    required this.view,
    required this.selectedKeys,
    required this.primaryKey,
    required this.playheadFrame,
    required this.lengthFrames,
    this.boxSelect,
  });

  static const double handleLengthPx = 48.0;
  static const double keyHalfSize = 4.5;
  static const double hitRadius = 8.0;

  /// X → red, Y → green, Z → blue; other channels cycle a distinct palette.
  static Color channelColor(String name) {
    final upper = name.toUpperCase();
    if (upper.endsWith('.X')) return EditorColors.axisX;
    if (upper.endsWith('.Y')) return EditorColors.axisY;
    if (upper.endsWith('.Z')) return EditorColors.axisZ;
    if (upper == 'VISIBILITY') return EditorColors.logSuccess;
    const palette = [Colors.cyan, Colors.purple, Colors.orange, Colors.pink, Colors.teal, Colors.yellow];
    return palette[name.hashCode.abs() % palette.length];
  }

  static Offset keyScreenPosition(SequencerKey key, CurveView view, Size size) =>
      Offset(view.frameToX(key.frame.toDouble(), size), view.valueToY(key.value, size));

  /// Polyline sampling of the channel's curve in screen space: every segment
  /// is sampled [samplesPerSegment] times so cubic bends and constant steps
  /// draw faithfully; the extrapolated flat ends span the visible window.
  static List<Offset> buildChannelPoints(SequencerChannel channel, CurveView view, Size size, {int samplesPerSegment = 24}) {
    final keys = List<SequencerKey>.from(channel.keys)..sort((a, b) => a.frame.compareTo(b.frame));
    if (keys.isEmpty) return const [];
    final points = <Offset>[];
    points.add(Offset(view.frameToX(math.min(view.minFrame, keys.first.frame.toDouble()), size), view.valueToY(keys.first.value, size)));
    for (int i = 0; i < keys.length - 1; i++) {
      final a = keys[i];
      final b = keys[i + 1];
      final span = (b.frame - a.frame).toDouble();
      for (int s = 0; s <= samplesPerSegment; s++) {
        final t = s / samplesPerSegment;
        final frame = a.frame + span * t;
        double value;
        if (a.interpolation == KeyInterpolation.constant) {
          value = t < 1.0 ? a.value : b.value;
          if (s == samplesPerSegment) {
            // Draw the vertical step explicitly.
            points.add(Offset(view.frameToX(frame, size), view.valueToY(a.value, size)));
          }
        } else {
          value = SequencerEvaluator.evaluateSegment(a, b, frame);
        }
        points.add(Offset(view.frameToX(frame, size), view.valueToY(value, size)));
      }
    }
    points.add(Offset(view.frameToX(math.max(view.maxFrame, keys.last.frame.toDouble()), size), view.valueToY(keys.last.value, size)));
    return points;
  }

  /// Screen positions of a key's in/out tangent handles. The handle points
  /// along the tangent direction with a fixed on-screen length, shortened so
  /// its frame component never crosses the neighbouring key.
  static ({Offset inHandle, Offset outHandle}) tangentHandlePositions(SequencerChannel channel, int keyIndex, CurveView view, Size size) {
    final key = channel.keys[keyIndex];
    final pos = keyScreenPosition(key, view, size);
    final pxPerFrame = size.width / view.frameSpan;
    final pxPerValue = size.height / view.valueSpan;

    Offset handle(double slope, int direction) {
      final dir = Offset(pxPerFrame, -slope * pxPerValue);
      final len = dir.distance;
      if (len < 1e-9) return pos + Offset(handleLengthPx * direction, 0);
      var scaled = dir / len * handleLengthPx;
      // Clamp the frame component to the gap towards the neighbour key.
      final neighbourIndex = keyIndex + direction;
      if (neighbourIndex >= 0 && neighbourIndex < channel.keys.length) {
        final gapPx = ((channel.keys[neighbourIndex].frame - key.frame).abs()) * pxPerFrame;
        if (gapPx > 0 && scaled.dx.abs() > gapPx) {
          scaled = scaled * (gapPx / scaled.dx.abs());
        }
      }
      return pos + scaled * direction.toDouble();
    }

    return (inHandle: handle(key.inTangent, -1), outHandle: handle(key.outTangent, 1));
  }

  /// Converts a dragged handle position back into a tangent slope
  /// (value units per frame); [direction] is +1 for the out handle, -1 for in.
  static double slopeFromHandle(Offset keyPos, Offset handlePos, int direction, CurveView view, Size size) {
    final pxPerFrame = size.width / view.frameSpan;
    final pxPerValue = size.height / view.valueSpan;
    var dx = handlePos.dx - keyPos.dx;
    dx = direction > 0 ? math.max(dx, 1.0) : math.min(dx, -1.0);
    final dy = handlePos.dy - keyPos.dy;
    final frames = dx / pxPerFrame;
    final values = -dy / pxPerValue;
    return values / frames;
  }

  static double niceStep(double span, int targetDivisions) {
    final raw = span / math.max(targetDivisions, 1);
    if (raw <= 0 || raw.isNaN || raw.isInfinite) return 1;
    final mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    final norm = raw / mag;
    double nice;
    if (norm < 1.5) {
      nice = 1;
    } else if (norm < 3.5) {
      nice = 2;
    } else if (norm < 7.5) {
      nice = 5;
    } else {
      nice = 10;
    }
    return nice * mag;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = EditorColors.background);

    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..strokeWidth = 1;
    final zeroPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..strokeWidth = 1;

    // Vertical frame grid
    final fStep = niceStep(view.frameSpan, (size.width / 90).clamp(2, 16).round());
    for (double f = (view.minFrame / fStep).floor() * fStep; f <= view.maxFrame; f += fStep) {
      final x = view.frameToX(f, size);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), f == 0 ? zeroPaint : gridPaint);
      textPainter.text = TextSpan(text: f.toStringAsFixed(fStep < 1 ? 1 : 0), style: const TextStyle(fontSize: 8, color: EditorColors.mutedForeground));
      textPainter.layout();
      textPainter.paint(canvas, Offset(x + 2, size.height - textPainter.height - 2));
    }
    // Horizontal value grid
    final vStep = niceStep(view.valueSpan, (size.height / 50).clamp(2, 12).round());
    for (double v = (view.minValue / vStep).floor() * vStep; v <= view.maxValue; v += vStep) {
      final y = view.valueToY(v, size);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), v == 0 ? zeroPaint : gridPaint);
      textPainter.text = TextSpan(text: _fmt(v, vStep), style: const TextStyle(fontSize: 8, color: EditorColors.mutedForeground));
      textPainter.layout();
      textPainter.paint(canvas, Offset(3, y - textPainter.height - 1));
    }

    // Sequence bounds shading
    final boundsPaint = Paint()..color = Colors.black.withValues(alpha: 0.28);
    final x0 = view.frameToX(0, size);
    final xEnd = view.frameToX(lengthFrames.toDouble(), size);
    if (x0 > 0) canvas.drawRect(Rect.fromLTRB(0, 0, x0.clamp(0, size.width), size.height), boundsPaint);
    if (xEnd < size.width) canvas.drawRect(Rect.fromLTRB(xEnd.clamp(0, size.width), 0, size.width, size.height), boundsPaint);

    // Curves
    for (final ref in channels) {
      final color = channelColor(ref.channel.name);
      final pts = buildChannelPoints(ref.channel, view, size);
      if (pts.length >= 2) {
        final path = Path()..moveTo(pts.first.dx, pts.first.dy);
        for (int i = 1; i < pts.length; i++) {
          path.lineTo(pts[i].dx, pts[i].dy);
        }
        canvas.drawPath(
          path,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6,
        );
      }
      // Keys
      for (int k = 0; k < ref.channel.keys.length; k++) {
        final key = ref.channel.keys[k];
        final p = keyScreenPosition(key, view, size);
        final selected = selectedKeys.contains((ref.track.id, ref.channel.name, k));
        final rect = Rect.fromCenter(center: p, width: keyHalfSize * 2, height: keyHalfSize * 2);
        canvas.drawRect(rect, Paint()..color = selected ? Colors.amber : color);
        canvas.drawRect(
          rect,
          Paint()
            ..color = Colors.black.withValues(alpha: 0.7)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      }
    }

    // Tangent handles of the primary key
    final primary = primaryKey;
    if (primary != null) {
      for (final ref in channels) {
        if (ref.track.id != primary.$1 || ref.channel.name != primary.$2) continue;
        if (primary.$3 < 0 || primary.$3 >= ref.channel.keys.length) continue;
        final key = ref.channel.keys[primary.$3];
        if (key.interpolation != KeyInterpolation.cubic) continue;
        final p = keyScreenPosition(key, view, size);
        final handles = tangentHandlePositions(ref.channel, primary.$3, view, size);
        final stem = Paint()
          ..color = Colors.amber.withValues(alpha: 0.85)
          ..strokeWidth = 1.2;
        final dot = Paint()..color = Colors.amber;
        canvas.drawLine(p, handles.inHandle, stem);
        canvas.drawLine(p, handles.outHandle, stem);
        canvas.drawCircle(handles.inHandle, 4, dot);
        canvas.drawCircle(handles.outHandle, 4, dot);
      }
    }

    // Playhead
    final px = view.frameToX(playheadFrame, size);
    if (px >= 0 && px <= size.width) {
      canvas.drawLine(
        Offset(px, 0),
        Offset(px, size.height),
        Paint()
          ..color = Colors.red
          ..strokeWidth = 1.5,
      );
    }

    // Box select
    final box = boxSelect;
    if (box != null) {
      canvas.drawRect(box, Paint()..color = Colors.indigo.withValues(alpha: 0.18));
      canvas.drawRect(
        box,
        Paint()
          ..color = Colors.indigo
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  String _fmt(double v, double step) {
    if (step >= 1) return v.toStringAsFixed(0);
    if (step >= 0.1) return v.toStringAsFixed(1);
    if (step >= 0.01) return v.toStringAsFixed(2);
    return v.toStringAsFixed(3);
  }

  @override
  bool shouldRepaint(covariant SequencerCurvePainter oldDelegate) => true;
}

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

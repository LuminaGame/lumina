// design-token-exempt: the curve canvas follows curve-editor conventions (dark grid, one colour per track, white keys), not the editor chrome palette.
import 'dart:math' as math;

import 'package:lumina/lumina.dart' hide BoxShape;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../../../../core/theme/editor_theme.dart';
import '../../../view_models/blueprint_editor_view_model.dart';

/// The Timeline tab: the
/// node's length / loop / auto-play, its float / vector / colour tracks
/// (add, rename, delete) and a curve canvas per track where keys are added
/// (click), moved (drag), deleted and given an interpolation. Everything
/// edits the Timeline node's literals through the view model, so the graph
/// node's track outputs and the `.lmas` follow at once.
class BlueprintTimelineEditor extends StatefulWidget {
  final BlueprintEditorViewModel viewModel;
  final String nodeId;

  const BlueprintTimelineEditor({super.key, required this.viewModel, required this.nodeId});

  @override
  State<BlueprintTimelineEditor> createState() => BlueprintTimelineEditorState();
}

class BlueprintTimelineEditorState extends State<BlueprintTimelineEditor> {
  /// The selected key: track name and key index.
  ({String track, int index})? _selected;
  String? _renaming;
  final TextEditingController _rename = TextEditingController();
  final TextEditingController _length = TextEditingController();

  BlueprintEditorViewModel get vm => widget.viewModel;
  String get nodeId => widget.nodeId;
  ({String track, int index})? get selectedKey => _selected;

  @override
  void dispose() {
    _rename.dispose();
    _length.dispose();
    super.dispose();
  }

  static const List<Color> trackColors = [Color(0xFF4FC3F7), Color(0xFFFFB74D), Color(0xFF81C784), Color(0xFFBA68C8), Color(0xFFE57373)];

  /// Replaces one key of [track]; the view model sorts and clamps.
  void setKey(String track, int index, LuminaTimelineKey key) {
    final t = vm.timelineTracks(nodeId).where((t) => t.name == track).firstOrNull;
    if (t == null || index < 0 || index >= t.keys.length) return;
    final keys = [...t.keys]..[index] = key;
    vm.setTimelineKeys(nodeId, track, keys);
  }

  /// Adds a key at ([time], [value]) to [track] and selects it.
  void addKey(String track, double time, double value) {
    final t = vm.timelineTracks(nodeId).where((t) => t.name == track).firstOrNull;
    if (t == null) return;
    final width = switch (t.type) { 'vector' => 3, 'color' => 4, _ => 1 };
    final key = LuminaTimelineKey(time, List<double>.filled(width, value), LuminaTimelineInterp.linear);
    vm.setTimelineKeys(nodeId, track, [...t.keys, key]);
    final after = vm.timelineTracks(nodeId).firstWhere((x) => x.name == track).keys;
    setState(() => _selected = (track: track, index: after.indexWhere((k) => k.time == time.clamp(0.0, vm.timelineLength(nodeId)))));
  }

  void deleteKey(String track, int index) {
    final t = vm.timelineTracks(nodeId).where((t) => t.name == track).firstOrNull;
    if (t == null || index < 0 || index >= t.keys.length) return;
    vm.setTimelineKeys(nodeId, track, [...t.keys]..removeAt(index));
    setState(() => _selected = null);
  }

  @override
  Widget build(BuildContext context) {
    final node = vm.timelineNode(nodeId);
    if (node == null) {
      return const Center(child: Text('This Timeline node is gone.', style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground)));
    }
    final tracks = vm.timelineTracks(nodeId);
    final length = vm.timelineLength(nodeId);
    final lengthText = length == length.roundToDouble() ? length.toStringAsFixed(1) : '$length';
    if (_length.text != lengthText && !_lengthFocus.hasFocus) _length.text = lengthText;
    return Container(
      key: const ValueKey('bp_timeline_editor'),
      color: EditorColors.graphCanvas,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _toolbar(length),
          const Divider(height: 1),
          Expanded(
            child: tracks.isEmpty
                ? const Center(
                    child: Text('No tracks. Add a Float, Vector or Color track above.',
                        style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground)))
                : ListView(
                    padding: const EdgeInsets.all(8),
                    children: [for (var i = 0; i < tracks.length; i++) _trackCard(tracks[i], trackColors[i % trackColors.length], length)],
                  ),
          ),
        ],
      ),
    );
  }

  final FocusNode _lengthFocus = FocusNode();

  Widget _toolbar(double length) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      color: EditorColors.card,
      child: Row(
        children: [
          const Icon(LucideIcons.chartLine, size: 12, color: EditorColors.primary),
          const SizedBox(width: 6),
          Text('TIMELINE  ·  ${vm.timelineNode(nodeId)?.title ?? ''}',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.primary)),
          const SizedBox(width: 16),
          const Text('Length', style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
          const SizedBox(width: 4),
          SizedBox(
            width: 60,
            height: 22,
            child: TextField(
              key: const ValueKey('timeline_length'),
              controller: _length,
              focusNode: _lengthFocus,
              style: const TextStyle(fontSize: 9, fontFamily: EditorTypography.monoFamily),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              onSubmitted: (v) {
                final parsed = double.tryParse(v);
                if (parsed != null) vm.setTimelineLength(nodeId, parsed);
              },
            ),
          ),
          const SizedBox(width: 4),
          const Text('s', style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
          const SizedBox(width: 14),
          Checkbox(
            key: const ValueKey('timeline_loop'),
            state: vm.timelineLoop(nodeId) ? CheckboxState.checked : CheckboxState.unchecked,
            onChanged: (s) => vm.setTimelineLoop(nodeId, s == CheckboxState.checked),
            trailing: const Text('Loop', style: TextStyle(fontSize: 9)),
          ),
          const SizedBox(width: 10),
          Checkbox(
            key: const ValueKey('timeline_autoplay'),
            state: vm.timelineAutoPlay(nodeId) ? CheckboxState.checked : CheckboxState.unchecked,
            onChanged: (s) => vm.setTimelineAutoPlay(nodeId, s == CheckboxState.checked),
            trailing: const Text('Auto Play', style: TextStyle(fontSize: 9)),
          ),
          const Spacer(),
          for (final (type, label, key) in const [('float', 'Float Track', 'timeline_add_float'), ('vector', 'Vector Track', 'timeline_add_vector'), ('color', 'Color Track', 'timeline_add_color')])
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: OutlineButton(
                key: ValueKey(key),
                size: ButtonSize.small,
                onPressed: () => vm.addTimelineTrack(nodeId, 'New${type[0].toUpperCase()}${type.substring(1)}Track', type: type),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(LucideIcons.plus, size: 10),
                  const SizedBox(width: 4),
                  Text(label, style: const TextStyle(fontSize: 9)),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _trackCard(LuminaTimelineTrack track, Color color, double length) {
    final selected = _selected?.track == track.name ? _selected!.index : null;
    final key = selected != null && selected < track.keys.length ? track.keys[selected] : null;
    return Card(
      key: ValueKey('timeline_track_${track.name}'),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              if (_renaming == track.name)
                SizedBox(
                  width: 140,
                  height: 22,
                  child: TextField(
                    key: const ValueKey('timeline_track_rename'),
                    controller: _rename,
                    autofocus: true,
                    style: const TextStyle(fontSize: 10),
                    onSubmitted: (v) {
                      vm.renameTimelineTrack(nodeId, track.name, v);
                      setState(() => _renaming = null);
                    },
                  ),
                )
              else
                GestureDetector(
                  onDoubleTap: () => setState(() {
                    _renaming = track.name;
                    _rename.text = track.name;
                  }),
                  child: Text(track.name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              const SizedBox(width: 8),
              OutlineBadge(child: Text(track.type, style: const TextStyle(fontSize: 8))),
              const SizedBox(width: 8),
              Text('${track.keys.length} key${track.keys.length == 1 ? '' : 's'}', style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
              const Spacer(),
              GhostButton(
                key: ValueKey('timeline_track_rename_${track.name}'),
                size: ButtonSize.xSmall,
                density: ButtonDensity.icon,
                onPressed: () => setState(() {
                  _renaming = track.name;
                  _rename.text = track.name;
                }),
                child: const Icon(LucideIcons.pencil, size: 11),
              ),
              GhostButton(
                key: ValueKey('timeline_track_delete_${track.name}'),
                size: ButtonSize.xSmall,
                density: ButtonDensity.icon,
                onPressed: () => vm.removeTimelineTrack(nodeId, track.name),
                child: const Icon(LucideIcons.trash2, size: 11),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 150,
            child: LayoutBuilder(
              builder: (context, constraints) => _CurveCanvas(
                key: ValueKey('timeline_curve_${track.name}'),
                track: track,
                length: length,
                color: color,
                size: constraints.biggest,
                selected: selected,
                onSelect: (i) => setState(() => _selected = i == null ? null : (track: track.name, index: i)),
                onAdd: (t, v) => addKey(track.name, t, v),
                onMove: (i, t, v) {
                  final k = track.keys[i];
                  final value = [...k.value];
                  value[0] = v;
                  setKey(track.name, i, LuminaTimelineKey(t, value, k.interp));
                },
                onDelete: (i) => deleteKey(track.name, i),
              ),
            ),
          ),
          if (key != null) ...[
            const SizedBox(height: 6),
            _keyFields(track, selected!, key),
          ],
          const SizedBox(height: 2),
          const Text('Click the curve to add a key, drag a key to move it, right-click a key to delete it.',
              style: TextStyle(fontSize: 8, color: EditorColors.mutedForeground)),
        ],
      ),
    );
  }

  /// The selected key's time, value components and interpolation.
  Widget _keyFields(LuminaTimelineTrack track, int index, LuminaTimelineKey key) {
    final labels = switch (track.type) { 'vector' => const ['X', 'Y', 'Z'], 'color' => const ['R', 'G', 'B', 'A'], _ => const ['Value'] };
    Widget field(String label, String fieldKey, double value, ValueChanged<double> commit) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label, style: const TextStyle(fontSize: 8, color: EditorColors.mutedForeground)),
            const SizedBox(width: 3),
            SizedBox(
              width: 58,
              height: 20,
              child: TextField(
                key: ValueKey(fieldKey),
                initialValue: value == value.roundToDouble() ? value.toStringAsFixed(1) : value.toStringAsFixed(3),
                style: const TextStyle(fontSize: 9, fontFamily: EditorTypography.monoFamily),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                onSubmitted: (v) {
                  final parsed = double.tryParse(v);
                  if (parsed != null) commit(parsed);
                },
              ),
            ),
          ]),
        );
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        field('Time', 'timeline_key_time', key.time, (t) => setKey(track.name, index, LuminaTimelineKey(t, key.value, key.interp))),
        for (var i = 0; i < labels.length && i < key.value.length; i++)
          field(labels[i], 'timeline_key_value_$i', key.value[i], (v) {
            final value = [...key.value];
            value[i] = v;
            setKey(track.name, index, LuminaTimelineKey(key.time, value, key.interp));
          }),
        const Text('Interp', style: TextStyle(fontSize: 8, color: EditorColors.mutedForeground)),
        const SizedBox(width: 4),
        SizedBox(
          width: 110,
          height: 22,
          child: Select<LuminaTimelineInterp>(
            key: const ValueKey('timeline_key_interp'),
            value: key.interp,
            itemBuilder: (context, item) => Text(item.name, style: const TextStyle(fontSize: 9)),
            onChanged: (v) {
              if (v != null) setKey(track.name, index, LuminaTimelineKey(key.time, key.value, v));
            },
            popup: SelectPopup(
              items: SelectItemList(
                children: [
                  for (final i in LuminaTimelineInterp.values)
                    SelectItemButton(key: ValueKey('timeline_interp_${i.name}'), value: i, child: Text(i.name, style: const TextStyle(fontSize: 9))),
                ],
              ),
            ).call,
          ),
        ),
        const SizedBox(width: 8),
        GhostButton(
          key: const ValueKey('timeline_key_delete'),
          size: ButtonSize.xSmall,
          onPressed: () => deleteKey(track.name, index),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(LucideIcons.trash2, size: 10), SizedBox(width: 3), Text('Delete key', style: TextStyle(fontSize: 9))]),
        ),
      ],
    );
  }
}

/// One track's curve: time along X over the timeline length, the first
/// value component along Y (auto-ranged), the curve sampled through
/// lumina's evaluator, keys as dots.
class _CurveCanvas extends StatefulWidget {
  final LuminaTimelineTrack track;
  final double length;
  final Color color;
  final Size size;
  final int? selected;
  final ValueChanged<int?> onSelect;
  final void Function(double time, double value) onAdd;
  final void Function(int index, double time, double value) onMove;
  final ValueChanged<int> onDelete;

  const _CurveCanvas({
    super.key,
    required this.track,
    required this.length,
    required this.color,
    required this.size,
    required this.selected,
    required this.onSelect,
    required this.onAdd,
    required this.onMove,
    required this.onDelete,
  });

  @override
  State<_CurveCanvas> createState() => _CurveCanvasState();
}

class _CurveCanvasState extends State<_CurveCanvas> {
  int? _dragging;

  static const double padX = 28;
  static const double padY = 12;

  (double min, double max) get _range {
    var lo = 0.0;
    var hi = 1.0;
    for (final k in widget.track.keys) {
      final v = k.value.isEmpty ? 0.0 : k.value[0];
      lo = math.min(lo, v);
      hi = math.max(hi, v);
    }
    if (hi - lo < 1e-6) hi = lo + 1.0;
    final margin = (hi - lo) * 0.1;
    return (lo - margin, hi + margin);
  }

  Offset toScreen(double t, double v) {
    final (lo, hi) = _range;
    final w = widget.size.width - padX * 2;
    final h = widget.size.height - padY * 2;
    return Offset(padX + (t / widget.length) * w, padY + h - ((v - lo) / (hi - lo)) * h);
  }

  (double, double) toCurve(Offset p) {
    final (lo, hi) = _range;
    final w = widget.size.width - padX * 2;
    final h = widget.size.height - padY * 2;
    final t = ((p.dx - padX) / w * widget.length).clamp(0.0, widget.length).toDouble();
    final v = lo + (padY + h - p.dy) / h * (hi - lo);
    return (t, v);
  }

  int? keyAt(Offset p) {
    for (var i = 0; i < widget.track.keys.length; i++) {
      final k = widget.track.keys[i];
      if ((toScreen(k.time, k.value.isEmpty ? 0 : k.value[0]) - p).distance <= 8) return i;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (d) {
        final hit = keyAt(d.localPosition);
        if (hit != null) {
          widget.onSelect(hit);
          return;
        }
        final (t, v) = toCurve(d.localPosition);
        widget.onAdd(t, v);
      },
      onSecondaryTapUp: (d) {
        final hit = keyAt(d.localPosition);
        if (hit != null) widget.onDelete(hit);
      },
      onPanStart: (d) {
        _dragging = keyAt(d.localPosition);
        if (_dragging != null) widget.onSelect(_dragging);
      },
      onPanUpdate: (d) {
        final i = _dragging;
        if (i == null) return;
        final (t, v) = toCurve(d.localPosition);
        widget.onMove(i, t, v);
      },
      onPanEnd: (_) => _dragging = null,
      child: CustomPaint(
        size: widget.size,
        painter: _CurvePainter(this),
      ),
    );
  }
}

class _CurvePainter extends CustomPainter {
  final _CurveCanvasState state;
  _CurvePainter(this.state);

  @override
  void paint(Canvas canvas, Size size) {
    final w = state.widget;
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF1B1D21));
    final grid = Paint()
      ..color = const Color(0xFF2B2E33)
      ..strokeWidth = 1;
    for (var i = 0; i <= 10; i++) {
      final x = _CurveCanvasState.padX + (size.width - _CurveCanvasState.padX * 2) * i / 10;
      canvas.drawLine(Offset(x, _CurveCanvasState.padY), Offset(x, size.height - _CurveCanvasState.padY), grid);
    }
    final (lo, hi) = state._range;
    for (var i = 0; i <= 4; i++) {
      final v = lo + (hi - lo) * i / 4;
      final y = state.toScreen(0, v).dy;
      canvas.drawLine(Offset(_CurveCanvasState.padX, y), Offset(size.width - _CurveCanvasState.padX, y), grid);
      final tp = TextPainter(
        text: TextSpan(text: v.toStringAsFixed(v.abs() >= 10 ? 0 : 1), style: const TextStyle(fontSize: 8, color: Color(0xFF8A8F98))),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(2, y - tp.height / 2));
    }
    // Time labels.
    for (final t in [0.0, w.length / 2, w.length]) {
      final tp = TextPainter(
        text: TextSpan(text: '${t.toStringAsFixed(2)}s', style: const TextStyle(fontSize: 8, color: Color(0xFF8A8F98))),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(state.toScreen(t, lo).dx - tp.width / 2, size.height - 10));
    }
    if (w.track.keys.isEmpty) return;
    // The curve, sampled as lumina evaluates it.
    final path = Path();
    const samples = 120;
    for (var i = 0; i <= samples; i++) {
      final t = w.length * i / samples;
      final v = w.track.evaluateComponents(t);
      final p = state.toScreen(t, v.isEmpty ? 0 : v[0]);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = w.color
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke);
    for (var i = 0; i < w.track.keys.length; i++) {
      final k = w.track.keys[i];
      final p = state.toScreen(k.time, k.value.isEmpty ? 0 : k.value[0]);
      final selected = w.selected == i;
      canvas.drawCircle(p, selected ? 6 : 4.5, Paint()..color = selected ? const Color(0xFFFFFFFF) : w.color);
      canvas.drawCircle(
          p,
          selected ? 6 : 4.5,
          Paint()
            ..color = const Color(0xFF000000)
            ..style = PaintingStyle.stroke);
      if (k.interp != LuminaTimelineInterp.linear) {
        final tp = TextPainter(
          text: TextSpan(text: k.interp.name[0].toUpperCase(), style: const TextStyle(fontSize: 8, color: Color(0xFFDDDDDD))),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, p + const Offset(7, -12));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CurvePainter oldDelegate) => true;
}

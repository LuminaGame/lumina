import 'package:lumina/lumina.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import '../../view_models/sequencer_view_model.dart';

/// The Sequencer's Key panel (docked on the right): the selected key's
/// frame (editable, moves the selected keys), time, track and channel(s),
/// the values at that frame (all nine Location / Rotation / Scale values for
/// a transform track, keyed ones marked; editing one writes or updates the
/// key at that frame), interpolation and, for a cubic key, its tangents.
/// Every edit is one undo step of the Sequencer.
class SequencerKeyDetailsPanel extends StatelessWidget {
  const SequencerKeyDetailsPanel({super.key, required this.viewModel});

  final SequencerViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final vm = viewModel;
    final ref = vm.selectedKey;
    final key = ref == null ? null : vm.keyAt(ref);
    final track = ref == null ? null : vm.findTrack(ref.$1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          color: EditorColors.cardHeader,
          child: Row(
            children: [
              const Icon(LucideIcons.keyRound, size: 12, color: EditorColors.warning),
              const SizedBox(width: 6),
              Text(
                vm.selectedKeys.length > 1 ? 'KEY (${vm.selectedKeys.length} SELECTED)' : 'KEY',
                key: const ValueKey('seq_key_panel_title'),
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.warning),
              ),
              const Spacer(),
              if (key != null) ...[
                Tooltip(
                  tooltip: (_) => const TooltipContainer(child: Text('Move the playhead to this key', style: TextStyle(fontSize: 9))),
                  child: GhostButton(
                    key: const ValueKey('seq_key_goto'),
                    size: ButtonSize.small,
                    density: ButtonDensity.icon,
                    onPressed: () => vm.scrubToFrame(key.frame),
                    child: const Icon(LucideIcons.crosshair, size: 12),
                  ),
                ),
                Tooltip(
                  tooltip: (_) => const TooltipContainer(child: Text('Delete the selected key(s) (Del)', style: TextStyle(fontSize: 9))),
                  child: GhostButton(
                    key: const ValueKey('seq_key_delete'),
                    size: ButtonSize.small,
                    density: ButtonDensity.icon,
                    onPressed: vm.deleteSelectedKeys,
                    child: const Icon(LucideIcons.trash2, size: 12, color: EditorColors.logError),
                  ),
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: key == null || track == null || ref == null
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Select a key on the timeline to edit its frame, values and interpolation.\nShift-click adds keys to the selection.',
                      key: ValueKey('seq_key_panel_empty'),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground),
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(8),
                  children: _details(vm, ref, key, track),
                ),
        ),
      ],
    );
  }

  List<Widget> _details(SequencerViewModel vm, SequencerKeyRef ref, SequencerKey key, SequencerTrack track) {
    final fps = vm.fps > 0 ? vm.fps : 30;
    final frame = key.frame;
    final seconds = frame / fps;
    final channels = {for (final r in vm.selectedKeys) r.$2}.toList();
    return [
      _row('Track', Text('${track.actorName} · ${track.kind.name}',
          key: const ValueKey('seq_key_track'), style: _valueStyle, overflow: TextOverflow.ellipsis)),
      _row(
          channels.length > 1 ? 'Channels' : 'Channel',
          Text(channels.join(', '), key: const ValueKey('seq_key_channels'), style: _valueStyle, overflow: TextOverflow.ellipsis)),
      _row(
        'Frame',
        SequencerNumberField(
          key: const ValueKey('seq_key_frame'),
          value: frame.toDouble(),
          decimals: 0,
          onCommit: (v) => vm.moveSelectedKeysToFrame(v.round()),
        ),
      ),
      _row('Time', Text('${seconds.toStringAsFixed(3)} s · ${_timecode(frame, fps)}', key: const ValueKey('seq_key_time'), style: _valueStyle)),
      const SizedBox(height: 8),
      _section('VALUES AT FRAME $frame'),
      if (track.kind == SequencerTrackKind.transform)
        for (final group in const ['Location', 'Rotation', 'Scale']) _transformRow(vm, track, group, frame)
      else
        for (final ch in track.channels)
          _row(
            ch.name,
            SequencerNumberField(
              key: ValueKey('seq_key_value_${ch.name}'),
              value: vm.channelValueAtFrame(track.id, ch.name, frame) ?? 0.0,
              keyed: vm.hasKeyAt(track.id, ch.name, frame),
              onCommit: (v) => vm.setChannelValueAtFrame(track.id, ch.name, frame, v),
            ),
          ),
      const SizedBox(height: 8),
      _section('INTERPOLATION'),
      _row(
        'Mode',
        Select<SequencerKeyInterpolationChoice>(
          key: const ValueKey('seq_key_interpolation'),
          value: switch (key.interpolation) {
            KeyInterpolation.constant => SequencerKeyInterpolationChoice.constant,
            KeyInterpolation.linear => SequencerKeyInterpolationChoice.linear,
            KeyInterpolation.cubic => SequencerKeyInterpolationChoice.cubic,
          },
          onChanged: (v) {
            if (v != null) vm.setSelectedKeysInterpolation(v);
          },
          itemBuilder: (context, item) => Text(_interpLabel(item), style: const TextStyle(fontSize: 9.5)),
          popup: SelectPopup(
            items: SelectItemList(
              children: [
                for (final c in SequencerKeyInterpolationChoice.values)
                  SelectItemButton(value: c, child: Text(_interpLabel(c), style: const TextStyle(fontSize: 9.5))),
              ],
            ),
          ).call,
        ),
      ),
      if (key.interpolation == KeyInterpolation.cubic) ...[
        _row(
          'In tangent',
          SequencerNumberField(
            key: const ValueKey('seq_key_in_tangent'),
            value: key.inTangent,
            onCommit: (v) => vm.setKeyTangents(ref.$1, ref.$2, ref.$3, inTangent: v),
          ),
        ),
        _row(
          'Out tangent',
          SequencerNumberField(
            key: const ValueKey('seq_key_out_tangent'),
            value: key.outTangent,
            onCommit: (v) => vm.setKeyTangents(ref.$1, ref.$2, ref.$3, outTangent: v),
          ),
        ),
      ],
    ];
  }

  Widget _transformRow(SequencerViewModel vm, SequencerTrack track, String group, int frame) {
    const axisColors = [EditorColors.axisX, EditorColors.axisY, EditorColors.axisZ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(width: 56, child: Text(group, style: _labelStyle)),
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: 3),
            Expanded(
              child: Builder(builder: (context) {
                final name = '$group.${'XYZ'[i]}';
                final keyed = vm.hasKeyAt(track.id, name, frame);
                final sampled = vm.channelValueAtFrame(track.id, name, frame);
                return SequencerNumberField(
                  key: ValueKey('seq_key_value_$name'),
                  value: sampled ?? vm.currentActorChannelValue(track.actorId, name) ?? (group == 'Scale' ? 1.0 : 0.0),
                  keyed: keyed,
                  accent: axisColors[i],
                  onCommit: (v) => vm.setChannelValueAtFrame(track.id, name, frame, v),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }

  static const _labelStyle = TextStyle(fontSize: 9.5, color: EditorColors.mutedForeground);
  static const _valueStyle = TextStyle(fontSize: 10, color: EditorColors.foreground, fontFamily: EditorTypography.monoFamily);

  Widget _row(String label, Widget value) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            SizedBox(width: 72, child: Text(label, style: _labelStyle)),
            Expanded(child: value),
          ],
        ),
      );

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(title, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.cyan)),
      );

  static String _timecode(int frame, int fps) {
    final total = frame ~/ fps;
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(total ~/ 3600)}:${two((total % 3600) ~/ 60)}:${two(total % 60)}:${two(frame % fps)}';
  }

  static String _interpLabel(SequencerKeyInterpolationChoice c) => switch (c) {
        SequencerKeyInterpolationChoice.constant => 'Constant',
        SequencerKeyInterpolationChoice.linear => 'Linear',
        SequencerKeyInterpolationChoice.cubic => 'Cubic',
        SequencerKeyInterpolationChoice.cubicAuto => 'Cubic (Auto)',
      };
}

/// A number field that commits on Enter or when it loses focus, and follows
/// [value] while it is not being edited. A keyed value is drawn bold with a
/// key-coloured edge; a sampled (unkeyed) one muted.
class SequencerNumberField extends StatefulWidget {
  const SequencerNumberField({
    super.key,
    required this.value,
    required this.onCommit,
    this.decimals = 2,
    this.keyed = true,
    this.accent,
  });

  final double value;
  final ValueChanged<double> onCommit;
  final int decimals;
  final bool keyed;
  final Color? accent;

  @override
  State<SequencerNumberField> createState() => _SequencerNumberFieldState();
}

class _SequencerNumberFieldState extends State<SequencerNumberField> {
  late final TextEditingController _controller = TextEditingController(text: _format(widget.value));
  final FocusNode _focus = FocusNode();

  String _format(double v) => v.toStringAsFixed(widget.decimals);

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit(_controller.text);
    });
  }

  @override
  void didUpdateWidget(covariant SequencerNumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focus.hasFocus && _format(widget.value) != _controller.text) _controller.text = _format(widget.value);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _commit(String text) {
    final v = double.tryParse(text.trim());
    if (v == null || !v.isFinite) {
      _controller.text = _format(widget.value);
      return;
    }
    if (_format(v) == _format(widget.value)) return;
    widget.onCommit(v);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: widget.accent ?? (widget.keyed ? EditorColors.warning : EditorColors.border), width: 2)),
      ),
      child: TextField(
        controller: _controller,
        focusNode: _focus,
        style: TextStyle(
          fontSize: 9.5,
          fontFamily: EditorTypography.monoFamily,
          fontWeight: widget.keyed ? FontWeight.bold : FontWeight.normal,
          color: widget.keyed ? EditorColors.foreground : EditorColors.mutedForeground,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        onSubmitted: _commit,
      ),
    );
  }
}

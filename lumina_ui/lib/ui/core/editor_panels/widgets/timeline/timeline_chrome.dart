import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/editor_panels/editor_panel_docking.dart' show editorPanelIcon;
import 'package:lumina_ui/ui/core/editor_panels/widgets/timeline/timeline_layout.dart';
import 'package:lumina_ui/ui/core/editor_panels/widgets/timeline/timeline_model.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

/// The transport bar: step back, play / pause, step forward, loop, and the
/// playhead and fps readout.
class TimelineTransportBar extends StatelessWidget {
  const TimelineTransportBar({super.key, required this.name, required this.model, required this.onTogglePlay});

  final String name;
  final TimelineModel model;
  final VoidCallback onTogglePlay;

  Widget _button(String id, IconData icon, String tooltip, VoidCallback onPressed, {bool active = false}) => Tooltip(
        tooltip: (context) => TooltipContainer(child: Text(tooltip).small()),
        child: GhostButton(
          key: ValueKey('editor_timeline_${name}_$id'),
          density: ButtonDensity.compact,
          onPressed: onPressed,
          child: Icon(icon, size: 13, color: active ? EditorColors.primary : EditorColors.foreground),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      height: TimelineLayout.transportHeight,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: const BoxDecoration(
        color: EditorColors.cardHeader,
        border: Border(bottom: BorderSide(color: EditorColors.border)),
      ),
      child: Row(children: [
        _button('step_back', LucideIcons.stepBack, 'Previous frame (←)', () => model.step(-1)),
        ValueListenableBuilder<bool>(
          valueListenable: model.playing,
          builder: (context, playing, _) =>
              _button('play', playing ? LucideIcons.pause : LucideIcons.play, playing ? 'Pause (Space)' : 'Play (Space)', onTogglePlay),
        ),
        _button('step_forward', LucideIcons.stepForward, 'Next frame (→)', () => model.step(1)),
        _button('loop', LucideIcons.repeat, 'Loop', model.toggleLoop, active: model.loop),
        const SizedBox(width: 8),
        ValueListenableBuilder<double>(
          valueListenable: model.playhead,
          builder: (context, frame, _) {
            final f = frame.floor();
            final fps = model.state.fps;
            return Text(
              '$f / ${model.frameCount}  ·  ${(f / fps).toStringAsFixed(2)} s',
              key: ValueKey('editor_timeline_${name}_readout'),
              style: const TextStyle(fontSize: 10, color: EditorColors.foreground, fontFeatures: [FontFeature.tabularFigures()]),
            );
          },
        ),
        const Spacer(),
        Text('${model.state.fps} fps', style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
        const SizedBox(width: 4),
      ]),
    );
  }
}

/// The track header column: group headers (semi-bold) and one row per track
/// with its icon and label, in the Outliner's row style.
class TimelineTrackHeaders extends StatelessWidget {
  const TimelineTrackHeaders({super.key, required this.name, required this.layout});

  final String name;
  final TimelineLayout layout;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: TimelineLayout.headerWidth,
      height: layout.contentHeight,
      child: Stack(children: [
        for (final r in layout.rows)
          Positioned(
            top: r.top,
            left: 0,
            right: 0,
            height: r.height,
            child: Container(
              key: ValueKey(r.isGroup ? 'editor_timeline_${name}_group_${r.group}' : 'editor_timeline_${name}_track_${r.track!.id}'),
              padding: EdgeInsets.only(left: r.isGroup ? 6 : 18, right: 6),
              decoration: BoxDecoration(
                color: r.isGroup ? EditorColors.cardHeader : EditorColors.sidebar,
                border: const Border(bottom: BorderSide(color: EditorColors.border), right: BorderSide(color: EditorColors.border)),
              ),
              child: Row(children: [
                if (r.isGroup)
                  const Icon(LucideIcons.chevronDown, size: 12, color: EditorColors.mutedForeground)
                else
                  Icon(timelineTrackIcon(r.track!.icon), size: 12, color: EditorColors.mutedForeground),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    r.isGroup ? r.group! : r.track!.label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: r.isGroup ? 11 : 10.5,
                      fontWeight: r.isGroup ? FontWeight.w600 : FontWeight.normal,
                      color: EditorColors.foreground,
                    ),
                  ),
                ),
                if (!r.isGroup && r.track!.locked) const Icon(LucideIcons.lock, size: 10, color: EditorColors.mutedForeground),
              ]),
            ),
          ),
      ]),
    );
  }
}

/// A track's Lucide icon by name.
IconData timelineTrackIcon(String? name) => switch (name?.toLowerCase()) {
      null || '' => LucideIcons.diamond,
      'text' || 'type' => LucideIcons.type,
      'diamond' => LucideIcons.diamond,
      'hand' => LucideIcons.hand,
      'footprints' || 'foot' => LucideIcons.footprints,
      'person-standing' || 'body' => LucideIcons.personStanding,
      'move' || 'root' => LucideIcons.move,
      'music' || 'audio' => LucideIcons.music,
      'camera' => LucideIcons.camera,
      'film' || 'clips' => LucideIcons.film,
      'sparkles' => LucideIcons.sparkles,
      'bone' => LucideIcons.bone,
      final other => editorPanelIcon(other),
    };

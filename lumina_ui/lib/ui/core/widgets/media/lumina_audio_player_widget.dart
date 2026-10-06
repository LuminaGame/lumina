import 'package:lumina/lumina.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Full-featured, shadcn_flutter styled audio player widget for Lumina Studio.
///
/// Provides transport controls (play/pause, stop, scrub slider, timecode),
/// volume popover, playback rate selector, and loop toggle.
class LuminaAudioPlayerWidget extends StatefulWidget {
  const LuminaAudioPlayerWidget({
    super.key,
    required this.controller,
    this.title,
    this.onPickAudio,
  });

  final LuminaAudioController controller;
  final String? title;
  final VoidCallback? onPickAudio;

  @override
  State<LuminaAudioPlayerWidget> createState() => _LuminaAudioPlayerWidgetState();
}

class _LuminaAudioPlayerWidgetState extends State<LuminaAudioPlayerWidget> {
  double _lastVolumeBeforeMute = 1.0;

  void _toggleMute() {
    final c = widget.controller;
    if (c.value.volume > 0) {
      _lastVolumeBeforeMute = c.value.volume;
      c.setVolume(0.0);
    } else {
      c.setVolume(_lastVolumeBeforeMute > 0 ? _lastVolumeBeforeMute : 1.0);
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;

    return ValueListenableBuilder<LuminaAudioPlayerValue>(
      valueListenable: c,
      builder: (context, value, _) {
        final totalSeconds = value.duration.inMilliseconds / 1000.0;
        final currentSeconds = (value.position.inMilliseconds / 1000.0).clamp(0.0, totalSeconds > 0 ? totalSeconds : 0.0);
        final max = totalSeconds > 0 ? totalSeconds : 1.0;
        final title = widget.title ?? value.title ?? (value.source != null ? value.source!.split(RegExp(r'[\\/]')).last : 'Audio Clip');

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF131317),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0x22FFFFFF)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.music, size: 14, color: Color(0xFF3B82F6)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_formatDuration(value.position)} / ${_formatDuration(value.duration)}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Slider(
                value: SliderValue.single(currentSeconds.clamp(0.0, max)),
                min: 0.0,
                max: max,
                onChanged: (v) => c.seekToSeconds(v.value),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  GhostButton(
                    density: ButtonDensity.compact,
                    onPressed: c.playOrPause,
                    child: Icon(
                      value.isPlaying ? LucideIcons.pause : LucideIcons.play,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 4),
                  GhostButton(
                    density: ButtonDensity.compact,
                    onPressed: c.stop,
                    child: const Icon(LucideIcons.square, size: 12, color: Colors.white),
                  ),
                  const Spacer(),
                  // Volume
                  GhostButton(
                    density: ButtonDensity.compact,
                    onPressed: _toggleMute,
                    child: Icon(
                      value.volume == 0 ? LucideIcons.volumeX : LucideIcons.volume2,
                      size: 14,
                      color: value.volume == 0 ? const Color(0xFFEF4444) : Colors.white,
                    ),
                  ),
                  SizedBox(
                    width: 64,
                    child: Slider(
                      value: SliderValue.single(value.volume),
                      min: 0.0,
                      max: 1.0,
                      onChanged: (v) => c.setVolume(v.value),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Loop
                  GhostButton(
                    density: ButtonDensity.compact,
                    onPressed: () => c.setLooping(!value.isLooping),
                    child: Icon(
                      LucideIcons.repeat,
                      size: 13,
                      color: value.isLooping ? const Color(0xFF3B82F6) : const Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Playback speed
                  OutlineButton(
                    density: ButtonDensity.compact,
                    onPressed: () {
                      final speeds = [0.5, 1.0, 1.5, 2.0];
                      final current = value.playbackSpeed;
                      final nextIndex = (speeds.indexOf(current) + 1) % speeds.length;
                      c.setPlaybackSpeed(speeds[nextIndex >= 0 ? nextIndex : 1]);
                    },
                    child: Text(
                      '${value.playbackSpeed.toStringAsFixed(value.playbackSpeed.truncateToDouble() == value.playbackSpeed ? 0 : 2)}x',
                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

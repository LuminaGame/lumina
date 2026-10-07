import 'package:flutter/widgets.dart';

import 'package:lumina/src/media/audio/lumina_audio_controller.dart';
import 'package:lumina/src/media/audio/lumina_audio_player_value.dart';

/// Renders a compact, sleek audio player control bar for a [LuminaAudioController].
class LuminaAudioPlayer extends StatelessWidget {
  const LuminaAudioPlayer({
    super.key,
    required this.controller,
    this.backgroundColor = const Color(0xFF141418),
    this.foregroundColor = const Color(0xFFFAFAFA),
    this.accentColor = const Color(0xFF3B82F6),
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
  });

  final LuminaAudioController controller;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color accentColor;
  final EdgeInsetsGeometry padding;

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
    return ValueListenableBuilder<LuminaAudioPlayerValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final totalMs = value.duration.inMilliseconds;
        final currentMs = value.position.inMilliseconds.clamp(0, totalMs > 0 ? totalMs : 0);
        final ratio = totalMs > 0 ? (currentMs / totalMs).clamp(0.0, 1.0) : 0.0;
        final title = value.title ?? (value.source != null ? value.source!.split(RegExp(r'[\\/]')).last : 'Audio Track');

        return Container(
          padding: padding,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0x22FFFFFF)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Text('🎵', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: foregroundColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_formatDuration(value.position)} / ${_formatDuration(value.duration)}',
                    style: const TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LayoutBuilder(builder: (context, constraints) {
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (details) {
                    final boxWidth = constraints.maxWidth;
                    if (boxWidth > 0 && totalMs > 0) {
                      final target = (details.localPosition.dx / boxWidth).clamp(0.0, 1.0);
                      controller.seekTo(Duration(milliseconds: (target * totalMs).round()));
                    }
                  },
                  onTapDown: (details) {
                    final boxWidth = constraints.maxWidth;
                    if (boxWidth > 0 && totalMs > 0) {
                      final target = (details.localPosition.dx / boxWidth).clamp(0.0, 1.0);
                      controller.seekTo(Duration(milliseconds: (target * totalMs).round()));
                    }
                  },
                  child: SizedBox(
                    height: 18,
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0x33FFFFFF),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: ratio,
                          child: Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: accentColor,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        Positioned(
                          left: (constraints.maxWidth * ratio - 6).clamp(0.0, constraints.maxWidth - 12),
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: foregroundColor,
                              shape: BoxShape.circle,
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x44000000),
                                  blurRadius: 3,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: controller.playOrPause,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: accentColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            value.isPlaying ? 'Pause' : 'Play',
                            style: const TextStyle(
                              color: Color(0xFFFFFFFF),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: controller.stop,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0x22FFFFFF),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Stop',
                            style: TextStyle(
                              color: Color(0xFFD4D4D8),
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => controller.setLooping(!value.isLooping),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: value.isLooping ? accentColor.withValues(alpha: 0.25) : const Color(0x11FFFFFF),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: value.isLooping ? accentColor : const Color(0x22FFFFFF),
                            ),
                          ),
                          child: Text(
                            'Loop',
                            style: TextStyle(
                              color: value.isLooping ? accentColor : const Color(0xFF9CA3AF),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
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

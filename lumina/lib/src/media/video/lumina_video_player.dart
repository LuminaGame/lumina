import 'package:flutter/widgets.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'lumina_video_controller.dart';
import 'lumina_video_player_value.dart';

/// Renders video output driven by a [LuminaVideoController].
///
/// Automatically handles native hardware-accelerated video surfaces when available,
/// and provides deterministic visual fallback in headless/test environments.
class LuminaVideoPlayer extends StatelessWidget {
  const LuminaVideoPlayer({
    super.key,
    required this.controller,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.showControls = false,
    this.placeholder,
    this.errorBuilder,
  });

  final LuminaVideoController controller;
  final BoxFit fit;
  final Alignment alignment;
  final bool showControls;
  final Widget? placeholder;
  final Widget Function(BuildContext context, String error)? errorBuilder;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<LuminaVideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        if (value.hasError) {
          if (errorBuilder != null) {
            return errorBuilder!(context, value.errorDescription!);
          }
          return Container(
            color: const Color(0xFF0F0F12),
            alignment: Alignment.center,
            padding: const EdgeInsets.all(16),
            child: Text(
              'Video Error: ${value.errorDescription}',
              style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12),
              textAlign: TextAlign.center,
            ),
          );
        }

        if (!value.isInitialized) {
          return placeholder ??
              Container(
                color: const Color(0xFF0A0A0C),
                alignment: Alignment.center,
                child: const Text(
                  'Loading video...',
                  style: TextStyle(color: Color(0xFF71717A), fontSize: 12),
                ),
              );
        }

        Widget content;
        final rawVideo = controller.rawVideoController;
        if (rawVideo != null) {
          content = Video(
            key: const Key('lumina_native_video_surface'),
            controller: rawVideo,
            fit: fit,
            alignment: alignment,
            controls: NoVideoControls,
          );
        } else {
          content = Center(
            child: AspectRatio(
              aspectRatio: value.aspectRatio,
              child: Container(
                key: const Key('lumina_video_fallback_surface'),
                color: const Color(0xFF000000),
                alignment: Alignment.center,
                child: placeholder ??
                    const Text(
                      'Video Preview',
                      style: TextStyle(color: Color(0xFF52525B), fontSize: 12),
                    ),
              ),
            ),
          );
        }

        if (showControls) {
          return Stack(
            fit: StackFit.passthrough,
            children: [
              content,
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _VideoControlsOverlay(controller: controller, value: value),
              ),
            ],
          );
        }

        return content;
      },
    );
  }
}

class _VideoControlsOverlay extends StatelessWidget {
  const _VideoControlsOverlay({
    required this.controller,
    required this.value,
  });

  final LuminaVideoController controller;
  final LuminaVideoPlayerValue value;

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
    final totalMs = value.duration.inMilliseconds;
    final currentMs = value.position.inMilliseconds.clamp(0, totalMs > 0 ? totalMs : 0);
    final ratio = totalMs > 0 ? (currentMs / totalMs).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00000000), Color(0xCC000000)],
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: controller.playOrPause,
            child: Container(
              padding: const EdgeInsets.all(4),
              child: Text(
                value.isPlaying ? '❚❚' : '▶',
                style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 14),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: LayoutBuilder(builder: (context, constraints) {
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
                  height: 20,
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0x44FFFFFF),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: ratio,
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(width: 8),
          Text(
            '${_formatDuration(value.position)} / ${_formatDuration(value.duration)}',
            style: const TextStyle(
              color: Color(0xFFD4D4D8),
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => controller.setLooping(!value.isLooping),
            child: Text(
              '🔁',
              style: TextStyle(
                fontSize: 12,
                color: value.isLooping ? const Color(0xFF3B82F6) : const Color(0x77FFFFFF),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

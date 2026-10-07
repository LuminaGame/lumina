import 'dart:async';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Full-featured, shadcn_flutter styled video player widget for Lumina Studio.
///
/// Provides transport controls (play/pause, stop, seek scrub slider, timecode),
/// volume popover, playback rate selector, loop toggle, and optional fullscreen expansion.
class LuminaVideoPlayerWidget extends StatefulWidget {
  const LuminaVideoPlayerWidget({
    super.key,
    required this.controller,
    this.title,
    this.showControls = true,
    this.autoHideControls = true,
    this.fit = BoxFit.contain,
    this.onPickVideo,
    this.onFullscreenToggle,
    this.overlay,
  });

  final LuminaVideoController controller;
  final String? title;
  final bool showControls;
  final bool autoHideControls;
  final BoxFit fit;
  final VoidCallback? onPickVideo;
  final VoidCallback? onFullscreenToggle;
  final Widget? overlay;

  @override
  State<LuminaVideoPlayerWidget> createState() => _LuminaVideoPlayerWidgetState();
}

class _LuminaVideoPlayerWidgetState extends State<LuminaVideoPlayerWidget> {
  bool _controlsVisible = true;
  Timer? _hideTimer;
  double _lastVolumeBeforeMute = 1.0;

  @override
  void initState() {
    super.initState();
    _resetHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _resetHideTimer() {
    _hideTimer?.cancel();
    if (!widget.autoHideControls || !widget.controller.value.isPlaying) {
      if (!_controlsVisible) setState(() => _controlsVisible = true);
      return;
    }
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && widget.controller.value.isPlaying) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _onPointerHover() {
    if (!_controlsVisible) {
      setState(() => _controlsVisible = true);
    }
    _resetHideTimer();
  }

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

    return ValueListenableBuilder<LuminaVideoPlayerValue>(
      valueListenable: c,
      builder: (context, value, _) {
        if (!value.isInitialized && (value.source == null || value.source!.isEmpty)) {
          return _buildEmptyPlaceholder();
        }

        return MouseRegion(
          onHover: (_) => _onPointerHover(),
          child: Container(
            color: const Color(0xFF0B0B0E),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Center(
                  child: AspectRatio(
                    aspectRatio: value.aspectRatio,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        LuminaVideoPlayer(
                          controller: c,
                          fit: widget.fit,
                          showControls: false,
                        ),
                        if (widget.overlay != null) widget.overlay!,
                      ],
                    ),
                  ),
                ),
                if (widget.showControls)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _controlsVisible ? 1.0 : 0.0,
                      child: IgnorePointer(
                        ignoring: !_controlsVisible,
                        child: _buildControlsBar(value),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyPlaceholder() {
    final muted = Theme.of(context).colorScheme.mutedForeground;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.fileVideo,
            size: 48,
            color: Colors.white.withValues(alpha: 0.25),
          ),
          const SizedBox(height: 14),
          const Text(
            'No Video Selected',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Load a video source to begin playback preview.',
            style: TextStyle(fontSize: 12, color: muted),
          ),
          if (widget.onPickVideo != null) ...[
            const SizedBox(height: 16),
            PrimaryButton(
              onPressed: widget.onPickVideo,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.fileVideo, size: 16),
                  SizedBox(width: 8),
                  Text('Browse Video File...'),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildControlsBar(LuminaVideoPlayerValue value) {
    final totalSeconds = value.duration.inMilliseconds / 1000.0;
    final currentSeconds = (value.position.inMilliseconds / 1000.0).clamp(0.0, totalSeconds > 0 ? totalSeconds : 0.0);
    final max = totalSeconds > 0 ? totalSeconds : 1.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      decoration: const BoxDecoration(
        color: Color(0xEE131317),
        border: Border(top: BorderSide(color: Color(0x22FFFFFF))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Slider(
            value: SliderValue.single(currentSeconds.clamp(0.0, max)),
            min: 0.0,
            max: max,
            onChanged: (v) {
              widget.controller.seekToSeconds(v.value);
              _resetHideTimer();
            },
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              GhostButton(
                density: ButtonDensity.compact,
                onPressed: () {
                  widget.controller.playOrPause();
                  _resetHideTimer();
                },
                child: Icon(
                  value.isPlaying ? LucideIcons.pause : LucideIcons.play,
                  size: 14,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 4),
              GhostButton(
                density: ButtonDensity.compact,
                onPressed: () {
                  widget.controller.stop();
                  _resetHideTimer();
                },
                child: const Icon(LucideIcons.square, size: 12, color: Colors.white),
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
              const Spacer(),
              // Volume button
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
                width: 70,
                child: Slider(
                  value: SliderValue.single(value.volume),
                  min: 0.0,
                  max: 1.0,
                  onChanged: (v) {
                    widget.controller.setVolume(v.value);
                    _resetHideTimer();
                  },
                ),
              ),
              const SizedBox(width: 6),
              // Loop button
              GhostButton(
                density: ButtonDensity.compact,
                onPressed: () {
                  widget.controller.setLooping(!value.isLooping);
                  _resetHideTimer();
                },
                child: Icon(
                  LucideIcons.repeat,
                  size: 13,
                  color: value.isLooping ? const Color(0xFF3B82F6) : const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(width: 6),
              // Playback speed menu
              OutlineButton(
                density: ButtonDensity.compact,
                onPressed: () {
                  final speeds = [0.5, 1.0, 1.5, 2.0];
                  final current = value.playbackSpeed;
                  final nextIndex = (speeds.indexOf(current) + 1) % speeds.length;
                  widget.controller.setPlaybackSpeed(speeds[nextIndex >= 0 ? nextIndex : 1]);
                  _resetHideTimer();
                },
                child: Text(
                  '${value.playbackSpeed.toStringAsFixed(value.playbackSpeed.truncateToDouble() == value.playbackSpeed ? 0 : 2)}x',
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                ),
              ),
              if (widget.onFullscreenToggle != null) ...[
                const SizedBox(width: 6),
                GhostButton(
                  density: ButtonDensity.compact,
                  onPressed: widget.onFullscreenToggle,
                  child: const Icon(LucideIcons.maximize2, size: 13, color: Colors.white),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

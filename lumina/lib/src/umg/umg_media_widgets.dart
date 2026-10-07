import 'dart:io';

import 'package:flutter/widgets.dart';

import 'package:lumina/src/media/media.dart';
import 'package:lumina/src/umg/umg_widgets.dart';

/// UMG Video Player widget: can be initialized with a [source] string (file path,
/// network URL, or asset), or driven by an external [controller].
class LuminaUmgVideoPlayer extends StatefulWidget {
  const LuminaUmgVideoPlayer({
    super.key,
    this.source,
    this.autoPlay = false,
    this.loop = false,
    this.volume = 1.0,
    this.controller,
    this.fit = BoxFit.contain,
    this.showControls = true,
    this.onCompleted,
  });

  final String? source;
  final bool autoPlay;
  final bool loop;
  final double volume;
  final LuminaVideoController? controller;
  final BoxFit fit;
  final bool showControls;
  final VoidCallback? onCompleted;

  @override
  State<LuminaUmgVideoPlayer> createState() => _LuminaUmgVideoPlayerState();
}

class _LuminaUmgVideoPlayerState extends State<LuminaUmgVideoPlayer> {
  LuminaVideoController? _internalController;
  LuminaVideoController get _effectiveController =>
      widget.controller ?? _internalController!;

  @override
  void initState() {
    super.initState();
    _setupController();
  }

  void _setupController() {
    if (widget.controller == null) {
      final src = widget.source;
      if (src != null && src.isNotEmpty) {
        if (src.startsWith('http://') || src.startsWith('https://')) {
          _internalController = LuminaVideoController.network(
            src,
            autoPlay: widget.autoPlay,
            loop: widget.loop,
            volume: widget.volume,
          );
        } else if (src.startsWith('asset://') || src.startsWith('assets/')) {
          _internalController = LuminaVideoController.asset(
            src,
            autoPlay: widget.autoPlay,
            loop: widget.loop,
            volume: widget.volume,
          );
        } else {
          _internalController = LuminaVideoController.file(
            File(src),
            autoPlay: widget.autoPlay,
            loop: widget.loop,
            volume: widget.volume,
          );
        }
      } else {
        _internalController = LuminaVideoController.headless(
          autoPlay: widget.autoPlay,
          loop: widget.loop,
          volume: widget.volume,
        );
      }
      _internalController?.initialize();
    }
  }

  @override
  void didUpdateWidget(LuminaUmgVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller == null && oldWidget.source != widget.source) {
      _internalController?.dispose();
      _setupController();
    }
  }

  @override
  void dispose() {
    _internalController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: LuminaUmgColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: LuminaUmgColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: LuminaVideoPlayer(
        controller: _effectiveController,
        fit: widget.fit,
        showControls: widget.showControls,
      ),
    );
  }
}

/// UMG Audio Player widget: renders a styled audio player bar driven by
/// [source] or an external [controller].
class LuminaUmgAudioPlayer extends StatefulWidget {
  const LuminaUmgAudioPlayer({
    super.key,
    this.source,
    this.title,
    this.autoPlay = false,
    this.loop = false,
    this.volume = 1.0,
    this.controller,
  });

  final String? source;
  final String? title;
  final bool autoPlay;
  final bool loop;
  final double volume;
  final LuminaAudioController? controller;

  @override
  State<LuminaUmgAudioPlayer> createState() => _LuminaUmgAudioPlayerState();
}

class _LuminaUmgAudioPlayerState extends State<LuminaUmgAudioPlayer> {
  LuminaAudioController? _internalController;
  LuminaAudioController get _effectiveController =>
      widget.controller ?? _internalController!;

  @override
  void initState() {
    super.initState();
    _setupController();
  }

  void _setupController() {
    if (widget.controller == null) {
      final src = widget.source;
      if (src != null && src.isNotEmpty) {
        if (src.startsWith('http://') || src.startsWith('https://')) {
          _internalController = LuminaAudioController.network(
            src,
            title: widget.title,
            autoPlay: widget.autoPlay,
            loop: widget.loop,
            volume: widget.volume,
          );
        } else if (src.startsWith('asset://') || src.startsWith('assets/')) {
          _internalController = LuminaAudioController.asset(
            src,
            title: widget.title,
            autoPlay: widget.autoPlay,
            loop: widget.loop,
            volume: widget.volume,
          );
        } else {
          _internalController = LuminaAudioController.file(
            File(src),
            title: widget.title,
            autoPlay: widget.autoPlay,
            loop: widget.loop,
            volume: widget.volume,
          );
        }
      } else {
        _internalController = LuminaAudioController.headless(
          title: widget.title ?? 'Audio Player',
          autoPlay: widget.autoPlay,
          loop: widget.loop,
          volume: widget.volume,
        );
      }
      _internalController?.initialize();
    }
  }

  @override
  void didUpdateWidget(LuminaUmgAudioPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller == null && oldWidget.source != widget.source) {
      _internalController?.dispose();
      _setupController();
    }
  }

  @override
  void dispose() {
    _internalController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LuminaAudioPlayer(
      controller: _effectiveController,
      backgroundColor: LuminaUmgColors.surface,
      foregroundColor: LuminaUmgColors.foreground,
      accentColor: LuminaUmgColors.primary,
    );
  }
}

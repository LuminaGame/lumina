import 'dart:async';

import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:window_manager/window_manager.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

/// Lumina Studio splash and loading screen — frameless 720×400 centered window
/// with glowing Lumina logo, "Lumina Studio", engine/project subtitle, live
/// status text, bottom-edge 2px accent progress bar, and hover/cancel controls.
class LuminaSplashScreen extends StatefulWidget {
  /// The main bold title (defaults to "Lumina Studio").
  final String title;

  /// Subtitle line, e.g. "Lumina Editor 0.0.1 · MyProject" or "Lumina Editor 0.0.1".
  final String subtitle;

  /// Dynamic status message, e.g. "25% - Resolving packages", "Scanning projects…".
  final String statusText;

  /// Progress fraction from 0.0 to 1.0. If null, an indeterminate shimmer animation is used.
  final double? progress;

  /// Whether the operation has failed (renders text and progress in destructive red).
  final bool failed;

  /// Whether this splash manages the OS window (resizes to 720×400 frameless, centers, restores on exit).
  final bool manageWindow;

  /// Optional cancellation callback.
  final VoidCallback? onCancel;

  /// Label for the cancel button (defaults to "Cancel").
  final String cancelLabel;

  /// Custom action buttons to display alongside or above the status row.
  final List<Widget>? actions;

  /// Optional extra widget (e.g. scrollable log tail).
  final Widget? extraContent;

  /// Whether action buttons should always be visible without requiring hover.
  final bool alwaysShowActions;

  /// Custom key for the root container.
  final Key? splashKey;

  /// Key for the status text widget (useful for automated widget tests).
  final Key? statusKey;

  /// Key for the bottom progress bar widget.
  final Key? progressBarKey;

  /// Key for the cancel button.
  final Key? cancelKey;

  /// Asset path for splash key art.
  final String splashArt;

  const LuminaSplashScreen({
    super.key,
    this.title = 'Lumina Studio',
    required this.subtitle,
    required this.statusText,
    this.progress,
    this.failed = false,
    this.manageWindow = true,
    this.onCancel,
    this.cancelLabel = 'Cancel',
    this.actions,
    this.extraContent,
    this.alwaysShowActions = false,
    this.splashKey,
    this.statusKey,
    this.progressBarKey,
    this.cancelKey,
    this.splashArt = 'assets/splash/lumina_splash.png',
  });

  static const Size windowSize = Size(720, 400);

  @override
  State<LuminaSplashScreen> createState() => _LuminaSplashScreenState();
}

class _LuminaSplashScreenState extends State<LuminaSplashScreen> with SingleTickerProviderStateMixin {
  Rect? _launcherBounds;
  bool _wasMaximized = false;
  bool _hovering = false;
  AnimationController? _indeterminateController;

  @override
  void initState() {
    super.initState();
    if (widget.progress == null) {
      _indeterminateController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1400),
      )..repeat();
    }
    if (widget.manageWindow) {
      unawaited(_enterSplashWindow());
    }
  }

  @override
  void didUpdateWidget(covariant LuminaSplashScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.progress == null && _indeterminateController == null) {
      _indeterminateController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1400),
      )..repeat();
    } else if (widget.progress != null && _indeterminateController != null) {
      _indeterminateController?.dispose();
      _indeterminateController = null;
    }
  }

  Future<void> _guard(Future<void> Function() call) async {
    try {
      await call();
    } catch (_) {
      // Ignored in test environments or platforms without native window manager support.
    }
  }

  Future<void> _enterSplashWindow() => _guard(() async {
        _wasMaximized = await windowManager.isMaximized();
        _launcherBounds = await windowManager.getBounds();
        if (_wasMaximized) {
          await windowManager.unmaximize();
        }
        await windowManager.setResizable(false);
        await windowManager.setSize(LuminaSplashScreen.windowSize);
        await windowManager.center();
        await windowManager.setAlwaysOnTop(true);
      });

  Future<void> _leaveSplashWindow() => _guard(() async {
        await windowManager.setAlwaysOnTop(false);
        await windowManager.setResizable(true);
        if (_wasMaximized) {
          await windowManager.maximize();
        } else if (_launcherBounds != null) {
          await windowManager.setBounds(_launcherBounds!);
        }
      });

  @override
  void dispose() {
    _indeterminateController?.dispose();
    if (widget.manageWindow) {
      unawaited(_leaveSplashWindow());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showControls = widget.alwaysShowActions || _hovering || widget.failed || widget.extraContent != null;
    final hasActions = (widget.actions != null && widget.actions!.isNotEmpty) || widget.onCancel != null;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        // Frameless: drag anywhere on the splash window to move it.
        onPanStart: widget.manageWindow ? (_) => _guard(windowManager.startDragging) : null,
        child: Container(
          key: widget.splashKey ?? const Key('lumina_splash_screen'),
          color: EditorColors.background,
          child: Stack(
            children: [
              Positioned.fill(child: _SplashArt(splashArt: widget.splashArt)),
              Positioned(
                left: 28,
                right: 28,
                bottom: 22,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.extraContent != null) ...[
                      widget.extraContent!,
                      const SizedBox(height: 10),
                    ],
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.title,
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  color: EditorColors.foreground,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.subtitle,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: EditorColors.mutedForeground,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                widget.statusText,
                                key: widget.statusKey,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: widget.failed ? FontWeight.w600 : FontWeight.normal,
                                  color: widget.failed ? EditorColors.destructive : EditorColors.foreground,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              'assets/logo_color.png',
                              height: 40,
                              errorBuilder: (_, _, _) => const SizedBox(height: 40),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              '© Lumina',
                              style: TextStyle(
                                fontSize: 10,
                                color: EditorColors.mutedForeground,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (hasActions) ...[
                      const SizedBox(height: 10),
                      AnimatedOpacity(
                        opacity: showControls ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 120),
                        child: IgnorePointer(
                          ignoring: !showControls,
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              if (widget.actions != null) ...widget.actions!,
                              if (widget.onCancel != null)
                                GhostButton(
                                  key: widget.cancelKey,
                                  density: ButtonDensity.compact,
                                  onPressed: widget.onCancel,
                                  child: Text(
                                    widget.cancelLabel,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // 2 px accent progress bar along the bottom edge
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 2,
                child: _ProgressBar(
                  progressBarKey: widget.progressBarKey,
                  progress: widget.progress,
                  failed: widget.failed,
                  controller: _indeterminateController,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final Key? progressBarKey;
  final double? progress;
  final bool failed;
  final AnimationController? controller;

  const _ProgressBar({
    this.progressBarKey,
    this.progress,
    required this.failed,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final barColor = failed ? EditorColors.destructive : EditorColors.primary;

    if (progress != null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          key: progressBarKey ?? const Key('lumina_splash_progress_bar'),
          widthFactor: progress!.clamp(0.0, 1.0),
          child: Container(color: barColor),
        ),
      );
    }

    if (controller != null) {
      return AnimatedBuilder(
        animation: controller!,
        builder: (context, _) {
          // Smooth sweeping indeterminate indicator
          final val = controller!.value;
          final alignX = -1.0 + (val * 2.6);
          return Align(
            alignment: Alignment(alignX.clamp(-1.0, 1.0), 0),
            child: FractionallySizedBox(
              key: progressBarKey ?? const Key('lumina_splash_progress_bar'),
              widthFactor: 0.35,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      barColor.withValues(alpha: 0.2),
                      barColor,
                      barColor.withValues(alpha: 0.2),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    return Container(color: barColor);
  }
}

/// Key art background or centered glowing logo with subtle dark gradient.
class _SplashArt extends StatelessWidget {
  final String splashArt;

  const _SplashArt({required this.splashArt});

  @override
  Widget build(BuildContext context) {
    final fallback = DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [EditorColors.cardHeader, EditorColors.background],
        ),
      ),
      child: Align(
        alignment: const Alignment(0, -0.35),
        child: Image.asset(
          'assets/logo_color.png',
          height: 96,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      ),
    );
    return Image.asset(
      splashArt,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}

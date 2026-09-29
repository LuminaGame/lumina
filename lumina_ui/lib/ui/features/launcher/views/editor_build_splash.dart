import 'dart:async';

import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:window_manager/window_manager.dart';

import '../../../core/theme/editor_theme.dart';
import '../view_models/editor_build_view_model.dart';

/// The project editor build splash — key art, "Lumina Studio", the engine and project line, a
/// `NN% - <phase>` status line and a 2 px bar along the bottom edge; a log
/// tail and Cancel on hover; on failure `Open without plugins` / `Retry` /
/// `Open log file` / `Close`.
class EditorBuildSplash extends StatefulWidget {
  final EditorBuildViewModel viewModel;

  /// The build finished: exec the project editor.
  final void Function(EditorBuildViewModel viewModel) onSucceeded;

  /// Open the project in this (stock) editor without its code plugins.
  final VoidCallback onOpenWithoutPlugins;

  /// Back to the launcher (Cancel, or Close after a failure).
  final VoidCallback onClose;

  /// Switch the OS window to the 720×400 frameless splash window (off in
  /// widget tests, which have no native window).
  final bool manageWindow;

  const EditorBuildSplash({
    super.key,
    required this.viewModel,
    required this.onSucceeded,
    required this.onOpenWithoutPlugins,
    required this.onClose,
    this.manageWindow = true,
  });

  /// Whether the launcher lets the splash resize the native window. A smoke
  /// run that records the splash inside its fixed-size test window turns it
  /// off; widget tests (no native window) never manage it.
  static bool manageNativeWindow = true;

  static const Size windowSize = Size(720, 400);
  static const String splashArt = 'assets/splash/lumina_splash.png';

  @override
  State<EditorBuildSplash> createState() => _EditorBuildSplashState();
}

class _EditorBuildSplashState extends State<EditorBuildSplash> {
  Rect? _launcherBounds;
  bool _hovering = false;

  EditorBuildViewModel get vm => widget.viewModel;

  @override
  void initState() {
    super.initState();
    vm.addListener(_changed);
    if (widget.manageWindow) unawaited(_enterSplashWindow());
    _run();
  }

  void _run() {
    vm.start().then((outcome) {
      if (!mounted) return;
      if (vm.state == EditorBuildSplashState.succeeded) widget.onSucceeded(vm);
      if (vm.state == EditorBuildSplashState.cancelled) _close();
    });
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _guard(Future<void> Function() call) async {
    try {
      await call();
    } catch (_) {
      // No native window (tests) or a platform without that call.
    }
  }

  Future<void> _enterSplashWindow() => _guard(() async {
        _launcherBounds = await windowManager.getBounds();
        await windowManager.setResizable(false);
        await windowManager.setSize(EditorBuildSplash.windowSize);
        await windowManager.center();
        await windowManager.setAlwaysOnTop(true);
      });

  Future<void> _leaveSplashWindow() => _guard(() async {
        await windowManager.setAlwaysOnTop(false);
        await windowManager.setResizable(true);
        final bounds = _launcherBounds;
        if (bounds != null) await windowManager.setBounds(bounds);
      });

  void _close() {
    if (widget.manageWindow) unawaited(_leaveSplashWindow());
    widget.onClose();
  }

  void _openWithoutPlugins() {
    if (widget.manageWindow) unawaited(_leaveSplashWindow());
    widget.onOpenWithoutPlugins();
  }

  @override
  void dispose() {
    vm.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final failed = vm.state == EditorBuildSplashState.failed;
    final running = vm.state == EditorBuildSplashState.running;
    final showControls = _hovering || failed || vm.showLog;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        // Frameless: drag anywhere to move the splash.
        onPanStart: widget.manageWindow ? (_) => _guard(windowManager.startDragging) : null,
        child: Container(
          key: const Key('editor_build_splash'),
          color: EditorColors.background,
          child: Stack(
            children: [
              const Positioned.fill(child: _SplashArt()),
              Positioned(
                left: 28,
                right: 28,
                bottom: 22,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (vm.showLog) _LogTail(lines: vm.logLines),
                    if (vm.showLog) const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Lumina Studio',
                                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: EditorColors.foreground)),
                              const SizedBox(height: 2),
                              Text('Lumina Editor ${vm.engineVersion} · ${vm.projectName}',
                                  style: const TextStyle(fontSize: 12, color: EditorColors.mutedForeground)),
                              const SizedBox(height: 10),
                              Text(
                                vm.statusText,
                                key: const Key('editor_build_status'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: failed ? FontWeight.w600 : FontWeight.normal,
                                  color: failed ? EditorColors.destructive : EditorColors.foreground,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset('assets/logo_color.png', height: 40, errorBuilder: (_, _, _) => const SizedBox(height: 40)),
                            const SizedBox(height: 6),
                            const Text('© Lumina',
                                style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    AnimatedOpacity(
                      opacity: showControls ? 1 : 0,
                      duration: const Duration(milliseconds: 120),
                      child: IgnorePointer(
                        ignoring: !showControls,
                        child: Wrap(
                          spacing: 6,
                          children: [
                            GhostButton(
                              key: const Key('editor_build_show_log'),
                              density: ButtonDensity.compact,
                              onPressed: vm.toggleLog,
                              child: Text(vm.showLog ? 'Hide log' : 'Show log', style: const TextStyle(fontSize: 11)),
                            ),
                            if (running)
                              GhostButton(
                                key: const Key('editor_build_cancel'),
                                density: ButtonDensity.compact,
                                onPressed: vm.cancel,
                                child: const Text('Cancel', style: TextStyle(fontSize: 11)),
                              ),
                            if (failed) ...[
                              OutlineButton(
                                key: const Key('editor_build_open_without_plugins'),
                                density: ButtonDensity.compact,
                                onPressed: _openWithoutPlugins,
                                child: Text(vm.hasPlugins ? 'Open without plugins' : 'Open in this editor', style: const TextStyle(fontSize: 11)),
                              ),
                              PrimaryButton(
                                key: const Key('editor_build_retry'),
                                density: ButtonDensity.compact,
                                onPressed: _run,
                                child: const Text('Retry', style: TextStyle(fontSize: 11)),
                              ),
                              GhostButton(
                                key: const Key('editor_build_open_log'),
                                density: ButtonDensity.compact,
                                onPressed: vm.openLogFile,
                                child: const Text('Open log file', style: TextStyle(fontSize: 11)),
                              ),
                              GhostButton(
                                key: const Key('editor_build_close'),
                                density: ButtonDensity.compact,
                                onPressed: _close,
                                child: const Text('Close', style: TextStyle(fontSize: 11)),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // The 2 px bar along the bottom edge.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    key: const Key('editor_build_progress_bar'),
                    widthFactor: vm.fraction.clamp(0.0, 1.0),
                    child: Container(color: failed ? EditorColors.destructive : EditorColors.primary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `assets/splash/lumina_splash.png` when committed; until then the theme's
/// background gradient with the colour logo centred.
class _SplashArt extends StatelessWidget {
  const _SplashArt();

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
        child: Image.asset('assets/logo_color.png', height: 96, errorBuilder: (_, _, _) => const SizedBox.shrink()),
      ),
    );
    return Image.asset(EditorBuildSplash.splashArt, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback);
  }
}

/// The build log, scrollable with an always-visible bar. It follows new
/// lines while it is at the bottom and stays put once scrolled up.
class _LogTail extends StatefulWidget {
  final List<String> lines;
  const _LogTail({required this.lines});

  @override
  State<_LogTail> createState() => _LogTailState();
}

class _LogTailState extends State<_LogTail> {
  static const double _lineHeight = 13.0;

  // The list is reversed: offset 0 is the latest line, so the log opens at
  // the bottom and follows new lines without a jump.
  final ScrollController _scroll = ScrollController();

  @override
  void didUpdateWidget(covariant _LogTail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_scroll.hasClients || _scroll.offset <= _lineHeight) return;
    // Scrolled back: keep the same lines in view as new ones arrive below.
    final old = oldWidget.lines, now = widget.lines;
    final added = now.length > old.length
        ? now.length - old.length
        : (now.isNotEmpty && old.isNotEmpty && now.last != old.last ? 1 : 0);
    if (added > 0) _scroll.jumpTo(_scroll.offset + added * _lineHeight);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('editor_build_log_tail'),
      height: 10 * _lineHeight + 12,
      padding: const EdgeInsets.fromLTRB(6, 6, 2, 6),
      decoration: BoxDecoration(
        color: EditorColors.background.withValues(alpha: 0.85),
        border: Border.all(color: EditorColors.border),
        borderRadius: BorderRadius.circular(3),
      ),
      child: RawScrollbar(
        controller: _scroll,
        thumbVisibility: true,
        thickness: 6,
        radius: const Radius.circular(3),
        thumbColor: EditorColors.mutedForeground.withValues(alpha: 0.5),
        child: ListView.builder(
          key: const Key('editor_build_log_list'),
          controller: _scroll,
          reverse: true,
          padding: const EdgeInsets.only(right: 10),
          itemCount: widget.lines.length,
          itemExtent: _lineHeight,
          itemBuilder: (_, i) => Text(widget.lines[widget.lines.length - 1 - i],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 10, height: 1.3, color: EditorColors.mutedForeground)),
        ),
      ),
    );
  }
}

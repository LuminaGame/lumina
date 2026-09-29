import 'dart:async';

import 'package:flutter/gestures.dart' show kPrimaryMouseButton;
import 'package:flutter/scheduler.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../../core/theme/editor_theme.dart';
import '../services/pie_controller.dart';
import '../services/pie_mouse_capture.dart';

/// Play's mouse capture on the game view, one child of the
/// viewport's Stack:
/// - the hint "Press F4 to show the mouse cursor", prominent when Play takes
///   the mouse and faded out after [hintDuration];
/// - once F4 gave the cursor back, a hint and a click target over the view:
///   a click takes the mouse again and is not passed to the editor (no
///   selection);
/// - while the backend holds the pointer, a window-wide shield in the root
///   overlay: the cursor is hidden wherever the held pointer sits (Wayland
///   holds it where it was, often on the toolbar's Play button), and clicks
///   there never press editor buttons.
class PieMouseCaptureLayer extends StatefulWidget {
  const PieMouseCaptureLayer({super.key, required this.pie, this.hintDuration = const Duration(seconds: 5)});

  final PieController pie;
  final Duration hintDuration;

  /// The capture hint, as the user asked for it.
  static const String captureHint = 'Press F4 to show the mouse cursor';

  /// The hint while the cursor is released.
  static const String releasedHint = 'Click the game view to capture the mouse · Esc stops Play';

  @override
  State<PieMouseCaptureLayer> createState() => _PieMouseCaptureLayerState();
}

class _PieMouseCaptureLayerState extends State<PieMouseCaptureLayer> {
  PieMouseCapture get _capture => widget.pie.mouseCapture;

  int _shownEpoch = 0;
  bool _hintVisible = false;
  Timer? _hintTimer;
  OverlayEntry? _shield;

  @override
  void initState() {
    super.initState();
    _attach(_capture);
  }

  @override
  void didUpdateWidget(covariant PieMouseCaptureLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.pie.mouseCapture, _capture)) {
      _detach(oldWidget.pie.mouseCapture);
      _attach(_capture);
    }
  }

  void _attach(PieMouseCapture capture) {
    capture.addListener(_onCaptureChanged);
    capture.centreProvider = _viewCentre;
    _refresh();
  }

  void _detach(PieMouseCapture capture) {
    capture.removeListener(_onCaptureChanged);
    if (capture.centreProvider == _viewCentre) capture.centreProvider = null;
  }

  /// The game view's centre in the Flutter view's coordinates.
  Offset? _viewCentre() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !box.attached) return null;
    return box.localToGlobal(box.size.center(Offset.zero));
  }

  void _onCaptureChanged() {
    if (!mounted) return;
    _refresh();
    // Listeners can fire from inside a build (the view model notifies); the
    // rebuild then waits for the frame.
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      setState(() {});
    }
  }

  /// Follows the capture: the hint for a new Play, the window shield.
  void _refresh() {
    final capture = _capture;
    if (capture.isSessionActive && capture.hintEpoch != _shownEpoch) {
      _shownEpoch = capture.hintEpoch;
      _hintVisible = true;
      _hintTimer?.cancel();
      _hintTimer = Timer(widget.hintDuration, () {
        if (mounted) setState(() => _hintVisible = false);
      });
    }
    if (!capture.isSessionActive) {
      _hintTimer?.cancel();
      _hintVisible = false;
    }
    _syncShield();
  }

  void _syncShield() {
    final wanted = _capture.holdsPointer;
    if (wanted == (_shield != null)) return;
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncShield();
      });
      return;
    }
    if (wanted) {
      final overlay = Overlay.maybeOf(context, rootOverlay: true);
      if (overlay == null) return;
      _shield = OverlayEntry(builder: (_) => _PointerShield(pie: widget.pie));
      overlay.insert(_shield!);
    } else {
      _shield!.remove();
      _shield!.dispose();
      _shield = null;
    }
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _detach(_capture);
    _shield?.remove();
    _shield?.dispose();
    _shield = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final capture = _capture;
    final showCaptureHint = capture.isSessionActive && _hintVisible && capture.isCaptured;
    final showReleasedHint = capture.isReleased;
    return Stack(
      children: [
        if (showReleasedHint)
          Positioned.fill(
            child: Listener(
              key: const ValueKey('pie_mouse_recapture_target'),
              behavior: HitTestBehavior.opaque,
              onPointerDown: (event) {
                if ((event.buttons & kPrimaryMouseButton) == 0) return;
                capture.recapture();
              },
              child: const MouseRegion(cursor: SystemMouseCursors.basic, child: SizedBox.expand()),
            ),
          ),
        Positioned(
          top: 44,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Center(
              child: AnimatedOpacity(
                key: const ValueKey('pie_mouse_capture_hint'),
                opacity: showCaptureHint ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 600),
                child: _HintChip(
                  text: PieMouseCaptureLayer.captureHint,
                  prominent: true,
                ),
              ),
            ),
          ),
        ),
        if (showReleasedHint)
          const Positioned(
            top: 44,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: _HintChip(
                  key: ValueKey('pie_mouse_released_hint'),
                  text: PieMouseCaptureLayer.releasedHint,
                  prominent: false,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _HintChip extends StatelessWidget {
  const _HintChip({super.key, required this.text, required this.prominent});

  final String text;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: prominent ? 18 : 12, vertical: prominent ? 9 : 6),
      decoration: BoxDecoration(
        color: EditorColors.hudSurface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: prominent ? EditorColors.primary : EditorColors.border),
        // Drop shadow under a HUD chip: an opacity, not a surface colour.
        boxShadow: const [BoxShadow(color: Color(0x8A000000), blurRadius: 10)],
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: prominent ? 15 : 11,
          fontWeight: prominent ? FontWeight.bold : FontWeight.w500,
          color: prominent ? EditorColors.foreground : EditorColors.mutedForeground,
          letterSpacing: prominent ? 0.4 : 0.2,
        ),
      ),
    );
  }
}

/// Covers the whole window while the pointer is held: no cursor, no clicks
/// reaching the editor, and — on a backend without relative motion — the
/// pointer's own deltas still turn the camera.
class _PointerShield extends StatelessWidget {
  const _PointerShield({required this.pie});

  final PieController pie;

  @override
  Widget build(BuildContext context) {
    // An OverlayEntry's child is not inside a Stack: the Overlay lays a
    // non-positioned entry out to fill itself, and a Positioned here throws
    // "Incorrect use of ParentDataWidget" on every frame.
    return MouseRegion(
      key: const ValueKey('pie_mouse_shield'),
      cursor: SystemMouseCursors.none,
      opaque: true,
      onHover: (event) => pie.injectPointerDelta(event.delta.dx, event.delta.dy),
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerMove: (event) => pie.injectPointerDelta(event.delta.dx, event.delta.dy),
        child: const SizedBox.expand(),
      ),
    );
  }
}

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_filament/flutter_filament.dart';

/// What [LuminaUiCapture] measured.
@immutable
class LuminaUiCaptureStats {
  const LuminaUiCaptureStats({
    this.captures = 0,
    this.skippedFrames = 0,
    this.lastWidth = 0,
    this.lastHeight = 0,
    this.lastReadbackMicros = 0,
    this.lastUploadMicros = 0,
    this.lastLatencyMicros = 0,
  });

  /// Pictures captured and uploaded.
  final int captures;

  /// Frames whose UI did not change (nothing captured).
  final int skippedFrames;

  /// The last picture's size in physical pixels.
  final int lastWidth;
  final int lastHeight;

  /// Rasterising the UI layer and reading it back (`toImageSync` +
  /// `toByteData`), wall time.
  final int lastReadbackMicros;

  /// Copying it into the overlay's texture (the UI thread's share).
  final int lastUploadMicros;

  /// From the frame that changed the UI to the picture handed to Filament:
  /// the UI is drawn by the frame after that at the earliest.
  final int lastLatencyMicros;

  @override
  String toString() => 'LuminaUiCaptureStats(captures: $captures, skipped: $skippedFrames, ${lastWidth}x$lastHeight, '
      'readback ${lastReadbackMicros / 1000} ms, upload ${lastUploadMicros / 1000} ms, latency ${lastLatencyMicros / 1000} ms)';
}

/// Renders [child] (a game's UI) offscreen for a [FilamentUiOverlay] when
/// the game presents directly: Filament blends the picture over every frame
/// it presents, so the UI keeps working as Flutter widgets (layout, input,
/// focus) while its pixels reach the screen through Filament.
///
/// The child is its own compositing layer; a picture is taken after a frame
/// that changed anything in it (the layer was added to the scene again, also
/// for a change deep inside a nested repaint boundary) or changed its size,
/// never for a frame where nothing changed. One capture runs at a time; a
/// change during it is captured right after. The picture is the child's
/// area at the device pixel ratio (`toImageSync` + `toByteData(rawRgba)`,
/// premultiplied), uploaded with [FilamentUiOverlay.upload].
///
/// With [overlay] null the child is painted normally and nothing is
/// captured.
class LuminaUiCapture extends SingleChildRenderObjectWidget {
  const LuminaUiCapture({super.key, required this.overlay, super.child});

  /// Where the pictures go; null captures nothing.
  final FilamentUiOverlay? overlay;

  /// The overlay of the game presenting directly right now (set by the game
  /// widget); what a [LuminaUiCaptureRoot] captures into.
  static final ValueNotifier<FilamentUiOverlay?> directOverlay = ValueNotifier(null);

  /// The latest measurements of the running capture.
  static final ValueNotifier<LuminaUiCaptureStats> stats = ValueNotifier(const LuminaUiCaptureStats());

  @override
  RenderLuminaUiCapture createRenderObject(BuildContext context) =>
      RenderLuminaUiCapture(overlay: overlay, devicePixelRatio: MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0);

  @override
  void updateRenderObject(BuildContext context, RenderLuminaUiCapture renderObject) {
    renderObject
      ..overlay = overlay
      ..devicePixelRatio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
  }
}

/// The render object of [LuminaUiCapture].
class RenderLuminaUiCapture extends RenderProxyBox {
  RenderLuminaUiCapture({FilamentUiOverlay? overlay, required double devicePixelRatio})
      // ignore: prefer_initializing_formals
      : _overlay = overlay,
        // ignore: prefer_initializing_formals
        _devicePixelRatio = devicePixelRatio;

  FilamentUiOverlay? _overlay;
  double _devicePixelRatio;
  bool _changed = true;
  bool _inFlight = false;
  bool _taking = false;
  bool _scheduled = false;
  int _changedAtMicros = 0;
  Size? _capturedSize;

  set overlay(FilamentUiOverlay? value) {
    if (identical(value, _overlay)) return;
    _overlay = value;
    _changed = true;
    _schedule();
  }

  set devicePixelRatio(double value) {
    if (value == _devicePixelRatio) return;
    _devicePixelRatio = value;
    _changed = true;
    _schedule();
  }

  @override
  bool get isRepaintBoundary => true;

  @override
  OffsetLayer updateCompositedLayer({required covariant OffsetLayer? oldLayer}) =>
      oldLayer ?? _ChangeTrackingLayer(_onLayerAdded);

  void _onLayerAdded() {
    // The capture's own scene adds the layer too; that is no change.
    if (_taking) return;
    if (!_changed) _changedAtMicros = DateTime.now().microsecondsSinceEpoch;
    _changed = true;
    _schedule();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _changed = true;
    _schedule();
  }

  void _schedule() {
    if (_scheduled || _overlay == null || !attached) return;
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      _captureIfChanged();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  void _captureIfChanged() {
    final overlay = _overlay;
    final layer = this.layer;
    if (overlay == null || !attached || layer is! OffsetLayer || !hasSize) return;
    if (_inFlight) {
      _schedule();
      return;
    }
    if (!_changed && _capturedSize == size) {
      final s = LuminaUiCapture.stats.value;
      LuminaUiCapture.stats.value = LuminaUiCaptureStats(
          captures: s.captures,
          skippedFrames: s.skippedFrames + 1,
          lastWidth: s.lastWidth,
          lastHeight: s.lastHeight,
          lastReadbackMicros: s.lastReadbackMicros,
          lastUploadMicros: s.lastUploadMicros,
          lastLatencyMicros: s.lastLatencyMicros);
      return;
    }
    _changed = false;
    _capturedSize = size;
    final changedAt = _changedAtMicros == 0 ? DateTime.now().microsecondsSinceEpoch : _changedAtMicros;
    _changedAtMicros = 0;
    final start = DateTime.now().microsecondsSinceEpoch;
    ui.Image image;
    _taking = true;
    try {
      image = layer.toImageSync(Offset.zero & size, pixelRatio: _devicePixelRatio);
    } finally {
      _taking = false;
    }
    _inFlight = true;
    unawaited(_upload(image, overlay, start, changedAt));
  }

  Future<void> _upload(ui.Image image, FilamentUiOverlay overlay, int start, int changedAt) async {
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final readback = DateTime.now().microsecondsSinceEpoch - start;
      if (bytes == null || !identical(overlay, _overlay)) return;
      final uploadStart = DateTime.now().microsecondsSinceEpoch;
      overlay.upload(bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes), image.width, image.height);
      final now = DateTime.now().microsecondsSinceEpoch;
      final s = LuminaUiCapture.stats.value;
      LuminaUiCapture.stats.value = LuminaUiCaptureStats(
        captures: s.captures + 1,
        skippedFrames: s.skippedFrames,
        lastWidth: image.width,
        lastHeight: image.height,
        lastReadbackMicros: readback,
        lastUploadMicros: now - uploadStart,
        lastLatencyMicros: now - changedAt,
      );
    } catch (e) {
      debugPrint('[LuminaUiCapture] capture failed: $e');
    } finally {
      image.dispose();
      _inFlight = false;
      if (_changed) _schedule();
    }
  }
}

/// The layer of [RenderLuminaUiCapture]: tells it whenever the compositor
/// adds it to a scene again, which happens only when something under it
/// changed (an unchanged layer is retained instead).
class _ChangeTrackingLayer extends OffsetLayer {
  _ChangeTrackingLayer(this._onAdded);

  final VoidCallback _onAdded;

  @override
  void addToScene(ui.SceneBuilder builder) {
    _onAdded();
    super.addToScene(builder);
  }
}

/// Captures the whole app for the game presenting directly
/// ([LuminaUiCapture.directOverlay]): everything Flutter draws in the window,
/// the game's UI and whatever the app puts around or over it (overlays,
/// popups, dialogs, a debug label), since the window shows Filament's frame
/// instead of Flutter's. A generated game wraps its app in one
/// (`runApp(const LuminaUiCaptureRoot(child: ...))`); without it the game
/// widget captures its own subtree only.
///
/// Whatever is opaque in the app covers the 3D view, so the app keeps the
/// area of the game transparent (the generated app's Scaffold has a
/// transparent background).
class LuminaUiCaptureRoot extends StatefulWidget {
  const LuminaUiCaptureRoot({super.key, required this.child});

  final Widget child;

  static int _mounted = 0;

  /// Whether a root capture is in the tree (the game widget then leaves the
  /// capture to it).
  static bool get isMounted => _mounted > 0;

  @override
  State<LuminaUiCaptureRoot> createState() => _LuminaUiCaptureRootState();
}

class _LuminaUiCaptureRootState extends State<LuminaUiCaptureRoot> {
  @override
  void initState() {
    super.initState();
    LuminaUiCaptureRoot._mounted++;
  }

  @override
  void dispose() {
    LuminaUiCaptureRoot._mounted--;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<FilamentUiOverlay?>(
        valueListenable: LuminaUiCapture.directOverlay,
        builder: (context, overlay, child) => LuminaUiCapture(overlay: overlay, child: child),
        child: widget.child,
      );
}

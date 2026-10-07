import 'dart:math' as math;

import 'package:lumina_editor_data/lumina_editor.dart' show LuminaUnits;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/services/camera_actor_view.dart';
import 'package:lumina_ui/ui/features/main_editor/services/editor_preferences.dart';
import 'package:lumina_ui/ui/features/main_editor/services/editor_view_layers.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/level_scene_view.dart';

/// The level viewport's camera preview: while exactly one camera actor is
/// selected (and no Play session runs), a picture-in-picture panel anchored
/// at the bottom-left of the 3D area shows what that camera sees — a second
/// view of the level's own scene through the camera's pose, projection,
/// clip planes and exposure, live while it is moved or edited, without the
/// editor's helpers.
///
/// The × hides it until the selection moves to another camera, or away and
/// back. The top-right corner (the one away from the anchor) resizes it,
/// keeping [CameraPreviewPanel.aspect]; the width is the user's
/// (`EditorPreferences.cameraPreviewWidth`). It covers [viewportSize] (the
/// level viewport's 3D area) but takes pointer events only on the panel, so
/// the rest of the view selects, drags the gizmo and navigates as before.
/// Hidden, it has no Filament view at all.
class CameraPreviewOverlay extends StatefulWidget {
  const CameraPreviewOverlay({super.key, required this.viewModel, required this.viewportSize, this.isPaused = false});

  final EditorViewModel viewModel;

  /// The level viewport's size, which bounds the panel.
  final Size viewportSize;

  /// The level viewport is not showing (another tab is in front).
  final bool isPaused;

  /// Gap between the panel and the 3D area's left edge.
  static const double margin = 8.0;

  /// The level viewport's bottom stats strip the panel sits above.
  static const double statsStripHeight = 22.0;

  /// Room left at the top for the viewport's header and quick controls.
  static const double topReserve = 40.0;

  /// The camera [vm]'s preview shows: the only selected actor when it is a
  /// camera, outside Play.
  static EditorActorNode? previewCameraOf(EditorViewModel vm) {
    if (vm.isPlaying || vm.selectedActorIds.length != 1) return null;
    final actor = vm.selectedActor;
    return actor != null && CameraActorView.isCamera(actor) ? actor : null;
  }

  @override
  State<CameraPreviewOverlay> createState() => CameraPreviewOverlayState();
}

class CameraPreviewOverlayState extends State<CameraPreviewOverlay> {
  /// The camera the preview was last offered for, and the one the user closed
  /// it on.
  String? _lastCameraId;
  String? _dismissedId;

  /// The width while the corner is being dragged (saved when it ends).
  double? _dragWidth;
  double _dragStartWidth = 0;
  Offset _dragDelta = Offset.zero;

  EditorPreferences get _prefs => widget.viewModel.editorPreferences;

  /// The camera shown, or null while the panel is hidden.
  EditorActorNode? get shownCamera {
    final camera = CameraPreviewOverlay.previewCameraOf(widget.viewModel);
    return camera != null && camera.id != _dismissedId ? camera : null;
  }

  /// The panel's width now, logical pixels (within the limits and the 3D
  /// area); its view is that wide and [CameraPreviewPanel.aspect] tall.
  double get panelWidth => _fit(_dragWidth ?? _prefs.cameraPreviewWidth);

  /// Hides the panel until another camera is selected.
  void close() => setState(() => _dismissedId = _lastCameraId);

  /// The widest panel [CameraPreviewOverlay.viewportSize] holds, never above
  /// the preference's maximum.
  double get maxWidth {
    final size = widget.viewportSize;
    var max = EditorPreferences.maxCameraPreviewWidth;
    if (size.width > 0 && size.height > 0) {
      final byWidth = size.width - 2 * CameraPreviewOverlay.margin;
      final byHeight = (size.height -
              CameraPreviewOverlay.statsStripHeight -
              CameraPreviewOverlay.margin -
              CameraPreviewOverlay.topReserve -
              CameraPreviewPanel.titleBarHeight) *
          CameraPreviewPanel.aspect;
      max = [max, byWidth, byHeight].reduce((a, b) => a < b ? a : b);
    }
    return max;
  }

  double _fit(double width) {
    final upper = maxWidth;
    final lower = EditorPreferences.minCameraPreviewWidth;
    if (upper <= lower) return upper > 0 ? upper : lower;
    return width.clamp(lower, upper);
  }

  void _onResizeStart(DragStartDetails _) {
    _dragStartWidth = panelWidth;
    _dragDelta = Offset.zero;
    setState(() => _dragWidth = _dragStartWidth);
  }

  /// Right and up grow the panel (it is anchored at its bottom-left); the
  /// axis dragged further decides, so the aspect holds.
  void _onResizeUpdate(DragUpdateDetails d) {
    _dragDelta += d.delta;
    final byX = _dragDelta.dx;
    final byY = -_dragDelta.dy * CameraPreviewPanel.aspect;
    final grow = byX.abs() >= byY.abs() ? byX : byY;
    setState(() => _dragWidth = _fit(_dragStartWidth + grow));
  }

  void _onResizeEnd() {
    final width = _dragWidth;
    if (width == null) return;
    _prefs.setCameraPreviewWidth(width);
    setState(() => _dragWidth = null);
  }

  @override
  Widget build(BuildContext context) {
    final candidate = CameraPreviewOverlay.previewCameraOf(widget.viewModel);
    if (candidate?.id != _lastCameraId) {
      // Another camera (or none): a closed preview opens again for the next.
      _lastCameraId = candidate?.id;
      _dismissedId = null;
    }
    final camera = shownCamera;
    if (camera == null) return const SizedBox.shrink();
    final width = panelWidth;
    return Stack(
      children: [
        Positioned(
          left: CameraPreviewOverlay.margin,
          bottom: CameraPreviewOverlay.statsStripHeight + CameraPreviewOverlay.margin,
          child: CameraPreviewPanel(
            key: const ValueKey('camera_preview_panel'),
            viewModel: widget.viewModel,
            camera: camera,
            width: width,
            isPaused: widget.isPaused,
            onClose: close,
            onResizeStart: _onResizeStart,
            onResizeUpdate: _onResizeUpdate,
            onResizeEnd: _onResizeEnd,
          ),
        ),
      ],
    );
  }
}

/// The preview panel itself: the camera's name and a close button over a
/// view of the level through the camera, with a resize grip at the top-right
/// corner.
class CameraPreviewPanel extends StatelessWidget {
  const CameraPreviewPanel({
    super.key,
    required this.viewModel,
    required this.camera,
    required this.width,
    required this.onClose,
    required this.onResizeStart,
    required this.onResizeUpdate,
    required this.onResizeEnd,
    this.isPaused = false,
  });

  final EditorViewModel viewModel;
  final EditorActorNode camera;

  /// The view's width; its height is `width / aspect`.
  final double width;
  final bool isPaused;
  final VoidCallback onClose;
  final GestureDragStartCallback onResizeStart;
  final GestureDragUpdateCallback onResizeUpdate;
  final VoidCallback onResizeEnd;

  /// The picture's width / height. A camera has no aspect setting yet; its
  /// vertical field of view is kept, so the vertical framing is the one Play
  /// shows at any window shape.
  static const double aspect = 16 / 9;

  static const double titleBarHeight = 22.0;
  static const double gripSize = 14.0;

  /// The preview's view of the level through [camera] (the level viewport's
  /// metered exposure when the camera meters automatically).
  void _aim(LevelSceneViewState view) {
    final target = view.camera;
    if (target == null) return;
    final far = CameraActorView.apply(target, camera, aspect: view.aspect, metered: view.drawn?.camera);
    view.view?.setDynamicLightingOptions(LuminaUnits.dynamicLightingNear, math.max(LuminaUnits.dynamicLightingFar, far));
  }

  @override
  Widget build(BuildContext context) {
    final viewHeight = width / aspect;
    // Opaque: a press on the panel never reaches the level view behind it
    // (no selection, no marquee, no camera navigation).
    return Listener(
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: width,
        height: titleBarHeight + viewHeight,
        decoration: BoxDecoration(
          color: EditorColors.hudSurfaceStrong,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: EditorColors.borderSolid),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Column(
              children: [
                SizedBox(
                  height: titleBarHeight,
                  child: Row(
                    children: [
                      const SizedBox(width: 6),
                      const Icon(LucideIcons.video, size: 11, color: Colors.amber),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          camera.name,
                          key: const ValueKey('camera_preview_title'),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.foreground),
                        ),
                      ),
                      // Leaves the corner to the resize grip.
                      GhostButton(
                        key: const ValueKey('camera_preview_close'),
                        density: ButtonDensity.icon,
                        onPressed: onClose,
                        child: const Icon(LucideIcons.x, size: 11, color: EditorColors.mutedForeground),
                      ),
                      const SizedBox(width: gripSize),
                    ],
                  ),
                ),
                SizedBox(
                  width: width,
                  height: viewHeight,
                  child: LevelSceneView(
                    key: const ValueKey('camera_preview_view'),
                    filamentKey: const ValueKey('camera_preview_filament'),
                    editorViewModel: viewModel,
                    debugLabel: 'Camera preview',
                    visibleLayers: EditorViewLayers.cameraView,
                    isPaused: isPaused,
                    onAim: _aim,
                    placeholder: const Text('The level viewport is not running.',
                        style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
                  ),
                ),
              ],
            ),
            Positioned(
              top: 0,
              right: 0,
              width: gripSize,
              height: gripSize,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeUpRight,
                child: GestureDetector(
                  key: const ValueKey('camera_preview_resize'),
                  behavior: HitTestBehavior.opaque,
                  onPanStart: onResizeStart,
                  onPanUpdate: onResizeUpdate,
                  onPanEnd: (_) => onResizeEnd(),
                  onPanCancel: onResizeEnd,
                  child: const CustomPaint(painter: _CornerGripPainter()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Three diagonal strokes in the top-right corner.
class _CornerGripPainter extends CustomPainter {
  const _CornerGripPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = EditorColors.mutedForeground
      ..strokeWidth = 1.0;
    for (var i = 1; i <= 3; i++) {
      final d = i * size.width / 4;
      canvas.drawLine(Offset(size.width - d, 1), Offset(size.width - 1, d), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CornerGripPainter oldDelegate) => false;
}

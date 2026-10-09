import 'dart:ui';

/// The game's render space inside the area that shows it: where the picture
/// is drawn, how many pixels the view renders (what `Get Viewport Size`
/// reports and what `Get Mouse Position`, `Project World to Screen` and
/// `Deproject Screen to World` use), and the size the game's UI is laid out
/// at.
///
/// Without a chosen resolution the picture fills [space] and the view
/// renders [space] × [devicePixelRatio] pixels ([physicalPixels]) or
/// [space] logical pixels. With one (borderless fullscreen at
/// `Set Screen Resolution`), the view renders [renderResolution] pixels and
/// the picture is the largest box of its aspect ratio, centred, with black
/// bars; the UI is laid out at the chosen resolution's logical size and
/// scaled with the picture, so it looks as it would in a window of that
/// resolution.
///
/// Resolution Scale and the FSR3 / DLSS upscalers render inside the view at
/// a lower internal size; none of that shows here: positions are always in
/// the view's output pixels.
class LuminaRenderSpace {
  const LuminaRenderSpace({
    required this.space,
    this.renderResolution,
    this.devicePixelRatio = 1.0,
    this.physicalPixels = true,
  });

  /// The logical size of the area showing the game (the window).
  final Size space;

  /// The chosen resolution the view renders at, in pixels; null renders the
  /// space's own size.
  final (int, int)? renderResolution;

  final double devicePixelRatio;

  /// Whether the view renders physical pixels without a chosen resolution
  /// (`FilamentWidget.physicalResolution`, what a game screen does).
  final bool physicalPixels;

  (int, int)? get _render {
    final r = renderResolution;
    return r == null || r.$1 <= 0 || r.$2 <= 0 ? null : r;
  }

  /// Where the picture is drawn, in [space]'s logical coordinates.
  Rect get rect {
    final r = _render;
    if (r == null || !space.isFinite) return Offset.zero & space;
    final sx = space.width / r.$1;
    final sy = space.height / r.$2;
    final scale = sx < sy ? sx : sy;
    final size = Size(r.$1 * scale, r.$2 * scale);
    return Offset((space.width - size.width) / 2, (space.height - size.height) / 2) & size;
  }

  /// The view's size in pixels.
  Size get viewportPixels {
    final r = _render;
    if (r != null) return Size(r.$1.toDouble(), r.$2.toDouble());
    final ratio = physicalPixels ? devicePixelRatio : 1.0;
    return Size((space.width * ratio).roundToDouble(), (space.height * ratio).roundToDouble());
  }

  /// The logical size the game's UI is laid out at before it is scaled to
  /// [rect]: the chosen resolution in logical pixels, else [space].
  Size get layoutSize {
    final r = _render;
    if (r == null) return space;
    return Size(r.$1 / devicePixelRatio, r.$2 / devicePixelRatio);
  }

  /// View pixels per logical pixel of [space].
  Offset get _pixelsPerLogical {
    final box = rect;
    final px = viewportPixels;
    return Offset(box.width == 0 ? 0 : px.width / box.width, box.height == 0 ? 0 : px.height / box.height);
  }

  /// [local] (in [space]) in view pixels; null on the black bars.
  Offset? toViewport(Offset local) {
    final box = rect;
    if (local.dx < box.left || local.dy < box.top || local.dx > box.right || local.dy > box.bottom) return null;
    return _map(local, box);
  }

  /// [local] in view pixels, a position on the bars clamped to the
  /// picture's nearest edge.
  Offset clampToViewport(Offset local) {
    final box = rect;
    final clamped = Offset(local.dx.clamp(box.left, box.right), local.dy.clamp(box.top, box.bottom));
    return _map(clamped, box);
  }

  /// A view pixel back in [space]'s logical coordinates.
  Offset fromViewport(Offset pixels) {
    final box = rect;
    final k = _pixelsPerLogical;
    return Offset(box.left + (k.dx == 0 ? 0 : pixels.dx / k.dx), box.top + (k.dy == 0 ? 0 : pixels.dy / k.dy));
  }

  Offset _map(Offset local, Rect box) {
    final k = _pixelsPerLogical;
    return Offset((local.dx - box.left) * k.dx, (local.dy - box.top) * k.dy);
  }

  @override
  bool operator ==(Object other) =>
      other is LuminaRenderSpace &&
      other.space == space &&
      other.renderResolution == renderResolution &&
      other.devicePixelRatio == devicePixelRatio &&
      other.physicalPixels == physicalPixels;

  @override
  int get hashCode => Object.hash(space, renderResolution, devicePixelRatio, physicalPixels);

  @override
  String toString() => 'LuminaRenderSpace(${space.width}x${space.height}, render: $renderResolution, dpr: $devicePixelRatio)';
}

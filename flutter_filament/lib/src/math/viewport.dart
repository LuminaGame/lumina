/// An immutable 2D viewport definition using Filament / OpenGL's **bottom-left origin** coordinate system.
class Viewport {
  /// The X-coordinate of the bottom-left corner (in physical pixels).
  final int left;

  /// The Y-coordinate of the bottom-left corner (in physical pixels).
  final int bottom;

  /// The width of the viewport (in physical pixels).
  final int width;

  /// The height of the viewport (in physical pixels).
  final int height;

  const Viewport({
    this.left = 0,
    this.bottom = 0,
    required this.width,
    required this.height,
  });

  /// Constructs a [Viewport] from a top-left origin Flutter rectangle.
  ///
  /// Converts top-left coordinates to Filament's bottom-left convention:
  /// `bottom = surfaceHeight - (top + height)`
  /// and scales by [devicePixelRatio].
  factory Viewport.fromFlutterRect({
    required double left,
    required double top,
    required double width,
    required double height,
    required double surfaceHeight,
    double devicePixelRatio = 1.0,
  }) {
    final pLeft = (left * devicePixelRatio).round();
    final pTop = (top * devicePixelRatio).round();
    final pWidth = (width * devicePixelRatio).round();
    final pHeight = (height * devicePixelRatio).round();
    final pSurfaceHeight = (surfaceHeight * devicePixelRatio).round();
    final pBottom = pSurfaceHeight - (pTop + pHeight);

    return Viewport(
      left: pLeft,
      bottom: pBottom,
      width: pWidth,
      height: pHeight,
    );
  }

  /// Converts this viewport's bottom-left origin back to Flutter's top-left coordinates.
  ({double left, double top}) toFlutterTopLeft({
    required double surfaceHeight,
    double devicePixelRatio = 1.0,
  }) {
    final pSurfaceHeight = surfaceHeight * devicePixelRatio;
    final pTop = pSurfaceHeight - (bottom + height);
    return (
      left: left / devicePixelRatio,
      top: pTop / devicePixelRatio,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Viewport &&
          runtimeType == other.runtimeType &&
          left == other.left &&
          bottom == other.bottom &&
          width == other.width &&
          height == other.height;

  @override
  int get hashCode => Object.hash(left, bottom, width, height);

  @override
  String toString() => 'Viewport(left: $left, bottom: $bottom, width: $width, height: $height)';
}

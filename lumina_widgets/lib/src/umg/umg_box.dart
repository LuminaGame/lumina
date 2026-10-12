import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A UMG Horizontal Box ([Axis.horizontal]) or Vertical Box
/// ([Axis.vertical]): a [Flex] that fills its main axis and stretches its
/// children across the cross axis.
///
/// When the parent leaves the cross axis unbounded (a Horizontal Box inside
/// a Vertical Box or a vertical Scroll Box, a Vertical Box inside a
/// Horizontal Box or a horizontal Scroll Box), the box first measures its
/// children and then stretches them to the largest one: it is as tall
/// (wide) as its content instead of failing layout with an infinite
/// cross extent. Children aligned with an [Align] keep that alignment
/// within the measured extent.
///
/// The UMG designer, the editor's runtime preview and generated widget code
/// all build box panels with it.
class LuminaUmgBox extends Flex {
  const LuminaUmgBox({super.key, required super.direction, super.children})
      : super(mainAxisSize: MainAxisSize.max, crossAxisAlignment: CrossAxisAlignment.stretch);

  @override
  RenderFlex createRenderObject(BuildContext context) => RenderLuminaUmgBox(
        direction: direction,
        mainAxisAlignment: mainAxisAlignment,
        mainAxisSize: mainAxisSize,
        crossAxisAlignment: crossAxisAlignment,
        textDirection: getEffectiveTextDirection(context),
        verticalDirection: verticalDirection,
        textBaseline: textBaseline,
        clipBehavior: clipBehavior,
        spacing: spacing,
      );
}

/// The render object of [LuminaUmgBox]: a [RenderFlex] that, with a
/// stretching cross axis the parent leaves unbounded, lays out twice: once
/// centred to measure the children's largest cross extent, then stretched to
/// exactly that extent.
class RenderLuminaUmgBox extends RenderFlex {
  RenderLuminaUmgBox({
    super.direction,
    super.mainAxisAlignment,
    super.mainAxisSize,
    super.crossAxisAlignment,
    super.textDirection,
    super.verticalDirection,
    super.textBaseline,
    super.clipBehavior,
    super.spacing,
  });

  /// True while the first (measuring) pass runs.
  bool _measuring = false;

  /// The cross-tightened constraints of the second pass, if one runs.
  BoxConstraints? _stretchedTo;

  @override
  CrossAxisAlignment get crossAxisAlignment => _measuring ? CrossAxisAlignment.center : super.crossAxisAlignment;

  @override
  BoxConstraints get constraints => _stretchedTo ?? super.constraints;

  bool _sizesToContent(BoxConstraints c) =>
      super.crossAxisAlignment == CrossAxisAlignment.stretch &&
      (direction == Axis.horizontal ? !c.hasBoundedHeight : !c.hasBoundedWidth);

  /// [c] with the cross axis fixed at the [measured] extent.
  BoxConstraints _tightCross(BoxConstraints c, Size measured) => direction == Axis.horizontal
      ? c.copyWith(minHeight: measured.height, maxHeight: measured.height)
      : c.copyWith(minWidth: measured.width, maxWidth: measured.width);

  Size _measure(Size Function() layout) {
    _measuring = true;
    try {
      return layout();
    } finally {
      _measuring = false;
    }
  }

  @override
  void performLayout() {
    final incoming = super.constraints;
    if (!_sizesToContent(incoming)) {
      super.performLayout();
      return;
    }
    final measured = _measure(() {
      super.performLayout();
      return size;
    });
    _stretchedTo = _tightCross(incoming, measured);
    try {
      super.performLayout();
    } finally {
      _stretchedTo = null;
    }
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    if (!_sizesToContent(constraints)) return super.computeDryLayout(constraints);
    final measured = _measure(() => super.computeDryLayout(constraints));
    return super.computeDryLayout(_tightCross(constraints, measured));
  }

  @override
  double? computeDryBaseline(covariant BoxConstraints constraints, TextBaseline baseline) {
    if (!_sizesToContent(constraints)) return super.computeDryBaseline(constraints, baseline);
    final measured = _measure(() => super.computeDryLayout(constraints));
    return super.computeDryBaseline(_tightCross(constraints, measured), baseline);
  }
}

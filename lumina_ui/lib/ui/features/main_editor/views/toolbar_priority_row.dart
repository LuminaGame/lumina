import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// The level toolbar's layout: three children, [leading],
/// [middle] and [trailing], in a row of fixed height.
///
/// - [trailing] (plugin end-slot buttons, Quality) always gets its full width.
/// - [leading] (the tool groups) gets its natural width when it fits beside
///   [trailing]; otherwise whatever is left (it scrolls).
/// - [middle] (the frame stats) gets the rest and gives way first; it is
///   laid out tight, so a text with an ellipsis truncates.
class ToolbarPriorityRow extends MultiChildRenderObjectWidget {
  ToolbarPriorityRow({super.key, required Widget leading, required Widget middle, required Widget trailing, this.gap = 12})
      : super(children: [leading, middle, trailing]);

  /// The space after [leading] and after [middle].
  final double gap;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderToolbarPriorityRow(gap);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) => (renderObject as _RenderToolbarPriorityRow).gap = gap;
}

class _ToolbarSlot extends ContainerBoxParentData<RenderBox> {}

class _RenderToolbarPriorityRow extends RenderBox
    with ContainerRenderObjectMixin<RenderBox, _ToolbarSlot>, RenderBoxContainerDefaultsMixin<RenderBox, _ToolbarSlot> {
  _RenderToolbarPriorityRow(this._gap);

  double _gap;
  set gap(double v) {
    if (v == _gap) return;
    _gap = v;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _ToolbarSlot) child.parentData = _ToolbarSlot();
  }

  List<RenderBox> get _children {
    final out = <RenderBox>[];
    var c = firstChild;
    while (c != null) {
      out.add(c);
      c = childAfter(c);
    }
    return out;
  }

  @override
  double computeMinIntrinsicHeight(double width) => _children.fold(0.0, (m, c) => math.max(m, c.getMinIntrinsicHeight(width)));

  @override
  double computeMaxIntrinsicHeight(double width) => _children.fold(0.0, (m, c) => math.max(m, c.getMaxIntrinsicHeight(width)));

  @override
  void performLayout() {
    final kids = _children;
    final width = constraints.maxWidth;
    final height = constraints.hasBoundedHeight ? constraints.maxHeight : kids.fold(0.0, (m, c) => math.max(m, c.getMaxIntrinsicHeight(double.infinity)));
    final leading = kids[0], middle = kids[1], trailing = kids[2];

    trailing.layout(BoxConstraints(maxWidth: width, minHeight: 0, maxHeight: height), parentUsesSize: true);
    final room = math.max(0.0, width - trailing.size.width);
    // The leading child takes its own width up to all the room (a scroll
    // view sizes to its content); loose widths also mean a child that grows
    // (a slot button gaining a label) lays this row out again.
    leading.layout(BoxConstraints(maxWidth: math.max(0.0, room - _gap), minHeight: height, maxHeight: height), parentUsesSize: true);
    // The middle gets what is left (its text ends with an ellipsis).
    final middleRoom = math.max(0.0, room - leading.size.width - 2 * _gap);
    middle.layout(BoxConstraints(maxWidth: middleRoom, minHeight: height, maxHeight: height), parentUsesSize: true);

    (leading.parentData! as _ToolbarSlot).offset = Offset(0, (height - leading.size.height) / 2);
    // The middle sits right before the trailing block, as the stats did.
    (middle.parentData! as _ToolbarSlot).offset = Offset(width - trailing.size.width - _gap - middle.size.width, (height - middle.size.height) / 2);
    (trailing.parentData! as _ToolbarSlot).offset = Offset(width - trailing.size.width, (height - trailing.size.height) / 2);
    size = constraints.constrain(Size(width, height));
  }

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) => defaultHitTestChildren(result, position: position);
}

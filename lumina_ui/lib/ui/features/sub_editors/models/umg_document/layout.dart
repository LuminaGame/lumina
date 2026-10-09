import 'dart:math' as math;
import 'dart:ui';

import 'package:lumina_ui/ui/features/sub_editors/models/umg_document/node.dart';

/// Anchor presets of the 3×3 + stretch matrix.
enum UmgAnchorPreset {
  topLeft(Offset(0, 0), Offset(0, 0)),
  topCenter(Offset(0.5, 0), Offset(0.5, 0)),
  topRight(Offset(1, 0), Offset(1, 0)),
  centerLeft(Offset(0, 0.5), Offset(0, 0.5)),
  center(Offset(0.5, 0.5), Offset(0.5, 0.5)),
  centerRight(Offset(1, 0.5), Offset(1, 0.5)),
  bottomLeft(Offset(0, 1), Offset(0, 1)),
  bottomCenter(Offset(0.5, 1), Offset(0.5, 1)),
  bottomRight(Offset(1, 1), Offset(1, 1)),
  stretchTop(Offset(0, 0), Offset(1, 0)),
  stretchMiddle(Offset(0, 0.5), Offset(1, 0.5)),
  stretchBottom(Offset(0, 1), Offset(1, 1)),
  stretchLeft(Offset(0, 0), Offset(0, 1)),
  stretchCenter(Offset(0.5, 0), Offset(0.5, 1)),
  stretchRight(Offset(1, 0), Offset(1, 1)),
  fullStretch(Offset(0, 0), Offset(1, 1));

  const UmgAnchorPreset(this.min, this.max);
  final Offset min;
  final Offset max;

  /// Alignment that keeps the pivot on the anchored corner/edge.
  Offset get alignment => Offset(min.dx == max.dx ? min.dx : 0, min.dy == max.dy ? min.dy : 0);

  String get label {
    switch (this) {
      case UmgAnchorPreset.topLeft:
        return 'Top-Left';
      case UmgAnchorPreset.topCenter:
        return 'Top-Center';
      case UmgAnchorPreset.topRight:
        return 'Top-Right';
      case UmgAnchorPreset.centerLeft:
        return 'Center-Left';
      case UmgAnchorPreset.center:
        return 'Center';
      case UmgAnchorPreset.centerRight:
        return 'Center-Right';
      case UmgAnchorPreset.bottomLeft:
        return 'Bottom-Left';
      case UmgAnchorPreset.bottomCenter:
        return 'Bottom-Center';
      case UmgAnchorPreset.bottomRight:
        return 'Bottom-Right';
      case UmgAnchorPreset.stretchTop:
        return 'Stretch Top';
      case UmgAnchorPreset.stretchMiddle:
        return 'Stretch Middle';
      case UmgAnchorPreset.stretchBottom:
        return 'Stretch Bottom';
      case UmgAnchorPreset.stretchLeft:
        return 'Stretch Left';
      case UmgAnchorPreset.stretchCenter:
        return 'Stretch Center';
      case UmgAnchorPreset.stretchRight:
        return 'Stretch Right';
      case UmgAnchorPreset.fullStretch:
        return 'Full Stretch';
    }
  }
}

/// Screen Resolution Simulator entries.
class UmgResolution {
  final String label;
  final int width;
  final int height;
  final bool isCustom;

  const UmgResolution(this.label, this.width, this.height, {this.isCustom = false});

  static const List<UmgResolution> presets = [
    UmgResolution('1920x1080 Full HD', 1920, 1080),
    UmgResolution('2560x1440 2K', 2560, 1440),
    UmgResolution('3840x2160 4K UHD', 3840, 2160),
    UmgResolution('Mobile iPhone 15 Pro (393x852)', 393, 852),
  ];

  UmgResolution copyWith({int? width, int? height}) =>
      UmgResolution('Custom ${width ?? this.width}x${height ?? this.height}', width ?? this.width, height ?? this.height, isCustom: true);

  String get key => '${width}x$height';

  @override
  bool operator ==(Object other) => other is UmgResolution && other.width == width && other.height == height && other.isCustom == isCustom;

  @override
  int get hashCode => Object.hash(width, height, isCustom);
}

/// Canvas-slot layout math shared by the designer canvas, the inspector and
/// (as emitted source) the generated widget. Semantics: when an axis is
/// not stretched, `position` is the pivot offset from the anchor point and
/// `size` the extent; when stretched, `position` is the near margin and
/// `size` the far margin.
class UmgLayout {
  static Rect resolveCanvasRect(UmgSlot slot, Size parent) {
    final w = parent.width;
    final h = parent.height;
    double left;
    double width;
    if (slot.anchorMin.dx == slot.anchorMax.dx) {
      width = slot.size.width;
      left = slot.anchorMin.dx * w + slot.position.dx - slot.alignment.dx * width;
    } else {
      left = slot.anchorMin.dx * w + slot.position.dx;
      final right = slot.anchorMax.dx * w - slot.size.width;
      width = math.max(0, right - left);
    }
    double top;
    double height;
    if (slot.anchorMin.dy == slot.anchorMax.dy) {
      height = slot.size.height;
      top = slot.anchorMin.dy * h + slot.position.dy - slot.alignment.dy * height;
    } else {
      top = slot.anchorMin.dy * h + slot.position.dy;
      final bottom = slot.anchorMax.dy * h - slot.size.height;
      height = math.max(0, bottom - top);
    }
    return Rect.fromLTWH(left, top, width, height);
  }

  /// Rewrites `position`/`size` of [slot] so that it resolves to [rect] at
  /// [parent] with its current anchors/alignment.
  static void fitSlotToRect(UmgSlot slot, Rect rect, Size parent) {
    final w = parent.width;
    final h = parent.height;
    double px;
    double sx;
    if (slot.anchorMin.dx == slot.anchorMax.dx) {
      sx = rect.width;
      px = rect.left + slot.alignment.dx * rect.width - slot.anchorMin.dx * w;
    } else {
      px = rect.left - slot.anchorMin.dx * w;
      sx = slot.anchorMax.dx * w - rect.right;
    }
    double py;
    double sy;
    if (slot.anchorMin.dy == slot.anchorMax.dy) {
      sy = rect.height;
      py = rect.top + slot.alignment.dy * rect.height - slot.anchorMin.dy * h;
    } else {
      py = rect.top - slot.anchorMin.dy * h;
      sy = slot.anchorMax.dy * h - rect.bottom;
    }
    slot.position = Offset(px, py);
    slot.size = Size(sx, sy);
  }

  /// Applies [preset] to [slot] keeping its resolved rect at [parent] unchanged.
  static void applyPreset(UmgSlot slot, UmgAnchorPreset preset, Size parent) {
    final rect = resolveCanvasRect(slot, parent);
    slot.anchorMin = preset.min;
    slot.anchorMax = preset.max;
    slot.alignment = preset.alignment;
    fitSlotToRect(slot, rect, parent);
  }

  static double snap(double v, double grid) => grid <= 0 ? v : (v / grid).roundToDouble() * grid;
}

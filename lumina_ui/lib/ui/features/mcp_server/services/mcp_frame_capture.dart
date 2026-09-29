import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A captured frame: PNG bytes and their size in pixels.
typedef McpFrame = ({Uint8List png, int width, int height});

/// Captures the composited frame of a keyed [RepaintBoundary] as a PNG:
/// what the user sees, Filament texture included, the way
/// the smoke recorder captures it. A frame wider than [maxWidth] is
/// rendered at a lower pixel ratio so the base64 stays small.
abstract final class McpFrameCapture {
  static Future<McpFrame> capture(GlobalKey key, {int maxWidth = 1280, String what = 'viewport'}) async {
    var render = key.currentContext?.findRenderObject();
    if (render is! RenderRepaintBoundary || !render.attached) {
      throw StateError('The $what is not shown: open the level tab (select_tab 0 / close sub-editor tabs) and try again.');
    }
    if (render.debugNeedsPaint) {
      // A change the agent just made is not painted yet: ask for a frame.
      final binding = WidgetsBinding.instance;
      binding.scheduleFrame();
      await binding.endOfFrame.timeout(const Duration(seconds: 2), onTimeout: () {});
      render = key.currentContext?.findRenderObject();
      if (render is! RenderRepaintBoundary || !render.attached) {
        throw StateError('The $what went away while a frame was awaited.');
      }
      if (render.debugNeedsPaint) {
        throw StateError('The $what has no painted frame yet; try again after the editor has drawn.');
      }
    }
    final size = render.size;
    if (size.isEmpty) throw StateError('The $what has no size.');
    final ratio = size.width > maxWidth ? maxWidth / size.width : 1.0;
    final image = await render.toImage(pixelRatio: ratio);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('The $what frame could not be encoded as PNG.');
      return (png: data.buffer.asUint8List(), width: image.width, height: image.height);
    } finally {
      image.dispose();
    }
  }
}

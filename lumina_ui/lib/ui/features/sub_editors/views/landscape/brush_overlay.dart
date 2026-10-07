import 'dart:math' as math;

import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_editor_data/lumina_editor.dart' show LandscapeData;
import 'package:lumina_ui/ui/features/sub_editors/view_models/landscape_editor_view_model.dart';

/// Interactive terrain map drawn over the viewport: the overview.
///
/// The map is the heightmap itself (real samples, colour-ramped from the
/// terrain's own min/max), with the tile seams, every foliage instance and the
/// active brush's ring — inner circle = full strength, outer circle = falloff
/// edge — under the cursor. The 3D viewport shows the same brush draped on the
/// terrain and is where one normally paints; the map
/// stays because it shows the whole terrain, its tiles and every instance at
/// once, which a perspective view cannot. Dragging on it sculpts or paints at
/// the exact world position through the same view-model calls.
class LandscapeBrushOverlay extends StatelessWidget {
  final LandscapeEditorViewModel viewModel;
  final double size;

  const LandscapeBrushOverlay({super.key, required this.viewModel, this.size = 240});

  @override
  Widget build(BuildContext context) {
    final vm = viewModel;
    final data = vm.data;

    double toWorldX(double px) => (px / size - 0.5) * data.worldSize;
    double toWorldZ(double py) => (py / size - 0.5) * data.worldSize;

    void pointerDown(Offset local) {
      final x = toWorldX(local.dx);
      final z = toWorldZ(local.dy);
      vm.setCursor(x, z);
      if (vm.tab == LandscapeEditorTab.foliage) {
        vm.beginFoliageStroke(x, z, erase: vm.paintMode == FoliagePaintMode.erase);
      } else {
        vm.beginStroke(x, z);
      }
    }

    void pointerMove(Offset local) {
      final x = toWorldX(local.dx);
      final z = toWorldZ(local.dy);
      vm.setCursor(x, z);
      if (vm.tab == LandscapeEditorTab.foliage) {
        vm.foliageStrokeTo(x, z);
      } else {
        vm.strokeTo(x, z);
      }
    }

    void pointerUp() {
      if (vm.tab == LandscapeEditorTab.foliage) {
        vm.endFoliageStroke();
      } else {
        vm.endStroke();
      }
    }

    final foliage = vm.tab == LandscapeEditorTab.foliage;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: EditorColors.border),
        borderRadius: BorderRadius.circular(4),
        color: Colors.black.withValues(alpha: 0.55),
      ),
      padding: const EdgeInsets.all(4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            vm.tab == LandscapeEditorTab.foliage ? 'FOLIAGE MAP (drag to place)' : 'SCULPT MAP (drag to sculpt)',
            style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: EditorColors.mutedForeground),
          ),
          const SizedBox(height: 4),
          MouseRegion(
            onHover: (e) => vm.setCursor(toWorldX(e.localPosition.dx), toWorldZ(e.localPosition.dy)),
            onExit: (_) => vm.setCursor(null, null),
            child: GestureDetector(
              key: const ValueKey('landscape_brush_map'),
              behavior: HitTestBehavior.opaque,
              // onTapUp (not onTapDown): during a drag the pan recognizer
              // wins the arena, so a stroke is never double-stamped.
              onTapUp: (d) {
                pointerDown(d.localPosition);
                pointerUp();
              },
              onPanStart: (d) => pointerDown(d.localPosition),
              onPanUpdate: (d) => pointerMove(d.localPosition),
              onPanEnd: (_) => pointerUp(),
              child: CustomPaint(
                size: Size(size, size),
                painter: _LandscapeMapPainter(
                  data: data,
                  sectionsPerSide: vm.sectionMap.sectionsPerSide,
                  cursorX: vm.cursorWorldX,
                  cursorZ: vm.cursorWorldZ,
                  radius: foliage ? vm.foliageBrushRadius : vm.brushRadius,
                  falloff: foliage ? vm.foliageBrushFalloff : vm.brushFalloff,
                  eraseMode: vm.tab == LandscapeEditorTab.foliage && vm.paintMode == FoliagePaintMode.erase,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LandscapeMapPainter extends CustomPainter {
  final LandscapeData data;
  final int sectionsPerSide;
  final double? cursorX;
  final double? cursorZ;
  final double radius;
  final double falloff;
  final bool eraseMode;

  _LandscapeMapPainter({
    required this.data,
    required this.sectionsPerSide,
    required this.cursorX,
    required this.cursorZ,
    required this.radius,
    required this.falloff,
    required this.eraseMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final minH = data.heightMin;
    final maxH = data.heightMax;
    final range = (maxH - minH).abs() < 1e-6 ? 1.0 : maxH - minH;

    // Heightmap: real samples, downsampled to at most 128 cells per side.
    final samples = math.min(128, data.gridResolution);
    final cell = size.width / samples;
    final paint = Paint();
    for (var r = 0; r < samples; r++) {
      for (var c = 0; c < samples; c++) {
        final gc = (c * (data.gridResolution - 1) / (samples - 1)).round();
        final gr = (r * (data.gridResolution - 1) / (samples - 1)).round();
        final t = ((data.heightAt(gc, gr) - minH) / range).clamp(0.0, 1.0);
        paint.color = Color.fromARGB(
          255,
          (40 + 180 * t).round(),
          (70 + 150 * t).round(),
          (55 + 90 * t).round(),
        );
        canvas.drawRect(Rect.fromLTWH(c * cell, r * cell, cell + 0.5, cell + 0.5), paint);
      }
    }

    // Tile seams.
    final seam = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..strokeWidth = 0.6
      ..style = PaintingStyle.stroke;
    for (var i = 1; i < sectionsPerSide; i++) {
      final p = size.width * i / sectionsPerSide;
      canvas.drawLine(Offset(p, 0), Offset(p, size.height), seam);
      canvas.drawLine(Offset(0, p), Offset(size.width, p), seam);
    }

    double px(double worldX) => (worldX / data.worldSize + 0.5) * size.width;

    // Foliage instances.
    final dot = Paint()..style = PaintingStyle.fill;
    // Landscape layer swatches. Four desaturated hues that stay apart from
    // each other when they are painted *onto terrain* — the prototype's chart
    // ramp is far too saturated to read as ground cover.
    const palette = [
      Color(0xFF7FE07F), // grass
      Color(0xFFE0C87F), // dirt
      Color(0xFF7FC8E0), // water/snow
      Color(0xFFE07FC8), // foliage
    ];
    for (var l = 0; l < data.layers.length; l++) {
      dot.color = palette[l % palette.length];
      final layer = data.layers[l];
      for (var i = 0; i < layer.instanceCount; i++) {
        final inst = layer.instanceAt(i);
        canvas.drawCircle(Offset(px(inst.x), px(inst.z)), 1.2, dot);
      }
    }

    // Brush ring: inner = full strength, outer = falloff edge.
    final cx = cursorX, cz = cursorZ;
    if (cx != null && cz != null) {
      final scale = size.width / data.worldSize;
      final outer = radius * scale;
      final inner = outer * (1.0 - falloff.clamp(0.0, 1.0));
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        // the erase brush ring, drawn over terrain of any colour; the paint brush ring, drawn over terrain of any colour
        ..color = eraseMode ? const Color(0xFFFF6B6B) : const Color(0xFFFFD166);
      canvas.drawCircle(Offset(px(cx), px(cz)), outer, ring);
      if (inner > 1.0) {
        canvas.drawCircle(
          Offset(px(cx), px(cz)),
          inner,
          // the erase brush ring, drawn over terrain of any colour; the paint brush ring, drawn over terrain of any colour
          ring..color = (eraseMode ? const Color(0xFFFF6B6B) : const Color(0xFFFFD166)).withValues(alpha: 0.55),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LandscapeMapPainter old) => true;
}

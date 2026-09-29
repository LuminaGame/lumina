import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';

double distToSegment(Offset p, Offset a, Offset b) {
  final dx = b.dx - a.dx;
  final dy = b.dy - a.dy;
  final lenSq = dx * dx + dy * dy;
  if (lenSq <= 0.0001) return (p - a).distance;
  final t = (((p.dx - a.dx) * dx + (p.dy - a.dy) * dy) / lenSq).clamp(0.0, 1.0);
  final proj = Offset(a.dx + t * dx, a.dy + t * dy);
  return (p - proj).distance;
}

String? hitTestGizmo({
  required Offset localPos,
  required Offset center2d,
  required Offset posX2d,
  required Offset posY2d,
  required Offset posZ2d,
  required Offset xy2d,
  required Offset xz2d,
  required Offset yz2d,
  required String activeTool,
}) {
  if (activeTool == 'translate') {
    final dXY = (localPos - xy2d).distance;
    final dXZ = (localPos - xz2d).distance;
    final dYZ = (localPos - yz2d).distance;
    final dCenter = (localPos - center2d).distance;

    final minPlaneDist = math.min(dXY, math.min(dXZ, dYZ));
    if (dCenter < 12.0 && dCenter < minPlaneDist) {
      return 'CENTER';
    } else if (minPlaneDist < 16.0) {
      if (minPlaneDist == dXY) return 'XY';
      if (minPlaneDist == dXZ) return 'XZ';
      return 'YZ';
    } else if (dCenter < 14.0) {
      return 'CENTER';
    } else {
      final dX = distToSegment(localPos, center2d, posX2d);
      final dY = distToSegment(localPos, center2d, posY2d);
      final dZ = distToSegment(localPos, center2d, posZ2d);
      final minAxisDist = math.min(dX, math.min(dY, dZ));
      if (minAxisDist < 20.0) {
        if (minAxisDist == dX) return 'X';
        if (minAxisDist == dY) return 'Y';
        return 'Z';
      }
    }
  }
  return null;
}

void main() {
  group('Gizmo Hover & Segment Hit-Testing Tests', () {
    test(
      'distToSegment calculates perpendicular and endpoint distances accurately',
      () {
        final a = const Offset(100.0, 100.0);
        final b = const Offset(200.0, 100.0);

        // Exactly on the midpoint of the segment
        expect(
          distToSegment(const Offset(150.0, 100.0), a, b),
          closeTo(0.0, 1e-4),
        );

        // 10 pixels directly above the midpoint of the shaft
        expect(
          distToSegment(const Offset(150.0, 90.0), a, b),
          closeTo(10.0, 1e-4),
        );

        // 15 pixels directly below the shaft near the start
        expect(
          distToSegment(const Offset(110.0, 115.0), a, b),
          closeTo(15.0, 1e-4),
        );

        // Beyond the tip (b) by 5 pixels
        expect(
          distToSegment(const Offset(205.0, 100.0), a, b),
          closeTo(5.0, 1e-4),
        );

        // Behind the base (a) by 8 pixels
        expect(
          distToSegment(const Offset(92.0, 100.0), a, b),
          closeTo(8.0, 1e-4),
        );
      },
    );

    test(
      'Translate gizmo detects hover anywhere along arrow shaft, not just tip',
      () {
        final center = const Offset(400.0, 300.0);
        final posX = const Offset(470.0, 300.0); // X arrow points right
        final posY = const Offset(435.0, 335.0); // Y arrow points down-right
        final posZ = const Offset(400.0, 230.0); // Z arrow points straight up

        final xy = const Offset(420.0, 320.0);
        final xz = const Offset(420.0, 280.0);
        final yz = const Offset(410.0, 300.0);

        // 1. Hovering near center
        expect(
          hitTestGizmo(
            localPos: const Offset(402.0, 302.0),
            center2d: center,
            posX2d: posX,
            posY2d: posY,
            posZ2d: posZ,
            xy2d: xy,
            xz2d: xz,
            yz2d: yz,
            activeTool: 'translate',
          ),
          equals('CENTER'),
        );

        // 2. Hovering halfway along X arrow shaft (Offset 435, 300)
        // Old point-only code failed here because distance to posX (470, 300) was 35px > 24px!
        expect(
          hitTestGizmo(
            localPos: const Offset(435.0, 302.0),
            center2d: center,
            posX2d: posX,
            posY2d: posY,
            posZ2d: posZ,
            xy2d: xy,
            xz2d: xz,
            yz2d: yz,
            activeTool: 'translate',
          ),
          equals('X'),
        );

        // 3. Hovering halfway along Z (up) arrow shaft (Offset 400, 260)
        expect(
          hitTestGizmo(
            localPos: const Offset(402.0, 260.0),
            center2d: center,
            posX2d: posX,
            posY2d: posY,
            posZ2d: posZ,
            xy2d: xy,
            xz2d: xz,
            yz2d: yz,
            activeTool: 'translate',
          ),
          equals('Z'),
        );

        // 4. Hovering on XY plane bracket
        expect(
          hitTestGizmo(
            localPos: const Offset(421.0, 321.0),
            center2d: center,
            posX2d: posX,
            posY2d: posY,
            posZ2d: posZ,
            xy2d: xy,
            xz2d: xz,
            yz2d: yz,
            activeTool: 'translate',
          ),
          equals('XY'),
        );

        // 5. Far outside hover zone
        expect(
          hitTestGizmo(
            localPos: const Offset(500.0, 500.0),
            center2d: center,
            posX2d: posX,
            posY2d: posY,
            posZ2d: posZ,
            xy2d: xy,
            xz2d: xz,
            yz2d: yz,
            activeTool: 'translate',
          ),
          isNull,
        );
      },
    );
  });
}

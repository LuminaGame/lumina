// design-token-exempt: 3D viewport canvas painter overlays and debug stats
part of '../viewport_widget.dart';

class _CameraMatrix {
  final Size viewportSize;
  final double yawDeg;
  final double pitchDeg;
  final double dist;
  final double panX;
  final double panY;
  final double panZ;

  late final double cx;
  late final double cy;
  late final double yawRad;
  late final double pitchRad;
  late final double fovScale;

  late final double camX;
  late final double camY;
  late final double camZ;

  late final double fX, fY, fZ;
  late final double rX, rY, rZ;
  late final double uX, uY, uZ;

  _CameraMatrix({
    required this.viewportSize,
    required this.yawDeg,
    required this.pitchDeg,
    required this.dist,
    required this.panX,
    required this.panY,
    this.panZ = 0.0,
  }) {
    cx = viewportSize.width / 2;
    cy = viewportSize.height / 2;
    // Pixels per unit of (view-space x / z), for the same vertical field of
    // view the Filament camera uses. A fixed 500 used to be assumed here,
    // which put overlay labels, gizmo hit-testing and picking rays somewhere
    // other than what the renderer drew, at every viewport size but one.
    final halfHeight = viewportSize.height / 2;
    fovScale = halfHeight <= 0
        ? 500.0
        : halfHeight / math.tan(kViewportFovDegrees * math.pi / 360.0);

    yawRad = yawDeg * math.pi / 180.0;
    pitchRad = pitchDeg.clamp(-89.0, 89.0) * math.pi / 180.0;

    // Eye position relative to pivot (panX, panY, panZ)
    final eyeOffsetX = dist * math.cos(pitchRad) * math.sin(yawRad);
    final eyeOffsetY = -dist * math.cos(pitchRad) * math.cos(yawRad);
    final eyeOffsetZ = dist * math.sin(pitchRad);

    camX = panX + eyeOffsetX;
    camY = panY + eyeOffsetY;
    camZ = panZ + eyeOffsetZ;

    // Forward vector (from camera eye to pivot)
    final dirX = panX - camX;
    final dirY = panY - camY;
    final dirZ = panZ - camZ;
    final lenF = math.sqrt(dirX * dirX + dirY * dirY + dirZ * dirZ);
    fX = dirX / (lenF == 0 ? 1 : lenF);
    fY = dirY / (lenF == 0 ? 1 : lenF);
    fZ = dirZ / (lenF == 0 ? 1 : lenF);

    // Right vector (horizontal, perpendicular to yaw direction)
    final rRawX = math.cos(yawRad);
    final rRawY = math.sin(yawRad);
    final lenR = math.sqrt(rRawX * rRawX + rRawY * rRawY);
    rX = rRawX / (lenR == 0 ? 1 : lenR);
    rY = rRawY / (lenR == 0 ? 1 : lenR);
    rZ = 0.0;

    // Up vector U = R x F
    uX = rY * fZ - rZ * fY;
    uY = rZ * fX - rX * fZ;
    uZ = rX * fY - rY * fX;
  }

  Offset? project(double wx, double wy, double wz) {
    final vx = wx - camX;
    final vy = wy - camY;
    final vz = wz - camZ;

    final viewZ = vx * fX + vy * fY + vz * fZ;
    if (viewZ <= 1.0) return null;

    final viewX = vx * rX + vy * rY + vz * rZ;
    final viewY = vx * uX + vy * uY + vz * uZ;

    final sx = cx + (viewX / viewZ) * fovScale;
    final sy = cy - (viewY / viewZ) * fovScale;
    return Offset(sx, sy);
  }

  List<double> getWorldRayDirection(Offset screenPos) {
    final dx = (screenPos.dx - cx) / fovScale;
    final dy = (cy - screenPos.dy) / fovScale;

    return [
      dx * rX + dy * uX + fX,
      dx * rY + dy * uY + fY,
      dx * rZ + dy * uZ + fZ,
    ];
  }

  Offset unprojectToFloor(Offset screenPos) {
    final dx = (screenPos.dx - cx) / fovScale;
    final dy = (cy - screenPos.dy) / fovScale;

    final rayX = dx * rX + dy * uX + fX;
    final rayY = dx * rY + dy * uY + fY;
    final rayZ = dx * rZ + dy * uZ + fZ;

    if (rayZ.abs() < 1e-6) return Offset(panX, panY);

    final t = -camZ / rayZ;
    if (t < 0) return Offset(panX, panY);
    final targetX = camX + t * rayX;
    final targetY = camY + t * rayY;
    return Offset(targetX, targetY);
  }
}

class _PerspectiveGridPainter extends CustomPainter {
  final Rect? marqueeRect;
  final Offset? dropPreviewPos;
  final String? dropPreviewName;
  final EditorViewModel viewModel;
  final String? activeGizmoAxis;

  _PerspectiveGridPainter({
    required this.viewModel,
    this.activeGizmoAxis,
    this.marqueeRect,
    this.dropPreviewPos,
    this.dropPreviewName,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (marqueeRect != null) {
      final paint = Paint()
        // Drag-drop footprint, drawn over the 3D render: a signal colour that has to read against any scene, not editor chrome.
        ..color = const Color(0x3300AAFF)
        ..style = PaintingStyle.fill;
      canvas.drawRect(marqueeRect!, paint);

      final borderPaint = Paint()
        // Drag-drop footprint ring, same reason.
        ..color = const Color(0xFF00AAFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawRect(marqueeRect!, borderPaint);
    }
    if (dropPreviewPos != null && dropPreviewName != null) {
      // Paint footprint ring
      final ringPaint = Paint()
        // Debug placement cross, drawn over the 3D render.
        ..color = const Color(0xFF00FF00).withAlpha(128)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawCircle(dropPreviewPos!, 20, ringPaint);

      // Paint axis cross
      canvas.drawLine(
        dropPreviewPos! - const Offset(10, 0),
        dropPreviewPos! + const Offset(10, 0),
        ringPaint,
      );
      canvas.drawLine(
        dropPreviewPos! - const Offset(0, 10),
        dropPreviewPos! + const Offset(0, 10),
        ringPaint,
      );

      // Paint asset name
      final textSpan = TextSpan(
        text: dropPreviewName,
        // Debug placement label: a signal colour over the render, with its own backing so it stays legible on any scene.
        style: const TextStyle(
          color: Color(0xFF00FF00),
          fontSize: 12,
          backgroundColor: Color(0x88000000),
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, dropPreviewPos! + const Offset(25, -10));
    }
    final camera = _CameraMatrix(
      viewportSize: size,
      yawDeg: viewModel.cameraYaw,
      pitchDeg: viewModel.cameraPitch,
      dist: viewModel.cameraDistance,
      panX: viewModel.cameraPanX,
      panY: viewModel.cameraPanY,
      panZ: viewModel.cameraPanZ,
    );

    // Draw Scene Actors 2D Billboard HUD Overlays (Name labels, Light/Pawn icons, Ground Drop Shadow)
    for (final actor in viewModel.actors) {
      // Folders are editor-only grouping: no icon, label or ground shadow.
      if (!viewModel.isViewportRepresented(actor.id)) continue;
      if (!viewModel.isEffectivelyVisible(actor.id)) continue;
      final isSelected = viewModel.selectedActorId == actor.id;
      final ax = actor.location[0];
      final ay = actor.location[1];
      final az = actor.location[2];

      final pos2D = camera.project(ax, ay, az);
      if (pos2D == null) continue;

      final groundPos = camera.project(ax, ay, 0);
      if (groundPos != null) {
        // Ground shadow under an actor icon: an opacity over the render.
        final shadowPaint = Paint()..color = const Color(0x55000000);
        canvas.drawCircle(groundPos, 8, shadowPaint);
        if (az > 0) {
          final dropLine = Paint()
            // Drop line from an actor to the ground plane: white at low alpha so it reads on any scene.
            ..color = const Color(0x44FFFFFF)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0;
          canvas.drawLine(groundPos, pos2D, dropLine);
        }
      }

      _draw3DActorIcon(canvas, pos2D, actor, isSelected);
    }
  }

  void _draw3DActorIcon(
    Canvas canvas,
    Offset pos,
    EditorActorNode actor,
    bool isSelected,
  ) {
    // Unselected actor outline: white at low alpha over the render.
    final outlineColor = isSelected
        ? EditorColors.primary
        : const Color(0x99FFFFFF);
    final outlinePaint = Paint()
      ..color = outlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 2.0 : 1.2;
    final fillPaint = Paint()
      // Unselected actor icon fill: a scene overlay, not a panel surface.
      ..color = isSelected
          ? EditorColors.primary.withValues(alpha: 0.25)
          : const Color(0x3342A5F5)
      ..style = PaintingStyle.fill;

    switch (actor.type) {
      case 'Mesh':
      case 'StaticMesh':
      case 'filamesh':
      case 'MeshComponent':
        // Native Filament 3D GPU renders the mesh and the 3D selection box
        break;

      case 'Pawn':
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: pos, width: 24, height: 38),
            const Radius.circular(12),
          ),
          fillPaint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: pos, width: 24, height: 38),
            const Radius.circular(12),
          ),
          outlinePaint,
        );
        break;

      case 'Light':
        canvas.drawCircle(
          pos,
          14,
          Paint()..color = Colors.amber.withValues(alpha: 0.3),
        );
        canvas.drawCircle(pos, 11, outlinePaint..color = Colors.amber);
        for (int i = 0; i < 8; i++) {
          final angle = i * math.pi / 4;
          final p1 = pos + Offset(math.cos(angle) * 13, math.sin(angle) * 13);
          final p2 = pos + Offset(math.cos(angle) * 18, math.sin(angle) * 18);
          canvas.drawLine(p1, p2, outlinePaint..strokeWidth = 1.5);
        }
        break;

      case 'NavMeshBoundsVolume':
        // Navigation bounds volume: green box marker;
        // the volume's extent is its scale, edited with the ordinary gizmos.
        final navRect = Rect.fromCenter(center: pos, width: 30, height: 22);
        // Navigation bounds volume, drawn in the scene: green is the navigation domain colour, like the axis colours.
        canvas.drawRect(
          navRect,
          Paint()
            ..color = const Color(0x3322C55E)
            ..style = PaintingStyle.fill,
        );
        // Navigation bounds outline, same domain colour.
        canvas.drawRect(
          navRect,
          outlinePaint
            ..color = isSelected
                ? EditorColors.primary
                : const Color(0xFF22C55E),
        );
        canvas.drawRect(
          navRect.deflate(5),
          Paint()
            // Navigation bounds handle, same domain colour.
            ..color = const Color(0x8822C55E)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0,
        );
        break;

      default:
        if (actor.meshData == null) {
          canvas.drawCircle(pos, 11, fillPaint);
          canvas.drawCircle(pos, 11, outlinePaint);
        }
        break;
    }

    final textSpan = TextSpan(
      text: actor.name,
      style: TextStyle(
        fontSize: 9,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        // Actor name label over the render: near-white with its own backing so it stays legible on any scene.
        color: isSelected ? EditorColors.primary : const Color(0xEAFFFFFF),
        // Backing for the actor name label.
        backgroundColor: const Color(0xCC000000),
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(pos.dx - textPainter.width / 2, pos.dy - 28),
    );
  }

  @override
  bool shouldRepaint(covariant _PerspectiveGridPainter oldDelegate) => true;
}

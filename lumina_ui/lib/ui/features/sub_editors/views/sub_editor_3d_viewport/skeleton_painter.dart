part of '../sub_editor_3d_viewport.dart';

class _SubEditorGizmoPainter extends CustomPainter {
  final GlbMeshData? glbMesh;
  final bool showBones;
  final bool showSockets;
  final List<SkeletalMeshSocket> sockets;
  final GlbNode? selectedNode;
  final SkeletalMeshSocket? selectedSocket;
  final Map<String, List<double>>? jointDeltas;
  final double cameraYaw;
  final double cameraPitch;
  final double cameraDistance;
  final Offset cameraPan;

  _SubEditorGizmoPainter({
    this.glbMesh,
    required this.showBones,
    required this.showSockets,
    required this.sockets,
    this.selectedNode,
    this.selectedSocket,
    this.jointDeltas,
    required this.cameraYaw,
    required this.cameraPitch,
    required this.cameraDistance,
    required this.cameraPan,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (glbMesh == null) return;
    if (!showBones && !showSockets) return;

    final center = Offset(size.width / 2, size.height / 2) + cameraPan;

    final radYaw = cameraYaw * math.pi / 180.0;
    final radPitch = cameraPitch * math.pi / 180.0;

    final cosY = math.cos(radYaw);
    final sinY = math.sin(radYaw);
    final cosP = math.cos(radPitch);
    final sinP = math.sin(radPitch);

    final minX = glbMesh!.minBounds[0];
    final minY = glbMesh!.minBounds[1];
    final minZ = glbMesh!.minBounds[2];
    final maxX = glbMesh!.maxBounds[0];
    final maxY = glbMesh!.maxBounds[1];
    final maxZ = glbMesh!.maxBounds[2];

    final cx = (minX + maxX) / 2.0;
    final cy = (minY + maxY) / 2.0;
    final cz = (minZ + maxZ) / 2.0;

    final spanX = (maxX - minX).abs();
    final spanY = (maxY - minY).abs();
    final spanZ = (maxZ - minZ).abs();
    final bool isZUp = (spanZ >= spanY);

    Offset? projectPoint(double x, double y, double z) {
      final target = Vector3(cx + cameraPan.dx, cy + cameraPan.dy, cz);
      return projectWorldToViewport(
        worldPos: Vector3(x, y, z),
        size: size,
        yawDeg: cameraYaw,
        pitchDeg: cameraPitch,
        distance: cameraDistance,
        target: target,
        isZUp: isZUp,
      );
    }

    // Traverse node hierarchy to calculate positions with full 4x4 matrix accumulation
    final Map<String, List<double>> boneWorldPositions = {};
    final Map<String, Matrix4> boneWorldMatrices = {};

    // T · R · S from the node's TRS, composed straight from the quaternion.
    // Never axis/angle: for a (near-)identity quaternion — `[0,0,0,±1]` and
    // the float-noise variants a MetaHuman export writes for `root` and its
    // corrective bones — `Quaternion.axis` is the zero vector and
    // `Matrix4.rotate` divides by its length, turning the node and every
    // descendant into NaN and `Canvas.drawLine` into an exception per frame.
    Matrix4 computeNodeTransform(GlbNode node) {
      final t = node.translation;
      final r = node.rotation;
      final s = node.scale;
      final translation = Vector3(
        t != null && t.isNotEmpty ? t[0] : 0.0,
        t != null && t.length > 1 ? t[1] : 0.0,
        t != null && t.length > 2 ? t[2] : 0.0,
      );
      var rotation = Quaternion.identity();
      if (r != null && r.length >= 4) {
        final q = Quaternion(r[0], r[1], r[2], r[3]);
        final len = q.length;
        if (len.isFinite && len > 1e-12) rotation = q.normalized();
      }
      final scale = Vector3(
        s != null && s.isNotEmpty ? s[0] : 1.0,
        s != null && s.length > 1 ? s[1] : 1.0,
        s != null && s.length > 2 ? s[2] : 1.0,
      );
      final restTransform = Matrix4.compose(translation, rotation, scale);

      final deltas = jointDeltas?[node.name];
      if (deltas != null && deltas.length >= 9) {
        final tx = deltas[0];
        final ty = deltas[1];
        final tz = deltas[2];
        final rx = deltas[3];
        final ry = deltas[4];
        final rz = deltas[5];
        final sx = deltas[6];
        final sy = deltas[7];
        final sz = deltas[8];

        final radX = rx * math.pi / 180.0;
        final radY = ry * math.pi / 180.0;
        final radZ = rz * math.pi / 180.0;

        final deltaMat = Matrix4.identity()
          ..translate(tx * 0.01, ty * 0.01, tz * 0.01)
          ..rotateX(radX)
          ..rotateY(radY)
          ..rotateZ(radZ);
        if (sx != 0.0 || sy != 0.0 || sz != 0.0) {
          deltaMat.scale(1.0 + sx, 1.0 + sy, 1.0 + sz);
        }
        return restTransform * deltaMat;
      }
      return restTransform;
    }

    void collectBonePositions(GlbNode node, Matrix4 parentTransform) {
      final localTransform = computeNodeTransform(node);
      final worldTransform = parentTransform * localTransform;
      final trans = worldTransform.getTranslation();
      boneWorldPositions[node.name] = [trans.x, trans.y, trans.z];
      boneWorldMatrices[node.name] = worldTransform;

      for (final child in node.children) {
        collectBonePositions(child, worldTransform);
      }
    }

    for (final root in glbMesh!.rootNodes) {
      collectBonePositions(root, Matrix4.identity());
    }

    // 1. Draw Bones Wireframe
    if (showBones) {
      final boneLinePaint = Paint()
        // a 3D overlay: magenta marks a particle emitter volume in the scene
        ..color = const Color(0xFFB026FF).withValues(alpha: 0.85)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;

      final selBoneLinePaint = Paint()
        // a 3D overlay: amber marks a socket/attachment point in the scene
        ..color = const Color(0xFFFFD54F)
        ..strokeWidth = 3.0
        ..style = PaintingStyle.stroke;

      final jointPaint = Paint()
        // a 3D overlay drawn over the sub-editor scene, not editor chrome: cyan is picked to stay legible against lit geometry of any colour
        ..color = const Color(0xFF00E5FF)
        ..style = PaintingStyle.fill;

      final selJointPaint = Paint()
        ..color = Colors.amber
        ..style = PaintingStyle.fill;

      void drawBoneNode(
        GlbNode node,
        Offset? parentProj,
        bool isParentSelected,
      ) {
        final pos = boneWorldPositions[node.name];
        if (pos != null) {
          final isSelected = selectedNode?.name == node.name;
          final proj = projectPoint(pos[0], pos[1], pos[2]);

          if (proj != null) {
            if (parentProj != null) {
              canvas.drawLine(
                parentProj,
                proj,
                (isSelected || isParentSelected)
                    ? selBoneLinePaint
                    : boneLinePaint,
              );
            }

            // Draw Joint marker
            canvas.drawCircle(
              proj,
              isSelected ? 5.0 : 3.0,
              isSelected ? selJointPaint : jointPaint,
            );
            if (isSelected) {
              canvas.drawCircle(
                proj,
                8.0,
                Paint()
                  // a 3D overlay: amber marks a socket/attachment point in the scene
                  ..color = const Color(0xFFFFD54F).withValues(alpha: 0.5)
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 1.5,
              );
            }
          }

          for (final child in node.children) {
            drawBoneNode(child, proj ?? parentProj, isSelected);
          }
        }
      }

      for (final root in glbMesh!.rootNodes) {
        drawBoneNode(root, null, false);
      }
    }

    // 2. Draw Sockets
    if (showSockets) {
      final socketPaint = Paint()
        ..color = Colors.amber
        ..style = PaintingStyle.fill;

      final socketLinePaint = Paint()
        ..color = Colors.amber
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;

      final selSocketPaint = Paint()
        // a 3D overlay: the hover/selected highlight the Filament manipulator also uses (FilamentTransformGizmo.highlightColor is 1,1,0)
        ..color = const Color(0xFFFFEB3B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;

      for (final socket in sockets) {
        final isSelected = selectedSocket?.name == socket.name;
        // entityWorld × G_bone × offset, as the attached preview mesh:
        // the offset is in the bone's frame and in cm.
        final boneWorld = boneWorldMatrices[socket.parentBone] ?? Matrix4.identity();
        final socketPos = boneWorld.multiplied(SkeletalSocketMath.localOffset(socket)).getTranslation();
        final sx = socketPos.x;
        final sy = socketPos.y;
        final sz = socketPos.z;

        final proj = projectPoint(sx, sy, sz);
        if (proj == null) continue;

        // Draw Socket Crosshair
        const r = 6.0;
        canvas.drawLine(
          Offset(proj.dx - r, proj.dy),
          Offset(proj.dx + r, proj.dy),
          socketLinePaint,
        );
        canvas.drawLine(
          Offset(proj.dx, proj.dy - r),
          Offset(proj.dx, proj.dy + r),
          socketLinePaint,
        );
        canvas.drawCircle(proj, isSelected ? 4.0 : 2.5, socketPaint);

        if (isSelected) {
          canvas.drawCircle(proj, 10.0, selSocketPaint);
        }

        // Draw text label for socket
        final textPainter = TextPainter(
          text: TextSpan(
            text: socket.name,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              // a 3D overlay: the hover/selected highlight the Filament manipulator also uses (FilamentTransformGizmo.highlightColor is 1,1,0)
              color: isSelected ? const Color(0xFFFFEB3B) : Colors.amber,
              backgroundColor: Colors.black.withValues(alpha: 0.6),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        textPainter.paint(canvas, Offset(proj.dx + 8, proj.dy - 6));
      }
    }

  }

  @override
  bool shouldRepaint(covariant _SubEditorGizmoPainter oldDelegate) => true;
}

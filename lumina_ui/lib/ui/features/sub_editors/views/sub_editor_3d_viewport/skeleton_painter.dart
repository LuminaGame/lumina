part of '../sub_editor_3d_viewport.dart';

class _SubEditorGizmoPainter extends CustomPainter {
  final GlbMeshData? glbMesh;
  final bool showBones;
  final bool showSockets;
  final List<SkeletalMeshSocket> sockets;
  final GlbNode? selectedNode;
  final String? selectedBoneName;
  final SkeletalMeshSocket? selectedSocket;
  final Map<String, List<double>>? jointDeltas;

  /// A whole pose (joint name → translation, rotation, scale; see
  /// `SubEditor3DViewport.jointLocalPose`) the bones are drawn in instead of
  /// the rest pose.
  final Map<String, List<double>>? jointLocalPose;
  final Set<String>? visibleBoneNames;

  /// Onion-skin skeletons, IK markers and drawn paths (GLB frame).
  final List<SubEditorGhostSkeleton> ghostSkeletons;
  final List<SubEditorOverlayMarker> overlayMarkers;
  final List<SubEditorOverlayPath> overlayPaths;
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
    this.selectedBoneName,
    this.selectedSocket,
    this.jointDeltas,
    this.jointLocalPose,
    this.visibleBoneNames,
    this.ghostSkeletons = const [],
    this.overlayMarkers = const [],
    this.overlayPaths = const [],
    required this.cameraYaw,
    required this.cameraPitch,
    required this.cameraDistance,
    required this.cameraPan,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (glbMesh == null) return;
    if (!showBones && !showSockets && ghostSkeletons.isEmpty && overlayMarkers.isEmpty && overlayPaths.isEmpty) return;

    final minX = glbMesh!.minBounds[0];
    final minY = glbMesh!.minBounds[1];
    final minZ = glbMesh!.minBounds[2];
    final maxX = glbMesh!.maxBounds[0];
    final maxY = glbMesh!.maxBounds[1];
    final maxZ = glbMesh!.maxBounds[2];

    final cx = (minX + maxX) / 2.0;
    final cy = (minY + maxY) / 2.0;
    final cz = (minZ + maxZ) / 2.0;

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
    Matrix4 computeNodeTransform(GlbNode node, [Map<String, List<double>>? posedBy]) {
      final posed = (posedBy ?? jointLocalPose)?[node.name];
      if (posed != null && posed.length >= 10) {
        return Matrix4.compose(
          Vector3(posed[0], posed[1], posed[2]),
          Quaternion(posed[3], posed[4], posed[5], posed[6]),
          Vector3(posed[7], posed[8], posed[9]),
        );
      }
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
          ..translateByDouble(tx * 0.01, ty * 0.01, tz * 0.01, 1.0)
          ..rotateX(radX)
          ..rotateY(radY)
          ..rotateZ(radZ);
        if (sx != 0.0 || sy != 0.0 || sz != 0.0) {
          deltaMat.scaleByDouble(1.0 + sx, 1.0 + sy, 1.0 + sz, 1.0);
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

    // 0. Onion skins, paths and markers under the live skeleton.
    for (final ghost in ghostSkeletons) {
      final positions = <String, Vector3>{};
      void collect(GlbNode node, Matrix4 parent) {
        final world = parent * computeNodeTransform(node, ghost.jointLocalPose);
        positions[node.name] = world.getTranslation();
        for (final child in node.children) {
          collect(child, world);
        }
      }

      for (final root in glbMesh!.rootNodes) {
        collect(root, Matrix4.identity());
      }
      final line = Paint()
        ..color = ghost.color.withValues(alpha: ghost.opacity)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;
      final joint = Paint()
        ..color = ghost.color.withValues(alpha: ghost.opacity)
        ..style = PaintingStyle.fill;
      Offset? top;
      void draw(GlbNode node, Offset? parentProj, String? parentName) {
        final p = positions[node.name];
        final proj = p == null || !ghost.jointLocalPose.containsKey(node.name) ? null : projectPoint(p.x, p.y, p.z);
        if (proj != null) {
          if (parentProj != null) {
            if (ghost.volumetric) {
              final n = node.name.toLowerCase();
              final pn = parentName?.toLowerCase() ?? '';
              double width = 8.0;
              if (n.contains('spine') || n.contains('hips') || n.contains('pelvis')) {
                width = 22.0;
              } else if (n.contains('thigh') || n.contains('upleg') || pn.contains('pelvis') || pn.contains('hips')) {
                width = 16.0;
              } else if (n.contains('calf') || n.contains('leg')) {
                width = 12.0;
              } else if (n.contains('upperarm') || (n.contains('arm') && !n.contains('forearm'))) {
                width = 13.0;
              } else if (n.contains('lowerarm') || n.contains('forearm')) {
                width = 9.0;
              } else if (n.contains('neck') || n.contains('head')) {
                width = 14.0;
              }

              // Outer volumetric translucent limb capsule
              final bodyPaint = Paint()
                ..color = ghost.color.withValues(alpha: (ghost.opacity * 0.45).clamp(0.0, 1.0))
                ..strokeWidth = width
                ..strokeCap = StrokeCap.round
                ..style = PaintingStyle.stroke;
              canvas.drawLine(parentProj, proj, bodyPaint);

              // Inner core highlight
              final corePaint = Paint()
                ..color = ghost.color.withValues(alpha: (ghost.opacity * 0.85).clamp(0.0, 1.0))
                ..strokeWidth = 2.0
                ..strokeCap = StrokeCap.round
                ..style = PaintingStyle.stroke;
              canvas.drawLine(parentProj, proj, corePaint);
            } else {
              canvas.drawLine(parentProj, proj, line);
            }
          }

          // Volumetric head sphere
          final isHead = node.name.toLowerCase().contains('head');
          if (ghost.volumetric && isHead) {
            final headGlow = Paint()
              ..color = ghost.color.withValues(alpha: (ghost.opacity * 0.5).clamp(0.0, 1.0))
              ..style = PaintingStyle.fill;
            canvas.drawCircle(proj, 14.0, headGlow);
            final headRing = Paint()
              ..color = ghost.color.withValues(alpha: ghost.opacity)
              ..strokeWidth = 1.5
              ..style = PaintingStyle.stroke;
            canvas.drawCircle(proj, 14.0, headRing);
          } else {
            canvas.drawCircle(proj, ghost.volumetric ? 4.0 : 2.5, joint);
          }

          if (top == null || proj.dy < top!.dy) top = proj;
        }
        for (final child in node.children) {
          draw(child, proj ?? parentProj, node.name);
        }
      }

      for (final root in glbMesh!.rootNodes) {
        draw(root, null, null);
      }
      if (ghost.label != null && top != null) {
        final tp = TextPainter(
          text: TextSpan(
            text: ghost.label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: ghost.color,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        final badgeRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            top!.dx - tp.width / 2 - 8,
            top!.dy - 24,
            tp.width + 16,
            tp.height + 6,
          ),
          const Radius.circular(5),
        );

        final bgPaint = Paint()
          ..color = const Color(0xDD111115)
          ..style = PaintingStyle.fill;
        canvas.drawRRect(badgeRect, bgPaint);

        final borderPaint = Paint()
          ..color = ghost.color.withValues(alpha: 0.8)
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke;
        canvas.drawRRect(badgeRect, borderPaint);

        tp.paint(canvas, Offset(top!.dx - tp.width / 2, top!.dy - 21));
      }
    }

    for (final path in overlayPaths) {
      final paint = Paint()
        ..color = path.color
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;
      Offset? last;
      for (final (i, p) in path.points.indexed) {
        final proj = projectPoint(p.x, p.y, p.z);
        if (proj == null) continue;
        if (last != null) canvas.drawLine(last, proj, paint);
        canvas.drawCircle(proj, 4.0, Paint()..color = path.color);
        final tp = TextPainter(
          text: TextSpan(text: '${i + 1}', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: path.color)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, proj + const Offset(6, -12));
        last = proj;
      }
    }

    for (final marker in overlayMarkers) {
      final proj = projectPoint(marker.position.x, marker.position.y, marker.position.z);
      if (proj == null) continue;
      final to = marker.lineTo;
      if (to != null) {
        final toProj = projectPoint(to.x, to.y, to.z);
        if (toProj != null) {
          final dash = Paint()
            ..color = marker.color.withValues(alpha: 0.7)
            ..strokeWidth = 1.2;
          final d = toProj - proj;
          final len = d.distance;
          for (var s = 0.0; s < len; s += 8.0) {
            canvas.drawLine(proj + d * (s / len), proj + d * (math.min(s + 4.0, len) / len), dash);
          }
        }
      }
      final fill = Paint()..color = marker.color;
      final stroke = Paint()
        ..color = marker.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      switch (marker.shape) {
        case SubEditorMarkerShape.dot:
          canvas.drawCircle(proj, 5.0, fill);
        case SubEditorMarkerShape.ring:
          canvas.drawCircle(proj, 7.0, stroke);
          canvas.drawCircle(proj, 2.0, fill);
        case SubEditorMarkerShape.diamond:
          final path = Path()
            ..moveTo(proj.dx, proj.dy - 8)
            ..lineTo(proj.dx + 8, proj.dy)
            ..lineTo(proj.dx, proj.dy + 8)
            ..lineTo(proj.dx - 8, proj.dy)
            ..close();
          canvas.drawPath(path, Paint()..color = marker.color.withValues(alpha: 0.35));
          canvas.drawPath(path, stroke);
      }
      if (marker.label != null) {
        final tp = TextPainter(
          text: TextSpan(
            text: marker.label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: marker.color,
              backgroundColor: Colors.black.withValues(alpha: 0.55),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, proj + const Offset(10, -6));
      }
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

      final visibleLower = visibleBoneNames?.map((n) => n.toLowerCase()).toSet();

      void drawBoneNode(
        GlbNode node,
        Offset? parentProj,
        bool isParentSelected,
      ) {
        final pos = boneWorldPositions[node.name];
        if (pos != null) {
          final isVisible = visibleLower == null || visibleLower.contains(node.name.toLowerCase());
          final isSelected = selectedNode?.name == node.name || (selectedBoneName != null && selectedBoneName == node.name);
          final proj = projectPoint(pos[0], pos[1], pos[2]);

          if (proj != null && isVisible) {
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

          final nextParent = isVisible ? (proj ?? parentProj) : parentProj;
          final nextSelected = isVisible ? isSelected : isParentSelected;

          for (final child in node.children) {
            drawBoneNode(child, nextParent, nextSelected);
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

/// Computes world positions of all bones in [glbMesh] given active [jointLocalPose] and [jointDeltas].
Map<String, Vector3> computeSkeletonBonePositions({
  required GlbMeshData glbMesh,
  Map<String, List<double>>? jointLocalPose,
  Map<String, List<double>>? jointDeltas,
}) {
  final Map<String, Vector3> boneWorldPositions = {};

  Matrix4 computeNodeTransform(GlbNode node) {
    final posed = jointLocalPose?[node.name];
    if (posed != null && posed.length >= 10) {
      return Matrix4.compose(
        Vector3(posed[0], posed[1], posed[2]),
        Quaternion(posed[3], posed[4], posed[5], posed[6]),
        Vector3(posed[7], posed[8], posed[9]),
      );
    }
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
      final radX = deltas[3] * math.pi / 180.0;
      final radY = deltas[4] * math.pi / 180.0;
      final radZ = deltas[5] * math.pi / 180.0;

      final deltaMat = Matrix4.identity()
        ..translateByDouble(deltas[0] * 0.01, deltas[1] * 0.01, deltas[2] * 0.01, 1.0)
        ..rotateX(radX)
        ..rotateY(radY)
        ..rotateZ(radZ);
      if (deltas[6] != 0.0 || deltas[7] != 0.0 || deltas[8] != 0.0) {
        deltaMat.scaleByDouble(1.0 + deltas[6], 1.0 + deltas[7], 1.0 + deltas[8], 1.0);
      }
      return restTransform * deltaMat;
    }
    return restTransform;
  }

  void collectBonePositions(GlbNode node, Matrix4 parentTransform) {
    final localTransform = computeNodeTransform(node);
    final worldTransform = parentTransform * localTransform;
    boneWorldPositions[node.name] = worldTransform.getTranslation();

    for (final child in node.children) {
      collectBonePositions(child, worldTransform);
    }
  }

  for (final root in glbMesh.rootNodes) {
    collectBonePositions(root, Matrix4.identity());
  }

  return boneWorldPositions;
}

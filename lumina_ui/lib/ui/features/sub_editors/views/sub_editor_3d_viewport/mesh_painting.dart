part of '../sub_editor_3d_viewport.dart';

/// Software rasterisation of the imported GLB mesh and of the mesh
/// component list, depth-sorted and flat-shaded, plus the shared 3D->2D
/// projection.
mixin _SubEditor3DMeshPainting on _SubEditor3DPainterBase {

  void _renderGlbMesh(
    Canvas canvas,
    Offset center,
    double cosY,
    double sinY,
    double cosP,
    double sinP,
  ) {
    final positions = glbMesh!.positions;
    final indices = glbMesh!.indices.isNotEmpty
        ? glbMesh!.indices
        : List<int>.generate(positions.length ~/ 3, (i) => i);
    final colors = glbMesh!.vertexColors;

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
    double maxSpan = math.max(spanX, math.max(spanY, spanZ));
    final double scaleFactor = 120.0 / maxSpan;
    final List<_GlobalTriData> allTris = [];
    const lx = 0.577, ly = 0.577, lz = 0.577;

    void addPrimitiveTriangles(
      List<double> primPositions,
      List<int> primIndices,
      Uint8List? primColors, [
      List<double>? baseColorFactor,
    ]) {
      if (primPositions.isEmpty || primIndices.isEmpty) return;

      final int vertCount = primPositions.length ~/ 3;
      final List<List<double>> world3DPts = List.generate(vertCount, (i) {
        final gltfX = primPositions[i * 3];
        final gltfY = primPositions[i * 3 + 1];
        final gltfZ = primPositions[i * 3 + 2];

        final double vx, vy, vz;
        if (isZUp) {
          vx = (gltfX - cx) * scaleFactor;
          vy = (gltfY - cy) * scaleFactor;
          vz = (gltfZ - minZ) * scaleFactor;
        } else {
          vx = (gltfX - cx) * scaleFactor;
          vy = (gltfZ - cz) * scaleFactor;
          vz = (gltfY - minY) * scaleFactor;
        }
        return [vx, vy, vz];
      });

      final List<Offset> projPts = [];
      final List<double> depths = [];

      for (final pt in world3DPts) {
        final proj = _project3D(
          pt[0],
          pt[1],
          pt[2],
          center,
          cosY,
          sinY,
          cosP,
          sinP,
        );
        projPts.add(proj);
        final d = pt[0] * sinY - pt[1] * cosY + pt[2] * sinP;
        depths.add(d);
      }

      for (int i = 0; i < primIndices.length - 2; i += 3) {
        final v0 = primIndices[i];
        final v1 = primIndices[i + 1];
        final v2 = primIndices[i + 2];

        if (v0 < vertCount && v1 < vertCount && v2 < vertCount) {
          final w0 = world3DPts[v0];
          final w1 = world3DPts[v1];
          final w2 = world3DPts[v2];

          final vax = w1[0] - w0[0], vay = w1[1] - w0[1], vaz = w1[2] - w0[2];
          final vbx = w2[0] - w0[0], vby = w2[1] - w0[1], vbz = w2[2] - w0[2];

          final nx = vay * vbz - vaz * vby;
          final ny = vaz * vbx - vax * vbz;
          final nz = vax * vby - vay * vbx;

          final nLen = math.sqrt(nx * nx + ny * ny + nz * nz);
          double dot = 0.5;
          if (nLen > 1e-6) {
            final dotVal = (nx * lx + ny * ly + nz * lz) / nLen;
            dot = dotVal.abs();
          }

          final shade = (0.35 + 0.65 * dot).clamp(0.2, 1.0);
          final avgDepth = (depths[v0] + depths[v1] + depths[v2]) / 3.0;

          Color baseCol = EditorColors.mutedForeground;
          if (primColors != null &&
              v0 * 3 + 2 < primColors.length &&
              v1 * 3 + 2 < primColors.length &&
              v2 * 3 + 2 < primColors.length) {
            final r0 = primColors[v0 * 3],
                g0 = primColors[v0 * 3 + 1],
                b0 = primColors[v0 * 3 + 2];
            final r1 = primColors[v1 * 3],
                g1 = primColors[v1 * 3 + 1],
                b1 = primColors[v1 * 3 + 2];
            final r2 = primColors[v2 * 3],
                g2 = primColors[v2 * 3 + 1],
                b2 = primColors[v2 * 3 + 2];

            final avgR = (r0 + r1 + r2) ~/ 3;
            final avgG = (g0 + g1 + g2) ~/ 3;
            final avgB = (b0 + b1 + b2) ~/ 3;

            baseCol = Color.fromRGBO(avgR, avgG, avgB, 1.0);
          } else if (baseColorFactor != null && baseColorFactor.length >= 3) {
            baseCol = Color.fromRGBO(
              (baseColorFactor[0] * 255).round().clamp(0, 255),
              (baseColorFactor[1] * 255).round().clamp(0, 255),
              (baseColorFactor[2] * 255).round().clamp(0, 255),
              1.0,
            );
          }

          allTris.add(
            _GlobalTriData(
              projPts[v0],
              projPts[v1],
              projPts[v2],
              avgDepth,
              shade,
              baseCol,
            ),
          );
        }
      }
    }

    if (glbMesh!.subPrimitives.isNotEmpty) {
      for (int i = 0; i < glbMesh!.subPrimitives.length; i++) {
        if (hiddenSectionIndices.contains(i)) continue;
        final subPrim = glbMesh!.subPrimitives[i];
        addPrimitiveTriangles(
          subPrim.positions,
          subPrim.indices,
          subPrim.vertexColors,
          highlightedSectionIndices.contains(i)
              ? _SubEditor3DPainter._highlightTint(subPrim.baseColor)
              : subPrim.baseColor,
        );
      }
    } else {
      addPrimitiveTriangles(positions, indices, colors, glbMesh!.baseColor);
    }

    // Back-to-front depth sorting (Painter's algorithm)
    allTris.sort((a, b) => b.depth.compareTo(a.depth));

    final fillPaint = Paint()..style = PaintingStyle.fill;
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = Colors.cyan.withValues(alpha: 0.5);

    for (final tri in allTris) {
      final path = Path()
        ..moveTo(tri.p0.dx, tri.p0.dy)
        ..lineTo(tri.p1.dx, tri.p1.dy)
        ..lineTo(tri.p2.dx, tri.p2.dy)
        ..close();

      if (shadingMode == ViewportShadingMode.lit ||
          shadingMode == ViewportShadingMode.unlit) {
        final baseCol = tri.color;
        fillPaint.color = shadingMode == ViewportShadingMode.lit
            ? Color.fromRGBO(
                ((baseCol.r * 255) * tri.shade).round().clamp(0, 255),
                ((baseCol.g * 255) * tri.shade).round().clamp(0, 255),
                ((baseCol.b * 255) * tri.shade).round().clamp(0, 255),
                1.0,
              )
            : baseCol;
        canvas.drawPath(path, fillPaint);
      }

      if (shadingMode == ViewportShadingMode.wireframe) {
        canvas.drawPath(path, linePaint);
      }
    }

    // Draw Selected Node Wireframe Highlight Overlay
    if (selectedNode != null && selectedNode!.isVisible) {
      final selPos = selectedNode!.getAllDescendantPositions();
      final selInd = selectedNode!.getAllDescendantIndices();

      if (selPos.isNotEmpty && selInd.isNotEmpty) {
        final highlightLinePaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          // a 3D overlay drawn over the sub-editor scene, not editor chrome: cyan is picked to stay legible against lit geometry of any colour
          ..color = const Color(0xFF00E5FF).withValues(alpha: 0.35);

        final int vCount = selPos.length ~/ 3;
        final List<Offset> selProjPts = [];

        for (int i = 0; i < vCount; i++) {
          final gltfX = selPos[i * 3];
          final gltfY = selPos[i * 3 + 1];
          final gltfZ = selPos[i * 3 + 2];

          final double vx, vy, vz;
          if (isZUp) {
            vx = (gltfX - cx) * scaleFactor;
            vy = (gltfY - cy) * scaleFactor;
            vz = (gltfZ - minZ) * scaleFactor;
          } else {
            vx = (gltfX - cx) * scaleFactor;
            vy = (gltfZ - cz) * scaleFactor;
            vz = (gltfY - minY) * scaleFactor;
          }

          selProjPts.add(
            _project3D(vx, vy, vz, center, cosY, sinY, cosP, sinP),
          );
        }

        for (int i = 0; i < selInd.length - 2; i += 3) {
          final i0 = selInd[i];
          final i1 = selInd[i + 1];
          final i2 = selInd[i + 2];

          if (i0 < vCount && i1 < vCount && i2 < vCount) {
            final p0 = selProjPts[i0];
            final p1 = selProjPts[i1];
            final p2 = selProjPts[i2];

            final hPath = Path()
              ..moveTo(p0.dx, p0.dy)
              ..lineTo(p1.dx, p1.dy)
              ..lineTo(p2.dx, p2.dy)
              ..close();

            canvas.drawPath(hPath, highlightLinePaint);
          }
        }
      }
    }
  }

  void _renderMeshComponents(
    Canvas canvas,
    Offset center,
    double cosY,
    double sinY,
    double cosP,
    double sinP,
  ) {
    if (meshComponents == null || meshComponents!.isEmpty) return;

    final active = meshComponents!
        .where((c) => c.isVisible && c.glbMesh.positions.isNotEmpty)
        .toList();
    if (active.isEmpty) return;

    double minX = double.infinity, minY = double.infinity, minZ = double.infinity;
    double maxX = -double.infinity, maxY = -double.infinity, maxZ = -double.infinity;

    for (final comp in active) {
      final m = comp.glbMesh;
      final sx = comp.scale.isNotEmpty ? comp.scale[0].abs() : 1.0;
      final sy = comp.scale.length > 1 ? comp.scale[1].abs() : 1.0;
      final sz = comp.scale.length > 2 ? comp.scale[2].abs() : 1.0;

      final cMinX = m.minBounds[0] * sx + (comp.location.isNotEmpty ? comp.location[0] : 0.0);
      final cMaxX = m.maxBounds[0] * sx + (comp.location.isNotEmpty ? comp.location[0] : 0.0);
      final cMinY = m.minBounds[1] * sy + (comp.location.length > 1 ? comp.location[1] : 0.0);
      final cMaxY = m.maxBounds[1] * sy + (comp.location.length > 1 ? comp.location[1] : 0.0);
      final cMinZ = m.minBounds[2] * sz + (comp.location.length > 2 ? comp.location[2] : 0.0);
      final cMaxZ = m.maxBounds[2] * sz + (comp.location.length > 2 ? comp.location[2] : 0.0);

      minX = math.min(minX, math.min(cMinX, cMaxX));
      maxX = math.max(maxX, math.max(cMinX, cMaxX));
      minY = math.min(minY, math.min(cMinY, cMaxY));
      maxY = math.max(maxY, math.max(cMinY, cMaxY));
      minZ = math.min(minZ, math.min(cMinZ, cMaxZ));
      maxZ = math.max(maxZ, math.max(cMinZ, cMaxZ));
    }

    final cx = (minX + maxX) / 2.0;
    final cy = (minY + maxY) / 2.0;
    final cz = (minZ + maxZ) / 2.0;

    final spanX = (maxX - minX).abs();
    final spanY = (maxY - minY).abs();
    final spanZ = (maxZ - minZ).abs();
    final bool isZUp = (spanZ >= spanY);
    final double maxSpan = math.max(spanX, math.max(spanY, spanZ));
    final double scaleFactor = maxSpan > 1e-6 ? 120.0 / maxSpan : 1.0;
    final List<_GlobalTriData> allTris = [];
    const lx = 0.577, ly = 0.577, lz = 0.577;

    for (final comp in active) {
      final mesh = comp.glbMesh;
      final loc = comp.location;
      final scl = comp.scale;

      final sx = scl.isNotEmpty ? scl[0] : 1.0;
      final sy = scl.length > 1 ? scl[1] : 1.0;
      final sz = scl.length > 2 ? scl[2] : 1.0;
      final tx = loc.isNotEmpty ? loc[0] : 0.0;
      final ty = loc.length > 1 ? loc[1] : 0.0;
      final tz = loc.length > 2 ? loc[2] : 0.0;

      void addCompTriangles(
        List<double> primPositions,
        List<int> primIndices,
        Uint8List? primColors, [
        List<double>? baseColorFactor,
      ]) {
        if (primPositions.isEmpty || primIndices.isEmpty) return;

        final int vertCount = primPositions.length ~/ 3;
        final List<List<double>> world3DPts = List.generate(vertCount, (i) {
          final gltfX = primPositions[i * 3] * sx + tx;
          final gltfY = primPositions[i * 3 + 1] * sy + ty;
          final gltfZ = primPositions[i * 3 + 2] * sz + tz;

          final double vx, vy, vz;
          if (isZUp) {
            vx = (gltfX - cx) * scaleFactor;
            vy = (gltfY - cy) * scaleFactor;
            vz = (gltfZ - minZ) * scaleFactor;
          } else {
            vx = (gltfX - cx) * scaleFactor;
            vy = (gltfZ - cz) * scaleFactor;
            vz = (gltfY - minY) * scaleFactor;
          }
          return [vx, vy, vz];
        });

        final List<Offset> projPts = [];
        final List<double> depths = [];

        for (final pt in world3DPts) {
          final proj = _project3D(
            pt[0],
            pt[1],
            pt[2],
            center,
            cosY,
            sinY,
            cosP,
            sinP,
          );
          projPts.add(proj);
          final d = pt[0] * sinY - pt[1] * cosY + pt[2] * sinP;
          depths.add(d);
        }

        for (int i = 0; i < primIndices.length - 2; i += 3) {
          final v0 = primIndices[i];
          final v1 = primIndices[i + 1];
          final v2 = primIndices[i + 2];

          if (v0 < vertCount && v1 < vertCount && v2 < vertCount) {
            final w0 = world3DPts[v0];
            final w1 = world3DPts[v1];
            final w2 = world3DPts[v2];

            final vax = w1[0] - w0[0], vay = w1[1] - w0[1], vaz = w1[2] - w0[2];
            final vbx = w2[0] - w0[0], vby = w2[1] - w0[1], vbz = w2[2] - w0[2];

            final nx = vay * vbz - vaz * vby;
            final ny = vaz * vbx - vax * vbz;
            final nz = vax * vby - vay * vbx;

            final nLen = math.sqrt(nx * nx + ny * ny + nz * nz);
            double dot = 0.5;
            if (nLen > 1e-6) {
              final dotVal = (nx * lx + ny * ly + nz * lz) / nLen;
              dot = dotVal.abs();
            }

            final shade = (0.35 + 0.65 * dot).clamp(0.2, 1.0);
            final avgDepth = (depths[v0] + depths[v1] + depths[v2]) / 3.0;

            Color baseCol = EditorColors.mutedForeground;
            if (primColors != null &&
                v0 * 3 + 2 < primColors.length &&
                v1 * 3 + 2 < primColors.length &&
                v2 * 3 + 2 < primColors.length) {
              final r0 = primColors[v0 * 3],
                  g0 = primColors[v0 * 3 + 1],
                  b0 = primColors[v0 * 3 + 2];
              final r1 = primColors[v1 * 3],
                  g1 = primColors[v1 * 3 + 1],
                  b1 = primColors[v1 * 3 + 2];
              final r2 = primColors[v2 * 3],
                  g2 = primColors[v2 * 3 + 1],
                  b2 = primColors[v2 * 3 + 2];

              final avgR = (r0 + r1 + r2) ~/ 3;
              final avgG = (g0 + g1 + g2) ~/ 3;
              final avgB = (b0 + b1 + b2) ~/ 3;

              baseCol = Color.fromRGBO(avgR, avgG, avgB, 1.0);
            } else if (baseColorFactor != null && baseColorFactor.length >= 3) {
              baseCol = Color.fromRGBO(
                (baseColorFactor[0] * 255).round().clamp(0, 255),
                (baseColorFactor[1] * 255).round().clamp(0, 255),
                (baseColorFactor[2] * 255).round().clamp(0, 255),
                1.0,
              );
            }

            allTris.add(
              _GlobalTriData(
                projPts[v0],
                projPts[v1],
                projPts[v2],
                avgDepth,
                shade,
                baseCol,
              ),
            );
          }
        }
      }

      final positions = mesh.positions;
      final indices = mesh.indices.isNotEmpty
          ? mesh.indices
          : List<int>.generate(positions.length ~/ 3, (i) => i);
      final colors = mesh.vertexColors;

      if (mesh.subPrimitives.isNotEmpty) {
        for (final subPrim in mesh.subPrimitives) {
          addCompTriangles(
            subPrim.positions,
            subPrim.indices,
            subPrim.vertexColors,
            subPrim.baseColor,
          );
        }
      } else {
        addCompTriangles(positions, indices, colors, mesh.baseColor);
      }
    }

    allTris.sort((a, b) => b.depth.compareTo(a.depth));

    final fillPaint = Paint()..style = PaintingStyle.fill;
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = Colors.cyan.withValues(alpha: 0.5);

    for (final tri in allTris) {
      final path = Path()
        ..moveTo(tri.p0.dx, tri.p0.dy)
        ..lineTo(tri.p1.dx, tri.p1.dy)
        ..lineTo(tri.p2.dx, tri.p2.dy)
        ..close();

      if (shadingMode == ViewportShadingMode.lit ||
          shadingMode == ViewportShadingMode.unlit) {
        final baseCol = tri.color;
        fillPaint.color = shadingMode == ViewportShadingMode.lit
            ? Color.fromRGBO(
                ((baseCol.r * 255) * tri.shade).round().clamp(0, 255),
                ((baseCol.g * 255) * tri.shade).round().clamp(0, 255),
                ((baseCol.b * 255) * tri.shade).round().clamp(0, 255),
                1.0,
              )
            : baseCol;
        canvas.drawPath(path, fillPaint);
      }

      if (shadingMode == ViewportShadingMode.wireframe) {
        canvas.drawPath(path, linePaint);
      }
    }
  }

  Offset _project3D(
    double x,
    double y,
    double z,
    Offset center,
    double cosY,
    double sinY,
    double cosP,
    double sinP, {
    double? scaleOverride,
  }) {
    final rx = x * cosY - y * sinY;
    final ry = x * sinY + y * cosY;

    final rz = ry * sinP + z * cosP;
    final finalY = ry * cosP - z * sinP;

    final scale = scaleOverride ?? (280.0 / (cameraDistance + finalY * 0.2));
    final screenX = center.dx + rx * scale;
    final screenY = center.dy - rz * scale;

    return Offset(screenX, screenY);
  }
}

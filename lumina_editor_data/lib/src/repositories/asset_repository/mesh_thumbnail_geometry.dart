part of '../asset_repository.dart';

/// A mesh's thumbnail drawing, worked out without `dart:ui` rendering so it
/// can be computed in a background isolate: the
/// triangles of the isometric projection [AssetRepository] draws, already
/// sorted back to front, each as three screen points in a 128 px canvas and
/// one shaded ARGB colour.
class MeshThumbnailGeometry {
  const MeshThumbnailGeometry(this.points, this.colors);

  /// `x0, y0, x1, y1, x2, y2` per triangle.
  final Float64List points;

  /// One opaque ARGB colour per triangle.
  final Uint32List colors;

  int get triangleCount => colors.length;

  /// The geometry of [type]'s thumbnail drawn from [payload] (a GLB, or OBJ
  /// text): null when the type does not draw its mesh or the payload holds
  /// none, as the thumbnail then falls back to the type's badge.
  static Future<MeshThumbnailGeometry?> forPayload(AssetType type, Uint8List? payload) async {
    if (type != AssetType.filamesh && type != AssetType.filameshSk) return null;
    if (payload == null || payload.length <= 50) return null;
    var mesh = await GlbParserService.parseGlb(payload);
    if (mesh == null) {
      try {
        mesh = ObjParserService.parseObj(utf8.decode(payload));
      } catch (_) {}
    }
    if (mesh == null || mesh.positions.isEmpty) return null;
    return MeshThumbnailGeometry.fromMesh(mesh);
  }

  /// Projects [glb] isometrically into the thumbnail (at most ~5000
  /// triangles), shades each triangle by a fixed light and colours it from
  /// its vertex colours or the mesh's base colour.
  static MeshThumbnailGeometry fromMesh(GlbMeshData glb) {
    final minX = glb.minBounds[0], minY = glb.minBounds[1], minZ = glb.minBounds[2];
    final maxX = glb.maxBounds[0], maxY = glb.maxBounds[1], maxZ = glb.maxBounds[2];

    final cx = (minX + maxX) / 2.0;
    final cy = (minY + maxY) / 2.0;
    final cz = (minZ + maxZ) / 2.0;

    final positions = glb.positions;
    final int vertCount = positions.length ~/ 3;

    final List<double> unscaledX = [];
    final List<double> unscaledY = [];
    final List<double> cameraDepths = [];
    final List<List<double>> worldPts = [];

    double minUX = double.infinity, maxUX = -double.infinity;
    double minUY = double.infinity, maxUY = -double.infinity;

    final spanY = (maxY - minY).abs();
    final spanZ = (maxZ - minZ).abs();
    final bool isZUp = (spanZ >= spanY);

    for (int i = 0; i < vertCount; i++) {
      final gltfX = positions[i * 3];
      final gltfY = positions[i * 3 + 1];
      final gltfZ = positions[i * 3 + 2];

      final double x, y, z;
      if (isZUp) {
        // Z is Up, X is Left/Right, Y is Front/Back
        x = gltfY - cy;
        y = gltfX - cx;
        z = gltfZ - cz;
      } else {
        // Y is Up, X is Left/Right, Z is Front/Back
        x = gltfZ - cz;
        y = gltfX - cx;
        z = gltfY - cy;
      }

      worldPts.add([x, y, z]);

      final uX = (x - y) * 0.707;
      final uY = (x + y) * 0.408 - z * 0.707;

      unscaledX.add(uX);
      unscaledY.add(uY);
      cameraDepths.add((x + y) * 0.707 + z * 0.707);

      if (uX < minUX) minUX = uX;
      if (uX > maxUX) maxUX = uX;
      if (uY < minUY) minUY = uY;
      if (uY > maxUY) maxUY = uY;
    }

    final spanUX = math.max(0.001, maxUX - minUX);
    final spanUY = math.max(0.001, maxUY - minUY);
    final centerUX = (minUX + maxUX) / 2.0;
    final centerUY = (minUY + maxUY) / 2.0;

    final fitScale = 96.0 / math.max(spanUX, spanUY);

    final List<ui.Offset> screenPts = [];
    for (int i = 0; i < vertCount; i++) {
      final px = 64.0 + (unscaledX[i] - centerUX) * fitScale;
      final py = 64.0 + (unscaledY[i] - centerUY) * fitScale;
      screenPts.add(ui.Offset(px, py));
    }

    if (screenPts.isEmpty) return MeshThumbnailGeometry(Float64List(0), Uint32List(0));

    const lx = 0.577, ly = 0.577, lz = 0.577;
    final indices = glb.indices.isNotEmpty
        ? glb.indices
        : List<int>.generate(vertCount, (i) => i);

    final List<_ThumbTri> triangles = [];
    final totalTriCount = (indices.length / 3).floor();
    int triStep = 1;
    if (totalTriCount > 5000) {
      triStep = (totalTriCount / 5000).ceil();
    }

    for (int i = 0; i < indices.length - 2; i += 3 * triStep) {
      final i0 = indices[i];
      final i1 = indices[i + 1];
      final i2 = indices[i + 2];

      if (i0 < vertCount && i1 < vertCount && i2 < vertCount) {
        final w0 = worldPts[i0];
        final w1 = worldPts[i1];
        final w2 = worldPts[i2];

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
        final avgDepth = (cameraDepths[i0] + cameraDepths[i1] + cameraDepths[i2]) / 3.0;

        triangles.add(_ThumbTri(screenPts[i0], screenPts[i1], screenPts[i2], avgDepth, shade, i0, i1, i2));
      }
    }

    triangles.sort((a, b) => a.depth.compareTo(b.depth));

    final vColors = glb.vertexColors;
    final modelColor = glb.baseColor;

    final points = Float64List(triangles.length * 6);
    final colors = Uint32List(triangles.length);
    for (var t = 0; t < triangles.length; t++) {
      final tri = triangles[t];
      int baseR, baseG, baseB;

      if (vColors != null && vColors.length >= vertCount * 3) {
        final idx0 = tri.i0, idx1 = tri.i1, idx2 = tri.i2;
        baseR = (vColors[idx0 * 3] + vColors[idx1 * 3] + vColors[idx2 * 3]) ~/ 3;
        baseG = (vColors[idx0 * 3 + 1] + vColors[idx1 * 3 + 1] + vColors[idx2 * 3 + 1]) ~/ 3;
        baseB = (vColors[idx0 * 3 + 2] + vColors[idx1 * 3 + 2] + vColors[idx2 * 3 + 2]) ~/ 3;
      } else {
        baseR = (modelColor[0] * 220).clamp(30, 255).toInt();
        baseG = (modelColor[1] * 225).clamp(30, 255).toInt();
        baseB = (modelColor[2] * 235).clamp(30, 255).toInt();
      }

      final r = (baseR * tri.shade).clamp(0, 255).toInt();
      final g = (baseG * tri.shade).clamp(0, 255).toInt();
      final b = (baseB * tri.shade).clamp(0, 255).toInt();

      colors[t] = 0xFF000000 | (r << 16) | (g << 8) | b;
      final o = t * 6;
      points[o] = tri.p0.dx;
      points[o + 1] = tri.p0.dy;
      points[o + 2] = tri.p1.dx;
      points[o + 3] = tri.p1.dy;
      points[o + 4] = tri.p2.dx;
      points[o + 5] = tri.p2.dy;
    }
    return MeshThumbnailGeometry(points, colors);
  }
}

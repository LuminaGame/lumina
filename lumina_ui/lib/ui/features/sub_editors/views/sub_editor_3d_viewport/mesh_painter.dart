part of '../sub_editor_3d_viewport.dart';

/// Fields shared by the software preview painter and its mesh mixins.
abstract class _SubEditor3DPainterBase extends CustomPainter {
  final GlbMeshData? glbMesh;
  final List<SubEditorMeshComponent>? meshComponents;
  final GlbNode? selectedNode;
  final PreviewShape shape;
  final ViewportShadingMode shadingMode;
  final Color baseColor;
  final double roughness;
  final double metallic;
  final double cameraYaw;
  final double cameraPitch;
  final double cameraDistance;
  final Offset cameraPan;

  /// Geometry sections left out of the drawing, driven by the mesh editors'
  /// per-slot Isolate toggle.
  final Set<int> hiddenSectionIndices;

  /// Geometry sections drawn tinted, driven by the per-slot Highlight toggle.
  final Set<int> highlightedSectionIndices;

  _SubEditor3DPainterBase({
    this.glbMesh,
    this.meshComponents,
    this.selectedNode,
    required this.shape,
    required this.shadingMode,
    // See previewColorFromParams: a material colour, not editor chrome.
    this.baseColor = const Color(0xFF00BCD4),
    this.roughness = 0.6,
    this.metallic = 0.0,
    required this.cameraYaw,
    required this.cameraPitch,
    required this.cameraDistance,
    required this.cameraPan,
    this.hiddenSectionIndices = const {},
    this.highlightedSectionIndices = const {},
  });
}

/// Base colour for the software-rendered preview, taken from the first
/// colour-typed material parameter (e.g. `baseColor`); cyan when none exists.
Color previewBaseColorFromParams(List<MaterialParamModel> params) {
  for (final p in params) {
    if (p.type != MaterialParamType.colorType &&
        p.type != MaterialParamType.vec4Type &&
        p.type != MaterialParamType.vec3Type)
      continue;
    final v = p.value;
    if (v is List && v.length >= 3 && v.every((e) => e is num)) {
      double c(int i) => (v[i] as num).toDouble().clamp(0.0, 1.0);
      final a = v.length >= 4 ? c(3) : 1.0;
      return Color.fromARGB(
        (a * 255).round(),
        (c(0) * 255).round(),
        (c(1) * 255).round(),
        (c(2) * 255).round(),
      );
    }
  }
  // The default *material* base colour of a preview surface, not an editor
  // colour: it stands in for an unset `baseColor` parameter and is matched by
  // material_preview_viewport_test.
  return const Color(0xFF00BCD4);
}

/// Scalar parameter lookup by (case-insensitive) name with a default.
double previewScalarFromParams(
  List<MaterialParamModel> params,
  String name,
  double fallback,
) {
  for (final p in params) {
    if (p.name.toLowerCase() == name.toLowerCase() && p.value is num) {
      return (p.value as num).toDouble();
    }
  }
  return fallback;
}

/// Lambert + rough specular approximation used by the software fallback:
/// darker facets away from the key light, a highlight that sharpens as
/// roughness drops, and a metallic tint that pulls the highlight toward the
/// base colour.
Color previewShadeColor(
  Color base,
  double lambert, {
  double roughness = 0.6,
  double metallic = 0.0,
}) {
  final l = lambert.clamp(0.0, 1.0);
  const ambient = 0.18;
  final diffuse = ambient + (1 - ambient) * l;
  final r = roughness.clamp(0.0, 1.0);
  final m = metallic.clamp(0.0, 1.0);
  final specPower = 2 + (1 - r) * 30;
  final spec = math.pow(l, specPower).toDouble() * (0.25 + 0.5 * (1 - r));
  int ch(double c) {
    final d = c * diffuse;
    final specTint = m * c + (1 - m);
    return ((d + spec * specTint).clamp(0.0, 1.0) * 255).round();
  }

  return Color.fromARGB(
    (base.a * 255).round(),
    ch(base.r),
    ch(base.g),
    ch(base.b),
  );
}

class _SubEditor3DPainter extends _SubEditor3DPainterBase with _SubEditor3DMeshPainting {
  _SubEditor3DPainter({
    super.glbMesh,
    super.meshComponents,
    super.selectedNode,
    required super.shape,
    required super.shadingMode,
    super.baseColor,
    super.roughness,
    super.metallic,
    required super.cameraYaw,
    required super.cameraPitch,
    required super.cameraDistance,
    required super.cameraPan,
    super.hiddenSectionIndices,
    super.highlightedSectionIndices,
  });

  /// Pushes a section's base colour towards amber so a highlighted slot reads
  /// apart from the rest without hiding anything.
  static List<double> _highlightTint(List<double> baseColor) {
    const tint = [1.0, 0.75, 0.2];
    return [
      for (var i = 0; i < 3; i++)
        (((i < baseColor.length ? baseColor[i] : 0.75) * 0.35) + tint[i] * 0.65)
            .clamp(0.0, 1.0),
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2) + cameraPan;

    final radYaw = cameraYaw * math.pi / 180.0;
    final radPitch = cameraPitch * math.pi / 180.0;

    final cosY = math.cos(radYaw);
    final sinY = math.sin(radYaw);
    final cosP = math.cos(radPitch);
    final sinP = math.sin(radPitch);

    // 1. Draw 3D Grid Floor
    _drawGridFloor(canvas, center, cosY, sinY, cosP, sinP);

    // 2. Render 3D Model / Primitive
    if (meshComponents != null && meshComponents!.isNotEmpty) {
      _renderMeshComponents(canvas, center, cosY, sinY, cosP, sinP);
    } else if (glbMesh != null &&
        glbMesh!.positions.isNotEmpty &&
        shape == PreviewShape.mesh) {
      _renderGlbMesh(canvas, center, cosY, sinY, cosP, sinP);
    } else {
      _renderPrimitiveShape(canvas, center, cosY, sinY, cosP, sinP);
    }

    // 3. Draw Axis Triad Overlay at bottom right
    _drawAxisTriad(canvas, size, cosY, sinY, cosP, sinP);
  }

  void _drawGridFloor(
    Canvas canvas,
    Offset center,
    double cosY,
    double sinY,
    double cosP,
    double sinP,
  ) {
    final gridPaint = Paint()
      ..color = EditorColors.cardHeader
      ..strokeWidth = 1.0;

    final axisXPaint = Paint()
      ..color = Colors.red.withValues(alpha: 0.6)
      ..strokeWidth = 1.5;

    final axisYPaint = Paint()
      ..color = Colors.green.withValues(alpha: 0.6)
      ..strokeWidth = 1.5;

    const gridSize = 10;
    const step = 25.0;

    for (int i = -gridSize; i <= gridSize; i++) {
      final p1 = _project3D(
        i * step,
        -gridSize * step,
        0,
        center,
        cosY,
        sinY,
        cosP,
        sinP,
      );
      final p2 = _project3D(
        i * step,
        gridSize * step,
        0,
        center,
        cosY,
        sinY,
        cosP,
        sinP,
      );
      canvas.drawLine(p1, p2, i == 0 ? axisYPaint : gridPaint);

      final p3 = _project3D(
        -gridSize * step,
        i * step,
        0,
        center,
        cosY,
        sinY,
        cosP,
        sinP,
      );
      final p4 = _project3D(
        gridSize * step,
        i * step,
        0,
        center,
        cosY,
        sinY,
        cosP,
        sinP,
      );
      canvas.drawLine(p3, p4, i == 0 ? axisXPaint : gridPaint);
    }
  }

  void _renderPrimitiveShape(
    Canvas canvas,
    Offset center,
    double cosY,
    double sinY,
    double cosP,
    double sinP,
  ) {
    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = baseColor.withValues(alpha: 0.9);
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.cyan;
    // Key light direction (view space) for the software Lambert shading.
    const lx = -0.45, ly = -0.6, lz = 0.66;

    if (shape == PreviewShape.cube) {
      const s = 60.0;
      final vertices = [
        [-s, -s, 0.0],
        [s, -s, 0.0],
        [s, s, 0.0],
        [-s, s, 0.0],
        [-s, -s, s * 2],
        [s, -s, s * 2],
        [s, s, s * 2],
        [-s, s, s * 2],
      ];
      final faces = [
        [0, 1, 2, 3],
        [4, 5, 6, 7],
        [0, 1, 5, 4],
        [1, 2, 6, 5],
        [2, 3, 7, 6],
        [3, 0, 4, 7],
      ];
      const faceNormals = [
        [0.0, 0.0, -1.0],
        [0.0, 0.0, 1.0],
        [0.0, -1.0, 0.0],
        [1.0, 0.0, 0.0],
        [0.0, 1.0, 0.0],
        [-1.0, 0.0, 0.0],
      ];

      for (var fi = 0; fi < faces.length; fi++) {
        final f = faces[fi];
        final n = faceNormals[fi];
        // rotate the normal by yaw/pitch to view space
        final nx1 = n[0] * cosY - n[1] * sinY;
        final ny1 = n[0] * sinY + n[1] * cosY;
        final ny2 = ny1 * cosP - n[2] * sinP;
        final nz2 = ny1 * sinP + n[2] * cosP;
        final lambert = (nx1 * lx + ny2 * ly + nz2 * lz).clamp(0.0, 1.0);
        fillPaint.color = previewShadeColor(
          baseColor,
          lambert,
          roughness: roughness,
          metallic: metallic,
        );
        final p1 = _project3D(
          vertices[f[0]][0],
          vertices[f[0]][1],
          vertices[f[0]][2],
          center,
          cosY,
          sinY,
          cosP,
          sinP,
        );
        final p2 = _project3D(
          vertices[f[1]][0],
          vertices[f[1]][1],
          vertices[f[1]][2],
          center,
          cosY,
          sinY,
          cosP,
          sinP,
        );
        final p3 = _project3D(
          vertices[f[2]][0],
          vertices[f[2]][1],
          vertices[f[2]][2],
          center,
          cosY,
          sinY,
          cosP,
          sinP,
        );
        final p4 = _project3D(
          vertices[f[3]][0],
          vertices[f[3]][1],
          vertices[f[3]][2],
          center,
          cosY,
          sinY,
          cosP,
          sinP,
        );

        final path = Path()
          ..moveTo(p1.dx, p1.dy)
          ..lineTo(p2.dx, p2.dy)
          ..lineTo(p3.dx, p3.dy)
          ..lineTo(p4.dx, p4.dy)
          ..close();

        if (shadingMode != ViewportShadingMode.wireframe)
          canvas.drawPath(path, fillPaint);
        if (shadingMode == ViewportShadingMode.wireframe)
          canvas.drawPath(path, linePaint);
      }
    } else {
      // Sphere / Cylinder 3D wireframe wiremesh
      const radius = 65.0;
      const latCount = 10;
      const lonCount = 14;

      for (int i = 0; i <= latCount; i++) {
        final lat = math.pi * (-0.5 + (i.toDouble() / latCount));
        final z = radius * math.sin(lat) + radius;
        final r = radius * math.cos(lat);

        final path = Path();
        for (int j = 0; j <= lonCount; j++) {
          final lon = 2 * math.pi * (j.toDouble() / lonCount);
          final x = r * math.cos(lon);
          final y = r * math.sin(lon);
          final pt = _project3D(x, y, z, center, cosY, sinY, cosP, sinP);
          if (j == 0) {
            path.moveTo(pt.dx, pt.dy);
          } else {
            path.lineTo(pt.dx, pt.dy);
          }
        }
        if (shadingMode != ViewportShadingMode.wireframe) {
          // Band normal ≈ (0, cos(lat) toward viewer, sin(lat)); shade with the key light.
          final lambert = (math.cos(lat) * 0.55 + math.sin(lat) * lz).clamp(
            0.0,
            1.0,
          );
          fillPaint.color = previewShadeColor(
            baseColor,
            lambert,
            roughness: roughness,
            metallic: metallic,
          );
          canvas.drawPath(path, fillPaint);
        }
        canvas.drawPath(path, linePaint);
      }
    }
  }

  void _drawAxisTriad(
    Canvas canvas,
    Size size,
    double cosY,
    double sinY,
    double cosP,
    double sinP,
  ) {
    final triadCenter = Offset(size.width - 40, size.height - 40);
    const len = 25.0;

    final xPt = _project3D(
      len,
      0,
      0,
      triadCenter,
      cosY,
      sinY,
      cosP,
      sinP,
      scaleOverride: 0.3,
    );
    final yPt = _project3D(
      0,
      len,
      0,
      triadCenter,
      cosY,
      sinY,
      cosP,
      sinP,
      scaleOverride: 0.3,
    );
    final zPt = _project3D(
      0,
      0,
      len,
      triadCenter,
      cosY,
      sinY,
      cosP,
      sinP,
      scaleOverride: 0.3,
    );

    canvas.drawLine(
      triadCenter,
      xPt,
      Paint()
        ..color = Colors.red
        ..strokeWidth = 2.0,
    );
    canvas.drawLine(
      triadCenter,
      yPt,
      Paint()
        ..color = Colors.green
        ..strokeWidth = 2.0,
    );
    canvas.drawLine(
      triadCenter,
      zPt,
      Paint()
        ..color = Colors.blue
        ..strokeWidth = 2.0,
    );
  }

  @override
  bool shouldRepaint(covariant _SubEditor3DPainter oldDelegate) => true;
}

class _GlobalTriData {
  final Offset p0;
  final Offset p1;
  final Offset p2;
  final double depth;
  final double shade;
  final Color color;

  const _GlobalTriData(
    this.p0,
    this.p1,
    this.p2,
    this.depth,
    this.shade,
    this.color,
  );
}

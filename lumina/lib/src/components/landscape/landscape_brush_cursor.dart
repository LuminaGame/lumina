import 'dart:math' as math;
import 'dart:typed_data';

import 'package:vector_math/vector_math_64.dart' show Vector3;

import 'package:lumina_core/lumina_core.dart';

/// Where and how a sculpt or foliage brush is drawn on a terrain.
///
/// Positions and the radius are **world units** — the space of
/// `LuminaLandscapeComponent.sampleHeightAtWorld` — so an editor passes what
/// its raycast returned without knowing the terrain's own scale.
class LandscapeBrushCursor {
  final double centerX;
  final double centerZ;

  /// Outer radius: where the brush's influence ends.
  final double radius;

  /// Fraction of [radius] that fades out; the full-strength core ends at
  /// `radius × (1 − falloff)`.
  final double falloff;

  /// Linear RGB, 0–1.
  final Vector3 color;

  LandscapeBrushCursor({
    required this.centerX,
    required this.centerZ,
    required this.radius,
    this.falloff = 0.5,
    Vector3? color,
  }) : color = color ?? Vector3(1.0, 0.72, 0.18);

  @override
  String toString() => 'LandscapeBrushCursor(($centerX, $centerZ), r $radius, falloff $falloff)';
}

/// What a ring of cursor vertices draws.
enum LandscapeCursorRing {
  /// The translucent disc: solid in the core, fading across the falloff band.
  fill,

  /// The crisp ring at the end of the full-strength core (both edges of it).
  innerLine,

  /// The inner edge of the crisp ring at the brush's radius.
  outerLine,

  /// The outermost ring of vertices, exactly at the brush's radius.
  outerEdge,
}

/// The cursor mesh: pure maths over a heightmap, with a topology that never
/// changes (so moving or resizing the cursor is one in-place upload).
///
/// Vertices are laid out ring by ring, [segments] per ring, and draped on the
/// heightmap's bilinear surface plus a small lift. Colours are premultiplied
/// by their alpha (Filament's translucent blending).
class LandscapeBrushCursorGeometry {
  /// Vertices per ring.
  static const int defaultSegments = 128;

  /// Rings in the full-strength core (after the centre) and in the falloff band.
  static const int coreRings = 12;
  static const int bandRings = 16;

  /// Fill opacity in the core, of 255.
  static const int fillAlpha = 72;

  /// Opacity of the two crisp rings, of 255.
  static const int lineAlpha = 235;

  final Float32List positions;
  final Float32List uv0;
  final Uint8List colors;
  final Uint32List indices;
  final int segments;

  /// Width of the crisp rings, in the same units as [positions].
  final double lineWidth;

  final List<double> _ringT;
  final List<LandscapeCursorRing> _ringKind;

  LandscapeBrushCursorGeometry._(
    this.positions,
    this.uv0,
    this.colors,
    this.indices,
    this.segments,
    this.lineWidth,
    this._ringT,
    this._ringKind,
  );

  int get vertexCount => positions.length ~/ 3;
  int get ringCount => _ringT.length;

  /// Normalised radius (0 centre → 1 rim) of vertex [v]'s ring.
  double ringTOf(int v) => _ringT[v ~/ segments];

  /// What vertex [v]'s ring draws.
  LandscapeCursorRing ringOf(int v) => _ringKind[v ~/ segments];

  /// Every vertex of the rings of [kind].
  List<int> verticesOf(LandscapeCursorRing kind) => [
        for (var ring = 0; ring < _ringKind.length; ring++)
          if (_ringKind[ring] == kind)
            for (var s = 0; s < segments; s++) ring * segments + s,
      ];

  /// The fill's opacity profile, 0–1: 1 in the core, a smooth fade to 0
  /// across the falloff band.
  static double fillWeight(double t, double falloff) {
    final inner = 1.0 - falloff.clamp(0.0, 1.0);
    if (t <= inner) return 1.0;
    if (inner >= 1.0) return 0.0;
    final f = ((t - inner) / (1.0 - inner)).clamp(0.0, 1.0);
    return 1.0 - f * f * (3.0 - 2.0 * f);
  }

  /// Builds the cursor centred on ([centerX], [centerZ]) with [radius] — all
  /// in the terrain's own metres — and returns positions scaled by
  /// [unitsPerMetre].
  ///
  /// [lineWidth] (metres) defaults to 2.5 % of the radius, at least 15 % of a
  /// terrain cell, so the rings read at any brush size.
  static LandscapeBrushCursorGeometry build(
    LandscapeData data, {
    required double centerX,
    required double centerZ,
    required double radius,
    double falloff = 0.5,
    Vector3? color,
    double unitsPerMetre = 1.0,
    int segments = defaultSegments,
    double? lineWidth,
  }) {
    final r = math.max(radius, 1e-3);
    final fo = falloff.clamp(0.0, 1.0);
    final inner = 1.0 - fo;
    final width = math.min(lineWidth ?? math.max(r * 0.025, data.cellSize * 0.15), r * 0.2);
    final hw = width / 2 / r;
    final hasInnerRing = fo >= 0.02 && inner * r > width;

    // Ring layout (fixed): fill = centre + core + band; inner line = 2 rings;
    // outer line = 2 rings (the outer one is the exact rim).
    final ringT = <double>[];
    final ringKind = <LandscapeCursorRing>[];
    void ring(double t, LandscapeCursorRing kind) {
      ringT.add(t.clamp(0.0, 1.0));
      ringKind.add(kind);
    }

    ring(0.0, LandscapeCursorRing.fill);
    for (var k = 1; k <= coreRings; k++) {
      ring(inner * k / coreRings, LandscapeCursorRing.fill);
    }
    for (var k = 1; k <= bandRings; k++) {
      ring(inner + (1.0 - inner) * k / bandRings, LandscapeCursorRing.fill);
    }
    final innerT = hasInnerRing ? inner : math.max(inner, hw);
    ring(innerT - hw, LandscapeCursorRing.innerLine);
    ring(innerT + hw, LandscapeCursorRing.innerLine);
    ring(1.0 - 2 * hw, LandscapeCursorRing.outerLine);
    ring(1.0, LandscapeCursorRing.outerEdge);

    final rgb = color ?? Vector3(1.0, 0.72, 0.18);
    final cr = (rgb.x.clamp(0.0, 1.0) * 255).round();
    final cg = (rgb.y.clamp(0.0, 1.0) * 255).round();
    final cb = (rgb.z.clamp(0.0, 1.0) * 255).round();

    final rings = ringT.length;
    final count = rings * segments;
    final positions = Float32List(count * 3);
    final uv0 = Float32List(count * 2);
    final colors = Uint8List(count * 4);

    // Draped on the bilinear surface, lifted a little. The component draws
    // the cursor without depth testing, so it can neither sink into a
    // triangle nor be cut by the ground; lifting to the highest nearby sample
    // instead made it float and step over steep flanks.
    final lift = math.max(data.cellSize * 0.05, 0.05);

    for (var ri = 0; ri < rings; ri++) {
      final t = ringT[ri];
      final kind = ringKind[ri];
      final int alpha;
      switch (kind) {
        case LandscapeCursorRing.fill:
          alpha = (fillAlpha * fillWeight(t, fo)).round();
        case LandscapeCursorRing.innerLine:
          alpha = hasInnerRing ? lineAlpha : 0;
        case LandscapeCursorRing.outerLine:
        case LandscapeCursorRing.outerEdge:
          alpha = lineAlpha;
      }
      // Premultiplied: Filament blends translucent materials as
      // (ONE, ONE_MINUS_SRC_ALPHA) and the unlit ubershader does not
      // premultiply the vertex colour itself.
      final pr = (cr * alpha / 255).round();
      final pg = (cg * alpha / 255).round();
      final pb = (cb * alpha / 255).round();
      for (var s = 0; s < segments; s++) {
        final a = 2 * math.pi * s / segments;
        final x = centerX + r * t * math.cos(a);
        final z = centerZ + r * t * math.sin(a);
        final y = data.sampleHeight(x, z) + lift;
        final v = ri * segments + s;
        positions[v * 3] = x * unitsPerMetre;
        positions[v * 3 + 1] = y * unitsPerMetre;
        positions[v * 3 + 2] = z * unitsPerMetre;
        uv0[v * 2] = s / segments;
        uv0[v * 2 + 1] = t;
        colors[v * 4] = pr;
        colors[v * 4 + 1] = pg;
        colors[v * 4 + 2] = pb;
        colors[v * 4 + 3] = alpha;
      }
    }

    // Strips between consecutive rings of the same band: the fill (rings
    // 0..fillRings-1), the inner line (2 rings), the outer line (2 rings).
    final fillRings = 1 + coreRings + bandRings;
    final strips = <(int, int)>[(0, fillRings - 1), (fillRings, fillRings + 1), (fillRings + 2, fillRings + 3)];
    var quads = 0;
    for (final (first, last) in strips) {
      quads += (last - first) * segments;
    }
    final indices = Uint32List(quads * 6);
    var k = 0;
    for (final (first, last) in strips) {
      for (var ri = first; ri < last; ri++) {
        for (var s = 0; s < segments; s++) {
          final s1 = (s + 1) % segments;
          final a = ri * segments + s;
          final b = ri * segments + s1;
          final c = (ri + 1) * segments + s;
          final d = (ri + 1) * segments + s1;
          indices[k++] = a;
          indices[k++] = c;
          indices[k++] = b;
          indices[k++] = b;
          indices[k++] = c;
          indices[k++] = d;
        }
      }
    }

    return LandscapeBrushCursorGeometry._(
      positions,
      uv0,
      colors,
      indices,
      segments,
      width * unitsPerMetre,
      ringT,
      ringKind,
    );
  }
}

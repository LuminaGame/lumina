import 'dart:math' as math;
import 'dart:typed_data';

import 'package:lumina_editor_data/lumina_editor.dart';

// The heightmap payload, the dirty-rect type and the section/tile map live in
// package:lumina so the engine's LuminaLandscapeComponent and this editor
// share exactly one implementation. Re-exported here so the editor's own
// imports stay stable.
export 'package:lumina_editor_data/lumina_editor.dart'
    show
        FoliageInstance,
        FoliageLayer,
        FoliageRules,
        HeightRect,
        LandscapeData,
        LandscapeSectionMap,
        SectionUpdateWindow;

/// The sculpt tools the engine can honestly back today.
///
/// Ramp / Erosion / Hydro and weight-blended texture layer
/// painting are **not** here: they need a multi-layer terrain material and
/// simulation passes that neither lumina nor flutter_filament define yet.
enum LandscapeTool { sculpt, smooth, flatten, noise }

/// Brush falloff curves, matching the editor's `Falloff Type` select.
enum LandscapeFalloffType { smooth, linear, spherical, tip }

/// One brush stamp's parameters.
class LandscapeBrushSettings {
  final LandscapeTool tool;

  /// Brush radius in metres.
  final double radius;

  /// Metres of height change at full weight (sculpt/noise), or the pull
  /// fraction for flatten/smooth.
  final double strength;

  /// Fraction of [radius] that fades out; `0` is a hard-edged cylinder,
  /// `1` fades from the very centre.
  final double falloff;
  final LandscapeFalloffType falloffType;

  /// Shift-held: sculpt lowers instead of raising.
  final bool invert;

  const LandscapeBrushSettings({
    required this.tool,
    required this.radius,
    required this.strength,
    required this.falloff,
    required this.falloffType,
    this.invert = false,
  });

  LandscapeBrushSettings copyWith({
    LandscapeTool? tool,
    double? radius,
    double? strength,
    double? falloff,
    LandscapeFalloffType? falloffType,
    bool? invert,
  }) {
    return LandscapeBrushSettings(
      tool: tool ?? this.tool,
      radius: radius ?? this.radius,
      strength: strength ?? this.strength,
      falloff: falloff ?? this.falloff,
      falloffType: falloffType ?? this.falloffType,
      invert: invert ?? this.invert,
    );
  }
}

/// Pure heightmap maths: every brush is a function over `LandscapeData.heights`
/// returning the dirty rect it touched. No GPU, no engine types — the editor,
/// the tests and the smoke run all exercise the identical code.
class LandscapeBrush {
  const LandscapeBrush._();

  /// Brush weight at normalised distance [t] (`0` centre → `1` edge).
  static double weightAt(double t, double falloff, LandscapeFalloffType type) {
    if (t <= 0.0) return 1.0;
    if (t >= 1.0) return 0.0;
    final inner = (1.0 - falloff.clamp(0.0, 1.0));
    if (t <= inner) return 1.0;
    final f = inner >= 1.0 ? 0.0 : ((t - inner) / (1.0 - inner)).clamp(0.0, 1.0);
    switch (type) {
      case LandscapeFalloffType.linear:
        return 1.0 - f;
      case LandscapeFalloffType.smooth:
        return 1.0 - (f * f * (3.0 - 2.0 * f));
      case LandscapeFalloffType.spherical:
        return math.sqrt(math.max(0.0, 1.0 - f * f));
      case LandscapeFalloffType.tip:
        final u = 1.0 - f;
        return 1.0 - math.sqrt(math.max(0.0, 1.0 - u * u));
    }
  }

  /// Applies one stamp of [settings] centred on the world position
  /// ([worldX], [worldZ]) and returns the cells it covered, or null when the
  /// stamp fell entirely outside the terrain.
  ///
  /// [flattenTarget] is the height sampled at the stroke's start (required by
  /// [LandscapeTool.flatten]); [noiseSeed] makes [LandscapeTool.noise]
  /// reproducible per stroke.
  static HeightRect? stamp(
    LandscapeData data,
    LandscapeBrushSettings settings,
    double worldX,
    double worldZ, {
    double? flattenTarget,
    int noiseSeed = 0,
  }) {
    final radius = settings.radius;
    if (radius <= 0.0) return null;
    final res = data.gridResolution;
    final cell = data.cellSize;
    final cCentre = data.columnOf(worldX);
    final rCentre = data.rowOf(worldZ);
    final span = radius / cell;
    final minCol = (cCentre - span).floor();
    final maxCol = (cCentre + span).ceil();
    final minRow = (rCentre - span).floor();
    final maxRow = (rCentre + span).ceil();
    if (maxCol < 0 || maxRow < 0 || minCol > res - 1 || minRow > res - 1) return null;

    // Smooth needs a read-only copy so the kernel never reads its own output
    // mid-pass — but only of the cells the kernel actually reads (the brush
    // rect grown by one ring). Copying the whole heightmap would be 264 MB at
    // 8129²; this is a few hundred kilobytes at any brush size.
    final _SmoothSource? source = settings.tool == LandscapeTool.smooth
        ? _SmoothSource.of(
            data,
            math.max(0, minCol - 1),
            math.max(0, minRow - 1),
            math.min(res - 1, maxCol + 1),
            math.min(res - 1, maxRow + 1),
          )
        : null;

    var touchedMinCol = res, touchedMinRow = res, touchedMaxCol = -1, touchedMaxRow = -1;
    for (var r = math.max(0, minRow); r <= math.min(res - 1, maxRow); r++) {
      final z = data.worldZOf(r);
      for (var c = math.max(0, minCol); c <= math.min(res - 1, maxCol); c++) {
        final x = data.worldXOf(c);
        final dx = x - worldX;
        final dz = z - worldZ;
        final dist = math.sqrt(dx * dx + dz * dz);
        if (dist > radius) continue;
        if (c < touchedMinCol) touchedMinCol = c;
        if (c > touchedMaxCol) touchedMaxCol = c;
        if (r < touchedMinRow) touchedMinRow = r;
        if (r > touchedMaxRow) touchedMaxRow = r;

        final w = weightAt(dist / radius, settings.falloff, settings.falloffType);
        if (w <= 0.0) continue;
        final h = data.heightAt(c, r);
        switch (settings.tool) {
          case LandscapeTool.sculpt:
            final delta = settings.strength * w * (settings.invert ? -1.0 : 1.0);
            data.setHeight(c, r, h + delta);
            break;
          case LandscapeTool.smooth:
            var sum = 0.0;
            var n = 0;
            for (var kr = r - 1; kr <= r + 1; kr++) {
              for (var kc = c - 1; kc <= c + 1; kc++) {
                if (kc < 0 || kr < 0 || kc >= res || kr >= res) continue;
                sum += source!.at(kc, kr);
                n++;
              }
            }
            final blurred = sum / n;
            final k = (w * settings.strength).clamp(0.0, 1.0);
            data.setHeight(c, r, h + (blurred - h) * k);
            break;
          case LandscapeTool.flatten:
            final target = flattenTarget ?? h;
            final k = (w * settings.strength).clamp(0.0, 1.0);
            data.setHeight(c, r, h + (target - h) * k);
            break;
          case LandscapeTool.noise:
            final n = _noise(noiseSeed, c, r) * 2.0 - 1.0;
            data.setHeight(c, r, h + n * settings.strength * w);
            break;
        }
      }
    }
    if (touchedMaxCol < 0) return null;
    return HeightRect(touchedMinCol, touchedMinRow, touchedMaxCol, touchedMaxRow);
  }

  /// Deterministic value noise in `[0, 1)` for a seed and cell.
  static double _noise(int seed, int col, int row) {
    var h = (seed * 374761393 + col * 668265263 + row * 1274126177) & 0x7fffffff;
    h = (h ^ (h >> 13)) & 0x7fffffff;
    h = (h * 1274126177) & 0x7fffffff;
    h = (h ^ (h >> 16)) & 0x7fffffff;
    return h / 0x7fffffff;
  }
}

/// A rectangular read-only snapshot of the heightmap, used by the Smooth
/// brush so its 3×3 kernel never reads cells it has already written.
///
/// Rect-sized rather than grid-sized: the sculpt path must never touch every
/// sample, and at 8129² a full copy is 264 MB.
class _SmoothSource {
  final int minCol;
  final int minRow;
  final int cols;
  final int rows;
  final Float32List values;

  const _SmoothSource._(this.minCol, this.minRow, this.cols, this.rows, this.values);

  factory _SmoothSource.of(LandscapeData data, int minCol, int minRow, int maxCol, int maxRow) {
    final cols = maxCol - minCol + 1;
    final rows = maxRow - minRow + 1;
    final values = Float32List(cols * rows);
    var i = 0;
    for (var r = minRow; r <= maxRow; r++) {
      for (var c = minCol; c <= maxCol; c++) {
        values[i++] = data.heightAt(c, r);
      }
    }
    return _SmoothSource._(minCol, minRow, cols, rows, values);
  }

  /// Height at a grid cell, clamped to the snapshot's own edge (the kernel
  /// only ever asks for cells inside the grown rect).
  double at(int col, int row) {
    final c = (col - minCol).clamp(0, cols - 1);
    final r = (row - minRow).clamp(0, rows - 1);
    return values[r * cols + c];
  }
}

/// Foliage scattering and erasing over a real heightmap.
///
/// Both honour the foliage brush's falloff: the weight
/// of a point at normalised distance `t` is [LandscapeBrush.weightAt] with
/// the Smooth curve — the sculpt brush's own — so instances thin out across
/// the falloff band instead of stopping at a hard circle.
class LandscapeFoliagePainter {
  const LandscapeFoliagePainter._();

  /// The foliage brush's weight at normalised distance [t].
  static double weightAt(double t, double falloff) =>
      LandscapeBrush.weightAt(t, falloff, LandscapeFalloffType.smooth);

  /// ∫ weight dA over a brush of [radius] (m²): the area a pass effectively
  /// covers at full density.
  static double effectiveArea(double radius, double falloff) {
    const steps = 64;
    var sum = 0.0;
    for (var i = 0; i < steps; i++) {
      final t = (i + 0.5) / steps;
      sum += weightAt(t, falloff) * t;
    }
    return 2 * math.pi * radius * radius * sum / steps;
  }

  /// Rejection-samples instances inside the brush circle honouring the
  /// layer's density, min spacing (against the instances already in [layer]
  /// and the ones placed in this call), slope range, random scale, random yaw
  /// and normal alignment. Heights come from a bilinear heightmap sample.
  ///
  /// [falloff] thins the placement towards the rim: a candidate at `t` is
  /// kept with probability `weightAt(t)`, and the pass aims at
  /// `density × densityScale × effectiveArea / 100` instances, so the core
  /// gets the layer's density × [densityScale] (the Paint Density).
  static List<FoliageInstance> scatter({
    required LandscapeData data,
    required FoliageLayer layer,
    required double centerX,
    required double centerZ,
    required double radius,
    required math.Random random,
    double falloff = 0.0,
    double densityScale = 1.0,
  }) {
    final rules = layer.rules;
    final placed = <FoliageInstance>[];
    if (radius <= 0 || densityScale <= 0) return placed;
    final area = math.pi * radius * radius;
    final effArea = effectiveArea(radius, falloff);
    final target = (rules.density * densityScale * effArea / 100.0).round();
    if (target <= 0) return placed;

    // Existing instances of this layer that could violate the spacing rule.
    final neighbourhood = <FoliageInstance>[];
    final guard = radius + rules.minSpacing;
    for (var i = 0; i < layer.instanceCount; i++) {
      final inst = layer.instanceAt(i);
      final dx = inst.x - centerX;
      final dz = inst.z - centerZ;
      if (dx * dx + dz * dz <= guard * guard) neighbourhood.add(inst);
    }

    final spacing2 = rules.minSpacing * rules.minSpacing;
    // Falloff rejects candidates too, so a soft brush needs more attempts.
    final attempts = math.max(256, (target * 60 / math.max(effArea / area, 0.05)).ceil());
    for (var a = 0; a < attempts && placed.length < target; a++) {
      final angle = random.nextDouble() * 2 * math.pi;
      final t = math.sqrt(random.nextDouble());
      if (random.nextDouble() >= weightAt(t, falloff)) continue;
      final x = centerX + radius * t * math.cos(angle);
      final z = centerZ + radius * t * math.sin(angle);
      if (!data.contains(x, z)) continue;

      final slope = data.sampleSlopeDegrees(x, z);
      if (slope < rules.slopeMinDegrees || slope > rules.slopeMaxDegrees) continue;

      var blocked = false;
      for (final n in neighbourhood) {
        final dx = n.x - x;
        final dz = n.z - z;
        if (dx * dx + dz * dz < spacing2) {
          blocked = true;
          break;
        }
      }
      if (blocked) continue;
      for (final n in placed) {
        final dx = n.x - x;
        final dz = n.z - z;
        if (dx * dx + dz * dz < spacing2) {
          blocked = true;
          break;
        }
      }
      if (blocked) continue;

      final scale = rules.scaleMin + random.nextDouble() * math.max(0.0, rules.scaleMax - rules.scaleMin);
      final yaw = rules.randomYaw ? random.nextDouble() * 2 * math.pi : 0.0;
      final normal = rules.alignToNormal ? data.sampleNormal(x, z) : null;
      placed.add(FoliageInstance(
        x: x,
        y: data.sampleHeight(x, z),
        z: z,
        scaleX: scale,
        scaleY: scale,
        scaleZ: scale,
        yaw: yaw,
        nx: normal?.x ?? 0.0,
        ny: normal?.y ?? 1.0,
        nz: normal?.z ?? 0.0,
      ));
    }
    return placed;
  }

  /// Indices of [layer]'s instances inside a circle, ascending.
  static List<int> instancesInCircle(FoliageLayer layer, double centerX, double centerZ, double radius) {
    final hits = <int>[];
    final r2 = radius * radius;
    for (var i = 0; i < layer.instanceCount; i++) {
      final inst = layer.instanceAt(i);
      final dx = inst.x - centerX;
      final dz = inst.z - centerZ;
      if (dx * dx + dz * dz <= r2) hits.add(i);
    }
    return hits;
  }

  /// Indices (ascending) of the instances one erase pass removes: an instance
  /// at `t` goes with probability `weightAt(t) × (1 − eraseDensity)`.
  ///
  /// Erase Density 0 clears the full-strength core and thins the falloff
  /// band; 0.5 halves the core per pass (the Erase Density is what the
  /// brush thins the layer down to).
  static List<int> instancesToErase(
    FoliageLayer layer,
    double centerX,
    double centerZ,
    double radius, {
    required math.Random random,
    double falloff = 0.0,
    double eraseDensity = 0.0,
  }) {
    final keep = eraseDensity.clamp(0.0, 1.0);
    final out = <int>[];
    if (radius <= 0) return out;
    for (final i in instancesInCircle(layer, centerX, centerZ, radius)) {
      final inst = layer.instanceAt(i);
      final dx = inst.x - centerX;
      final dz = inst.z - centerZ;
      final t = math.sqrt(dx * dx + dz * dz) / radius;
      if (random.nextDouble() < weightAt(t, falloff) * (1.0 - keep)) out.add(i);
    }
    return out;
  }
}

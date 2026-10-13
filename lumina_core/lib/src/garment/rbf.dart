import 'dart:math' as math;
import 'dart:typed_data';

/// A smooth 3D displacement field through control points: polyharmonic
/// `φ(r) = r³` radial basis functions plus an affine part, fitted so every
/// control point moves exactly by its displacement.
class LuminaRbfField {
  LuminaRbfField._(this._centres, this._weights, this._affine);

  final Float64List _centres; // xyz per control point
  final Float64List _weights; // xyz per control point
  final Float64List _affine; // 4 rows (1, x, y, z) × 3 columns

  int get controlCount => _centres.length ~/ 3;

  /// The field moving each of [from] (xyz per point) by [to] − [from].
  /// Fewer than four points give a translation (their mean displacement).
  factory LuminaRbfField.fit(List<double> from, List<double> to, {double smoothing = 0}) {
    final n = from.length ~/ 3;
    final centres = Float64List.fromList(from);
    if (n < 4) {
      final mean = [0.0, 0.0, 0.0];
      for (var i = 0; i < n; i++) {
        for (var k = 0; k < 3; k++) {
          mean[k] += (to[i * 3 + k] - from[i * 3 + k]) / n;
        }
      }
      return LuminaRbfField._(Float64List(0), Float64List(0), Float64List.fromList([mean[0], mean[1], mean[2], 0, 0, 0, 0, 0, 0, 0, 0, 0]));
    }
    final m = n + 4;
    final a = Float64List(m * m);
    final b = Float64List(m * 3);
    for (var i = 0; i < n; i++) {
      for (var j = 0; j < n; j++) {
        final dx = from[i * 3] - from[j * 3], dy = from[i * 3 + 1] - from[j * 3 + 1], dz = from[i * 3 + 2] - from[j * 3 + 2];
        final r = math.sqrt(dx * dx + dy * dy + dz * dz);
        a[i * m + j] = r * r * r;
      }
      a[i * m + i] += smoothing;
      final p = [1.0, from[i * 3], from[i * 3 + 1], from[i * 3 + 2]];
      for (var k = 0; k < 4; k++) {
        a[i * m + n + k] = p[k];
        a[(n + k) * m + i] = p[k];
      }
      for (var k = 0; k < 3; k++) {
        b[i * 3 + k] = to[i * 3 + k] - from[i * 3 + k];
      }
    }
    final x = _solve(a, b, m, 3);
    return LuminaRbfField._(centres, Float64List.sublistView(x, 0, n * 3), Float64List.sublistView(x, n * 3, m * 3));
  }

  /// The displacement at (x, y, z), written to [out] (3 values).
  void displacement(double x, double y, double z, List<double> out) {
    var ox = _affine[0] + _affine[3] * x + _affine[6] * y + _affine[9] * z;
    var oy = _affine[1] + _affine[4] * x + _affine[7] * y + _affine[10] * z;
    var oz = _affine[2] + _affine[5] * x + _affine[8] * y + _affine[11] * z;
    final c = _centres, w = _weights;
    for (var i = 0; i + 2 < c.length; i += 3) {
      final dx = x - c[i], dy = y - c[i + 1], dz = z - c[i + 2];
      final r = math.sqrt(dx * dx + dy * dy + dz * dz);
      final phi = r * r * r;
      ox += w[i] * phi;
      oy += w[i + 1] * phi;
      oz += w[i + 2] * phi;
    }
    out[0] = ox;
    out[1] = oy;
    out[2] = oz;
  }

  /// Solves A X = B (A m×m, B m×k, row-major) by Gaussian elimination with
  /// partial pivoting; returns X (m×k).
  static Float64List _solve(Float64List a, Float64List b, int m, int k) {
    for (var col = 0; col < m; col++) {
      var pivot = col;
      var best = a[col * m + col].abs();
      for (var r = col + 1; r < m; r++) {
        final v = a[r * m + col].abs();
        if (v > best) {
          best = v;
          pivot = r;
        }
      }
      if (best < 1e-14) continue;
      if (pivot != col) {
        for (var c = 0; c < m; c++) {
          final t = a[col * m + c];
          a[col * m + c] = a[pivot * m + c];
          a[pivot * m + c] = t;
        }
        for (var c = 0; c < k; c++) {
          final t = b[col * k + c];
          b[col * k + c] = b[pivot * k + c];
          b[pivot * k + c] = t;
        }
      }
      final inv = 1 / a[col * m + col];
      for (var r = col + 1; r < m; r++) {
        final f = a[r * m + col] * inv;
        if (f == 0) continue;
        for (var c = col; c < m; c++) {
          a[r * m + c] -= f * a[col * m + c];
        }
        for (var c = 0; c < k; c++) {
          b[r * k + c] -= f * b[col * k + c];
        }
      }
    }
    final x = Float64List(m * k);
    for (var r = m - 1; r >= 0; r--) {
      final d = a[r * m + r];
      for (var c = 0; c < k; c++) {
        var s = b[r * k + c];
        for (var j = r + 1; j < m; j++) {
          s -= a[r * m + j] * x[j * k + c];
        }
        x[r * k + c] = d.abs() < 1e-14 ? 0 : s / d;
      }
    }
    return x;
  }
}

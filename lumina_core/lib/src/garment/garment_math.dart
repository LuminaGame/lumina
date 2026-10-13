import 'dart:math' as math;

/// A ray's nearest hit on a mesh: the triangle, the distance along the ray
/// and the point.
class LuminaRayHit {
  const LuminaRayHit(this.triangle, this.t, this.x, this.y, this.z);

  final int triangle;
  final double t, x, y, z;
}

/// A similarity transform `p' = s · R · p + t` (R a unit quaternion
/// `[x, y, z, w]`).
class LuminaSimilarity {
  const LuminaSimilarity(this.scale, this.rotation, this.translation);

  final double scale;
  final List<double> rotation;
  final List<double> translation;

  List<double> apply(List<double> p) {
    final r = LuminaGarmentMath.rotate(rotation, p);
    return [scale * r[0] + translation[0], scale * r[1] + translation[1], scale * r[2] + translation[2]];
  }
}

/// Small geometry helpers of garment fitting: ray picking on a mesh, the
/// best similarity between point pairs, and Euler angles.
abstract final class LuminaGarmentMath {
  /// The nearest hit of the ray ([ox], [oy], [oz]) + t·([dx], [dy], [dz])
  /// (t > 0) on the triangles of [positions] (xyz per vertex), or null.
  static LuminaRayHit? raycast(
    List<double> positions,
    List<int> triangles,
    double ox,
    double oy,
    double oz,
    double dx,
    double dy,
    double dz,
  ) {
    LuminaRayHit? best;
    for (var t = 0; t + 2 < triangles.length; t += 3) {
      final a = triangles[t] * 3, b = triangles[t + 1] * 3, c = triangles[t + 2] * 3;
      final e1x = positions[b] - positions[a], e1y = positions[b + 1] - positions[a + 1], e1z = positions[b + 2] - positions[a + 2];
      final e2x = positions[c] - positions[a], e2y = positions[c + 1] - positions[a + 1], e2z = positions[c + 2] - positions[a + 2];
      final px = dy * e2z - dz * e2y, py = dz * e2x - dx * e2z, pz = dx * e2y - dy * e2x;
      final det = e1x * px + e1y * py + e1z * pz;
      if (det.abs() < 1e-12) continue;
      final inv = 1 / det;
      final sx = ox - positions[a], sy = oy - positions[a + 1], sz = oz - positions[a + 2];
      final u = (sx * px + sy * py + sz * pz) * inv;
      if (u < 0 || u > 1) continue;
      final qx = sy * e1z - sz * e1y, qy = sz * e1x - sx * e1z, qz = sx * e1y - sy * e1x;
      final v = (dx * qx + dy * qy + dz * qz) * inv;
      if (v < 0 || u + v > 1) continue;
      final d = (e2x * qx + e2y * qy + e2z * qz) * inv;
      if (d <= 1e-9 || (best != null && d >= best.t)) continue;
      best = LuminaRayHit(t ~/ 3, d, ox + dx * d, oy + dy * d, oz + dz * d);
    }
    return best;
  }

  /// The similarity that best maps [from] onto [to] (least squares, Horn's
  /// quaternion method). One pair gives a translation; two keep the
  /// rotation and fit scale and translation; three or more fit all.
  /// [allowScale] false keeps the scale at 1.
  static LuminaSimilarity fitSimilarity(List<List<double>> from, List<List<double>> to, {bool allowScale = true}) {
    final n = math.min(from.length, to.length);
    if (n == 0) return const LuminaSimilarity(1, [0, 0, 0, 1], [0, 0, 0]);
    final cf = List<double>.filled(3, 0), ct = List<double>.filled(3, 0);
    for (var i = 0; i < n; i++) {
      for (var k = 0; k < 3; k++) {
        cf[k] += from[i][k] / n;
        ct[k] += to[i][k] / n;
      }
    }
    if (n == 1) return LuminaSimilarity(1, const [0, 0, 0, 1], [ct[0] - cf[0], ct[1] - cf[1], ct[2] - cf[2]]);
    var rotation = const <double>[0, 0, 0, 1];
    if (n >= 3) {
      // S = Σ a bᵀ of the centred points.
      final s = List<double>.filled(9, 0);
      for (var i = 0; i < n; i++) {
        for (var r = 0; r < 3; r++) {
          for (var c = 0; c < 3; c++) {
            s[r * 3 + c] += (from[i][r] - cf[r]) * (to[i][c] - ct[c]);
          }
        }
      }
      final sxx = s[0], sxy = s[1], sxz = s[2], syx = s[3], syy = s[4], syz = s[5], szx = s[6], szy = s[7], szz = s[8];
      final m = [
        sxx + syy + szz, syz - szy, szx - sxz, sxy - syx, //
        syz - szy, sxx - syy - szz, sxy + syx, szx + sxz,
        szx - sxz, sxy + syx, -sxx + syy - szz, syz + szy,
        sxy - syx, szx + sxz, syz + szy, -sxx - syy + szz,
      ];
      final q = _largestEigenvector4(m); // [w, x, y, z]
      rotation = [q[1], q[2], q[3], q[0]];
    }
    var scale = 1.0;
    if (allowScale) {
      var num = 0.0, den = 0.0;
      for (var i = 0; i < n; i++) {
        final a = rotate(rotation, [from[i][0] - cf[0], from[i][1] - cf[1], from[i][2] - cf[2]]);
        final b = [to[i][0] - ct[0], to[i][1] - ct[1], to[i][2] - ct[2]];
        num += a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
        den += a[0] * a[0] + a[1] * a[1] + a[2] * a[2];
      }
      if (den > 1e-12 && num > 0) scale = num / den;
    }
    final rc = rotate(rotation, cf);
    return LuminaSimilarity(scale, rotation, [ct[0] - scale * rc[0], ct[1] - scale * rc[1], ct[2] - scale * rc[2]]);
  }

  /// [p] rotated by the unit quaternion [q] (`[x, y, z, w]`).
  static List<double> rotate(List<double> q, List<double> p) {
    final x = q[0], y = q[1], z = q[2], w = q[3];
    final tx = 2 * (y * p[2] - z * p[1]), ty = 2 * (z * p[0] - x * p[2]), tz = 2 * (x * p[1] - y * p[0]);
    return [p[0] + w * tx + (y * tz - z * ty), p[1] + w * ty + (z * tx - x * tz), p[2] + w * tz + (x * ty - y * tx)];
  }

  /// The product a · b of two quaternions (`[x, y, z, w]`).
  static List<double> multiply(List<double> a, List<double> b) => [
    a[3] * b[0] + a[0] * b[3] + a[1] * b[2] - a[2] * b[1],
    a[3] * b[1] - a[0] * b[2] + a[1] * b[3] + a[2] * b[0],
    a[3] * b[2] + a[0] * b[1] - a[1] * b[0] + a[2] * b[3],
    a[3] * b[3] - a[0] * b[0] - a[1] * b[1] - a[2] * b[2],
  ];

  /// The quaternion of Euler angles in degrees applied X, then Y, then Z
  /// (R = Rz · Ry · Rx).
  static List<double> quaternionFromEuler(List<double> degrees) {
    List<double> axis(int k, double deg) {
      final h = deg * math.pi / 360;
      final q = [0.0, 0.0, 0.0, math.cos(h)];
      q[k] = math.sin(h);
      return q;
    }

    return multiply(multiply(axis(2, degrees[2]), axis(1, degrees[1])), axis(0, degrees[0]));
  }

  /// Euler angles in degrees (X, Y, Z; R = Rz · Ry · Rx) of the unit
  /// quaternion [q].
  static List<double> eulerFromQuaternion(List<double> q) {
    final x = q[0], y = q[1], z = q[2], w = q[3];
    final r20 = 2 * (x * z - w * y);
    final r21 = 2 * (y * z + w * x), r22 = 1 - 2 * (x * x + y * y);
    final r10 = 2 * (x * y + w * z), r00 = 1 - 2 * (y * y + z * z);
    final ry = math.asin((-r20).clamp(-1.0, 1.0));
    double rx, rz;
    if (r20.abs() < 0.999999) {
      rx = math.atan2(r21, r22);
      rz = math.atan2(r10, r00);
    } else {
      // Gimbal lock: Z carries the whole turn about the vertical.
      rx = 0;
      final r01 = 2 * (x * y - w * z), r11 = 1 - 2 * (x * x + z * z);
      rz = math.atan2(-r01, r11);
    }
    const d = 180 / math.pi;
    return [rx * d, ry * d, rz * d];
  }

  /// The unit eigenvector of the largest eigenvalue of the symmetric 4×4
  /// [m] (row-major), by Jacobi rotations.
  static List<double> _largestEigenvector4(List<double> m) {
    final a = [for (var r = 0; r < 4; r++) [for (var c = 0; c < 4; c++) m[r * 4 + c]]];
    final v = [for (var r = 0; r < 4; r++) [for (var c = 0; c < 4; c++) r == c ? 1.0 : 0.0]];
    for (var sweep = 0; sweep < 50; sweep++) {
      var off = 0.0;
      for (var p = 0; p < 4; p++) {
        for (var q = p + 1; q < 4; q++) {
          off += a[p][q] * a[p][q];
        }
      }
      if (off < 1e-22) break;
      for (var p = 0; p < 4; p++) {
        for (var q = p + 1; q < 4; q++) {
          if (a[p][q].abs() < 1e-30) continue;
          final theta = (a[q][q] - a[p][p]) / (2 * a[p][q]);
          final t = (theta >= 0 ? 1 : -1) / (theta.abs() + math.sqrt(theta * theta + 1));
          final c = 1 / math.sqrt(t * t + 1), s = t * c;
          for (var k = 0; k < 4; k++) {
            final akp = a[k][p], akq = a[k][q];
            a[k][p] = c * akp - s * akq;
            a[k][q] = s * akp + c * akq;
          }
          for (var k = 0; k < 4; k++) {
            final apk = a[p][k], aqk = a[q][k];
            a[p][k] = c * apk - s * aqk;
            a[q][k] = s * apk + c * aqk;
          }
          for (var k = 0; k < 4; k++) {
            final vkp = v[k][p], vkq = v[k][q];
            v[k][p] = c * vkp - s * vkq;
            v[k][q] = s * vkp + c * vkq;
          }
        }
      }
    }
    var best = 0;
    for (var i = 1; i < 4; i++) {
      if (a[i][i] > a[best][best]) best = i;
    }
    final out = [for (var r = 0; r < 4; r++) v[r][best]];
    final len = math.sqrt(out.fold(0.0, (s, e) => s + e * e));
    return [for (final e in out) e / len];
  }
}

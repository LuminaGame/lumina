import 'dart:math' as math;
import 'dart:typed_data';

/// Allocation-free pose math on flat `Float64List`s, for sampling and
/// comparing thousands of skeleton poses.
///
/// - A **TRS** is 10 doubles: translation (3), rotation quaternion x, y, z, w
///   (4), scale (3) — [trsStride].
/// - An **affine** is 12 doubles, column-major: the 3×3 linear part's columns
///   (9), then the translation (3) — [affineStride].
abstract final class LuminaPoseMath {
  static const int trsStride = 10;
  static const int affineStride = 12;

  /// Writes the affine of the TRS at [src]/[so] into [out]/[oo].
  static void composeTrs(Float64List src, int so, Float64List out, int oo) {
    final x = src[so + 3], y = src[so + 4], z = src[so + 5], w = src[so + 6];
    final sx = src[so + 7], sy = src[so + 8], sz = src[so + 9];
    final xx = x * x, yy = y * y, zz = z * z, xy = x * y, xz = x * z, yz = y * z, wx = w * x, wy = w * y, wz = w * z;
    out[oo] = (1 - 2 * (yy + zz)) * sx;
    out[oo + 1] = 2 * (xy + wz) * sx;
    out[oo + 2] = 2 * (xz - wy) * sx;
    out[oo + 3] = 2 * (xy - wz) * sy;
    out[oo + 4] = (1 - 2 * (xx + zz)) * sy;
    out[oo + 5] = 2 * (yz + wx) * sy;
    out[oo + 6] = 2 * (xz + wy) * sz;
    out[oo + 7] = 2 * (yz - wx) * sz;
    out[oo + 8] = (1 - 2 * (xx + yy)) * sz;
    out[oo + 9] = src[so];
    out[oo + 10] = src[so + 1];
    out[oo + 11] = src[so + 2];
  }

  /// `out = a · b` (affines). [out] may not alias [a] or [b].
  static void multiplyAffine(Float64List a, int ao, Float64List b, int bo, Float64List out, int oo) {
    for (var c = 0; c < 4; c++) {
      final b0 = b[bo + c * 3], b1 = b[bo + c * 3 + 1], b2 = b[bo + c * 3 + 2];
      for (var r = 0; r < 3; r++) {
        var v = a[ao + r] * b0 + a[ao + 3 + r] * b1 + a[ao + 6 + r] * b2;
        if (c == 3) v += a[ao + 9 + r];
        out[oo + c * 3 + r] = v;
      }
    }
  }

  /// `out = a⁻¹` (affine; a general 3×3 inverse). [out] may not alias [a].
  static void invertAffine(Float64List a, int ao, Float64List out, int oo) {
    final m00 = a[ao], m10 = a[ao + 1], m20 = a[ao + 2];
    final m01 = a[ao + 3], m11 = a[ao + 4], m21 = a[ao + 5];
    final m02 = a[ao + 6], m12 = a[ao + 7], m22 = a[ao + 8];
    final c00 = m11 * m22 - m12 * m21, c01 = m02 * m21 - m01 * m22, c02 = m01 * m12 - m02 * m11;
    final c10 = m12 * m20 - m10 * m22, c11 = m00 * m22 - m02 * m20, c12 = m02 * m10 - m00 * m12;
    final c20 = m10 * m21 - m11 * m20, c21 = m01 * m20 - m00 * m21, c22 = m00 * m11 - m01 * m10;
    var det = m00 * c00 + m01 * c10 + m02 * c20;
    if (det.abs() < 1e-30) det = 1e-30;
    final inv = 1.0 / det;
    out[oo] = c00 * inv;
    out[oo + 1] = c10 * inv;
    out[oo + 2] = c20 * inv;
    out[oo + 3] = c01 * inv;
    out[oo + 4] = c11 * inv;
    out[oo + 5] = c21 * inv;
    out[oo + 6] = c02 * inv;
    out[oo + 7] = c12 * inv;
    out[oo + 8] = c22 * inv;
    final tx = a[ao + 9], ty = a[ao + 10], tz = a[ao + 11];
    out[oo + 9] = -(out[oo] * tx + out[oo + 3] * ty + out[oo + 6] * tz);
    out[oo + 10] = -(out[oo + 1] * tx + out[oo + 4] * ty + out[oo + 7] * tz);
    out[oo + 11] = -(out[oo + 2] * tx + out[oo + 5] * ty + out[oo + 8] * tz);
  }

  /// The TRS of an affine (no shear): column lengths as the scale, the
  /// normalized columns as the rotation.
  static void decomposeAffine(Float64List m, int mo, Float64List out, int oo) {
    out[oo] = m[mo + 9];
    out[oo + 1] = m[mo + 10];
    out[oo + 2] = m[mo + 11];
    final sx = math.sqrt(m[mo] * m[mo] + m[mo + 1] * m[mo + 1] + m[mo + 2] * m[mo + 2]);
    final sy = math.sqrt(m[mo + 3] * m[mo + 3] + m[mo + 4] * m[mo + 4] + m[mo + 5] * m[mo + 5]);
    final sz = math.sqrt(m[mo + 6] * m[mo + 6] + m[mo + 7] * m[mo + 7] + m[mo + 8] * m[mo + 8]);
    out[oo + 7] = sx;
    out[oo + 8] = sy;
    out[oo + 9] = sz;
    final ix = sx > 1e-12 ? 1 / sx : 0.0, iy = sy > 1e-12 ? 1 / sy : 0.0, iz = sz > 1e-12 ? 1 / sz : 0.0;
    rotationToQuaternion(
      m[mo] * ix, m[mo + 3] * iy, m[mo + 6] * iz, //
      m[mo + 1] * ix, m[mo + 4] * iy, m[mo + 7] * iz,
      m[mo + 2] * ix, m[mo + 5] * iy, m[mo + 8] * iz,
      out, oo + 3,
    );
  }

  /// The rotation part of an affine as a quaternion (columns normalized).
  static void affineRotation(Float64List m, int mo, Float64List out, int oo) {
    double len(int o) => math.sqrt(m[mo + o] * m[mo + o] + m[mo + o + 1] * m[mo + o + 1] + m[mo + o + 2] * m[mo + o + 2]);
    final a = len(0), b = len(3), c = len(6);
    final ia = a > 1e-12 ? 1 / a : 0.0, ib = b > 1e-12 ? 1 / b : 0.0, ic = c > 1e-12 ? 1 / c : 0.0;
    rotationToQuaternion(
      m[mo] * ia, m[mo + 3] * ib, m[mo + 6] * ic, //
      m[mo + 1] * ia, m[mo + 4] * ib, m[mo + 7] * ic,
      m[mo + 2] * ia, m[mo + 5] * ib, m[mo + 8] * ic,
      out, oo,
    );
  }

  /// Row-major 3×3 rotation → quaternion (x, y, z, w) at [out]/[oo].
  static void rotationToQuaternion(double m00, double m01, double m02, double m10, double m11, double m12, double m20,
      double m21, double m22, Float64List out, int oo) {
    final trace = m00 + m11 + m22;
    double x, y, z, w;
    if (trace > 0) {
      final s = math.sqrt(trace + 1.0) * 2;
      w = 0.25 * s;
      x = (m21 - m12) / s;
      y = (m02 - m20) / s;
      z = (m10 - m01) / s;
    } else if (m00 > m11 && m00 > m22) {
      final s = math.sqrt(1.0 + m00 - m11 - m22) * 2;
      w = (m21 - m12) / s;
      x = 0.25 * s;
      y = (m01 + m10) / s;
      z = (m02 + m20) / s;
    } else if (m11 > m22) {
      final s = math.sqrt(1.0 + m11 - m00 - m22) * 2;
      w = (m02 - m20) / s;
      x = (m01 + m10) / s;
      y = 0.25 * s;
      z = (m12 + m21) / s;
    } else {
      final s = math.sqrt(1.0 + m22 - m00 - m11) * 2;
      w = (m10 - m01) / s;
      x = (m02 + m20) / s;
      y = (m12 + m21) / s;
      z = 0.25 * s;
    }
    final n = math.sqrt(x * x + y * y + z * z + w * w);
    out[oo] = x / n;
    out[oo + 1] = y / n;
    out[oo + 2] = z / n;
    out[oo + 3] = w / n;
  }

  /// `out = a · b` (quaternions at offsets; [out] may alias either).
  static void multiplyQuaternion(Float64List a, int ao, Float64List b, int bo, Float64List out, int oo) {
    final ax = a[ao], ay = a[ao + 1], az = a[ao + 2], aw = a[ao + 3];
    final bx = b[bo], by = b[bo + 1], bz = b[bo + 2], bw = b[bo + 3];
    out[oo] = aw * bx + ax * bw + ay * bz - az * by;
    out[oo + 1] = aw * by - ax * bz + ay * bw + az * bx;
    out[oo + 2] = aw * bz + ax * by - ay * bx + az * bw;
    out[oo + 3] = aw * bw - ax * bx - ay * by - az * bz;
  }

  /// Rotates (x, y, z) by the unit quaternion at [q]/[qo] into [out]/[oo].
  static void rotateVector(Float64List q, int qo, double x, double y, double z, Float64List out, int oo) {
    final qx = q[qo], qy = q[qo + 1], qz = q[qo + 2], qw = q[qo + 3];
    final tx = 2 * (qy * z - qz * y), ty = 2 * (qz * x - qx * z), tz = 2 * (qx * y - qy * x);
    out[oo] = x + qw * tx + (qy * tz - qz * ty);
    out[oo + 1] = y + qw * ty + (qz * tx - qx * tz);
    out[oo + 2] = z + qw * tz + (qx * ty - qy * tx);
  }

  /// Shortest-path slerp of the quaternions at [a] and [b] by [t] into [out].
  static void slerp(Float64List a, int ao, Float64List b, int bo, double t, Float64List out, int oo) {
    final ax = a[ao], ay = a[ao + 1], az = a[ao + 2], aw = a[ao + 3];
    var bx = b[bo], by = b[bo + 1], bz = b[bo + 2], bw = b[bo + 3];
    var dot = ax * bx + ay * by + az * bz + aw * bw;
    if (dot < 0) {
      dot = -dot;
      bx = -bx;
      by = -by;
      bz = -bz;
      bw = -bw;
    }
    double k0, k1;
    if (dot > 0.9995) {
      k0 = 1 - t;
      k1 = t;
    } else {
      final omega = math.acos(dot.clamp(-1.0, 1.0));
      final sinOmega = math.sin(omega);
      k0 = math.sin((1 - t) * omega) / sinOmega;
      k1 = math.sin(t * omega) / sinOmega;
    }
    var x = ax * k0 + bx * k1, y = ay * k0 + by * k1, z = az * k0 + bz * k1, w = aw * k0 + bw * k1;
    final n = math.sqrt(x * x + y * y + z * z + w * w);
    if (n > 1e-12) {
      x /= n;
      y /= n;
      z /= n;
      w /= n;
    }
    out[oo] = x;
    out[oo + 1] = y;
    out[oo + 2] = z;
    out[oo + 3] = w;
  }

  /// The ground-plane yaw of direction (x, z): 0 along +Z, π/2 along +X.
  static double yawOf(double x, double z) => math.atan2(x, z);

  /// (x, z) turned by [yaw] about +Y (+Z goes toward +X).
  static (double, double) rotateYaw(double x, double z, double yaw) {
    final c = math.cos(yaw), s = math.sin(yaw);
    return (x * c + z * s, -x * s + z * c);
  }

  /// [angle] wrapped to (−π, π].
  static double wrapAngle(double angle) {
    var a = angle % (2 * math.pi);
    if (a > math.pi) a -= 2 * math.pi;
    if (a <= -math.pi) a += 2 * math.pi;
    return a;
  }
}

import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart';

/// Decomposes a 4x4 matrix into translation, rotation (quaternion), and scale.
///
/// Direct line-for-line port of `filament::gltfio::decomposeMatrix` from `libs/gltfio/include/gltfio/math.h`.
({Vector3 translation, Quaternion rotation, Vector3 scale}) decomposeMatrix(Matrix4 mat) {
  // Extract translation
  final translation = Vector3(mat.entry(0, 3), mat.entry(1, 3), mat.entry(2, 3));

  // Extract upper-left 3x3 for determinant computation
  // mat.entry(row, col)
  final a = mat.entry(0, 0);
  final b = mat.entry(1, 0);
  final c = mat.entry(2, 0);
  final d = mat.entry(0, 1);
  final e = mat.entry(1, 1);
  final f = mat.entry(2, 1);
  final g = mat.entry(0, 2);
  final h = mat.entry(1, 2);
  final i = mat.entry(2, 2);

  final A = e * i - f * h;
  final B = f * g - d * i;
  final C = d * h - e * g;

  final det = a * A + b * B + c * C;
  final scalex = math.sqrt(a * a + b * b + c * c);
  final scaley = math.sqrt(d * d + e * e + f * f);
  final scalez = math.sqrt(g * g + h * h + i * i);

  var s = Vector3(scalex, scaley, scalez);
  if (det < 0) {
    s = -s;
  }

  Quaternion rotation;
  if (det.abs() > 1e-7) {
    // Clone upper-left and normalize columns by scale
    final c00 = a / s.x;
    final c10 = b / s.x;
    final c20 = c / s.x;

    final c01 = d / s.y;
    final c11 = e / s.y;
    final c21 = f / s.y;

    final c02 = g / s.z;
    final c12 = h / s.z;
    final c22 = i / s.z;

    // extractQuat per TMatHelpers.h
    final trace = c00 + c11 + c22;
    if (trace > 0) {
      double sq = math.sqrt(trace + 1.0);
      final qw = 0.5 * sq;
      sq = 0.5 / sq;
      final qx = (c21 - c12) * sq;
      final qy = (c02 - c20) * sq;
      final qz = (c10 - c01) * sq;
      rotation = Quaternion(qx, qy, qz, qw);
    } else {
      int idx = 0;
      if (c11 > c00) idx = 1;
      if (c22 > (idx == 0 ? c00 : c11)) idx = 2;

      final diag = [c00, c11, c22];
      final m = [
        [c00, c01, c02],
        [c10, c11, c12],
        [c20, c21, c22],
      ];
      final nextIjk = [1, 2, 0];
      final j = nextIjk[idx];
      final k = nextIjk[j];

      double sq = math.sqrt((diag[idx] - (diag[j] + diag[k])) + 1.0);
      final qValues = [0.0, 0.0, 0.0, 0.0];
      qValues[idx] = 0.5 * sq;
      if (sq != 0.0) {
        sq = 0.5 / sq;
      }
      final qw = (m[k][j] - m[j][k]) * sq;
      qValues[j] = (m[j][idx] + m[idx][j]) * sq;
      qValues[k] = (m[k][idx] + m[idx][k]) * sq;
      rotation = Quaternion(qValues[0], qValues[1], qValues[2], qw);
    }
  } else {
    rotation = Quaternion.identity();
  }

  return (translation: translation, rotation: rotation, scale: s);
}

/// Composes a 4x4 transformation matrix from translation, rotation, and scale.
///
/// Direct line-for-line port of `filament::gltfio::composeMatrix` from `libs/gltfio/include/gltfio/math.h`.
Matrix4 composeMatrix(Vector3 translation, Quaternion rotation, Vector3 scale) {
  final tx = translation.x, ty = translation.y, tz = translation.z;
  final qx = rotation.x, qy = rotation.y, qz = rotation.z, qw = rotation.w;
  final sx = scale.x, sy = scale.y, sz = scale.z;

  return Matrix4(
    (1 - 2 * qy * qy - 2 * qz * qz) * sx,
    (2 * qx * qy + 2 * qz * qw) * sx,
    (2 * qx * qz - 2 * qy * qw) * sx,
    0.0,

    (2 * qx * qy - 2 * qz * qw) * sy,
    (1 - 2 * qx * qx - 2 * qz * qz) * sy,
    (2 * qy * qz + 2 * qx * qw) * sy,
    0.0,

    (2 * qx * qz + 2 * qy * qw) * sz,
    (2 * qy * qz - 2 * qx * qw) * sz,
    (1 - 2 * qx * qx - 2 * qy * qy) * sz,
    0.0,

    tx, ty, tz, 1.0,
  );
}

/// Evaluates cubic spline interpolation for glTF animation channels.
///
/// Port of `filament::gltfio::cubicSpline` from `libs/gltfio/include/gltfio/math.h`.
Vector4 cubicSpline(Vector4 vert0, Vector4 tang0, Vector4 vert1, Vector4 tang1, double t) {
  final tt = t * t;
  final ttt = tt * t;
  final s2 = -2 * ttt + 3 * tt;
  final s3 = ttt - tt;
  final s0 = 1 - s2;
  final s1 = s3 - tt + t;
  return vert0 * s0 + tang0 * (s1 * t) + vert1 * s2 + tang1 * (s3 * t);
}

/// Evaluates cubic spline interpolation for 3D vectors.
Vector3 cubicSpline3(Vector3 vert0, Vector3 tang0, Vector3 vert1, Vector3 tang1, double t) {
  final tt = t * t;
  final ttt = tt * t;
  final s2 = -2 * ttt + 3 * tt;
  final s3 = ttt - tt;
  final s0 = 1 - s2;
  final s1 = s3 - tt + t;
  return vert0 * s0 + tang0 * (s1 * t) + vert1 * s2 + tang1 * (s3 * t);
}

import 'dart:typed_data';
import 'package:vector_math/vector_math_64.dart';

/// Packs a signed float in range [-1.0, 1.0] into a 16-bit signed integer [-32767, 32767].
///
/// Symmetric packaging matching `filament/libs/math/include/math/norm.h`.
int packSnorm16(double v) {
  return (v.clamp(-1.0, 1.0) * 32767.0).round();
}

/// Packs a 4D vector into an [Int16List] of length 4.
Int16List packSnorm16x4(Vector4 v) {
  final list = Int16List(4);
  list[0] = packSnorm16(v.x);
  list[1] = packSnorm16(v.y);
  list[2] = packSnorm16(v.z);
  list[3] = packSnorm16(v.w);
  return list;
}

/// Unpacks a 16-bit signed integer [-32767, 32767] into a signed float [-1.0, 1.0].
double unpackSnorm16(int v) {
  return (v / 32767.0).clamp(-1.0, 1.0);
}

/// Packs an unsigned float in range [0.0, 1.0] into an 8-bit unsigned integer [0, 255].
int packUnorm8(double v) {
  return (v.clamp(0.0, 1.0) * 255.0).round();
}

/// Unpacks an 8-bit unsigned integer [0, 255] into an unsigned float [0.0, 1.0].
double unpackUnorm8(int v) {
  return v / 255.0;
}

/// Packs an unsigned float in range [0.0, 1.0] into a 16-bit unsigned integer [0, 65535].
int packUnorm16(double v) {
  return (v.clamp(0.0, 1.0) * 65535.0).round();
}

/// Unpacks a 16-bit unsigned integer [0, 65535] into an unsigned float [0.0, 1.0].
double unpackUnorm16(int v) {
  return v / 65535.0;
}

/// Packs a signed float in range [-1.0, 1.0] into an 8-bit signed integer [-127, 127].
int packSnorm8(double v) {
  return (v.clamp(-1.0, 1.0) * 127.0).round();
}

/// Unpacks an 8-bit signed integer [-127, 127] into a signed float [-1.0, 1.0].
double unpackSnorm8(int v) {
  return (v / 127.0).clamp(-1.0, 1.0);
}

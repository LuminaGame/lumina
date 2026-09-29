import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:flutter_filament/src/math_types.dart';
import 'package:flutter_filament/src/third_party/filament_c.g.dart' as c;
import 'package:test/test.dart';

void main() {
  group('Math ABI Types & Flat Memory Struct Layouts', () {
    test('Exact byte size equality with C++ sizeof for all vector and matrix types', () {
      expect(sizeOf<Float2>(), equals(8));
      expect(sizeOf<Float2>(), equals(c.filament_sizeof_float2()));

      // float3 is 12 bytes — NOT 16 bytes (no padding)
      expect(sizeOf<Float3>(), equals(12));
      expect(sizeOf<Float3>(), equals(c.filament_sizeof_float3()));

      expect(sizeOf<Float4>(), equals(16));
      expect(sizeOf<Float4>(), equals(c.filament_sizeof_float4()));

      expect(sizeOf<Int2>(), equals(8));
      expect(sizeOf<Int2>(), equals(c.filament_sizeof_int2()));

      expect(sizeOf<Int3>(), equals(12));
      expect(sizeOf<Int3>(), equals(c.filament_sizeof_int3()));

      expect(sizeOf<Int4>(), equals(16));
      expect(sizeOf<Int4>(), equals(c.filament_sizeof_int4()));

      expect(sizeOf<Uint2>(), equals(8));
      expect(sizeOf<Uint2>(), equals(c.filament_sizeof_uint2()));

      expect(sizeOf<Uint3>(), equals(12));
      expect(sizeOf<Uint3>(), equals(c.filament_sizeof_uint3()));

      expect(sizeOf<Uint4>(), equals(16));
      expect(sizeOf<Uint4>(), equals(c.filament_sizeof_uint4()));

      expect(sizeOf<Bool2>(), equals(2));
      expect(sizeOf<Bool2>(), equals(c.filament_sizeof_bool2()));

      expect(sizeOf<Bool3>(), equals(3));
      expect(sizeOf<Bool3>(), equals(c.filament_sizeof_bool3()));

      expect(sizeOf<Bool4>(), equals(4));
      expect(sizeOf<Bool4>(), equals(c.filament_sizeof_bool4()));

      expect(sizeOf<Short4>(), equals(8));
      expect(sizeOf<Short4>(), equals(c.filament_sizeof_short4()));

      expect(sizeOf<Quatf>(), equals(16));
      expect(sizeOf<Quatf>(), equals(c.filament_sizeof_quatf()));

      expect(sizeOf<Mat3f>(), equals(36));
      expect(sizeOf<Mat3f>(), equals(c.filament_sizeof_mat3f()));

      expect(sizeOf<Mat4f>(), equals(64));
      expect(sizeOf<Mat4f>(), equals(c.filament_sizeof_mat4f()));

      expect(sizeOf<Mat4d>(), equals(128));
      expect(sizeOf<Mat4d>(), equals(c.filament_sizeof_mat4()));
    });

    test('Array stride: Float3 array of 4 elements passes 12-byte stride to C++ without drift', () {
      final arrayPtr = calloc<Float3>(4);
      final outPtr = calloc<Float>(3);
      try {
        arrayPtr[0]
          ..x = 1.0
          ..y = 2.0
          ..z = 3.0;
        arrayPtr[1]
          ..x = 10.0
          ..y = 20.0
          ..z = 30.0;
        arrayPtr[2]
          ..x = 100.0
          ..y = 200.0
          ..z = 300.0;
        arrayPtr[3]
          ..x = 1000.0
          ..y = 2000.0
          ..z = 3000.0;

        c.filament_test_float3_array_sum(arrayPtr.cast<Void>(), 4, outPtr);

        expect(outPtr[0], equals(1111.0));
        expect(outPtr[1], equals(2222.0));
        expect(outPtr[2], equals(3333.0));
      } finally {
        calloc.free(arrayPtr);
        calloc.free(outPtr);
      }
    });

    test('Quatf memory order is {x, y, z, w}', () {
      final qPtr = calloc<Quatf>();
      final outPtr = calloc<Float>(4);
      try {
        qPtr.ref.x = 1.0;
        qPtr.ref.y = 2.0;
        qPtr.ref.z = 3.0;
        qPtr.ref.w = 4.0;

        c.filament_test_quatf_read(qPtr.cast<Void>(), outPtr);

        expect(outPtr[0], equals(1.0));
        expect(outPtr[1], equals(2.0));
        expect(outPtr[2], equals(3.0));
        expect(outPtr[3], equals(4.0));
      } finally {
        calloc.free(qPtr);
        calloc.free(outPtr);
      }
    });

    test('Mat4f translation is stored in floats 12, 13, 14 (column-major)', () {
      final matPtr = calloc<Mat4f>();
      try {
        c.filament_test_mat4f_col_major(matPtr.cast<Void>());

        final list = matPtr.ref.toList();
        expect(list.length, equals(16));

        // Diagonal elements are 1.0
        expect(list[0], equals(1.0));
        expect(list[5], equals(1.0));
        expect(list[10], equals(1.0));
        expect(list[15], equals(1.0));

        // Translation column is at indices 12, 13, 14
        expect(list[12], equals(1.0));
        expect(list[13], equals(2.0));
        expect(list[14], equals(3.0));
      } finally {
        calloc.free(matPtr);
      }
    });

    test('Mat3f 9-component round-trip and byte layout', () {
      final mPtr = calloc<Mat3f>();
      final outPtr = calloc<Float>(9);
      try {
        for (int i = 0; i < 9; i++) {
          mPtr.ref.elements[i] = (i + 1).toDouble();
        }

        c.filament_test_mat3f_read(mPtr.cast<Void>(), outPtr);
        for (int i = 0; i < 9; i++) {
          expect(outPtr[i], equals((i + 1).toDouble()));
        }
      } finally {
        calloc.free(mPtr);
        calloc.free(outPtr);
      }
    });

    test('Bool3 3-byte field round-trip', () {
      final bPtr = calloc<Bool3>();
      final outPtr = calloc<Uint8>(3);
      try {
        bPtr.ref.x = 1;
        bPtr.ref.y = 0;
        bPtr.ref.z = 1;

        c.filament_test_bool3_read(bPtr.cast<Void>(), outPtr);

        expect(outPtr[0], equals(1));
        expect(outPtr[1], equals(0));
        expect(outPtr[2], equals(1));
      } finally {
        calloc.free(bPtr);
        calloc.free(outPtr);
      }
    });
  });
}

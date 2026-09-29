import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';
import 'package:flutter_filament/src/math_types.dart';
import 'package:flutter_filament/src/third_party/filament_c.g.dart' as c;
import 'package:test/test.dart';

void main() {
  group('Math ABI Layout Tests', () {
    test('sizeOf Float3 == 12', () {
      expect(ffi.sizeOf<Float3>(), 12);
      expect(ffi.sizeOf<Float3>(), c.filament_sizeof_float3());
    });

    test('sizeOf other types match C', () {
      expect(ffi.sizeOf<Float2>(), c.filament_sizeof_float2());
      expect(ffi.sizeOf<Float4>(), c.filament_sizeof_float4());
      expect(ffi.sizeOf<Int2>(), c.filament_sizeof_int2());
      expect(ffi.sizeOf<Int3>(), c.filament_sizeof_int3());
      expect(ffi.sizeOf<Int4>(), c.filament_sizeof_int4());
      expect(ffi.sizeOf<Uint2>(), c.filament_sizeof_uint2());
      expect(ffi.sizeOf<Uint3>(), c.filament_sizeof_uint3());
      expect(ffi.sizeOf<Uint4>(), c.filament_sizeof_uint4());
      expect(ffi.sizeOf<Bool2>(), c.filament_sizeof_bool2());
      expect(ffi.sizeOf<Bool3>(), c.filament_sizeof_bool3());
      expect(ffi.sizeOf<Bool4>(), c.filament_sizeof_bool4());
      expect(ffi.sizeOf<Short4>(), c.filament_sizeof_short4());
      expect(ffi.sizeOf<Quatf>(), c.filament_sizeof_quatf());
      expect(ffi.sizeOf<Mat3f>(), c.filament_sizeof_mat3f());
      expect(ffi.sizeOf<Mat4f>(), c.filament_sizeof_mat4f());
      expect(ffi.sizeOf<Mat4d>(), c.filament_sizeof_mat4());
    });

    test('Float3 array stride is exactly 12 bytes', () {
      final arr = calloc<Float3>(4);
      arr[0].x = 1.0; arr[0].y = 1.0; arr[0].z = 1.0;
      arr[1].x = 2.0; arr[1].y = 2.0; arr[1].z = 2.0;
      arr[2].x = 3.0; arr[2].y = 3.0; arr[2].z = 3.0;
      arr[3].x = 4.0; arr[3].y = 4.0; arr[3].z = 4.0;
      
      final out = calloc<ffi.Float>(3);
      c.filament_test_float3_array_sum(arr.cast(), 4, out);
      
      final outList = out.asTypedList(3);
      expect(outList[0], 10.0); // 1+2+3+4
      expect(outList[1], 10.0);
      expect(outList[2], 10.0);
      
      calloc.free(arr);
      calloc.free(out);
    });

    test('Quatf memory order is {x, y, z, w}', () {
      final q = calloc<Quatf>();
      q.ref.x = 1.0;
      q.ref.y = 2.0;
      q.ref.z = 3.0;
      q.ref.w = 4.0;
      
      final out = calloc<ffi.Float>(4);
      c.filament_test_quatf_read(q.cast(), out);
      
      final outList = out.asTypedList(4);
      expect(outList[0], 1.0);
      expect(outList[1], 2.0);
      expect(outList[2], 3.0);
      expect(outList[3], 4.0);
      
      calloc.free(q);
      calloc.free(out);
    });

    test('Mat4f is column-major and 64 bytes', () {
      final out = calloc<Mat4f>();
      c.filament_test_mat4f_col_major(out.cast());
      
      final list = out.ref.toList();
      // Identity diagonal
      expect(list[0], 1.0);
      expect(list[5], 1.0);
      expect(list[10], 1.0);
      expect(list[15], 1.0);
      
      // Translation at floats 12, 13, 14
      expect(list[12], 1.0);
      expect(list[13], 2.0);
      expect(list[14], 3.0);
      
      calloc.free(out);
    });

    test('Mat3f layout verification', () {
      final m = calloc<Mat3f>();
      for (int i = 0; i < 9; i++) {
        m.ref.elements[i] = i.toDouble();
      }
      
      final out = calloc<ffi.Float>(9);
      c.filament_test_mat3f_read(m.cast(), out);
      
      final outList = out.asTypedList(9);
      for (int i = 0; i < 9; i++) {
        expect(outList[i], i.toDouble());
      }
      
      calloc.free(m);
      calloc.free(out);
    });

    test('Bool3 size and readback', () {
      final b = calloc<Bool3>();
      b.ref.x = 1;
      b.ref.y = 0;
      b.ref.z = 1;
      
      final out = calloc<ffi.Uint8>(3);
      c.filament_test_bool3_read(b.cast(), out);
      
      final outList = out.asTypedList(3);
      expect(outList[0], 1);
      expect(outList[1], 0);
      expect(outList[2], 1);
      
      calloc.free(b);
      calloc.free(out);
    });
  });
}

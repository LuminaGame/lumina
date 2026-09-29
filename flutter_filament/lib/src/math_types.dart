/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

import 'ffi_platform.dart' as ffi;
import 'dart:typed_data';

/// 2D float vector (8 bytes).
final class Float2 extends ffi.Struct {
  @ffi.Float()
  external double x;

  @ffi.Float()
  external double y;
}

/// 3D float vector (12 bytes, contiguous without padding).
final class Float3 extends ffi.Struct {
  @ffi.Float()
  external double x;

  @ffi.Float()
  external double y;

  @ffi.Float()
  external double z;
}

/// 4D float vector (16 bytes).
final class Float4 extends ffi.Struct {
  @ffi.Float()
  external double x;

  @ffi.Float()
  external double y;

  @ffi.Float()
  external double z;

  @ffi.Float()
  external double w;
}

/// 2D int32 vector (8 bytes).
final class Int2 extends ffi.Struct {
  @ffi.Int32()
  external int x;

  @ffi.Int32()
  external int y;
}

/// 3D int32 vector (12 bytes).
final class Int3 extends ffi.Struct {
  @ffi.Int32()
  external int x;

  @ffi.Int32()
  external int y;

  @ffi.Int32()
  external int z;
}

/// 4D int32 vector (16 bytes).
final class Int4 extends ffi.Struct {
  @ffi.Int32()
  external int x;

  @ffi.Int32()
  external int y;

  @ffi.Int32()
  external int z;

  @ffi.Int32()
  external int w;
}

/// 2D uint32 vector (8 bytes).
final class Uint2 extends ffi.Struct {
  @ffi.Uint32()
  external int x;

  @ffi.Uint32()
  external int y;
}

/// 3D uint32 vector (12 bytes).
final class Uint3 extends ffi.Struct {
  @ffi.Uint32()
  external int x;

  @ffi.Uint32()
  external int y;

  @ffi.Uint32()
  external int z;
}

/// 4D uint32 vector (16 bytes).
final class Uint4 extends ffi.Struct {
  @ffi.Uint32()
  external int x;

  @ffi.Uint32()
  external int y;

  @ffi.Uint32()
  external int z;

  @ffi.Uint32()
  external int w;
}

/// 2D boolean vector (2 bytes).
final class Bool2 extends ffi.Struct {
  @ffi.Uint8()
  external int x;

  @ffi.Uint8()
  external int y;
}

/// 3D boolean vector (3 bytes).
final class Bool3 extends ffi.Struct {
  @ffi.Uint8()
  external int x;

  @ffi.Uint8()
  external int y;

  @ffi.Uint8()
  external int z;
}

/// 4D boolean vector (4 bytes).
final class Bool4 extends ffi.Struct {
  @ffi.Uint8()
  external int x;

  @ffi.Uint8()
  external int y;

  @ffi.Uint8()
  external int z;

  @ffi.Uint8()
  external int w;
}

/// 4D signed int16 vector (8 bytes).
final class Short4 extends ffi.Struct {
  @ffi.Int16()
  external int x;

  @ffi.Int16()
  external int y;

  @ffi.Int16()
  external int z;

  @ffi.Int16()
  external int w;
}

/// Unit quaternion stored in {x, y, z, w} memory order (16 bytes).
final class Quatf extends ffi.Struct {
  @ffi.Float()
  external double x;

  @ffi.Float()
  external double y;

  @ffi.Float()
  external double z;

  @ffi.Float()
  external double w;
}

/// 3x3 float column-major matrix (36 bytes).
final class Mat3f extends ffi.Struct {
  @ffi.Array(9)
  external ffi.Array<ffi.Float> elements;

  List<double> toList() {
    return List<double>.generate(9, (i) => elements[i]);
  }

  void setFromList(List<double> list) {
    if (list.length != 9) {
      throw ArgumentError.value(list.length, 'list.length', 'Expected 9 elements');
    }
    for (int i = 0; i < 9; i++) {
      elements[i] = list[i];
    }
  }
}

/// 4x4 float column-major matrix (64 bytes).
final class Mat4f extends ffi.Struct {
  @ffi.Array(16)
  external ffi.Array<ffi.Float> elements;

  List<double> toList() {
    return List<double>.generate(16, (i) => elements[i]);
  }

  void setFromList(List<double> list) {
    if (list.length != 16) {
      throw ArgumentError.value(list.length, 'list.length', 'Expected 16 elements');
    }
    for (int i = 0; i < 16; i++) {
      elements[i] = list[i];
    }
  }

  static Float32List asFloat32List(ffi.Pointer<Mat4f> ptr) {
    return ptr.cast<ffi.Float>().asTypedList(16);
  }
}

/// 4x4 double precision column-major matrix (128 bytes).
final class Mat4d extends ffi.Struct {
  @ffi.Array(16)
  external ffi.Array<ffi.Double> elements;

  List<double> toList() {
    return List<double>.generate(16, (i) => elements[i]);
  }

  void setFromList(List<double> list) {
    if (list.length != 16) {
      throw ArgumentError.value(list.length, 'list.length', 'Expected 16 elements');
    }
    for (int i = 0; i < 16; i++) {
      elements[i] = list[i];
    }
  }
}

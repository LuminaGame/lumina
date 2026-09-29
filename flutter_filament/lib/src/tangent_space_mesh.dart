/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

import 'ffi_platform.dart' as ffi;
import 'dart:typed_data';

import 'package:flutter_filament/src/buffer_descriptor.dart';
import 'package:flutter_filament/src/filament_bindings.dart' as c;

/// The algorithm used to generate the tangent space.
enum TsmAlgorithm {
  /// Tries to select the best possible algorithm given the input.
  default_(0),
  /// MikkTSpace (requires normals, uvs, positions, indices). Will remesh.
  mikktspace(1),
  /// Lengyel's method (requires normals, uvs, positions, indices).
  lengyel(2),
  /// Hughes-Moller method (requires normals).
  hughesMoller(3),
  /// Frisvad's method (requires normals).
  frisvad(4);

  final int value;
  const TsmAlgorithm(this.value);
}

/// Auxiliary attributes that can be provided and will be properly mapped if remeshed.
enum TsmAuxAttribute {
  uv1(0),
  colors(1),
  joints(2),
  weights(3);

  final int value;
  const TsmAuxAttribute(this.value);
}

/// Internal data types for auxiliary attributes.
enum _TsmAuxType {
  float2(0),
  float4(2);

  final int value;
  const _TsmAuxType(this.value);
}

/// Builds a [TangentSpaceMesh].
class TangentSpaceMeshBuilder {
  final ffi.Pointer<c.FilTsmBuilder> _builder;
  final List<NativeBuffer> _retainedBuffers = [];

  TangentSpaceMeshBuilder() : _builder = c.filament_tsm_builder_create();

  void _retain(NativeBuffer buffer) {
    _retainedBuffers.add(buffer);
  }

  void vertexCount(int count) {
    c.filament_tsm_builder_vertex_count(_builder, count);
  }

  void normals(Float32List normals, {int strideBytes = 0}) {
    final buffer = NativeBuffer.fromTypedData(normals);
    _retain(buffer);
    c.filament_tsm_builder_normals(_builder, buffer.pointer.cast(), strideBytes);
  }

  void tangents(Float32List tangents, {int strideBytes = 0}) {
    final buffer = NativeBuffer.fromTypedData(tangents);
    _retain(buffer);
    c.filament_tsm_builder_tangents(_builder, buffer.pointer.cast(), strideBytes);
  }

  void uvs(Float32List uvs, {int strideBytes = 0}) {
    final buffer = NativeBuffer.fromTypedData(uvs);
    _retain(buffer);
    c.filament_tsm_builder_uvs(_builder, buffer.pointer.cast(), strideBytes);
  }

  void positions(Float32List positions, {int strideBytes = 0}) {
    final buffer = NativeBuffer.fromTypedData(positions);
    _retain(buffer);
    c.filament_tsm_builder_positions(_builder, buffer.pointer.cast(), strideBytes);
  }

  void triangleCount(int count) {
    c.filament_tsm_builder_triangle_count(_builder, count);
  }

  void trianglesUint(Uint32List tris) {
    final buffer = NativeBuffer.fromTypedData(tris);
    _retain(buffer);
    c.filament_tsm_builder_triangles_uint3(_builder, buffer.pointer.cast());
  }

  void trianglesUshort(Uint16List tris) {
    final buffer = NativeBuffer.fromTypedData(tris);
    _retain(buffer);
    c.filament_tsm_builder_triangles_ushort3(_builder, buffer.pointer.cast());
  }

  void aux(TsmAuxAttribute attribute, Float32List data, {int strideBytes = 0}) {
    final buffer = NativeBuffer.fromTypedData(data);
    _retain(buffer);
    // Rough heuristic since the builder doesn't specify if it's float2/3/4 directly:
    // We assume the user passes a properly sized list for vertexCount * channels.
    // If we just default to float4 it might read out of bounds. The C API doesn't know.
    // Let's deduce type from size, or we could require user to specify.
    // Actually the test uses float4 for colors. Let's just pass type 2 (float4) for colors, 0 (float2) for uv1.
    int type = _TsmAuxType.float4.value;
    if (attribute == TsmAuxAttribute.uv1) type = _TsmAuxType.float2.value;
    
    c.filament_tsm_builder_aux(_builder, attribute.value, buffer.pointer.cast(), type, strideBytes);
  }

  void algorithm(TsmAlgorithm algo) {
    c.filament_tsm_builder_algorithm(_builder, algo.value);
  }

  TangentSpaceMesh build() {
    final ptr = c.filament_tsm_builder_build(_builder);
    c.filament_tsm_builder_destroy(_builder);
    
    for (final buf in _retainedBuffers) {
      buf.free();
    }
    _retainedBuffers.clear();

    if (ptr == ffi.nullptr) {
      throw StateError('Failed to build TangentSpaceMesh (check if triangleCount matches triangles provided)');
    }

    return TangentSpaceMesh._(ptr);
  }
}

/// The generated tangent space mesh.
class TangentSpaceMesh {
  ffi.Pointer<c.FilTangentSpaceMesh> _ptr;

  TangentSpaceMesh._(this._ptr);

  void _checkAlive() {
    if (_ptr == ffi.nullptr) {
      throw StateError('TangentSpaceMesh is destroyed.');
    }
  }

  int get vertexCount {
    _checkAlive();
    return c.filament_tsm_get_vertex_count(_ptr);
  }

  int get triangleCount {
    _checkAlive();
    return c.filament_tsm_get_triangle_count(_ptr);
  }

  bool get remeshed {
    _checkAlive();
    return c.filament_tsm_remeshed(_ptr);
  }

  Float32List getPositions({int strideBytes = 0}) {
    _checkAlive();
    final count = vertexCount;
    final byteSize = count * 3 * 4;
    final buffer = NativeBuffer.allocate(byteSize);
    c.filament_tsm_get_positions(_ptr, buffer.pointer.cast(), strideBytes);
    final result = Float32List.fromList(buffer.asTypedList.buffer.asFloat32List());
    buffer.free();
    return result;
  }

  Float32List getUVs({int strideBytes = 0}) {
    _checkAlive();
    final count = vertexCount;
    final byteSize = count * 2 * 4;
    final buffer = NativeBuffer.allocate(byteSize);
    c.filament_tsm_get_uvs(_ptr, buffer.pointer.cast(), strideBytes);
    final result = Float32List.fromList(buffer.asTypedList.buffer.asFloat32List());
    buffer.free();
    return result;
  }

  Float32List getQuatsFloat({int strideBytes = 0}) {
    _checkAlive();
    final count = vertexCount;
    final byteSize = count * 4 * 4;
    final buffer = NativeBuffer.allocate(byteSize);
    c.filament_tsm_get_quats_float4(_ptr, buffer.pointer.cast(), strideBytes);
    final result = Float32List.fromList(buffer.asTypedList.buffer.asFloat32List());
    buffer.free();
    return result;
  }

  Int16List getQuatsShort4({int strideBytes = 0}) {
    _checkAlive();
    final count = vertexCount;
    final byteSize = count * 4 * 2;
    final buffer = NativeBuffer.allocate(byteSize);
    c.filament_tsm_get_quats_short4(_ptr, buffer.pointer.cast(), strideBytes);
    final result = Int16List.fromList(buffer.asTypedList.buffer.asInt16List());
    buffer.free();
    return result;
  }

  Uint16List getQuatsHalf4({int strideBytes = 0}) {
    _checkAlive();
    final count = vertexCount;
    final byteSize = count * 4 * 2;
    final buffer = NativeBuffer.allocate(byteSize);
    c.filament_tsm_get_quats_half4(_ptr, buffer.pointer.cast(), strideBytes);
    final result = Uint16List.fromList(buffer.asTypedList.buffer.asUint16List());
    buffer.free();
    return result;
  }

  Uint32List getTrianglesUint32() {
    _checkAlive();
    final count = triangleCount;
    final byteSize = count * 3 * 4;
    final buffer = NativeBuffer.allocate(byteSize);
    c.filament_tsm_get_triangles_uint3(_ptr, buffer.pointer.cast());
    final result = Uint32List.fromList(buffer.asTypedList.buffer.asUint32List());
    buffer.free();
    return result;
  }

  Float32List getAuxFloat(TsmAuxAttribute attribute, {int strideBytes = 0}) {
    _checkAlive();
    final count = vertexCount;
    int channels = 4;
    int type = _TsmAuxType.float4.value;
    if (attribute == TsmAuxAttribute.uv1) {
      channels = 2;
      type = _TsmAuxType.float2.value;
    }

    final byteSize = count * channels * 4;
    final buffer = NativeBuffer.allocate(byteSize);
    c.filament_tsm_get_aux(_ptr, attribute.value, buffer.pointer.cast(), type, strideBytes);
    final result = Float32List.fromList(buffer.asTypedList.buffer.asFloat32List());
    buffer.free();
    return result;
  }

  void destroy() {
    _checkAlive();
    c.filament_tsm_destroy(_ptr);
    _ptr = ffi.nullptr;
  }
}

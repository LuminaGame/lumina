import 'package:flutter_filament/src/ffi_platform.dart' as ffi;
import 'dart:typed_data';
import 'package:flutter_filament/src/ffi_package_platform.dart';
import 'package:flutter_filament/src/filament_bindings.dart' as c;

/// Component type for vertex attribute input transcoding.
enum ComponentType {
  byte(0),
  ubyte(1),
  short(2),
  ushort(3),
  half(4),
  float(5);

  final int value;
  const ComponentType(this.value);
}

/// Configuration describing the input format for [Transcoder].
class TranscoderConfig {
  /// The input element component type (BYTE, UBYTE, SHORT, USHORT, HALF, FLOAT).
  final ComponentType componentType;

  /// Whether integer input components should be mapped to the normalized [0, 1] or [-1, +1] range.
  final bool normalized;

  /// The number of components per vertex (e.g. 1 for float, 2 for float2/uv, 3 for float3/normal, 4 for float4/color).
  final int componentCount;

  /// Input stride in bytes. If 0, the transcoder assumes tightly packed data.
  final int inputStrideBytes;

  const TranscoderConfig({
    required this.componentType,
    this.normalized = false,
    required this.componentCount,
    this.inputStrideBytes = 0,
  }) : assert(componentCount >= 1 && componentCount <= 4, 'componentCount must be between 1 and 4');
}

/// Converts arbitrary packed/normalized vertex attribute data into tightly packed 32-bit floating point values.
///
/// This is especially useful for 3-component formats (e.g. `short3`, `half3`) which are not supported
/// on backends with strict minspecs (like Vulkan), allowing CPU expansion to `float3`.
class Transcoder {
  final TranscoderConfig config;

  const Transcoder(this.config);

  /// Transcodes [source] attribute data of [vertexCount] items into tightly packed [Float32List].
  ///
  /// [source] can be any [TypedData] (such as [Int8List], [Uint8List], [Int16List], [Uint16List], [Float32List]).
  Float32List run(TypedData source, int vertexCount) {
    if (vertexCount <= 0) {
      return Float32List(0);
    }

    final totalFloats = vertexCount * config.componentCount;

    final targetPtr = calloc<ffi.Float>(totalFloats);
    final sourceBytes = source.buffer.asUint8List(source.offsetInBytes, source.lengthInBytes);
    final sourcePtr = calloc<ffi.Uint8>(sourceBytes.length);
    sourcePtr.asTypedList(sourceBytes.length).setAll(0, sourceBytes);

    try {
      c.filament_transcode(
        targetPtr,
        sourcePtr.cast(),
        vertexCount,
        config.componentType.value,
        config.normalized,
        config.componentCount,
        config.inputStrideBytes,
      );

      final result = Float32List.fromList(targetPtr.asTypedList(totalFloats));
      return result;
    } finally {
      calloc.free(targetPtr);
      calloc.free(sourcePtr);
    }
  }

  /// Calculates the required output buffer size in bytes for [vertexCount] items.
  static int outputSize({required int vertexCount, required int componentCount}) {
    return c.filament_transcode_output_size(vertexCount, componentCount);
  }
}

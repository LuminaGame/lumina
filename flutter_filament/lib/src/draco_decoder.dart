import 'ffi_platform.dart' as ffi;
import 'dart:typed_data';
import 'ffi_package_platform.dart';
import 'filament_bindings.dart' as c;

class FilamentDracoDecodedMesh {
  final List<double> positions;
  final List<double> uvs;
  final List<int> indices;

  const FilamentDracoDecodedMesh({
    required this.positions,
    required this.uvs,
    required this.indices,
  });
}

class FilamentDracoDecoder {
  static FilamentDracoDecodedMesh? decode(Uint8List compressedBytes) {
    if (compressedBytes.isEmpty) return null;

    final inPtr = calloc<ffi.Uint8>(compressedBytes.length);
    inPtr.asTypedList(compressedBytes.length).setAll(0, compressedBytes);

    final vertCountPtr = calloc<ffi.Uint32>();
    final indexCountPtr = calloc<ffi.Uint32>();

    try {
      final querySuccess = c.filament_gltf_decode_draco(
        inPtr,
        compressedBytes.length,
        ffi.nullptr,
        ffi.nullptr,
        ffi.nullptr,
        vertCountPtr,
        indexCountPtr,
      );

      if (!querySuccess || vertCountPtr.value == 0 || indexCountPtr.value == 0) {
        return null;
      }

      final vertCount = vertCountPtr.value;
      final indexCount = indexCountPtr.value;

      final posPtr = calloc<ffi.Float>(vertCount * 3);
      final uvPtr = calloc<ffi.Float>(vertCount * 2);
      final indPtr = calloc<ffi.Uint32>(indexCount);

      final decodeSuccess = c.filament_gltf_decode_draco(
        inPtr,
        compressedBytes.length,
        posPtr,
        uvPtr,
        indPtr,
        vertCountPtr,
        indexCountPtr,
      );

      if (!decodeSuccess) {
        calloc.free(posPtr);
        calloc.free(uvPtr);
        calloc.free(indPtr);
        return null;
      }

      final positions = posPtr.asTypedList(vertCount * 3).map((e) => e.toDouble()).toList();
      final uvs = uvPtr.asTypedList(vertCount * 2).map((e) => e.toDouble()).toList();
      final indices = indPtr.asTypedList(indexCount).toList();

      calloc.free(posPtr);
      calloc.free(uvPtr);
      calloc.free(indPtr);

      return FilamentDracoDecodedMesh(positions: positions, uvs: uvs, indices: indices);
    } catch (_) {
      return null;
    } finally {
      calloc.free(inPtr);
      calloc.free(vertCountPtr);
      calloc.free(indexCountPtr);
    }
  }
}

import 'ffi_platform.dart' as ffi;
import 'dart:typed_data';
import 'ffi_package_platform.dart';
import 'filament_bindings.dart' as c;
import 'engine.dart';

class SkinningBuffer {
  ffi.Pointer<ffi.Void> _nativeBuffer;
  final FilamentEngine engine;
  final int _boneCount;

  SkinningBuffer._(this._nativeBuffer, this.engine, this._boneCount);

  /// Creates a SkinningBuffer.
  /// 
  /// The [boneCount] will be automatically rounded up to the nearest multiple of 256
  /// as required by Filament. 
  /// If [initialize] is true, the buffer will be initialized with identity matrices.
  factory SkinningBuffer.create(FilamentEngine engine, {required int boneCount, bool initialize = true}) {
    // Filament requires boneCount to be a multiple of 256.
    final roundedBoneCount = ((boneCount + 255) ~/ 256) * 256;
    
    final nativeBuffer = c.filament_skinning_buffer_create(
      engine.nativePointer,
      roundedBoneCount,
      initialize,
    );

    if (nativeBuffer == ffi.nullptr) {
      throw StateError('Failed to create SkinningBuffer');
    }

    return SkinningBuffer._(nativeBuffer, engine, roundedBoneCount);
  }

  /// Updates bones from an array of dual quaternions (represented by FilamentBone).
  void setBones(List<ffi.Pointer<c.FilamentBone>> bones, {int offset = 0}) {
    if (offset + bones.length > _boneCount) {
      throw RangeError('offset + bones.length (${offset + bones.length}) exceeds boneCount ($_boneCount)');
    }

    using((Arena arena) {
      final bonesArray = arena<c.FilamentBone>(bones.length);
      for (var i = 0; i < bones.length; i++) {
        bonesArray[i] = bones[i].ref;
      }
      c.filament_skinning_buffer_set_bones(
        engine.nativePointer,
        _nativeBuffer,
        bonesArray,
        bones.length,
        offset,
      );
    });
  }

  /// Updates bones from an array of 4x4 column-major matrices.
  void setBonesFromMatrices(Float32List matrices, {int? count, int offset = 0}) {
    final actualCount = count ?? matrices.length ~/ 16;
    
    if (offset + actualCount > _boneCount) {
      throw RangeError('offset + count (${offset + actualCount}) exceeds boneCount ($_boneCount)');
    }
    
    if (matrices.length < actualCount * 16) {
      throw ArgumentError('matrices list is too small for count $actualCount. Expected at least ${actualCount * 16} floats.');
    }

    using((Arena arena) {
      final matricesArray = arena<ffi.Float>(actualCount * 16);
      matricesArray.asTypedList(actualCount * 16).setAll(0, matrices.take(actualCount * 16));
      c.filament_skinning_buffer_set_bones_matrices(
        engine.nativePointer,
        _nativeBuffer,
        matricesArray,
        actualCount,
        offset,
      );
    });
  }

  /// Returns the (rounded) capacity of the buffer.
  int get boneCount => _boneCount;
  
  /// The underlying native pointer for internal bindings.
  ffi.Pointer<ffi.Void> get nativePtr => _nativeBuffer;

  /// Destroys the SkinningBuffer.
  void destroy() {
    if (_nativeBuffer != ffi.nullptr) {
      c.filament_engine_destroy_skinning_buffer(engine.nativePointer, _nativeBuffer);
      _nativeBuffer = ffi.nullptr;
    }
  }
}

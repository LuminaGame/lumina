import 'package:flutter_filament/ffi.dart' as ffi;
import 'dart:typed_data';
import 'package:flutter_filament/ffi_package.dart';
import 'package:flutter_filament/filament.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/src/components/mesh/skeletal_mesh_component.dart';

/// Bridge for Filament C++ RenderableManager::setSkinningBuffer FFI bindings.
/// Allocates flat Float32List SIMD matrices for zero-GC GPU skinning uploads.
class FilamentSkinningBufferBridge {
  final int requestedBoneCount;
  SkinningBuffer? _skinningBuffer;
  ffi.Pointer<ffi.Float>? _nativeMemory;
  Float32List? _skinningTransforms;
  
  final Matrix4 _scratchMatrix = Matrix4.identity();

  FilamentSkinningBufferBridge._(
    this.requestedBoneCount,
    this._skinningBuffer,
    this._nativeMemory,
    this._skinningTransforms,
  );

  /// Creates a zero-GC skinning bridge.
  /// 
  /// The underlying [SkinningBuffer] rounds capacity up to a multiple of 256.
  factory FilamentSkinningBufferBridge.create(FilamentEngine engine, {required int boneCount}) {
    final buffer = SkinningBuffer.create(engine, boneCount: boneCount, initialize: true);
    
    // allocate memory using calloc (freed in dispose, invisible to GC, lives as long as the component)
    final nativeMemory = calloc<ffi.Float>(buffer.boneCount * 16);
    final skinningTransforms = nativeMemory.asTypedList(buffer.boneCount * 16);

    return FilamentSkinningBufferBridge._(boneCount, buffer, nativeMemory, skinningTransforms);
  }

  /// The physical capacity of the buffer (rounded up to a multiple of 256).
  int get paletteBoneCount => _skinningBuffer?.boneCount ?? 0;

  /// The memory view used to write matrices before upload.
  Float32List get skinningTransforms {
    if (_skinningTransforms == null) throw StateError('Bridge disposed');
    return _skinningTransforms!;
  }

  /// Computes final skinning matrices ($M_{skinning} = G_{bone} \times InverseBindMatrix$) into [skinningTransforms].
  /// Does zero memory allocation per frame.
  void updateSkinningMatrices(Skeleton skeleton) {
    if (_skinningTransforms == null) throw StateError('Bridge disposed');
    
    if (skeleton.boneCount > requestedBoneCount) {
      throw ArgumentError('Skeleton bone count (${skeleton.boneCount}) exceeds requested bone capacity ($requestedBoneCount)');
    }
    
    final transforms = _skinningTransforms!;
    for (int i = 0; i < skeleton.boneCount; i++) {
      final bone = skeleton[i];
      // Compute G_bone * IBM
      _scratchMatrix.setFrom(bone.globalTransform);
      _scratchMatrix.multiply(bone.inverseBindMatrix);
      
      final storage = _scratchMatrix.storage;
      final offset = i * 16;
      for (int j = 0; j < 16; j++) {
        transforms[offset + j] = storage[j];
      }
    }
  }

  /// Uploads the computed skinning palette to the GPU.
  void upload({int offset = 0}) {
    if (_skinningBuffer == null) throw StateError('Bridge disposed');
    // Note: setBonesFromMatrices copies at call time inside FFI boundary.
    _skinningBuffer!.setBonesFromMatrices(_skinningTransforms!, count: requestedBoneCount, offset: offset);
  }

  /// Binds the skinning buffer to a renderable entity.
  void bindToRenderable(FilamentRenderableManager rm, int entity, {int offset = 0}) {
    if (_skinningBuffer == null) throw StateError('Bridge disposed');
    rm.setSkinningBuffer(entity, _skinningBuffer!, count: requestedBoneCount, offset: offset);
  }

  /// Frees native memory and destroys the SkinningBuffer. Double-dispose safe.
  void dispose() {
    if (_skinningBuffer != null) {
      _skinningBuffer!.destroy();
      _skinningBuffer = null;
    }
    if (_nativeMemory != null) {
      calloc.free(_nativeMemory!);
      _nativeMemory = null;
      _skinningTransforms = null;
    }
  }
}

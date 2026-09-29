
import 'dart:typed_data';
import 'package:vector_math/vector_math_64.dart';
import 'dart:math' as math;
import 'package:flutter_filament/flutter_filament.dart';
import '../base/scene_component.dart';
import '../../object/actor.dart';
import 'skinning_buffer.dart';
import 'morph_target_set.dart';
import '../../animation/anim_instance.dart';

class LuminaSocket {
  final String name;
  final String boneName;
  final Matrix4 localOffset;

  LuminaSocket(this.name, this.boneName, this.localOffset);

  factory LuminaSocket.at(String name, String boneName, {Vector3? translation, Quaternion? rotation}) {
    final mat = Matrix4.identity();
    if (translation != null || rotation != null) {
      mat.setFromTranslationRotation(
        translation ?? Vector3.zero(),
        rotation ?? Quaternion.identity(),
      );
    }
    return LuminaSocket(name, boneName, mat);
  }
}

class _SocketAttachment {
  final LuminaSceneComponent component;
  final String socketName;
  final Matrix4 relativeOffset;

  _SocketAttachment(this.component, this.socketName, this.relativeOffset);
}

class BoneNode {
  final int id;
  String name;
  final int parentIndex;
  
  Matrix4 localTransform;
  Matrix4 globalTransform;
  Matrix4 inverseBindMatrix;

  final Vector3 translation = Vector3.zero();
  final Quaternion rotation = Quaternion.identity();
  final Vector3 scale = Vector3.all(1.0);

  final Vector3 bindTranslation = Vector3.zero();
  final Quaternion bindRotation = Quaternion.identity();
  final Vector3 bindScale = Vector3.all(1.0);

  BoneNode({
    required this.id,
    required this.name,
    this.parentIndex = -1,
    Matrix4? localTransform,
    Matrix4? globalTransform,
    Matrix4? inverseBindMatrix,
  })  : localTransform = localTransform ?? Matrix4.identity(),
        globalTransform = globalTransform ?? Matrix4.identity(),
        inverseBindMatrix = inverseBindMatrix ?? Matrix4.identity();

  void composeLocal() {
    localTransform.setFromTranslationRotationScale(translation, rotation, scale);
  }
}

class Skeleton {
  final List<BoneNode> _bones;
  final Map<String, int> _nameToIndex = {};
  final List<int> _rootIndices = [];

  Skeleton(List<BoneNode> bones) : _bones = bones {
    for (int i = 0; i < _bones.length; i++) {
      final bone = _bones[i];
      if (bone.parentIndex >= i) {
        throw ArgumentError('Topological order violated for bone "${bone.name}": parentIndex ${bone.parentIndex} >= $i');
      }
      _nameToIndex[bone.name] = i;
      if (bone.parentIndex == -1) {
        _rootIndices.add(i);
      }
    }
  }

  int get boneCount => _bones.length;

  BoneNode operator [](int index) => _bones[index];

  int indexOfBone(String name) => _nameToIndex[name] ?? -1;

  BoneNode? findBone(String name) {
    final index = indexOfBone(name);
    if (index != -1) return _bones[index];
    return null;
  }

  List<int> get rootIndices => _rootIndices;

  void updateGlobalTransforms() {
    for (int i = 0; i < _bones.length; i++) {
      final bone = _bones[i];
      if (bone.parentIndex == -1) {
        bone.globalTransform.setFrom(bone.localTransform);
      } else {
        final parent = _bones[bone.parentIndex];
        bone.globalTransform.setFrom(parent.globalTransform);
        bone.globalTransform.multiply(bone.localTransform);
      }
    }
  }

  void resetToBindPose() {
    for (int i = 0; i < _bones.length; i++) {
      final bone = _bones[i];
      bone.translation.setFrom(bone.bindTranslation);
      bone.rotation.setFrom(bone.bindRotation);
      bone.scale.setFrom(bone.bindScale);
      bone.composeLocal();
    }
  }
}

class TransformCurve {
  final Float32List times;
  final List<Vector3> translations;
  final List<Quaternion> rotations;
  final List<Vector3> scales;

  TransformCurve(this.times, this.translations, this.rotations, this.scales);

  void sampleInto(double time, BoneNode bone) {
    if (times.isEmpty) return;

    if (time <= times.first) {
      bone.translation.setFrom(translations.first);
      bone.rotation.setFrom(rotations.first);
      bone.scale.setFrom(scales.first);
      return;
    }
    
    if (time >= times.last) {
      bone.translation.setFrom(translations.last);
      bone.rotation.setFrom(rotations.last);
      bone.scale.setFrom(scales.last);
      return;
    }

    int low = 0;
    int high = times.length - 1;
    while (low <= high) {
      final mid = (low + high) >> 1;
      if (times[mid] < time) {
        low = mid + 1;
      } else if (times[mid] > time) {
        high = mid - 1;
      } else {
        low = mid;
        break;
      }
    }
    
    int index0 = high >= 0 ? high : 0;
    int index1 = low < times.length ? low : times.length - 1;

    if (index0 == index1) {
      bone.translation.setFrom(translations[index0]);
      bone.rotation.setFrom(rotations[index0]);
      bone.scale.setFrom(scales[index0]);
      return;
    }

    final t0 = times[index0];
    final t1 = times[index1];
    final alpha = (time - t0) / (t1 - t0);

    // Translation lerp
    final v0 = translations[index0];
    final v1 = translations[index1];
    bone.translation.setValues(
      v0.x + (v1.x - v0.x) * alpha,
      v0.y + (v1.y - v0.y) * alpha,
      v0.z + (v1.z - v0.z) * alpha,
    );

    // Scale lerp
    final s0 = scales[index0];
    final s1 = scales[index1];
    bone.scale.setValues(
      s0.x + (s1.x - s0.x) * alpha,
      s0.y + (s1.y - s0.y) * alpha,
      s0.z + (s1.z - s0.z) * alpha,
    );

    // Rotation slerp (in-place, double cover guard)
    final q0 = rotations[index0];
    final q1 = rotations[index1];

    double cosOmega = q0.x * q1.x + q0.y * q1.y + q0.z * q1.z + q0.w * q1.w;
    double sign = 1.0;
    if (cosOmega < 0.0) {
      cosOmega = -cosOmega;
      sign = -1.0;
    }

    double k0, k1;
    if (cosOmega > 0.9999) {
      // Linear interpolation for small angles
      k0 = 1.0 - alpha;
      k1 = alpha * sign;
    } else {
      final sinOmega = math.sqrt(1.0 - cosOmega * cosOmega);
      final omega = math.atan2(sinOmega, cosOmega);
      final invSinOmega = 1.0 / sinOmega;
      k0 = math.sin((1.0 - alpha) * omega) * invSinOmega;
      k1 = math.sin(alpha * omega) * invSinOmega * sign;
    }

    bone.rotation.setValues(
      q0.x * k0 + q1.x * k1,
      q0.y * k0 + q1.y * k1,
      q0.z * k0 + q1.z * k1,
      q0.w * k0 + q1.w * k1,
    );
    bone.rotation.normalize();
  }
}

/// Skinned mesh component supporting bone hierarchies, sockets, and animation interpolation.
class LuminaSkinnedMeshComponent extends LuminaSceneComponent {
  final String? meshAssetPath;
  Skeleton? _skeleton;
  FilamentSkinningBufferBridge? _skinningBridge;

  MorphTargetSet? _morphTargets;
  final Map<int, Float32List> _morphStaging = {};
  final Set<int> _dirtyMorphEntities = {};

  final List<LuminaSocket> _sockets = [];
  final Map<String, int> _socketBoneIndices = {};
  final List<_SocketAttachment> _attachments = [];

  // Scratch matrices/vectors for zero-allocation math
  final Matrix4 _scratchMatrix1 = Matrix4.identity();
  final Matrix4 _scratchMatrix2 = Matrix4.identity();
  final Vector3 _scratchVector = Vector3.zero();

  /// Active animation instance driving skeletal bone transforms.
  LuminaAnimInstance? animInstance;

  LuminaSkinnedMeshComponent({
    super.key,
    super.location,
    super.rotation,
    this.meshAssetPath,
    this.animInstance,
  });

  Skeleton? get skeleton => _skeleton;

  void setSkeleton(Skeleton? s) {
    _skeleton = s;
    if (s != null) {
      // Re-resolve all bones
      for (final socket in _sockets) {
        final index = s.indexOfBone(socket.boneName);
        if (index == -1) {
          throw StateError('Skeleton swapped but missing bone "${socket.boneName}" for socket "${socket.name}"');
        }
        _socketBoneIndices[socket.name] = index;
      }
    }
    if (isRegistered) {
      _rebuildSkinningBridge();
    }
  }

  void _rebuildSkinningBridge() {
    if (_skinningBridge != null) {
      _skinningBridge!.dispose();
      _skinningBridge = null;
    }
    final skel = _skeleton;
    final w = owner?.world;
    if (skel == null || w == null) return;
    if (!w.hasNativeContext) return;

    _skinningBridge = FilamentSkinningBufferBridge.create(w.filamentEngine, boneCount: skel.boneCount);
  }

  @override
  void onRegister(LuminaActor ownerActor) {
    super.onRegister(ownerActor);
    _rebuildSkinningBridge();
  }

  @override
  void onUnregister() {
    if (_skinningBridge != null) {
      _skinningBridge!.dispose();
      _skinningBridge = null;
    }
    super.onUnregister();
  }
  
  @override
  void onTick(double deltaTime) {
    super.onTick(deltaTime);
    animInstance?.update(deltaTime);
    if (_skeleton != null) {
      _skeleton!.updateGlobalTransforms();
      if (_skinningBridge != null) {
        _skinningBridge!.updateSkinningMatrices(_skeleton!);
        _skinningBridge!.upload();
      }
      
      // Update followers
      if (_attachments.isNotEmpty) {
        for (final attachment in _attachments) {
          final socket = findSocket(attachment.socketName);
          if (socket != null) {
            final boneIndex = _socketBoneIndices[socket.name]!;
            final boneGlobal = _skeleton![boneIndex].globalTransform;
            
            // Socket-relative pose in component space = G_bone * socketOffset * attachmentOffset
            _scratchMatrix1.setFrom(boneGlobal);
            _scratchMatrix1.multiply(socket.localOffset);
            _scratchMatrix1.multiply(attachment.relativeOffset);
            
            // Extract translation and rotation (component space)
            attachment.component.relativeLocation = _scratchMatrix1.getTranslation();
            
            // For rotation, we must normalize the upper 3x3 to avoid skewing from scale
            _scratchMatrix2.setFrom(_scratchMatrix1);
            _scratchVector.setValues(_scratchMatrix2.entry(0, 0), _scratchMatrix2.entry(1, 0), _scratchMatrix2.entry(2, 0));
            final sx = _scratchVector.length;
            _scratchVector.setValues(_scratchMatrix2.entry(0, 1), _scratchMatrix2.entry(1, 1), _scratchMatrix2.entry(2, 1));
            final sy = _scratchVector.length;
            _scratchVector.setValues(_scratchMatrix2.entry(0, 2), _scratchMatrix2.entry(1, 2), _scratchMatrix2.entry(2, 2));
            final sz = _scratchVector.length;
            
            if (sx != 0.0) {
              _scratchMatrix2.setEntry(0, 0, _scratchMatrix2.entry(0, 0) / sx);
              _scratchMatrix2.setEntry(1, 0, _scratchMatrix2.entry(1, 0) / sx);
              _scratchMatrix2.setEntry(2, 0, _scratchMatrix2.entry(2, 0) / sx);
            }
            if (sy != 0.0) {
              _scratchMatrix2.setEntry(0, 1, _scratchMatrix2.entry(0, 1) / sy);
              _scratchMatrix2.setEntry(1, 1, _scratchMatrix2.entry(1, 1) / sy);
              _scratchMatrix2.setEntry(2, 1, _scratchMatrix2.entry(2, 1) / sy);
            }
            if (sz != 0.0) {
              _scratchMatrix2.setEntry(0, 2, _scratchMatrix2.entry(0, 2) / sz);
              _scratchMatrix2.setEntry(1, 2, _scratchMatrix2.entry(1, 2) / sz);
              _scratchMatrix2.setEntry(2, 2, _scratchMatrix2.entry(2, 2) / sz);
            }
            
            final rot = Quaternion.fromRotation(_scratchMatrix2.getRotation());
            attachment.component.relativeRotation = rot;
          }
        }
      }
    }

    // Flush morph targets
    if (_morphTargets != null && _dirtyMorphEntities.isNotEmpty && owner?.world != null) {
      final rm = RenderableManager(owner!.world!.filamentEngine);
      for (final entity in _dirtyMorphEntities) {
        final staging = _morphStaging[entity]!;
        rm.setMorphWeights(entity, staging, offset: 0);
      }
      _dirtyMorphEntities.clear();
    }
  }

  void addSocket(LuminaSocket socket) {
    if (_sockets.any((s) => s.name == socket.name)) {
      throw ArgumentError('Duplicate socket name: ${socket.name}');
    }
    if (_skeleton != null) {
      final index = _skeleton!.indexOfBone(socket.boneName);
      if (index == -1) {
        throw ArgumentError('Unknown bone: ${socket.boneName}');
      }
      _socketBoneIndices[socket.name] = index;
    }
    _sockets.add(socket);
  }

  bool removeSocket(String name) {
    final idx = _sockets.indexWhere((s) => s.name == name);
    if (idx != -1) {
      _sockets.removeAt(idx);
      _socketBoneIndices.remove(name);
      return true;
    }
    return false;
  }

  LuminaSocket? findSocket(String name) {
    for (final socket in _sockets) {
      if (socket.name == name) return socket;
    }
    return null;
  }

  List<String> get socketNames => _sockets.map((s) => s.name).toList();

  /// Computes world transform for a socket attached to [boneIndex].
  Matrix4 getSocketWorldTransform(int boneIndex, Matrix4 localOffset, {Matrix4? out}) {
    if (_skeleton == null) {
      throw StateError('no skeleton');
    }
    if (boneIndex < 0 || boneIndex >= _skeleton!.boneCount) {
      throw RangeError.value(boneIndex, 'boneIndex', 'Out of bounds');
    }
    
    final result = out ?? Matrix4.identity();
    final boneGlobal = _skeleton![boneIndex].globalTransform;
    final worldMat = Matrix4.compose(worldLocation, worldRotation, relativeScale);
    
    result.setFrom(worldMat);
    result.multiply(boneGlobal);
    result.multiply(localOffset);
    return result;
  }

  Matrix4 getSocketTransformByName(String socketName, {Matrix4? out}) {
    final socket = findSocket(socketName);
    if (socket == null) {
      throw StateError('Unknown socket: $socketName');
    }
    return getSocketWorldTransform(_socketBoneIndices[socketName]!, socket.localOffset, out: out);
  }

  Vector3 getSocketLocation(String socketName, {Vector3? out}) {
    final result = out ?? Vector3.zero();
    final mat = getSocketTransformByName(socketName, out: _scratchMatrix1);
    result.setValues(mat.entry(0, 3), mat.entry(1, 3), mat.entry(2, 3));
    return result;
  }

  Quaternion getSocketRotation(String socketName, {Quaternion? out}) {
    final mat = getSocketTransformByName(socketName, out: _scratchMatrix1);
    final result = out ?? Quaternion.identity();
    
    // Normalize upper 3x3 to drop scale
    _scratchVector.setValues(mat.entry(0, 0), mat.entry(1, 0), mat.entry(2, 0));
    final sx = _scratchVector.length;
    _scratchVector.setValues(mat.entry(0, 1), mat.entry(1, 1), mat.entry(2, 1));
    final sy = _scratchVector.length;
    _scratchVector.setValues(mat.entry(0, 2), mat.entry(1, 2), mat.entry(2, 2));
    final sz = _scratchVector.length;
    
    if (sx != 0.0) {
      mat.setEntry(0, 0, mat.entry(0, 0) / sx);
      mat.setEntry(1, 0, mat.entry(1, 0) / sx);
      mat.setEntry(2, 0, mat.entry(2, 0) / sx);
    }
    if (sy != 0.0) {
      mat.setEntry(0, 1, mat.entry(0, 1) / sy);
      mat.setEntry(1, 1, mat.entry(1, 1) / sy);
      mat.setEntry(2, 1, mat.entry(2, 1) / sy);
    }
    if (sz != 0.0) {
      mat.setEntry(0, 2, mat.entry(0, 2) / sz);
      mat.setEntry(1, 2, mat.entry(1, 2) / sz);
      mat.setEntry(2, 2, mat.entry(2, 2) / sz);
    }
    
    result.setFromRotation(mat.getRotation());
    return result;
  }

  void attachToSocket(LuminaSceneComponent component, String socketName, {Matrix4? relativeOffset}) {
    component.attachToComponent(this);
    final offset = relativeOffset ?? Matrix4.identity();
    _attachments.add(_SocketAttachment(component, socketName, offset));
  }

  void detachFromSocket(LuminaSceneComponent component) {
    _attachments.removeWhere((a) => a.component == component);
    // Component remains attached to this MeshComponent, but no longer tracks the socket.
  }

  // --- Morph Targets ---
  
  void discoverMorphTargets(FilamentAsset asset) {
    _morphTargets = MorphTargetSet.fromAsset(asset);
    _morphStaging.clear();
    _dirtyMorphEntities.clear();
    
    for (final entity in asset.entities) {
      final count = asset.getMorphTargetCountAt(entity);
      if (count > 0) {
        _morphStaging[entity] = Float32List(count);
      }
    }
  }

  List<String> get morphTargetNames {
    if (_morphTargets == null) {
      throw StateError('no morph targets discovered');
    }
    return _morphTargets!.names;
  }

  MorphTargetHandle resolveMorphTarget(String name) {
    if (_morphTargets == null) {
      throw StateError('no morph targets discovered');
    }
    final handle = _morphTargets!.getHandle(name);
    if (handle == null) {
      final available = _morphTargets!.names.join(', ');
      throw ArgumentError('Unknown morph target: "$name". Available: $available');
    }
    return handle;
  }

  void setMorphTarget(String name, double weight) {
    final handle = resolveMorphTarget(name);
    setMorphTargetByHandle(handle, weight);
  }

  void setMorphTargetByHandle(MorphTargetHandle handle, double weight) {
    for (final target in handle.targets) {
      final entity = target.$1;
      final index = target.$2;
      _morphStaging[entity]![index] = weight;
      _dirtyMorphEntities.add(entity);
    }
  }

  double getMorphTarget(String name) {
    final handle = resolveMorphTarget(name);
    if (handle.targets.isEmpty) return 0.0;
    // Just return the first one as representative
    final target = handle.targets.first;
    return _morphStaging[target.$1]![target.$2];
  }

  void clearMorphTargets() {
    if (_morphTargets == null) return;
    for (final entry in _morphStaging.entries) {
      final arr = entry.value;
      for (int i = 0; i < arr.length; i++) {
        arr[i] = 0.0;
      }
      _dirtyMorphEntities.add(entry.key);
    }
  }
}


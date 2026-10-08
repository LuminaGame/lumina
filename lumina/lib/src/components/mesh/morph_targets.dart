import 'dart:typed_data';

import 'package:flutter_filament/filament.dart';
import 'package:lumina/src/components/base/scene_component.dart';
import 'package:lumina/src/components/mesh/morph_target_set.dart';

/// Morph target weights of a mesh component: the targets are discovered by
/// name from the renderables of its asset (or asset instance), weights are
/// staged per renderable and written to Filament by [flushMorphTargets].
mixin LuminaMorphTargets on LuminaSceneComponent {
  MorphTargetSet? _morphTargets;
  final Map<int, Float32List> _morphStaging = {};
  final Set<int> _dirtyMorphEntities = {};

  /// Whether targets were discovered and there is at least one.
  bool get hasMorphTargets => _morphTargets != null && _morphTargets!.names.isNotEmpty;

  /// Discovers the targets of [asset]'s own entities.
  void discoverMorphTargets(FilamentAsset asset) => discoverMorphTargetsOf(asset, asset.entities);

  /// Discovers the targets of [entities] (an asset instance's entities),
  /// names read through [asset].
  void discoverMorphTargetsOf(FilamentAsset asset, List<int> entities) {
    _morphTargets = MorphTargetSet.fromEntities(asset, entities);
    _morphStaging.clear();
    _dirtyMorphEntities.clear();
    for (final entity in entities) {
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

  /// Whether a target named [name] was discovered.
  bool hasMorphTarget(String name) => _morphTargets?.contains(name) ?? false;

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

  /// Writes the weights changed since the last flush to Filament.
  void flushMorphTargets() {
    final world = owner?.world;
    if (_morphTargets == null || _dirtyMorphEntities.isEmpty || world == null || !world.hasNativeContext) return;
    final rm = RenderableManager(world.filamentEngine);
    for (final entity in _dirtyMorphEntities) {
      rm.setMorphWeights(entity, _morphStaging[entity]!, offset: 0);
    }
    _dirtyMorphEntities.clear();
  }
}

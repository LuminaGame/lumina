
import 'package:flutter_filament/filament.dart';

class MorphTargetHandle {
  final String name;
  final List<(int, int)> targets; // entity, index

  MorphTargetHandle(this.name, this.targets);
}

class MorphTargetSet {
  final Map<String, MorphTargetHandle> _handles = {};
  final List<String> _names = [];

  List<String> get names => List.unmodifiable(_names);
  
  bool contains(String name) => _handles.containsKey(name);

  MorphTargetHandle? getHandle(String name) => _handles[name];

  MorphTargetSet.fromAsset(FilamentAsset asset) : this.fromEntities(asset, asset.entities);

  /// The targets of [entities] (for example an asset instance's), names
  /// read through [asset].
  MorphTargetSet.fromEntities(FilamentAsset asset, List<int> entities) {
    for (final entity in entities) {
      final count = asset.getMorphTargetCountAt(entity);
      for (int i = 0; i < count; i++) {
        String name = asset.getMorphTargetNameAt(entity, i) ?? 'morph_$i';
        
        if (!_handles.containsKey(name)) {
          _handles[name] = MorphTargetHandle(name, []);
          _names.add(name);
        }
        
        _handles[name]!.targets.add((entity, i));
      }
    }
  }
}

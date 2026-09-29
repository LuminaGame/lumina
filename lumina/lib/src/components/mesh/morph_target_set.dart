
import 'package:flutter_filament/flutter_filament.dart';

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

  MorphTargetSet.fromAsset(FilamentAsset asset) {
    for (final entity in asset.entities) {
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

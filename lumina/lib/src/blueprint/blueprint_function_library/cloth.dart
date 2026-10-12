part of '../blueprint_function_library.dart';

/// [LuminaBlueprintFunctionLibrary.callShapes]: the owner's cloth.
const Map<String, LuminaBlueprintCallShape> _clothCallShapes = <String, LuminaBlueprintCallShape>{
  'set_cloth_wind': LuminaBlueprintCallShape('setClothWind', ['wind', 'drag'], self: true),
  'set_cloth_simulation_enabled': LuminaBlueprintCallShape('setClothSimulationEnabled', ['enabled'], self: true),
  'is_cloth_simulating': LuminaBlueprintCallShape('isClothSimulating', [], self: true, outputs: LuminaBlueprintFunctionLibrary._r),
  'reset_cloth': LuminaBlueprintCallShape('resetCloth', [], self: true),
  'pin_cloth_vertex': LuminaBlueprintCallShape('pinClothVertex', ['vertex', 'pinned'], self: true),
};

/// [LuminaBlueprintFunctionLibrary.builtInFunctions]: the owner's cloth.
final Map<String, LuminaBlueprintFunction> _clothFunctions = <String, LuminaBlueprintFunction>{
  'set_cloth_wind': (c, i) {
    LuminaBlueprintFunctionLibrary.setClothWind(c.self, _vec3(i['wind']), (i['drag'] as num?)?.toDouble() ?? 1.0);
    return const {};
  },
  'set_cloth_simulation_enabled': (c, i) {
    LuminaBlueprintFunctionLibrary.setClothSimulationEnabled(c.self, i['enabled'] as bool? ?? true);
    return const {};
  },
  'is_cloth_simulating': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.isClothSimulating(c.self)),
  'reset_cloth': (c, i) {
    LuminaBlueprintFunctionLibrary.resetCloth(c.self);
    return const {};
  },
  'pin_cloth_vertex': (c, i) {
    LuminaBlueprintFunctionLibrary.pinClothVertex(c.self, (i['vertex'] as num?)?.toInt() ?? 0, i['pinned'] as bool? ?? true);
    return const {};
  },
};

Iterable<LuminaClothComponent> _cloths(LuminaActor self) => self.components.whereType<LuminaClothComponent>();

/// Every cloth of the actor: [wind] in authoring axes (cm/s) at [drag] per
/// second.
void _setClothWind(LuminaActor self, Vector3 wind, [double drag = 1.0]) {
  for (final c in _cloths(self)) {
    c
      ..wind = LuminaBlueprintFunctionLibrary.toRuntime(wind)
      ..windDrag = drag;
  }
}

void _setClothSimulationEnabled(LuminaActor self, bool enabled) {
  for (final c in _cloths(self)) {
    c.simulate = enabled;
  }
}

/// Whether any cloth of the actor is simulated now (false on a backend
/// without cloth).
bool _isClothSimulating(LuminaActor self) => _cloths(self).any((c) => c.isSimulating);

void _resetCloth(LuminaActor self) {
  for (final c in _cloths(self)) {
    c.reset();
  }
}

/// Pins (or frees) simulation vertex [vertex] of the actor's first cloth
/// where it is now.
void _pinClothVertex(LuminaActor self, int vertex, [bool pinned = true]) =>
    _cloths(self).firstOrNull?.pinVertex(vertex, pinned: pinned);

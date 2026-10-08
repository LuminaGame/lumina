part of '../blueprint_function_library.dart';

/// [LuminaBlueprintFunctionLibrary.callShapes]: the owner's ragdoll.
const Map<String, LuminaBlueprintCallShape> _ragdollCallShapes = <String, LuminaBlueprintCallShape>{
  'start_ragdoll': LuminaBlueprintCallShape('startRagdoll', [], self: true, outputs: LuminaBlueprintFunctionLibrary._r),
  'stop_ragdoll': LuminaBlueprintCallShape('stopRagdoll', ['get_up'], self: true),
  'toggle_ragdoll': LuminaBlueprintCallShape('toggleRagdoll', [], self: true),
  'is_ragdoll': LuminaBlueprintCallShape('isRagdoll', [], self: true, outputs: LuminaBlueprintFunctionLibrary._r),
  'add_ragdoll_impulse': LuminaBlueprintCallShape('addRagdollImpulse', ['impulse', 'bone_name'], self: true),
};

/// [LuminaBlueprintFunctionLibrary.builtInFunctions]: the owner's ragdoll.
final Map<String, LuminaBlueprintFunction> _ragdollFunctions = <String, LuminaBlueprintFunction>{
  'start_ragdoll': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.startRagdoll(c.self)),
  'stop_ragdoll': (c, i) {
    LuminaBlueprintFunctionLibrary.stopRagdoll(c.self, i['get_up'] as bool? ?? true);
    return const {};
  },
  'toggle_ragdoll': (c, i) {
    LuminaBlueprintFunctionLibrary.toggleRagdoll(c.self);
    return const {};
  },
  'is_ragdoll': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.isRagdoll(c.self)),
  'add_ragdoll_impulse': (c, i) {
    LuminaBlueprintFunctionLibrary.addRagdollImpulse(c.self, _vec3(i['impulse']), i['bone_name'] as String? ?? '');
    return const {};
  },
};

LuminaRagdollComponent? _ragdoll(LuminaActor self) => self.getComponent<LuminaRagdollComponent>();

bool _startRagdoll(LuminaActor self) => _ragdoll(self)?.startRagdoll() ?? false;

void _stopRagdoll(LuminaActor self, [bool getUp = true]) => _ragdoll(self)?.stopRagdoll(getUp: getUp);

void _toggleRagdoll(LuminaActor self) => _ragdoll(self)?.toggleRagdoll();

bool _isRagdoll(LuminaActor self) => _ragdoll(self)?.isRagdoll ?? false;

/// [impulse] in authoring axes (kg·cm/s); starts the ragdoll when the
/// character is still animated.
void _addRagdollImpulse(LuminaActor self, Vector3 impulse, [String boneName = '']) =>
    _ragdoll(self)?.addImpulse(LuminaBlueprintFunctionLibrary.toRuntime(impulse), bone: boneName.isEmpty ? null : boneName);

part of '../blueprint_function_library.dart';

/// [LuminaBlueprintFunctionLibrary.callShapes]: the owner's character slots.
const Map<String, LuminaBlueprintCallShape> _characterSlotCallShapes = <String, LuminaBlueprintCallShape>{
  'set_slot_mesh': LuminaBlueprintCallShape('setSlotMesh', ['slot', 'mesh'], self: true, outputs: LuminaBlueprintFunctionLibrary._r),
  'clear_slot': LuminaBlueprintCallShape('clearSlot', ['slot'], self: true, outputs: LuminaBlueprintFunctionLibrary._r),
  'get_slot_mesh': LuminaBlueprintCallShape('getSlotMesh', ['slot'], self: true, outputs: LuminaBlueprintFunctionLibrary._r),
  'get_slots': LuminaBlueprintCallShape('getSlots', [], self: true, outputs: LuminaBlueprintFunctionLibrary._r),
};

/// [LuminaBlueprintFunctionLibrary.builtInFunctions]: the owner's character slots.
final Map<String, LuminaBlueprintFunction> _characterSlotFunctions = <String, LuminaBlueprintFunction>{
  'set_slot_mesh': (c, i) => LuminaBlueprintFunctionLibrary._ret(
    LuminaBlueprintFunctionLibrary.setSlotMesh(c.self, i['slot'] as String? ?? '', i['mesh'] as String? ?? ''),
  ),
  'clear_slot': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.clearSlot(c.self, i['slot'] as String? ?? '')),
  'get_slot_mesh': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getSlotMesh(c.self, i['slot'] as String? ?? '')),
  'get_slots': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getSlots(c.self)),
};

/// Fills the owner's [slot] with [mesh] (a mesh asset path; '' clears it).
/// True when the owner has that slot; the mesh loads in the background.
bool _setSlotMesh(LuminaActor self, String slot, String mesh) {
  final slots = LuminaCharacterSlots.maybeOf(self);
  if (slots == null || slots.slot(slot) == null) return false;
  unawaited(slots.setMesh(slot, mesh));
  return true;
}

/// Empties the owner's [slot]; true when the owner has that slot.
bool _clearSlot(LuminaActor self, String slot) {
  final slots = LuminaCharacterSlots.maybeOf(self);
  if (slots == null || slots.slot(slot) == null) return false;
  unawaited(slots.clear(slot));
  return true;
}

/// The mesh asset in the owner's [slot] ('' when empty or unknown).
String _getSlotMesh(LuminaActor self, String slot) => LuminaCharacterSlots.maybeOf(self)?.meshOf(slot) ?? '';

/// The owner's slot names.
List<String> _getSlots(LuminaActor self) => LuminaCharacterSlots.maybeOf(self)?.names ?? const [];

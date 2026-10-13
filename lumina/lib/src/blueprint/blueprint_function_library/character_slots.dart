part of '../blueprint_function_library.dart';

/// [LuminaBlueprintFunctionLibrary.callShapes]: the owner's character slots.
const Map<String, LuminaBlueprintCallShape> _characterSlotCallShapes = <String, LuminaBlueprintCallShape>{
  'set_slot_mesh': LuminaBlueprintCallShape('setSlotMesh', ['target', 'slot', 'mesh'], self: true, outputs: LuminaBlueprintFunctionLibrary._r),
  'clear_slot': LuminaBlueprintCallShape('clearSlot', ['target', 'slot'], self: true, outputs: LuminaBlueprintFunctionLibrary._r),
  'fit_garment': LuminaBlueprintCallShape('fitGarment', ['target', 'slot', 'garment'], self: true, outputs: LuminaBlueprintFunctionLibrary._r),
  'get_slot_mesh': LuminaBlueprintCallShape('getSlotMesh', ['target', 'slot'], self: true, outputs: LuminaBlueprintFunctionLibrary._r),
  'get_slots': LuminaBlueprintCallShape('getSlots', ['target'], self: true, outputs: LuminaBlueprintFunctionLibrary._r),
};

/// [LuminaBlueprintFunctionLibrary.builtInFunctions]: the owner's character slots.
final Map<String, LuminaBlueprintFunction> _characterSlotFunctions = <String, LuminaBlueprintFunction>{
  'set_slot_mesh': (c, i) => LuminaBlueprintFunctionLibrary._ret(
    LuminaBlueprintFunctionLibrary.setSlotMesh(c.self, i['target'], i['slot'] as String? ?? '', i['mesh'] as String? ?? ''),
  ),
  'fit_garment': (c, i) => LuminaBlueprintFunctionLibrary._ret(
    LuminaBlueprintFunctionLibrary.fitGarment(c.self, i['target'], i['slot'] as String? ?? '', i['garment'] as String? ?? ''),
  ),
  'clear_slot': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.clearSlot(c.self, i['target'], i['slot'] as String? ?? '')),
  'get_slot_mesh': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getSlotMesh(c.self, i['target'], i['slot'] as String? ?? '')),
  'get_slots': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getSlots(c.self, i['target'])),
};

/// Fills [slot] of [target] (the owner when null) with [mesh] (a mesh asset path; '' clears it).
/// True when the owner has that slot; the mesh loads in the background.
bool _setSlotMesh(LuminaActor self, Object? target, String slot, String mesh) {
  final slots = LuminaCharacterSlots.maybeOf(_target(self, target));
  if (slots == null || slots.slot(slot) == null) return false;
  unawaited(slots.setMesh(slot, mesh));
  return true;
}

/// Fits the Garment asset [garment] (its `.lmas`) into the owner's [slot],
/// on the body of the slot it follows (refitting it when it is there
/// already). True when the owner has that slot and [garment] is a `.lmas`;
/// the fit runs in the background on a worker isolate.
bool _fitGarment(LuminaActor self, Object? target, String slot, String garment) {
  final slots = LuminaCharacterSlots.maybeOf(_target(self, target));
  if (slots == null || slots.slot(slot) == null || !garment.toLowerCase().endsWith('.lmas')) return false;
  unawaited(slots.fitGarment(slot, garment));
  return true;
}

/// Empties the owner's [slot]; true when the owner has that slot.
bool _clearSlot(LuminaActor self, Object? target, String slot) {
  final slots = LuminaCharacterSlots.maybeOf(_target(self, target));
  if (slots == null || slots.slot(slot) == null) return false;
  unawaited(slots.clear(slot));
  return true;
}

/// The mesh asset in the owner's [slot] ('' when empty or unknown).
String _getSlotMesh(LuminaActor self, Object? target, String slot) =>
    LuminaCharacterSlots.maybeOf(_target(self, target))?.meshOf(slot) ?? '';

/// The owner's slot names.
List<String> _getSlots(LuminaActor self, [Object? target]) => LuminaCharacterSlots.maybeOf(_target(self, target))?.names ?? const [];

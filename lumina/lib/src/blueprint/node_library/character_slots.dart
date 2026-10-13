part of '../node_library.dart';

/// Built-in nodes: an actor's character slots (`LuminaCharacterSlots`):
/// Target's, or the owner's when Target is not connected.
final List<LuminaBlueprintNodeSpec> _characterSlotNodes = <LuminaBlueprintNodeSpec>[
  LuminaBlueprintNodeSpec(
    id: 'set_slot_mesh',
    title: 'Set Slot Mesh',
    category: 'Character|Slots',
    kind: LuminaBlueprintNodeKind.impure,
    headerColor: _function,
    keywords: const ['slot', 'mesh', 'hair', 'beard', 'garment', 'clothes', 'outfit', 'swap', 'character', 'part'],
    inputs: [
      _execIn,
      _obj('target', 'Target', LuminaBlueprintObjectClass.anyActor),
      const LuminaBlueprintPinSpec('slot', 'Slot', LuminaPinType.string, defaultValue: 'Hair'),
      const LuminaBlueprintPinSpec('mesh', 'Mesh', LuminaPinType.string, defaultValue: ''),
    ],
    outputs: [_execOut, _ret(LuminaPinType.boolean)],
  ),
  LuminaBlueprintNodeSpec(
    id: 'fit_garment',
    title: 'Fit Garment',
    category: 'Character|Slots',
    kind: LuminaBlueprintNodeKind.impure,
    headerColor: _function,
    keywords: const ['garment', 'fit', 'clothes', 'outfit', 'wear', 'refit', 'slot', 'character'],
    inputs: [
      _execIn,
      _obj('target', 'Target', LuminaBlueprintObjectClass.anyActor),
      const LuminaBlueprintPinSpec('slot', 'Slot', LuminaPinType.string, defaultValue: 'Torso'),
      const LuminaBlueprintPinSpec('garment', 'Garment', LuminaPinType.string, defaultValue: ''),
    ],
    outputs: [_execOut, _ret(LuminaPinType.boolean)],
  ),
  LuminaBlueprintNodeSpec(
    id: 'clear_slot',
    title: 'Clear Slot',
    category: 'Character|Slots',
    kind: LuminaBlueprintNodeKind.impure,
    headerColor: _function,
    keywords: const ['slot', 'clear', 'remove', 'empty', 'garment', 'character', 'part'],
    inputs: [
      _execIn,
      _obj('target', 'Target', LuminaBlueprintObjectClass.anyActor),
      const LuminaBlueprintPinSpec('slot', 'Slot', LuminaPinType.string, defaultValue: 'Hair'),
    ],
    outputs: [_execOut, _ret(LuminaPinType.boolean)],
  ),
  LuminaBlueprintNodeSpec(
    id: 'get_slot_mesh',
    title: 'Get Slot Mesh',
    category: 'Character|Slots',
    kind: LuminaBlueprintNodeKind.pure,
    headerColor: _pure,
    keywords: const ['slot', 'mesh', 'character', 'part'],
    inputs: [
      _obj('target', 'Target', LuminaBlueprintObjectClass.anyActor),
      const LuminaBlueprintPinSpec('slot', 'Slot', LuminaPinType.string, defaultValue: 'Hair'),
    ],
    outputs: [_ret(LuminaPinType.string)],
  ),
  LuminaBlueprintNodeSpec(
    id: 'get_slots',
    title: 'Get Slots',
    category: 'Character|Slots',
    kind: LuminaBlueprintNodeKind.pure,
    headerColor: _pure,
    keywords: const ['slots', 'parts', 'character', 'list'],
    inputs: [_obj('target', 'Target', LuminaBlueprintObjectClass.anyActor)],
    outputs: const [LuminaBlueprintPinSpec(_returnValue, 'Return Value', LuminaPinType.array, elementType: LuminaPinType.string)],
  ),
];

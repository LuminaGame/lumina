part of '../node_library.dart';

/// Built-in nodes: the owner's cloth (`LuminaClothComponent`).
final List<LuminaBlueprintNodeSpec> _clothNodes = <LuminaBlueprintNodeSpec>[
  LuminaBlueprintNodeSpec(
    id: 'set_cloth_wind',
    title: 'Set Cloth Wind',
    category: 'Physics|Cloth',
    kind: LuminaBlueprintNodeKind.impure,
    headerColor: _function,
    keywords: const ['cloth', 'wind', 'flag', 'curtain', 'blow', 'physics'],
    inputs: const [
      _execIn,
      LuminaBlueprintPinSpec('wind', 'Wind', LuminaPinType.vector),
      LuminaBlueprintPinSpec('drag', 'Drag', LuminaPinType.float, defaultValue: 1.0),
    ],
    outputs: const [_execOut],
  ),
  LuminaBlueprintNodeSpec(
    id: 'set_cloth_simulation_enabled',
    title: 'Set Cloth Simulation Enabled',
    category: 'Physics|Cloth',
    kind: LuminaBlueprintNodeKind.impure,
    headerColor: _function,
    keywords: const ['cloth', 'simulate', 'enable', 'disable', 'freeze', 'physics'],
    inputs: const [_execIn, LuminaBlueprintPinSpec('enabled', 'Enabled', LuminaPinType.boolean, defaultValue: true)],
    outputs: const [_execOut],
  ),
  LuminaBlueprintNodeSpec(
    id: 'is_cloth_simulating',
    title: 'Is Cloth Simulating',
    category: 'Physics|Cloth',
    kind: LuminaBlueprintNodeKind.pure,
    headerColor: _pure,
    keywords: const ['cloth', 'simulating', 'physics'],
    outputs: [_ret(LuminaPinType.boolean)],
  ),
  LuminaBlueprintNodeSpec(
    id: 'reset_cloth',
    title: 'Reset Cloth',
    category: 'Physics|Cloth',
    kind: LuminaBlueprintNodeKind.impure,
    headerColor: _function,
    keywords: const ['cloth', 'reset', 'rest', 'teleport', 'physics'],
    inputs: const [_execIn],
    outputs: const [_execOut],
  ),
  LuminaBlueprintNodeSpec(
    id: 'pin_cloth_vertex',
    title: 'Pin Cloth Vertex',
    category: 'Physics|Cloth',
    kind: LuminaBlueprintNodeKind.impure,
    headerColor: _function,
    keywords: const ['cloth', 'pin', 'attach', 'unpin', 'release', 'vertex', 'physics'],
    inputs: const [
      _execIn,
      LuminaBlueprintPinSpec('vertex', 'Vertex', LuminaPinType.integer),
      LuminaBlueprintPinSpec('pinned', 'Pinned', LuminaPinType.boolean, defaultValue: true),
    ],
    outputs: const [_execOut],
  ),
];

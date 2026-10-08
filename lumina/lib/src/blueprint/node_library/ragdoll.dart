part of '../node_library.dart';

/// Built-in nodes: the owner's ragdoll (`LuminaRagdollComponent`).
final List<LuminaBlueprintNodeSpec> _ragdollNodes = <LuminaBlueprintNodeSpec>[
  LuminaBlueprintNodeSpec(
    id: 'start_ragdoll',
    title: 'Start Ragdoll',
    category: 'Physics|Ragdoll',
    kind: LuminaBlueprintNodeKind.impure,
    headerColor: _function,
    keywords: const ['ragdoll', 'physics', 'limp', 'fall', 'knock', 'down', 'simulate'],
    inputs: const [_execIn],
    outputs: [_execOut, _ret(LuminaPinType.boolean, name: 'Started')],
  ),
  LuminaBlueprintNodeSpec(
    id: 'stop_ragdoll',
    title: 'Stop Ragdoll',
    category: 'Physics|Ragdoll',
    kind: LuminaBlueprintNodeKind.impure,
    headerColor: _function,
    keywords: const ['ragdoll', 'get up', 'getup', 'stand', 'recover', 'physics'],
    inputs: const [_execIn, LuminaBlueprintPinSpec('get_up', 'Get Up', LuminaPinType.boolean, defaultValue: true)],
    outputs: const [_execOut],
  ),
  LuminaBlueprintNodeSpec(
    id: 'toggle_ragdoll',
    title: 'Toggle Ragdoll',
    category: 'Physics|Ragdoll',
    kind: LuminaBlueprintNodeKind.impure,
    headerColor: _function,
    keywords: const ['ragdoll', 'toggle', 'physics', 'limp', 'get up'],
    inputs: const [_execIn],
    outputs: const [_execOut],
  ),
  LuminaBlueprintNodeSpec(
    id: 'is_ragdoll',
    title: 'Is Ragdoll',
    category: 'Physics|Ragdoll',
    kind: LuminaBlueprintNodeKind.pure,
    headerColor: _pure,
    keywords: const ['ragdoll', 'physics', 'limp', 'simulating'],
    outputs: [_ret(LuminaPinType.boolean)],
  ),
  LuminaBlueprintNodeSpec(
    id: 'add_ragdoll_impulse',
    title: 'Add Ragdoll Impulse',
    category: 'Physics|Ragdoll',
    kind: LuminaBlueprintNodeKind.impure,
    headerColor: _function,
    keywords: const ['ragdoll', 'impulse', 'hit', 'push', 'knock', 'shot', 'physics'],
    inputs: const [
      _execIn,
      LuminaBlueprintPinSpec('impulse', 'Impulse', LuminaPinType.vector),
      LuminaBlueprintNodeLibrary._bone,
    ],
    outputs: const [_execOut],
  ),
];

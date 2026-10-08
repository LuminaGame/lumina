part of '../node_library.dart';

/// Built-in nodes: traversal (hurdle, vault, mantle) through the owner's
/// `LuminaTraversalComponent`.
final List<LuminaBlueprintNodeSpec> _traversalNodes = <LuminaBlueprintNodeSpec>[
  LuminaBlueprintNodeSpec(
    id: 'try_traversal_action',
    title: 'Try Traversal Action',
    category: 'Character|Traversal',
    kind: LuminaBlueprintNodeKind.impure,
    headerColor: _function,
    keywords: const ['traversal', 'vault', 'hurdle', 'mantle', 'climb', 'jump', 'parkour', 'ledge'],
    inputs: const [_execIn],
    outputs: [_execOut, _ret(LuminaPinType.boolean, name: 'Success')],
  ),
  LuminaBlueprintNodeSpec(
    id: 'traversal_check',
    title: 'Traversal Check',
    category: 'Character|Traversal',
    kind: LuminaBlueprintNodeKind.impure,
    headerColor: _function,
    keywords: const ['traversal', 'obstacle', 'ledge', 'height', 'depth', 'trace'],
    inputs: const [_execIn],
    outputs: const [
      _execOut,
      LuminaBlueprintPinSpec('action_type', 'Action Type', LuminaPinType.string),
      LuminaBlueprintPinSpec('obstacle_height', 'Obstacle Height', LuminaPinType.float),
      LuminaBlueprintPinSpec('obstacle_depth', 'Obstacle Depth', LuminaPinType.float),
      LuminaBlueprintPinSpec('back_ledge_height', 'Back Ledge Height', LuminaPinType.float),
      LuminaBlueprintPinSpec('has_front_ledge', 'Has Front Ledge', LuminaPinType.boolean),
    ],
  ),
  LuminaBlueprintNodeSpec(
    id: 'is_traversing',
    title: 'Is Traversing',
    category: 'Character|Traversal',
    kind: LuminaBlueprintNodeKind.pure,
    headerColor: _pure,
    keywords: const ['traversal', 'vault', 'hurdle', 'mantle', 'playing'],
    outputs: [_ret(LuminaPinType.boolean)],
  ),
];

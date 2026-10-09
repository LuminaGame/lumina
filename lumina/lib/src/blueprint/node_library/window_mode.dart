part of '../node_library.dart';

/// Built-in nodes: the game window's mode (`LuminaGameWindow`): windowed or
/// borderless fullscreen, kept as the player's choice.
final List<LuminaBlueprintNodeSpec> _windowModeNodes = <LuminaBlueprintNodeSpec>[
  LuminaBlueprintNodeSpec(
    id: 'set_fullscreen_mode',
    title: 'Set Fullscreen Mode',
    category: 'Settings|Display',
    kind: LuminaBlueprintNodeKind.impure,
    headerColor: _function,
    keywords: const ['fullscreen', 'full screen', 'borderless', 'windowed', 'window mode', 'display', 'screen'],
    inputs: [_execIn, _s('mode', 'Mode', 'Borderless Fullscreen')],
    outputs: const [_execOut],
  ),
  LuminaBlueprintNodeSpec(
    id: 'get_fullscreen_mode',
    title: 'Get Fullscreen Mode',
    category: 'Settings|Display',
    kind: LuminaBlueprintNodeKind.pure,
    headerColor: _pure,
    keywords: const ['fullscreen', 'full screen', 'borderless', 'windowed', 'window mode', 'display'],
    outputs: [_ret(LuminaPinType.string)],
  ),
  LuminaBlueprintNodeSpec(
    id: 'toggle_fullscreen',
    title: 'Toggle Fullscreen',
    category: 'Settings|Display',
    kind: LuminaBlueprintNodeKind.impure,
    headerColor: _function,
    keywords: const ['fullscreen', 'full screen', 'toggle', 'alt enter', 'f11', 'windowed', 'display'],
    inputs: const [_execIn],
    outputs: const [_execOut],
  ),
];

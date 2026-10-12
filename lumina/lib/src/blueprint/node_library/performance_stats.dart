part of '../node_library.dart';

/// Built-in nodes for a stats overlay and a menu that restores what it
/// found: the GPU memory the game uses (`VK_EXT_memory_budget`), the
/// resolution the GPU renders at before the upscale, and the player
/// controller's cursor and input mode.
final List<LuminaBlueprintNodeSpec> _performanceStatsNodes = <LuminaBlueprintNodeSpec>[
  LuminaBlueprintNodeSpec(
    id: 'get_gpu_memory_usage',
    title: 'Get GPU Memory Usage',
    category: 'Lumina|Engine',
    kind: LuminaBlueprintNodeKind.pure,
    headerColor: _pure,
    keywords: const ['vram', 'gpu', 'memory', 'video memory', 'budget', 'usage', 'performance', 'stat'],
    tooltip: "The device-local GPU memory this game uses and the budget the driver grants it, in MB "
        "(VK_EXT_memory_budget). Available is false on OpenGL, on the web and where the GPU does not report it.",
    outputs: [_f('used_mb', 'Used MB'), _f('budget_mb', 'Budget MB'), _b('available', 'Available')],
  ),
  LuminaBlueprintNodeSpec(
    id: 'get_render_resolution',
    title: 'Get Render Resolution',
    category: 'Settings|Display',
    kind: LuminaBlueprintNodeKind.pure,
    headerColor: _pure,
    keywords: const ['render resolution', 'internal resolution', 'upscaler', 'resolution scale', 'dynamic resolution',
      'performance', 'stat', 'display'],
    tooltip: 'The resolution the GPU renders the scene at in physical pixels: the screen resolution scaled by the '
        'upscaler and the resolution scale of the last frame.',
    outputs: [_i('width', 'Width'), _i('height', 'Height')],
  ),
  const LuminaBlueprintNodeSpec(
    id: 'get_show_mouse_cursor',
    title: 'Get Show Mouse Cursor',
    category: 'Input|Mouse Interaction',
    kind: LuminaBlueprintNodeKind.pure,
    headerColor: _pure,
    keywords: ['mouse', 'cursor', 'show', 'visible', 'pointer', 'ui'],
    tooltip: "Whether the player controller shows the mouse cursor (Target like Set Show Mouse Cursor; false without "
        "a player controller).",
    inputs: [LuminaBlueprintPinSpec('target', 'Target', LuminaPinType.object)],
    outputs: [LuminaBlueprintPinSpec(_returnValue, 'Return Value', LuminaPinType.boolean)],
  ),
  const LuminaBlueprintNodeSpec(
    id: 'get_input_mode',
    title: 'Get Input Mode',
    category: 'Input',
    kind: LuminaBlueprintNodeKind.pure,
    headerColor: _pure,
    keywords: ['input', 'mode', 'ui', 'game', 'focus', 'mouse', 'cursor'],
    tooltip: 'The player controller\'s input mode: GameOnly, GameAndUI or UIOnly (Target like Set Input Mode; '
        'GameOnly without a player controller).',
    inputs: [LuminaBlueprintPinSpec('target', 'Target', LuminaPinType.object)],
    outputs: [LuminaBlueprintPinSpec(_returnValue, 'Return Value', LuminaPinType.string)],
  ),
];

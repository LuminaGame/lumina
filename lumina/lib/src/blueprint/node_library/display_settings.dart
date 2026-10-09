part of '../node_library.dart';

const List<String> _displayKeywords = ['resolution', 'screen', 'display', 'monitor', 'settings', 'graphics'];

LuminaBlueprintNodeSpec _displayPure(String id, String title, List<LuminaBlueprintPinSpec> outputs, List<String> keywords,
        {List<LuminaBlueprintPinSpec> inputs = const []}) =>
    LuminaBlueprintNodeSpec(
      id: id,
      title: title,
      category: 'Settings|Display',
      kind: LuminaBlueprintNodeKind.pure,
      headerColor: _pure,
      keywords: [..._displayKeywords, ...keywords],
      inputs: inputs,
      outputs: outputs,
    );

/// Built-in nodes: the screen resolution, the desktop resolution, the
/// resolutions and refresh rates the monitor offers, the monitors
/// (`LuminaGameDisplay`), and the staged Set Screen Resolution / Set
/// Fullscreen Monitor that Apply Scalability Settings applies.
final List<LuminaBlueprintNodeSpec> _displaySettingsNodes = <LuminaBlueprintNodeSpec>[
  _displayPure(
    'get_screen_resolution',
    'Get Screen Resolution',
    [_i('width', 'Width'), _i('height', 'Height')],
    ['render resolution', 'window size', 'fullscreen', 'current resolution', 'pixels'],
  ),
  _displayPure(
    'get_desktop_resolution',
    'Get Desktop Resolution',
    [_i('width', 'Width'), _i('height', 'Height'), _i('refresh_rate', 'Refresh Rate')],
    ['desktop', 'native resolution', 'refresh rate', 'hz', 'fullscreen'],
  ),
  _displayPure(
    'get_supported_resolutions',
    'Get Supported Resolutions',
    [const LuminaBlueprintPinSpec(_returnValue, 'Return Value', LuminaPinType.array, elementType: LuminaPinType.vector2D)],
    ['supported', 'list', 'modes', 'display modes', 'options', 'menu', 'fullscreen'],
  ),
  _displayPure(
    'get_supported_refresh_rates',
    'Get Supported Refresh Rates',
    [const LuminaBlueprintPinSpec(_returnValue, 'Return Value', LuminaPinType.array, elementType: LuminaPinType.integer)],
    ['refresh rate', 'hz', 'frequency', 'supported', 'list', 'modes'],
    inputs: [_i('width', 'Width', 1920), _i('height', 'Height', 1080)],
  ),
  _displayPure('get_monitor_count', 'Get Monitor Count', [_ret(LuminaPinType.integer)],
      ['monitors', 'displays', 'count', 'multi monitor']),
  _displayPure(
    'get_current_monitor',
    'Get Current Monitor',
    [_i('index', 'Index'), _s('name', 'Name')],
    ['current monitor', 'monitor name', 'display name', 'fullscreen'],
  ),
  LuminaBlueprintNodeSpec(
    id: 'set_screen_resolution',
    title: 'Set Screen Resolution',
    category: 'Settings|Display',
    kind: LuminaBlueprintNodeKind.impure,
    headerColor: _function,
    keywords: const [..._displayKeywords, 'set resolution', 'window size', 'fullscreen', 'windowed', 'apply'],
    inputs: [_execIn, _i('width', 'Width', 1920), _i('height', 'Height', 1080)],
    outputs: const [_execOut],
  ),
  LuminaBlueprintNodeSpec(
    id: 'set_fullscreen_monitor',
    title: 'Set Fullscreen Monitor',
    category: 'Settings|Display',
    kind: LuminaBlueprintNodeKind.impure,
    headerColor: _function,
    keywords: const [..._displayKeywords, 'fullscreen', 'move window', 'multi monitor', 'second monitor'],
    inputs: [_execIn, _i('index', 'Index')],
    outputs: const [_execOut],
  ),
];

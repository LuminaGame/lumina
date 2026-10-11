part of '../node_library.dart';

// --- Editor panels: the editor's events ------------------------------------

/// The events the editor raises in an editor panel's graph: the level
/// selection or the level changed, the Content Browser selection changed,
/// and the owning plugin's process sent an event or changed state. Editor
/// only; the panel host dispatches them.
abstract final class LuminaEditorEventNodes {
  static const String selectionChanged = 'event_editor_selection_changed';
  static const String levelChanged = 'event_editor_level_changed';
  static const String contentBrowserSelectionChanged = 'event_content_browser_selection_changed';
  static const String pluginProcessEvent = 'event_plugin_process_event';
  static const String pluginProcessStateChanged = 'event_plugin_process_state_changed';

  /// The editor events.
  static const Set<String> ids = {
    selectionChanged,
    levelChanged,
    contentBrowserSelectionChanged,
    pluginProcessEvent,
    pluginProcessStateChanged,
  };
}

final List<LuminaBlueprintNodeSpec> _editorEventNodes = [
  const LuminaBlueprintNodeSpec(
    id: LuminaEditorEventNodes.selectionChanged,
    title: 'On Editor Selection Changed',
    category: 'Editor|Selection',
    kind: LuminaBlueprintNodeKind.event,
    headerColor: _event,
    keywords: ['editor', 'selection', 'selected', 'actors', 'changed'],
    outputs: [_execOut, LuminaBlueprintPinSpec('selected_ids', 'Selected Ids', LuminaPinType.array, elementType: LuminaPinType.string)],
    editorOnly: true,
  ),
  const LuminaBlueprintNodeSpec(
    id: LuminaEditorEventNodes.levelChanged,
    title: 'On Level Changed',
    category: 'Editor|Level',
    kind: LuminaBlueprintNodeKind.event,
    headerColor: _event,
    keywords: ['editor', 'level', 'actors', 'changed', 'edited'],
    outputs: [_execOut],
    editorOnly: true,
  ),
  const LuminaBlueprintNodeSpec(
    id: LuminaEditorEventNodes.contentBrowserSelectionChanged,
    title: 'On Content Browser Selection Changed',
    category: 'Editor|Assets',
    kind: LuminaBlueprintNodeKind.event,
    headerColor: _event,
    keywords: ['editor', 'content browser', 'assets', 'selection', 'changed'],
    outputs: [_execOut, LuminaBlueprintPinSpec('asset_paths', 'Asset Paths', LuminaPinType.array, elementType: LuminaPinType.string)],
    editorOnly: true,
  ),
  const LuminaBlueprintNodeSpec(
    id: LuminaEditorEventNodes.pluginProcessEvent,
    title: 'On Plugin Process Event',
    category: 'Editor|Plugin Process',
    kind: LuminaBlueprintNodeKind.event,
    headerColor: _event,
    keywords: ['plugin', 'process', 'event', 'emit', 'message'],
    outputs: [
      _execOut,
      LuminaBlueprintPinSpec('name', 'Name', LuminaPinType.string, defaultValue: ''),
      LuminaBlueprintPinSpec('data', 'Data', LuminaPinType.json),
    ],
    tooltip: "An event the panel's plugin process emitted; the node's Name setting filters (empty: every event).",
    editorOnly: true,
    editorCapability: 'process',
  ),
  const LuminaBlueprintNodeSpec(
    id: LuminaEditorEventNodes.pluginProcessStateChanged,
    title: 'On Plugin Process State Changed',
    category: 'Editor|Plugin Process',
    kind: LuminaBlueprintNodeKind.event,
    headerColor: _event,
    keywords: ['plugin', 'process', 'state', 'running', 'stopped', 'crashed', 'restarting'],
    outputs: [_execOut, LuminaBlueprintPinSpec('state', 'State', LuminaPinType.string, defaultValue: '')],
    tooltip: 'running, stopped, crashed or restarting.',
    editorOnly: true,
    editorCapability: 'process',
  ),
];

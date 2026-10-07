import 'package:lumina_ui/ui/features/main_editor/services/editor_preferences.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_protocol.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_tool.dart';

/// Editor Preferences (Edit → Editor Preferences) as MCP tools
/// (group `settings`): the user's own editor settings in
/// `editor_preferences.json`, saved at once as the page does. An open
/// Editor Preferences tab follows through the preferences' listener.
void registerEditorPreferencesTools(McpToolRegistry registry, EditorViewModel vm) {
  const settings = {McpToolGroups.settings};
  final flights = [for (final t in FlightCameraControlType.values) t.name];

  Map<String, Object?> read() {
    final p = vm.editorPreferences;
    return {
      'flight_camera_control': p.flightCameraControl.name,
      'flight_camera_control_label': p.flightCameraControl.label,
      'flight_camera_control_accepted': flights,
      'import_workers': p.importWorkers,
      'import_workers_range': [1, EditorPreferences.maxImportWorkers],
      'marketplace_url': p.marketplaceUrl,
      'file': p.file.path,
    };
  }

  registry.registerAll([
    McpTool(
      name: 'get_editor_preferences',
      risk: McpToolRisk.readOnly,
      groups: settings,
      title: 'Get Editor Preferences',
      description: 'The editor\'s per-user preferences: flight_camera_control (when W/A/S/D fly the level viewport: '
          'rmbHeld | always | never), import_workers (1..4 parallel import isolates), marketplace_url (read-only here), and '
          'the file they live in.',
      inputSchema: McpSchema.object(const {}),
      handler: (args) => McpToolResult.json(read()),
    ),
    McpTool(
      name: 'set_editor_preferences',
      risk: McpToolRisk.mutating,
      groups: settings,
      idempotent: true,
      title: 'Set Editor Preferences',
      description: 'Sets flight_camera_control (rmbHeld | always | never) and / or import_workers (1..4); saved to '
          'editor_preferences.json at once. marketplace_url is not settable by an agent: it decides where installs '
          'download from, so only the user changes it (Edit → Editor Preferences).',
      inputSchema: {
        'type': 'object',
        'properties': {
          'flight_camera_control': McpSchema.string('When W/A/S/D/Q/E fly the viewport camera.', enumValues: flights),
          'import_workers': McpSchema.integer('Parallel import workers, 1..${EditorPreferences.maxImportWorkers}.'),
          'marketplace_url': McpSchema.string('Refused: the user sets it.'),
        },
      },
      handler: (args) {
        if (args.has('marketplace_url')) {
          return McpToolResult.error('marketplace_url is read-only for agents: it decides where marketplace installs are '
              'downloaded from, and an agent silently repointing it would be a supply-chain lever. Ask the user to change it '
              'in Edit → Editor Preferences.');
        }
        for (final key in args.raw.keys) {
          if (key != 'flight_camera_control' && key != 'import_workers') {
            throw JsonRpcException(JsonRpcErrorCode.invalidParams,
                'set_editor_preferences has no "$key"; it sets flight_camera_control and import_workers.');
          }
        }
        if (!args.has('flight_camera_control') && !args.has('import_workers')) {
          throw const JsonRpcException(JsonRpcErrorCode.invalidParams, 'Pass flight_camera_control and / or import_workers.');
        }
        final workers = args.has('import_workers') ? args.integer('import_workers') : null;
        if (workers != null && (workers < 1 || workers > EditorPreferences.maxImportWorkers)) {
          throw JsonRpcException(JsonRpcErrorCode.invalidParams,
              'import_workers must be in the range 1..${EditorPreferences.maxImportWorkers} (got $workers)');
        }
        final prefs = vm.editorPreferences;
        final flight = args.optionalString('flight_camera_control');
        if (flight != null) prefs.setFlightCameraControl(FlightCameraControlType.parse(flight));
        if (workers != null) prefs.setImportWorkers(workers);
        return McpToolResult.json(read());
      },
    ),
  ]);
}

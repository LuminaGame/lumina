import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lumina/data/services/config_json_file.dart';
import 'package:lumina/data/services/lumina_config_dir.dart';

import 'mcp_tool_risk.dart';

/// Whether the editor offers its MCP server to AI agents, and on which port,
/// per user in `mcp_server_settings.json` of the editor's config directory
/// ([LuminaConfigDir]; a temp directory in every test). Saved on change.
///
/// Enabled by default: the server binds loopback
/// only and its token lives in a 0600 file, so nothing outside this user's
/// own processes can reach it.
class McpServerSettings extends ChangeNotifier {
  McpServerSettings._(this.file, this._enabled, this._port, this._maxRisk);

  static const String fileName = 'mcp_server_settings.json';

  /// The port the server tries first, so a registered
  /// `claude mcp add --transport http` URL survives editor restarts.
  static const int defaultPort = 7741;

  factory McpServerSettings.load({Directory? configDir}) {
    final file = File('${LuminaConfigDir.resolve(explicit: configDir).path}/$fileName');
    var enabled = true;
    var port = defaultPort;
    var maxRisk = McpToolRisk.external;
    try {
      final decoded = ConfigJsonFile(file).read();
      if (decoded is Map) {
        if (decoded['enabled'] is bool) enabled = decoded['enabled'] as bool;
        if (decoded['port'] is int) port = decoded['port'] as int;
        maxRisk = McpToolRisk.parse(decoded['max_risk']) ?? maxRisk;
      }
    } catch (e) {
      debugPrint('[McpServerSettings] ${file.path} is unreadable, using the defaults: $e');
    }
    return McpServerSettings._(file, enabled, port, maxRisk);
  }

  final File file;
  bool _enabled;
  int _port;

  bool get enabled => _enabled;
  int get port => _port;

  /// "External agents may run": tools above this risk are
  /// not listed and their calls are denied. Default: everything.
  McpToolRisk get maxRisk => _maxRisk;
  McpToolRisk _maxRisk;

  void setMaxRisk(McpToolRisk value) {
    if (value == _maxRisk) return;
    _maxRisk = value;
    _save();
    notifyListeners();
  }

  void setEnabled(bool value) {
    if (value == _enabled) return;
    _enabled = value;
    _save();
    notifyListeners();
  }

  void setPort(int value) {
    if (value == _port) return;
    _port = value;
    _save();
    notifyListeners();
  }

  void _save() {
    try {
      ConfigJsonFile(file).update(
        (current) => {
          ...?(current is Map<String, dynamic> ? current : null),
          'enabled': _enabled,
          'port': _port,
          'max_risk': _maxRisk.name,
        },
        isValid: (value) => value is Map<String, dynamic>,
        pretty: true,
        onUnreadable: (keptAside, error) =>
            debugPrint('[McpServerSettings] ${file.path} was unreadable ($error); kept it as ${keptAside.path}'),
      );
    } catch (e) {
      debugPrint('[McpServerSettings] could not save ${file.path}: $e');
    }
  }
}

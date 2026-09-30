// A stdio ↔ Streamable HTTP bridge for Lumina Studio's MCP server.
//
// Some MCP clients only launch stdio servers. This script is such a server:
// it reads the running editor's connection file (`mcp_server.json` in the
// editor's config directory: `$LUMINA_CONFIG_DIR`, else `~/.config/lumina`),
// and forwards every JSON-RPC message it reads on stdin to the editor over
// HTTP with the bearer token, writing each response as one line on stdout.
//
// Register it with `claude mcp add lumina -- dart <this file>`; it imports
// nothing but `dart:io`, so `dart` runs it from any directory.
// `--groups level,view` lists only those tool groups: the
// bridge connects to `/mcp?groups=level,view`.
// `--caller <tag>` connects to `/mcp?caller=<tag>`: a plugin that started
// the client (MiniAI running Claude Code) binds the tag to its own caller, so
// the calls join its turn.
//
// A missing or dead editor answers every request with a JSON-RPC error
// (-32000) naming the file, so the client shows why instead of hanging.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

const int _serverUnavailable = -32000;

void main(List<String> arguments) async {
  final client = HttpClient();
  final groups = _optionArg(arguments, 'groups');
  final caller = _optionArg(arguments, 'caller');
  String? sessionId;
  final stdoutSink = stdout;

  void emit(Object message) {
    stdoutSink.writeln(jsonEncode(message));
  }

  Map<String, Object?>? readConnection() {
    final file = _connectionFile();
    if (!file.existsSync()) return null;
    try {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is Map && decoded['url'] is String && decoded['token'] is String) {
        return Map<String, Object?>.from(decoded);
      }
    } catch (_) {}
    return null;
  }

  Future<void> forward(String line) async {
    Object? message;
    try {
      message = jsonDecode(line);
    } on FormatException catch (e) {
      emit({
        'jsonrpc': '2.0',
        'id': null,
        'error': {'code': -32700, 'message': 'Parse error: ${e.message}'},
      });
      return;
    }
    final id = message is Map ? message['id'] : null;
    final isNotification = message is Map && message['id'] == null;
    final connection = readConnection();
    if (connection == null) {
      if (!isNotification) {
        emit({
          'jsonrpc': '2.0',
          'id': id,
          'error': {
            'code': _serverUnavailable,
            'message': 'Lumina Studio is not running or its MCP server is off: ${_connectionFile().path} is missing. '
                'Open a project in Lumina Studio and enable Tools → AI Agent Access (MCP).',
          },
        });
      }
      return;
    }
    try {
      var endpoint = Uri.parse(connection['url'] as String);
      if (groups != null || caller != null) {
        endpoint = endpoint.replace(queryParameters: {
          ...endpoint.queryParameters,
          'groups': ?groups,
          'caller': ?caller,
        });
      }
      final request = await client.postUrl(endpoint);
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer ${connection['token']}');
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json, text/event-stream');
      if (sessionId != null) request.headers.set('Mcp-Session-Id', sessionId!);
      request.write(line);
      final response = await request.close();
      final issued = response.headers.value('mcp-session-id');
      if (issued != null) sessionId = issued;
      final body = await utf8.decoder.bind(response).join();
      if (response.statusCode == HttpStatus.accepted) return;
      if (response.statusCode != HttpStatus.ok) {
        if (!isNotification) {
          emit({
            'jsonrpc': '2.0',
            'id': id,
            'error': {
              'code': _serverUnavailable,
              'message': 'Lumina Studio answered HTTP ${response.statusCode}: ${body.trim()}',
            },
          });
        }
        return;
      }
      final decoded = jsonDecode(body);
      if (decoded is List) {
        for (final item in decoded) {
          emit(item as Object);
        }
      } else {
        emit(decoded as Object);
      }
    } on SocketException catch (e) {
      if (!isNotification) {
        emit({
          'jsonrpc': '2.0',
          'id': id,
          'error': {
            'code': _serverUnavailable,
            'message': 'Lumina Studio is not reachable at ${connection['url']} (${e.message}); '
                '${_connectionFile().path} may be stale from a closed editor.',
          },
        });
      }
    }
  }

  // Requests are forwarded in order, one at a time: the editor answers on
  // its main isolate anyway, and ordered replies keep the client simple.
  final lines = stdin.transform(utf8.decoder).transform(const LineSplitter());
  await for (final line in lines) {
    if (line.trim().isEmpty) continue;
    await forward(line);
  }
  client.close();
}

File _connectionFile() {
  final env = Platform.environment;
  final fromEnv = env['LUMINA_CONFIG_DIR'];
  final dir = (fromEnv != null && fromEnv.isNotEmpty)
      ? fromEnv
      : '${env['HOME'] ?? env['USERPROFILE'] ?? '.'}/.config/lumina';
  return File('$dir/mcp_server.json');
}

/// `--<name> value` or `--<name>=value` (`--groups a,b`: the tool groups to
/// list; `--caller tag`: the session's caller tag).
String? _optionArg(List<String> arguments, String name) {
  for (var i = 0; i < arguments.length; i++) {
    final a = arguments[i];
    if (a == '--$name' && i + 1 < arguments.length) return arguments[i + 1];
    if (a.startsWith('--$name=')) return a.substring('--$name='.length);
  }
  return null;
}

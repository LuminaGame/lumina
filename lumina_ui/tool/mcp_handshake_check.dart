// A real connection check for Lumina Studio's MCP server:
// a plain JSON-RPC 2.0 client over Streamable HTTP, nothing shared with the
// editor's code. It reads the running editor's connection file, performs
// `initialize`, `notifications/initialized` and `tools/list`, and prints the
// tool names. Exit code 0 on success, 1 otherwise.
//
//   dart tool/mcp_handshake_check.dart            # $LUMINA_CONFIG_DIR or ~/.config/lumina
//   dart tool/mcp_handshake_check.dart --claude   # also registers it with the `claude` CLI
//                                                 # under a throwaway HOME and lists it there
//
// With `--claude`, the user's real ~/.claude.json is never touched: the CLI
// runs with HOME set to a temp directory that is deleted afterwards.

import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  final env = Platform.environment;
  final configDir = (env['LUMINA_CONFIG_DIR']?.isNotEmpty ?? false)
      ? env['LUMINA_CONFIG_DIR']!
      : '${env['HOME'] ?? '.'}/.config/lumina';
  final file = File('$configDir/mcp_server.json');
  if (!file.existsSync()) {
    stderr.writeln('No ${file.path}: Lumina Studio is not running with its MCP server on '
        '(Tools → AI Agent Access (MCP)).');
    exit(1);
  }
  final info = jsonDecode(file.readAsStringSync()) as Map;
  final url = info['url'] as String;
  final token = info['token'] as String;
  stdout.writeln('Connection file: ${file.path}');
  stdout.writeln('Editor PID ${info['pid']}, project ${info['project']} at ${info['projectDir']}');
  stdout.writeln('URL: $url');

  final http = HttpClient();
  String? session;
  var nextId = 1;

  Future<Map<String, Object?>> rpc(String method, {Map<String, Object?>? params, bool notification = false}) async {
    final request = await http.postUrl(Uri.parse(url));
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.acceptHeader, 'application/json, text/event-stream');
    if (session != null) request.headers.set('Mcp-Session-Id', session!);
    request.write(jsonEncode({
      'jsonrpc': '2.0',
      if (!notification) 'id': nextId++,
      'method': method,
      'params': ?params,
    }));
    final response = await request.close();
    session = response.headers.value('mcp-session-id') ?? session;
    final body = await utf8.decoder.bind(response).join();
    if (notification) {
      if (response.statusCode != HttpStatus.accepted) throw StateError('HTTP ${response.statusCode}: $body');
      return const {};
    }
    if (response.statusCode != HttpStatus.ok) throw StateError('HTTP ${response.statusCode}: $body');
    final decoded = jsonDecode(body) as Map;
    if (decoded['error'] != null) throw StateError('JSON-RPC error: ${decoded['error']}');
    return Map<String, Object?>.from(decoded['result'] as Map);
  }

  try {
    final init = await rpc('initialize', params: {
      'protocolVersion': '2025-06-18',
      'capabilities': {},
      'clientInfo': {'name': 'lumina-mcp-handshake-check', 'version': '1.0'},
    });
    stdout.writeln('initialize: protocol ${init['protocolVersion']}, server ${(init['serverInfo'] as Map)['name']} '
        '${(init['serverInfo'] as Map)['version']}, session $session');
    await rpc('notifications/initialized', notification: true);
    final list = await rpc('tools/list');
    final tools = (list['tools'] as List).cast<Map>();
    stdout.writeln('tools/list: ${tools.length} tools');
    for (final t in tools) {
      stdout.writeln('  - ${t['name']}');
    }
    final info = await rpc('tools/call', params: {'name': 'project_info', 'arguments': {}});
    stdout.writeln('project_info: ${(info['content'] as List).first['text']}');
  } catch (e) {
    stderr.writeln('Handshake failed: $e');
    http.close(force: true);
    exit(1);
  }
  http.close(force: true);

  if (args.contains('--claude')) {
    final claude = Process.runSync('which', ['claude']).stdout.toString().trim();
    if (claude.isEmpty) {
      stdout.writeln('claude CLI not found; skipping the registration check.');
      return;
    }
    final home = Directory.systemTemp.createTempSync('lumina_mcp_claude_home_');
    try {
      final childEnv = {...env, 'HOME': home.path, 'XDG_CONFIG_HOME': '${home.path}/.config'};
      final add = Process.runSync(
        claude,
        ['mcp', 'add', '--transport', 'http', 'lumina', url, '--header', 'Authorization: Bearer $token'],
        environment: childEnv,
        workingDirectory: home.path,
      );
      stdout.writeln('claude mcp add → exit ${add.exitCode}\n${add.stdout}${add.stderr}');
      final list = Process.runSync(claude, ['mcp', 'list'], environment: childEnv, workingDirectory: home.path);
      stdout.writeln('claude mcp list → exit ${list.exitCode}\n${list.stdout}${list.stderr}');
      final get = Process.runSync(claude, ['mcp', 'get', 'lumina'], environment: childEnv, workingDirectory: home.path);
      stdout.writeln('claude mcp get lumina → exit ${get.exitCode}\n${get.stdout}${get.stderr}');
      if (add.exitCode != 0 || list.exitCode != 0) exit(1);
    } finally {
      try {
        home.deleteSync(recursive: true);
      } catch (_) {}
    }
  }
}

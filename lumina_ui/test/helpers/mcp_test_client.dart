import 'dart:convert';
import 'dart:io';

/// A real MCP client for tests: JSON-RPC 2.0 over Streamable HTTP with
/// `dart:io`'s [HttpClient], nothing shared with the server's code.
class McpTestClient {
  McpTestClient(this.url, this.token);

  final String url;
  final String token;
  final HttpClient _http = realHttpClient();
  String? sessionId;
  int _nextId = 1;

  /// The raw HTTP exchange: status, headers and decoded body (null when the
  /// body is empty or not JSON).
  Future<McpHttpReply> post(
    Object body, {
    String? bearer,
    bool omitAuthorization = false,
    bool omitSession = false,
    String method = 'POST',
    String? path,
  }) async {
    final uri = Uri.parse(url);
    final target = path == null ? uri : uri.replace(path: path);
    final request = await _http.openUrl(method, target);
    if (!omitAuthorization) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer ${bearer ?? token}');
    }
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.acceptHeader, 'application/json, text/event-stream');
    if (sessionId != null && !omitSession) request.headers.set('Mcp-Session-Id', sessionId!);
    if (method == 'POST') request.write(body is String ? body : jsonEncode(body));
    final response = await request.close();
    final text = await utf8.decoder.bind(response).join();
    Object? decoded;
    if (text.isNotEmpty) {
      try {
        decoded = jsonDecode(text);
      } on FormatException {
        decoded = null;
      }
    }
    final issued = response.headers.value('mcp-session-id');
    if (issued != null) sessionId = issued;
    return McpHttpReply(response.statusCode, response.headers, text, decoded);
  }

  /// Sends a request and returns its `result`, throwing on a JSON-RPC error.
  Future<Map<String, Object?>> request(String method, [Map<String, Object?>? params]) async {
    final id = _nextId++;
    final reply = await post({
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      'params': ?params,
    });
    if (reply.status != HttpStatus.ok) {
      throw StateError('HTTP ${reply.status} for $method: ${reply.text}');
    }
    final body = reply.json;
    if (body is! Map) throw StateError('No JSON-RPC body for $method: ${reply.text}');
    if (body['error'] != null) {
      final error = body['error'] as Map;
      throw McpRpcError(error['code'] as int, error['message'] as String, error['data']);
    }
    return Map<String, Object?>.from(body['result'] as Map);
  }

  Future<void> notify(String method, [Map<String, Object?>? params]) async {
    final reply = await post({'jsonrpc': '2.0', 'method': method, 'params': ?params});
    if (reply.status != HttpStatus.accepted && reply.status != HttpStatus.ok) {
      throw StateError('HTTP ${reply.status} for notification $method: ${reply.text}');
    }
  }

  /// `initialize` + `notifications/initialized`; returns the initialize result.
  Future<Map<String, Object?>> handshake({String protocolVersion = '2025-06-18', String clientName = 'lumina-ui-test-client'}) async {
    final result = await request('initialize', {
      'protocolVersion': protocolVersion,
      'capabilities': <String, Object?>{},
      'clientInfo': {'name': clientName, 'version': '1.0'},
    });
    await notify('notifications/initialized');
    return result;
  }

  /// `tools/list`; [groups] is `params.groups`.
  Future<List<Map<String, Object?>>> listTools({List<String>? groups}) async {
    final result = await request('tools/list', groups == null ? null : {'groups': groups});
    return (result['tools'] as List).map((t) => Map<String, Object?>.from(t as Map)).toList();
  }

  /// `tools/call`; returns the result object (`content`, `structuredContent`, `isError`).
  Future<McpToolReply> callTool(String name, [Map<String, Object?> arguments = const {}]) async {
    final result = await request('tools/call', {'name': name, 'arguments': arguments});
    return McpToolReply(result);
  }

  void close() => _http.close(force: true);
}

/// A real [HttpClient], even under `flutter_test`: `TestWidgetsFlutterBinding`
/// installs `HttpOverrides.global` with a fake client that answers every
/// request with an empty 400 and never opens a socket, so a plain
/// `HttpClient()` could not reach the editor's loopback server. The base
/// [HttpOverrides] creates the real `dart:io` client.
HttpClient realHttpClient() => HttpOverrides.runWithHttpOverrides(HttpClient.new, _RealHttpOverrides());

class _RealHttpOverrides extends HttpOverrides {}

class McpHttpReply {
  final int status;
  final HttpHeaders headers;
  final String text;
  final Object? json;
  const McpHttpReply(this.status, this.headers, this.text, this.json);
}

class McpRpcError implements Exception {
  final int code;
  final String message;
  final Object? data;
  const McpRpcError(this.code, this.message, this.data);

  @override
  String toString() => 'McpRpcError($code): $message';
}

class McpToolReply {
  final Map<String, Object?> raw;
  const McpToolReply(this.raw);

  bool get isError => raw['isError'] == true;

  List<Map<String, Object?>> get content =>
      (raw['content'] as List).map((c) => Map<String, Object?>.from(c as Map)).toList();

  String get text => content.where((c) => c['type'] == 'text').map((c) => c['text'] as String).join('\n');

  /// The `structuredContent` object, else the text parsed as JSON.
  Map<String, Object?> get data {
    final structured = raw['structuredContent'];
    if (structured is Map) return Map<String, Object?>.from(structured);
    return Map<String, Object?>.from(jsonDecode(text) as Map);
  }
}

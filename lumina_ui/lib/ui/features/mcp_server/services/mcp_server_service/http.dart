part of '../mcp_server_service.dart';

/// The HTTP side: request handling, the server-to-client streams, auth and replies.
extension _McpServerHttp on McpServerService {
  // ---------------------------------------------------------------------------
  // HTTP
  // ---------------------------------------------------------------------------

  Future<void> _handle(HttpRequest request) async {
    _requestCount++;
    final response = request.response;
    try {
      if (request.uri.path != McpServerService.path) {
        await _plain(response, HttpStatus.notFound, 'Not found. The MCP endpoint is ${McpServerService.path}.');
        return;
      }
      if (!_authorized(request)) {
        response.headers.set(HttpHeaders.wwwAuthenticateHeader, 'Bearer realm="lumina-studio"');
        await _plain(response, HttpStatus.unauthorized,
            'Unauthorized: send "Authorization: Bearer <token>" with the token from ${connectionFile.path}.');
        return;
      }
      if (request.method == 'GET') {
        // A session's server-to-client stream (SSE), which
        // carries notifications/tools/list_changed.
        final id = request.headers.value('mcp-session-id');
        if (id == null || !_sessions.containsKey(id)) {
          await _plain(response, HttpStatus.badRequest,
              'GET ${McpServerService.path} opens the notification stream of a session: send the Mcp-Session-Id from initialize.');
          return;
        }
        await _openStream(id, response);
        return;
      }
      if (request.method == 'DELETE') {
        final id = request.headers.value('mcp-session-id');
        _sessions.remove(id);
        // An agent that leaves never leaves a key held.
        if (id != null) playTesting.releaseAll(sessionId: id);
        await _closeStream(id);
        response.statusCode = HttpStatus.ok;
        await response.close();
        _notify();
        return;
      }
      if (request.method != 'POST') {
        await _plain(response, HttpStatus.methodNotAllowed, 'Only POST (and DELETE) are accepted on ${McpServerService.path}.');
        return;
      }
      final body = await utf8.decoder.bind(request).join();
      Object? decoded;
      try {
        decoded = jsonDecode(body);
      } on FormatException catch (e) {
        await _json(response, HttpStatus.ok,
            JsonRpcResponse.error(null, JsonRpcException(JsonRpcErrorCode.parseError, 'Parse error: ${e.message}')));
        return;
      }
      final sessionId = request.headers.value('mcp-session-id');
      if (decoded is List) {
        if (decoded.isEmpty) {
          await _json(response, HttpStatus.ok,
              JsonRpcResponse.error(null, const JsonRpcException(JsonRpcErrorCode.invalidRequest, 'Empty batch')));
          return;
        }
        final results = <Map<String, Object?>>[];
        String? issued;
        for (final item in decoded) {
          final (result, session) = await _dispatchOne(item, sessionId, request.uri);
          issued ??= session;
          if (result != null) results.add(result);
        }
        if (issued != null) response.headers.set('Mcp-Session-Id', issued);
        if (results.isEmpty) {
          response.statusCode = HttpStatus.accepted;
          await response.close();
        } else {
          await _json(response, HttpStatus.ok, results);
        }
        return;
      }
      final (result, issued) = await _dispatchOne(decoded, sessionId, request.uri);
      if (issued != null) response.headers.set('Mcp-Session-Id', issued);
      if (result == null) {
        response.statusCode = HttpStatus.accepted;
        await response.close();
      } else {
        await _json(response, HttpStatus.ok, result);
      }
    } on _HttpFailure catch (e) {
      await _plain(response, e.status, e.message);
    } catch (e, st) {
      _lastError = e.toString();
      viewModel.logger.log('MCP request failed: $e\n$st', level: 'error', source: 'MCP');
      try {
        await _json(response, HttpStatus.ok,
            JsonRpcResponse.error(null, JsonRpcException(JsonRpcErrorCode.internalError, 'Internal error: $e')));
      } catch (_) {}
    } finally {
      _notify();
    }
  }


  Future<void> _openStream(String sessionId, HttpResponse response) async {
    if (!_listChangedHooked) {
      _listChangedHooked = true;
      tools.toolsChanged.addListener(_broadcastListChanged);
    }
    await _closeStream(sessionId);
    response.statusCode = HttpStatus.ok;
    response.headers
      ..contentType = ContentType('text', 'event-stream', charset: 'utf-8')
      ..set(HttpHeaders.cacheControlHeader, 'no-cache');
    response.bufferOutput = false;
    // Unbuffered: every write goes out at once (no flush, which would
    // refuse a notification written meanwhile). Registered before the first
    // byte: a client may act on seeing it.
    _streams[sessionId] = response;
    response.write(': lumina-studio notification stream\n\n');
  }

  Future<void> _closeStream(String? sessionId) async {
    final stream = sessionId == null ? null : _streams.remove(sessionId);
    if (stream == null) return;
    try {
      await stream.close();
    } catch (_) {}
  }

  void _dropStreams() {
    final open = List.of(_streams.values);
    _streams.clear();
    for (final s in open) {
      unawaited(s.close().then((_) {}, onError: (_) {}));
    }
  }

  /// `notifications/tools/list_changed` to every open stream.
  void _broadcastListChanged() {
    const event = 'event: message\ndata: {"jsonrpc":"2.0","method":"notifications/tools/list_changed"}\n\n';
    for (final entry in List.of(_streams.entries)) {
      try {
        entry.value.write(event);
      } catch (_) {
        _streams.remove(entry.key);
      }
    }
  }

  bool _authorized(HttpRequest request) {
    final header = request.headers.value(HttpHeaders.authorizationHeader) ?? '';
    const prefix = 'Bearer ';
    if (!header.startsWith(prefix)) return false;
    return _constantTimeEquals(header.substring(prefix.length).trim(), _token);
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  Future<void> _plain(HttpResponse response, int status, String text) async {
    response.statusCode = status;
    response.headers.contentType = ContentType.text;
    response.write(text);
    await response.close();
  }

  Future<void> _json(HttpResponse response, int status, Object body) async {
    response.statusCode = status;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(body));
    await response.close();
  }
}

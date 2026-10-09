part of '../mcp_server_service.dart';

/// JSON-RPC dispatch: sessions, initialize, tools/call and its records.
extension _McpServerRpc on McpServerService {
  /// Dispatches one message; returns the response (null for a notification)
  /// and a session id when this message issued one.
  Future<(Map<String, Object?>?, String?)> _dispatchOne(Object? item, String? sessionId, Uri uri) async {
    JsonRpcRequest request;
    try {
      request = JsonRpcRequest.fromJson(item);
    } on JsonRpcException catch (e) {
      return (JsonRpcResponse.error(item is Map ? item['id'] : null, e), null);
    }
    String? issued;
    try {
      final Object? result;
      switch (request.method) {
        case 'initialize':
          // ?groups=level,view on the endpoint URL.
          final groups = McpSession.parseGroups(uri.queryParameters['groups']);
          result = _initialize(request.params);
          final tag = uri.queryParameters['caller'];
          issued = _newSession(request.params, groups, (result as Map)['protocolVersion'] as String,
              callerTag: tag == null || tag.isEmpty ? null : tag);
        case 'notifications/initialized':
        case 'notifications/cancelled':
        case 'notifications/roots/list_changed':
          result = null;
        case 'ping':
          _requireSession(sessionId);
          result = const <String, Object?>{};
        case 'tools/list':
          _requireSession(sessionId);
          // params.groups overrides the session's for this call; tools above
          // the risk ceiling are never listed.
          final groups = McpSession.parseGroups(request.params['groups']) ?? _sessions[sessionId]?.groups;
          result = {'tools': tools.list(groups: groups, maxRisk: settings.maxRisk)};
        case 'tools/call':
          _requireSession(sessionId);
          result = await _callTool(request.params, _sessions[sessionId]);
        case 'resources/list':
          _requireSession(sessionId);
          result = {'resources': _resources()};
        case 'resources/read':
          _requireSession(sessionId);
          result = await _readResource(request.params);
        case 'resources/templates/list':
          result = {
            'resourceTemplates': [
              {
                'uriTemplate': '${LuminaGuide.resource}/{topic}',
                'name': 'guide-topic',
                'title': 'Lumina engine guide topic',
                'description': 'One topic of the Lumina engine guide: ${[for (final t in LuminaGuide.topics) t.id].join(', ')}.',
                'mimeType': 'text/markdown',
              },
            ],
          };
        case 'prompts/list':
          result = {'prompts': const <Object>[]};
        default:
          throw JsonRpcException(JsonRpcErrorCode.methodNotFound, 'Method not found: ${request.method}');
      }
      if (request.isNotification) return (null, issued);
      return (JsonRpcResponse.result(request.id, result), issued);
    } on JsonRpcException catch (e) {
      if (request.isNotification) return (null, issued);
      return (JsonRpcResponse.error(request.id, e), issued);
    }
  }

  String _newSession(Map<String, Object?> params, Set<String>? groups, String protocolVersion, {String? callerTag}) {
    final id = McpServerService._mintToken().substring(0, 32);
    final info = params['clientInfo'];
    final client = info is Map && info['name'] is String ? info['name'] as String : 'unknown';
    _sessions[id] = McpSession(
        id: id, started: DateTime.now(), clientName: client, protocolVersion: protocolVersion, groups: groups, callerTag: callerTag);
    return id;
  }

  /// Once `initialize` has issued a session id, every later request must
  /// carry it (spec: 400 without one, 404 for an unknown one).
  void _requireSession(String? sessionId) {
    if (_sessions.isEmpty) return;
    if (sessionId == null || sessionId.isEmpty) {
      throw const _HttpFailure(HttpStatus.badRequest, 'Missing Mcp-Session-Id header; send the one initialize returned.');
    }
    if (!_sessions.containsKey(sessionId)) {
      throw const _HttpFailure(HttpStatus.notFound, 'Unknown Mcp-Session-Id; call initialize again.');
    }
  }

  Map<String, Object?> _initialize(Map<String, Object?> params) => {
        'protocolVersion': McpProtocol.negotiate(params['protocolVersion']),
        'capabilities': {
          // GET /mcp streams notifications/tools/list_changed.
          'tools': {'listChanged': true},
          'resources': {'subscribe': false, 'listChanged': false},
        },
        'serverInfo': {
          'name': McpProtocol.serverName,
          'title': 'Lumina Studio',
          'version': viewModel.engineVersion,
        },
        'instructions': 'Lumina Studio, the editor of the Lumina game engine, running project '
            '"${viewModel.project.projectName}". Units: centimetres, degrees, Z up. '
            'Every edit call is one undo step labelled MCP: … (undo / redo; scope "agent" undoes only yours). '
            'Deleted assets go to .lumina/trash (list_trash, restore_asset). Tools come in groups '
            '(list_tool_groups); connect with /mcp?groups=level,view to list fewer. File tools are confined to the '
            'project; every file change is snapshotted first (fs_history, fs_restore). Read project_info first. '
            'Before working in an area you have not used yet (Blueprints, game mode, input, widgets, materials, lights, '
            'camera, play-testing, …) read its topic with get_lumina_guide (no topic: the overview and the list). '
            'Play-testing: after start_pie (or the start of a pie_sequence) let the game run at least 1.5 s '
            '(pie_play_for with ms >= 1500, or a {"play_ms": 1500} step) before the first screenshot; '
            'earlier frames can still show the editor camera.',
      };

  Future<Map<String, Object?>> _callTool(Map<String, Object?> params, McpSession? session) async {
    final name = params['name'];
    if (name is! String) {
      throw const JsonRpcException(JsonRpcErrorCode.invalidParams, 'tools/call needs a "name"');
    }
    final rawArgs = params['arguments'];
    final arguments = rawArgs is Map ? Map<String, Object?>.from(rawArgs) : <String, Object?>{};
    final started = DateTime.now();
    final watch = Stopwatch()..start();
    final client = session?.clientName ?? 'unknown';
    final risk = tools.byName(name)?.riskOf(arguments);
    // A tagged session bound by a plugin runs as the plugin's caller, in the
    // plugin's zone (its transaction groups the call's edits).
    final binding = tools.externalBinding(session?.callerTag);
    try {
      Future<McpToolResult> run() => tools.call(
            name,
            arguments,
            context: (tool) => McpCallContext(
              sessionId: session?.id ?? 'anonymous',
              clientName: client,
              transport: McpTransport.http,
              tool: name,
              risk: tool.riskOf(arguments),
              groups: tool.groups,
              arguments: arguments,
              caller: binding?.caller,
            ),
          );
      final result = binding == null ? await run() : await binding.zone.run(run);
      _record(McpCallRecord(
        tool: name,
        started: started,
        duration: watch.elapsed,
        ok: !result.isError,
        error: result.isError ? (result.deniedReason ?? result.content.first['text'] as String?) : null,
        risk: risk,
        client: client,
        deniedReason: result.deniedReason,
        detail: _detail(result),
        jobId: _jobId(result),
      ));
      _audit(client, name, risk, arguments, result);
      return result.toJson();
    } on JsonRpcException catch (e) {
      _record(McpCallRecord(
          tool: name, started: started, duration: watch.elapsed, ok: false, error: e.message, risk: risk, client: client));
      rethrow;
    }
  }

  /// A file tool's `path · snapshot <id>`.
  static String? _detail(McpToolResult result) {
    final data = result.structuredContent;
    final snapshot = data?['snapshot_id'];
    final path = data?['path'];
    if (snapshot is! String || path is! String) return null;
    return '$path · snapshot $snapshot';
  }

  /// The `job_id` a job-starting tool returned.
  static String? _jobId(McpToolResult result) {
    final id = result.structuredContent?['job_id'];
    return id is String ? id : null;
  }

  void _record(McpCallRecord record) {
    _recentCalls.insert(0, record);
    if (_recentCalls.length > 20) _recentCalls.removeLast();
  }

  /// The audit trail: one Output Log line per
  /// call of risk `mutating` or higher, and per denial.
  void _audit(String client, String tool, McpToolRisk? risk, Map<String, Object?> args, McpToolResult result) {
    if (result.deniedReason != null) {
      viewModel.logger.log('$client: $tool denied (${risk?.name}): ${result.deniedReason}', level: 'warning', source: 'MCP');
      return;
    }
    if (risk == null || !(risk > McpToolRisk.editorState)) return;
    final target = args['asset'] ?? args['id'] ?? args['path'] ?? args['name'] ?? args['type'] ?? args['trash_id'];
    final data = result.structuredContent;
    final trash = data?['trash_id'];
    final outcome = result.isError ? ' failed' : (trash is String ? ' → trash $trash' : '');
    viewModel.logger.log('$client: $tool${target == null ? '' : ' $target'}$outcome',
        level: result.isError ? 'warning' : 'info', source: 'MCP');
  }
}

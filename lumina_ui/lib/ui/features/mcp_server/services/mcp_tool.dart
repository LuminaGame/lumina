import 'dart:async';

import '../../main_editor/commands/editor_transaction.dart';
import 'mcp_approval_policy.dart';
import 'mcp_protocol.dart';
import 'mcp_tool_risk.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart' show McpArgs, McpTool, McpChangeSignal, McpToolCallEvent;

// Moved to lumina_editor_api, re-exported for the server's importers.
export 'package:lumina_editor_api/lumina_editor_api.dart' show McpArgs, McpTool, McpToolHandler, McpSchema, McpChangeSignal, McpToolCallEvent, EditorMcp;

export 'mcp_approval_policy.dart';
export 'mcp_tool_risk.dart';

/// The tools a server offers, by name; validates a call's arguments against
/// the declared schema before running the handler.
class McpToolRegistry {
  final Map<String, McpTool> _tools = {};

  /// The approval chain every call passes: the first `deny`
  /// wins; empty means allow all.
  final List<McpApprovalPolicy> approvalPolicies = [];

  /// How long a policy may take before the call is denied.
  Duration approvalTimeout = const Duration(minutes: 10);

  final Map<String, ({String caller, Zone zone})> _external = {};

  /// Binds external sessions tagged [tag] to [caller], run in [zone]
  /// (`EditorMcp.attributeExternalCalls`).
  void bindExternal(String tag, String caller, Zone zone) => _external[tag] = (caller: caller, zone: zone);

  /// Ends [tag]'s binding when it still belongs to [caller].
  void unbindExternal(String tag, String caller) {
    if (_external[tag]?.caller == caller) _external.remove(tag);
  }

  /// The caller and zone the sessions tagged [tag] run in now, if any.
  ({String caller, Zone zone})? externalBinding(String? tag) => tag == null ? null : _external[tag];

  /// Refuses a tool with no group, an unknown group, or a `wraps` entry on
  /// [McpExposure.neverExpose].
  void register(McpTool tool) {
    if (tool.groups.isEmpty) throw StateError('MCP tool "${tool.name}" declares no group');
    final unknown = tool.groups.difference(McpToolGroups.known);
    if (unknown.isNotEmpty) {
      throw StateError('MCP tool "${tool.name}" declares unknown group(s) ${unknown.join(', ')}; '
          'known: ${McpToolGroups.known.join(', ')}');
    }
    final forbidden = tool.wraps.intersection(McpExposure.neverExpose);
    if (forbidden.isNotEmpty) {
      throw StateError('MCP tool "${tool.name}" wraps ${forbidden.join(', ')}, which no MCP tool may expose');
    }
    _tools[tool.name] = tool;
    toolsChanged.notify();
  }

  void registerAll(Iterable<McpTool> tools) => tools.forEach(register);

  /// Removes tool [name] (a plugin re-registering).
  void unregister(String name) {
    if (_tools.remove(name) != null) toolsChanged.notify();
  }

  /// Fires when a tool is added or removed.
  final McpChangeSignal toolsChanged = McpChangeSignal();

  final StreamController<McpToolCallEvent> _calls = StreamController.broadcast();

  /// Every [call], from either transport, denied ones included.
  Stream<McpToolCallEvent> get calls => _calls.stream;

  List<McpTool> get tools => List.unmodifiable(_tools.values);

  McpTool? byName(String name) => _tools[name];

  /// The tools in [groups] (all when null; `core` always) at or below
  /// [maxRisk].
  List<McpTool> filtered({Set<String>? groups, McpToolRisk? maxRisk}) => [
        for (final t in _tools.values)
          if ((groups == null || t.groups.contains(McpToolGroups.core) || t.groups.intersection(groups).isNotEmpty) &&
              (maxRisk == null || t.risk <= maxRisk))
            t,
      ];

  List<Map<String, Object?>> list({Set<String>? groups, McpToolRisk? maxRisk}) =>
      [for (final t in filtered(groups: groups, maxRisk: maxRisk)) t.toJson()];

  /// Runs [name] with [arguments]: validates them, passes [context] through
  /// the approval chain, then runs the handler as one attributed call (every
  /// undo step it records is one `MCP: …` step per stack). A handler that
  /// throws a [JsonRpcException] surfaces it as a protocol error (bad
  /// arguments); any other exception becomes a tool error result with its
  /// message, never a transport failure. A denied call is a tool error whose
  /// text is `{"status": "denied", "tool", "risk", "reason"}`.
  Future<McpToolResult> call(
    String name,
    Map<String, Object?> arguments, {
    required McpCallContext Function(McpTool tool) context,
  }) async {
    final tool = _tools[name];
    if (tool == null) {
      throw JsonRpcException(
        JsonRpcErrorCode.invalidParams,
        'Unknown tool "$name". Call tools/list for the available tools.',
      );
    }
    _validate(tool, arguments);
    final call = context(tool);
    final sw = Stopwatch()..start();
    void report(McpToolResult result, {bool denied = false}) {
      if (_calls.hasListener) {
        _calls.add(McpToolCallEvent(
          tool: name,
          caller: call.clientName,
          transport: call.transport,
          elapsed: sw.elapsed,
          isError: result.isError,
          denied: denied,
        ));
      }
    }

    final denial = await _review(call);
    if (denial != null) {
      final result = McpToolResult.denied(tool: name, risk: call.risk.name, reason: denial);
      report(result, denied: true);
      return result;
    }
    final origin = TransactionOrigin.mcp(sessionId: call.sessionId, clientName: call.clientName, tool: name, caller: call.caller);
    McpToolResult result;
    try {
      result = await TransactionManager.runAttributed(origin, () async => await tool.handler(McpArgs(arguments)));
    } on JsonRpcException {
      rethrow;
    } catch (e, st) {
      result = McpToolResult.error('$name failed: $e\n$st');
    }
    report(result);
    return result;
  }

  /// The first denial reason of the chain, or null to allow. A policy that
  /// throws denies with its message; one pending past [approvalTimeout]
  /// denies with "approval timed out".
  Future<String?> _review(McpCallContext call) async {
    for (final policy in approvalPolicies) {
      try {
        final decision = await Future.value(policy.review(call)).timeout(approvalTimeout);
        if (!decision.allowed) return decision.reason ?? 'denied';
      } on TimeoutException {
        return 'approval timed out';
      } catch (e) {
        return '$e';
      }
    }
    return null;
  }

  /// Checks required properties, unknown properties and the primitive types
  /// the schema declares. Nested objects are passed through.
  void _validate(McpTool tool, Map<String, Object?> arguments) {
    final schema = tool.inputSchema;
    final properties = (schema['properties'] as Map?)?.cast<String, Object?>() ?? const {};
    final required = (schema['required'] as List?)?.cast<String>() ?? const [];
    for (final key in required) {
      if (arguments[key] == null) {
        throw JsonRpcException(
          JsonRpcErrorCode.invalidParams,
          'Tool "${tool.name}" requires argument "$key" (${_describe(properties[key])})',
        );
      }
    }
    if (schema['additionalProperties'] == false) {
      for (final key in arguments.keys) {
        if (!properties.containsKey(key)) {
          throw JsonRpcException(
            JsonRpcErrorCode.invalidParams,
            'Tool "${tool.name}" has no argument "$key". Arguments: ${properties.keys.join(', ')}',
          );
        }
      }
    }
    for (final entry in properties.entries) {
      final value = arguments[entry.key];
      if (value == null) continue;
      final spec = entry.value;
      if (spec is! Map) continue;
      final type = spec['type'];
      final ok = switch (type) {
        'string' => value is String,
        'boolean' => value is bool,
        'integer' => value is int || (value is num && value == value.roundToDouble()),
        'number' => value is num,
        'array' => value is List,
        'object' => value is Map,
        _ => true,
      };
      if (!ok) {
        throw JsonRpcException(
          JsonRpcErrorCode.invalidParams,
          'Tool "${tool.name}": argument "${entry.key}" must be ${_describe(spec)}',
        );
      }
      final allowed = spec['enum'];
      if (allowed is List && !allowed.contains(value)) {
        throw JsonRpcException(
          JsonRpcErrorCode.invalidParams,
          'Tool "${tool.name}": argument "${entry.key}" must be one of ${allowed.join(', ')}',
        );
      }
    }
  }

  static String _describe(Object? spec) {
    if (spec is! Map) return 'any value';
    final type = spec['type'];
    final description = spec['description'];
    final base = switch (type) {
      'array' => 'an array',
      'object' => 'an object',
      'integer' => 'an integer',
      'number' => 'a number',
      'boolean' => 'a boolean',
      'string' => 'a string',
      _ => 'a value',
    };
    return description is String ? '$base: $description' : base;
  }
}

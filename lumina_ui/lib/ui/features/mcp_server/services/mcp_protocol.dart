import 'package:lumina_editor_api/lumina_editor_api.dart' show JsonRpcException, JsonRpcErrorCode;

// Moved to lumina_editor_api, re-exported for the server's importers.
export 'package:lumina_editor_api/lumina_editor_api.dart' show JsonRpcErrorCode, JsonRpcException, McpContent, McpToolResult;

/// The JSON-RPC 2.0 and Model Context Protocol shapes the editor's MCP
/// server speaks.
///
/// Only what the editor emits and accepts is modelled: `initialize`,
/// `notifications/initialized`, `ping`, `tools/list`, `tools/call`,
/// `resources/list`, `resources/read`. The wire format follows the MCP
/// specification's Streamable HTTP transport (2025-06-18); the newer
/// 2025-11-25 revision changes nothing in this subset, so it is accepted too.
abstract final class McpProtocol {
  /// Protocol revisions this server implements, newest first.
  static const List<String> supportedVersions = ['2025-11-25', '2025-06-18', '2025-03-26'];

  /// The revision answered when the client names one this server does not
  /// know: the spec says to answer with the newest version the server
  /// supports that the client might accept, and every client at the time of
  /// writing understands 2025-06-18.
  static const String defaultVersion = '2025-06-18';

  static const String serverName = 'lumina-studio';

  /// The revision to answer for a client's `protocolVersion`.
  static String negotiate(Object? requested) {
    if (requested is String && supportedVersions.contains(requested)) return requested;
    return defaultVersion;
  }
}


/// One decoded JSON-RPC request or notification.
class JsonRpcRequest {
  /// Null for a notification.
  final Object? id;
  final String method;
  final Map<String, Object?> params;

  const JsonRpcRequest({required this.id, required this.method, required this.params});

  bool get isNotification => id == null;

  /// Decodes one message object. Throws [JsonRpcException] with
  /// [JsonRpcErrorCode.invalidRequest] for anything that is not a request.
  static JsonRpcRequest fromJson(Object? json) {
    if (json is! Map) {
      throw const JsonRpcException(JsonRpcErrorCode.invalidRequest, 'A JSON-RPC message must be an object');
    }
    if (json['jsonrpc'] != '2.0') {
      throw const JsonRpcException(JsonRpcErrorCode.invalidRequest, 'Missing "jsonrpc": "2.0"');
    }
    final method = json['method'];
    if (method is! String || method.isEmpty) {
      throw const JsonRpcException(JsonRpcErrorCode.invalidRequest, 'Missing "method"');
    }
    final id = json['id'];
    if (id != null && id is! String && id is! num) {
      throw const JsonRpcException(JsonRpcErrorCode.invalidRequest, '"id" must be a string or a number');
    }
    final rawParams = json['params'];
    final params = rawParams is Map ? Map<String, Object?>.from(rawParams) : <String, Object?>{};
    return JsonRpcRequest(id: id, method: method, params: params);
  }
}

/// Builds JSON-RPC response objects.
abstract final class JsonRpcResponse {
  static Map<String, Object?> result(Object? id, Object? result) => {
        'jsonrpc': '2.0',
        'id': id,
        'result': result,
      };

  static Map<String, Object?> error(Object? id, JsonRpcException error) => {
        'jsonrpc': '2.0',
        'id': id,
        'error': error.toJson(),
      };
}


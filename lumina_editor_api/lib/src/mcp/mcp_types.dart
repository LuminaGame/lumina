// The MCP tool types shared by the editor's MCP server and plugins:
// moved from lumina_ui's mcp_server/services, where
// the same files re-export them. Pure Dart: no Flutter import, so the stdio
// bridge and CLI tools can use them too.
import 'dart:async';
import 'dart:convert';

/// What a tool does to the project, ordered from harmless to
/// far-reaching so a ceiling compares with `<=`:
///
/// - [readOnly]: reads; changes nothing.
/// - [editorState]: changes what the user sees, never the project — the
///   selection, the camera, the active or open tabs, Play, the session log.
///   Not on the undo stack, never on disk.
/// - [mutating]: edits the project; one undo step per call.
/// - [destructive]: removes project files (recoverable through the trash).
/// - [external]: reaches outside the project (network, other programs).
enum McpToolRisk {
  readOnly,
  editorState,
  mutating,
  destructive,
  external;

  bool operator <=(McpToolRisk other) => index <= other.index;
  bool operator >(McpToolRisk other) => index > other.index;

  static McpToolRisk? parse(Object? name) => McpToolRisk.values.where((r) => r.name == name).firstOrNull;
}

/// The groups a tool belongs to: a client lists only the groups it needs
/// (`/mcp?groups=level,view`, `tools/list` `params.groups`). Groups size the
/// context; they are not a permission — the approval chain is.
abstract final class McpToolGroups {
  /// Always listed: project info, undo / redo, the group catalogue.
  static const String core = 'core';
  static const String level = 'level';
  static const String asset = 'asset';
  static const String material = 'material';
  static const String blueprint = 'blueprint';
  static const String pie = 'pie';
  static const String view = 'view';
  static const String log = 'log';

  /// Components of level actors and Blueprints, class
  /// defaults, parent class.
  static const String component = 'component';

  /// Every tool a plugin registers.
  static const String plugin = 'plugin';

  /// Project files (list, read, search, write, edit,
  /// delete, snapshots) confined to the project root.
  static const String fs = 'fs';

  /// `dart analyze` diagnostics and code generation.
  static const String code = 'code';

  /// World Outliner folders, attach / detach, solo.
  static const String outliner = 'outliner';

  /// The multi-select Details panel (several actors
  /// edited at once).
  static const String details = 'details';

  /// Project Settings (staged on the tab's working
  /// copy, then applied) and Editor Preferences.
  static const String settings = 'settings';

  /// The Build menu and the Build Manager (Build
  /// All, Cook & Package as long-running jobs).
  static const String build = 'build';

  /// Content Browser organisation (folders, moves,
  /// collections, thumbnails, Import Asset Folder), the Marketplace and the
  /// Derived Data Cache.
  static const String content = 'content';

  /// Source Control (git status, init, commit,
  /// history, revert, identity).
  static const String scm = 'scm';

  /// The UMG designer (widget tree, slots, props,
  /// events, compile to Dart).
  static const String umg = 'umg';

  /// The Material editor's node graph, parameter
  /// values, texture bindings and header settings.
  static const String materialGraph = 'material_graph';

  /// The Animation Blueprint, Blend Space,
  /// Animation and Skeletal Mesh editors.
  static const String animation = 'animation';

  /// The Sequencer (tracks, keys, scrub, movie
  /// render jobs).
  static const String sequencer = 'sequencer';

  /// The Particle editor (emitter stack, preview).
  static const String particle = 'particle';

  /// The Landscape editor (terrain, sculpt strokes,
  /// foliage layers and strokes).
  static const String landscape = 'landscape';

  /// The Static Mesh editor (LODs, collision,
  /// material slots).
  static const String staticMesh = 'static_mesh';

  /// The Texture editor (settings, mip / channel
  /// view, reimport).
  static const String texture = 'texture';

  /// The Physics Asset editor (bodies, constraints,
  /// collision pairs, overlap validation).
  static const String physicsAsset = 'physics_asset';

  /// The Sound editor (settings, attenuation probe).
  static const String audio = 'audio';

  /// The Enumeration and Blueprint Interface editors.
  static const String blueprintTypes = 'blueprint_types';

  /// Umbrella over the six groups above.
  static const String assetEditors = 'asset_editors';

  static const Set<String> known = {
    core, level, asset, material, blueprint, pie, view, log, component, plugin, fs, code, outliner, details, settings, build, //
    content, scm, umg, materialGraph, animation, sequencer, particle, //
    landscape, staticMesh, texture, physicsAsset, audio, blueprintTypes, assetEditors,
  };
}

/// The MCP annotations of a tool, computed in one place from its risk.
///
/// `destructiveHint` follows the MCP spec's "may perform destructive updates"
/// vs "only additive updates": it is true when the tool **removes** content
/// (actors, nodes, wires, assets, files), even when undo brings it back, and
/// false for in-place edits the undo stack reverts. Flagging every undoable
/// property set would train users to ignore the warning.
abstract final class McpToolAnnotations {
  static Map<String, Object?> of({
    required McpToolRisk risk,
    required String? title,
    bool? idempotent,
    bool? openWorld,
    bool removesContent = false,
  }) {
    final readOnly = risk == McpToolRisk.readOnly;
    return {
      'title': ?title,
      'readOnlyHint': readOnly,
      'destructiveHint': switch (risk) {
        McpToolRisk.readOnly || McpToolRisk.editorState => false,
        McpToolRisk.mutating => removesContent,
        McpToolRisk.destructive || McpToolRisk.external => true,
      },
      'idempotentHint': readOnly ? true : (idempotent ?? false),
      'openWorldHint': risk == McpToolRisk.external ? true : (openWorld ?? false),
    };
  }
}

/// Editor entry points no MCP tool may wrap: ending the
/// session the agent runs in, recursive or unrecoverable deletes, and
/// anything that changes the agent's own permissions. A tool that declares
/// one of these in `wraps` fails registration.
abstract final class McpExposure {
  static const Set<String> neverExpose = {
    'editor.restart',
    'file.exitStudio',
    'EditorViewModel.deleteContentFolder',
    'MarketplaceViewModel.uninstall',
    'ProjectTrash.empty',
    'McpServerService.regenerateToken',
    'McpServerService.stop',
    'McpServerSettings.enabled',
    'McpServerSettings.maxRisk',
    'McpServerService.approvalPolicies',
  };
}

/// JSON-RPC 2.0 error codes, plus the MCP-specific one the stdio bridge uses.
abstract final class JsonRpcErrorCode {
  static const int parseError = -32700;
  static const int invalidRequest = -32600;
  static const int methodNotFound = -32601;
  static const int invalidParams = -32602;
  static const int internalError = -32603;

  /// The editor is not reachable (bridge only).
  static const int serverUnavailable = -32000;
}

/// A JSON-RPC error, thrown by the dispatcher and serialised into the
/// response.
class JsonRpcException implements Exception {
  final int code;
  final String message;
  final Object? data;

  const JsonRpcException(this.code, this.message, {this.data});

  Map<String, Object?> toJson() => {
        'code': code,
        'message': message,
        if (data != null) 'data': data,
      };

  @override
  String toString() => 'JsonRpcException($code): $message';
}

/// MCP `tools/call` result content: text or an image.
abstract final class McpContent {
  static Map<String, Object?> text(String text) => {'type': 'text', 'text': text};

  static Map<String, Object?> image(List<int> pngBytes, {String mimeType = 'image/png'}) => {
        'type': 'image',
        'data': base64Encode(pngBytes),
        'mimeType': mimeType,
      };
}

/// An MCP `tools/call` result.
class McpToolResult {
  final List<Map<String, Object?>> content;
  final Map<String, Object?>? structuredContent;
  final bool isError;

  /// Set when the approval chain refused the call.
  final String? deniedReason;

  const McpToolResult(this.content, {this.structuredContent, this.isError = false, this.deniedReason});

  /// A call the approval chain refused: a tool error whose text is
  /// `{"status": "denied", "tool", "risk", "reason"}`.
  factory McpToolResult.denied({required String tool, required String risk, required String reason}) => McpToolResult(
        [McpContent.text(jsonEncode({'status': 'denied', 'tool': tool, 'risk': risk, 'reason': reason}))],
        isError: true,
        deniedReason: reason,
      );

  /// A successful result whose text is [data] pretty-printed as JSON; the
  /// same object is returned as `structuredContent` for clients that read it.
  factory McpToolResult.json(Map<String, Object?> data) => McpToolResult(
        [McpContent.text(const JsonEncoder.withIndent('  ').convert(data))],
        structuredContent: data,
      );

  factory McpToolResult.text(String text) => McpToolResult([McpContent.text(text)]);

  /// A tool error: the call was understood but could not be done; the text
  /// says what to change.
  factory McpToolResult.error(String message) => McpToolResult([McpContent.text(message)], isError: true);

  Map<String, Object?> toJson() => {
        'content': content,
        if (structuredContent != null) 'structuredContent': structuredContent,
        'isError': isError,
      };
}

/// The arguments of one `tools/call`, validated against the tool's schema.
///
/// Typed getters throw a [JsonRpcException] with a message that names the
/// argument, so an agent that passes the wrong type sees exactly what to fix.
class McpArgs {
  final Map<String, Object?> _values;

  const McpArgs(this._values);

  Map<String, Object?> get raw => _values;

  bool has(String key) => _values[key] != null;

  Object? operator [](String key) => _values[key];

  String string(String key, {String? fallback}) {
    final v = _values[key];
    if (v == null) {
      if (fallback != null) return fallback;
      throw JsonRpcException(JsonRpcErrorCode.invalidParams, 'Missing required argument "$key"');
    }
    if (v is! String) throw JsonRpcException(JsonRpcErrorCode.invalidParams, 'Argument "$key" must be a string');
    return v;
  }

  String? optionalString(String key) => has(key) ? string(key) : null;

  bool boolean(String key, {bool fallback = false}) {
    final v = _values[key];
    if (v == null) return fallback;
    if (v is! bool) throw JsonRpcException(JsonRpcErrorCode.invalidParams, 'Argument "$key" must be a boolean');
    return v;
  }

  int integer(String key, {int? fallback}) {
    final v = _values[key];
    if (v == null) {
      if (fallback != null) return fallback;
      throw JsonRpcException(JsonRpcErrorCode.invalidParams, 'Missing required argument "$key"');
    }
    if (v is int) return v;
    if (v is num && v == v.roundToDouble()) return v.toInt();
    throw JsonRpcException(JsonRpcErrorCode.invalidParams, 'Argument "$key" must be an integer');
  }

  double number(String key, {double? fallback}) {
    final v = _values[key];
    if (v == null) {
      if (fallback != null) return fallback;
      throw JsonRpcException(JsonRpcErrorCode.invalidParams, 'Missing required argument "$key"');
    }
    if (v is num) return v.toDouble();
    throw JsonRpcException(JsonRpcErrorCode.invalidParams, 'Argument "$key" must be a number');
  }

  double? optionalNumber(String key) => has(key) ? number(key) : null;

  /// A `[x, y, z]` vector of numbers.
  List<double> vector3(String key) {
    final v = _values[key];
    if (v is! List || v.length != 3 || v.any((e) => e is! num)) {
      throw JsonRpcException(JsonRpcErrorCode.invalidParams, 'Argument "$key" must be an array of three numbers [x, y, z]');
    }
    return [for (final e in v) (e as num).toDouble()];
  }

  List<double>? optionalVector3(String key) => has(key) ? vector3(key) : null;

  List<String> stringList(String key) {
    final v = _values[key];
    if (v is! List || v.any((e) => e is! String)) {
      throw JsonRpcException(JsonRpcErrorCode.invalidParams, 'Argument "$key" must be an array of strings');
    }
    return v.cast<String>();
  }

  Map<String, Object?>? optionalObject(String key) {
    final v = _values[key];
    if (v == null) return null;
    if (v is! Map) throw JsonRpcException(JsonRpcErrorCode.invalidParams, 'Argument "$key" must be an object');
    return Map<String, Object?>.from(v);
  }
}

typedef McpToolHandler = FutureOr<McpToolResult> Function(McpArgs args);

/// One tool the server offers: its `tools/list` entry and its handler.
class McpTool {
  final String name;
  final String? title;
  final String description;

  /// A JSON Schema object (`type: object`, `properties`, `required`).
  final Map<String, Object?> inputSchema;
  final McpToolHandler handler;

  /// What the tool does to the project.
  final McpToolRisk risk;

  /// The [McpToolGroups] it is listed under (at least one).
  final Set<String> groups;

  /// `idempotentHint` for editor-state and mutating tools (read-only tools
  /// are always idempotent).
  final bool? idempotent;

  /// `openWorldHint`: the tool reaches outside the project (e.g. reads any
  /// file on the machine).
  final bool? openWorld;

  /// A mutating tool that removes content (actors, nodes, wires):
  /// `destructiveHint: true` although undo brings it back.
  final bool removesContent;

  /// The editor entry points the handler calls (command ids,
  /// `Class.method`), checked against [McpExposure.neverExpose].
  final Set<String> wraps;

  /// A higher risk for some arguments (e.g.
  /// `open_level` with `if_dirty: "discard"` is destructive although the
  /// tool is mutating). The approval chain reviews the call at the higher of
  /// the two; null, or a lower risk, leaves [risk].
  final McpToolRisk? Function(Map<String, Object?> arguments)? riskForArguments;

  const McpTool({
    required this.name,
    this.title,
    required this.description,
    required this.inputSchema,
    required this.handler,
    required this.risk,
    required this.groups,
    this.idempotent,
    this.openWorld,
    this.removesContent = false,
    this.wraps = const {},
    this.riskForArguments,
  });

  /// The risk one call with [arguments] carries: [risk], raised by
  /// [riskForArguments].
  McpToolRisk riskOf(Map<String, Object?> arguments) {
    final raised = riskForArguments?.call(arguments);
    return raised != null && raised > risk ? raised : risk;
  }

  bool get readOnly => risk == McpToolRisk.readOnly;

  Map<String, Object?> get annotations => McpToolAnnotations.of(
        risk: risk,
        title: title,
        idempotent: idempotent,
        openWorld: openWorld,
        removesContent: removesContent,
      );

  Map<String, Object?> toJson() => {
        'name': name,
        if (title != null) 'title': title,
        'description': description,
        'inputSchema': inputSchema,
        'annotations': annotations,
        '_meta': {
          'lumina/risk': risk.name,
          'lumina/groups': (groups.toList()..sort()),
        },
      };
}

/// Builds the JSON Schema objects tools declare.
abstract final class McpSchema {
  static Map<String, Object?> object(Map<String, Object?> properties, {List<String> required = const []}) => {
        'type': 'object',
        'properties': properties,
        if (required.isNotEmpty) 'required': required,
        'additionalProperties': false,
      };

  static Map<String, Object?> string(String description, {List<String>? enumValues}) => {
        'type': 'string',
        'description': description,
        'enum': ?enumValues,
      };

  static Map<String, Object?> boolean(String description) => {'type': 'boolean', 'description': description};

  static Map<String, Object?> integer(String description) => {'type': 'integer', 'description': description};

  static Map<String, Object?> number(String description) => {'type': 'number', 'description': description};

  static Map<String, Object?> vector3(String description) => {
        'type': 'array',
        'description': description,
        'items': {'type': 'number'},
        'minItems': 3,
        'maxItems': 3,
      };

  static Map<String, Object?> stringArray(String description) => {
        'type': 'array',
        'description': description,
        'items': {'type': 'string'},
      };

  /// Any JSON value.
  static Map<String, Object?> any(String description) => {'description': description};
}


/// How a call reached the server.
enum McpTransport { http, inProcess }

/// One `tools/call` as an approval policy sees it.
class McpCallContext {
  final String sessionId;

  /// `initialize`'s `clientInfo.name` ("claude-code", …), or "unknown".
  final String clientName;
  final McpTransport transport;
  final String tool;
  final McpToolRisk risk;
  final Set<String> groups;
  final Map<String, Object?> arguments;

  /// Who the call is made for: an in-process caller, or the caller an
  /// external client's tagged session is bound to
  /// (`EditorMcp.attributeExternalCalls`); null otherwise.
  final String? caller;

  const McpCallContext({
    required this.sessionId,
    required this.clientName,
    required this.transport,
    required this.tool,
    required this.risk,
    required this.groups,
    required this.arguments,
    this.caller,
  });
}

class McpApprovalDecision {
  final bool allowed;
  final String? reason;

  const McpApprovalDecision.allow()
      : allowed = true,
        reason = null;
  const McpApprovalDecision.deny(String this.reason) : allowed = false;
}

/// Decides whether a `tools/call` may run. The server runs every call through
/// its ordered list of policies; the first `deny` wins.
abstract interface class McpApprovalPolicy {
  FutureOr<McpApprovalDecision> review(McpCallContext call);
}


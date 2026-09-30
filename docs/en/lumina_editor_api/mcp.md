[Türkçe](../../tr/lumina_editor_api/mcp.md)

# MCP tools API

The Model Context Protocol types that the editor's MCP server and plugins share: tools with their schemas, arguments and results, risk levels and groups, approval policies, and `EditorMcp`, through which a plugin calls the same tools external agents use and registers its own. File paths are relative to the `lumina_editor_api/` package directory.

## `lib/src/mcp/editor_mcp.dart`

### `class McpToolCallEvent`

One `tools/call`, however it arrived: for logs and for a plugin that watches what agents do.

**Constructors:**

- `const McpToolCallEvent({required this.tool, required this.caller, required this.transport, required this.elapsed, required this.isError, required this.denied,})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `tool` | `final String tool` |  |
| `caller` | `final String caller` | The in-process caller, or the HTTP client's name. |
| `transport` | `final McpTransport transport` |  |
| `elapsed` | `final Duration elapsed` |  |
| `isError` | `final bool isError` |  |
| `denied` | `final bool denied` | The approval chain refused it. |

### `class McpChangeSignal`

A change notifier without Flutter (the MCP files stay pure Dart).

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `addListener` | `void addListener(void Function() listener)` |  |
| `removeListener` | `void removeListener(void Function() listener)` |  |
| `notify` | `void notify()` |  |

### `class McpClientLaunch`

How an MCP client outside the editor starts a connection to it : the stdio bridge's command line, which reads the running editor's connection file itself, so it carries no token and never goes stale.

**Constructors:**

- `const McpClientLaunch({required this.command, required this.args, this.url, this.environment = const {}})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `command` | `final String command` | An absolute path to the Dart executable (or `dart`). |
| `args` | `final List<String> args` | `[<lumina_ui>/bin/lumina_mcp_bridge.dart]`. |
| `url` | `final String? url` | The HTTP endpoint while the server runs (it changes per session). |
| `environment` | `final Map<String, String> environment` | Variables the bridge needs to find this editor (`LUMINA_CONFIG_DIR` when the editor's config directory is not the default one). A client config that passes them reaches this editor even from a redirected run. |

### `abstract class EditorMcp`

The editor's MCP tools for a plugin, reached through `LuminaEditorContext.mcp`: the same tools, schemas and approval chain external agents get over HTTP, used in process.

**Constructors:**

- `const EditorMcp()`
- `factory EditorMcp.detached({String pluginName})`: A working in-memory implementation for a context with no editor behind it: tools run directly, with no approval chain.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `registerTool` | `void registerTool(McpTool tool)` | Adds [tool] to the editor's MCP server as `<pluginName>.<name>`, in the `plugin` group besides its own. Validated like the host's tools: known groups, nothing on `McpExposure.neverExpose`. |
| `listTools` | `List<McpTool> listTools({Set<String>? groups})` | Every tool (host and plugins) in [groups] (all when null). |
| `callTool` | `Future<McpToolResult> callTool(String name, Map<String, Object?> args, {String? caller})` | Runs tool [name] in process: validated against its schema, through the approval chain, attributed on the undo stack as an MCP call by [caller]. Bad arguments throw a [JsonRpcException]; a failure or a denial is an error result. |
| `calls` | `Stream<McpToolCallEvent> get calls` | Every call, from any transport. |
| `attributeExternalCalls` | `Future<T> attributeExternalCalls<T>(String clientTag, String caller, Future<T> Function() body)` | Runs [body]; while it runs, the tool calls of external MCP clients that connected with the tag [clientTag] (the stdio bridge's `--caller`) are made as [caller] and in the zone this was called from. A surrounding `EditorLevelAccess.runTransaction` therefore groups their level edits, and their file snapshots carry [caller] like an in-process call's. Without an editor behind it, this only runs [body]. |
| `attributesExternalCalls` | `bool get attributesExternalCalls` | Whether [attributeExternalCalls] attributes anything here. |
| `clientLaunch` | `McpClientLaunch? get clientLaunch` | How an external MCP client reaches this editor; null without an editor MCP server. |
| `toolsChanged` | `McpChangeSignal get toolsChanged` | Fires when a tool is added or removed. |

## `lib/src/mcp/mcp_types.dart`

### `enum McpToolRisk`

What a tool does to the project, ordered from harmless to far-reaching so a ceiling compares with `<=`:

- [readOnly]: reads; changes nothing. - [editorState]: changes what the user sees, never the project — the selection, the camera, the active or open tabs, Play, the session log. Not on the undo stack, never on disk. - [mutating]: edits the project; one undo step per call. - [destructive]: removes project files (recoverable through the trash). - [external]: reaches outside the project (network, other programs).

**Values:**

- `readOnly`
- `editorState`
- `mutating`
- `destructive`
- `external`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `operator` | `bool operator <=(McpToolRisk other)` |  |
| `operator` | `bool operator >(McpToolRisk other)` |  |
| `parse` | `static McpToolRisk? parse(Object? name)` |  |

### `abstract final class McpToolGroups`

The groups a tool belongs to: a client lists only the groups it needs (`/mcp?groups=level,view`, `tools/list` `params.groups`). Groups size the context; they are not a permission — the approval chain is.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `core` | `static const String core` | Always listed: project info, undo / redo, the group catalogue. |
| `level` | `static const String level` |  |
| `asset` | `static const String asset` |  |
| `material` | `static const String material` |  |
| `blueprint` | `static const String blueprint` |  |
| `pie` | `static const String pie` |  |
| `view` | `static const String view` |  |
| `log` | `static const String log` |  |
| `component` | `static const String component` | Components of level actors and Blueprints, class defaults, parent class. |
| `plugin` | `static const String plugin` | Every tool a plugin registers. |
| `fs` | `static const String fs` | Project files (list, read, search, write, edit, delete, snapshots) confined to the project root. |
| `code` | `static const String code` | `dart analyze` diagnostics and code generation. |
| `outliner` | `static const String outliner` | World Outliner folders, attach / detach, solo. |
| `details` | `static const String details` | The multi-select Details panel (several actors edited at once). |
| `settings` | `static const String settings` | Project Settings (staged on the tab's working copy, then applied) and Editor Preferences. |
| `build` | `static const String build` | The Build menu and the Build Manager (Build All, Cook & Package as long-running jobs). |
| `content` | `static const String content` | Content Browser organisation (folders, moves, collections, thumbnails, Import Asset Folder), the Marketplace and the Derived Data Cache. |
| `scm` | `static const String scm` | Source Control (git status, init, commit, history, revert, identity). |
| `umg` | `static const String umg` | The UMG designer (widget tree, slots, props, events, compile to Dart). |
| `materialGraph` | `static const String materialGraph` | The Material editor's node graph, parameter values, texture bindings and header settings. |
| `animation` | `static const String animation` | The Animation Blueprint, Blend Space, Animation and Skeletal Mesh editors. |
| `sequencer` | `static const String sequencer` | The Sequencer (tracks, keys, scrub, movie render jobs). |
| `particle` | `static const String particle` | The Particle editor (emitter stack, preview). |
| `landscape` | `static const String landscape` | The Landscape editor (terrain, sculpt strokes, foliage layers and strokes). |
| `staticMesh` | `static const String staticMesh` | The Static Mesh editor (LODs, collision, material slots). |
| `texture` | `static const String texture` | The Texture editor (settings, mip / channel view, reimport). |
| `physicsAsset` | `static const String physicsAsset` | The Physics Asset editor (bodies, constraints, collision pairs, overlap validation). |
| `audio` | `static const String audio` | The Sound editor (settings, attenuation probe). |
| `blueprintTypes` | `static const String blueprintTypes` | The Enumeration and Blueprint Interface editors. |
| `assetEditors` | `static const String assetEditors` | Umbrella over the six groups above. |
| `known` | `static const Set<String> known` |  |

### `abstract final class McpToolAnnotations`

The MCP annotations of a tool, computed in one place from its risk.

`destructiveHint` follows the MCP spec's "may perform destructive updates" vs "only additive updates": it is true when the tool **removes** content (actors, nodes, wires, assets, files), even when undo brings it back, and false for in-place edits the undo stack reverts. Flagging every undoable property set would train users to ignore the warning.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `of` | `static Map<String, Object?> of({required McpToolRisk risk, required String? title, bool? idempotent, bool? ope...` |  |

### `abstract final class McpExposure`

Editor entry points no MCP tool may wrap: ending the session the agent runs in, recursive or unrecoverable deletes, and anything that changes the agent's own permissions. A tool that declares one of these in `wraps` fails registration.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `neverExpose` | `static const Set<String> neverExpose` |  |

### `abstract final class JsonRpcErrorCode`

JSON-RPC 2.0 error codes, plus the MCP-specific one the stdio bridge uses.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `parseError` | `static const int parseError` |  |
| `invalidRequest` | `static const int invalidRequest` |  |
| `methodNotFound` | `static const int methodNotFound` |  |
| `invalidParams` | `static const int invalidParams` |  |
| `internalError` | `static const int internalError` |  |
| `serverUnavailable` | `static const int serverUnavailable` | The editor is not reachable (bridge only). |

### `class JsonRpcException`

A JSON-RPC error, thrown by the dispatcher and serialised into the response.

**Constructors:**

- `const JsonRpcException(this.code, this.message, {this.data})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `code` | `final int code` |  |
| `message` | `final String message` |  |
| `data` | `final Object? data` |  |
| `toJson` | `Map<String, Object?> toJson()` |  |

### `abstract final class McpContent`

MCP `tools/call` result content: text or an image.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `text` | `static Map<String, Object?> text(String text)` |  |
| `image` | `static Map<String, Object?> image(List<int> pngBytes, {String mimeType = 'image/png'})` |  |

### `class McpToolResult`

An MCP `tools/call` result.

**Constructors:**

- `const McpToolResult(this.content, {this.structuredContent, this.isError = false, this.deniedReason})`
- `factory McpToolResult.denied({required String tool, required String risk, required String reason})`: A call the approval chain refused: a tool error whose text is `{"status": "denied", "tool", "risk", "reason"}`.
- `factory McpToolResult.json(Map<String, Object?> data)`: A successful result whose text is [data] pretty-printed as JSON; the same object is returned as `structuredContent` for clients that read it.
- `factory McpToolResult.text(String text)`
- `factory McpToolResult.error(String message)`: A tool error: the call was understood but could not be done; the text says what to change.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `content` | `final List<Map<String, Object?>> content` |  |
| `structuredContent` | `final Map<String, Object?>? structuredContent` |  |
| `isError` | `final bool isError` |  |
| `deniedReason` | `final String? deniedReason` | Set when the approval chain refused the call. |
| `toJson` | `Map<String, Object?> toJson()` |  |

### `class McpArgs`

The arguments of one `tools/call`, validated against the tool's schema.

Typed getters throw a [JsonRpcException] with a message that names the argument, so an agent that passes the wrong type sees exactly what to fix.

**Constructors:**

- `const McpArgs(this._values)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `raw` | `Map<String, Object?> get raw` |  |
| `has` | `bool has(String key)` |  |
| `operator` | `Object? operator [](String key)` |  |
| `string` | `String string(String key, {String? fallback})` |  |
| `optionalString` | `String? optionalString(String key)` |  |
| `boolean` | `bool boolean(String key, {bool fallback = false})` |  |
| `integer` | `int integer(String key, {int? fallback})` |  |
| `number` | `double number(String key, {double? fallback})` |  |
| `optionalNumber` | `double? optionalNumber(String key)` |  |
| `vector3` | `List<double> vector3(String key)` | A `[x, y, z]` vector of numbers. |
| `optionalVector3` | `List<double>? optionalVector3(String key)` |  |
| `stringList` | `List<String> stringList(String key)` |  |
| `optionalObject` | `Map<String, Object?>? optionalObject(String key)` |  |

### `typedef McpToolHandler`

### `class McpTool`

One tool the server offers: its `tools/list` entry and its handler.

**Constructors:**

- `const McpTool({required this.name, this.title, required this.description, required this.inputSchema, required this.handler, required this.risk, required this.gr...`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `name` | `final String name` |  |
| `title` | `final String? title` |  |
| `description` | `final String description` |  |
| `inputSchema` | `final Map<String, Object?> inputSchema` | A JSON Schema object (`type: object`, `properties`, `required`). |
| `handler` | `final McpToolHandler handler` |  |
| `risk` | `final McpToolRisk risk` | What the tool does to the project. |
| `groups` | `final Set<String> groups` | The [McpToolGroups] it is listed under (at least one). |
| `idempotent` | `final bool? idempotent` | `idempotentHint` for editor-state and mutating tools (read-only tools are always idempotent). |
| `openWorld` | `final bool? openWorld` | `openWorldHint`: the tool reaches outside the project (e.g. reads any file on the machine). |
| `removesContent` | `final bool removesContent` | A mutating tool that removes content (actors, nodes, wires): `destructiveHint: true` although undo brings it back. |
| `wraps` | `final Set<String> wraps` | The editor entry points the handler calls (command ids, `Class.method`), checked against [McpExposure.neverExpose]. |
| `riskForArguments` | `final McpToolRisk? Function(Map<String, Object?> arguments)? riskForArguments` | A higher risk for some arguments (e.g. `open_level` with `if_dirty: "discard"` is destructive although the tool is mutating). The approval chain reviews the call at the higher of the two; null, or a lower risk, leaves [risk]. |
| `riskOf` | `McpToolRisk riskOf(Map<String, Object?> arguments)` | The risk one call with [arguments] carries: [risk], raised by [riskForArguments]. |
| `readOnly` | `bool get readOnly` |  |
| `annotations` | `Map<String, Object?> get annotations` |  |
| `toJson` | `Map<String, Object?> toJson()` |  |

### `abstract final class McpSchema`

Builds the JSON Schema objects tools declare.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `object` | `static Map<String, Object?> object(Map<String, Object?> properties, {List<String> required = const []})` |  |
| `string` | `static Map<String, Object?> string(String description, {List<String>? enumValues})` |  |
| `boolean` | `static Map<String, Object?> boolean(String description)` |  |
| `integer` | `static Map<String, Object?> integer(String description)` |  |
| `number` | `static Map<String, Object?> number(String description)` |  |
| `vector3` | `static Map<String, Object?> vector3(String description)` |  |
| `stringArray` | `static Map<String, Object?> stringArray(String description)` |  |
| `any` | `static Map<String, Object?> any(String description)` | Any JSON value. |

### `enum McpTransport`

How a call reached the server.

**Values:**

- `http`
- `inProcess`

### `class McpCallContext`

One `tools/call` as an approval policy sees it.

**Constructors:**

- `const McpCallContext({required this.sessionId, required this.clientName, required this.transport, required this.tool, required this.risk, required this.groups,...`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `sessionId` | `final String sessionId` |  |
| `clientName` | `final String clientName` | `initialize`'s `clientInfo.name` ("claude-code", …), or "unknown". |
| `transport` | `final McpTransport transport` |  |
| `tool` | `final String tool` |  |
| `risk` | `final McpToolRisk risk` |  |
| `groups` | `final Set<String> groups` |  |
| `arguments` | `final Map<String, Object?> arguments` |  |
| `caller` | `final String? caller` | Who the call is made for: an in-process caller, or the caller an external client's tagged session is bound to (`EditorMcp.attributeExternalCalls`); null otherwise. |

### `class McpApprovalDecision`

**Constructors:**

- `const McpApprovalDecision.allow()`
- `const McpApprovalDecision.deny(String this.reason)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `allowed` | `final bool allowed` |  |
| `reason` | `final String? reason` |  |

### `abstract interface class McpApprovalPolicy`

Decides whether a `tools/call` may run. The server runs every call through its ordered list of policies; the first `deny` wins.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `review` | `FutureOr<McpApprovalDecision> review(McpCallContext call)` |  |

---

[Previous: API reference](api-reference.md) | [Up: lumina_editor_api](index.md) | [Next: Editor plugins](../plugins/index.md)

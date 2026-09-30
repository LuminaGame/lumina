[English](../../en/lumina_ui/mcp-server.md)

# MCP sunucusu

Yapay zeka agent'larının açık proje üzerinde çalışmasını sağlayan editörün Model Context Protocol sunucusu: oturum başına bearer token ile localhost üzerinde Streamable HTTP transport, JSON-RPC protokolü, oturumlar, araç registry'si ve onay politikaları, uzun süren job'lar, dosya araçlarının arkasındaki proje sandbox'ı ve dosya snapshot'ları, frame yakalama ve play testing ile AI Agent Access paneli. Dosya yolları `lumina_ui/` paket dizinine görelidir.

**Bu sayfada:**

- [`lib/ui/features/mcp_server/services/host_editor_mcp.dart`](#libuifeaturesmcp_serverserviceshost_editor_mcpdart)
- [`lib/ui/features/mcp_server/services/lumina_guide.dart`](#libuifeaturesmcp_serverserviceslumina_guidedart)
- [`lib/ui/features/mcp_server/services/mcp_approval_policy.dart`](#libuifeaturesmcp_serverservicesmcp_approval_policydart)
- [`lib/ui/features/mcp_server/services/mcp_editor_sessions.dart`](#libuifeaturesmcp_serverservicesmcp_editor_sessionsdart)
- [`lib/ui/features/mcp_server/services/mcp_file_snapshots.dart`](#libuifeaturesmcp_serverservicesmcp_file_snapshotsdart)
- [`lib/ui/features/mcp_server/services/mcp_frame_capture.dart`](#libuifeaturesmcp_serverservicesmcp_frame_capturedart)
- [`lib/ui/features/mcp_server/services/mcp_jobs.dart`](#libuifeaturesmcp_serverservicesmcp_jobsdart)
- [`lib/ui/features/mcp_server/services/mcp_play_testing.dart`](#libuifeaturesmcp_serverservicesmcp_play_testingdart)
- [`lib/ui/features/mcp_server/services/mcp_protocol.dart`](#libuifeaturesmcp_serverservicesmcp_protocoldart)
- [`lib/ui/features/mcp_server/services/mcp_server_service.dart`](#libuifeaturesmcp_serverservicesmcp_server_servicedart)
- [`lib/ui/features/mcp_server/services/mcp_server_settings.dart`](#libuifeaturesmcp_serverservicesmcp_server_settingsdart)
- [`lib/ui/features/mcp_server/services/mcp_session.dart`](#libuifeaturesmcp_serverservicesmcp_sessiondart)
- [`lib/ui/features/mcp_server/services/mcp_tool.dart`](#libuifeaturesmcp_serverservicesmcp_tooldart)
- [`lib/ui/features/mcp_server/services/project_dart_sdk.dart`](#libuifeaturesmcp_serverservicesproject_dart_sdkdart)
- [`lib/ui/features/mcp_server/services/project_sandbox.dart`](#libuifeaturesmcp_serverservicesproject_sandboxdart)
- [`lib/ui/features/mcp_server/views/mcp_server_panel.dart`](#libuifeaturesmcp_serverviewsmcp_server_paneldart)
- [`lib/ui/features/mcp_server/views/mcp_tool_catalogue.dart`](#libuifeaturesmcp_serverviewsmcp_tool_cataloguedart)

## `lib/ui/features/mcp_server/services/host_editor_mcp.dart`

### `class HostEditorMcp`

The editor's MCP tools as plugins see them: one [McpToolRegistry] — the server's — shared by host tools, plugin tools, external agents over HTTP and in-process callers.

**Yapıcı Metotlar (Constructors):**

- `HostEditorMcp(this.tools, {this.log, this.launch})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `tools` | `final McpToolRegistry tools` |  |
| `launch` | `final McpClientLaunch? Function()? launch` | How external MCP clients start the stdio bridge. |
| `log` | `final void Function(String message)? log` | Reports a refused registration (the plugin's name is in the message). |
| `validName` | `static final RegExp validName` | MCP's tool-name alphabet (1–128 of `[A-Za-z0-9_.-]`). |
| `scoped` | `EditorMcp scoped(String pluginName)` | [pluginName]'s view: its tools are named `<pluginName>.<name>`. |
| `lazyScoped` | `static EditorMcp lazyScoped(HostEditorMcp Function() host, String pluginName)` | A plugin's view whose host is created on first use. |
| `removePlugin` | `void removePlugin(String pluginName)` | Removes every tool [pluginName] registered (it registers again). |
| `toolsOf` | `Set<String> toolsOf(String pluginName)` | The tools [pluginName] registered. |

## `lib/ui/features/mcp_server/services/lumina_guide.dart`

### `class LuminaGuideTopic`

One topic of the Lumina engine guide: its id (the `reference/<id>.md` file) and title.

**Yapıcı Metotlar (Constructors):**

- `const LuminaGuideTopic(this.id, this.title)`

### `class LuminaGuide`

The Lumina engine guide for AI models: how the engine works, written from the code, shipped with the editor as the `lumina-engine` skill (`skills/lumina-engine/`, Flutter assets, so every build carries it). `get_lumina_guide` and the `lumina://guide` resources serve it.

**Yapıcı Metotlar (Constructors):**

- `LuminaGuide({Future<String> Function(String assetPath)? load})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `root` | `static const String root` | The asset folder of the skill (`skills/lumina-engine`). |
| `topics` | `static const List<LuminaGuideTopic> topics` | The topics, in reading order: `project-layout`, `levels-actors-transforms`, `blueprints`, `gameplay-framework`, `input`, `umg-widgets`, `meshes-materials`, `filament-materials`, `lights`, `camera-spring-arm`, `play-testing`, `save-games`, `pitfalls`. A test keeps this list equal to the `reference/*.md` files. |
| `topicIds` | `static final Set<String> topicIds` |  |
| `resource` | `static const String resource` | `lumina://guide`: the overview and the topic list. |
| `resourceOf` | `static String resourceOf(String topic)` | `lumina://guide/<topic>`. |
| `assetOf` | `static String assetOf(String? topic)` | The asset path of [topic] (null: the overview, `SKILL.md`). |
| `stripFrontMatter` | `static String stripFrontMatter(String text)` | [text] without a leading YAML front matter block. |
| `overview` | `Future<String> overview() async` | The overview followed by the topic list and how to ask for a topic. |
| `topic` | `Future<String> topic(String id) async` | The text of [id]; an [ArgumentError] naming the topics when unknown. |

## `lib/ui/features/mcp_server/services/mcp_approval_policy.dart`

### `class AllowAllPolicy`

The default: every call runs, as before approvals existed.

**Yapıcı Metotlar (Constructors):**

- `const AllowAllPolicy()`

### `class McpRiskCeilingPolicy`

The panel's "External agents may run" ceiling: a call above [maxRisk] is refused (and its tool is not listed).

**Yapıcı Metotlar (Constructors):**

- `const McpRiskCeilingPolicy(this.maxRisk)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `maxRisk` | `final McpToolRisk Function() maxRisk` |  |

## `lib/ui/features/mcp_server/services/mcp_editor_sessions.dart`

### `class McpEditorSessions`

Reaches the sub-editor view model of an asset for the MCP tools: the one bound to the asset's open tab when there is one, else a view model this class creates, loads, binds as the tab's session and opens the tab for — so the user sees the agent's edits in the Material editor's code view or the Blueprint editor's graph canvas, and the tab's own undo stack and Save cover them. It also covers the UMG designer (a Widget Blueprint's graph is its designer's graph editor), the animation editors, the Sequencer and particles, and the Landscape, Static Mesh, Texture, Physics Asset, Sound, Enumeration and Blueprint Interface editors.

**Yapıcı Metotlar (Constructors):**

- `McpEditorSessions(this.vm)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `vm` | `final EditorViewModel vm` |  |
| `resolveAsset` | `RealAssetInfo resolveAsset(String wanted, {AssetType? type, String? forTool})` | The asset [wanted] names: a project-relative path, an absolute `.lmas` path, or a file name (with or without `.lmas`) when it is unique. |
| `tabIdOf` | `static String tabIdOf(RealAssetInfo asset)` |  |
| `projectRelative` | `String projectRelative(String path)` | [path] relative to the project (`/`-separated) when it lies inside it, else as given — what the tools report for an editor's absolute paths. |
| `material` | `Future<MaterialEditorViewModel> material(RealAssetInfo asset)` | The Material editor's view model for [asset], opening its tab. |
| `widget` | `Future<UmgEditorViewModel> widget(RealAssetInfo asset)` | The UMG designer's view model for the Widget Blueprint [asset], opening its tab. |
| `animBlueprint` | `Future<AnimBlueprintEditorViewModel> animBlueprint(RealAssetInfo asset)` | The Animation Blueprint editor's view model for [asset], opening its tab. |
| `blendSpace` | `Future<BlendSpaceEditorViewModel> blendSpace(RealAssetInfo asset)` | The Blend Space editor's view model for [asset]. |
| `animation` | `Future<AnimationEditorViewModel> animation(RealAssetInfo asset)` | The Animation editor's view model for [asset]. Created here it has no frame ticker (the tab's widget owns none either when it adopts one), so playback advances only through `animation_preview`. |
| `skeletalMesh` | `Future<SkeletalMeshEditorViewModel> skeletalMesh(RealAssetInfo asset)` | The Skeletal Mesh editor's view model for [asset]. |
| `sequencer` | `Future<SequencerViewModel> sequencer(RealAssetInfo asset)` | The Sequencer's view model for [asset], bound to the open level as the tab binds it (a scrub before the tab mounts moves the level's actors too). |
| `particle` | `Future<ParticleEditorViewModel> particle(RealAssetInfo asset)` | The Particle editor's view model for [asset]. |
| `landscape` | `Future<LandscapeEditorViewModel> landscape(RealAssetInfo asset)` | The Landscape editor's view model for [asset], created with the editor (its mesh palette) and its own [LandscapePreviewScene], which the tab's viewport attaches when it adopts the view model. |
| `staticMesh` | `Future<StaticMeshEditorViewModel> staticMesh(RealAssetInfo asset)` | The Static Mesh editor's view model for [asset]. |
| `texture` | `Future<TextureEditorViewModel> texture(RealAssetInfo asset)` | The Texture editor's view model for [asset]. |
| `physicsAsset` | `Future<PhysicsAssetEditorViewModel> physicsAsset(RealAssetInfo asset)` | The Physics Asset editor's view model for [asset]. |
| `audio` | `Future<AudioEditorViewModel> audio(RealAssetInfo asset)` | The Sound editor's view model for [asset] (silent: an agent cannot hear, so nothing here plays). |
| `blueprintEnum` | `Future<BlueprintEnumViewModel> blueprintEnum(RealAssetInfo asset)` | The Enumeration editor's view model for [asset]. |
| `blueprintInterface` | `Future<BlueprintInterfaceViewModel> blueprintInterface(RealAssetInfo asset)` | The Blueprint Interface editor's view model for [asset]. |
| `isWidget` | `bool isWidget(RealAssetInfo asset)` | Whether [asset] is a Widget Blueprint: a widget asset, or an actor Blueprint with the widget parent written by an older build. |
| `blueprint` | `Future<BlueprintEditorViewModel> blueprint(RealAssetInfo asset) async` | The Blueprint editor's view model for [asset], opening its tab. A Widget Blueprint's is its designer's graph editor, so the Blueprint tools edit a widget's graph unchanged. |
| `blueprintEditor` | `Future<BlueprintEditorViewModel> blueprintEditor(String wanted) async` | The Blueprint editor for [wanted] — `"level"` (the active level's Level Blueprint), a level `.lmas` (that level's Level Blueprint), an actor Blueprint asset, or a Widget Blueprint, whose graph it is — opening its tab. |
| `environment` | `Future<EnvironmentLightingViewModel> environment() async` | The Environment Lighting tab's view model (Tools → Environment Lighting), opening the tab: the one bound to it, or one created, opened and bound here that the tab's widget adopts. A bound view model left over from another level is replaced, so two view models never edit one level and none edits a level that is no longer open. |
| `navigation` | `Future<NavigationEditorViewModel> navigation() async` | The Navigation tab's view model (Tools → Navigation, Build → Build Navigation), opening the tab, as [environment] does. |
| `boundEnvironment` | `EnvironmentLightingViewModel? get boundEnvironment` | The bound Environment Lighting / Navigation view model when there is one for the open level, without opening anything (the read tools). |
| `boundNavigation` | `NavigationEditorViewModel? get boundNavigation` |  |
| `projectSettings` | `Future<ProjectSettingsViewModel> projectSettings() async` | The Project Settings tab's view model (Edit → Project Settings), opening the tab: the one bound to it, or one created here with the editor's project, Apply hook and cook code generator, loaded from the `.lmproject` and bound, which the tab's widget adopts. Tools stage on its working copy exactly as the tab's fields do. |
| `boundProjectSettings` | `ProjectSettingsViewModel? get boundProjectSettings` | The bound Project Settings view model, without opening anything. |
| `projectSettingsTabId` | `static const String projectSettingsTabId` |  |
| `environmentTabId` | `static const String environmentTabId` |  |
| `navigationTabId` | `static const String navigationTabId` |  |
| `isLevelBlueprint` | `static bool isLevelBlueprint(BlueprintEditorViewModel editor)` |  |
| `dispose` | `void dispose()` |  |

## `lib/ui/features/mcp_server/services/mcp_file_snapshots.dart`

### `class McpSnapshotContext`

Who took a snapshot: the MCP session and client, and — for an in-process call (a plugin such as MiniAI) — the `caller` string it passed to `EditorMcp.callTool`, which carries MiniAI's turn id so a whole turn's file changes can be listed and undone together.

**Yapıcı Metotlar (Constructors):**

- `const McpSnapshotContext({this.sessionId, this.client, this.caller})`
- `factory McpSnapshotContext.current()`: The attributed MCP call running now (`TransactionManager.currentOrigin`): its origin's `caller` (an in-process call's, or the one a plugin bound an external client's tagged session to), else the one in an in-process session id `in-process:<caller>`.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `sessionId` | `final String? sessionId` |  |
| `client` | `final String? client` |  |
| `caller` | `final String? caller` |  |

### `class McpFileSnapshot`

One pre-write snapshot.

**Yapıcı Metotlar (Constructors):**

- `const McpFileSnapshot({required this.id, required this.seq, required this.tool, required this.path, required this.existed, required this.bytes, required this.sh...`
- `factory McpFileSnapshot.fromJson(Map<String, dynamic> j)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `id` | `final String id` |  |
| `seq` | `final int seq` |  |
| `tool` | `final String tool` |  |
| `path` | `final String path` | Project-relative, `/`-separated. |
| `existed` | `final bool existed` | Whether the file existed; its previous bytes are in `before` when it did. |
| `bytes` | `final int bytes` |  |
| `sha256` | `final String? sha256` |  |
| `created` | `final DateTime created` |  |
| `sessionId` | `final String? sessionId` |  |
| `client` | `final String? client` |  |
| `caller` | `final String? caller` |  |
| `toJson` | `Map<String, Object?> toJson()` |  |

### `class McpRestoreResult`

What [McpFileSnapshots.restore] did.

**Yapıcı Metotlar (Constructors):**

- `const McpRestoreResult({required this.restored, required this.replaced, required this.restoredBytes, this.trashId})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `restored` | `final McpFileSnapshot restored` |  |
| `replaced` | `final McpFileSnapshot replaced` | The snapshot of the state the restore replaced (restore it to undo). |
| `restoredBytes` | `final int restoredBytes` |  |
| `trashId` | `final String? trashId` | Set when the snapshot's file did not exist and the restore moved the current one to the project trash. |

### `class McpFileSnapshots`

The file tools' undo: before every write, edit, delete, restore and codegen overwrite the file's previous bytes go to `<project>/.lumina/mcp/snapshots/<seq:06d>-<tool>/` (`manifest.json` + `before`). Newest [maxCount] snapshots and at most [maxBytes] are kept.

**Yapıcı Metotlar (Constructors):**

- `McpFileSnapshots(this.projectDir, {required this.trash, this.maxCount = 500, this.maxBytes = 200 * 1024 * 1024})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `projectDir` | `final String projectDir` |  |
| `trash` | `final ProjectTrash trash` |  |
| `root` | `final Directory root` |  |
| `maxCount` | `final int maxCount` |  |
| `maxBytes` | `final int maxBytes` |  |
| `take` | `McpFileSnapshot take(String relative, String tool, McpSnapshotContext context)` | Snapshots [relative]'s current bytes (or its absence) before [tool] changes it. |
| `byId` | `McpFileSnapshot? byId(String id)` |  |
| `list` | `List<McpFileSnapshot> list({String? path, int limit = 20, String? caller, String? callerPrefix, String? client...` | Newest first, filtered by project-relative [path], by the exact in-process [caller] or a [callerPrefix] of it, by [client] or [sessionId]; at most [limit]. |
| `restore` | `McpRestoreResult restore(String id, McpSnapshotContext context)` | Puts snapshot [id]'s state back: snapshots the current state first (so the restore is itself reversible), then writes the old bytes or — when the file did not exist — moves the current file to the project trash. |
| `writeAtomically` | `static void writeAtomically(File file, List<int> bytes, {void Function()? beforeRename})` | Writes [bytes] to `<file>.lumina-tmp`, then renames it over [file]. |

## `lib/ui/features/mcp_server/services/mcp_frame_capture.dart`

### `typedef McpFrame`

A captured frame: PNG bytes and their size in pixels.

### `abstract final class McpFrameCapture`

Captures the composited frame of a keyed [RepaintBoundary] as a PNG: what the user sees, Filament texture included, the way the smoke recorder captures it. A frame wider than [maxWidth] is rendered at a lower pixel ratio so the base64 stays small.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `capture` | `static Future<McpFrame> capture(GlobalKey key, {int maxWidth = 1280, String what = 'viewport'}) async` |  |

## `lib/ui/features/mcp_server/services/mcp_jobs.dart`

### `enum McpJobState`

Where an [McpJob] is.

**Değerler:**

- `queued`
- `running`
- `succeeded`
- `failed`
- `cancelled`

### `class McpJobLogLine`

One line of a job's log; [index] is stable for the job's lifetime, so an agent pages with `get_job({since_log_index})`.

**Yapıcı Metotlar (Constructors):**

- `const McpJobLogLine({required this.index, required this.at, required this.level, required this.source, required this.message})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `index` | `final int index` |  |
| `at` | `final DateTime at` |  |
| `level` | `final String level` |  |
| `source` | `final String source` |  |
| `message` | `final String message` |  |
| `toJson` | `Map<String, Object?> toJson()` |  |

### `class McpJobFailure`

Thrown by a job's `run` to end it as `failed` with a [result] (a build whose pipeline failed still reports its per-step statuses).

**Yapıcı Metotlar (Constructors):**

- `const McpJobFailure(this.message, {this.result})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `message` | `final String message` |  |
| `result` | `final Object? result` |  |

### `class McpJobConflict`

A second job on an exclusive resource while one runs there.

**Yapıcı Metotlar (Constructors):**

- `const McpJobConflict(this.running)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `running` | `final McpJob running` |  |
| `message` | `String get message` |  |

### `class McpJob`

A long-running operation an MCP call started and returned at once: a Build All, a Cook & Package, Play Standalone, a widget library switch. The agent polls it (`get_job`), long-polls it (`wait_job`, bounded) or cancels it (`cancel_job`); no MCP call ever blocks for the whole operation.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `id` | `final String id` |  |
| `kind` | `final String kind` |  |
| `title` | `final String title` |  |
| `exclusive` | `final String? exclusive` | The resource key this job holds alone while it runs, or null. |
| `state` | `McpJobState get state` |  |
| `progress` | `double? progress` | 0..1, or null while unmeasurable. |
| `stage` | `String? stage` | What the job is doing now (`Running Validate Assets…`, `running`). |
| `started` | `final DateTime started` |  |
| `finished` | `DateTime? finished` |  |
| `result` | `Object? result` |  |
| `error` | `String? error` |  |
| `log` | `List<McpJobLogLine> get log` |  |
| `nextLogIndex` | `int get nextLogIndex` |  |
| `isDone` | `bool get isDone` | Whether the job has left `queued` / `running`. |
| `settled` | `Future<void> get settled` | Completes when the job leaves `running`. |
| `runDone` | `Future<void> get runDone` | Completes when the job's `run` has returned (after a cancel too). |
| `cancelRequested` | `bool get cancelRequested` | Whether `cancel_job` was called. |
| `addLog` | `void addLog(String message, {String level = 'info', String source = 'Job'})` |  |
| `update` | `void update({double? progress, String? stage, bool clearProgress = false})` |  |
| `elapsed` | `Duration get elapsed` |  |
| `summary` | `Map<String, Object?> summary()` | The job as `list_jobs` shows it. |
| `detail` | `Map<String, Object?> detail({int sinceLogIndex = 0, int tail = 100})` | The job as `get_job` shows it: [summary], result, error, log lines from [sinceLogIndex] (the last [tail] of them). |

### `class McpJobRegistry`

The session's jobs: ids `job_<n>`, the last [capacity] kept, one running job per exclusive key.

**Yapıcı Metotlar (Constructors):**

- `McpJobRegistry({this.capacity = 50})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `capacity` | `final int capacity` |  |
| `jobs` | `List<McpJob> get jobs` |  |
| `byId` | `McpJob? byId(String id)` |  |
| `runningOn` | `McpJob? runningOn(String exclusive)` | The job running on [exclusive], or null. |
| `start` | `McpJob start(String kind, {required Future<Object?> Function(McpJob job) run, String? title, void Function()?...` | Starts [run] as a new job and returns it at once. [cancel] is what `cancel_job` calls (once). With [exclusive] set, a second job while one runs on the same key throws [McpJobConflict]. `run`'s value becomes the job's result (`succeeded`); an [McpJobFailure] or any other exception ends it `failed`. |
| `cancel` | `bool cancel(McpJob job)` | Cancels [job]: its cancel callback runs once and it is `cancelled` at once. Returns false when it had already finished. |
| `wait` | `Future<bool> wait(McpJob job, Duration timeout) async` | Waits until [job] leaves `running`, at most [timeout]; returns whether it did. |

## `lib/ui/features/mcp_server/services/mcp_play_testing.dart`

### `class McpPlayTesting`

The MCP layer's side of play-testing: the keys agents hold down in the running game, the frames they advanced, and the release of every held key when Play stops, the player is ejected, or the agent's MCP session ends — so an agent that forgets an `up` never leaves W stuck.

**Yapıcı Metotlar (Constructors):**

- `McpPlayTesting(this.vm)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `vm` | `final EditorViewModel vm` |  |
| `framesAdvanced` | `int framesAdvanced` | Frames `pie_advance` / `pie_action` / `pie_key tap` stepped this Play. |
| `pie` | `PieController get pie` |  |
| `heldKeys` | `List<String> get heldKeys` | The keys agents hold, by id (`KeyW`). |
| `isHeld` | `bool isHeld(LuminaKey key)` |  |
| `press` | `bool press(LuminaKey key)` | Presses [key] in the running game (while paused too; the next frame sees it) and remembers it. False when the game refuses input (ejected). |
| `release` | `void release(LuminaKey key)` | Releases [key]; always forwarded, even when ejected. |
| `releaseAll` | `List<String> releaseAll({String? sessionId})` | Releases every held key (only [sessionId]'s when given); returns them. |
| `pauseForStepping` | `bool pauseForStepping()` | Pauses a running game (frame stepping needs it). Returns whether it was running before. |
| `resumeAfterStepping` | `void resumeAfterStepping(bool wasRunning)` | Resumes the game [pauseForStepping] paused. |
| `step` | `void step(int frames, double dt, {void Function()? beforeFrame})` | Steps the paused game [frames] times by [dt], without a log line per frame. [beforeFrame] runs before each step (analog values are consumed per tick, so a held stick is injected every frame). |
| `dispose` | `void dispose()` |  |

## `lib/ui/features/mcp_server/services/mcp_protocol.dart`

### `abstract final class McpProtocol`

The JSON-RPC 2.0 and Model Context Protocol shapes the editor's MCP server speaks.

Only what the editor emits and accepts is modelled: `initialize`, `notifications/initialized`, `ping`, `tools/list`, `tools/call`, `resources/list`, `resources/read`. The wire format follows the MCP specification's Streamable HTTP transport (2025-06-18); the newer 2025-11-25 revision changes nothing in this subset, so it is accepted too.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `supportedVersions` | `static const List<String> supportedVersions` | Protocol revisions this server implements, newest first. |
| `defaultVersion` | `static const String defaultVersion` | The revision answered when the client names one this server does not know: the spec says to answer with the newest version the server supports that the client might accept, and every client at the time of writing understands 2025-06-18. |
| `serverName` | `static const String serverName` |  |
| `negotiate` | `static String negotiate(Object? requested)` | The revision to answer for a client's `protocolVersion`. |

### `class JsonRpcRequest`

One decoded JSON-RPC request or notification.

**Yapıcı Metotlar (Constructors):**

- `const JsonRpcRequest({required this.id, required this.method, required this.params})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `id` | `final Object? id` | Null for a notification. |
| `method` | `final String method` |  |
| `params` | `final Map<String, Object?> params` |  |
| `isNotification` | `bool get isNotification` |  |
| `fromJson` | `static JsonRpcRequest fromJson(Object? json)` | Decodes one message object. Throws [JsonRpcException] with [JsonRpcErrorCode.invalidRequest] for anything that is not a request. |

### `abstract final class JsonRpcResponse`

Builds JSON-RPC response objects.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `result` | `static Map<String, Object?> result(Object? id, Object? result)` |  |
| `error` | `static Map<String, Object?> error(Object? id, JsonRpcException error)` |  |

## `lib/ui/features/mcp_server/services/mcp_server_service.dart`

### `class McpCallRecord`

One `tools/call` the server ran, for the panel's Recent calls list.

**Yapıcı Metotlar (Constructors):**

- `const McpCallRecord({required this.tool, required this.started, required this.duration, required this.ok, this.error, this.risk, this.client = 'unknown', this.d...`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `tool` | `final String tool` |  |
| `started` | `final DateTime started` |  |
| `duration` | `final Duration duration` |  |
| `ok` | `final bool ok` |  |
| `error` | `final String? error` |  |
| `risk` | `final McpToolRisk? risk` | The tool's risk (null for an unknown tool) and the calling client. |
| `client` | `final String client` |  |
| `deniedReason` | `final String? deniedReason` | Set when the approval chain refused the call. |
| `detail` | `final String? detail` | What the call touched, for the row's tooltip (e.g. a file tool's project-relative path and snapshot id). |
| `jobId` | `final String? jobId` | The job the call started (`start_build`, `play_standalone`, …), whose state the row shows beside it. |
| `denied` | `bool get denied` |  |

### `class McpServerService`

The editor's Model Context Protocol server: MCP's Streamable HTTP transport on `127.0.0.1` only, guarded by a bearer token minted per editor session, driving the real [EditorViewModel] so an AI agent does exactly what a user could do with the mouse — undoably, and visibly in the Outliner, Details and viewport.

`POST /mcp` carries one JSON-RPC request (or a batch) and is answered with `application/json`. `initialize` issues an `Mcp-Session-Id` the client echoes on every later request. `GET /mcp` with that session opens its server-to-client SSE stream, which carries `notifications/tools/list_changed` when a plugin adds or removes a tool; `DELETE /mcp` ends the session and its stream.

On start the connection details go to `mcp_server.json` (mode 0600) in the editor's config directory, where the stdio bridge (`bin/lumina_mcp_bridge.dart`) and the panel read them.

The bridge's `--groups a,b` connects to `/mcp?groups=a,b`, and `--caller <tag>` to `/mcp?caller=<tag>`: `initialize` keeps the tag with the session (`McpSession.callerTag`). While a plugin binds that tag (`EditorMcp.attributeExternalCalls`, MiniAI running Claude Code), the session's calls run as the plugin's caller and in its zone, so its `runTransaction` groups their level edits and their file snapshots carry its caller.

**Yapıcı Metotlar (Constructors):**

- `McpServerService(this.viewModel, {McpServerSettings? settings, Directory? configDir,})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `viewportBoundaryKey` | `GlobalKey get viewportBoundaryKey` | The shell's `RepaintBoundary` around the level viewport, and around the whole editor: what `viewport_screenshot` captures. |
| `editorBoundaryKey` | `GlobalKey get editorBoundaryKey` |  |
| `Expando` | `static final Expando<(GlobalKey, GlobalKey)> _boundaryKeys = Expando('mcp_boundary_keys')` |  |
| `subEditorBoundaryKeyFor` | `GlobalKey subEditorBoundaryKeyFor(String tabId)` | The `RepaintBoundary` around sub-editor tab [tabId] in the shell, what `asset_editor_screenshot` captures; one per tab id and editor view model, like the two keys above. |
| `viewModel` | `final EditorViewModel viewModel` |  |
| `settings` | `final McpServerSettings settings` |  |
| `tools` | `final McpToolRegistry tools` |  |
| `jobs` | `final McpJobRegistry jobs` | The long-running operations tools start and agents poll. |
| `playTesting` | `late final McpPlayTesting playTesting` | The keys agents hold in Play, released when their session ends. |
| `approvalPolicies` | `List<McpApprovalPolicy> get approvalPolicies` | Every `tools/call` passes these in order; the first deny wins. Starts with the panel's risk ceiling. |
| `sessions` | `late final McpEditorSessions sessions` | The sub-editor view models the tools edit through. |
| `connectionFileName` | `static const String connectionFileName` |  |
| `path` | `static const String path` |  |
| `bridgeScriptPath` | `static String get bridgeScriptPath` | The path of the stdio bridge, for the registration command the panel shows. Resolved from this package's location when the editor runs from its source tree (`flutter run`), else next to the executable. |
| `dartExecutable` | `static String get dartExecutable` | The Dart executable external clients start the bridge with : `FLUTTER_ROOT`'s SDK, else the Flutter SDK this editor's own package config names, else the running `dart`, else `dart` on PATH. |
| `clientLaunch` | `McpClientLaunch get clientLaunch` | How an external MCP client starts a connection to this editor: the stdio bridge, which reads [connectionFile] itself. |
| `sessionList` | `List<McpSession> get sessionList` |  |
| `isRunning` | `bool get isRunning` |  |
| `port` | `int? get port` |  |
| `token` | `String get token` |  |
| `lastError` | `String? get lastError` |  |
| `sessionCount` | `int get sessionCount` |  |
| `requestCount` | `int get requestCount` |  |
| `recentCalls` | `List<McpCallRecord> get recentCalls` |  |
| `onFallbackPort` | `bool get onFallbackPort` | True when the preferred port was taken and an ephemeral one is in use. |
| `url` | `String? get url` |  |
| `connectionFile` | `File get connectionFile` |  |
| `httpRegistrationCommand` | `String? get httpRegistrationCommand` | `claude mcp add` for the HTTP transport, with this session's token. |
| `stdioRegistrationCommand` | `String get stdioRegistrationCommand` | `claude mcp add` for a stdio-only client: the bridge reads the connection file, so the command never changes. |
| `start` | `Future<bool> start({int? port}) async` | Binds the loopback address on [port] (default: the settings' port, then an ephemeral port when that one is taken) and writes the connection file. Returns whether the server is listening. |
| `stop` | `Future<void> stop() async` |  |
| `applySettings` | `Future<void> applySettings() async` | Applies the settings' switch: starts when enabled, stops otherwise. |
| `regenerateToken` | `void regenerateToken()` | A new token; clients registered with the old one must re-register. |
| `connectionInfo` | `Map<String, Object?> connectionInfo()` |  |
| `openStreamCount` | `int get openStreamCount` |  |
| `projectResource` | `static const String projectResource` |  |
| `outputLogResource` | `static const String outputLogResource` |  |
| `selectionResource` | `static const String selectionResource` |  |
| `guide` | `final LuminaGuide guide` | The Lumina engine guide the tool and the `lumina://guide` resources serve. |

## `lib/ui/features/mcp_server/services/mcp_server_settings.dart`

### `class McpServerSettings`

Whether the editor offers its MCP server to AI agents, and on which port, per user in `mcp_server_settings.json` of the editor's config directory ([LuminaConfigDir]; a temp directory in every test). Saved on change.

Enabled by default: the server binds loopback only and its token lives in a 0600 file, so nothing outside this user's own processes can reach it.

**Yapıcı Metotlar (Constructors):**

- `factory McpServerSettings.load({Directory? configDir})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `fileName` | `static const String fileName` |  |
| `defaultPort` | `static const int defaultPort` | The port the server tries first, so a registered `claude mcp add --transport http` URL survives editor restarts. |
| `file` | `final File file` |  |
| `enabled` | `bool get enabled` |  |
| `port` | `int get port` |  |
| `maxRisk` | `McpToolRisk get maxRisk` | "External agents may run": tools above this risk are not listed and their calls are denied. Default: everything. |
| `setMaxRisk` | `void setMaxRisk(McpToolRisk value)` |  |
| `setEnabled` | `void setEnabled(bool value)` |  |
| `setPort` | `void setPort(int value)` |  |

## `lib/ui/features/mcp_server/services/mcp_session.dart`

### `class McpSession`

One MCP session: issued by `initialize`, echoed by the client as `Mcp-Session-Id`.

**Yapıcı Metotlar (Constructors):**

- `const McpSession({required this.id, required this.started, required this.clientName, required this.protocolVersion, this.groups,})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `id` | `final String id` |  |
| `started` | `final DateTime started` |  |
| `clientName` | `final String clientName` | `initialize`'s `clientInfo.name`. |
| `protocolVersion` | `final String protocolVersion` |  |
| `groups` | `final Set<String>? groups` | The groups `tools/list` shows this session (null: every group), from the endpoint URL's `?groups=level,view`. |
| `parseGroups` | `static Set<String>? parseGroups(Object? value)` | `level,view` (a query value) or `["level", "view"]` (a `params.groups`) as a group set; null when absent. Unknown names are a −32602 that lists the known groups. |

## `lib/ui/features/mcp_server/services/mcp_tool.dart`

### `class McpToolRegistry`

The tools a server offers, by name; validates a call's arguments against the declared schema before running the handler.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `approvalPolicies` | `final List<McpApprovalPolicy> approvalPolicies` | The approval chain every call passes: the first `deny` wins; empty means allow all. |
| `approvalTimeout` | `Duration approvalTimeout` | How long a policy may take before the call is denied. |
| `register` | `void register(McpTool tool)` | Refuses a tool with no group, an unknown group, or a `wraps` entry on [McpExposure.neverExpose]. |
| `registerAll` | `void registerAll(Iterable<McpTool> tools)` |  |
| `unregister` | `void unregister(String name)` | Removes tool [name] (a plugin re-registering). |
| `toolsChanged` | `final McpChangeSignal toolsChanged` | Fires when a tool is added or removed. |
| `calls` | `Stream<McpToolCallEvent> get calls` | Every [call], from either transport, denied ones included. |
| `tools` | `List<McpTool> get tools` |  |
| `byName` | `McpTool? byName(String name)` |  |
| `filtered` | `List<McpTool> filtered({Set<String>? groups, McpToolRisk? maxRisk})` | The tools in [groups] (all when null; `core` always) at or below [maxRisk]. |
| `list` | `List<Map<String, Object?>> list({Set<String>? groups, McpToolRisk? maxRisk})` |  |
| `call` | `Future<McpToolResult> call(String name, Map<String, Object?> arguments, {required McpCallContext Function(McpT...` | Runs [name] with [arguments]: validates them, passes [context] through the approval chain, then runs the handler as one attributed call (every undo step it records is one `MCP: …` step per stack). A handler that throws a [JsonRpcException] surfaces it as a protocol error (bad arguments); any other exception becomes a tool error result with its message, never a transport failure. A denied call is a tool error whose text is `{"status": "denied", "tool", "risk", "reason"}`. |

## `lib/ui/features/mcp_server/services/project_dart_sdk.dart`

### `abstract final class ProjectDartSdk`

The Dart SDK a project's packages were resolved with, in the order `BlueprintFunctionScanner._sdkFor` (lumina) uses: the `flutterRoot` in `.dart_tool/package_config.json`, else `FLUTTER_ROOT`, else the running `dart`. A mirror of that private method; switch to it when lumina exposes it.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `packageConfig` | `static File packageConfig(String projectDir)` |  |
| `resolve` | `static String? resolve(String projectDir)` | The SDK directory (with `bin/dart`), or null when none is found. |
| `dartExecutable` | `static String dartExecutable(String sdk)` | `<sdk>/bin/dart` (`dart.exe` on Windows). |

## `lib/ui/features/mcp_server/services/project_sandbox.dart`

### `enum SandboxAccess`

What a file tool wants to do with a path.

**Değerler:**

- `read`
- `write`
- `delete`

### `class SandboxViolation`

A path a file tool may not touch; [message] is what the agent sees.

**Yapıcı Metotlar (Constructors):**

- `const SandboxViolation(this.message)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `message` | `final String message` |  |

### `class SandboxPath`

A path inside the project: its real [absolute] path and its project-relative, `/`-separated form (`.` for the root itself).

**Yapıcı Metotlar (Constructors):**

- `const SandboxPath(this.absolute, this.relative)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `absolute` | `final String absolute` |  |
| `relative` | `final String relative` |  |
| `isRoot` | `bool get isRoot` |  |

### `class ProjectSandbox`

The open project's root as the file tools see it: every path is resolved (symlinks and `..` included) and must stay inside the resolved root; writes and deletes are further denied where the editor, the build or another tool owns the files.

**Yapıcı Metotlar (Constructors):**

- `ProjectSandbox(String projectDir)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `root` | `final String root` | The project directory with its symlinks resolved. |
| `skippedDirs` | `static const Set<String> skippedDirs` | The directories a recursive listing or search skips unless the listed / searched path is inside them. |
| `resolve` | `SandboxPath resolve(String path, {required SandboxAccess access})` | [path] (project-relative or absolute) resolved inside the project; throws a [SandboxViolation] when it leaves the project or [access] is denied there. |
| `isBinaryFile` | `bool isBinaryFile(File file)` | Whether [file] holds a NUL byte in its first 8 KiB. |
| `checkContent` | `static void checkContent(List<int> bytes)` | Refuses [bytes] that are not UTF-8 text without NUL bytes. |
| `generatedBy` | `static String? generatedBy(String relative)` | The tool that regenerates [relative] (a file the editor writes), or null for a hand-written file. |

### `class SandboxGlob`

A glob over `/`-separated relative paths: `*` (not `/`), `**` (anything; `**/` also matches no directory), `?`, `{a,b}` and `[...]` / `[!...]` classes. Kept in this file so `package:glob` stays a transitive dependency.

**Yapıcı Metotlar (Constructors):**

- `SandboxGlob(this.pattern)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `pattern` | `final String pattern` |  |
| `matches` | `bool matches(String path)` |  |

## `lib/ui/features/mcp_server/views/mcp_server_panel.dart`

### `class McpServerPanel`

Tools → AI Agent Access (MCP): the on/off switch for the editor's MCP server, its status and port, the exact registration commands with copy buttons, and the calls agents made.

**Yapıcı Metotlar (Constructors):**

- `const McpServerPanel({super.key, required this.service, this.onClose})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `service` | `final McpServerService service` |  |
| `onClose` | `final VoidCallback? onClose` |  |

## `lib/ui/features/mcp_server/views/mcp_tool_catalogue.dart`

### `class McpRiskBadge`

A tool risk as a small coloured badge.

**Yapıcı Metotlar (Constructors):**

- `const McpRiskBadge(this.risk, {super.key})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `risk` | `final McpToolRisk risk` |  |
| `label` | `static String label(McpToolRisk r)` |  |
| `color` | `static Color color(McpToolRisk r)` |  |

### `class McpToolCatalogue`

The registry as a collapsible tree of groups → tools, each with its risk badge and title, under a header counted from the registry ("52 tools · 17 read-only · 13 editor state · 21 edits · 1 destructive").

**Yapıcı Metotlar (Constructors):**

- `const McpToolCatalogue({super.key, required this.registry, this.initiallyExpanded = false})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `registry` | `final McpToolRegistry registry` |  |
| `initiallyExpanded` | `final bool initiallyExpanded` |  |
| `summary` | `static String summary(McpToolRegistry registry)` | The header line, from the registry. |

---

[Önceki: Marketplace](marketplace.md) | [Üst: lumina_ui (Lumina Studio)](index.md) | [Sonraki: MCP araç kataloğu](mcp-tools.md)

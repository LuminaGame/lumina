import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show GlobalKey;
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart' show McpClientLaunch;
import 'package:lumina_ui/ui/core/host/editor_host.dart' show LuminaEditorHost;

import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/mcp_server/tools/anim_blueprint_tools.dart';
import 'package:lumina_ui/ui/features/mcp_server/tools/animation_tools.dart';
import 'package:lumina_ui/ui/features/mcp_server/tools/asset_tools.dart';
import 'package:lumina_ui/ui/features/mcp_server/tools/audio_tools.dart';
import 'package:lumina_ui/ui/features/mcp_server/tools/blend_space_tools.dart';
import 'package:lumina_ui/ui/features/mcp_server/tools/blueprint_class_tools.dart';
import 'package:lumina_ui/ui/features/mcp_server/tools/blueprint_member_tools.dart';
import 'package:lumina_ui/ui/features/mcp_server/tools/blueprint_tools.dart';
import 'package:lumina_ui/ui/features/mcp_server/tools/blueprint_type_tools.dart';
import 'package:lumina_ui/ui/features/mcp_server/tools/build_tools.dart';
import 'package:lumina_ui/ui/features/mcp_server/tools/code_tools.dart';
import 'package:lumina_ui/ui/features/mcp_server/tools/content_tools.dart';
import 'package:lumina_ui/ui/features/mcp_server/tools/maintenance_tools.dart';
import 'package:lumina_ui/ui/features/mcp_server/tools/marketplace_tools.dart';
import 'package:lumina_ui/ui/features/mcp_server/tools/plugin_tools.dart';
import 'package:lumina_ui/ui/features/mcp_server/tools/source_control_tools.dart';
import 'package:lumina_ui/ui/features/mcp_server/tools/details_tools.dart';
import 'package:lumina_ui/ui/features/mcp_server/tools/editor_preferences_tools.dart';
import 'package:lumina_ui/ui/features/mcp_server/tools/level_file_tools.dart';
import 'package:lumina_ui/ui/features/mcp_server/tools/level_settings_tools.dart';
import 'package:lumina_ui/ui/features/mcp_server/tools/outliner_tools.dart';
import 'package:lumina_ui/ui/features/mcp_server/tools/viewport_settings_tools.dart';
import 'package:lumina_ui/ui/features/mcp_server/tools/component_tools.dart';
import 'package:lumina_ui/ui/features/mcp_server/tools/fs_tools.dart';
import 'package:lumina_ui/ui/features/mcp_server/tools/guide_tools.dart';
import 'package:lumina_ui/ui/features/mcp_server/tools/job_tools.dart';
import 'package:lumina_ui/ui/features/mcp_server/tools/landscape_tools.dart';
import 'package:lumina_ui/ui/features/mcp_server/tools/level_tools.dart';
import 'package:lumina_ui/ui/features/mcp_server/tools/log_tools.dart';
import 'package:lumina_ui/ui/features/mcp_server/tools/material_tools.dart';
import 'package:lumina_ui/ui/features/mcp_server/tools/play_testing_tools.dart';
import 'package:lumina_ui/ui/features/mcp_server/tools/pie_sequence_tool.dart';
import 'package:lumina_ui/ui/features/mcp_server/tools/play_tools.dart';
import 'package:lumina_ui/ui/features/mcp_server/tools/project_settings_tools.dart';
import 'package:lumina_ui/ui/features/mcp_server/tools/selection_tools.dart';
import 'package:lumina_ui/ui/features/mcp_server/tools/umg_tools.dart';
import 'package:lumina_ui/ui/features/mcp_server/tools/material_graph_tools.dart';
import 'package:lumina_ui/ui/features/mcp_server/tools/particle_tools.dart';
import 'package:lumina_ui/ui/features/mcp_server/tools/physics_asset_tools.dart';
import 'package:lumina_ui/ui/features/mcp_server/tools/sequencer_tools.dart';
import 'package:lumina_ui/ui/features/mcp_server/tools/skeletal_mesh_tools.dart';
import 'package:lumina_ui/ui/features/mcp_server/tools/static_mesh_tools.dart';
import 'package:lumina_ui/ui/features/mcp_server/tools/texture_tools.dart';
import 'package:lumina_ui/ui/features/mcp_server/tools/view_tools.dart';
import 'package:lumina_ui/ui/features/main_editor/commands/editor_transaction.dart';
import 'package:lumina_ui/ui/features/mcp_server/tools/core_tools.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/lumina_guide.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_editor_sessions.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_jobs.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_play_testing.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_protocol.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_server_settings.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_session.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_tool.dart';

part 'mcp_server_service/http.dart';
part 'mcp_server_service/rpc.dart';

/// One `tools/call` the server ran, for the panel's Recent calls list.
class McpCallRecord {
  final String tool;
  final DateTime started;
  final Duration duration;
  final bool ok;
  final String? error;

  /// The tool's risk (null for an unknown tool) and the calling client.
  final McpToolRisk? risk;
  final String client;

  /// Set when the approval chain refused the call.
  final String? deniedReason;

  /// What the call touched, for the row's tooltip (e.g. a file
  /// tool's project-relative path and snapshot id).
  final String? detail;

  /// The job the call started (`start_build`,
  /// `play_standalone`, …), whose state the row shows beside it.
  final String? jobId;

  const McpCallRecord({
    required this.tool,
    required this.started,
    required this.duration,
    required this.ok,
    this.error,
    this.risk,
    this.client = 'unknown',
    this.deniedReason,
    this.detail,
    this.jobId,
  });

  bool get denied => deniedReason != null;
}

/// The editor's Model Context Protocol server: MCP's
/// Streamable HTTP transport on `127.0.0.1` only, guarded by a bearer token
/// minted per editor session, driving the real [EditorViewModel] so an AI
/// agent does exactly what a user could do with the mouse — undoably, and
/// visibly in the Outliner, Details and viewport.
///
/// `POST /mcp` carries one JSON-RPC request (or a batch) and is answered
/// with `application/json`. `initialize` issues an `Mcp-Session-Id` the
/// client echoes on every later request. `GET /mcp` with that session opens
/// its server-to-client SSE stream, which carries
/// `notifications/tools/list_changed` when a plugin adds or removes a tool;
/// `DELETE /mcp` ends the session and its stream.
///
/// On start the connection details go to `mcp_server.json` (mode 0600) in
/// the editor's config directory, where the stdio bridge
/// (`bin/lumina_mcp_bridge.dart`) and the panel read them.
class McpServerService extends ChangeNotifier {
  McpServerService(
    this.viewModel, {
    McpServerSettings? settings,
    Directory? configDir,
  })  : settings = settings ?? McpServerSettings.load(configDir: configDir),
        _configDir = configDir {
    // The panel's risk ceiling is the first policy; more are
    // appended to approvalPolicies (the first deny wins).
    tools.approvalPolicies.add(McpRiskCeilingPolicy(() => this.settings.maxRisk));
    tools.onToolError = (tool, e, st) => viewModel.logger.log('$tool failed: $e\n$st', level: 'error', source: 'MCP');
    registerCoreTools(
      tools,
      viewModel,
      sessions,
      activeGroups: () => _currentSession?.groups,
      maxRisk: () => this.settings.maxRisk,
    );
    registerLevelTools(tools, viewModel);
    registerSelectionTools(tools, viewModel);
    // How the engine works, for AI models (the lumina-engine skill).
    registerGuideTools(tools, guide);
    // The Content Browser and the Material / Blueprint editors.
    registerAssetTools(tools, viewModel, sessions);
    registerMaterialTools(tools, viewModel, sessions);
    registerBlueprintTools(tools, viewModel, sessions);
    // Components, Blueprint class settings and members.
    registerComponentTools(tools, viewModel);
    registerBlueprintClassTools(tools, viewModel, sessions);
    registerBlueprintMemberTools(tools, viewModel, sessions);
    // Play, the viewport camera and screenshots, the log.
    registerPlayTools(tools, viewModel, play: playTesting, jobs: jobs);
    registerViewTools(
      tools,
      viewModel,
      viewportBoundaryKey: viewportBoundaryKey,
      editorBoundaryKey: editorBoundaryKey,
      sessions: sessions,
      subEditorBoundaryKeyFor: subEditorBoundaryKeyFor,
    );
    registerLogTools(tools, viewModel);
    // Project files (sandboxed, snapshotted) and game code.
    registerFsTools(tools, viewModel);
    registerCodeTools(tools, viewModel);
    // Level files, the Outliner, multi-select Details, the
    // level's own settings and the viewport toolbar.
    registerLevelFileTools(tools, viewModel);
    registerOutlinerTools(tools, viewModel);
    registerDetailsTools(tools, viewModel);
    registerLevelSettingsTools(tools, viewModel, sessions);
    registerViewportSettingsTools(tools, viewModel);
    // Long-running jobs, Project
    // Settings, Editor Preferences, the Build menu and play-testing.
    registerJobTools(tools, jobs);
    registerProjectSettingsTools(tools, viewModel, sessions, jobs);
    registerEditorPreferencesTools(tools, viewModel);
    registerBuildTools(tools, viewModel, jobs);
    registerPlayTestingTools(tools, viewModel, playTesting, viewportBoundaryKey: viewportBoundaryKey);
    registerPieSequenceTool(tools, viewModel, playTesting, viewportBoundaryKey: viewportBoundaryKey);
    // Content Browser organisation, Plugins, the Marketplace,
    // Source Control and Clear Derived Data Cache.
    registerContentTools(tools, viewModel, sessions, jobs);
    registerPluginTools(tools, viewModel, jobs);
    registerMarketplaceTools(tools, viewModel, jobs);
    registerSourceControlTools(tools, viewModel);
    registerMaintenanceTools(tools, viewModel);
    // The UMG designer and the material node graph.
    registerUmgTools(tools, viewModel, sessions);
    registerMaterialGraphTools(tools, viewModel, sessions);
    // The Animation Blueprint, Blend Space, Animation and
    // Skeletal Mesh editors, the Sequencer and the Particle editor.
    registerAnimBlueprintTools(tools, viewModel, sessions);
    registerBlendSpaceTools(tools, viewModel, sessions);
    registerAnimationTools(tools, viewModel, sessions);
    registerSkeletalMeshTools(tools, viewModel, sessions);
    registerSequencerTools(tools, viewModel, sessions, jobs);
    registerParticleTools(tools, viewModel, sessions);
    // The Landscape, Static Mesh, Texture, Physics Asset,
    // Sound, Enumeration and Blueprint Interface editors (assets only; the
    // environment mixer and navigation are level data).
    registerLandscapeTools(tools, viewModel, sessions);
    registerStaticMeshTools(tools, viewModel, sessions);
    registerTextureTools(tools, viewModel, sessions);
    registerPhysicsAssetTools(tools, viewModel, sessions);
    registerAudioTools(tools, viewModel, sessions);
    registerBlueprintTypeTools(tools, viewModel, sessions);
  }

  /// The shell's `RepaintBoundary` around the level viewport, and around the
  /// whole editor: what `viewport_screenshot` captures.
  ///
  /// One pair per editor view model, shared by every service over it: the
  /// shell mounts `viewModel.mcpServer`'s keys, and a service a test or a
  /// smoke constructs over the same view model must capture that same
  /// editor. Two editors (two view models) never share a `GlobalKey`.
  GlobalKey get viewportBoundaryKey => _boundaryKeysOf(viewModel).$1;
  GlobalKey get editorBoundaryKey => _boundaryKeysOf(viewModel).$2;

  static final Expando<(GlobalKey, GlobalKey)> _boundaryKeys = Expando('mcp_boundary_keys');

  /// The `RepaintBoundary` around sub-editor tab [tabId] in
  /// the shell, what `asset_editor_screenshot` captures; one per tab id and
  /// editor view model, like the two keys above.
  GlobalKey subEditorBoundaryKeyFor(String tabId) =>
      (_subEditorKeys[viewModel] ??= {})[tabId] ??= GlobalKey(debugLabel: 'mcp_sub_editor_boundary:$tabId');

  static final Expando<Map<String, GlobalKey>> _subEditorKeys = Expando('mcp_sub_editor_keys');

  static (GlobalKey, GlobalKey) _boundaryKeysOf(EditorViewModel vm) => _boundaryKeys[vm] ??= (
        GlobalKey(debugLabel: 'mcp_viewport_boundary'),
        GlobalKey(debugLabel: 'mcp_editor_boundary'),
      );

  final EditorViewModel viewModel;
  final McpServerSettings settings;
  final Directory? _configDir;
  final McpToolRegistry tools = McpToolRegistry();

  /// The long-running operations tools start and agents poll.
  final McpJobRegistry jobs = McpJobRegistry();

  /// The keys agents hold in Play, released when their session ends.
  late final McpPlayTesting playTesting = McpPlayTesting(viewModel);

  /// Every `tools/call` passes these in order; the first deny wins.
  /// Starts with the panel's risk ceiling.
  List<McpApprovalPolicy> get approvalPolicies => tools.approvalPolicies;

  /// The sub-editor view models the tools edit through.
  late final McpEditorSessions sessions = McpEditorSessions(viewModel);

  static const String connectionFileName = 'mcp_server.json';
  static const String path = '/mcp';

  /// The path of the stdio bridge, for the registration command the panel
  /// shows. Resolved from this package's location when the editor runs from
  /// its source tree (`flutter run`), else next to the executable.
  static String get bridgeScriptPath {
    final fromEnv = Platform.environment['LUMINA_EDITOR_ROOT'];
    final roots = <String>[
      if (fromEnv != null && fromEnv.isNotEmpty) fromEnv,
      LuminaEditorHost.uiRoot,
      File(Platform.resolvedExecutable).parent.path,
    ];
    for (final root in roots) {
      final candidate = File('$root/bin/lumina_mcp_bridge.dart');
      if (candidate.existsSync()) return candidate.absolute.path;
    }
    return '${LuminaEditorHost.uiRoot}/bin/lumina_mcp_bridge.dart';
  }

  /// The Dart executable external clients start the bridge with (MiniAI
  /// 05): `FLUTTER_ROOT`'s SDK, else the Flutter SDK this editor's own
  /// package config names, else the running `dart`, else `dart` on PATH.
  static String get dartExecutable {
    final exe = Platform.isWindows ? 'dart.exe' : 'dart';
    String? inSdk(String? flutterRoot) {
      if (flutterRoot == null || flutterRoot.isEmpty) return null;
      final f = File('$flutterRoot/bin/cache/dart-sdk/bin/$exe');
      return f.existsSync() ? f.absolute.path : null;
    }

    final fromEnv = inSdk(Platform.environment['FLUTTER_ROOT']);
    if (fromEnv != null) return fromEnv;
    for (final root in [LuminaEditorHost.uiRoot, File(Platform.resolvedExecutable).parent.path]) {
      final config = File('$root/.dart_tool/package_config.json');
      if (!config.existsSync()) continue;
      try {
        final flutterRoot = (jsonDecode(config.readAsStringSync()) as Map)['flutterRoot'];
        if (flutterRoot is String) {
          final found = inSdk(Uri.parse(flutterRoot).toFilePath());
          if (found != null) return found;
        }
      } on FormatException {
        // Try the next place.
      }
    }
    final running = Platform.resolvedExecutable;
    if (running.split(RegExp(r'[\\/]')).last.startsWith('dart')) return running;
    return 'dart';
  }

  /// How an external MCP client starts a connection to this editor: the
  /// stdio bridge, which reads [connectionFile] itself.
  McpClientLaunch get clientLaunch => McpClientLaunch(
        command: _native(dartExecutable),
        args: [_native(bridgeScriptPath)],
        url: url,
        environment: {LuminaConfigDir.environmentVariable: connectionFile.parent.path},
      );

  /// One separator style in paths other tools' config files show.
  static String _native(String path) => Platform.isWindows ? path.replaceAll('/', r'\') : path;

  HttpServer? _server;
  String _token = '';
  String? _lastError;
  final Map<String, McpSession> _sessions = {};

  /// The session of the attributed call running now (a tool handler asking
  /// for its own session's groups).
  McpSession? get _currentSession {
    final id = TransactionManager.currentOrigin?.sessionId;
    return id == null ? null : _sessions[id];
  }

  List<McpSession> get sessionList => List.unmodifiable(_sessions.values);
  final List<McpCallRecord> _recentCalls = [];
  int _requestCount = 0;

  bool get isRunning => _server != null;
  int? get port => _server?.port;
  String get token => _token;
  String? get lastError => _lastError;
  int get sessionCount => _sessions.length;
  int get requestCount => _requestCount;
  List<McpCallRecord> get recentCalls => List.unmodifiable(_recentCalls);

  /// True when the preferred port was taken and an ephemeral one is in use.
  bool get onFallbackPort => isRunning && port != settings.port;

  String? get url => isRunning ? 'http://127.0.0.1:$port$path' : null;

  File get connectionFile => LuminaConfigDir.file(connectionFileName, explicit: _configDir);

  /// `claude mcp add` for the HTTP transport, with this session's token.
  String? get httpRegistrationCommand => isRunning
      ? 'claude mcp add --transport http lumina $url --header "Authorization: Bearer $_token"'
      : null;

  /// `claude mcp add` for a stdio-only client: the bridge reads the
  /// connection file, so the command never changes.
  String get stdioRegistrationCommand => 'claude mcp add lumina -- dart $bridgeScriptPath';

  /// Binds the loopback address on [port] (default: the settings' port, then
  /// an ephemeral port when that one is taken) and writes the connection
  /// file. Returns whether the server is listening.
  Future<bool> start({int? port}) async {
    if (_disposed) return false;
    if (_server != null) return true;
    _lastError = null;
    final preferred = port ?? settings.port;
    HttpServer? server;
    try {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, preferred);
    } on SocketException catch (e) {
      if (preferred == 0) {
        _lastError = 'Could not bind 127.0.0.1: ${e.message}';
      } else {
        viewModel.logger.log(
          'MCP: port $preferred is taken (${e.message}); using an ephemeral port',
          level: 'warning',
          source: 'MCP',
        );
        try {
          server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        } on SocketException catch (e2) {
          _lastError = 'Could not bind 127.0.0.1: ${e2.message}';
        }
      }
    }
    if (_disposed) {
      // The editor closed while the socket was binding.
      await server?.close(force: true);
      return false;
    }
    if (server == null) {
      viewModel.logger.log('MCP server could not start: $_lastError', level: 'error', source: 'MCP');
      _notify();
      return false;
    }
    _server = server;
    _token = _mintToken();
    _sessions.clear();
    _dropStreams();
    server.listen(_handle, onError: (Object e) {
      _lastError = e.toString();
      _notify();
    });
    _writeConnectionFile();
    viewModel.logger.log(
      'MCP server listening on $url (loopback only, bearer token in ${connectionFile.path})',
      level: 'success',
      source: 'MCP',
    );
    _notify();
    return true;
  }

  Future<void> stop() async {
    final server = _server;
    if (server == null) return;
    _server = null;
    await server.close(force: true);
    _sessions.clear();
    _dropStreams();
    _deleteConnectionFile();
    _token = '';
    viewModel.logger.log('MCP server stopped', level: 'info', source: 'MCP');
    _notify();
  }

  /// Applies the settings' switch: starts when enabled, stops otherwise.
  Future<void> applySettings() async {
    if (settings.enabled) {
      if (!isRunning) await start();
    } else if (isRunning) {
      await stop();
    }
  }

  /// A new token; clients registered with the old one must re-register.
  void regenerateToken() {
    if (!isRunning) return;
    _token = _mintToken();
    _sessions.clear();
    _dropStreams();
    _writeConnectionFile();
    viewModel.logger.log('MCP bearer token regenerated', level: 'info', source: 'MCP');
    _notify();
  }

  bool _disposed = false;

  /// Listeners hear about state changes until [dispose]; an async tail (a
  /// stop, a start still binding, a request finishing) that runs after it
  /// changes nothing observable.
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    // Stop at once: the socket closes in the background, but the server no
    // longer counts as running and its connection file is gone now.
    final server = _server;
    _server = null;
    if (server != null) {
      unawaited(server.close(force: true));
      _sessions.clear();
      _dropStreams();
      _deleteConnectionFile();
      _token = '';
      viewModel.logger.log('MCP server stopped', level: 'info', source: 'MCP');
    }
    sessions.dispose();
    playTesting.dispose();
    jobs.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Connection file
  // ---------------------------------------------------------------------------

  static String _mintToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  Map<String, Object?> connectionInfo() => {
        'version': 1,
        'url': url,
        'port': port,
        'token': _token,
        'pid': pid,
        'project': viewModel.project.projectName,
        'projectDir': viewModel.projectDirPath,
        'startedAt': DateTime.now().toIso8601String(),
      };

  void _writeConnectionFile() {
    final file = connectionFile;
    try {
      file.parent.createSync(recursive: true);
      // Written empty first and restricted before the token lands in it, so
      // no other user ever reads a token, not even for a moment.
      file.writeAsStringSync('');
      _chmod600(file);
      file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(connectionInfo()));
    } catch (e) {
      _lastError = 'Could not write ${file.path}: $e';
      viewModel.logger.log(_lastError!, level: 'error', source: 'MCP');
    }
  }

  void _deleteConnectionFile() {
    try {
      final file = connectionFile;
      if (file.existsSync()) file.deleteSync();
    } catch (_) {}
  }

  static void _chmod600(File file) {
    if (Platform.isWindows) return;
    try {
      Process.runSync('chmod', ['600', file.path]);
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Server-to-client stream
  // ---------------------------------------------------------------------------

  /// The open `GET /mcp` streams, by session.
  final Map<String, HttpResponse> _streams = {};
  bool _listChangedHooked = false;

  int get openStreamCount => _streams.length;

  // ---------------------------------------------------------------------------
  // Resources
  // ---------------------------------------------------------------------------

  static const String projectResource = 'lumina://project';
  static const String outputLogResource = 'lumina://output-log';
  static const String selectionResource = 'lumina://selection';

  /// The Lumina engine guide the tool and the `lumina://guide` resources
  /// serve.
  final LuminaGuide guide = LuminaGuide();

  List<Map<String, Object?>> _resources() => [
        {
          'uri': projectResource,
          'name': 'project',
          'title': 'Project manifest',
          'description': 'The open project\'s .lmproject manifest as JSON.',
          'mimeType': 'application/json',
        },
        {
          'uri': outputLogResource,
          'name': 'output-log',
          'title': 'Output Log',
          'description': 'The last 500 lines of the editor\'s Output Log.',
          'mimeType': 'text/plain',
        },
        {
          'uri': selectionResource,
          'name': 'selection',
          'title': 'Current selection',
          'description': 'What the user has selected now (level actors, Content Browser assets, the active tab), '
              'as get_selection returns it with its defaults.',
          'mimeType': 'application/json',
        },
        {
          'uri': LuminaGuide.resource,
          'name': 'guide',
          'title': 'Lumina engine guide',
          'description': 'How the Lumina engine works, for AI models: the overview and the topic list '
              '(as get_lumina_guide returns it).',
          'mimeType': 'text/markdown',
        },
        for (final t in LuminaGuide.topics)
          {
            'uri': LuminaGuide.resourceOf(t.id),
            'name': 'guide-${t.id}',
            'title': 'Lumina guide: ${t.title}',
            'description': 'The "${t.id}" topic of the Lumina engine guide.',
            'mimeType': 'text/markdown',
          },
      ];

  Future<Map<String, Object?>> _readResource(Map<String, Object?> params) async {
    final uri = params['uri'];
    Map<String, Object?> markdown(String text) => {
          'contents': [
            {'uri': uri, 'mimeType': 'text/markdown', 'text': text},
          ],
        };
    if (uri == LuminaGuide.resource) return markdown(await guide.overview());
    if (uri is String && uri.startsWith('${LuminaGuide.resource}/')) {
      final topic = uri.substring(LuminaGuide.resource.length + 1);
      if (!LuminaGuide.topicIds.contains(topic)) {
        throw JsonRpcException(JsonRpcErrorCode.invalidParams,
            'Unknown guide topic "$topic"; topics: ${LuminaGuide.topics.map((t) => t.id).join(', ')}.');
      }
      return markdown(await guide.topic(topic));
    }
    switch (uri) {
      case projectResource:
        return {
          'contents': [
            {
              'uri': projectResource,
              'mimeType': 'application/json',
              'text': const JsonEncoder.withIndent('  ').convert(viewModel.project.toMap()),
            },
          ],
        };
      case outputLogResource:
        final logs = viewModel.logs;
        final tail = logs.length > 500 ? logs.sublist(logs.length - 500) : logs;
        return {
          'contents': [
            {
              'uri': outputLogResource,
              'mimeType': 'text/plain',
              'text': tail.map((e) => '[${e.timestamp}] [${e.level}] [${e.source}] ${e.message}').join('\n'),
            },
          ],
        };
      case selectionResource:
        return {
          'contents': [
            {
              'uri': selectionResource,
              'mimeType': 'application/json',
              'text': const JsonEncoder.withIndent('  ').convert(mcpSelectionSnapshot(viewModel)),
            },
          ],
        };
      default:
        throw JsonRpcException(JsonRpcErrorCode.invalidParams, 'Unknown resource "$uri"; call resources/list.');
    }
  }
}

/// An HTTP-level refusal (the spec's 400 / 404 for session problems).
class _HttpFailure implements Exception {
  final int status;
  final String message;
  const _HttpFailure(this.status, this.message);
}

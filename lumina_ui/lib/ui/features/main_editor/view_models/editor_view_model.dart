import 'package:lumina_ui/ui/core/built_in_editor_plugin.dart';
import 'package:lumina_ui/ui/core/host/editor_host.dart';
import 'package:lumina_ui/ui/core/plugin_extension_registry.dart';
import 'package:lumina_ui/ui/core/editor_level_access.dart';
import 'package:lumina_ui/ui/core/services/content_folders.dart';
import 'package:lumina_ui/ui/core/services/user_plugin_dir.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/level_blueprint_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/umg_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/material_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_editor_nodes.dart';
import 'package:flutter/scheduler.dart' show SchedulerBinding;
import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_layout_state.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_panels_controller.dart';
import 'dart:io';
import 'package:path/path.dart' as p;

import 'dart:math' as math;
import 'dart:typed_data';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_ui/ui/features/details/models/component_property_registry.dart';
import 'package:lumina_ui/ui/features/details/models/editor_component_node.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina_ui/ui/features/main_editor/views/new_level_dialog.dart';
import 'package:lumina_ui/ui/features/main_editor/views/about_dialog.dart';
import 'package:lumina_ui/ui/features/main_editor/views/ai_agent_files_dialog.dart';
import 'package:lumina_ui/ui/features/main_editor/views/import_asset_folder_dialog.dart';

import 'package:lumina_ui/ui/features/main_editor/models/editor_actor_catalog.dart';
import 'package:lumina_ui/ui/features/main_editor/services/viewport_picker.dart';
import 'package:lumina_ui/ui/features/main_editor/services/editor_preferences.dart';
import 'package:lumina_ui/ui/features/main_editor/services/project_trash.dart';
import 'package:lumina_ui/ui/features/main_editor/services/camera_actor_properties.dart';
import 'package:lumina_ui/ui/features/main_editor/services/light_actor_properties.dart';
import 'package:lumina_ui/ui/features/main_editor/services/editor_camera_store.dart';
import 'package:lumina_ui/ui/features/main_editor/services/editor_quality_settings.dart';
import 'package:lumina_ui/ui/features/main_editor/services/editor_level_scene.dart';
import 'package:lumina_ui/ui/features/main_editor/commands/editor_command.dart';
import 'package:lumina_ui/ui/features/main_editor/commands/editor_transaction.dart';
import 'package:lumina_ui/ui/features/main_editor/services/pie_controller.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/umg_widget_codegen.dart';
import 'package:lumina_ui/ui/features/main_editor/services/blueprint_play_support.dart';
import 'package:lumina_ui/ui/features/main_editor/services/project_blueprint_functions.dart';
import 'package:lumina_ui/ui/features/main_editor/services/standalone_game_runner.dart';
import 'package:lumina_ui/ui/features/main_editor/services/android_device_runner.dart';
import 'package:lumina_ui/ui/features/main_editor/services/android_devices.dart';
import 'package:lumina_ui/ui/features/main_editor/services/android_sdk.dart';
import 'package:lumina_ui/ui/features/main_editor/services/widget_blueprint_assets.dart';
import 'package:lumina_ui/ui/features/main_editor/services/asset_editor_category.dart';
import 'package:lumina_ui/ui/features/plugin_manager/view_models/plugin_manager_view_model.dart';
import 'package:lumina_ui/ui/features/plugin_manager/views/new_plugin_wizard.dart';
import 'package:lumina_ui/ui/features/source_control/source_control_commands.dart';
import 'package:lumina_ui/ui/features/source_control/view_models/source_control_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/build_pipeline_service.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/build_manager_view_model.dart';
import 'package:lumina_ui/ui/core/services/crash_reporter.dart';
import 'package:lumina_ui/ui/core/services/plugin_process/plugin_isolation_overrides.dart';
import 'package:lumina_ui/ui/core/services/plugin_process/plugin_process_manager.dart';
import 'package:lumina_ui/ui/core/services/editor_scene_environment.dart';
import 'package:lumina_ui/ui/core/window/lumina_window.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_server_service.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/host_editor_mcp.dart';
import 'package:lumina_ui/ui/features/marketplace/view_models/marketplace_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/import_jobs_view_model.dart';

part 'editor_view_model/state.dart';
part 'editor_view_model/project_and_levels.dart';
part 'editor_view_model/level_sections.dart';
part 'editor_view_model/actors_and_components.dart';
part 'editor_view_model/actor_spawning.dart';
part 'editor_view_model/outliner.dart';
part 'editor_view_model/selection_and_transforms.dart';
part 'editor_view_model/camera_and_viewport.dart';
part 'editor_view_model/assets_and_content_browser.dart';
part 'editor_view_model/thumbnails.dart';
part 'editor_view_model/import.dart';
part 'editor_view_model/sub_editor_tabs.dart';
part 'editor_view_model/blueprints_and_level_blueprints.dart';
part 'editor_view_model/play_in_editor.dart';
part 'editor_view_model/codegen_and_save.dart';
part 'editor_view_model/commands.dart';
part 'editor_view_model/dialogs.dart';
part 'editor_view_model/plugins.dart';
part 'editor_view_model/plugin_extensions.dart';
part 'editor_view_model/marketplace.dart';
part 'editor_view_model/trash.dart';

/// A live binding between an open sub-editor tab and its view model.
class EditorTabSession {
  final Listenable notifier;
  final Future<bool> Function() save;
  final bool Function() isDirty;
  final VoidCallback onChanged;
  const EditorTabSession({
    required this.notifier,
    required this.save,
    required this.isDirty,
    required this.onChanged,
  });
}

class EditorTabInfo {
  final String id;
  final String title;
  final String category;
  final RealAssetInfo? asset;
  bool isDirty;

  EditorTabInfo({
    required this.id,
    required this.title,
    required this.category,
    this.asset,
    this.isDirty = false,
  });
}

class EditorActorNode {
  final String id;
  String name;
  final String type;
  String? parentId;

  /// Stored transform, as the Details panel shows it: centimetres, **Z up**.
  /// The runtime is
  /// Y up; convert only through lumina's `LuminaAxes` (`EditorTransforms`).
  List<double> location;

  /// Degrees about the stored X, Y and Z axes (see [location]).
  List<double> rotation;

  /// Per stored axis (see [location]).
  List<double> scale;
  bool isVisible;
  bool isLocked;
  String mobility;
  double lightIntensity;
  bool castShadows;
  String lightColorHex;
  String? materialPath;
  final Uint8List? thumbnailBytes;
  GlbMeshData? meshData;

  /// Absolute path of the mesh file (.lmas/.glb/.obj) this actor renders,
  /// resolved from the project's contents/ tree. Null for non-mesh actors.
  String? meshAssetPath;
  List<EditorComponentNode> components = [];

  /// A placed Blueprint's class: its project-relative `.lmas` path
  /// (lumina reads it from `metadata.actors[].blueprintClass`). Null for other actors.
  String? blueprintClass;

  /// How the viewport draws a placed Blueprint (its first mesh component's
  /// offset, a Character's capsule); not saved, read from the class.
  BlueprintActorPreview? blueprintPreview;

  EditorActorNode({
    required this.id,
    required this.name,
    required this.type,
    this.parentId,
    required this.location,
    List<double>? rotation,
    List<double>? scale,
    this.isVisible = true,
    this.isLocked = false,
    this.mobility = 'Movable',
    this.lightIntensity = 5000.0,
    this.castShadows = true,
    this.lightColorHex = '#FFF2A3',
    this.materialPath,
    this.thumbnailBytes,
    this.meshData,
    this.meshAssetPath,
    this.blueprintClass,
    List<EditorComponentNode>? components,
  }) : rotation = rotation ?? [0.0, 0.0, 0.0],
       scale = scale ?? [1.0, 1.0, 1.0],
       components = components ?? [];

  /// A copy of every field, for Duplicate and the undo snapshots:
  /// the class, the mesh it draws and its components (their properties
  /// deep-copied). Under a new [id], a component id made from this actor's id
  /// is remade from [id] (any other gets [id] as a prefix), so the copy's
  /// components never share the original's ids.
  EditorActorNode copy({String? id, String? name}) {
    final newId = id ?? this.id;
    String componentId(String c) {
      if (newId == this.id) return c;
      return c.startsWith('${this.id}_') ? '$newId${c.substring(this.id.length)}' : '${newId}_$c';
    }

    return EditorActorNode(
      id: newId,
      name: name ?? this.name,
      type: type,
      parentId: parentId,
      location: List.of(location),
      rotation: List.of(rotation),
      scale: List.of(scale),
      isVisible: isVisible,
      isLocked: isLocked,
      mobility: mobility,
      lightIntensity: lightIntensity,
      castShadows: castShadows,
      lightColorHex: lightColorHex,
      materialPath: materialPath,
      thumbnailBytes: thumbnailBytes,
      meshData: meshData,
      meshAssetPath: meshAssetPath,
      components: [for (final c in components) c.copy(id: componentId(c.id))],
    )
      ..blueprintClass = blueprintClass
      ..blueprintPreview = blueprintPreview;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'parentId': parentId,
      'location': location,
      'rotation': rotation,
      'scale': scale,
      'isVisible': isVisible,
      'isLocked': isLocked,
      'mobility': mobility,
      'lightIntensity': lightIntensity,
      'castShadows': castShadows,
      'lightColorHex': lightColorHex,
      'materialPath': materialPath,
      'meshAssetPath': meshAssetPath,
      'components': components.map((c) => c.toMap()).toList(),
      if (blueprintClass != null) 'blueprintClass': blueprintClass,
    };
  }

  factory EditorActorNode.fromMap(Map<String, dynamic> map) {
    final node = EditorActorNode(
      id: map['id'] as String? ?? 'act_0',
      name: map['name'] as String? ?? 'Actor',
      type: map['type'] as String? ?? 'Mesh',
      parentId: map['parentId'] as String?,
      location: List<double>.from(
        (map['location'] as List? ?? [0.0, 0.0, 0.0]).map(
          (e) => (e as num).toDouble(),
        ),
      ),
      rotation: List<double>.from(
        (map['rotation'] as List? ?? [0.0, 0.0, 0.0]).map(
          (e) => (e as num).toDouble(),
        ),
      ),
      scale: List<double>.from(
        (map['scale'] as List? ?? [1.0, 1.0, 1.0]).map(
          (e) => (e as num).toDouble(),
        ),
      ),
      isVisible: map['isVisible'] as bool? ?? true,
      isLocked: map['isLocked'] as bool? ?? false,
      mobility: map['mobility'] as String? ?? 'Movable',
      lightIntensity: (map['lightIntensity'] as num?)?.toDouble() ?? 5000.0,
      castShadows: map['castShadows'] as bool? ?? true,
      lightColorHex: map['lightColorHex'] as String? ?? '#FFF2A3',
      materialPath: map['materialPath'] as String?,
      meshAssetPath: map['meshAssetPath'] as String?,
      components: map['components'] != null
          ? (map['components'] as List)
                .map((c) => EditorComponentNode.fromMap(c))
                .toList()
          : [],
    );
    node.blueprintClass = map['blueprintClass'] as String?;

    if (map['components'] == null) {
      if (node.type == 'DirectionalLight' ||
          node.type == 'PointLight' ||
          node.type == 'SpotLight') {
        node.components.add(
          EditorComponentNode(
            id: '${node.id}_light',
            type: 'LuminaLightComponent',
            name: 'Light Component',
            properties: {
              'lightIntensity': node.lightIntensity,
              'castShadows': node.castShadows,
              'lightColorHex': node.lightColorHex,
            },
          ),
        );
      } else if (node.type == 'StaticMesh' || node.type == 'SkeletalMesh') {
        node.components.add(
          EditorComponentNode(
            id: '${node.id}_mesh',
            type: node.type == 'StaticMesh'
                ? 'LuminaMeshComponent'
                : 'LuminaSkeletalMeshComponent',
            name: 'Mesh Component',
            properties: {},
          ),
        );
      } else if (EditorSceneEnvironment.isEnvironmentActor(node.type)) {
        node.components.add(
          EditorSceneEnvironment.seedSkyComponent(node.id),
        );
      }
    } else if (EditorSceneEnvironment.isEnvironmentActor(node.type) &&
        !node.components.any((c) => c.type == EditorSceneEnvironment.skyComponentType)) {
      node.components.add(
        EditorSceneEnvironment.seedSkyComponent(node.id),
      );
    }

    return node;
  }
}

class EditorViewModel extends _EditorViewModelState
    with
        _EditorProjectAndLevels,
        _EditorLevelSections,
        _EditorActorsAndComponents,
        _EditorActorSpawning,
        _EditorOutliner,
        _EditorSelectionAndTransforms,
        _EditorCameraAndViewport,
        _EditorAssetsAndContentBrowser,
        _EditorThumbnails,
        _EditorImport,
        _EditorSubEditorTabs,
        _EditorBlueprintsAndLevelBlueprints,
        _EditorPlayInEditor,
        _EditorCodegenAndSave,
        _EditorCommands,
        _EditorDialogs,
        _EditorPlugins,
        _EditorPluginExtensions,
        _EditorMarketplace,
        _EditorTrash {
  // Main Workspace Tab Architecture
  ///
  /// The first tab is the level workspace. Its title used to be the literal
  /// string `L_OpenWorld_Main`, so the breadcrumb named a level the project did
  /// not have; it now follows whichever level is open.
  static const String kLevelTabId = 'main_level';

  /// Where Marketplace asset listings install: the
  /// Content Browser's Marketplace smart view lists what is under it.
  static const String marketplaceFolder = 'contents/Marketplace';

  /// The Marketplace window's tab category (Window → Marketplace).
  static const String marketplaceCategory = 'marketplace';

  // --- Level Blueprints ---

  /// The tab category of a Level Blueprint editor.
  static const String levelBlueprintCategory = 'LevelBlueprint';

  /// The tab of [levelPath]'s Level Blueprint: one per level.
  static String levelBlueprintTabId(String levelPath) => 'level_blueprint:$levelPath';

  /// The tab title: `L_DefaultLevel (Level Blueprint)`.
  static String levelBlueprintTabTitle(String levelPath) =>
      '${levelPath.split('/').last.replaceAll('.lmas', '')} (Level Blueprint)';

  /// Formats a triangle count as 1.2K / 3.4M for the viewport stats strip.
  static String formatTriangleCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  /// The actors a brand-new level starts with. This is the on-disk starter
  /// template written into a level's `.lmas` the first time it is created
  /// (or the first time a legacy level file without an `actors` list is
  /// opened); it is never injected into a session from memory.
  ///
  /// The list itself lives in the shared [GameTemplateCatalog] as the Blank 3D
  /// template's actor set, so the launcher's scaffolder and the editor's lazy
  /// seeding cannot drift apart.
  static List<EditorActorNode> starterLevelActors() => GameTemplateCatalog.byId(
    kBlank3dTemplateId,
  ).levelActors.map(EditorActorNode.fromMap).toList();

  /// The outliner actor type an asset dropped into the level becomes.
  ///
  /// Public so the landscape placement tests can assert it directly: a
  /// `LANDSCAPE` `.lmas` must become a `Landscape` actor, not an untyped
  /// `Mesh` with no geometry.
  static String actorTypeNameForAssetType(AssetType type) =>
      EditorViewModel._categoryNameFromAssetType(type);

  static String _categoryNameFromAssetType(AssetType type) {
    switch (type) {
      case AssetType.filamesh:
        return 'Mesh';
      case AssetType.filamat:
        return 'Material';
      case AssetType.texture:
        return 'Texture';
      case AssetType.actor:
        return 'Pawn';
      case AssetType.audio:
        return 'Audio';
      case AssetType.level:
        return 'Level';
      case AssetType.landscape:
        return 'Landscape';
      default:
        return 'Mesh';
    }
  }

  @override
  late final PieController pieController = PieController(this);

  EditorViewModel({
    super.initialProject,
    super.projectDirPath,
    super.projectLocation,
    bool enableTimers = true,
    bool autoInitAssets = true,
    super.qualityStore,
    super.cameraStore,
    super.thumbnailService,
    super.autoGenerateThumbnails,
  }) : super(enableTimers: enableTimers) {
    // Crash reports name the open project (its folder name only).
    CrashReporter.instance?.projectName = p.basename(projectDirPath);
    commands = EditorCommandRegistry(
      onCommandExecuted: (id) {
        _logger.log(
          'Executed command: $id',
          level: 'info',
          source: 'EditorCommandRegistry',
        );
      },
    );
    extensionRegistry = PluginExtensionRegistry(logger: _logger);
    // The saved layout is in place before any plugin registers: a plugin
    // may read or change its panels' visibility in `register()`.
    _loadLayoutState();
    // Plugins reach the open level through the registry.
    extensionRegistry.attachLevel(EditorViewModelLevelAccess(this));
    // Plugins open, close and observe their panels.
    extensionRegistry.attachPanels(panelsController);
    // Plugins open workspace tabs.
    extensionRegistry.attachTabOpener((id, {title}) => openSubEditorTab(id, title: title));
    // Plugins save assets, refresh Content Browser and generate thumbnails.
    extensionRegistry.attachAssetSaver(({
      required String relativePath,
      Uint8List? bytes,
      bool generateThumbnail = true,
    }) async {
      final normRel = p.normalize(relativePath).replaceAll('\\', '/');
      final fullPath = p.normalize(p.join(projectDirPath, normRel));
      if (bytes != null) {
        final file = File(fullPath);
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes, flush: true);
      }
      _refreshAssets();
      if (generateThumbnail && File(fullPath).existsSync()) {
        enqueueThumbnail(fullPath, force: true);
      }
    });
    // Plugins access the project's assets for the asset picker.
    extensionRegistry.attachAssetsProvider(() => realAssets);
    // Per-plugin storage, the project each plugin is told about,
    // and plugin shutdown before a hand-off exits the process.
    extensionRegistry.attachStorage(dataRoot: PluginDataDir.resolve, projectDir: () => projectDirPath);
    // Plugins read their applied `plugin_settings`.
    extensionRegistry.publishPluginSettings(_project.pluginSettings);
    extensionRegistry.onPluginRegistered = _pluginRegistered;
    // Isolated plugins: one supervised process each (their channels exist
    // before their shells register).
    extensionRegistry.attachProjectInfo(() => EditorProjectInfo(name: project.projectName, dir: projectDirPath));
    extensionRegistry.attachProcesses(pluginProcesses);
    EditorHandOff.beforeExit.add(_shutdownPluginsForExit);
    // Plugin MCP tools and in-process calls, on the server's
    // registry (created when a plugin first uses it).
    extensionRegistry.attachMcp(() => HostEditorMcp(mcpServer.tools,
        log: (message) => _logger.log(message, level: 'error', source: 'PluginRegistry'),
        // External agents start the stdio bridge.
        launch: () => mcpServer.clientLaunch));
    addListener(panelsController.refresh);
    BuiltInEditorPlugin(this).register(extensionRegistry);
    // A Window-menu command per plugin panel, kept in step.
    extensionRegistry.addListener(_syncPluginPanelCommands);
    // The code plugins compiled into this binary (a project
    // editor host's registrar; none in the stock editor). One that fails is
    // logged and left out; the rest still register.
    for (final plugin in LuminaEditorHost.plugins) {
      if (extensionRegistry.registerPlugin(plugin)) {
        _logger.log('Registered code plugin ${plugin.pluginName}', level: 'info', source: 'Plugins');
      }
    }
    // The isolated plugins' processes start after the shells registered.
    if (pluginProcesses.pluginNames.isNotEmpty) unawaited(pluginProcesses.startAll());
    sourceControl = SourceControlViewModel(
      projectRoot: projectDirPath,
      logger: _logger,
      onFileRestored: _onSourceControlFileRestored,
    );
    sourceControl.addListener(() {
      if (!_disposed) notifyListeners();
    });
    _initCommands();
    commands.addListener(notifyListeners);

    ProjectRepository.ensurePubspecAssets(projectDirPath);

    // Log lines can arrive synchronously from inside a widget's initState /
    // build (sub-editors log while loading). Coalesce and defer the
    // notification to a microtask so listeners never call setState during build.
    _logSub = _logger.logStream.listen((_) {
      if (_logNotifyScheduled) return;
      _logNotifyScheduled = true;
      scheduleMicrotask(() {
        _logNotifyScheduled = false;
        if (!_disposed) notifyListeners();
      });
    });

    _assetsChangedSub = AssetRepository.onAssetsChanged.listen((_) {
      if (!_disposed) {
        _refreshAssets();
      }
    });

    if (enableTimers) {
      _autoSaveTimer = AutoSaveTimerService(
        onPerformSave: _autoSaveAndGenerateCode,
      );
      _autoSaveTimer?.start(_project);
      // The palette knows the project's exposed
      // functions from the start, and follows edits to them.
      unawaited(blueprintFunctions.open());
    }

    _logger.log(
      'Editor session initialized for ${_project.projectName}',
      level: 'info',
      source: 'EditorViewModel',
    );

    // Load collections on startup
    loadCollections();
    _scanPlugins();

    if (autoInitAssets) {
      _ensureDefaultLevelAssets();
    } else {
      _refreshAssets();
    }
  }

  @override
  EditorViewModel get _self => this;

  McpServerService get mcpServer => _mcpServer ??= McpServerService(this);

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
      // An open Level Blueprint follows the outliner.
      _levelBlueprintEditors[_project.activeLevel]?.levelActorsChanged();
    }
  }

  /// Disposes the session and completes once nothing it started still uses
  /// the project folder: a source-control git probe runs with the
  /// folder as its working directory, and Windows refuses to delete a folder
  /// a live process works in. Await it before deleting or moving a project.
  Future<void> close() async {
    // The project is closing; plugins finish their writes.
    await shutdownPlugins(exiting: false);
    final pending = sourceControl.idle;
    dispose();
    await pending;
  }

  @override
  void dispose() {
    _cameraSaveTimer?.cancel();
    EditorHandOff.beforeExit.remove(_shutdownPluginsForExit);
    unawaited(pluginProcesses.shutdownAll());
    removeListener(panelsController.refresh);
    panelsController.dispose();
    _frameStatsRevision.dispose();
    _disposed = true;
    _buildManagerVm?.dispose();
    sourceControl.dispose();
    for (final session in _tabSessions.values) {
      session.notifier.removeListener(session.onChanged);
    }
    _tabSessions.clear();
    for (final vm in _levelBlueprintEditors.values) {
      vm.dispose();
    }
    _levelBlueprintEditors.clear();
    _isDisposed = true;
    _logSub?.cancel();
    _assetsChangedSub?.cancel();

    _autoSaveTimer?.stop();
    blueprintFunctions.dispose();
    standalone.dispose();
    _androidRunner?.dispose();
    _androidDevices?.dispose();
    _mcpServer?.dispose();
    _disposeMarketplace();
    _importJobs?.dispose();
    _importQueue?.dispose();
    for (final waiters in _thumbnailWaiters.values) {
      for (final w in waiters) {
        if (!w.isCompleted) w.complete();
      }
    }
    _thumbnailWaiters.clear();
    super.dispose();
  }
}

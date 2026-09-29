import 'dart:io';

import 'package:lumina_editor_api/lumina_editor_api.dart' show kAssetPathMetadataKey;
import 'package:lumina_ui/ui/core/plugin_extension_registry.dart';
import 'package:lumina_ui/ui/features/plugin_manager/view_models/plugin_manager_view_model.dart';
import 'package:lumina_ui/ui/features/plugin_manager/views/plugin_manager_view.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/level_blueprint_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/material_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/environment_lighting_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/navigation_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/project_settings_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/umg_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/anim_blueprint_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/animation_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blend_space_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/particle_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/sequencer_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/skeletal_mesh_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/audio_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_enum_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_interface_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/landscape_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/physics_asset_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/static_mesh_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/texture_editor_view_model.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina/lumina.dart';
import 'material/material_sub_editor.dart';
import 'blueprint/blueprint_sub_editor.dart';
import 'blueprint_enum/enum_sub_editor.dart';
import 'blueprint_interface/interface_sub_editor.dart';
import '../models/sub_editor_transform_gizmo.dart';
import 'anim_blueprint/anim_blueprint_sub_editor.dart';
import 'blend_space/blend_space_sub_editor.dart';
import 'static_mesh_sub_editor.dart';
import 'skeletal_mesh/skeletal_mesh_sub_editor.dart';
import 'animation_sub_editor.dart';
import 'texture_sub_editor.dart';
import 'particle/particle_sub_editor.dart';
import 'audio_sub_editor.dart';
import 'landscape/foliage_sub_editor.dart';
import 'physics_asset_sub_editor.dart';
import 'sequencer/sequencer_sub_editor.dart';
import 'umg/widget_sub_editor.dart';
import 'project_settings_sub_editor.dart';
import 'editor_preferences_sub_editor.dart';
import '../../mcp_server/views/mcp_server_panel.dart';
import '../../marketplace/views/marketplace_view.dart';
import '../../main_editor/services/editor_preferences.dart';
import 'environment_lighting_sub_editor.dart';
import 'navigation_sub_editor.dart';
import 'build_manager_sub_editor.dart';

export 'material/material_sub_editor.dart';
export 'material/material.dart';
export 'blueprint/blueprint_sub_editor.dart';
export 'blueprint/blueprint.dart';
export 'blueprint_enum/blueprint_enum.dart';
export 'blueprint_interface/blueprint_interface.dart';
export 'anim_blueprint/anim_blueprint.dart';
export 'blend_space/blend_space.dart';
export 'static_mesh_sub_editor.dart';
export 'skeletal_mesh/skeletal_mesh_sub_editor.dart';
export 'skeletal_mesh/skeletal_mesh.dart';
export 'animation_sub_editor.dart';
export 'texture_sub_editor.dart';
export 'particle/particle_sub_editor.dart';
export 'particle/particle.dart';
export 'audio_sub_editor.dart';
export 'landscape/foliage_sub_editor.dart';
export 'landscape/landscape.dart';
export 'physics_asset_sub_editor.dart';
export 'sequencer/sequencer_sub_editor.dart';
export 'sequencer/sequencer.dart';
export 'umg/widget_sub_editor.dart';
export 'umg/umg.dart';
export 'project_settings_sub_editor.dart';
export 'environment_lighting_sub_editor.dart';
export 'navigation_sub_editor.dart';
export 'build_manager_sub_editor.dart';

/// Main Dispatcher Widget for rendering full-page Sub-Editor Workspaces in tabs or dialogs
class SubEditorWorkspaceWidget extends StatefulWidget {
  final String assetType;
  final String assetName;
  final RealAssetInfo? asset;
  final VoidCallback? onClose;
  final EditorViewModel? editorViewModel;

  /// Id of the hosting workspace tab; when set together with
  /// [editorViewModel], the sub-editor's view model is bound to the tab so
  /// the shell can save it on close.
  final String? tabId;

  const SubEditorWorkspaceWidget({
    super.key,
    required this.assetType,
    required this.assetName,
    this.asset,
    this.onClose,
    this.tabId,
    this.editorViewModel,
  });

  @override
  State<SubEditorWorkspaceWidget> createState() => _SubEditorWorkspaceWidgetState();
}

/// What a tab's sub-editor has to do with the tab's session: the
/// view model it was handed ([adopted], bound by MCP or the editor) and the
/// one it created and bound itself ([created]), which dies with the widget.
class _TabBindings {
  Listenable? adopted;
  Listenable? created;

  /// The Plugins tab's view model, kept across rebuilds so its selection and
  /// a pending import survive the editor's notifications.
  PluginManagerViewModel? pluginManager;
}

class _SubEditorWorkspaceWidgetState extends State<SubEditorWorkspaceWidget> {
  final _TabBindings _bindings = _TabBindings();

  @override
  void dispose() {
    // The sub-editor disposed the view model it created (children go
    // first): take it off the tab, or a remounted editor and the MCP tools
    // would adopt a disposed view model. One the tab adopted stays with its
    // owner.
    final id = widget.tabId;
    final editor = widget.editorViewModel;
    final own = _bindings.created;
    if (id != null && editor != null && own != null && identical(editor.editorSessionFor(id), own)) {
      editor.unbindTabSession(id);
    }
    _bindings.pluginManager?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _SubEditorDispatcher(
        assetType: widget.assetType,
        assetName: widget.assetName,
        asset: widget.asset,
        onClose: widget.onClose,
        tabId: widget.tabId,
        editorViewModel: widget.editorViewModel,
        bindings: _bindings,
      );
}

class _SubEditorDispatcher extends StatelessWidget {
  final String assetType;
  final String assetName;
  final RealAssetInfo? asset;
  final VoidCallback? onClose;
  final EditorViewModel? editorViewModel;
  final String? tabId;
  final _TabBindings bindings;

  const _SubEditorDispatcher({
    required this.assetType,
    required this.assetName,
    required this.asset,
    required this.onClose,
    required this.tabId,
    required this.editorViewModel,
    required this.bindings,
  });

  /// A view model already bound to this tab (an MCP tool opened the asset
  /// before the widget mounted), when it is a [T].
  T? _existingSession<T extends Listenable>() {
    final id = tabId;
    if (id == null || editorViewModel == null) return null;
    final session = editorViewModel!.editorSessionFor(id);
    if (session is! T) return null;
    // Rebuilds hand the editor its own view model back; only another
    // owner's is adopted.
    if (!identical(session, bindings.created)) bindings.adopted = session;
    return session;
  }

  void _bind(Listenable notifier, Future<bool> Function() save, bool Function() isDirty) {
    final id = tabId;
    if (id == null || editorViewModel == null) return;
    if (!identical(notifier, bindings.adopted)) bindings.created = notifier;
    editorViewModel!.bindTabSession(id, notifier: notifier, save: save, isDirty: isDirty);
  }

  @override
  Widget build(BuildContext context) {
    // A plugin asset type's own editor (its
    // registerAssetType.editorFactory), by its customTypeId.
    if (assetType.startsWith(PluginExtensionRegistry.pluginAssetCategoryPrefix)) {
      return _buildPluginAssetEditor(context, assetType.substring(PluginExtensionRegistry.pluginAssetCategoryPrefix.length));
    }
    switch (assetType) {
      case 'plugins':
        if (editorViewModel == null) return const Center(child: Text('Missing EditorViewModel'));
        final cached = bindings.pluginManager;
        if (cached != null && identical(cached.registryService, editorViewModel!.pluginRegistry)) {
          cached
            ..folderPicker = editorViewModel!.pluginFolderPicker
            ..zipPicker = editorViewModel!.pluginZipPicker;
          return PluginManagerView(viewModel: cached);
        }
        cached?.dispose();
        final vm = bindings.pluginManager = PluginManagerViewModel(
          registryService: editorViewModel!.pluginRegistry,
          onSetEnabled: (name, enabled, {cascade = false}) =>
              editorViewModel!.enablePlugin(name, enabled, cascade: cascade),
          // An import rescans every plugin root, as a Marketplace install does.
          onPluginsChanged: editorViewModel!.rescanPlugins,
          folderPicker: editorViewModel!.pluginFolderPicker,
          zipPicker: editorViewModel!.pluginZipPicker,
        );
        return PluginManagerView(viewModel: vm);
      case 'Material':
      case 'FILAMAT':
      case 'Material Editor':
        return MaterialSubEditor(
          assetName: assetName,
          assetPath: asset?.lmasPath ?? asset?.relativePath,
          viewModel: _existingSession<MaterialEditorViewModel>(),
          onBind: _bind,
          onClose: onClose,
        );
      case 'Blueprint':
      case 'ACTOR':
      case 'BLUEPRINT':
      case 'Blueprint Editor':
        return BlueprintSubEditor(
          assetName: assetName,
          assetPath: asset?.lmasPath ?? (editorViewModel != null ? '${editorViewModel!.projectDirPath}/contents/blueprints/$assetName.lmas' : asset?.relativePath),
          viewModel: _existingSession<BlueprintEditorViewModel>(),
          gizmoDefaults: editorViewModel == null
              ? null
              : BlueprintGizmoDefaults(
                  mode: SubEditorTransformGizmo.modeForTool(editorViewModel!.activeTool),
                  space: editorViewModel!.gizmoSpace == 'local' ? GizmoSpace.local : GizmoSpace.world,
                  snap: TransformGizmoSnap(
                    translateEnabled: editorViewModel!.translateSnapEnabled,
                    rotateEnabled: editorViewModel!.rotateSnapEnabled,
                    scaleEnabled: editorViewModel!.scaleSnapEnabled,
                    translateStep: editorViewModel!.translateSnapStep,
                    rotateStep: editorViewModel!.rotateSnapStep,
                    scaleStep: editorViewModel!.scaleSnapStep,
                  ),
                ),
          onBind: _bind, onClose: onClose,
        );
      case EditorViewModel.levelBlueprintCategory:
        // The level's Blueprint, in the Blueprint editor
        // configured for a level; the view model is the editor's (it follows
        // the outliner's actors and survives the tab widget).
        final levelVm = _existingSession<LevelBlueprintEditorViewModel>();
        if (levelVm == null) return const Center(child: Text('The Level Blueprint is not open'));
        return BlueprintSubEditor(
          assetName: levelVm.levelName,
          assetPath: levelVm.assetPath,
          viewModel: levelVm,
          onClose: onClose,
        );
      case 'BlueprintEnum':
        return BlueprintEnumSubEditor(
          assetName: assetName,
          assetPath: asset?.lmasPath ?? asset?.relativePath ?? '',
          viewModel: _existingSession<BlueprintEnumViewModel>(),
          onBind: _bind,
          onClose: onClose,
        );
      case 'BlueprintInterface':
        return BlueprintInterfaceSubEditor(
          assetName: assetName,
          assetPath: asset?.lmasPath ?? asset?.relativePath ?? '',
          viewModel: _existingSession<BlueprintInterfaceViewModel>(),
          onBind: _bind,
          onClose: onClose,
        );
      case 'AnimBlueprint':
      case 'animBlueprint':
      case 'ANIM_BLUEPRINT':
        return AnimBlueprintSubEditor(
          assetName: assetName,
          assetPath: asset?.lmasPath ?? asset?.relativePath ?? '',
          viewModel: _existingSession<AnimBlueprintEditorViewModel>(),
          onBind: _bind,
          onClose: onClose,
          onAssetsModified: editorViewModel?.refreshAssets,
        );
      case 'BlendSpace':
      case 'blendSpace':
      case 'BLEND_SPACE':
        return BlendSpaceSubEditor(
          assetName: assetName,
          assetPath: asset?.lmasPath ?? asset?.relativePath ?? '',
          viewModel: _existingSession<BlendSpaceEditorViewModel>(),
          onBind: _bind,
          onClose: onClose,
        );
      case 'Mesh':
      case 'FILAMESH':
      case 'Mesh Inspector':
        return StaticMeshSubEditor(
            assetName: assetName, asset: asset, viewModel: _existingSession<StaticMeshEditorViewModel>(), onBind: _bind, onClose: onClose);
      case 'Skeleton':
      case 'SKELETAL':
        return SkeletalMeshSubEditor(
          assetName: assetName,
          asset: asset,
          assetPath: asset?.lmasPath ?? asset?.relativePath,
          viewModel: _existingSession<SkeletalMeshEditorViewModel>(),
          onBind: _bind, onClose: onClose,
        );
      case 'Animation':
      case 'ANIMATION':
        return AnimationSubEditor(
          assetName: assetName,
          asset: asset,
          assetPath: asset?.lmasPath ?? asset?.relativePath,
          viewModel: _existingSession<AnimationEditorViewModel>(),
          onBind: _bind, onClose: onClose,
          onAssetsModified: editorViewModel?.refreshAssets,
        );
      case 'Texture':
      case 'TEXTURE':
        return TextureSubEditor(
          assetName: assetName,
          asset: asset,
          assetPath: asset?.lmasPath ?? asset?.relativePath,
          viewModel: _existingSession<TextureEditorViewModel>(),
          onBind: _bind, onClose: onClose,
        );
      case 'Particle':
      case 'PARTICLE':
        return ParticleSubEditor(
          assetName: assetName,
          assetPath: asset?.lmasPath ?? asset?.relativePath,
          projectDirPath: editorViewModel?.projectDirPath,
          viewModel: _existingSession<ParticleEditorViewModel>(),
          onBind: _bind, onClose: onClose,
        );
      case 'Audio':
      case 'AUDIO':
        return AudioSubEditor(
          assetName: assetName,
          asset: asset,
          assetPath: asset?.lmasPath ?? asset?.relativePath,
          viewModel: _existingSession<AudioEditorViewModel>(),
          onBind: _bind, onClose: onClose,
        );
      case 'Landscape':
      case 'LANDSCAPE':
      case 'FOLIAGE':
        return LandscapeFoliageSubEditor(
          assetName: assetName,
          assetPath: asset?.lmasPath ??
              (editorViewModel != null ? '${editorViewModel!.projectDirPath}/contents/landscapes/$assetName.lmas' : asset?.relativePath),
          editorViewModel: editorViewModel,
          viewModel: _existingSession<LandscapeEditorViewModel>(),
          onBind: _bind, onClose: onClose,
        );
      case 'Physics':
      case 'PhysicsAsset':
      case 'PHYSICS_ASSET':
        return PhysicsAssetSubEditor(
          assetName: assetName,
          asset: asset,
          assetPath: asset?.lmasPath ?? asset?.relativePath,
          skeletalMeshCandidates: (editorViewModel?.realAssets ?? const <RealAssetInfo>[])
              .where((a) =>
                  a.type == AssetType.filameshSk ||
                  a.relativePath.toLowerCase().contains('skeletal') ||
                  a.fileName.toLowerCase().startsWith('skm_'))
              .toList(),
          viewModel: _existingSession<PhysicsAssetEditorViewModel>(),
          onBind: _bind, onClose: onClose,
        );
      case 'Sequencer':
      case 'SEQUENCER':
        return SequencerSubEditor(
          assetName: assetName,
          asset: asset,
          assetPath: asset?.lmasPath ?? asset?.relativePath,
          levelActors: editorViewModel?.actors,
          editorViewModel: editorViewModel,
          viewModel: _existingSession<SequencerViewModel>(),
          onBind: _bind, onClose: onClose,
        );
      case 'Widget':
      case 'WIDGET':
      case 'WIDGET_BLUEPRINT':
        return UMGWidgetSubEditor(
          assetName: assetName,
          assetPath: asset?.lmasPath ?? (editorViewModel != null ? '${editorViewModel!.projectDirPath}/contents/widgets/$assetName.lmas' : asset?.relativePath),
          projectDirPath: editorViewModel?.projectDirPath,
          viewModel: _existingSession<UmgEditorViewModel>(),
          onBind: _bind,
          onClose: onClose,
        );
      case 'Settings':
      case 'PROJECT_SETTINGS':
      case 'projectSettings':
        return ProjectSettingsSubEditor(
          assetName: assetName,
          // A view model an MCP tool bound as this tab's session.
          viewModel: _existingSession<ProjectSettingsViewModel>(),
          projectDirPath: editorViewModel?.projectDirPath,
          initialProject: editorViewModel?.project,
          onApplied: editorViewModel?.applyProjectSettings,
          codeGenerator: editorViewModel?.cookCodeGenerator,
          pluginSections: editorViewModel?.extensionRegistry.projectSettingsSections ?? const [],
          onClose: onClose,
          onBind: _bind,
        );
      case 'mcpServer':
        // Tools → AI Agent Access (MCP).
        if (editorViewModel == null) return const Center(child: Text('Missing EditorViewModel'));
        return McpServerPanel(service: editorViewModel!.mcpServer, onClose: onClose);
      case EditorViewModel.marketplaceCategory:
        // Window → Marketplace.
        if (editorViewModel == null) return const Center(child: Text('Missing EditorViewModel'));
        return MarketplaceView(
          viewModel: editorViewModel!.marketplace,
          contentFolders: () => editorViewModel!.sourceFolders.where((f) => f == 'contents' || f.startsWith('contents/')).toList(),
          foldersChanged: editorViewModel,
        );
      case 'editorPreferences':
        // Edit → Editor Preferences...
        return EditorPreferencesSubEditor(
          preferences: editorViewModel?.editorPreferences ?? EditorPreferences.load(),
          projectDir: editorViewModel?.projectDirPath,
          onClose: onClose,
        );
      case 'Environment':
      case 'ENVIRONMENT_LIGHTING':
      case 'lighting':
        return EnvironmentLightingSubEditor(
          assetName: assetName,
          editorViewModel: editorViewModel,
          // A view model an MCP tool bound first.
          viewModel: _existingSession<EnvironmentLightingViewModel>(),
          onBind: _bind,
          onClose: onClose,
        );
      case 'Navigation':
      case 'NAVIGATION':
      case 'navigation':
      case 'navmesh':
        return NavigationSubEditor(
          assetName: assetName,
          editorViewModel: editorViewModel,
          viewModel: _existingSession<NavigationEditorViewModel>(),
          onBind: _bind,
          onClose: onClose,
        );
      case 'Build':
      case 'BUILD_MANAGER':
      case 'buildManager':
        return BuildManagerSubEditor(
          assetName: assetName,
          projectDirPath: editorViewModel?.projectDirPath,
          initialProject: editorViewModel?.project,
          editorViewModel: editorViewModel,
          onBind: _bind,
          onClose: onClose,
        );
      default:
        return MaterialSubEditor(assetName: assetName, assetPath: asset?.lmasPath ?? asset?.relativePath, onClose: onClose);
    }
  }
}

/// Renders the `editorFactory` a plugin registered for
/// [customTypeId] over the `.lmas` at the tab's asset path, with
/// `metadata.asset_path` set so the editor can write the asset back.
Widget _pluginAssetEditorFor(BuildContext context, EditorViewModel? vm, RealAssetInfo? asset, String customTypeId, VoidCallback? onClose) {
  if (vm == null) return const Center(child: Text('Missing EditorViewModel'));
  final handler = vm.extensionRegistry.allAssetTypes.where((h) => h.customTypeId == customTypeId).firstOrNull;
  if (handler == null) return Center(child: Text('No plugin registered the asset type "$customTypeId" (is its plugin enabled?)'));
  final path = asset?.lmasPath;
  if (path == null || !File(path).existsSync()) return Center(child: Text('Asset file not found: ${asset?.relativePath}'));
  final factory = handler.editorFactory;
  if (factory == null) return Center(child: Text('${handler.displayName} has no editor'));
  final LuminaAsset loaded;
  try {
    loaded = LuminaAsset.fromBytes(File(path).readAsBytesSync());
  } catch (e) {
    return Center(child: Text('Cannot read ${asset!.relativePath}: $e'));
  }
  final withPath = LuminaAsset(
    assetId: loaded.assetId,
    name: loaded.name,
    type: loaded.type,
    hasThumbnail: loaded.hasThumbnail,
    thumbnailPng: loaded.thumbnailPng,
    rawPayload: loaded.rawPayload,
    rawMatSource: loaded.rawMatSource,
    references: loaded.references,
    metadata: {...loaded.metadata, kAssetPathMetadataKey: path},
  );
  return factory(context, withPath);
}

extension _PluginAssetEditor on _SubEditorDispatcher {
  Widget _buildPluginAssetEditor(BuildContext context, String customTypeId) =>
      _pluginAssetEditorFor(context, editorViewModel, asset, customTypeId, onClose);
}

/// Helper method to open sub-editor modal if requested outside of tab bar
void showSubEditorModal(BuildContext context, String assetType, String assetName) {
  showOverlay(
    context,
    const DialogConfiguration(),
    builder: (context) {
      return AlertDialog(
        content: SizedBox(
          width: 1000,
          height: 700,
          child: SubEditorWorkspaceWidget(
            assetType: assetType,
            assetName: assetName,
            onClose: () => Navigator.of(context).pop(),
          ),
        ),
      );
    },
  );
}

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart' show SchedulerBinding;
import 'package:lumina/lumina.dart';

import '../../main_editor/services/widget_blueprint_assets.dart' show isWidgetBlueprintLmas;
import '../../main_editor/view_models/editor_view_model.dart';
import '../../sub_editors/view_models/anim_blueprint_editor_view_model.dart';
import '../../sub_editors/view_models/animation_editor_view_model.dart';
import '../../sub_editors/view_models/blend_space_editor_view_model.dart';
import '../../sub_editors/view_models/blueprint_editor_view_model.dart';
import '../../sub_editors/view_models/environment_lighting_view_model.dart';
import '../../sub_editors/view_models/navigation_editor_view_model.dart';
import '../../sub_editors/view_models/level_blueprint_editor_view_model.dart';
import '../../sub_editors/view_models/material_editor_view_model.dart';
import '../../sub_editors/view_models/particle_editor_view_model.dart';
import '../../sub_editors/view_models/project_settings_view_model.dart';
import '../../sub_editors/view_models/sequencer_view_model.dart';
import '../../sub_editors/view_models/skeletal_mesh_editor_view_model.dart';
import '../../sub_editors/view_models/umg_editor_view_model.dart';
import '../../sub_editors/services/landscape_preview_scene.dart';
import '../../sub_editors/view_models/audio_editor_view_model.dart';
import '../../sub_editors/view_models/blueprint_enum_view_model.dart';
import '../../sub_editors/view_models/blueprint_interface_view_model.dart';
import '../../sub_editors/view_models/landscape_editor_view_model.dart';
import '../../sub_editors/view_models/physics_asset_editor_view_model.dart';
import '../../sub_editors/view_models/static_mesh_editor_view_model.dart';
import '../../sub_editors/view_models/texture_editor_view_model.dart';
import 'mcp_protocol.dart';

/// Reaches the sub-editor view model of an asset for the MCP tools:
/// the one bound to the asset's open tab when there is
/// one, else a view model this class creates, loads, binds as the tab's
/// session and opens the tab for — so the user sees the agent's edits in
/// the Material editor's code view or the Blueprint editor's graph canvas,
/// and the tab's own undo stack and Save cover them. It also covers the
/// UMG designer (a Widget Blueprint's graph is its designer's graph editor),
/// the animation editors, the Sequencer and particles, and
/// the Landscape, Static Mesh, Texture, Physics Asset, Sound,
/// Enumeration and Blueprint Interface editors.
class McpEditorSessions {
  McpEditorSessions(this.vm);

  final EditorViewModel vm;
  final List<ChangeNotifier> _owned = [];

  /// The asset [wanted] names: a project-relative path, an absolute `.lmas`
  /// path, or a file name (with or without `.lmas`) when it is unique.
  RealAssetInfo resolveAsset(String wanted, {AssetType? type, String? forTool}) {
    Iterable<RealAssetInfo> pool = vm.realAssets;
    if (type != null) pool = pool.where((a) => a.type == type);
    var matches = pool.where((a) => a.relativePath == wanted || a.lmasPath == wanted).toList();
    if (matches.isEmpty) {
      matches = pool.where((a) => a.fileName == wanted || a.fileName == '$wanted.lmas').toList();
    }
    if (matches.isEmpty) {
      final kind = type == null ? 'asset' : '${type.name} asset';
      throw JsonRpcException(
        JsonRpcErrorCode.invalidParams,
        'No $kind "$wanted" in the project. Call list_assets${type == null ? '' : ' with type "${type.name}"'} '
        'and pass the relative path (e.g. "contents/materials/M_Example.lmas").',
      );
    }
    if (matches.length > 1) {
      throw JsonRpcException(
        JsonRpcErrorCode.invalidParams,
        '"$wanted" matches ${matches.length} assets: ${matches.map((a) => a.relativePath).join(', ')}. Pass the relative path.',
      );
    }
    return matches.first;
  }

  static String tabIdOf(RealAssetInfo asset) => asset.lmasPath ?? asset.relativePath;

  /// [path] relative to the project (`/`-separated) when it lies inside it,
  /// else as given — what the tools report for an editor's absolute paths.
  String projectRelative(String path) {
    final prefix = '${vm.projectDirPath.replaceAll(r'\', '/')}/';
    final p = path.replaceAll(r'\', '/');
    return p.startsWith(prefix) ? p.substring(prefix.length) : p;
  }

  String _absolutePath(RealAssetInfo asset) =>
      asset.lmasPath ?? (asset.relativePath.startsWith('/') ? asset.relativePath : '${vm.projectDirPath}/${asset.relativePath}');

  /// The view model bound to [asset]'s tab when it is a [T]; else one
  /// [create]d, [load]ed and bound here, which the tab's widget adopts
  /// (`_existingSession` in `sub_editor_modal.dart`). Opens the tab either way.
  Future<T> _session<T extends ChangeNotifier>(
    RealAssetInfo asset,
    String category,
    T Function(String path) create, {
    required Future<void> Function(T editor) load,
    required Future<bool> Function(T editor) save,
    required bool Function(T editor) isDirty,
  }) async {
    final tabId = tabIdOf(asset);
    final existing = vm.editorSessionFor(tabId);
    if (existing is T) {
      vm.openSubEditorTab(category, asset: asset);
      return existing;
    }
    final editor = create(_absolutePath(asset));
    _owned.add(editor);
    await load(editor);
    vm.bindTabSession(tabId, notifier: editor, save: () => save(editor), isDirty: () => isDirty(editor));
    vm.openSubEditorTab(category, asset: asset);
    return editor;
  }

  /// The Material editor's view model for [asset], opening its tab.
  Future<MaterialEditorViewModel> material(RealAssetInfo asset) => _session(
        asset,
        'Material',
        (path) => MaterialEditorViewModel(assetPath: path),
        load: (e) => e.load(),
        save: (e) => e.save(),
        isDirty: (e) => e.isDirty,
      );

  /// The UMG designer's view model for the Widget Blueprint
  /// [asset], opening its tab.
  Future<UmgEditorViewModel> widget(RealAssetInfo asset) => _session(
        asset,
        'Widget',
        (path) => UmgEditorViewModel(assetPath: path, projectDirPathOverride: vm.projectDirPath),
        load: (e) => e.load(),
        save: (e) => e.save(),
        isDirty: (e) => e.isDirty,
      );

  /// The Animation Blueprint editor's view model for [asset],
  /// opening its tab.
  Future<AnimBlueprintEditorViewModel> animBlueprint(RealAssetInfo asset) => _session(
        asset,
        'AnimBlueprint',
        (path) => AnimBlueprintEditorViewModel(assetPath: path),
        load: (e) => e.load(),
        save: (e) => e.save(),
        isDirty: (e) => e.isDirty,
      );

  /// The Blend Space editor's view model for [asset].
  Future<BlendSpaceEditorViewModel> blendSpace(RealAssetInfo asset) => _session(
        asset,
        'BlendSpace',
        (path) => BlendSpaceEditorViewModel(assetPath: path),
        load: (e) => e.load(),
        save: (e) => e.save(),
        isDirty: (e) => e.isDirty,
      );

  /// The Animation editor's view model for [asset]. Created
  /// here it has no frame ticker (the tab's widget owns none either when it
  /// adopts one), so playback advances only through `animation_preview`.
  Future<AnimationEditorViewModel> animation(RealAssetInfo asset) => _session(
        asset,
        'Animation',
        (path) => AnimationEditorViewModel(assetPath: path),
        load: (e) => e.load(),
        save: (e) => e.save(),
        isDirty: (e) => e.isDirty,
      );

  /// The Skeletal Mesh editor's view model for [asset].
  Future<SkeletalMeshEditorViewModel> skeletalMesh(RealAssetInfo asset) => _session(
        asset,
        'Skeleton',
        (path) => SkeletalMeshEditorViewModel(assetPath: path),
        load: (e) => e.load(),
        save: (e) => e.save(),
        isDirty: (e) => e.isDirty,
      );

  /// The Sequencer's view model for [asset], bound to the
  /// open level as the tab binds it (a scrub before the tab mounts moves the
  /// level's actors too).
  Future<SequencerViewModel> sequencer(RealAssetInfo asset) => _session(
        asset,
        'Sequencer',
        (path) => SequencerViewModel(assetPath: path, projectDirPath: vm.projectDirPath),
        load: (e) async {
          await e.load();
          e.bindLevel(actors: () => vm.actors, onChanged: vm.notifyListeners);
        },
        save: (e) => e.save(),
        isDirty: (e) => e.isDirty,
      );

  /// The Particle editor's view model for [asset].
  Future<ParticleEditorViewModel> particle(RealAssetInfo asset) => _session(
        asset,
        'Particle',
        (path) => ParticleEditorViewModel(assetPath: path, projectDirPath: vm.projectDirPath),
        load: (e) async => e.open(),
        save: (e) => e.save(),
        isDirty: (e) => e.isDirty,
      );

  /// The Landscape editor's view model for [asset], created
  /// with the editor (its mesh palette) and its own [LandscapePreviewScene],
  /// which the tab's viewport attaches when it adopts the view model.
  Future<LandscapeEditorViewModel> landscape(RealAssetInfo asset) => _session(
        asset,
        'Landscape',
        (path) => LandscapeEditorViewModel(editor: vm, assetPath: path, sink: LandscapePreviewScene()),
        load: (e) async => e.open(),
        save: (e) => e.save(),
        isDirty: (e) => e.isDirty,
      );

  /// The Static Mesh editor's view model for [asset].
  Future<StaticMeshEditorViewModel> staticMesh(RealAssetInfo asset) => _session(
        asset,
        'Mesh',
        (path) => StaticMeshEditorViewModel(assetPath: path),
        load: (e) => e.load(),
        save: (e) => e.save(),
        isDirty: (e) => e.isDirty,
      );

  /// The Texture editor's view model for [asset].
  Future<TextureEditorViewModel> texture(RealAssetInfo asset) => _session(
        asset,
        'Texture',
        (path) => TextureEditorViewModel(assetPath: path),
        load: (e) => e.load(),
        save: (e) => e.save(),
        isDirty: (e) => e.isDirty,
      );

  /// The Physics Asset editor's view model for [asset].
  Future<PhysicsAssetEditorViewModel> physicsAsset(RealAssetInfo asset) => _session(
        asset,
        'PhysicsAsset',
        (path) => PhysicsAssetEditorViewModel(assetPath: path),
        load: (e) => e.load(),
        save: (e) => e.save(),
        isDirty: (e) => e.isDirty,
      );

  /// The Sound editor's view model for [asset] (silent: an
  /// agent cannot hear, so nothing here plays).
  Future<AudioEditorViewModel> audio(RealAssetInfo asset) => _session(
        asset,
        'Audio',
        (path) => AudioEditorViewModel(assetPath: path),
        load: (e) => e.load(),
        save: (e) => e.save(),
        isDirty: (e) => e.isDirty,
      );

  /// The Enumeration editor's view model for [asset].
  Future<BlueprintEnumViewModel> blueprintEnum(RealAssetInfo asset) => _session(
        asset,
        'BlueprintEnum',
        (path) => BlueprintEnumViewModel(assetPath: path),
        load: (e) => e.load(),
        save: (e) => e.save(),
        isDirty: (e) => e.isDirty,
      );

  /// The Blueprint Interface editor's view model for [asset].
  Future<BlueprintInterfaceViewModel> blueprintInterface(RealAssetInfo asset) => _session(
        asset,
        'BlueprintInterface',
        (path) => BlueprintInterfaceViewModel(assetPath: path),
        load: (e) => e.load(),
        save: (e) => e.save(),
        isDirty: (e) => e.isDirty,
      );

  /// Whether [asset] is a Widget Blueprint: a widget asset, or an actor
  /// Blueprint with the widget parent written by an older build.
  bool isWidget(RealAssetInfo asset) =>
      asset.type == AssetType.widget || (asset.type == AssetType.actor && isWidgetBlueprintLmas(_absolutePath(asset)));

  /// The Blueprint editor's view model for [asset], opening its tab. A
  /// Widget Blueprint's is its designer's graph editor, so
  /// the Blueprint tools edit a widget's graph unchanged.
  Future<BlueprintEditorViewModel> blueprint(RealAssetInfo asset) async {
    if (isWidget(asset)) {
      final designer = await widget(asset);
      designer.setMode(UmgEditorMode.graph);
      return designer.graphEditor;
    }
    return _session(
      asset,
      'Blueprint',
      (path) => BlueprintEditorViewModel(assetPath: path),
      load: (e) => e.load(),
      save: (e) => e.save(),
      isDirty: (e) => e.isDirty,
    );
  }

  /// The Blueprint editor for [wanted] — `"level"` (the active
  /// level's Level Blueprint), a level `.lmas` (that level's Level
  /// Blueprint), an actor Blueprint asset, or a Widget
  /// Blueprint, whose graph it is — opening its tab.
  Future<BlueprintEditorViewModel> blueprintEditor(String wanted) async {
    if (wanted == 'level') return vm.openLevelBlueprint();
    final asset = resolveAsset(wanted);
    if (asset.type == AssetType.level) return vm.openLevelBlueprint(asset.relativePath);
    if (asset.type != AssetType.actor && asset.type != AssetType.widget) {
      throw JsonRpcException(JsonRpcErrorCode.invalidParams,
          '${asset.relativePath} is a ${asset.type.name}, not a Blueprint class. Pass a Blueprint (list_assets type "actor"), '
          'a Widget Blueprint (type "widget": its graph), "level" for the active level\'s Level Blueprint, or a level .lmas.');
    }
    return blueprint(asset);
  }


  /// The Environment Lighting tab's view model (Tools →
  /// Environment Lighting), opening the tab: the one bound to it, or one
  /// created, opened and bound here that the tab's widget adopts. A bound
  /// view model left over from another level is replaced, so two view models
  /// never edit one level and none edits a level that is no longer open.
  Future<EnvironmentLightingViewModel> environment() async {
    final existing = vm.editorSessionFor(environmentTabId);
    if (existing is EnvironmentLightingViewModel && !_stale(existing, existing.sunActor)) {
      _levelOf[existing] ??= vm.project.activeLevel;
      vm.openSubEditorTab('lighting', title: 'Environment Lighting');
      if (!existing.isOpened) existing.open();
      return existing;
    }
    if (existing != null) await _retire(environmentTabId);
    final editor = EnvironmentLightingViewModel(editor: vm);
    _owned.add(editor);
    _levelOf[editor] = vm.project.activeLevel;
    editor.open();
    vm.bindTabSession(environmentTabId, notifier: editor, save: editor.save, isDirty: () => editor.isDirty);
    vm.openSubEditorTab('lighting', title: 'Environment Lighting');
    return editor;
  }

  /// The Navigation tab's view model (Tools → Navigation,
  /// Build → Build Navigation), opening the tab, as [environment] does.
  Future<NavigationEditorViewModel> navigation() async {
    final existing = vm.editorSessionFor(navigationTabId);
    if (existing is NavigationEditorViewModel && !_stale(existing, null)) {
      _levelOf[existing] ??= vm.project.activeLevel;
      vm.openSubEditorTab('navmesh', title: 'Navigation');
      if (!existing.isOpened) existing.open();
      return existing;
    }
    if (existing != null) await _retire(navigationTabId);
    final editor = NavigationEditorViewModel(editor: vm);
    _owned.add(editor);
    _levelOf[editor] = vm.project.activeLevel;
    editor.open();
    vm.bindTabSession(navigationTabId, notifier: editor, save: editor.save, isDirty: () => editor.isDirty);
    vm.openSubEditorTab('navmesh', title: 'Navigation');
    return editor;
  }

  /// The bound Environment Lighting / Navigation view model when there is
  /// one for the open level, without opening anything (the read tools).
  EnvironmentLightingViewModel? get boundEnvironment {
    final s = vm.editorSessionFor(environmentTabId);
    return s is EnvironmentLightingViewModel && s.isOpened && !_stale(s, s.sunActor) ? s : null;
  }

  NavigationEditorViewModel? get boundNavigation {
    final s = vm.editorSessionFor(navigationTabId);
    return s is NavigationEditorViewModel && s.isOpened && !_stale(s, null) ? s : null;
  }

  /// The Project Settings tab's view model (Edit → Project
  /// Settings), opening the tab: the one bound to it, or one created here
  /// with the editor's project, Apply hook and cook code generator, loaded
  /// from the `.lmproject` and bound, which the tab's widget adopts. Tools
  /// stage on its working copy exactly as the tab's fields do.
  Future<ProjectSettingsViewModel> projectSettings() async {
    final existing = vm.editorSessionFor(projectSettingsTabId);
    if (existing is ProjectSettingsViewModel) {
      // Blueprints and levels created since the tab loaded become choices.
      existing.refreshChoices();
      vm.openSubEditorTab('projectSettings', title: 'Project Settings');
      return existing;
    }
    final editor = ProjectSettingsViewModel(
      projectDirPath: vm.projectDirPath,
      initialProject: vm.project,
      codeGenerator: vm.cookCodeGenerator,
    )
      ..onApplied = vm.applyProjectSettings
      ..pluginSections = vm.extensionRegistry.projectSettingsSections;
    _owned.add(editor);
    await editor.load();
    vm.bindTabSession(projectSettingsTabId, notifier: editor, save: editor.apply, isDirty: () => editor.isDirty);
    vm.openSubEditorTab('projectSettings', title: 'Project Settings');
    return editor;
  }

  /// The bound Project Settings view model, without opening anything.
  ProjectSettingsViewModel? get boundProjectSettings {
    final s = vm.editorSessionFor(projectSettingsTabId);
    return s is ProjectSettingsViewModel ? s : null;
  }

  static const String projectSettingsTabId = 'tab_projectSettings';
  static const String environmentTabId = 'tab_lighting';
  static const String navigationTabId = 'tab_navmesh';

  /// The level each level-scoped view model was first used for.
  final Expando<String> _levelOf = Expando('mcp_session_level');

  /// Whether [session] belongs to a level that is no longer open: it was
  /// used for another level, or the actor it edits is gone from the level.
  bool _stale(Object session, EditorActorNode? actor) {
    final level = _levelOf[session];
    if (level != null && level != vm.project.activeLevel) return true;
    return actor != null && !vm.actors.contains(actor);
  }

  /// Closes the tab [tabId] (its stale view model goes with it) and lets its
  /// widget unmount before a new one is bound, so the new tab's widget
  /// adopts the new view model instead of keeping the old one.
  Future<void> _retire(String tabId) async {
    final old = vm.editorSessionFor(tabId);
    final index = vm.openTabs.indexWhere((t) => t.id == tabId);
    if (index > 0) {
      vm.closeTab(index);
    } else {
      vm.unbindTabSession(tabId);
    }
    final binding = SchedulerBinding.instance;
    if (binding.hasScheduledFrame) await binding.endOfFrame;
    if (old is ChangeNotifier && _owned.remove(old)) old.dispose();
  }

  static bool isLevelBlueprint(BlueprintEditorViewModel editor) => editor is LevelBlueprintEditorViewModel;

  void dispose() {
    for (final editor in _owned) {
      editor.dispose();
    }
    _owned.clear();
  }
}

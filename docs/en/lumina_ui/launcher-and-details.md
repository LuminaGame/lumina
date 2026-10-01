[Türkçe](../../tr/lumina_ui/launcher-and-details.md)

# Launcher and details

The project launcher (recent projects, templates and the create-project flow) and the models and services behind the details panel: the component property registry, editor component nodes and multi-selection editing. File paths are relative to the `lumina_ui/` package directory.

**On this page:**

- [`lib/ui/features/launcher/views/create_project_dialog.dart`](#libuifeatureslauncherviewscreate_project_dialogdart)
- [`lib/ui/features/launcher/views/launcher_view.dart`](#libuifeatureslauncherviewslauncher_viewdart)
- [`lib/ui/features/launcher/view_models/create_project_view_model.dart`](#libuifeatureslauncherview_modelscreate_project_view_modeldart)
- [`lib/ui/features/launcher/view_models/launcher_view_model.dart`](#libuifeatureslauncherview_modelslauncher_view_modeldart)
- [`lib/ui/features/details/services/multi_edit_service.dart`](#libuifeaturesdetailsservicesmulti_edit_servicedart)
- [`lib/ui/features/details/models/component_property_registry.dart`](#libuifeaturesdetailsmodelscomponent_property_registrydart)
- [`lib/ui/features/details/models/editor_component_node.dart`](#libuifeaturesdetailsmodelseditor_component_nodedart)
- [`lib/ui/features/details/services/blueprint_collision_overrides.dart`](#libuifeaturesdetailsservicesblueprint_collision_overridesdart)
- [`lib/ui/features/details/widgets/actor_mesh_section.dart`](#libuifeaturesdetailswidgetsactor_mesh_sectiondart)
- [`lib/ui/features/launcher/services/installed_template_repository.dart`](#libuifeatureslauncherservicesinstalled_template_repositorydart)
- [`lib/ui/features/launcher/services/project_editor_resolver.dart`](#libuifeatureslauncherservicesproject_editor_resolverdart)
- [`lib/ui/features/launcher/services/template_project_creator.dart`](#libuifeatureslauncherservicestemplate_project_creatordart)
- [`lib/ui/features/launcher/view_models/editor_build_view_model.dart`](#libuifeatureslauncherview_modelseditor_build_view_modeldart)
- [`lib/ui/features/launcher/views/editor_build_splash.dart`](#libuifeatureslauncherviewseditor_build_splashdart)
- [`lib/ui/features/launcher/views/installed_template_widgets.dart`](#libuifeatureslauncherviewsinstalled_template_widgetsdart)
- [`lib/ui/features/launcher/views/launcher_recent_projects_pane.dart`](#libuifeatureslauncherviewslauncher_recent_projects_panedart)
- [`lib/ui/features/launcher/views/launcher_settings_panes.dart`](#libuifeatureslauncherviewslauncher_settings_panesdart)
- [`lib/ui/features/launcher/views/launcher_templates_pane.dart`](#libuifeatureslauncherviewslauncher_templates_panedart)
- [`lib/ui/features/launcher/views/missing_editor_binary_dialog.dart`](#libuifeatureslauncherviewsmissing_editor_binary_dialogdart)
- [`lib/ui/features/launcher/services/project_editor_update.dart`](#libuifeatureslauncherservicesproject_editor_updatedart)
- [`lib/ui/features/launcher/views/project_editor_update_dialog.dart`](#libuifeatureslauncherviewsproject_editor_update_dialogdart)

## `lib/ui/features/launcher/views/create_project_dialog.dart`

### `class CreateProjectDialog`

`CreateProjectDialog`: shadcn_flutter UI component rendering interface elements and listening to interactions.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `viewModel` | `CreateProjectViewModel viewModel` | Holds the `viewModel` property or configuration state. |
| `onSuccess` | `VoidCallback onSuccess` | Holds the `onSuccess` property or configuration state. |
| `createState` | `State<CreateProjectDialog> createState() => _CreateProjectDialogState()` | Creates, configures, and returns a new `State` instance or associated GPU resource. |

### `class _CreateProjectDialogState`

`_CreateProjectDialogState`: shadcn_flutter UI component rendering interface elements and listening to interactions.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `initState` | `void initState()` | Executes `initState` operation. |
| `dispose` | `void dispose()` | Releases native FFI pointers, event subscriptions, and allocated memory. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

## `lib/ui/features/launcher/views/launcher_view.dart`

### `class LauncherView`

`LauncherView`: shadcn_flutter UI component rendering interface elements and listening to interactions.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `viewModel` | `LauncherViewModel? viewModel` | Holds the `viewModel` property or configuration state. |
| `createState` | `State<LauncherView> createState() => _LauncherViewState()` | Creates, configures, and returns a new `State` instance or associated GPU resource. |

**Opening a project.** Every Open (the Recent Projects list, Open External, a new project, `--project <dir>`) goes through `_openProject`: the resolver decides (in place, cached project editor, build, or the missing-binary prompt). When a project editor is to be exec'd or built and the project's copy of the engine source comes from another engine than this Studio's (`LauncherViewModel.projectEditorUpdate`), the shadcn dialog "Update this project's editor?" (`ProjectEditorUpdateDialog`) names both versions first: **Update** replaces the copy on the build splash, records the new `engine_version` and rebuilds, then opens; **Open with the old editor** goes on as before ("Don't ask again for this version" stores the answer for this engine on this machine); **Cancel** stays in the launcher. `--update-editor` (a project editor's hand-off after the user chose Update there) updates without asking. Per-project editors off and no code plugins, the project opens in place and its `engine_version` becomes this Studio's version (one Output Log line). A project editor started on its own first reads the last Lumina Studio that started on this machine (`LuminaStudioRecord`) and, when its engine differs from the copy, asks the same question: Update hands the project to that Studio with `--update-editor`, Cancel returns to it, Open with the old editor goes on to the stale-build check.

### `class _LauncherViewState`

`_LauncherViewState`: shadcn_flutter UI component rendering interface elements and listening to interactions.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `initState` | `void initState()` | Executes `initState` operation. |
| `dispose` | `void dispose()` | Releases native FFI pointers, event subscriptions, and allocated memory. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

## `lib/ui/features/launcher/view_models/create_project_view_model.dart`

### `class CreateProjectViewModel`

`CreateProjectViewModel`: ChangeNotifier ViewModel managing UI state, user actions, and data binding for the view.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `launcherVM` | `LauncherViewModel launcherVM` | Holds the `launcherVM` property or configuration state. |
| `projectRepo` | `ProjectRepository projectRepo` | Holds the `projectRepo` property or configuration state. |
| `name` | `String get name` | Getter accessor returning the current value of `name`. |
| `location` | `String get location` | Getter accessor returning the current value of `location`. |
| `template` | `String get template` | Getter accessor returning the current value of `template`. |
| `validationError` | `String? get validationError` | Getter accessor returning the current value of `validationError`. |
| `activeProject` | `LuminaProject? get activeProject` | Getter accessor returning the current value of `activeProject`. |
| `isCreating` | `bool get isCreating` | Checks current state or capability and returns a boolean value. |
| `currentStep` | `ProjectCreationStep? get currentStep` | Getter accessor returning the current value of `currentStep`. |
| `progress` | `double get progress` | Getter accessor returning the current value of `progress`. |
| `progressLabel` | `String get progressLabel` | Getter accessor returning the current value of `progressLabel`. |
| `processOutput` | `List<String> get processOutput` | Getter accessor returning the current value of `processOutput`. |
| `creationError` | `String? get creationError` | Getter accessor returning the current value of `creationError`. |
| `updateName` | `void updateName(String val)` | Updates the current state or data values. |
| `updateLocation` | `void updateLocation(String val)` | Updates the current state or data values. |
| `updateTemplate` | `void updateTemplate(String val)` | Updates the current state or data values. |
| `validateProjectName` | `static String? validateProjectName(String name)` | Executes `validateProjectName` operation. |
| `validateLocation` | `static String? validateLocation(String location)` | Executes `validateLocation` operation. |
| `createProject` | `Future<void> createProject()` | Creates, configures, and returns a new `Project` instance or associated GPU resource. |

## `lib/ui/features/launcher/view_models/launcher_view_model.dart`

### `class LauncherTemplate`

`LauncherTemplate`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `id` | `String id` | Holds the `id` property or configuration state. |
| `title` | `String title` | Holds the `title` property or configuration state. |
| `description` | `String description` | Holds the `description` property or configuration state. |
| `icon` | `IconData icon` | Holds the `icon` property or configuration state. |

### `class LauncherViewModel`

`LauncherViewModel`: ChangeNotifier ViewModel managing UI state, user actions, and data binding for the view.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `configDir` | `Directory? configDir` | Holds the `configDir` property or configuration state. |
| `defaultProjectsDir` | `static String get defaultProjectsDir` | Getter accessor returning the current value of `defaultProjectsDir`. |
| `selectedTabIndex` | `int get selectedTabIndex` | Selects the target actor or asset. |
| `themeMode` | `ThemeMode get themeMode` | Getter accessor returning the current value of `themeMode`. |
| `projectRepo` | `ProjectRepository get projectRepo` | Getter accessor returning the current value of `projectRepo`. |
| `defaultProjectsDirectory` | `String get defaultProjectsDirectory` | Getter accessor returning the current value of `defaultProjectsDirectory`. |
| `recentProjects` | `List<RecentProjectEntry> get recentProjects` | Getter accessor returning the current value of `recentProjects`. |
| `isLoading` | `bool get isLoading` | Checks current state or capability and returns a boolean value. |
| `isCreating` | `bool get isCreating` | Checks current state or capability and returns a boolean value. |
| `projectName` | `String get projectName` | Getter accessor returning the current value of `projectName`. |
| `projectPath` | `String get projectPath` | Getter accessor returning the current value of `projectPath`. |
| `activeProject` | `LuminaProject? get activeProject` | Getter accessor returning the current value of `activeProject`. |
| `engineVersion` | `String get engineVersion` | Getter accessor returning the current value of `engineVersion`. |
| `engineDisplayVersion` | `String get engineDisplayVersion` | Getter accessor returning the current value of `engineDisplayVersion`. |
| `resolvedConfigDir` | `Directory get resolvedConfigDir` | Getter accessor returning the current value of `resolvedConfigDir`. |
| `loadSettings` | `Future<void> loadSettings()` | Loads data from disk or memory buffer into the engine. |
| `saveSettings` | `Future<void> saveSettings()` | Serializes and writes the current state or asset to disk. |
| `setTab` | `void setTab(int index)` | Updates the `Tab` parameter and applies changes to the system. |
| `setThemeMode` | `Future<void> setThemeMode(ThemeMode mode)` | Updates the `ThemeMode` parameter and applies changes to the system. |
| `toggleTheme` | `Future<void> toggleTheme(bool isDark)` | Toggles the target feature or visibility on/off. |
| `setDefaultProjectsDirectory` | `Future<void> setDefaultProjectsDirectory(String path)` | Updates the `DefaultProjectsDirectory` parameter and applies changes to the system. |
| `loadRecentProjects` | `Future<void> loadRecentProjects()` | Loads data from disk or memory buffer into the engine. |
| `updateProjectName` | `void updateProjectName(String val)` | Updates the current state or data values. |
| `updateProjectPath` | `void updateProjectPath(String val)` | Updates the current state or data values. |
| `openProject` | `Future<LuminaProject?> openProject(RecentProjectEntry entry)` | Executes `openProject` operation. |
| `openExternal` | `Future<LuminaProject?> openExternal(String lmprojectPath)` | Executes `openExternal` operation. |
| `renameProject` | `Future<void> renameProject(RecentProjectEntry entry, String newName)` | Executes `renameProject` operation. |
| `duplicateProject` | `Future<void> duplicateProject(RecentProjectEntry entry)` | Executes `duplicateProject` operation. |
| `removeFromHub` | `Future<void> removeFromHub(RecentProjectEntry entry)` | Releases and safely disposes the specified `FromHub` resource. |
| `deleteFromDisk` | `Future<void> deleteFromDisk(RecentProjectEntry entry)` | Releases and safely disposes the specified `FromDisk` resource. |
| `locateProject` | `Future<LuminaProject?> locateProject(RecentProjectEntry entry, String ne...` | Executes `locateProject` operation. |
| `revealInFileManager` | `Future<void> revealInFileManager(RecentProjectEntry entry)` | Executes `revealInFileManager` operation. |
| `updatePrompts` | `late final ProjectEditorUpdatePrompts updatePrompts` | The "Don't ask again for this version" answers, per project on this machine (this launcher's config folder). |
| `projectEditorUpdate` | `Future<EditorEngineUpdate?> projectEditorUpdate(String projectDir) async` | Whether the project's editor should be offered an update to this Studio's engine: its copy of the engine source comes from another engine and the user did not ask to skip this one. Logs the comparison. |
| `dismissProjectEditorUpdate` | `void dismissProjectEditorUpdate(String projectDir, EditorEngineUpdate update)` | "Don't ask again for this version": [update]'s engine is not offered for [projectDir] again on this machine. |
| `recordEngineVersion` | `Future<LuminaProject> recordEngineVersion(LuminaProject project, String projectDir, {String? version}) async` | Writes [version] (default: this Studio's `LuminaRelease.displayVersion`) as the project's `engine_version` and logs one line when it changed; returns [project] carrying it. The open-in-place path uses it. |
| `projectEditorBuild` | `EditorBuildViewModel projectEditorBuild(String projectName, String projectDir, List<LuminaPluginDescriptor> plugins, {EditorEngineUpdate? update})` | The build behind the splash. [update] first replaces the project's copy of the engine source with this Studio's (`syncSource`) and, once it is in place, writes the new `engine_version` and logs both versions. |

## `lib/ui/features/details/services/multi_edit_service.dart`

### `class MultiEditComponentProperty`

`MultiEditComponentProperty`: Actor component providing spatial 3D transform, visual mesh, lighting, or movement capability.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `propertyId` | `String propertyId` | Holds the `propertyId` property or configuration state. |
| `descriptor` | `PropertyDescriptor descriptor` | Holds the `descriptor` property or configuration state. |
| `isMixed` | `bool isMixed` | Holds the `isMixed` property or configuration state. |
| `commonValue` | `dynamic commonValue` | Holds the `commonValue` property or configuration state. |
| `isMixedPerAxis` | `List<bool>? isMixedPerAxis` | Holds the `isMixedPerAxis` property or configuration state. |
| `commonVector` | `List<double>? commonVector` | Holds the `commonVector` property or configuration state. |

### `class MultiEditComponentBlock`

`MultiEditComponentBlock`: Actor component providing spatial 3D transform, visual mesh, lighting, or movement capability.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `componentType` | `String componentType` | Holds the `componentType` property or configuration state. |
| `componentName` | `String componentName` | Holds the `componentName` property or configuration state. |
| `isMixedEnabled` | `bool isMixedEnabled` | Holds the `isMixedEnabled` property or configuration state. |
| `commonEnabled` | `bool? commonEnabled` | Holds the `commonEnabled` property or configuration state. |
| `properties` | `List<MultiEditComponentProperty> properties` | Holds the `properties` property or configuration state. |

### `class MultiEditView`

`MultiEditView`: shadcn_flutter UI component rendering interface elements and listening to interactions.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `isMixedVisible` | `bool isMixedVisible` | Holds the `isMixedVisible` property or configuration state. |
| `commonVisible` | `bool? commonVisible` | Holds the `commonVisible` property or configuration state. |
| `isMixedLocked` | `bool isMixedLocked` | Holds the `isMixedLocked` property or configuration state. |
| `commonLocked` | `bool? commonLocked` | Holds the `commonLocked` property or configuration state. |
| `locationMixed` | `List<bool> locationMixed` | Holds the `locationMixed` property or configuration state. |
| `locationCommon` | `List<double> locationCommon` | Holds the `locationCommon` property or configuration state. |
| `rotationMixed` | `List<bool> rotationMixed` | Holds the `rotationMixed` property or configuration state. |
| `rotationCommon` | `List<double> rotationCommon` | Holds the `rotationCommon` property or configuration state. |
| `scaleMixed` | `List<bool> scaleMixed` | Holds the `scaleMixed` property or configuration state. |
| `scaleCommon` | `List<double> scaleCommon` | Holds the `scaleCommon` property or configuration state. |
| `components` | `List<MultiEditComponentBlock> components` | Holds the `components` property or configuration state. |

### `class MultiEditService`

`MultiEditService`: Service class encapsulating business logic, file I/O, or engine processing.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `computeMultiEditView` | `static MultiEditView computeMultiEditView(List<EditorActorNode> actors)` | Executes `computeMultiEditView` operation. |

## `lib/ui/features/details/models/component_property_registry.dart`

### `enum PropertyEditorType`

`PropertyEditorType`: Enumeration listing system options and state constants.

### `class PropertyDescriptor`

`PropertyDescriptor`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `id` | `String id` | Holds the `id` property or configuration state. |
| `label` | `String label` | Holds the `label` property or configuration state. |
| `group` | `String group` | Holds the `group` property or configuration state. |
| `editor` | `PropertyEditorType editor` | Holds the `editor` property or configuration state. |
| `unit` | `String? unit` | Holds the `unit` property or configuration state. |
| `min` | `double? min` | Holds the `min` property or configuration state. |
| `max` | `double? max` | Holds the `max` property or configuration state. |
| `defaultValue` | `dynamic defaultValue` | Holds the `defaultValue` property or configuration state. |
| `enumValues` | `List<String>? enumValues` | Holds the `enumValues` property or configuration state. |
| `type` | `String? type` | Holds the `type` property or configuration state. |

### `class ComponentDescriptor`

`ComponentDescriptor`: Actor component providing spatial 3D transform, visual mesh, lighting, or movement capability.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `type` | `String type` | Holds the `type` property or configuration state. |
| `icon` | `IconData? icon` | Holds the `icon` property or configuration state. |
| `sections` | `List<String> sections` | Holds the `sections` property or configuration state. |
| `properties` | `List<PropertyDescriptor> properties` | Holds the `properties` property or configuration state. |

### `class ComponentPropertyRegistry`

`ComponentPropertyRegistry`: Actor component providing spatial 3D transform, visual mesh, lighting, or movement capability.

## `lib/ui/features/details/models/editor_component_node.dart`

### `class EditorComponentNode`

`EditorComponentNode`: Actor component providing spatial 3D transform, visual mesh, lighting, or movement capability.

**Constructors:**
- `EditorComponentNode.fromMap(Map<String, dynamic> map)`: Initializes `EditorComponentNode.fromMap(Map<String, dynamic> map)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `id` | `String id` | Holds the `id` property or configuration state. |
| `type` | `String type` | Holds the `type` property or configuration state. |
| `name` | `String name` | Holds the `name` property or configuration state. |
| `enabled` | `bool enabled` | Holds the `enabled` property or configuration state. |
| `properties` | `Map<String, dynamic> properties` | Holds the `properties` property or configuration state. |
| `toMap` | `Map<String, dynamic> toMap()` | Executes `toMap` operation. |

## `lib/ui/features/details/services/blueprint_collision_overrides.dart`

### `abstract final class BlueprintCollisionOverrides`

A placed Blueprint actor's per-instance collision, as the level Details edits it: instance overrides of a component's Collision section.

The class's collision components come from its Blueprint document; an edit stores an [EditorComponentNode] in the actor's `components` (saved in the level `.lmas` `metadata.actors[]`) with the component's type and name, [componentIdKey] naming the Blueprint component, and the collision JSON keys. Play-In-Editor applies it to the instance's built component ([applyTo]); keys an override lacks keep the class's values.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `componentIdKey` | `static const String componentIdKey` | The override node property naming the Blueprint component it overrides. |
| `overrideId` | `static String overrideId(String actorId, String componentId)` | The id of [actorId]'s override of Blueprint component [componentId]. |
| `isOverride` | `static bool isOverride(EditorComponentNode node)` | Whether [node] is an instance override (not a component of its own). |
| `documentOf` | `static LuminaBlueprintDocument? documentOf(String projectDir, String path)` | The Blueprint document at [path] (project-relative) in [projectDir]; cached until the file changes. Null when it cannot be read. |
| `collisionComponentsOf` | `static List<LuminaBlueprintComponent> collisionComponentsOf(EditorActorNode actor, String projectDir)` | The collision components of placed Blueprint [actor]'s class, in document order; empty for any other actor. |
| `overrideOf` | `static EditorComponentNode? overrideOf(EditorActorNode actor, String componentId)` | [actor]'s override of Blueprint component [componentId], if any. |
| `collisionOf` | `static Map<String, dynamic> collisionOf(EditorActorNode actor, LuminaBlueprintComponent component)` | The collision JSON the level Details shows for [component] of [actor]: the class's keys with the instance override on top. |
| `physicsComponentsOf` | `static List<LuminaBlueprintComponent> physicsComponentsOf(EditorActorNode actor, String projectDir)` | The components of placed Blueprint [actor]'s class with a Physics section: collision shapes and static meshes. |
| `physicsOf` | `static Map<String, dynamic> physicsOf(EditorActorNode actor, LuminaBlueprintComponent component)` | The physics JSON the level Details shows for [component] of [actor]: the class's `physics` map with the instance override's keys on top. |
| `baseOf` | `static LuminaCollisionProfile baseOf(LuminaBlueprintDocument? doc, LuminaBlueprintComponent component)` | [component]'s built-in setup in [doc]: a Character's root capsule is Pawn, anything else lumina's default. |
| `applyTo` | `static int applyTo(LuminaBlueprintInstance instance, EditorActorNode actor)` | Applies [actor]'s overrides to [instance]'s built collision components (Play-In-Editor, before the actor is registered). |

## `lib/ui/features/details/widgets/actor_material_section.dart`

### `class ActorMaterialSection`

The Details panel's Material section of a placed mesh or basic shape: the material asset drawn on every section of it (in the level viewport, in Play and in the built game), picked with the shared searchable [AssetPickerSelect]; clearing it gives the mesh its own materials back. One undo step per pick. A material that cannot be drawn (not compiled, not found) is named under the picker.

**Constructors:**

- `const ActorMaterialSection({super.key, required this.viewModel, required this.actor})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `viewModel` | `final EditorViewModel viewModel` |  |
| `actor` | `final EditorActorNode actor` |  |
| `appliesTo` | `static bool appliesTo(EditorActorNode actor)` | A placed mesh or basic shape (`LuminaLevelActorMaterial.actorTypes`), not a Blueprint. |

## `lib/ui/features/details/widgets/actor_mesh_section.dart`

### `class ActorMeshSection`

The Details panel's Static Mesh (or Skeletal Mesh) section of a placed mesh actor: the mesh it renders, picked with the shared searchable [AssetPickerSelect]; a pick swaps the geometry as one undo step.

**Constructors:**

- `const ActorMeshSection({super.key, required this.viewModel, required this.actor})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `viewModel` | `final EditorViewModel viewModel` |  |
| `actor` | `final EditorActorNode actor` |  |
| `appliesTo` | `static bool appliesTo(EditorActorNode actor)` | A placed mesh: it renders a mesh asset of the project (not a Blueprint, primitive or landscape, which draw something else). |


## `lib/ui/features/details/widgets/actor_shape_section.dart`

### `class ActorShapeSection`

The Details panel's Shape section of a basic shape (`Primitive`): its shape, its size and its colour, kept on the actor's `LuminaProceduralMeshComponent`. Sizes are centimetres, Z up like the Transform above them: Size Z is the height, Size Y the depth along Y (a plane uses X and Y). Each commit is one undo step and redraws the shape in the viewport.

**Constructors:**

- `const ActorShapeSection({super.key, required this.viewModel, required this.actor})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `viewModel` | `final EditorViewModel viewModel` |  |
| `actor` | `final EditorActorNode actor` |  |
| `componentType` | `static const String componentType` | `LuminaProceduralMeshComponent`. |
| `shapes` | `static const List<String> shapes` | `box`, `plane`, `sphere`, `cylinder`. |
| `appliesTo` | `static bool appliesTo(EditorActorNode actor)` | A placed basic shape (not a Blueprint). |


## `lib/ui/features/launcher/services/installed_template_repository.dart`

### `class InstalledGameTemplate`

A game template installed into `<config>/templates/<Folder>/`, usually from the Lumina Marketplace.

The folder is a Lumina project tree in the game template archive format: `template.json` and/or the source project's `.lmproject`, `contents/`, optionally `lib/`, `pubspec.yaml` and a `thumbnail.png`, plus the `LICENSE-<Listing>.txt` notice the installer wrote beside them.

**Constructors:**

- `const InstalledGameTemplate({required this.folderName, required this.dir, required this.title, required this.description, required this.engineVersion, this.thum...`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `folderName` | `final String folderName` | The folder under `<config>/templates/`. |
| `dir` | `final String dir` | The absolute template folder. |
| `title` | `final String title` |  |
| `description` | `final String description` |  |
| `engineVersion` | `final String engineVersion` | The engine version the template was made with (`template.json` `engine_version`, else the `.lmproject`'s), or ''. |
| `thumbnailPath` | `final String? thumbnailPath` | The screenshot shown on the template's card, or null. |
| `lmprojectPath` | `final String? lmprojectPath` | The source project's manifest, or null for a template that ships only `template.json` and `contents/`. |
| `record` | `final MarketplaceInstallRecord? record` | The Marketplace install record (`<config>/marketplace/licenses.json`), or null for a folder that was copied in by hand. |
| `declaredPublisher` | `final String declaredPublisher` | `template.json` `publisher` / `version`, for hand-copied templates. |
| `declaredVersion` | `final String declaredVersion` |  |
| `id` | `String get id` | What the Create Project dialog selects (`marketplace:<Folder>`). |
| `publisher` | `String get publisher` |  |
| `version` | `String get version` |  |
| `licenseLabel` | `String get licenseLabel` | The listing's licenses as SPDX ids (`CC-BY-4.0 + MIT`), or ''. |
| `licenseNotice` | `File? get licenseNotice` | The `LICENSE-<Listing>.txt` notice the installer wrote, when it exists. |
| `canUninstall` | `bool get canUninstall` | Only Marketplace installs are removed from the launcher (through [MarketplaceInstaller.uninstall]); a hand-copied folder is the user's. |

### `class InvalidTemplateFolder`

A template folder that was skipped, and why.

**Constructors:**

- `const InvalidTemplateFolder(this.path, this.reason)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `path` | `final String path` |  |
| `reason` | `final String reason` |  |

### `class InstalledTemplateRepository`

Lists the game templates installed under `<config>/templates/`.

A folder is a template when it passes the shared game template check (`checkGameTemplate` in lumina_marketplace_shared), the same rules the Marketplace server applies to an upload: files under `contents/`, a `template.json` with a title or exactly one `.lmproject` that parses, an existing thumbnail when one is named, no platform or build folders, and a pubspec whose path dependencies stay inside the template. Anything else is left out of the list and reported once in the Output Log with the check's reasons.

**Constructors:**

- `InstalledTemplateRepository({required this.dirs, EngineLoggerService? logger})`
- `factory InstalledTemplateRepository.forConfigDir(Directory? configDir)`: [MarketplaceInstallDirs.resolve] for [configDir] (null: the editor's config directory).

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `dirs` | `final MarketplaceInstallDirs dirs` |  |
| `thumbnailNames` | `static const List<String> thumbnailNames` |  |
| `invalid` | `List<InvalidTemplateFolder> get invalid` | The folders the last [scan] skipped. |
| `scan` | `List<InstalledGameTemplate> scan()` | The valid templates, sorted by title. |
| `byId` | `InstalledGameTemplate? byId(String id)` |  |
| `uninstall` | `bool uninstall(InstalledGameTemplate template)` | Removes a Marketplace-installed [template] and its licenses.json entry. |

**Top-level functions and variables:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `kInstalledTemplateIdPrefix` | `const String kInstalledTemplateIdPrefix` | The `id` prefix of a folder template in the Create Project dialog; the built-in templates use their bare catalog ids (`blank_3d`, …). |

## `lib/ui/features/launcher/services/project_editor_resolver.dart`

### `sealed class ProjectEditorDecision`

What the launcher does with a project on Open.

**Constructors:**

- `const ProjectEditorDecision()`

### `class OpenInPlace`

The stock editor opens it: per-project editors are off (Editor Preferences) and the project has no code plugins.

**Constructors:**

- `const OpenInPlace()`

### `class ExecCached`

The project's editor is built and current: exec it.

**Constructors:**

- `const ExecCached(this.entry)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `entry` | `final EditorBuildEntry entry` |  |

### `class NeedsBuild`

The host exists but its fingerprint is not cached (stale or never built here): build it behind the splash.

**Constructors:**

- `const NeedsBuild(this.reason, this.plugins)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `reason` | `final String reason` | "editor source changed (lumina_ui)", "plugin lumina_plugin_miniai changed", …. |
| `plugins` | `final List<LuminaPluginDescriptor> plugins` |  |
| `pluginNames` | `List<String> get pluginNames` |  |

### `class MissingBinary`

Code plugins are enabled but the host is absent (an older project, a fresh clone, another OS): ask before building.

**Constructors:**

- `const MissingBinary(this.reason, this.plugins)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `reason` | `final String reason` |  |
| `plugins` | `final List<LuminaPluginDescriptor> plugins` |  |
| `pluginNames` | `List<String> get pluginNames` |  |

### `class ProjectEditorResolver`

Decides how a project opens: in place, in its cached project editor, or after a build. Scans the same plugin roots as the editor.

**Constructors:**

- `ProjectEditorResolver({String? engineRoot, EditorBuildCache? cache, EditorHostGeneratorService? generator, this.mode = 'release', String? platform, Future<Flutt...`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `engineRoot` | `final String engineRoot` |  |
| `cache` | `final EditorBuildCache cache` |  |
| `generator` | `final EditorHostGeneratorService generator` |  |
| `mode` | `final String mode` | `release` (default) or `debug` (Editor Preferences → Project Editor Builds). |
| `platform` | `final String platform` |  |
| `flutterInfo` | `final Future<FlutterToolInfo> Function() flutterInfo` |  |
| `scanRoots` | `final List<PluginScanRoot> Function(String projectDir) scanRoots` |  |
| `everyProject` | `final bool everyProject` | Every project opens in its own project editor, code plugins or not (Editor Preferences › Project Editor Builds; default on). Off, a plugin-less project opens in the stock editor. |
| `currentEngine` | `final Future<EngineIdentity> Function() currentEngine` | The running engine's identity (default: read from [engineRoot]). |
| `enabledCodePlugins` | `Future<List<LuminaPluginDescriptor>> enabledCodePlugins(String projectDir) async` | The project's enabled plugins that contribute editor code, as found on the plugin roots (an enabled plugin that is not installed is skipped). |
| `inputsFor` | `Future<EditorHostInputs> inputsFor(String projectDir, List<LuminaPluginDescriptor> plugins) async` | The inputs of the project's host build (see `fingerprint`). |
| `resolve` | `Future<ProjectEditorDecision> resolve(String projectDir, {bool rebuild = false}) async` |  |
| `staleReason` | `static String staleReason(String hostDir, Map<String, String> current)` | What changed since the host's last build, from its stamp. |
| `readStamp` | `static Map<String, dynamic>? readStamp(String hostDir)` |  |
| `staleSelfCheck` | `Future<List<String>> staleSelfCheck(String projectDir, String compiledFingerprint) async` | A project editor's self-check: the reasons its compiled-in [compiledFingerprint] no longer matches the project's current inputs (empty when current, or when this is not a built project editor). |
| `engineUpdate` | `Future<EditorEngineUpdate?> engineUpdate(String projectDir, {EngineIdentity? current, String? engineRoot}) async` | Whether the project's copy of the engine source comes from another engine than the one at [engineRoot] (default: this resolver's, the running Studio's), whose identity is [current] (default: [currentEngine], or read from [engineRoot]); the project's `engine_version` is the fallback for copies made before stamps recorded their engine. Null when there is no copy or it is current. |

## `lib/ui/features/launcher/services/template_project_creator.dart`

### `class TemplateProjectCreator`

Creates a project from an installed folder template, the way [ProjectRepository.createProjectStream] creates one from a built-in template:

1. `flutter create` into `<location>/<name>/` (the platform folders a template archive does not carry); 2. the template's project tree — `contents/`, `lib/` and the rest, minus its own manifests and notice — copied over it; 3. its `pubspec.yaml` (dependencies, assets) renamed to the new package, with the engine as a git dependency, linked to this machine's engine checkout by [ProjectEngineLink] (a gitignored `pubspec_overrides.yaml` and the native hooks' settings); 4. every `package:<template>/` import in `lib/` renamed; 5. `flutter pub get`; 6. the manifest written as `<name>.lmproject` (the source project's settings, input, maps and modes under the new name), and the normal code generation: `lib/main.dart` (its game class is named after the project), the Blueprint registry and any level without generated code; 7. the template's license notice kept in `contents/Marketplace/` (`LICENSE-<Listing>.txt` and a `licenses.json` entry), and the project added to the recent projects.

A failure removes the half-created folder, as the built-in pipeline does.

**Constructors:**

- `TemplateProjectCreator(this.projectRepo, {DartCodeGeneratorService? codegen, EngineLoggerService? logger})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `projectRepo` | `final ProjectRepository projectRepo` |  |
| `create` | `Stream<ProjectCreationProgress> create({required InstalledGameTemplate template, required String projectName,...` |  |
| `rewritePubspec` | `static String rewritePubspec(String yaml, {required String name})` | [yaml] with `name: [name]` and the `lumina:` dependency in its git form (replacing a template's `path:` one, added when missing) and no `hooks:` block; every other dependency and asset entry is kept. |
| `renamePackageImports` | `static int renamePackageImports(String projectDir, String from, String to)` | Rewrites `package:[from]/` to `package:[to]/` in every Dart file under `lib/` and `test/` of [projectDir]; returns how many files changed. |

## `lib/ui/features/launcher/view_models/editor_build_view_model.dart`

### `enum EditorBuildSplashState`

**Values:**

- `running`
- `failed`
- `succeeded`
- `cancelled`

### `class EditorBuildViewModel`

Drives [EditorBuildSplash] from a real [EditorBuildJob]: the status line, the progress bar, the log tail and the failure state.

**Constructors:**

- `EditorBuildViewModel({required this.projectName, required this.projectDir, required this.startBuild, this.engineVersion = '0.0.1', this.hasPlugins = true,})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `projectName` | `final String projectName` |  |
| `projectDir` | `final String projectDir` |  |
| `engineVersion` | `final String engineVersion` |  |
| `startBuild` | `final EditorBuildJob Function() startBuild` | Starts (and on Retry restarts) the build. |
| `hasPlugins` | `final bool hasPlugins` | Whether the project enables code plugins: a failed build then offers "Open without plugins", otherwise "Open in this editor". |
| `logTailLines` | `static const int logTailLines` |  |
| `state` | `EditorBuildSplashState get state` |  |
| `phase` | `EditorBuildPhase get phase` |  |
| `fraction` | `double get fraction` |  |
| `percent` | `int get percent` |  |
| `logPath` | `String? get logPath` |  |
| `outcome` | `EditorBuildOutcome? get outcome` |  |
| `showLog` | `bool get showLog` |  |
| `logTail` | `List<String> get logTail` |  |
| `statusText` | `String get statusText` | `NN% - <phase message>`, or the failure line. |
| `start` | `Future<EditorBuildOutcome> start()` | Completes with the outcome of the current run. |
| `toggleLog` | `void toggleLog()` |  |
| `cancel` | `void cancel()` |  |
| `openLogFile` | `Future<void> openLogFile() async` | Opens the full build log with the OS's default handler. |

## `lib/ui/features/launcher/views/editor_build_splash.dart`

### `class EditorBuildSplash`

The project editor build splash — key art, "Lumina Studio", the engine and project line, a `NN% - <phase>` status line and a 2 px bar along the bottom edge; a log tail and Cancel on hover; on failure `Open without plugins` / `Retry` / `Open log file` / `Close`.

**Constructors:**

- `const EditorBuildSplash({super.key, required this.viewModel, required this.onSucceeded, required this.onOpenWithoutPlugins, required this.onClose, this.manageWi...`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `viewModel` | `final EditorBuildViewModel viewModel` |  |
| `onSucceeded` | `final void Function(EditorBuildViewModel viewModel) onSucceeded` | The build finished: exec the project editor. |
| `onOpenWithoutPlugins` | `final VoidCallback onOpenWithoutPlugins` | Open the project in this (stock) editor without its code plugins. |
| `onClose` | `final VoidCallback onClose` | Back to the launcher (Cancel, or Close after a failure). |
| `manageWindow` | `final bool manageWindow` | Switch the OS window to the 720×400 frameless splash window (off in widget tests, which have no native window). |
| `manageNativeWindow` | `static bool manageNativeWindow` | Whether the launcher lets the splash resize the native window. A smoke run that records the splash inside its fixed-size test window turns it off; widget tests (no native window) never manage it. |
| `windowSize` | `static const Size windowSize` |  |
| `splashArt` | `static const String splashArt` |  |

## `lib/ui/features/launcher/views/installed_template_widgets.dart`

### `class InstalledTemplateThumbnail`

The pieces the launcher shows an installed game template with — its screenshot, license badge and the "publisher · version" line — in the Create Project dialog ([InstalledTemplateOption]) and the Templates pane ([InstalledTemplateCard]). The template's screenshot, or a placeholder icon when it has none.

**Constructors:**

- `const InstalledTemplateThumbnail({super.key, required this.template, required this.width, required this.height, this.radius = 4})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `template` | `final InstalledGameTemplate template` |  |
| `width` | `final double width` |  |
| `height` | `final double height` |  |
| `radius` | `final double radius` |  |

### `class InstalledTemplateLicenseBadge`

The listing's licenses (`CC-BY-4.0 + MIT`); the tooltip names them and says when attribution is required.

**Constructors:**

- `const InstalledTemplateLicenseBadge({super.key, required this.template})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `template` | `final InstalledGameTemplate template` |  |

### `class InstalledTemplateOption`

A selectable installed template row in the Create Project dialog, with Uninstall for Marketplace installs.

**Constructors:**

- `const InstalledTemplateOption({super.key, required this.template, required this.selected, required this.onTap, required this.onUninstall,})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `template` | `final InstalledGameTemplate template` |  |
| `selected` | `final bool selected` |  |
| `onTap` | `final VoidCallback onTap` |  |
| `onUninstall` | `final VoidCallback onUninstall` |  |

### `class InstalledTemplateCard`

An installed template's card in the launcher's Templates pane.

**Constructors:**

- `const InstalledTemplateCard({super.key, required this.template, required this.width, required this.onUse, required this.onUninstall,})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `template` | `final InstalledGameTemplate template` |  |
| `width` | `final double width` |  |
| `onUse` | `final VoidCallback onUse` |  |
| `onUninstall` | `final VoidCallback onUninstall` |  |

**Top-level functions and variables:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `installedTemplateByline` | `String installedTemplateByline(InstalledGameTemplate t)` | `by <publisher> · v<version>`, leaving out what is unknown. |

## `lib/ui/features/launcher/views/launcher_recent_projects_pane.dart`

### `class LauncherRecentProjectsPane`

The launcher's Recent Projects pane: the searchable project cards with their Open / Locate… actions and context menu (rename, reveal, duplicate, remove from the hub, delete from disk).

**Constructors:**

- `const LauncherRecentProjectsPane({super.key, required this.viewModel, required this.onOpenProject, required this.onNewProject,})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `viewModel` | `final LauncherViewModel viewModel` |  |
| `onOpenProject` | `final void Function(LuminaProject project, String projectDir) onOpenProject` | Opens [project] (in [projectDir]) in the editor. |
| `onNewProject` | `final VoidCallback onNewProject` | Opens the Create Project dialog (the empty state's button). |

## `lib/ui/features/launcher/views/launcher_settings_panes.dart`

### `class LauncherEngineVersionsPane`

The launcher's Engine Versions pane: the running engine, its render backend and the graphics device in use.

**Constructors:**

- `const LauncherEngineVersionsPane({super.key, required this.viewModel})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `viewModel` | `final LauncherViewModel viewModel` |  |

### `class LauncherSettingsPane`

The launcher's Settings pane: the default projects directory and the graphics device.

**Constructors:**

- `const LauncherSettingsPane({super.key, required this.viewModel})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `viewModel` | `final LauncherViewModel viewModel` |  |

### `class LauncherSettingRow`

One label / value row of a launcher info card.

**Constructors:**

- `const LauncherSettingRow({super.key, required this.label, required this.value})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `label` | `final String label` |  |
| `value` | `final String value` |  |

## `lib/ui/features/launcher/views/launcher_templates_pane.dart`

### `class LauncherTemplatesPane`

The launcher's Templates pane: the built-in templates (`GameTemplateCatalog`) and, below them, the game templates installed from the Marketplace. "Use Template" opens the Create Project dialog with that template selected.

**Constructors:**

- `const LauncherTemplatesPane({super.key, required this.viewModel, required this.onUseTemplate})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `viewModel` | `final LauncherViewModel viewModel` |  |
| `onUseTemplate` | `final void Function(String templateId) onUseTemplate` | Opens the Create Project dialog on the template with this id. |

## `lib/ui/features/launcher/views/missing_editor_binary_dialog.dart`

### `enum MissingBinaryChoice`

The answer to [MissingEditorBinaryDialog].

**Values:**

- `buildAndOpen`
- `openWithoutPlugins`
- `cancel`

### `class MissingEditorBinaryDialog`

A project with code plugins whose editor was never built on this machine (an older project, a fresh clone, another OS): the modules are missing or built with a different engine version, so it offers to rebuild them now.

**Constructors:**

- `const MissingEditorBinaryDialog({super.key, required this.projectName, required this.pluginNames, required this.reason})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `projectName` | `final String projectName` |  |
| `pluginNames` | `final List<String> pluginNames` |  |
| `reason` | `final String reason` |  |
| `show` | `static Future<MissingBinaryChoice> show(BuildContext context, {required String projectName, required List<Stri...` |  |

## `lib/ui/features/launcher/services/project_editor_update.dart`

### `class ProjectEditorUpdatePrompts`

The projects whose "Update this project's editor?" question the user answered with "Don't ask again for this version", on this machine: per project folder, the engine ([EngineIdentity.key]) not to ask about again. A newer engine asks again. Kept in the config folder (`project_editor_updates.json`), never in the shared `.lmproject`.

**Constructors:**

- `ProjectEditorUpdatePrompts({this.configDir})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `configDir` | `final Directory? configDir` |  |
| `fileName` | `static const String fileName` | `project_editor_updates.json`. |
| `projectKey` | `static String projectKey(String projectDir)` | One key per project folder, whatever the spelling of its path. |
| `isDismissed` | `bool isDismissed(String projectDir, EngineIdentity engine)` | Whether the user asked not to be asked about [engine] for [projectDir]. |
| `dismiss` | `void dismiss(String projectDir, EngineIdentity engine)` | Don't ask about [engine] for [projectDir] again. |

### `class LuminaStudioRecord`

The last Lumina Studio (the stock editor) that started on this machine: its executable, engine root and engine. A project editor started on its own reads it to see whether a newer Studio is installed and to hand the project to it (`lumina_studio.json` in the config folder).

**Constructors:**

- `const LuminaStudioRecord({required this.executable, required this.engineRoot, required this.engine})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `executable / engineRoot / engine` | `final String executable · final String engineRoot · final EngineIdentity engine` |  |
| `read` | `static LuminaStudioRecord? read({Directory? configDir})` | The record; null when there is none or it is unreadable. |
| `write` | `void write({Directory? configDir})` |  |
| `recordThisStudio` | `static Future<LuminaStudioRecord?> recordThisStudio({Directory? configDir}) async` | Records the running stock editor, when it is one: the real `lumina_ui` binary, not a project editor and not a test run. The launcher calls it when it starts. |

## `lib/ui/features/launcher/views/project_editor_update_dialog.dart`

### `enum ProjectEditorUpdateChoice`

The answers of [ProjectEditorUpdateDialog].

**Values:**

- `update`
- `openWithOldEditor`
- `cancel`

### `class ProjectEditorUpdateAnswer`

What the user chose, and whether "Don't ask again for this version" was ticked (it applies to [ProjectEditorUpdateChoice.openWithOldEditor]).

**Constructors:**

- `const ProjectEditorUpdateAnswer(this.choice, {this.dontAskAgain = false})`

### `class ProjectEditorUpdateDialog`

A project whose editor was set up with another Lumina than the one opening it: "Update this project's editor?" — "<Project> was set up with Lumina <old>; this Studio is Lumina <new>. Update the project's editor to Lumina <new>? Its copy of the engine source is replaced and the editor is rebuilt; edits made inside .lumina/editor are lost." Update, Open with the old editor, Cancel, and a "Don't ask again for this version" checkbox. shadcn_flutter only.

**Constructors:**

- `const ProjectEditorUpdateDialog({super.key, required this.projectName, required this.fromLabel, required this.toLabel})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `show` | `static Future<ProjectEditorUpdateAnswer> show(BuildContext context, {required String projectName, required String fromLabel, required String toLabel}) async` | Shows the dialog; closing it without an answer is Cancel. |
| `lumina` | `static String lumina(String label)` | "Lumina 0.0.1-dev.6", or "an older engine" as it is. |

---

[Previous: Main editor: view model and services (continued)](main-editor-state-continued.md) | [Up: lumina_ui (Lumina Studio)](index.md) | [Next: Plugin manager](plugin-manager.md)

[Türkçe](../../../tr/lumina_ui/sub-editors/blueprint.md)

# Blueprint editor

The Blueprint editor for actor classes: the sub-editor view and view model, the component tree, the event graph and the component registry that describes which components and properties can be added. File paths are relative to the `lumina_ui/` package directory.

**On this page:**

- [`lib/ui/features/sub_editors/views/blueprint/component_tree.dart`](#libuifeaturessub_editorsviewsblueprintcomponent_treedart)
- [`lib/ui/features/sub_editors/views/blueprint/event_graph.dart`](#libuifeaturessub_editorsviewsblueprintevent_graphdart)
- [`lib/ui/features/sub_editors/views/blueprint/blueprint_sub_editor.dart`](#libuifeaturessub_editorsviewsblueprintblueprint_sub_editordart)
- [`lib/ui/features/sub_editors/view_models/blueprint_editor_view_model.dart`](#libuifeaturessub_editorsview_modelsblueprint_editor_view_modeldart)
- [`lib/ui/features/sub_editors/models/blueprint_component_registry.dart`](#libuifeaturessub_editorsmodelsblueprint_component_registrydart)

## `lib/ui/features/sub_editors/views/blueprint/component_tree.dart`

### `class BlueprintComponentTree`

The Blueprint editor's component hierarchy, built like the Level Editor's World Outliner so the two panels look and behave alike: the same header (`COMPONENTS` in `EditorTypography.panelHeading` on `EditorColors.cardHeader`, `EditorDensity.panelHeaderHeight` tall, Expand All / Collapse All and a primary `+ Add` chip that opens the Add Component dialog), the same search field (`Search components...`, a flat filtered list while it has text), the editor background, and 24 px rows (`EditorDensity.rowHeight`) indented by `EditorDensity.indentStep` per depth with the chevron, eye and lock toggles, the type icon, the name, small `Inherited` / `Overridden` / `ROOT` chips and the short type on the right. Selection is the outliner's (`EditorColors.selectionBg` and a primary left bar). Actor (non-scene) components follow under `ACTOR COMPONENTS`.

- **Attach by drag and drop.** A scene component that is not the root and not inherited is dragged onto another scene component to attach to it (the target row is highlighted as an outliner drop target; the target expands), or onto the empty area below the rows to attach to the root. A drop that would make a cycle, onto a non-scene component or onto the current parent is refused. Each attach is one undo step and keeps the component's relative transform.
- **Right-click menu.** Rename, Duplicate, Attach To (every scene component it may attach to; the root is labelled), Delete; rename and delete are disabled for an inherited component.
- **Inline rename.** Double-click a name (or Rename) to edit it in place; Enter or leaving the field applies it, Escape cancels; a name that is not a valid identifier or is taken turns red and the field stays open.

Row keys: `component_row_<id>`, `component_chevron_<id>`, `component_rename_field`, `components_search`, `components_empty_area`, `components_expand_all`, `components_collapse_all`, `add_component_button`. Rows live in `component_tree/rows.dart`, the Add Component dialog in `component_tree/add_component_dialog.dart`. Tests: `test/ui/blueprint_component_tree_outliner_test.dart`; smoke: `integration_test/smoke/blueprint_component_tree_smoke_test.dart`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `viewModel` | `BlueprintEditorViewModel viewModel` | The Blueprint editor whose components the tree shows and edits. |
| `createState` | `State<BlueprintComponentTree> createState() => _BlueprintComponentTreeSt...` | Creates the tree's state (collapsed rows, search text, inline rename). |

### `class _BlueprintComponentTreeState`

The tree's state: which rows are collapsed, the search text and the inline rename; it rebuilds whenever the view model changes.

### `class _AddComponentDialog`

`_AddComponentDialog`: shadcn_flutter UI component rendering interface elements and listening to interactions.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `viewModel` | `BlueprintEditorViewModel viewModel` | Holds the `viewModel` property or configuration state. |
| `onClose` | `VoidCallback onClose` | Holds the `onClose` property or configuration state. |
| `createState` | `State<_AddComponentDialog> createState() => _AddComponentDialogState()` | Creates, configures, and returns a new `State` instance or associated GPU resource. |

### `class _AddComponentDialogState`

`_AddComponentDialogState`: shadcn_flutter UI component rendering interface elements and listening to interactions.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `dispose` | `void dispose()` | Releases native FFI pointers, event subscriptions, and allocated memory. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

## `lib/ui/features/sub_editors/views/blueprint/event_graph.dart`

### `class BlueprintEventGraph`

`BlueprintEventGraph`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `viewModel` | `BlueprintEditorViewModel viewModel` | Holds the `viewModel` property or configuration state. |
| `createState` | `State<BlueprintEventGraph> createState() => BlueprintEventGraphState()` | Creates, configures, and returns a new `State` instance or associated GPU resource. |

### `class BlueprintEventGraphState`

`BlueprintEventGraphState`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `openNodePalette` | `void openNodePalette(Offset screenPosition)` | Setter mutator assigning a new value to `openNodePalette`. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

### `class _NodePaletteDialog`

`_NodePaletteDialog`: shadcn_flutter UI component rendering interface elements and listening to interactions.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `onSelect` | `ValueChanged<String> onSelect` | Holds the `onSelect` property or configuration state. |
| `onClose` | `VoidCallback onClose` | Holds the `onClose` property or configuration state. |
| `createState` | `State<_NodePaletteDialog> createState() => _NodePaletteDialogState()` | Creates, configures, and returns a new `State` instance or associated GPU resource. |

### `class _NodePaletteDialogState`

`_NodePaletteDialogState`: shadcn_flutter UI component rendering interface elements and listening to interactions.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `dispose` | `void dispose()` | Releases native FFI pointers, event subscriptions, and allocated memory. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

### `class _EventGraphPainter`

`_EventGraphPainter`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `panOffset` | `Offset panOffset` | Holds the `panOffset` property or configuration state. |
| `zoomScale` | `double zoomScale` | Holds the `zoomScale` property or configuration state. |
| `nodes` | `List<BlueprintGraphNode> nodes` | Holds the `nodes` property or configuration state. |
| `wires` | `List<BlueprintGraphWire> wires` | Holds the `wires` property or configuration state. |
| `pinPositions` | `Map<String, Offset> pinPositions` | Holds the `pinPositions` property or configuration state. |
| `dragStart` | `Offset? dragStart` | Holds the `dragStart` property or configuration state. |
| `dragEnd` | `Offset? dragEnd` | Holds the `dragEnd` property or configuration state. |
| `dragColor` | `Color dragColor` | Holds the `dragColor` property or configuration state. |
| `marqueeStart` | `Offset? marqueeStart` | Holds the `marqueeStart` property or configuration state. |
| `marqueeEnd` | `Offset? marqueeEnd` | Holds the `marqueeEnd` property or configuration state. |
| `paint` | `void paint(Canvas canvas, Size size)` | Executes `paint` operation. |
| `shouldRepaint` | `bool shouldRepaint(covariant _EventGraphPainter oldDelegate)` | Executes `shouldRepaint` operation. |

## `lib/ui/features/sub_editors/views/blueprint/blueprint_sub_editor.dart`

### `class BlueprintSubEditor`

`BlueprintSubEditor`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `assetName` | `String assetName` | Holds the `assetName` property or configuration state. |
| `assetPath` | `String? assetPath` | Holds the `assetPath` property or configuration state. |
| `asset` | `LuminaAsset? asset` | Holds the `asset` property or configuration state. |
| `onClose` | `VoidCallback? onClose` | Holds the `onClose` property or configuration state. |
| `onBind` | `SubEditorBindCallback? onBind` | Holds the `onBind` property or configuration state. |
| `viewModel` | `BlueprintEditorViewModel? viewModel` | Holds the `viewModel` property or configuration state. |
| `createState` | `State<BlueprintSubEditor> createState() => _BlueprintSubEditorState()` | Creates, configures, and returns a new `State` instance or associated GPU resource. |

### `class _BlueprintSubEditorState`

`_BlueprintSubEditorState`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `initState` | `void initState()` | Executes `initState` operation. |
| `dispose` | `void dispose()` | Releases native FFI pointers, event subscriptions, and allocated memory. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

## `lib/ui/features/sub_editors/view_models/blueprint_editor_view_model.dart`

### `class BlueprintEditorViewModel`

`BlueprintEditorViewModel`: ChangeNotifier ViewModel managing UI state, user actions, and data binding for the view.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `assetPath` | `String assetPath` | Holds the `assetPath` property or configuration state. |
| `fileBasename` | `String get fileBasename` | Getter accessor returning the current value of `fileBasename`. |
| `document` | `BlueprintDocument get document` | Getter accessor returning the current value of `document`. |
| `selectedComponentId` | `String? get selectedComponentId` | Selects the target actor or asset. |
| `selectedNodeIds` | `Set<String> get selectedNodeIds` | Selects the target actor or asset. |
| `graphNodes` | `List<BlueprintGraphNode> get graphNodes` | Getter accessor returning the current value of `graphNodes`. |
| `graphWires` | `List<BlueprintGraphWire> get graphWires` | Getter accessor returning the current value of `graphWires`. |
| `isDirty` | `bool get isDirty` | Checks current state or capability and returns a boolean value. |
| `availableSkeletalMeshes` | `List<RealAssetInfo> get availableSkeletalMeshes` | Getter accessor returning the current value of `availableSkeletalMeshes`. |
| `availableStaticMeshes` | `List<RealAssetInfo> get availableStaticMeshes` | Getter accessor returning the current value of `availableStaticMeshes`. |
| `availableAnimations` | `List<RealAssetInfo> get availableAnimations` | Getter accessor returning the current value of `availableAnimations`. |
| `availableMaterials` | `List<RealAssetInfo> get availableMaterials` | Getter accessor returning the current value of `availableMaterials`. |
| `previewGlbMesh` | `GlbMeshData? get previewGlbMesh` | Getter accessor returning the current value of `previewGlbMesh`. |
| `previewMeshPath` | `String? get previewMeshPath` | Getter accessor returning the current value of `previewMeshPath`. |
| `generatedDartCode` | `String get generatedDartCode` | Getter accessor returning the current value of `generatedDartCode`. |
| `setMeshForComponent` | `Future<void> setMeshForComponent(String componentId, String propField, S...` | Updates the `MeshForComponent` parameter and applies changes to the system. |
| `loadPreviewMesh` | `Future<void> loadPreviewMesh(String relativePath)` | Loads data from disk or memory buffer into the engine. |
| `compile` | `Future<bool> compile()` | Compiles this blueprint into a real Dart file in the active project. |
| `rootComponent` | `BlueprintComponentNode? get rootComponent` | Getter accessor returning the current value of `rootComponent`. |
| `getComponent` | `BlueprintComponentNode? getComponent(String id)` | Queries and returns the `Component` value or child object. |
| `isSceneComponent` | `bool isSceneComponent(String id)` | Checks current state or capability and returns a boolean value. |
| `selectComponent` | `void selectComponent(String? id)` | Selects the target actor or asset. |
| `getGraphNode` | `BlueprintGraphNode? getGraphNode(String id)` | Queries and returns the `GraphNode` value or child object. |
| `addGraphNode` | `BlueprintGraphNode? addGraphNode(String registryId, Offset position)` | Appends a new item to the collection or scene. |
| `removeGraphNode` | `bool removeGraphNode(String nodeId)` | Releases and safely disposes the specified `GraphNode` resource. |
| `removeSelectedGraphNodes` | `void removeSelectedGraphNodes()` | Releases and safely disposes the specified `SelectedGraphNodes` resource. |
| `removeGraphWire` | `bool removeGraphWire(String wireId)` | Releases and safely disposes the specified `GraphWire` resource. |
| `setPinLiteral` | `void setPinLiteral(String nodeId, String pinId, dynamic value)` | Updates the `PinLiteral` parameter and applies changes to the system. |
| `toggleSelectGraphNode` | `void toggleSelectGraphNode(String nodeId)` | Toggles the target feature or visibility on/off. |
| `selectGraphNodes` | `void selectGraphNodes(Set<String> nodeIds)` | Selects the target actor or asset. |
| `clearGraphSelection` | `void clearGraphSelection()` | Clears all elements from the collection or buffer. |
| `moveNodes` | `void moveNodes(Iterable<String> nodeIds, Offset delta)` | Setter mutator assigning a new value to `moveNodes`. |
| `load` | `Future<void> load()` | Loads data from disk or memory buffer into the engine. |
| `removeComponent` | `bool removeComponent(String id)` | Releases and safely disposes the specified `Component` resource. |
| `renameComponent` | `bool renameComponent(String id, String newName)` | Executes `renameComponent` operation. |
| `canReparent` | `bool canReparent(String childId, String? targetParentId)` | Whether scene component [childId] may be attached to [targetParentId] (null: the root). The root itself, an inherited or a non-scene component cannot move, and a component cannot go under itself or a descendant. |
| `reparent` | `bool reparent(String childId, String? newParentId)` | Attaches [childId] to [newParentId] (null: the root, never a second root) as one undo step, keeping its relative transform. |
| `canTransformComponent` | `bool canTransformComponent(String id)` | Whether the gizmo may move [id]: a scene component that is not the root and not a Character's capsule. |
| `isCharacterCapsule` | `bool isCharacterCapsule(String id)` | Whether [id] is a Character Blueprint's capsule: Play builds it as the character's own capsule, centred on the actor, so its transform is not authored; the Details panel shows a note (place the meshes relative to it: a mesh whose origin is at the feet goes at Z = −half height) instead of transform fields, and the gizmo is locked. |
| `transformLockReason` | `String? transformLockReason(String id)` | The gizmo's hint when [id] cannot move: the root's, or the Character capsule's; null when it can. |
| `duplicateComponent` | `BlueprintComponentNode? duplicateComponent(String id)` | Executes `duplicateComponent` operation. |
| `setProperty` | `void setProperty(String componentId, String propName, dynamic value)` | Updates the `Property` parameter and applies changes to the system. |
| `addVariable` | `void addVariable(String name, String type, String defaultValue)` | Appends a new item to the collection or scene. |
| `setClassDefault` | `void setClassDefault(String key, dynamic value)` | Updates the `ClassDefault` parameter and applies changes to the system. |
| `setParentClass` | `void setParentClass(String parentClass)` | Updates the `ParentClass` parameter and applies changes to the system. |
| `resetToDefaultComponents` | `void resetToDefaultComponents()` | Resets values or state back to defaults. |
| `save` | `Future<bool> save()` | Serializes and writes the current state or asset to disk. |

## `lib/ui/features/sub_editors/models/blueprint_component_registry.dart`

### `enum ComponentPropertyType`

`ComponentPropertyType`: Enumeration listing system options and state constants. `componentReference` names another component of the same Blueprint.

### `class ComponentPropertySchema`

`ComponentPropertySchema`: Actor component providing spatial 3D transform, visual mesh, lighting, or movement capability.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `group` | `String group` | Holds the `group` property or configuration state. |
| `name` | `String name` | Holds the `name` property or configuration state. |
| `dartField` | `String dartField` | Holds the `dartField` property or configuration state. |
| `type` | `ComponentPropertyType type` | Holds the `type` property or configuration state. |
| `defaultValue` | `dynamic defaultValue` | Holds the `defaultValue` property or configuration state. |
| `min` | `double min` | Holds the `min` property or configuration state. |
| `max` | `double max` | Holds the `max` property or configuration state. |
| `enumOptions` | `List<String> enumOptions` | Holds the `enumOptions` property or configuration state. |
| `referenceTypes` | `List<String> referenceTypes` | The component types a `componentReference` property may name. A `componentReference` row (Skeletal Mesh / Skinned Cloth **Pose From**) is a picker over the Blueprint's components of those types, leaving out the component itself and any that already follow it; stored as the component id (see [Character slots](../../lumina/character-slots.md)). |
| `assetTypes` | `List<AssetType> assetTypes` | The asset types an `assetReference` property takes: its Details picker offers only these (`BlueprintEditorViewModel.assetsOfTypes`; skeletal meshes also include older imports the name rules recognise). Every asset reference field of the built-in components names its types (a cloth's Cloth Settings: cloth settings; Texture: textures; Material / Material Override: materials; Mesh Asset: static and skeletal meshes). |

### `class ComponentTypeDescriptor`

`ComponentTypeDescriptor`: Actor component providing spatial 3D transform, visual mesh, lighting, or movement capability.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `typeName` | `String typeName` | Holds the `typeName` property or configuration state. |
| `displayName` | `String displayName` | Holds the `displayName` property or configuration state. |
| `category` | `String category` | Holds the `category` property or configuration state. |
| `isSceneComponent` | `bool isSceneComponent` | Holds the `isSceneComponent` property or configuration state. |
| `isAvailable` | `bool isAvailable` | Holds the `isAvailable` property or configuration state. |
| `gapReason` | `String? gapReason` | Holds the `gapReason` property or configuration state. |
| `properties` | `List<ComponentPropertySchema> properties` | Holds the `properties` property or configuration state. |

### `class BlueprintComponentRegistry`

`BlueprintComponentRegistry`: Actor component providing spatial 3D transform, visual mesh, lighting, or movement capability.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `getDescriptor` | `static ComponentTypeDescriptor? getDescriptor(String typeName)` | Queries and returns the `Descriptor` value or child object. |
| `getSchema` | `static List<ComponentPropertySchema> getSchema(String typeName)` | Queries and returns the `Schema` value or child object. |

---

[Previous: Audio editor](audio.md) | [Up: Sub-editors](index.md) | [Next: Blueprint editor (continued, part 1)](blueprint-continued.md)

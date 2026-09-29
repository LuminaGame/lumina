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

Real Component Hierarchy Tree for Blueprint Editor.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `viewModel` | `BlueprintEditorViewModel viewModel` | Holds the `viewModel` property or configuration state. |
| `createState` | `State<BlueprintComponentTree> createState() => _BlueprintComponentTreeSt...` | Creates, configures, and returns a new `State` instance or associated GPU resource. |

### `class _BlueprintComponentTreeState`

`_BlueprintComponentTreeState`: Actor component providing spatial 3D transform, visual mesh, lighting, or movement capability.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

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
| `canReparent` | `bool canReparent(String childId, String? targetParentId)` | Executes `canReparent` operation. |
| `reparent` | `bool reparent(String childId, String? newParentId)` | Executes `reparent` operation. |
| `duplicateComponent` | `BlueprintComponentNode? duplicateComponent(String id)` | Executes `duplicateComponent` operation. |
| `setProperty` | `void setProperty(String componentId, String propName, dynamic value)` | Updates the `Property` parameter and applies changes to the system. |
| `addVariable` | `void addVariable(String name, String type, String defaultValue)` | Appends a new item to the collection or scene. |
| `setClassDefault` | `void setClassDefault(String key, dynamic value)` | Updates the `ClassDefault` parameter and applies changes to the system. |
| `setParentClass` | `void setParentClass(String parentClass)` | Updates the `ParentClass` parameter and applies changes to the system. |
| `resetToDefaultComponents` | `void resetToDefaultComponents()` | Resets values or state back to defaults. |
| `save` | `Future<bool> save()` | Serializes and writes the current state or asset to disk. |

## `lib/ui/features/sub_editors/models/blueprint_component_registry.dart`

### `enum ComponentPropertyType`

`ComponentPropertyType`: Enumeration listing system options and state constants.

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

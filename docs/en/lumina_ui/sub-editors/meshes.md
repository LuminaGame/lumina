[Türkçe](../../../tr/lumina_ui/sub-editors/meshes.md)

# Static and skeletal mesh editors

The Static Mesh and Skeletal Mesh editors: mesh preview, LOD slots, collision shapes and material slot bindings for static meshes, and sockets for skeletal meshes. File paths are relative to the `lumina_ui/` package directory.

**On this page:**

- [`lib/ui/features/sub_editors/views/skeletal_mesh/skeletal_mesh_sub_editor.dart`](#libuifeaturessub_editorsviewsskeletal_meshskeletal_mesh_sub_editordart)
- [`lib/ui/features/sub_editors/views/static_mesh_sub_editor.dart`](#libuifeaturessub_editorsviewsstatic_mesh_sub_editordart)
- [`lib/ui/features/sub_editors/view_models/skeletal_mesh_editor_view_model.dart`](#libuifeaturessub_editorsview_modelsskeletal_mesh_editor_view_modeldart)
- [`lib/ui/features/sub_editors/view_models/static_mesh_editor_view_model.dart`](#libuifeaturessub_editorsview_modelsstatic_mesh_editor_view_modeldart)
- [`lib/ui/features/sub_editors/models/skeletal_mesh_socket.dart`](#libuifeaturessub_editorsmodelsskeletal_mesh_socketdart)
- [`lib/ui/features/sub_editors/models/static_mesh_collision.dart`](#libuifeaturessub_editorsmodelsstatic_mesh_collisiondart)
- [`lib/ui/features/sub_editors/models/static_mesh_lod.dart`](#libuifeaturessub_editorsmodelsstatic_mesh_loddart)
- [`lib/ui/features/sub_editors/models/skeletal_socket_attachment.dart`](#libuifeaturessub_editorsmodelsskeletal_socket_attachmentdart)
- [`lib/ui/features/sub_editors/views/skeletal_mesh/material_slots_panel.dart`](#libuifeaturessub_editorsviewsskeletal_meshmaterial_slots_paneldart)

## `lib/ui/features/sub_editors/views/skeletal_mesh/skeletal_mesh_sub_editor.dart`

### `class SkeletalMeshSubEditor`

`SkeletalMeshSubEditor`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `assetName` | `String assetName` | Holds the `assetName` property or configuration state. |
| `assetPath` | `String? assetPath` | Holds the `assetPath` property or configuration state. |
| `asset` | `RealAssetInfo? asset` | Holds the `asset` property or configuration state. |
| `viewModel` | `SkeletalMeshEditorViewModel? viewModel` | Holds the `viewModel` property or configuration state. |
| `onClose` | `VoidCallback? onClose` | Holds the `onClose` property or configuration state. |
| `onBind` | `SubEditorBindCallback? onBind` | Holds the `onBind` property or configuration state. |
| `createState` | `State<SkeletalMeshSubEditor> createState() => _SkeletalMeshSubEditorState()` | Creates, configures, and returns a new `State` instance or associated GPU resource. |

### `class _SkeletalMeshSubEditorState`

`_SkeletalMeshSubEditorState`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `initState` | `void initState()` | Executes `initState` operation. |
| `dispose` | `void dispose()` | Releases native FFI pointers, event subscriptions, and allocated memory. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

## `lib/ui/features/sub_editors/views/static_mesh_sub_editor.dart`

### `class StaticMeshSubEditor`

`StaticMeshSubEditor`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `assetName` | `String assetName` | Holds the `assetName` property or configuration state. |
| `assetPath` | `String? assetPath` | Holds the `assetPath` property or configuration state. |
| `asset` | `RealAssetInfo? asset` | Holds the `asset` property or configuration state. |
| `onClose` | `VoidCallback? onClose` | Holds the `onClose` property or configuration state. |
| `onBind` | `SubEditorBindCallback? onBind` | Holds the `onBind` property or configuration state. |
| `viewModel` | `StaticMeshEditorViewModel? viewModel` | Holds the `viewModel` property or configuration state. |
| `createState` | `State<StaticMeshSubEditor> createState() => _StaticMeshSubEditorState()` | Creates, configures, and returns a new `State` instance or associated GPU resource. |

### `class _StaticMeshSubEditorState`

`_StaticMeshSubEditorState`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `initState` | `void initState()` | Executes `initState` operation. |
| `dispose` | `void dispose()` | Releases native FFI pointers, event subscriptions, and allocated memory. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

## `lib/ui/features/sub_editors/view_models/skeletal_mesh_editor_view_model.dart`

### `class SkeletalMeshEditorViewModel`

`SkeletalMeshEditorViewModel`: ChangeNotifier ViewModel managing UI state, user actions, and data binding for the view.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `assetPath` | `String assetPath` | Holds the `assetPath` property or configuration state. |
| `isLoading` | `bool get isLoading` | Checks current state or capability and returns a boolean value. |
| `hasError` | `bool get hasError` | Checks current state or capability and returns a boolean value. |
| `isDirty` | `bool get isDirty` | Checks current state or capability and returns a boolean value. |
| `asset` | `LuminaAsset? get asset` | Getter accessor returning the current value of `asset`. |
| `glbMesh` | `GlbMeshData? get glbMesh` | Getter accessor returning the current value of `glbMesh`. |
| `triangleCount` | `int get triangleCount` | Getter accessor returning the current value of `triangleCount`. |
| `vertexCount` | `int get vertexCount` | Getter accessor returning the current value of `vertexCount`. |
| `boneCount` | `int get boneCount` | Getter accessor returning the current value of `boneCount`. |
| `maxInfluences` | `int get maxInfluences` | Getter accessor returning the current value of `maxInfluences`. |
| `allBones` | `List<GlbNode> get allBones` | Getter accessor returning the current value of `allBones`. |
| `rootBones` | `List<GlbNode> get rootBones` | Getter accessor returning the current value of `rootBones`. |
| `selectedBone` | `GlbNode? get selectedBone` | Selects the target actor or asset. |
| `selectedSocket` | `SkeletalMeshSocket? get selectedSocket` | Selects the target actor or asset. |
| `sockets` | `List<SkeletalMeshSocket> get sockets` | Getter accessor returning the current value of `sockets`. |
| `boneRetargeting` | `Map<String, String> get boneRetargeting` | Getter accessor returning the current value of `boneRetargeting`. |
| `morphTargets` | `List<GlbMorphTarget> get morphTargets` | Getter accessor returning the current value of `morphTargets`. |
| `morphWeights` | `Map<String, double> get morphWeights` | Getter accessor returning the current value of `morphWeights`. |
| `activeMorphTargetCount` | `int get activeMorphTargetCount` | Getter accessor returning the current value of `activeMorphTargetCount`. |
| `showBones` | `bool get showBones` | Getter accessor returning the current value of `showBones`. |
| `displaySockets` | `bool get displaySockets` | Getter accessor returning the current value of `displaySockets`. |
| `heatmapEnabled` | `bool get heatmapEnabled` | Getter accessor returning the current value of `heatmapEnabled`. |
| `inspectedVertex` | `int? get inspectedVertex` | Getter accessor returning the current value of `inspectedVertex`. |
| `boneSearchFilter` | `String get boneSearchFilter` | Getter accessor returning the current value of `boneSearchFilter`. |
| `allBoneNames` | `List<String> get allBoneNames` | Getter accessor returning the current value of `allBoneNames`. |
| `fileBasename` | `String get fileBasename` | Getter accessor returning the current value of `fileBasename`. |
| `load` | `Future<void> load()` | Loads data from disk or memory buffer into the engine. |
| `setBoneSearchFilter` | `void setBoneSearchFilter(String filter)` | Updates the `BoneSearchFilter` parameter and applies changes to the system. |
| `selectBone` | `void selectBone(GlbNode? bone)` | Selects the target actor or asset. |
| `selectSocket` | `void selectSocket(SkeletalMeshSocket? socket)` | Selects the target actor or asset. |
| `toggleShowBones` | `void toggleShowBones()` | Toggles the target feature or visibility on/off. |
| `toggleDisplaySockets` | `void toggleDisplaySockets()` | Toggles the target feature or visibility on/off. |
| `toggleHeatmap` | `void toggleHeatmap()` | Toggles the target feature or visibility on/off. |
| `setHeatmapEnabled` | `void setHeatmapEnabled(bool enabled)` | Updates the `HeatmapEnabled` parameter and applies changes to the system. |
| `setInspectedVertex` | `void setInspectedVertex(int? vertIndex)` | Updates the `InspectedVertex` parameter and applies changes to the system. |
| `setMorphWeight` | `void setMorphWeight(String name, double weight)` | Updates the `MorphWeight` parameter and applies changes to the system. |
| `resetMorphs` | `void resetMorphs()` | Resets values or state back to defaults. |
| `deformedPositions` | `Float32List deformedPositions()` | Executes `deformedPositions` operation. |
| `heatmapColors` | `Uint8List? heatmapColors(int? boneNodeIndex)` | Executes `heatmapColors` operation. |
| `getVertexInfluences` | `Map<String, double> getVertexInfluences(int vertIndex)` | Queries and returns the `VertexInfluences` value or child object. |
| `getVertexWeightSum` | `double getVertexWeightSum(int vertIndex)` | Queries and returns the `VertexWeightSum` value or child object. |
| `renameSocket` | `bool renameSocket(String oldName, String newName)` | Executes `renameSocket` operation. |
| `reparentSocket` | `bool reparentSocket(String socketName, String newParentBone)` | Executes `reparentSocket` operation. |
| `setSocketPreviewAsset` | `void setSocketPreviewAsset(String socketName, String? assetPath)` | Updates the `SocketPreviewAsset` parameter and applies changes to the system. |
| `removeSocket` | `bool removeSocket(String socketName)` | Releases and safely disposes the specified `Socket` resource. |
| `setBoneRetargeting` | `void setBoneRetargeting(String boneName, String option)` | Updates the `BoneRetargeting` parameter and applies changes to the system. |
| `getSocketsForBone` | `List<SkeletalMeshSocket> getSocketsForBone(String boneName)` | Queries and returns the `SocketsForBone` value or child object. |
| `save` | `Future<bool> save()` | Serializes and writes the current state or asset to disk. |

## `lib/ui/features/sub_editors/view_models/static_mesh_editor_view_model.dart`

### `class StaticMeshEditorViewModel`

`StaticMeshEditorViewModel`: ChangeNotifier ViewModel managing UI state, user actions, and data binding for the view.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `assetPath` | `String assetPath` | Holds the `assetPath` property or configuration state. |
| `isLoading` | `bool get isLoading` | Checks current state or capability and returns a boolean value. |
| `hasError` | `bool get hasError` | Checks current state or capability and returns a boolean value. |
| `isDirty` | `bool get isDirty` | Checks current state or capability and returns a boolean value. |
| `asset` | `LuminaAsset? get asset` | Getter accessor returning the current value of `asset`. |
| `glbMesh` | `GlbMeshData? get glbMesh` | Getter accessor returning the current value of `glbMesh`. |
| `triangleCount` | `int get triangleCount` | Getter accessor returning the current value of `triangleCount`. |
| `vertexCount` | `int get vertexCount` | Getter accessor returning the current value of `vertexCount`. |
| `uvChannelsCount` | `int get uvChannelsCount` | Getter accessor returning the current value of `uvChannelsCount`. |
| `sectionCount` | `int get sectionCount` | Getter accessor returning the current value of `sectionCount`. |
| `minBounds` | `List<double> get minBounds` | Getter accessor returning the current value of `minBounds`. |
| `maxBounds` | `List<double> get maxBounds` | Getter accessor returning the current value of `maxBounds`. |
| `boundsWidth` | `double get boundsWidth` | Getter accessor returning the current value of `boundsWidth`. |
| `boundsDepth` | `double get boundsDepth` | Getter accessor returning the current value of `boundsDepth`. |
| `boundsHeight` | `double get boundsHeight` | Getter accessor returning the current value of `boundsHeight`. |
| `materialSlots` | `List<MaterialSlotBinding> get materialSlots` | Getter accessor returning the current value of `materialSlots`. |
| `collisionShapes` | `List<StaticMeshCollisionShape> get collisionShapes` | Getter accessor returning the current value of `collisionShapes`. |
| `collisionComplexity` | `String get collisionComplexity` | Getter accessor returning the current value of `collisionComplexity`. |
| `massKg` | `double get massKg` | Getter accessor returning the current value of `massKg`. |
| `centerOfMassOffset` | `List<double> get centerOfMassOffset` | Getter accessor returning the current value of `centerOfMassOffset`. |
| `showCollisionWireframe` | `bool get showCollisionWireframe` | Getter accessor returning the current value of `showCollisionWireframe`. |
| `lods` | `List<LodSlot> get lods` | Getter accessor returning the current value of `lods`. |
| `forcedLod` | `int? get forcedLod` | Getter accessor returning the current value of `forcedLod`. |
| `lodGroup` | `String get lodGroup` | Getter accessor returning the current value of `lodGroup`. |
| `autoComputeLodDistances` | `bool get autoComputeLodDistances` | Getter accessor returning the current value of `autoComputeLodDistances`. |
| `activePreviewLod` | `LodSlot get activePreviewLod` | Getter accessor returning the current value of `activePreviewLod`. |
| `fileBasename` | `String get fileBasename` | Getter accessor returning the current value of `fileBasename`. |
| `load` | `Future<void> load()` | Loads data from disk or memory buffer into the engine. |
| `addLod` | `void addLod()` | Appends a new item to the collection or scene. |
| `removeLod` | `void removeLod(int level)` | Releases and safely disposes the specified `Lod` resource. |
| `setLodRatio` | `void setLodRatio(int level, double ratio)` | Updates the `LodRatio` parameter and applies changes to the system. |
| `setLodScreenSize` | `bool setLodScreenSize(int level, double screenSize)` | Updates the `LodScreenSize` parameter and applies changes to the system. |
| `setLodMaterialOverride` | `void setLodMaterialOverride(int level, String slotName, String? material...` | Updates the `LodMaterialOverride` parameter and applies changes to the system. |
| `setLodGroup` | `void setLodGroup(String group)` | Updates the `LodGroup` parameter and applies changes to the system. |
| `setAutoComputeLodDistances` | `void setAutoComputeLodDistances(bool enabled)` | Updates the `AutoComputeLodDistances` parameter and applies changes to the system. |
| `setForcedLod` | `void setForcedLod(int? level)` | Updates the `ForcedLod` parameter and applies changes to the system. |
| `highlightMaterial` | `void highlightMaterial(int slotIndex, bool enabled)` | Executes `highlightMaterial` operation. |
| `isolateMaterial` | `void isolateMaterial(int slotIndex, bool enabled)` | Checks current state or capability and returns a boolean value. |
| `generateCollision` | `void generateCollision(StaticMeshCollisionShapeType type)` | Executes `generateCollision` operation. |
| `removeCollision` | `void removeCollision()` | Releases and safely disposes the specified `Collision` resource. |
| `setCollisionComplexity` | `void setCollisionComplexity(String val)` | Updates the `CollisionComplexity` parameter and applies changes to the system. |
| `setMass` | `void setMass(double val)` | Updates the `Mass` parameter and applies changes to the system. |
| `setCenterOfMassOffset` | `void setCenterOfMassOffset(List<double> offset)` | Updates the `CenterOfMassOffset` parameter and applies changes to the system. |
| `toggleCollisionWireframe` | `void toggleCollisionWireframe()` | Toggles the target feature or visibility on/off. |
| `save` | `Future<bool> save()` | Serializes and writes the current state or asset to disk. |

## `lib/ui/features/sub_editors/models/skeletal_mesh_socket.dart`

### `class SkeletalMeshSocket`

`SkeletalMeshSocket`: `class` representing the data model or functionality of the module.

**Constructors:**
- `SkeletalMeshSocket.fromJson(Map<String, dynamic> json)`: Initializes `SkeletalMeshSocket.fromJson(Map<String, dynamic> json)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `name` | `String name` | Holds the `name` property or configuration state. |
| `parentBone` | `String parentBone` | Holds the `parentBone` property or configuration state. |
| `relativeLocation` | `List<double> relativeLocation` | Holds the `relativeLocation` property or configuration state. |
| `relativeRotation` | `List<double> relativeRotation` | Holds the `relativeRotation` property or configuration state. |
| `relativeScale` | `List<double> relativeScale` | Holds the `relativeScale` property or configuration state. |
| `previewAssetPath` | `String? previewAssetPath` | Holds the `previewAssetPath` property or configuration state. |
| `toJson` | `Map<String, dynamic> toJson()` | Serializes the object to a JSON map. |

## `lib/ui/features/sub_editors/models/static_mesh_collision.dart`

### `enum StaticMeshCollisionShapeType`

`StaticMeshCollisionShapeType`: Enumeration listing system options and state constants.

### `class StaticMeshCollisionShape`

`StaticMeshCollisionShape`: `class` representing the data model or functionality of the module.

**Constructors:**
- `StaticMeshCollisionShape.fromJson(Map<String, dynamic> json)`: Initializes `StaticMeshCollisionShape.fromJson(Map<String, dynamic> json)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `type` | `StaticMeshCollisionShapeType type` | Holds the `type` property or configuration state. |
| `center` | `List<double> center` | Holds the `center` property or configuration state. |
| `extents` | `List<double>? extents` | Holds the `extents` property or configuration state. |
| `radius` | `double? radius` | Holds the `radius` property or configuration state. |
| `halfHeight` | `double? halfHeight` | Holds the `halfHeight` property or configuration state. |
| `axis` | `String? axis` | Holds the `axis` property or configuration state. |
| `points` | `List<List<double>>? points` | Holds the `points` property or configuration state. |
| `toJson` | `Map<String, dynamic> toJson()` | Serializes the object to a JSON map. |
| `createBox` | `static StaticMeshCollisionShape createBox(List<double> minBounds, List<d...` | Creates, configures, and returns a new `Box` instance or associated GPU resource. |
| `createSphere` | `static StaticMeshCollisionShape createSphere(List<double> minBounds, Lis...` | Creates, configures, and returns a new `Sphere` instance or associated GPU resource. |
| `createCapsule` | `static StaticMeshCollisionShape createCapsule(List<double> minBounds, Li...` | Creates, configures, and returns a new `Capsule` instance or associated GPU resource. |

### `class MaterialSlotBinding`

`MaterialSlotBinding`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `index` | `int index` | Holds the `index` property or configuration state. |
| `slotName` | `String slotName` | Holds the `slotName` property or configuration state. |
| `assignedMaterialPath` | `String? assignedMaterialPath` | Holds the `assignedMaterialPath` property or configuration state. |
| `assignedMaterialId` | `String? assignedMaterialId` | Holds the `assignedMaterialId` property or configuration state. |
| `isHighlighted` | `bool isHighlighted` | Holds the `isHighlighted` property or configuration state. |
| `isIsolated` | `bool isIsolated` | Holds the `isIsolated` property or configuration state. |

## `lib/ui/features/sub_editors/models/static_mesh_lod.dart`

### `class LodSlot`

`LodSlot`: `class` representing the data model or functionality of the module.

**Constructors:**
- `LodSlot.fromJson(Map<String, dynamic> json)`: Initializes `LodSlot.fromJson(Map<String, dynamic> json)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `level` | `int level` | Holds the `level` property or configuration state. |
| `reductionRatio` | `double reductionRatio` | Holds the `reductionRatio` property or configuration state. |
| `screenSize` | `double screenSize` | Holds the `screenSize` property or configuration state. |
| `triangleCount` | `int triangleCount` | Holds the `triangleCount` property or configuration state. |
| `vertexCount` | `int vertexCount` | Holds the `vertexCount` property or configuration state. |
| `materialOverrides` | `Map<String, String> materialOverrides` | Holds the `materialOverrides` property or configuration state. |
| `toJson` | `Map<String, dynamic> toJson()` | Serializes the object to a JSON map. |

## `lib/ui/features/sub_editors/models/skeletal_socket_attachment.dart`

### `class SkeletalSocketAttachment`

A mesh previewed on a skeletal socket: the Skeletal Mesh editor's viewport draws [mesh] at `entityWorld × G_bone × offset`, the engine's socket chain, so an attachment follows its bone.

**Constructors:**

- `const SkeletalSocketAttachment({required this.socketName, required this.boneName, required this.assetPath, required this.mesh, required this.localOffset, requir...`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `socketName` | `final String socketName` |  |
| `boneName` | `final String boneName` |  |
| `assetPath` | `final String assetPath` | The previewed mesh's `.lmas` on disk. |
| `mesh` | `final GlbMeshData mesh` |  |
| `localOffset` | `final Matrix4 localOffset` | The socket's offset in its bone's frame, in the viewport's units (metres): the right-hand factor of the chain. |
| `restWorld` | `final Matrix4 restWorld` | `entityWorld × G_bone × offset` with the bone at its rest pose and the preview mesh at the origin: where the attachment is drawn when the viewport cannot parent it to the live joint. |
| `signature` | `String get signature` | What the viewport compares to know an attachment changed. |

### `abstract final class SkeletalSocketMath`

The socket transform chain shared by the viewport's attachments and its socket markers.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `cmToViewport` | `static const double cmToViewport` | Socket locations are authored in centimetres (like joint deltas and the collision / physics editors); the preview's GLB is in metres. |
| `localOffset` | `static Matrix4 localOffset(SkeletalMeshSocket socket)` | `T · R · S` of [socket] in its bone's frame, in metres. A 3-element rotation is X, Y, Z degrees about the bone's axes, applied X then Y then Z (`R = Rz · Ry · Rx`); a 4-element one is a quaternion `[x, y, z, w]`. |
| `boneGlobal` | `static Matrix4? boneGlobal(GlbMeshData mesh, String bone)` | The rest-pose global transform of the node named [bone] in [mesh] (`G_bone`, the GLB's frame), or null when the mesh has no such node. |
| `nodeLocal` | `static Matrix4 nodeLocal(GlbNode node)` | A node's local `T · R · S`; a degenerate quaternion is the identity (as in the skeleton painter). |
| `worldTransform` | `static Matrix4? worldTransform(GlbMeshData mesh, SkeletalMeshSocket socket, {Matrix4? entityWorld})` | `entityWorld × G_bone × offset` for [socket] on [mesh] at rest; the entity sits at the origin in the preview. Null when the bone is missing. |

## `lib/ui/features/sub_editors/views/skeletal_mesh/material_slots_panel.dart`

### `class SkeletalMaterialSlotsPanel`

`MATERIAL SLOTS` section of the Skeletal Mesh editor's right inspector.

One row per geometry section: the material bound to it (pickable from the project's real FILAMAT `.lmas`), Highlight/Isolate toggles, and — once bound — one texture row per sampler the material declares.

**Constructors:**

- `const SkeletalMaterialSlotsPanel({super.key, required this.viewModel})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `viewModel` | `final SkeletalMeshEditorViewModel viewModel` |  |

---

[Previous: Sequencer](sequencer.md) | [Up: Sub-editors](index.md) | [Next: Texture editor](texture.md)

[Türkçe](../../tr/lumina/components-mesh-and-particles.md)

# Components: meshes and particles

Components that draw geometry: static and instanced static meshes with LODs, the mesh asset cache, procedural meshes with updatable sections, skinned meshes with skeletons and sockets, morph targets, and the CPU particle system with its emitter configuration. File paths are relative to the `lumina/` package directory.

**On this page:**

- [`lib/src/components/mesh/instanced_static_mesh_component.dart`](#libsrccomponentsmeshinstanced_static_mesh_componentdart)
- [`lib/src/components/mesh/mesh_asset_cache.dart`](#libsrccomponentsmeshmesh_asset_cachedart)
- [`lib/src/components/mesh/morph_target_set.dart`](#libsrccomponentsmeshmorph_target_setdart)
- [`lib/src/components/mesh/morph_targets.dart`](#libsrccomponentsmeshmorph_targetsdart)
- [`lib/src/components/mesh/morph_spring_solver.dart`](#libsrccomponentsmeshmorph_spring_solverdart)
- [`lib/src/components/mesh/spring_morph_component.dart`](#libsrccomponentsmeshspring_morph_componentdart)
- [`lib/src/components/mesh/procedural_mesh_component.dart`](#libsrccomponentsmeshprocedural_mesh_componentdart)
- [`lib/src/components/mesh/skeletal_mesh_component.dart`](#libsrccomponentsmeshskeletal_mesh_componentdart)
- [`lib/src/components/mesh/skinning_buffer.dart`](#libsrccomponentsmeshskinning_bufferdart)
- [`lib/src/components/mesh/static_mesh_component.dart`](#libsrccomponentsmeshstatic_mesh_componentdart)
- [`lib/src/components/particles/particle_emitter_config.dart`](#libsrccomponentsparticlesparticle_emitter_configdart)
- [`lib/src/components/particles/particle_system_component.dart`](#libsrccomponentsparticlesparticle_system_componentdart)
- [`lib/src/components/mesh/animated_mesh_component.dart`](#libsrccomponentsmeshanimated_mesh_componentdart)

## `lib/src/components/mesh/instanced_static_mesh_component.dart`

### `class LuminaStaticMeshLod`

Descriptor for a single level of detail (LOD) geometry mesh in an [LuminaInstancedStaticMeshComponent].

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `vb` | `FilamentVertexBuffer vb` | Holds the `vb` property or configuration state. |
| `ib` | `FilamentIndexBuffer ib` | Holds the `ib` property or configuration state. |
| `indexCount` | `int indexCount` | Holds the `indexCount` property or configuration state. |
| `switchDistance` | `double switchDistance` | Holds the `switchDistance` property or configuration state. |

### `class LuminaInstancedStaticMeshComponent`

Scene component rendering thousands of mesh copies in a single GPU instanced draw call with LOD support.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `lods` | `List<LuminaStaticMeshLod> lods` | Holds the `lods` property or configuration state. |
| `material` | `FilamentMaterialInstance material` | Holds the `material` property or configuration state. |
| `capacity` | `int capacity` | Holds the `capacity` property or configuration state. |
| `lodHysteresis` | `double lodHysteresis` | Holds the `lodHysteresis` property or configuration state. |
| `initialBounds` | `Aabb3? initialBounds` | Bounding box the renderable is built with when the component registers.  Filament bakes a renderable's bounds at build time, so a batch that is registered before (or faster than) its instances arrive would otherwise be culled against a placeholder box. Callers that already know the volume their instances will occupy — a landscape's footprint, a streamed cell — pass it here; everyone else keeps the previous behaviour, which derives the box from the instances added before registration. |
| `instanceCount` | `int get instanceCount` | Number of live active instances. |
| `combinedBounds` | `Aabb3 get combinedBounds` | Combined axis-aligned bounding box encompassing all live instances. |
| `currentLodIndex` | `int get currentLodIndex` | Active LOD index (0 is highest detail). |
| `entity` | `int get entity` | Native Filament entity handle for this instanced renderable. |
| `instanceBuffer` | `InstanceBuffer? get instanceBuffer` | Active GPU instance buffer. |
| `onRegister` | `void onRegister(LuminaActor ownerActor)` | Callback invoked when the corresponding event is triggered. |
| `onUnregister` | `void onUnregister()` | Callback invoked when the corresponding event is triggered. |
| `addInstance` | `int addInstance(Matrix4 transform)` | Adds a new instance transform, returning its instance index. |
| `updateInstanceTransform` | `void updateInstanceTransform(int index, Matrix4 transform)` | Updates the transform for instance at [index]. |
| `removeInstance` | `bool removeInstance(int index)` | Removes instance at [index] using swap-remove, zero-scaling the freed slot. |
| `recalculateBounds` | `void recalculateBounds()` | Recalculates [combinedBounds] tightly over all active instance positions. |
| `flushTransformsToGpu` | `void flushTransformsToGpu()` | Flushes any pending local transform updates to the GPU instance buffer in a single batched upload. |

## `lib/src/components/mesh/mesh_asset_cache.dart`

### `class _CachedMeshEntry`

`_CachedMeshEntry`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `asset` | `FilamentAsset asset` | Holds the `asset` property or configuration state. |
| `bytes` | `Uint8List bytes` | Holds the `bytes` property or configuration state. |
| `refCount` | `int refCount` | Holds the `refCount` property or configuration state. |

### `class LuminaMeshAssetCache`

Refcounted mesh asset cache managing gltfio parsing and shared instancing across components.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `engine` | `FilamentEngine engine` | Holds the `engine` property or configuration state. |
| `materialProvider` | `FilamentMaterialProvider materialProvider` | Holds the `materialProvider` property or configuration state. |
| `assetLoader` | `final FilamentAssetLoader assetLoader` | Holds the `assetLoader` property or configuration state. |
| `resourceLoader` | `final FilamentResourceLoader resourceLoader` | Holds the `resourceLoader` property or configuration state. |
| `releaseInstance` | `void releaseInstance(String meshAssetPath, FilamentAssetInstance instance)` | Releases an acquired [FilamentAssetInstance], destroying the underlying asset when refCount reaches 0. |
| `dispose` | `void dispose()` | Disposes loaders and internal resources. |

## `lib/src/components/mesh/morph_target_set.dart`

### `class MorphTargetHandle`

`MorphTargetHandle`: `class` representing the data model or functionality of the module.

**Constructors:**
- `MorphTargetHandle(this.name, this.targets)`: Initializes `MorphTargetHandle(this.name, this.targets)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `name` | `String name` | Holds the `name` property or configuration state. |

### `class MorphTargetSet`

`MorphTargetSet`: `class` representing the data model or functionality of the module.

**Constructors:**
- `MorphTargetSet.fromAsset(FilamentAsset asset)`: Initializes `MorphTargetSet.fromAsset(FilamentAsset asset)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `names` | `List<String> get names` | Getter accessor returning the current value of `names`. |
| `contains` | `bool contains(String name) => _handles.containsKey(name)` | Executes `contains` operation. |
| `getHandle` | `MorphTargetHandle? getHandle(String name)` | Queries and returns the `Handle` value or child object. |

## `lib/src/components/mesh/morph_targets.dart`

### `mixin LuminaMorphTargets`

Morph target weights of a mesh component, shared by `LuminaSkinnedMeshComponent` and `LuminaAnimatedMeshComponent`
(the runtime skeletal mesh: Blueprint `LuminaSkeletalMeshComponent`, and placed skeletal meshes that carry springs).
Targets are discovered by name from the renderables of an asset or of one asset instance (`discoverMorphTargetsOf`;
the animated mesh does this for its own instance on load, so two characters sharing a mesh keep their own weights).
Weights are staged per renderable and written to Filament by `flushMorphTargets` (the meshes flush at the end of
their tick).

| Member | Signature | Description |
|---|---|---|
| `hasMorphTargets` | `bool get hasMorphTargets` | Whether targets were discovered and there is at least one. |
| `discoverMorphTargets` | `void discoverMorphTargets(FilamentAsset asset)` | Discovers the targets of the asset's own entities. |
| `discoverMorphTargetsOf` | `void discoverMorphTargetsOf(FilamentAsset asset, List<int> entities)` | Discovers the targets of an asset instance's entities. |
| `hasMorphTarget` | `bool hasMorphTarget(String name)` | Whether a target of that name exists. |
| `setMorphTarget` / `setMorphTargetByHandle` | `void setMorphTarget(String name, double weight)` | Stages a weight (by name, or by a resolved handle without the lookup). |
| `getMorphTarget` | `double getMorphTarget(String name)` | The staged weight. |
| `clearMorphTargets` | `void clearMorphTargets()` | Every weight back to 0. |
| `flushMorphTargets` | `void flushMorphTargets()` | Writes the weights changed since the last flush. |

## `lib/src/components/mesh/morph_spring_solver.dart`

### `class LuminaMorphSpringSolver`

A damped spring for secondary motion (pure Dart): the offset (cm, in the mesh's frame) of a soft mass carried by the
body. It steps at a fixed 240 Hz: `offset'' = −ω²·offset − 2ζω·offset' − inertia·a + gravity·(g − g_rest)`, where `a`
is the body's acceleration and `g` the direction of gravity in the mesh's frame (taken as the rest one on the first
step, so lying down or bending over moves the rest). The offset is clamped to `limit`.

| Member | Description |
|---|---|
| `frequency`, `damping`, `inertia`, `gravity`, `limit` | Natural frequency (Hz), damping ratio (1: no overshoot), share of the acceleration and of the gravity change, largest offset (cm). |
| `advance(dt, acceleration, gravityLocal)` | Advances by `dt` seconds. |
| `offset`, `velocity`, `reset()` | The state; `reset` puts the mass at rest and takes the next gravity as the rest one. |

## `lib/src/components/mesh/spring_morph_component.dart`

### `class LuminaMorphSpring`

One soft mass: `name`, the `bone` carrying it (null: the mesh itself) and an `offset` from it (cm), the spring
(`frequency`, `damping`, `inertia`, `gravity`, `limit`), `range` (the offset at target weight 1, cm) and `morphs`, the
morph target per axis direction of the mesh's frame (`+x`, `-x`, `+y`, `-y`, `+z`, `-z`). `toJson` / `fromJson`.

### `class LuminaSpringMorphComponent`

Secondary motion (jiggle) through morph targets. Each frame, after the owner's mesh ticked (add it after the mesh),
every spring reads its mass's world position (the bone's joint world transform on an animated mesh, the socket
transform on a skinned one, else the mesh's transform), derives its acceleration from the last frames (a speed above
50 m/s is a teleport: the spring rests again), advances its solver with the acceleration and gravity in the mesh's
frame and writes `offset × amplitude / range` as the weights of its two targets per axis, then flushes the mesh. A
missing bone or morph target is reported once.

| Member | Description |
|---|---|
| `springs`, `enabled`, `amplitude`, `stiffnessScale`, `dampingScale` | The masses; on/off; offset scale (0: no motion); frequency and damping multipliers. |
| `fromProperties` / `toProperties` | The level / Blueprint component properties (`springs` as a list of `LuminaMorphSpring` JSON). |
| `offsetOf(name)` | A spring's current offset. |
| `resetSprings()` | Every spring back at rest. |

Blueprint components of type `LuminaSpringMorphComponent` build it (`LuminaBlueprintComponents`). A placed
`SkeletalMesh` level actor that carries one plays, in PIE and in the generated game, as a `LuminaAnimatedMeshComponent`
root plus this component (every other skeletal mesh actor is unchanged); the level Details panel edits Enabled,
Amplitude, Stiffness Scale and Damping Scale.

## `lib/src/components/mesh/procedural_mesh_component.dart`

### `class _ProceduralMeshSection`

`_ProceduralMeshSection`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `sectionIndex` | `int sectionIndex` | Holds the `sectionIndex` property or configuration state. |
| `vertexCount` | `int vertexCount` | Holds the `vertexCount` property or configuration state. |
| `triangleCount` | `int triangleCount` | Holds the `triangleCount` property or configuration state. |
| `stride` | `int stride` | Holds the `stride` property or configuration state. |
| `indexType` | `IndexType indexType` | Holds the `indexType` property or configuration state. |
| `entity` | `int entity` | Holds the `entity` property or configuration state. |
| `vertexBuffer` | `FilamentVertexBuffer? vertexBuffer` | Holds the `vertexBuffer` property or configuration state. |
| `indexBuffer` | `FilamentIndexBuffer? indexBuffer` | Holds the `indexBuffer` property or configuration state. |
| `material` | `FilamentMaterialInstance? material` | Holds the `material` property or configuration state. |
| `stagingByteSize` | `int stagingByteSize` | Holds the `stagingByteSize` property or configuration state. |
| `visible` | `bool visible` | Holds the `visible` property or configuration state. |
| `bounds` | `Aabb3 bounds` | Holds the `bounds` property or configuration state. |
| `hasNormals` | `bool hasNormals` | Holds the `hasNormals` property or configuration state. |
| `hasUv0` | `bool hasUv0` | Holds the `hasUv0` property or configuration state. |
| `hasColors` | `bool hasColors` | Holds the `hasColors` property or configuration state. |
| `hasTangents` | `bool hasTangents` | Holds the `hasTangents` property or configuration state. |
| `normalOffset` | `int normalOffset` | Holds the `normalOffset` property or configuration state. |
| `tangentOffset` | `int tangentOffset` | Holds the `tangentOffset` property or configuration state. |
| `uv0Offset` | `int uv0Offset` | Holds the `uv0Offset` property or configuration state. |
| `colorOffset` | `int colorOffset` | Holds the `colorOffset` property or configuration state. |
| `dispose` | `void dispose(FilamentEngine? engine, FilamentScene? scene)` | Releases native FFI pointers, event subscriptions, and allocated memory. |

### `class LuminaProceduralMeshComponent`

Component that allows building and deforming 3D meshes dynamically at runtime.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `sectionCount` | `int get sectionCount` | Number of active mesh sections. |
| `hasSection` | `bool hasSection(int sectionIndex) => _sections.containsKey(sectionIndex)` | Returns whether a section at [sectionIndex] exists. |
| `sectionBounds` | `Aabb3? sectionBounds(int sectionIndex)` | Returns the local AABB bounding box for [sectionIndex]. |
| `sectionVertexCount` | `int sectionVertexCount(int sectionIndex)` | Returns the vertex count for [sectionIndex]. |
| `isSectionVisible` | `bool isSectionVisible(int sectionIndex)` | Returns whether [sectionIndex] is currently visible. |
| `getSectionStride` | `int getSectionStride(int sectionIndex)` | Test inspection helper returning the byte stride of [sectionIndex]. |
| `getSectionIndexType` | `IndexType? getSectionIndexType(int sectionIndex)` | Test inspection helper returning the IndexType of [sectionIndex]. |
| `getSectionStagingPointerAddress` | `int getSectionStagingPointerAddress(int sectionIndex)` | Test inspection helper returning the raw native memory address of the staging buffer for [sectionIndex]. |
| `setSectionMaterial` | `void setSectionMaterial(int sectionIndex, FilamentMaterialInstance mi)` | Sets the material instance for [sectionIndex]. |
| `setSectionVisible` | `void setSectionVisible(int sectionIndex, bool visible)` | Sets the visibility of [sectionIndex]. |
| `clearMeshSection` | `void clearMeshSection(int sectionIndex)` | Clears and releases all native and staging resources for [sectionIndex]. |
| `clearAllMeshSections` | `void clearAllMeshSections()` | Clears and releases all mesh sections. |
| `onUnregister` | `void onUnregister()` | Callback invoked when the corresponding event is triggered. |

## `lib/src/components/mesh/skeletal_mesh_component.dart`

### `class LuminaSocket`

`LuminaSocket`: `class` representing the data model or functionality of the module.

**Constructors:**
- `LuminaSocket(this.name, this.boneName, this.localOffset)`: Initializes `LuminaSocket(this.name, this.boneName, this.localOffset)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `name` | `String name` | Holds the `name` property or configuration state. |
| `boneName` | `String boneName` | Holds the `boneName` property or configuration state. |
| `localOffset` | `Matrix4 localOffset` | Holds the `localOffset` property or configuration state. |

### `class _SocketAttachment`

`_SocketAttachment`: `class` representing the data model or functionality of the module.

**Constructors:**
- `_SocketAttachment(this.component, this.socketName, this.relativeOffset)`: Initializes `_SocketAttachment(this.component, this.socketName, this.relativeOffset)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `component` | `LuminaSceneComponent component` | Holds the `component` property or configuration state. |
| `socketName` | `String socketName` | Holds the `socketName` property or configuration state. |
| `relativeOffset` | `Matrix4 relativeOffset` | Holds the `relativeOffset` property or configuration state. |

### `class BoneNode`

`BoneNode`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `id` | `int id` | Holds the `id` property or configuration state. |
| `name` | `String name` | Holds the `name` property or configuration state. |
| `parentIndex` | `int parentIndex` | Holds the `parentIndex` property or configuration state. |
| `localTransform` | `Matrix4 localTransform` | Holds the `localTransform` property or configuration state. |
| `globalTransform` | `Matrix4 globalTransform` | Holds the `globalTransform` property or configuration state. |
| `inverseBindMatrix` | `Matrix4 inverseBindMatrix` | Holds the `inverseBindMatrix` property or configuration state. |
| `composeLocal` | `void composeLocal()` | Executes `composeLocal` operation. |

### `class Skeleton`

`Skeleton`: `class` representing the data model or functionality of the module.

**Constructors:**
- `Skeleton(List<BoneNode> bones)`: Initializes `Skeleton(List<BoneNode> bones)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `boneCount` | `int get boneCount` | Getter accessor returning the current value of `boneCount`. |
| `indexOfBone` | `int indexOfBone(String name)` | Executes `indexOfBone` operation. |
| `findBone` | `BoneNode? findBone(String name)` | Searches and retrieves matching items or actors. |
| `rootIndices` | `List<int> get rootIndices` | Getter accessor returning the current value of `rootIndices`. |
| `updateGlobalTransforms` | `void updateGlobalTransforms()` | Updates the current state or data values. |
| `resetToBindPose` | `void resetToBindPose()` | Resets values or state back to defaults. |

### `class TransformCurve`

`TransformCurve`: `class` representing the data model or functionality of the module.

**Constructors:**
- `TransformCurve(this.times, this.translations, this.rotations, this.scales)`: Initializes `TransformCurve(this.times, this.translations, this.rotations, this.scales)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `times` | `Float32List times` | Holds the `times` property or configuration state. |
| `translations` | `List<Vector3> translations` | Holds the `translations` property or configuration state. |
| `rotations` | `List<Quaternion> rotations` | Holds the `rotations` property or configuration state. |
| `scales` | `List<Vector3> scales` | Holds the `scales` property or configuration state. |
| `sampleInto` | `void sampleInto(double time, BoneNode bone)` | Executes `sampleInto` operation. |

### `class LuminaSkinnedMeshComponent`

Its morph target members come from `LuminaMorphTargets` (below `morph_target_set.dart`).

Skinned mesh component supporting bone hierarchies, sockets, and animation interpolation.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `meshAssetPath` | `String? meshAssetPath` | Holds the `meshAssetPath` property or configuration state. |
| `animInstance` | `LuminaAnimInstance? animInstance` | Active animation instance driving skeletal bone transforms. |
| `skeleton` | `Skeleton? get skeleton` | Getter accessor returning the current value of `skeleton`. |
| `setSkeleton` | `void setSkeleton(Skeleton? s)` | Updates the `Skeleton` parameter and applies changes to the system. |
| `onRegister` | `void onRegister(LuminaActor ownerActor)` | Callback invoked when the corresponding event is triggered. |
| `onUnregister` | `void onUnregister()` | Callback invoked when the corresponding event is triggered. |
| `onTick` | `void onTick(double deltaTime)` | Callback invoked when the corresponding event is triggered. |
| `addSocket` | `void addSocket(LuminaSocket socket)` | Appends a new item to the collection or scene. |
| `removeSocket` | `bool removeSocket(String name)` | Releases and safely disposes the specified `Socket` resource. |
| `findSocket` | `LuminaSocket? findSocket(String name)` | Searches and retrieves matching items or actors. |
| `socketNames` | `List<String> get socketNames` | Getter accessor returning the current value of `socketNames`. |
| `detachFromSocket` | `void detachFromSocket(LuminaSceneComponent component)` | Executes `detachFromSocket` operation. |
| `discoverMorphTargets` | `void discoverMorphTargets(FilamentAsset asset)` | Setter mutator assigning a new value to `discoverMorphTargets`. |
| `morphTargetNames` | `List<String> get morphTargetNames` | Getter accessor returning the current value of `morphTargetNames`. |
| `resolveMorphTarget` | `MorphTargetHandle resolveMorphTarget(String name)` | Executes `resolveMorphTarget` operation. |
| `setMorphTarget` | `void setMorphTarget(String name, double weight)` | Updates the `MorphTarget` parameter and applies changes to the system. |
| `setMorphTargetByHandle` | `void setMorphTargetByHandle(MorphTargetHandle handle, double weight)` | Updates the `MorphTargetByHandle` parameter and applies changes to the system. |
| `getMorphTarget` | `double getMorphTarget(String name)` | Queries and returns the `MorphTarget` value or child object. |
| `clearMorphTargets` | `void clearMorphTargets()` | Clears all elements from the collection or buffer. |

## `lib/src/components/mesh/skinning_buffer.dart`

### `class FilamentSkinningBufferBridge`

Bridge for Filament C++ RenderableManager::setSkinningBuffer FFI bindings. Allocates flat Float32List SIMD matrices for zero-GC GPU skinning uploads.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `requestedBoneCount` | `int requestedBoneCount` | Holds the `requestedBoneCount` property or configuration state. |
| `paletteBoneCount` | `int get paletteBoneCount` | The physical capacity of the buffer (rounded up to a multiple of 256). |
| `skinningTransforms` | `Float32List get skinningTransforms` | The memory view used to write matrices before upload. |
| `updateSkinningMatrices` | `void updateSkinningMatrices(Skeleton skeleton)` | Computes final skinning matrices ($M_{skinning} = G_{bone} \times InverseBindMatrix$) into [skinningTransforms]. Does zero memory allocation per frame. |
| `dispose` | `void dispose()` | Frees native memory and destroys the SkinningBuffer. Double-dispose safe. |

## `lib/src/components/mesh/static_mesh_component.dart`

### `class LuminaStaticMeshComponent`

Scene component rendering a static (non-skinned) 3D mesh via Filament and gltfio.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `meshAssetPath` | `String meshAssetPath` | Holds the `meshAssetPath` property or configuration state. |
| `isLoaded` | `bool get isLoaded` | Whether the glTF/GLB asset has completed loading and is active in the scene. |
| `loaded` | `Future<void> get loaded` | Future completing when the mesh asset finishes asynchronous loading and scene attachment. |
| `rootEntity` | `int? get rootEntity` | Root Filament entity of the loaded mesh hierarchy. |
| `entities` | `List<int> get entities` | All Filament entities belonging to the loaded mesh hierarchy (including root transform entity). |
| `localBounds` | `Aabb3? get localBounds` | Local bounding box of the loaded mesh. |
| `materialOverrideAsset` | `final String? materialOverrideAsset` | A material asset (a material `.lmas` or `.filamat`) drawn on every section in place of the mesh's own materials (a Blueprint Static Mesh component's Material Override); null keeps them, or the materials the mesh asset's slots name. |
| `drawsSlotMaterials` | `bool get drawsSlotMaterials` | Whether the materials assigned to the mesh asset's slots (`element_<n>` / `material_slot_<n>` references of its `.lmas`) are drawn on its sections; only one with a compiled package is. False for skeletal meshes. |
| `setMaterialOverride` | `void setMaterialOverride(dynamic mi, {int primitiveIndex = 0})` | Draws [mi] on section [primitiveIndex] (the renderables in entity order, each one's primitives in order); set before the mesh has loaded it is drawn once it does. The section's own material comes back when the override is cleared or the component leaves the world. |
| `setMaterialAsset` | `Future<void> setMaterialAsset(String path, {int primitiveIndex = 0})` | Draws the material asset at [path] (a material `.lmas` saved by the Material Editor, with its saved parameter values, or a `.filamat`) on section [primitiveIndex], loaded through the world's material cache (what Set Material runs). A later assignment to the same section wins over a load in flight. The component holds the material until the section's override is replaced or cleared or it leaves the world, then destroys its instance and releases the material, so the world's cache destroys it (and its textures) with its last user and the next load reads the asset again. |
| `isMaterialLoading` | `bool isMaterialLoading([int primitiveIndex = 0])` | Whether section [primitiveIndex] has no override yet but may get one from a material asset still loading: the mesh (and with it `materialOverrideAsset` or its slot materials) has not loaded, or a `setMaterialAsset` load is in flight, as at BeginPlay. |
| `materialOverrideWhenLoaded` | `Future<LuminaMaterialInstance?> materialOverrideWhenLoaded([int primitiveIndex = 0])` | The override the section draws once the mesh and its material assets have loaded; null when it gets none or the mesh failed to load. |
| `castShadows` | `bool get castShadows` | Getter accessor returning the current value of `castShadows`. |
| `castShadows` | `castShadows(bool value)` | Executes `castShadows` operation. |
| `receiveShadows` | `bool get receiveShadows` | Getter accessor returning the current value of `receiveShadows`. |
| `receiveShadows` | `receiveShadows(bool value)` | Executes `receiveShadows` operation. |
| `visible` | `bool get visible` | Getter accessor returning the current value of `visible`. |
| `visible` | `visible(bool value)` | Executes `visible` operation. |
| `onRegister` | `void onRegister(LuminaActor ownerActor)` | Callback invoked when the corresponding event is triggered. |
| `onRenderPrep` | `void onRenderPrep(LuminaWorld world)` | Callback invoked when the corresponding event is triggered. |
| `onUnregister` | `void onUnregister()` | Callback invoked when the corresponding event is triggered. |

## `lib/src/components/particles/particle_emitter_config.dart`

### `class LuminaParticleBurst`

Instantaneous particle burst event at a specific time in the emitter cycle.

**Constructors:**
- `LuminaParticleBurst(this.time, this.count)`: Initializes `LuminaParticleBurst(this.time, this.count)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `time` | `double time` | Holds the `time` property or configuration state. |
| `count` | `int count` | Holds the `count` property or configuration state. |

### `class LuminaGradientStop`

Color gradient stop along normalized particle lifetime [0, 1].

**Constructors:**
- `LuminaGradientStop(this.t, this.rgba)`: Initializes `LuminaGradientStop(this.t, this.rgba)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `t` | `double t` | Holds the `t` property or configuration state. |
| `rgba` | `Vector4 rgba` | Holds the `rgba` property or configuration state. |

### `class LuminaCurvePoint`

Scale curve point along normalized particle lifetime [0, 1].

**Constructors:**
- `LuminaCurvePoint(this.t, this.scale)`: Initializes `LuminaCurvePoint(this.t, this.scale)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `t` | `double t` | Holds the `t` property or configuration state. |
| `scale` | `double scale` | Holds the `scale` property or configuration state. |

### `class LuminaParticleEmitterConfig`

Immutable configuration template for particle emitter simulation and rendering properties.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `spawnRate` | `double spawnRate` | Holds the `spawnRate` property or configuration state. |
| `bursts` | `List<LuminaParticleBurst> bursts` | Holds the `bursts` property or configuration state. |
| `maxParticles` | `int maxParticles` | Holds the `maxParticles` property or configuration state. |
| `lifetimeMin` | `double lifetimeMin` | Holds the `lifetimeMin` property or configuration state. |
| `lifetimeMax` | `double lifetimeMax` | Holds the `lifetimeMax` property or configuration state. |
| `speedMin` | `double speedMin` | Holds the `speedMin` property or configuration state. |
| `speedMax` | `double speedMax` | Holds the `speedMax` property or configuration state. |
| `coneAngleDegrees` | `double coneAngleDegrees` | Holds the `coneAngleDegrees` property or configuration state. |
| `inheritVelocityScale` | `Vector3 inheritVelocityScale` | Holds the `inheritVelocityScale` property or configuration state. |
| `gravity` | `Vector3 gravity` | Holds the `gravity` property or configuration state. |
| `drag` | `double drag` | Holds the `drag` property or configuration state. |
| `colorOverLife` | `List<LuminaGradientStop> colorOverLife` | Holds the `colorOverLife` property or configuration state. |
| `sizeOverLife` | `List<LuminaCurvePoint> sizeOverLife` | Holds the `sizeOverLife` property or configuration state. |
| `looping` | `bool looping` | Holds the `looping` property or configuration state. |
| `duration` | `double duration` | Holds the `duration` property or configuration state. |
| `meshAssetPath` | `String? meshAssetPath` | Holds the `meshAssetPath` property or configuration state. |
| `billboard` | `bool billboard` | Holds the `billboard` property or configuration state. |
| `sampleSizeAt` | `double sampleSizeAt(double t)` | Evaluates the particle scale multiplier at normalized lifetime [t] (0.0 to 1.0). |
| `sampleColorAt` | `Vector4 sampleColorAt(double t)` | Evaluates the particle RGBA color at normalized lifetime [t] (0.0 to 1.0). |

## `lib/src/components/particles/particle_system_component.dart`

### `class LuminaParticleSystemComponent`

Scene component that simulates CPU particles and renders them as a pool of Filament instanced meshes.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `config` | `LuminaParticleEmitterConfig config` | Holds the `config` property or configuration state. |
| `autoActivate` | `bool autoActivate` | Holds the `autoActivate` property or configuration state. |
| `randomSeed` | `int? randomSeed` | Holds the `randomSeed` property or configuration state. |
| `liveParticleCount` | `int get liveParticleCount` | Getter accessor returning the current value of `liveParticleCount`. |
| `isActive` | `bool get isActive` | Checks current state or capability and returns a boolean value. |
| `getParticlePosition` | `Vector3 getParticlePosition(int index)` | Queries and returns the `ParticlePosition` value or child object. |
| `renderedParticleCount` | `int get renderedParticleCount` | Particles drawn at the last render prep. |
| `hasSpriteGeometry` | `bool get hasSpriteGeometry` | Whether the batched sprite geometry currently exists on the scene. |
| `spriteVertexCount` | `int get spriteVertexCount` | Vertices in the batched sprite section (8 per drawn particle). |
| `particleAgeAt` | `double particleAgeAt(int index)` | Normalized age of live particle [index] in `[0, 1]`. |
| `particleColorAt` | `Vector4 particleColorAt(int index) => config.sampleColorAt(particleAgeAt...` | The colour live particle [index] is drawn with, from its own age. |
| `particleSizeAt` | `double particleSizeAt(int index) => config.sampleSizeAt(particleAgeAt(in...` | The size multiplier live particle [index] is drawn with, from its own age. |
| `getParticleVelocity` | `Vector3 getParticleVelocity(int index)` | Queries and returns the `ParticleVelocity` value or child object. |
| `deactivate` | `void deactivate()` | Deactivates particle emission. Existing live particles continue until end of life. |
| `resetSimulation` | `void resetSimulation()` | Resets particle simulation and recycles all active particles. |
| `onRegister` | `void onRegister(LuminaActor ownerActor)` | Callback invoked when the corresponding event is triggered. |
| `onUnregister` | `void onUnregister()` | Callback invoked when the corresponding event is triggered. |
| `onTick` | `void onTick(double deltaTime)` | Callback invoked when the corresponding event is triggered. |
| `onRenderPrep` | `void onRenderPrep(LuminaWorld world)` | Callback invoked when the corresponding event is triggered. |

## `lib/src/components/mesh/animated_mesh_component.dart`

### `class LuminaJointOverride`

A local-space delta multiplied onto one animated joint every frame: `joint = animated · T(translation) · R(rotation)`.

**Constructors:**

- `LuminaJointOverride({Quaternion? rotation, Vector3? translation})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `rotation` | `final Quaternion rotation` |  |
| `translation` | `final Vector3 translation` |  |
| `matrix` | `Matrix4 get matrix` | The delta as a matrix (translation, then rotation). |
| `rotationDegrees` | `double get rotationDegrees` | The rotation's angle in degrees. |

### `class LuminaAnimatedMeshComponent`

A skinned glTF/GLB mesh that plays the animation clips stored in it, through gltfio's animator.

gltfio only animates the asset a clip is stored in, so every clip the mesh should play must live in the same GLB — see `GlbAnimationMerger`, which builds such a file from one-clip-per-file exports. Each component draws its own asset instance with its own animator, so characters sharing one cached GLB animate independently.

It also carries morph target weights (`LuminaMorphTargets`), discovered from its own instance on load and flushed after the clip and the joint overrides; `LuminaSpringMorphComponent` drives them for secondary motion.

Clips are addressed by name. A request made before the asset has loaded is remembered and applied on load (an unknown name is then left unplayed and reported through [missingClip]); after load an unknown name throws.

**Constructors:**

- `LuminaAnimatedMeshComponent({super.key, super.location, super.rotation, super.scale, required super.meshAssetPath, super.castShadows, super.receiveShadows, supe...`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `missingClip` | `String? missingClip` | A clip requested before load that the asset turned out not to have. |
| `jointOverrides` | `Map<String, LuminaJointOverride> get jointOverrides` | The joint overrides in force, by bone name. |
| `poseDriver` | `LuminaMeshPoseDriver? poseDriver` | A CPU pose source (motion matching) that replaces gltfio's animator while set: every frame its pose is written to the skin joints of the same names, then joint overrides apply and the bone matrices update. Null hands the joints back to the playing clip. |
| `poseModifiers` | `List<LuminaMeshPoseModifier> poseModifiers` | Run after the clip or the pose driver and the joint overrides: each reads and rewrites the local transforms of its `poseModifierNodes` (`modifyPose(pose, meshTransform, dt)`, see [Ragdolls](ragdoll.md)). |
| `missingJointOverrideBones` | `Set<String> get missingJointOverrideBones` | The overridden bones the mesh turned out not to have, each logged once. |
| `hasJoint` | `bool hasJoint(String bone)` | Whether the loaded mesh has a skin joint named [bone]. |
| `setJointOverride` | `void setJointOverride(String bone, {Quaternion? rotation, Vector3? translation})` | Multiplies a local-space delta onto [bone]'s animated transform every frame, after the clip is applied and before the bone matrices update (e.g. an aim offset): `joint = animated · T · R`. Replaces an earlier override of the same bone; a bone the mesh lacks is logged once and ignored. |
| `clearJointOverride` | `void clearJointOverride(String bone)` | Drops [bone]'s override; the animated transform is restored next frame (at once when no clip animates the bone). |
| `jointLocalTransform` | `Matrix4? jointLocalTransform(String bone)` | [bone]'s local transform (relative to its parent joint), as the transform manager holds it now; null before load or for an unknown bone. |
| `jointWorldTransform` | `Matrix4? jointWorldTransform(String bone)` | [bone]'s world transform (Filament's, including the owner's), as the transform manager holds it now; null before load or for an unknown bone. |
| `clipNames` | `List<String> get clipNames` | The clips stored in the mesh, in gltfio index order. Empty until loaded. |
| `hasClip` | `bool hasClip(String clip)` |  |
| `clipDuration` | `double clipDuration(String clip)` | Length of [clip] in seconds. |
| `currentClip` | `String? get currentClip` | The clip playing now (the fade target while cross-fading), or null. |
| `currentTime` | `double get currentTime` | Seconds into [currentClip]. |
| `isCrossFading` | `bool get isCrossFading` |  |
| `playRate` | `double get playRate` | Clip seconds per real second. 0 freezes the pose. |
| `playRate` | `set playRate(double value)` |  |
| `play` | `void play(String clip, {double startTime = 0.0, bool loop = true})` | Snaps to [clip] at [startTime], dropping any cross-fade in progress. |
| `crossFadeTo` | `void crossFadeTo(String clip, {double duration = 0.2, bool syncPhase = false, bool loop = true,})` | Blends from the current pose to [clip] over [duration] seconds. |
| `stop` | `void stop()` | Stops playback: the mesh holds its current pose and [currentClip] is null until the next [play]. |

---

[Previous: Components: base, movement, camera, light, audio, collision](components-core.md) | [Up: lumina (engine core)](index.md) | [Next: Components: environment and landscape](components-environment-and-landscape.md)

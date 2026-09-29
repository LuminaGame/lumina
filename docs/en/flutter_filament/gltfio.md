[Türkçe](../../tr/flutter_filament/gltfio.md)

# glTF loading and animation

Loading glTF 2.0 and GLB assets through gltfio: the asset and resource loaders, material providers, asset instances, the animator, node and TRS transform managers, Draco mesh decoding and a small animation state machine. File paths are relative to the `flutter_filament/` package directory.

**On this page:**

- [Native C bridge](#native-c-bridge)
  - [`src/gltf_c.h`](#srcgltf_ch)
- [Dart API](#dart-api)
  - [`lib/src/animation_state_machine.dart`](#libsrcanimation_state_machinedart)
  - [`lib/src/draco_decoder.dart`](#libsrcdraco_decoderdart)
  - [`lib/src/gltf_loader.dart`](#libsrcgltf_loaderdart)

## Native C bridge

The C functions below are declared in the package's `src/` headers and called from Dart through FFI.

### `src/gltf_c.h`

| C Function | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `filament_gltfio_create_ubershader_provider` | `FFI_PLUGIN_EXPORT void* filament_gltfio_create_ubershader_provider(...` | Allocates and initializes the native Filament `filament_gltfio_create_ubershader_provider` resource on the engine/GPU. |
| `filament_gltfio_create_jit_material_provider` | `FFI_PLUGIN_EXPORT void* filament_gltfio_create_jit_material_provide...` | Allocates and initializes the native Filament `filament_gltfio_create_jit_material_provider` resource on the engine/GPU. |
| `filament_gltfio_create_jit_material_provider_ex` | `FFI_PLUGIN_EXPORT void* filament_gltfio_create_jit_material_provide...` | Allocates and initializes the native Filament `filament_gltfio_create_jit_material_provider_ex` resource on the engine/GPU. |
| `filament_gltfio_destroy_material_provider` | `FFI_PLUGIN_EXPORT void filament_gltfio_destroy_material_provider(vo...` | Destroys the native Filament `filament_gltfio_destroy_material_provider` resource and releases GPU/host memory. |
| `filament_gltfio_material_provider_create_material_instance` | `FFI_PLUGIN_EXPORT void* filament_gltfio_material_provider_create_ma...` | Allocates and initializes the native Filament `filament_gltfio_material_provider_create_material_instance` resource on the engine/GPU. |
| `filament_gltfio_material_provider_get_materials` | `FFI_PLUGIN_EXPORT size_t filament_gltfio_material_provider_get_mate...` | Queries the `filament_gltfio_material_provider_get_materials` state, property, or counter from the native C layer. |
| `filament_gltfio_material_provider_needs_dummy_data` | `FFI_PLUGIN_EXPORT bool filament_gltfio_material_provider_needs_dumm...` | Executes native Filament `filament_gltfio_material_provider_needs_dummy_data` C binding. |
| `filament_gltfio_material_provider_get_materials_count` | `FFI_PLUGIN_EXPORT size_t filament_gltfio_material_provider_get_mate...` | Queries the `filament_gltfio_material_provider_get_materials_count` state, property, or counter from the native C layer. |
| `filament_gltfio_material_provider_destroy_materials` | `FFI_PLUGIN_EXPORT void filament_gltfio_material_provider_destroy_ma...` | Destroys the native Filament `filament_gltfio_material_provider_destroy_materials` resource and releases GPU/host memory. |
| `filament_gltfio_asset_loader_create` | `FFI_PLUGIN_EXPORT void* filament_gltfio_asset_loader_create(void* e...` | Allocates and initializes the native Filament `filament_gltfio_asset_loader_create` resource on the engine/GPU. |
| `filament_gltfio_asset_loader_create_with_names` | `FFI_PLUGIN_EXPORT void* filament_gltfio_asset_loader_create_with_na...` | Allocates and initializes the native Filament `filament_gltfio_asset_loader_create_with_names` resource on the engine/GPU. |
| `filament_gltfio_asset_loader_destroy` | `FFI_PLUGIN_EXPORT void filament_gltfio_asset_loader_destroy(void* l...` | Destroys the native Filament `filament_gltfio_asset_loader_destroy` resource and releases GPU/host memory. |
| `filament_gltfio_asset_loader_create_asset` | `FFI_PLUGIN_EXPORT void* filament_gltfio_asset_loader_create_asset(v...` | Allocates and initializes the native Filament `filament_gltfio_asset_loader_create_asset` resource on the engine/GPU. |
| `filament_gltfio_asset_loader_create_instanced_asset` | `FFI_PLUGIN_EXPORT void* filament_gltfio_asset_loader_create_instanc...` | Allocates and initializes the native Filament `filament_gltfio_asset_loader_create_instanced_asset` resource on the engine/GPU. |
| `filament_gltfio_asset_loader_create_instance` | `FFI_PLUGIN_EXPORT void* filament_gltfio_asset_loader_create_instanc...` | Allocates and initializes the native Filament `filament_gltfio_asset_loader_create_instance` resource on the engine/GPU. |
| `filament_gltfio_asset_loader_destroy_asset` | `FFI_PLUGIN_EXPORT void filament_gltfio_asset_loader_destroy_asset(v...` | Destroys the native Filament `filament_gltfio_asset_loader_destroy_asset` resource and releases GPU/host memory. |
| `filament_gltfio_asset_loader_gc` | `FFI_PLUGIN_EXPORT void filament_gltfio_asset_loader_gc(void* loader);` | Updates the `filament_gltfio_asset_loader_gc` parameter or state in the native C layer. |
| `filament_gltfio_resource_loader_create` | `FFI_PLUGIN_EXPORT void* filament_gltfio_resource_loader_create(void...` | Allocates and initializes the native Filament `filament_gltfio_resource_loader_create` resource on the engine/GPU. |
| `filament_gltfio_resource_loader_destroy` | `FFI_PLUGIN_EXPORT void filament_gltfio_resource_loader_destroy(void...` | Destroys the native Filament `filament_gltfio_resource_loader_destroy` resource and releases GPU/host memory. |
| `filament_gltfio_resource_loader_load_resources` | `FFI_PLUGIN_EXPORT bool filament_gltfio_resource_loader_load_resourc...` | Executes native Filament `filament_gltfio_resource_loader_load_resources` C binding. |
| `filament_gltfio_resource_loader_set_configuration` | `FFI_PLUGIN_EXPORT void filament_gltfio_resource_loader_set_configur...` | Updates the `filament_gltfio_resource_loader_set_configuration` parameter or state in the native C layer. |
| `filament_gltfio_resource_loader_add_texture_provider` | `FFI_PLUGIN_EXPORT void filament_gltfio_resource_loader_add_texture_...` | Executes native Filament `filament_gltfio_resource_loader_add_texture_provider` C binding. |
| `filament_gltfio_resource_loader_add_resource_data` | `FFI_PLUGIN_EXPORT void filament_gltfio_resource_loader_add_resource...` | Executes native Filament `filament_gltfio_resource_loader_add_resource_data` C binding. |
| `filament_gltfio_resource_loader_has_resource_data` | `FFI_PLUGIN_EXPORT bool filament_gltfio_resource_loader_has_resource...` | Validates or queries the `filament_gltfio_resource_loader_has_resource_data` state/capability. |
| `filament_gltfio_resource_loader_evict_resource_data` | `FFI_PLUGIN_EXPORT void filament_gltfio_resource_loader_evict_resour...` | Executes native Filament `filament_gltfio_resource_loader_evict_resource_data` C binding. |
| `filament_gltfio_resource_loader_async_begin_load` | `FFI_PLUGIN_EXPORT bool filament_gltfio_resource_loader_async_begin_...` | Executes native Filament `filament_gltfio_resource_loader_async_begin_load` C binding. |
| `filament_gltfio_resource_loader_async_get_load_progress` | `FFI_PLUGIN_EXPORT float filament_gltfio_resource_loader_async_get_l...` | Queries the `filament_gltfio_resource_loader_async_get_load_progress` state, property, or counter from the native C layer. |
| `filament_gltfio_resource_loader_async_update_load` | `FFI_PLUGIN_EXPORT void filament_gltfio_resource_loader_async_update...` | Executes native Filament `filament_gltfio_resource_loader_async_update_load` C binding. |
| `filament_gltfio_resource_loader_async_cancel_load` | `FFI_PLUGIN_EXPORT void filament_gltfio_resource_loader_async_cancel...` | Executes native Filament `filament_gltfio_resource_loader_async_cancel_load` C binding. |
| `filament_gltfio_asset_release_source_data` | `FFI_PLUGIN_EXPORT void filament_gltfio_asset_release_source_data(vo...` | Updates the `filament_gltfio_asset_release_source_data` parameter or state in the native C layer. |
| `filament_gltfio_asset_get_root` | `FFI_PLUGIN_EXPORT uint32_t filament_gltfio_asset_get_root(void* ass...` | Updates the `filament_gltfio_asset_get_root` parameter or state in the native C layer. |
| `filament_gltfio_asset_get_entity_count` | `FFI_PLUGIN_EXPORT uint32_t filament_gltfio_asset_get_entity_count(v...` | Updates the `filament_gltfio_asset_get_entity_count` parameter or state in the native C layer. |
| `filament_gltfio_asset_get_entities` | `FFI_PLUGIN_EXPORT const uint32_t* filament_gltfio_asset_get_entitie...` | Updates the `filament_gltfio_asset_get_entities` parameter or state in the native C layer. |
| `filament_gltfio_asset_get_bounding_box` | `FFI_PLUGIN_EXPORT void filament_gltfio_asset_get_bounding_box(void*...` | Updates the `filament_gltfio_asset_get_bounding_box` parameter or state in the native C layer. |
| `filament_gltfio_asset_get_light_entity_count` | `FFI_PLUGIN_EXPORT size_t filament_gltfio_asset_get_light_entity_cou...` | Updates the `filament_gltfio_asset_get_light_entity_count` parameter or state in the native C layer. |
| `filament_gltfio_asset_get_light_entities` | `FFI_PLUGIN_EXPORT const uint32_t* filament_gltfio_asset_get_light_e...` | Updates the `filament_gltfio_asset_get_light_entities` parameter or state in the native C layer. |
| `filament_gltfio_asset_get_renderable_entity_count` | `FFI_PLUGIN_EXPORT size_t filament_gltfio_asset_get_renderable_entit...` | Updates the `filament_gltfio_asset_get_renderable_entity_count` parameter or state in the native C layer. |
| `filament_gltfio_asset_get_renderable_entities` | `FFI_PLUGIN_EXPORT const uint32_t* filament_gltfio_asset_get_rendera...` | Updates the `filament_gltfio_asset_get_renderable_entities` parameter or state in the native C layer. |
| `filament_gltfio_asset_get_camera_entity_count` | `FFI_PLUGIN_EXPORT size_t filament_gltfio_asset_get_camera_entity_co...` | Updates the `filament_gltfio_asset_get_camera_entity_count` parameter or state in the native C layer. |
| `filament_gltfio_asset_get_camera_entities` | `FFI_PLUGIN_EXPORT const uint32_t* filament_gltfio_asset_get_camera_...` | Updates the `filament_gltfio_asset_get_camera_entities` parameter or state in the native C layer. |
| *... and 90 additional native C functions* | - | Library FFI bindings. |

## Dart API

### `lib/src/animation_state_machine.dart`

#### `class AnimationStateMachine`

A simple state machine that wraps [FilamentAnimator] to manage playback and cross-fading.

**Constructors:**
- `AnimationStateMachine(this._animator)`: Creates a state machine for the given [animator].

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `currentIndex` | `int get currentIndex` | The index of the currently playing animation. |
| `play` | `void play(int index)` | Jumps immediately to the given animation [index]. |
| `tick` | `void tick(double dt)` | Advances the animation by [dt] (in seconds) and applies it to the [FilamentAnimator].  This will: 1. Advance time and alpha. 2. Apply the current animation. 3. If fading, apply cross-fade with the previous animation. 4. Update the bone matrices. |

### `lib/src/draco_decoder.dart`

#### `class FilamentDracoDecodedMesh`

`FilamentDracoDecodedMesh`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `positions` | `List<double> positions` | Holds the `positions` property or configuration state. |
| `uvs` | `List<double> uvs` | Holds the `uvs` property or configuration state. |
| `indices` | `List<int> indices` | Holds the `indices` property or configuration state. |

#### `class FilamentDracoDecoder`

`FilamentDracoDecoder`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `decode` | `static FilamentDracoDecodedMesh? decode(Uint8List compressedBytes)` | Executes `decode` operation. |

### `lib/src/gltf_loader.dart`

#### `class MaterialKey`

Configuration for glTF materials

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `doubleSided` | `bool doubleSided` | Holds the `doubleSided` property or configuration state. |
| `unlit` | `bool unlit` | Holds the `unlit` property or configuration state. |
| `hasVertexColors` | `bool hasVertexColors` | Holds the `hasVertexColors` property or configuration state. |
| `hasBaseColorTexture` | `bool hasBaseColorTexture` | Holds the `hasBaseColorTexture` property or configuration state. |
| `hasNormalTexture` | `bool hasNormalTexture` | Holds the `hasNormalTexture` property or configuration state. |
| `hasOcclusionTexture` | `bool hasOcclusionTexture` | Holds the `hasOcclusionTexture` property or configuration state. |
| `hasEmissiveTexture` | `bool hasEmissiveTexture` | Holds the `hasEmissiveTexture` property or configuration state. |
| `useSpecularGlossiness` | `bool useSpecularGlossiness` | Holds the `useSpecularGlossiness` property or configuration state. |
| `alphaMode` | `int alphaMode` | Holds the `alphaMode` property or configuration state. |
| `enableDiagnostics` | `bool enableDiagnostics` | Holds the `enableDiagnostics` property or configuration state. |
| `hasMetallicRoughnessTexture` | `bool hasMetallicRoughnessTexture` | Holds the `hasMetallicRoughnessTexture` property or configuration state. |
| `metallicRoughnessUV` | `int metallicRoughnessUV` | Holds the `metallicRoughnessUV` property or configuration state. |
| `hasSpecularGlossinessTexture` | `bool hasSpecularGlossinessTexture` | Holds the `hasSpecularGlossinessTexture` property or configuration state. |
| `specularGlossinessUV` | `int specularGlossinessUV` | Holds the `specularGlossinessUV` property or configuration state. |
| `baseColorUV` | `int baseColorUV` | Holds the `baseColorUV` property or configuration state. |
| `hasClearCoatTexture` | `bool hasClearCoatTexture` | Holds the `hasClearCoatTexture` property or configuration state. |
| `clearCoatUV` | `int clearCoatUV` | Holds the `clearCoatUV` property or configuration state. |
| `hasClearCoatRoughnessTexture` | `bool hasClearCoatRoughnessTexture` | Holds the `hasClearCoatRoughnessTexture` property or configuration state. |
| `clearCoatRoughnessUV` | `int clearCoatRoughnessUV` | Holds the `clearCoatRoughnessUV` property or configuration state. |
| `hasClearCoatNormalTexture` | `bool hasClearCoatNormalTexture` | Holds the `hasClearCoatNormalTexture` property or configuration state. |
| `clearCoatNormalUV` | `int clearCoatNormalUV` | Holds the `clearCoatNormalUV` property or configuration state. |
| `hasClearCoat` | `bool hasClearCoat` | Holds the `hasClearCoat` property or configuration state. |
| `hasTransmission` | `bool hasTransmission` | Holds the `hasTransmission` property or configuration state. |
| `hasTextureTransforms` | `bool hasTextureTransforms` | Holds the `hasTextureTransforms` property or configuration state. |
| `emissiveUV` | `int emissiveUV` | Holds the `emissiveUV` property or configuration state. |
| `aoUV` | `int aoUV` | Holds the `aoUV` property or configuration state. |
| `normalUV` | `int normalUV` | Holds the `normalUV` property or configuration state. |
| `hasTransmissionTexture` | `bool hasTransmissionTexture` | Holds the `hasTransmissionTexture` property or configuration state. |
| `transmissionUV` | `int transmissionUV` | Holds the `transmissionUV` property or configuration state. |
| `hasSheenColorTexture` | `bool hasSheenColorTexture` | Holds the `hasSheenColorTexture` property or configuration state. |
| `sheenColorUV` | `int sheenColorUV` | Holds the `sheenColorUV` property or configuration state. |
| `hasSheenRoughnessTexture` | `bool hasSheenRoughnessTexture` | Holds the `hasSheenRoughnessTexture` property or configuration state. |
| `sheenRoughnessUV` | `int sheenRoughnessUV` | Holds the `sheenRoughnessUV` property or configuration state. |
| `hasVolumeThicknessTexture` | `bool hasVolumeThicknessTexture` | Holds the `hasVolumeThicknessTexture` property or configuration state. |
| `volumeThicknessUV` | `int volumeThicknessUV` | Holds the `volumeThicknessUV` property or configuration state. |
| `hasSheen` | `bool hasSheen` | Holds the `hasSheen` property or configuration state. |
| `hasIOR` | `bool hasIOR` | Holds the `hasIOR` property or configuration state. |
| `hasVolume` | `bool hasVolume` | Holds the `hasVolume` property or configuration state. |
| `hasDispersion` | `bool hasDispersion` | Holds the `hasDispersion` property or configuration state. |
| `hasSpecular` | `bool hasSpecular` | Holds the `hasSpecular` property or configuration state. |
| `hasSpecularTexture` | `bool hasSpecularTexture` | Holds the `hasSpecularTexture` property or configuration state. |
| `hasSpecularColorTexture` | `bool hasSpecularColorTexture` | Holds the `hasSpecularColorTexture` property or configuration state. |
| `specularTextureUV` | `int specularTextureUV` | Holds the `specularTextureUV` property or configuration state. |
| `specularColorTextureUV` | `int specularColorTextureUV` | Holds the `specularColorTextureUV` property or configuration state. |

#### `class MaterialProviderResult`

Result of creating a material instance via MaterialProvider.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `instance` | `FilamentMaterialInstance? instance` | Holds the `instance` property or configuration state. |
| `key` | `MaterialKey key` | Holds the `key` property or configuration state. |
| `uvMap` | `List<int> uvMap` | Holds the `uvMap` property or configuration state. |

#### `class FilamentMaterialProvider`

Material provider using ubershader materials for glTF rendering.

**Constructors:**
- `FilamentMaterialProvider._(this._ptr, this.engine)`: Initializes `FilamentMaterialProvider._(this._ptr, this.engine)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `engine` | `FilamentEngine engine` | Holds the `engine` property or configuration state. |
| `materialsCount` | `int get materialsCount` | Returns the number of cached Material instances owned by this provider. |
| `materials` | `List<FilamentMaterial?> get materials` | Returns the cached Material instances owned by this provider. |
| `needsDummyData` | `bool needsDummyData(int vertexAttribute)` | Check if the material provider needs dummy data for a vertex attribute (e.g. UV0). |
| `destroyMaterials` | `void destroyMaterials()` | Destroys all cached materials held by this provider. |
| `dispose` | `void dispose()` | Destroys this material provider and frees its cached materials. |
| `isDisposed` | `bool get isDisposed` | Checks current state or capability and returns a boolean value. |

#### `class FilamentAssetLoader`

Parses glTF and GLB binary files to produce [FilamentAsset] instances.

**Constructors:**
- `FilamentAssetLoader._(this._ptr, this._materialProvider, this.engine, [this.names])`: Initializes `FilamentAssetLoader._(this._ptr, this._materialProvider, this.engine, [this.names])`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `engine` | `FilamentEngine engine` | Holds the `engine` property or configuration state. |
| `names` | `NameComponentManager? names` | Holds the `names` property or configuration state. |
| `createAsset` | `FilamentAsset? createAsset(Uint8List bytes)` | Parses a GLB or glTF 2.0 byte buffer and creates a [FilamentAsset]. |
| `createInstance` | `FilamentAssetInstance? createInstance(FilamentAsset asset)` | Creates a new instance of a previously loaded [FilamentAsset].  Fails and returns null if the asset was not loaded as instanced or if `releaseSourceData` was already called. |
| `gc` | `void gc()` | Garbage collects unused internal resources in the asset loader. |
| `destroyAsset` | `void destroyAsset(FilamentAsset asset)` | Destroys an asset. |
| `dispose` | `void dispose()` | Destroys this AssetLoader. |
| `nodeManager` | `FilamentNodeManager get nodeManager` | Gets the NodeManager for accessing node attributes like extras and morph targets. |
| `isDisposed` | `bool get isDisposed` | Checks current state or capability and returns a boolean value. |

#### `class FilamentAsset`

A loaded glTF 2.0 3D model asset containing entities, transforms, materials, and animations.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `isInstanced` | `bool isInstanced` | Holds the `isInstanced` property or configuration state. |
| `instance` | `FilamentAssetInstance? get instance` | Gets the primary instance of this asset. |
| `trsTransformManager` | `FilamentTrsTransformManager get trsTransformManager` | Gets the TrsTransformManager for procedural animation of nodes. |
| `rootEntity` | `int get rootEntity` | Gets the root entity of the asset hierarchy. |
| `entityCount` | `int get entityCount` | Gets the total number of entities in the asset. |
| `entities` | `List<int> get entities` | Gets all entity IDs in the asset corresponding 1-to-1 with glTF nodes. |
| `addToScene` | `void addToScene(FilamentScene scene)` | Adds all entities in this asset to [scene]. |
| `removeFromScene` | `void removeFromScene(FilamentScene scene)` | Removes all entities in this asset from [scene]. |
| `releaseSourceData` | `void releaseSourceData()` | Releases temporary source glTF JSON/buffer memory after loading resources. |
| `animator` | `FilamentAnimator get animator` | Gets the [FilamentAnimator] interface for playing glTF animations. |
| `getWireframeEntity` | `int getWireframeEntity()` | Returns the wireframe entity for diagnostic lines rendering. |
| `getEntityName` | `String? getEntityName(int entity)` | Gets the glTF node name for [entity], or null if unnamed. |
| `getExtras` | `String? getExtras(int entity)` | Gets the extras JSON string for [entity], or null if none. |
| `getMorphTargetCountAt` | `int getMorphTargetCountAt(int entity)` | Gets the number of morph targets for [entity]. |
| `getMorphTargetNameAt` | `String? getMorphTargetNameAt(int entity, int target)` | Gets the morph target name for [entity] at [target] index, or null. |
| `getFirstEntityByName` | `int getFirstEntityByName(String name)` | Gets the first entity ID matching [name], or 0 if not found. |
| `getEntitiesByName` | `List<int> getEntitiesByName(String name)` | Gets all entity IDs matching [name]. |
| `getBoundingBox` | `Aabb getBoundingBox()` | Gets the axis-aligned bounding box of the asset. |
| `getSceneCount` | `int getSceneCount()` | Gets the total number of scenes in this asset. |
| `getSceneName` | `String? getSceneName(int sceneIndex)` | Gets the name of the scene at [sceneIndex], or null if unnamed. |
| `renderableEntityCount` | `int get renderableEntityCount` | Number of entities in this asset that have a renderable component. |
| `renderableEntities` | `List<int> get renderableEntities` | Entities in this asset that have a renderable component. |
| `lightEntityCount` | `int get lightEntityCount` | Number of entities in this asset that have a light component. |
| `lightEntities` | `List<int> get lightEntities` | Entities in this asset that have a light component (KHR_lights_punctual). |
| `cameraEntityCount` | `int get cameraEntityCount` | Number of entities in this asset that have a camera component. |
| `cameraEntities` | `List<int> get cameraEntities` | Entities in this asset that have a camera component. |
| `resourceUriCount` | `int get resourceUriCount` | Number of external resource URIs referenced by this asset. |
| `resourceUris` | `List<String> get resourceUris` | External resource URIs (buffers/images) referenced by this asset. |
| `popRenderable` | `int popRenderable()` | Pops one not-yet-popped renderable entity, or returns 0 when none remain.  Useful for progressive scene population while resources stream in. |
| `popRenderables` | `List<int> popRenderables(int max)` | Executes `popRenderables` operation. |
| `detachFilamentComponents` | `void detachFilamentComponents()` | Detaches Filament components from this asset's ownership. |
| `dispose` | `void dispose()` | Destroys this asset via its asset loader. |
| `isDisposed` | `bool get isDisposed` | Checks current state or capability and returns a boolean value. |

#### `class FilamentResourceLoader`

Controls loading external buffer/texture resources for a [FilamentAsset].

**Constructors:**
- `FilamentResourceLoader._(this._ptr)`: Initializes `FilamentResourceLoader._(this._ptr)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `loadResources` | `bool loadResources(FilamentAsset asset)` | Loads resources (buffers, textures) for [asset]. |
| `dispose` | `void dispose()` | Destroys this ResourceLoader. |
| `isDisposed` | `bool get isDisposed` | Checks current state or capability and returns a boolean value. |
| `addTextureProvider` | `void addTextureProvider(String mime, TextureProvider provider)` | Registers a TextureProvider for a specific MIME type. |
| `addResourceData` | `void addResourceData(String uri, Uint8List data)` | Feeds binary data for a specific URI into the loader. |
| `hasResourceData` | `bool hasResourceData(String uri)` | Checks if resource data for [uri] is present. |
| `evictResourceData` | `void evictResourceData()` | Evicts all resource data from the cache. |
| `asyncBeginLoad` | `void asyncBeginLoad(FilamentAsset asset)` | Begins asynchronous loading for [asset]. |
| `asyncUpdateLoad` | `void asyncUpdateLoad()` | Updates the async loading process. Must be called repeatedly (e.g. per frame). |
| `asyncGetLoadProgress` | `double asyncGetLoadProgress()` | Gets the async loading progress [0, 1]. |
| `asyncCancelLoad` | `void asyncCancelLoad()` | Cancels an in-progress async load. |
| `registerDefaultProviders` | `void registerDefaultProviders(FilamentEngine engine)` | Registers standard texture providers: stb (PNG/JPG), ktx2, and webp if available. |

#### `class FilamentWireframeMesh`

Represents a native Filament C++ Vulkan GPU Wireframe Mesh entity built from positions & indices.

**Constructors:**
- `FilamentWireframeMesh._(this._handle, this._engine)`: Initializes `FilamentWireframeMesh._(this._handle, this._engine)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `setColor` | `void setColor(double r, double g, double b, double a)` | Gets the native Filament C++ entity ID for adding to [FilamentScene]. Sets the base color of the wireframe mesh. |
| `hasMaterial` | `bool get hasMaterial` | Whether this mesh owns a compiled material instance.  False means the wireframe material failed to compile and Filament is drawing the lines with its default material, which ignores [setColor]: every wireframe comes out white. That is worth failing a test over, because nothing else about the render looks wrong. |
| `entityId` | `int get entityId` | Getter accessor returning the current value of `entityId`. |
| `dispose` | `void dispose()` | Destroys the native Filament wireframe mesh entity, vertex buffer, and index buffer. |
| `isDisposed` | `bool get isDisposed` | Checks current state or capability and returns a boolean value. |

#### `class FilamentAnimator`

Controls glTF animation playbacks and skeletal bone matrices.

**Constructors:**
- `FilamentAnimator._(this._ptr)`: Initializes `FilamentAnimator._(this._ptr)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `applyAnimation` | `void applyAnimation(int animationIndex, double timeSeconds)` | Applies rotation, translation, and scale to entities for animation [animationIndex] at [timeSeconds]. |
| `applyCrossFade` | `void applyCrossFade(int previousAnimIndex, double previousAnimTime, doub...` | Applies a cross-fade transition from a previous animation to the current animation.  You must call [applyAnimation] with the *next* clip first, and then call [applyCrossFade]. The [alpha] controls the blend between the previous clip (0.0) and the new clip (1.0). |
| `updateBoneMatrices` | `void updateBoneMatrices()` | Updates bone matrices for skinned models. |
| `resetBoneMatrices` | `void resetBoneMatrices()` | Resets the bone matrices to their rest pose. |
| `animationCount` | `int get animationCount` | Returns the number of animations in the asset. |
| `getAnimationDuration` | `double getAnimationDuration(int animationIndex)` | Returns the duration of animation at [animationIndex] in seconds. |
| `getAnimationName` | `String getAnimationName(int animationIndex)` | Returns the string name of animation at [animationIndex]. |

#### `class FilamentAssetInstance`

A specific instance of a [FilamentAsset].

**Constructors:**
- `FilamentAssetInstance._(this._ptr, this._asset)`: Initializes `FilamentAssetInstance._(this._ptr, this._asset)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `getAsset` | `FilamentAsset getAsset()` | Queries and returns the `Asset` value or child object. |
| `root` | `int get root` | Getter accessor returning the current value of `root`. |
| `entityCount` | `int get entityCount` | Getter accessor returning the current value of `entityCount`. |
| `entities` | `List<int> get entities` | Getter accessor returning the current value of `entities`. |
| `animator` | `FilamentAnimator get animator` | Getter accessor returning the current value of `animator`. |
| `skinCount` | `int get skinCount` | Getter accessor returning the current value of `skinCount`. |
| `skinNameAt` | `String? skinNameAt(int skinIndex)` | Executes `skinNameAt` operation. |
| `jointCountAt` | `int jointCountAt(int skinIndex) => c.filament_gltfio_instance_get_joint_...` | Executes `jointCountAt` operation. |
| `jointsAt` | `List<int> jointsAt(int skinIndex)` | Executes `jointsAt` operation. |
| `attachSkin` | `void attachSkin(int skinIndex, int targetEntity)` | Executes `attachSkin` operation. |
| `detachSkin` | `void detachSkin(int skinIndex, int targetEntity)` | Executes `detachSkin` operation. |
| `inverseBindMatricesAt` | `Float32List inverseBindMatricesAt(int skinIndex)` | Executes `inverseBindMatricesAt` operation. |
| `materialInstanceCount` | `int get materialInstanceCount` | Getter accessor returning the current value of `materialInstanceCount`. |
| `materialInstances` | `List<FilamentMaterialInstance> get materialInstances` | Getter accessor returning the current value of `materialInstances`. |
| `detachMaterialInstances` | `void detachMaterialInstances()` | Executes `detachMaterialInstances` operation. |
| `materialVariantCount` | `int get materialVariantCount` | Getter accessor returning the current value of `materialVariantCount`. |
| `materialVariantName` | `String? materialVariantName(int variantIndex)` | Executes `materialVariantName` operation. |
| `applyMaterialVariant` | `void applyMaterialVariant(int variantIndex)` | Executes `applyMaterialVariant` operation. |
| `recomputeBoundingBoxes` | `void recomputeBoundingBoxes()` | Executes `recomputeBoundingBoxes` operation. |
| `boundingBox` | `Aabb get boundingBox` | Getter accessor returning the current value of `boundingBox`. |

#### `class FilamentNodeManager`

`FilamentNodeManager`: `class` representing the data model or functionality of the module.

**Constructors:**
- `FilamentNodeManager._(this._ptr)`: Initializes `FilamentNodeManager._(this._ptr)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `hasComponent` | `bool hasComponent(int entity)` | Checks current state or capability and returns a boolean value. |
| `getExtras` | `String? getExtras(int entity)` | Queries and returns the `Extras` value or child object. |
| `setExtras` | `void setExtras(int entity, String json)` | Updates the `Extras` parameter and applies changes to the system. |
| `getMorphTargetNameCount` | `int getMorphTargetNameCount(int entity)` | Queries and returns the `MorphTargetNameCount` value or child object. |
| `getMorphTargetNameAt` | `String? getMorphTargetNameAt(int entity, int index)` | Queries and returns the `MorphTargetNameAt` value or child object. |
| `setMorphTargetNames` | `void setMorphTargetNames(int entity, List<String> names)` | Updates the `MorphTargetNames` parameter and applies changes to the system. |
| `getSceneMembership` | `int getSceneMembership(int entity)` | Queries and returns the `SceneMembership` value or child object. |
| `setSceneMembership` | `void setSceneMembership(int entity, int mask)` | Updates the `SceneMembership` parameter and applies changes to the system. |

#### `class FilamentTrsTransformManager`

`FilamentTrsTransformManager`: `class` representing the data model or functionality of the module.

**Constructors:**
- `FilamentTrsTransformManager._(this._ptr)`: Initializes `FilamentTrsTransformManager._(this._ptr)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `hasComponent` | `bool hasComponent(int entity)` | Checks current state or capability and returns a boolean value. |
| `setTranslation` | `void setTranslation(int entity, double x, double y, double z)` | Updates the `Translation` parameter and applies changes to the system. |
| `getTranslation` | `Float32List getTranslation(int entity)` | Queries and returns the `Translation` value or child object. |
| `setRotation` | `void setRotation(int entity, double qx, double qy, double qz, double qw)` | Updates the `Rotation` parameter and applies changes to the system. |
| `getRotation` | `Float32List getRotation(int entity)` | Queries and returns the `Rotation` value or child object. |
| `setScale` | `void setScale(int entity, double x, double y, double z)` | Updates the `Scale` parameter and applies changes to the system. |
| `getScale` | `Float32List getScale(int entity)` | Queries and returns the `Scale` value or child object. |
| `setTrs` | `void setTrs(int entity, Float32List translation, Float32List rotation, F...` | Updates the `Trs` parameter and applies changes to the system. |
| `getTransform` | `Float32List getTransform(int entity)` | Queries and returns the `Transform` value or child object. |

#### `class GltfLoader`

Helper wrapper / alias for loading glTF and GLB assets.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `assetLoader` | `FilamentAssetLoader get assetLoader` | Getter accessor returning the current value of `assetLoader`. |
| `loadGltf` | `FilamentAsset? loadGltf(Uint8List bytes) => _loader.createAsset(bytes)` | Loads data from disk or memory buffer into the engine. |
| `dispose` | `void dispose() => _loader.dispose()` | Releases native FFI pointers, event subscriptions, and allocated memory. |

---

[Previous: Textures and images](textures-and-images.md) | [Up: flutter_filament](index.md) | [Next: Math types](math.md)

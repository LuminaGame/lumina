[English](../../en/flutter_filament/gltfio.md)

# glTF yükleme ve animasyon

gltfio ile glTF 2.0 ve GLB asset'lerinin yüklenmesi: asset ve resource loader'lar, material provider'lar, asset instance'ları, animator, node ve TRS transform manager'ları, Draco mesh decode ve küçük bir animasyon state machine'i. Dosya yolları `flutter_filament/` paket dizinine görelidir.

**Bu sayfada:**

- [Native C köprüsü](#native-c-köprüsü)
  - [`src/gltf_c.h`](#srcgltf_ch)
- [Dart API](#dart-api)
  - [`lib/src/animation_state_machine.dart`](#libsrcanimation_state_machinedart)
  - [`lib/src/draco_decoder.dart`](#libsrcdraco_decoderdart)
  - [`lib/src/gltf_loader.dart`](#libsrcgltf_loaderdart)

## Native C köprüsü

Aşağıdaki C fonksiyonları paketin `src/` header'larında tanımlanır ve Dart'tan FFI ile çağrılır.

### `src/gltf_c.h`

| C Fonksiyonu | İmzası | Açıklama ve Ne İşe Yaradığı |
| :--- | :--- | :--- |
| `filament_gltfio_create_ubershader_provider` | `FFI_PLUGIN_EXPORT void* filament_gltfio_create_ubershader_provider(...` | İlgili Filament C API kaynağını GPU/motor üzerinde tahsis eder ve ilklendirir. |
| `filament_gltfio_create_jit_material_provider` | `FFI_PLUGIN_EXPORT void* filament_gltfio_create_jit_material_provide...` | İlgili Filament C API kaynağını GPU/motor üzerinde tahsis eder ve ilklendirir. |
| `filament_gltfio_create_jit_material_provider_ex` | `FFI_PLUGIN_EXPORT void* filament_gltfio_create_jit_material_provide...` | İlgili Filament C API kaynağını GPU/motor üzerinde tahsis eder ve ilklendirir. |
| `filament_gltfio_destroy_material_provider` | `FFI_PLUGIN_EXPORT void filament_gltfio_destroy_material_provider(vo...` | İlgili Filament C API nesnesini yok eder ve GPU belleğini serbest bırakır. |
| `filament_gltfio_material_provider_create_material_instance` | `FFI_PLUGIN_EXPORT void* filament_gltfio_material_provider_create_ma...` | İlgili Filament C API kaynağını GPU/motor üzerinde tahsis eder ve ilklendirir. |
| `filament_gltfio_material_provider_get_materials` | `FFI_PLUGIN_EXPORT size_t filament_gltfio_material_provider_get_mate...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_gltfio_material_provider_needs_dummy_data` | `FFI_PLUGIN_EXPORT bool filament_gltfio_material_provider_needs_dumm...` | Filament yerel `filament_gltfio_material_provider_needs_dummy_data` C fonksiyonunu çalıştırır. |
| `filament_gltfio_material_provider_get_materials_count` | `FFI_PLUGIN_EXPORT size_t filament_gltfio_material_provider_get_mate...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_gltfio_material_provider_destroy_materials` | `FFI_PLUGIN_EXPORT void filament_gltfio_material_provider_destroy_ma...` | İlgili Filament C API nesnesini yok eder ve GPU belleğini serbest bırakır. |
| `filament_gltfio_asset_loader_create` | `FFI_PLUGIN_EXPORT void* filament_gltfio_asset_loader_create(void* e...` | İlgili Filament C API kaynağını GPU/motor üzerinde tahsis eder ve ilklendirir. |
| `filament_gltfio_asset_loader_create_with_names` | `FFI_PLUGIN_EXPORT void* filament_gltfio_asset_loader_create_with_na...` | İlgili Filament C API kaynağını GPU/motor üzerinde tahsis eder ve ilklendirir. |
| `filament_gltfio_asset_loader_destroy` | `FFI_PLUGIN_EXPORT void filament_gltfio_asset_loader_destroy(void* l...` | İlgili Filament C API nesnesini yok eder ve GPU belleğini serbest bırakır. |
| `filament_gltfio_asset_loader_create_asset` | `FFI_PLUGIN_EXPORT void* filament_gltfio_asset_loader_create_asset(v...` | İlgili Filament C API kaynağını GPU/motor üzerinde tahsis eder ve ilklendirir. |
| `filament_gltfio_asset_loader_create_instanced_asset` | `FFI_PLUGIN_EXPORT void* filament_gltfio_asset_loader_create_instanc...` | İlgili Filament C API kaynağını GPU/motor üzerinde tahsis eder ve ilklendirir. |
| `filament_gltfio_asset_loader_create_instance` | `FFI_PLUGIN_EXPORT void* filament_gltfio_asset_loader_create_instanc...` | İlgili Filament C API kaynağını GPU/motor üzerinde tahsis eder ve ilklendirir. |
| `filament_gltfio_asset_loader_destroy_asset` | `FFI_PLUGIN_EXPORT void filament_gltfio_asset_loader_destroy_asset(v...` | İlgili Filament C API nesnesini yok eder ve GPU belleğini serbest bırakır. |
| `filament_gltfio_asset_loader_gc` | `FFI_PLUGIN_EXPORT void filament_gltfio_asset_loader_gc(void* loader);` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_gltfio_resource_loader_create` | `FFI_PLUGIN_EXPORT void* filament_gltfio_resource_loader_create(void...` | İlgili Filament C API kaynağını GPU/motor üzerinde tahsis eder ve ilklendirir. |
| `filament_gltfio_resource_loader_destroy` | `FFI_PLUGIN_EXPORT void filament_gltfio_resource_loader_destroy(void...` | İlgili Filament C API nesnesini yok eder ve GPU belleğini serbest bırakır. |
| `filament_gltfio_resource_loader_load_resources` | `FFI_PLUGIN_EXPORT bool filament_gltfio_resource_loader_load_resourc...` | Filament yerel `filament_gltfio_resource_loader_load_resources` C fonksiyonunu çalıştırır. |
| `filament_gltfio_resource_loader_set_configuration` | `FFI_PLUGIN_EXPORT void filament_gltfio_resource_loader_set_configur...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_gltfio_resource_loader_add_texture_provider` | `FFI_PLUGIN_EXPORT void filament_gltfio_resource_loader_add_texture_...` | Filament yerel `filament_gltfio_resource_loader_add_texture_provider` C fonksiyonunu çalıştırır. |
| `filament_gltfio_resource_loader_add_resource_data` | `FFI_PLUGIN_EXPORT void filament_gltfio_resource_loader_add_resource...` | Filament yerel `filament_gltfio_resource_loader_add_resource_data` C fonksiyonunu çalıştırır. |
| `filament_gltfio_resource_loader_has_resource_data` | `FFI_PLUGIN_EXPORT bool filament_gltfio_resource_loader_has_resource...` | Filament C motor durum veya yetenek doğrulamasını yapar. |
| `filament_gltfio_resource_loader_evict_resource_data` | `FFI_PLUGIN_EXPORT void filament_gltfio_resource_loader_evict_resour...` | Filament yerel `filament_gltfio_resource_loader_evict_resource_data` C fonksiyonunu çalıştırır. |
| `filament_gltfio_resource_loader_async_begin_load` | `FFI_PLUGIN_EXPORT bool filament_gltfio_resource_loader_async_begin_...` | Filament yerel `filament_gltfio_resource_loader_async_begin_load` C fonksiyonunu çalıştırır. |
| `filament_gltfio_resource_loader_async_get_load_progress` | `FFI_PLUGIN_EXPORT float filament_gltfio_resource_loader_async_get_l...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_gltfio_resource_loader_async_update_load` | `FFI_PLUGIN_EXPORT void filament_gltfio_resource_loader_async_update...` | Filament yerel `filament_gltfio_resource_loader_async_update_load` C fonksiyonunu çalıştırır. |
| `filament_gltfio_resource_loader_async_cancel_load` | `FFI_PLUGIN_EXPORT void filament_gltfio_resource_loader_async_cancel...` | Filament yerel `filament_gltfio_resource_loader_async_cancel_load` C fonksiyonunu çalıştırır. |
| `filament_gltfio_asset_release_source_data` | `FFI_PLUGIN_EXPORT void filament_gltfio_asset_release_source_data(vo...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_gltfio_asset_get_root` | `FFI_PLUGIN_EXPORT uint32_t filament_gltfio_asset_get_root(void* ass...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_gltfio_asset_get_entity_count` | `FFI_PLUGIN_EXPORT uint32_t filament_gltfio_asset_get_entity_count(v...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_gltfio_asset_get_entities` | `FFI_PLUGIN_EXPORT const uint32_t* filament_gltfio_asset_get_entitie...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_gltfio_asset_get_bounding_box` | `FFI_PLUGIN_EXPORT void filament_gltfio_asset_get_bounding_box(void*...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_gltfio_asset_get_light_entity_count` | `FFI_PLUGIN_EXPORT size_t filament_gltfio_asset_get_light_entity_cou...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_gltfio_asset_get_light_entities` | `FFI_PLUGIN_EXPORT const uint32_t* filament_gltfio_asset_get_light_e...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_gltfio_asset_get_renderable_entity_count` | `FFI_PLUGIN_EXPORT size_t filament_gltfio_asset_get_renderable_entit...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_gltfio_asset_get_renderable_entities` | `FFI_PLUGIN_EXPORT const uint32_t* filament_gltfio_asset_get_rendera...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_gltfio_asset_get_camera_entity_count` | `FFI_PLUGIN_EXPORT size_t filament_gltfio_asset_get_camera_entity_co...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_gltfio_asset_get_camera_entities` | `FFI_PLUGIN_EXPORT const uint32_t* filament_gltfio_asset_get_camera_...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| *... ve 90 ek C fonksiyonu* | - | İlgili C kütüphane bağlayıcıları. |

## Dart API

### `lib/src/animation_state_machine.dart`

#### `class AnimationStateMachine`

A simple state machine that wraps [FilamentAnimator] to manage playback and cross-fading.

**Yapıcı Metotlar (Constructors):**
- `AnimationStateMachine(this._animator)`: Creates a state machine for the given [animator].

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `currentIndex` | `int get currentIndex` | The index of the currently playing animation. |
| `play` | `void play(int index)` | Jumps immediately to the given animation [index]. |
| `tick` | `void tick(double dt)` | Advances the animation by [dt] (in seconds) and applies it to the [FilamentAnimator].  This will: 1. Advance time and alpha. 2. Apply the current animation. 3. If fading, apply cross-fade with the previous animation. 4. Update the bone matrices. |

### `lib/src/draco_decoder.dart`

#### `class FilamentDracoDecodedMesh`

`FilamentDracoDecodedMesh`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `positions` | `List<double> positions` | `positions` alanını (field/property) ve ilişkili veriyi saklar. |
| `uvs` | `List<double> uvs` | `uvs` alanını (field/property) ve ilişkili veriyi saklar. |
| `indices` | `List<int> indices` | `indices` alanını (field/property) ve ilişkili veriyi saklar. |

#### `class FilamentDracoDecoder`

`FilamentDracoDecoder`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `decode` | `static FilamentDracoDecodedMesh? decode(Uint8List compressedBytes)` | `decode` işlemini gerçekleştirir. |

### `lib/src/gltf_loader.dart`

#### `class MaterialKey`

Configuration for glTF materials

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `doubleSided` | `bool doubleSided` | `doubleSided` alanını (field/property) ve ilişkili veriyi saklar. |
| `unlit` | `bool unlit` | `unlit` alanını (field/property) ve ilişkili veriyi saklar. |
| `hasVertexColors` | `bool hasVertexColors` | `hasVertexColors` alanını (field/property) ve ilişkili veriyi saklar. |
| `hasBaseColorTexture` | `bool hasBaseColorTexture` | `hasBaseColorTexture` alanını (field/property) ve ilişkili veriyi saklar. |
| `hasNormalTexture` | `bool hasNormalTexture` | `hasNormalTexture` alanını (field/property) ve ilişkili veriyi saklar. |
| `hasOcclusionTexture` | `bool hasOcclusionTexture` | `hasOcclusionTexture` alanını (field/property) ve ilişkili veriyi saklar. |
| `hasEmissiveTexture` | `bool hasEmissiveTexture` | `hasEmissiveTexture` alanını (field/property) ve ilişkili veriyi saklar. |
| `useSpecularGlossiness` | `bool useSpecularGlossiness` | `useSpecularGlossiness` alanını (field/property) ve ilişkili veriyi saklar. |
| `alphaMode` | `int alphaMode` | `alphaMode` alanını (field/property) ve ilişkili veriyi saklar. |
| `enableDiagnostics` | `bool enableDiagnostics` | `enableDiagnostics` alanını (field/property) ve ilişkili veriyi saklar. |
| `hasMetallicRoughnessTexture` | `bool hasMetallicRoughnessTexture` | `hasMetallicRoughnessTexture` alanını (field/property) ve ilişkili veriyi saklar. |
| `metallicRoughnessUV` | `int metallicRoughnessUV` | `metallicRoughnessUV` alanını (field/property) ve ilişkili veriyi saklar. |
| `hasSpecularGlossinessTexture` | `bool hasSpecularGlossinessTexture` | `hasSpecularGlossinessTexture` alanını (field/property) ve ilişkili veriyi saklar. |
| `specularGlossinessUV` | `int specularGlossinessUV` | `specularGlossinessUV` alanını (field/property) ve ilişkili veriyi saklar. |
| `baseColorUV` | `int baseColorUV` | `baseColorUV` alanını (field/property) ve ilişkili veriyi saklar. |
| `hasClearCoatTexture` | `bool hasClearCoatTexture` | `hasClearCoatTexture` alanını (field/property) ve ilişkili veriyi saklar. |
| `clearCoatUV` | `int clearCoatUV` | `clearCoatUV` alanını (field/property) ve ilişkili veriyi saklar. |
| `hasClearCoatRoughnessTexture` | `bool hasClearCoatRoughnessTexture` | `hasClearCoatRoughnessTexture` alanını (field/property) ve ilişkili veriyi saklar. |
| `clearCoatRoughnessUV` | `int clearCoatRoughnessUV` | `clearCoatRoughnessUV` alanını (field/property) ve ilişkili veriyi saklar. |
| `hasClearCoatNormalTexture` | `bool hasClearCoatNormalTexture` | `hasClearCoatNormalTexture` alanını (field/property) ve ilişkili veriyi saklar. |
| `clearCoatNormalUV` | `int clearCoatNormalUV` | `clearCoatNormalUV` alanını (field/property) ve ilişkili veriyi saklar. |
| `hasClearCoat` | `bool hasClearCoat` | `hasClearCoat` alanını (field/property) ve ilişkili veriyi saklar. |
| `hasTransmission` | `bool hasTransmission` | `hasTransmission` alanını (field/property) ve ilişkili veriyi saklar. |
| `hasTextureTransforms` | `bool hasTextureTransforms` | `hasTextureTransforms` alanını (field/property) ve ilişkili veriyi saklar. |
| `emissiveUV` | `int emissiveUV` | `emissiveUV` alanını (field/property) ve ilişkili veriyi saklar. |
| `aoUV` | `int aoUV` | `aoUV` alanını (field/property) ve ilişkili veriyi saklar. |
| `normalUV` | `int normalUV` | `normalUV` alanını (field/property) ve ilişkili veriyi saklar. |
| `hasTransmissionTexture` | `bool hasTransmissionTexture` | `hasTransmissionTexture` alanını (field/property) ve ilişkili veriyi saklar. |
| `transmissionUV` | `int transmissionUV` | `transmissionUV` alanını (field/property) ve ilişkili veriyi saklar. |
| `hasSheenColorTexture` | `bool hasSheenColorTexture` | `hasSheenColorTexture` alanını (field/property) ve ilişkili veriyi saklar. |
| `sheenColorUV` | `int sheenColorUV` | `sheenColorUV` alanını (field/property) ve ilişkili veriyi saklar. |
| `hasSheenRoughnessTexture` | `bool hasSheenRoughnessTexture` | `hasSheenRoughnessTexture` alanını (field/property) ve ilişkili veriyi saklar. |
| `sheenRoughnessUV` | `int sheenRoughnessUV` | `sheenRoughnessUV` alanını (field/property) ve ilişkili veriyi saklar. |
| `hasVolumeThicknessTexture` | `bool hasVolumeThicknessTexture` | `hasVolumeThicknessTexture` alanını (field/property) ve ilişkili veriyi saklar. |
| `volumeThicknessUV` | `int volumeThicknessUV` | `volumeThicknessUV` alanını (field/property) ve ilişkili veriyi saklar. |
| `hasSheen` | `bool hasSheen` | `hasSheen` alanını (field/property) ve ilişkili veriyi saklar. |
| `hasIOR` | `bool hasIOR` | `hasIOR` alanını (field/property) ve ilişkili veriyi saklar. |
| `hasVolume` | `bool hasVolume` | `hasVolume` alanını (field/property) ve ilişkili veriyi saklar. |
| `hasDispersion` | `bool hasDispersion` | `hasDispersion` alanını (field/property) ve ilişkili veriyi saklar. |
| `hasSpecular` | `bool hasSpecular` | `hasSpecular` alanını (field/property) ve ilişkili veriyi saklar. |
| `hasSpecularTexture` | `bool hasSpecularTexture` | `hasSpecularTexture` alanını (field/property) ve ilişkili veriyi saklar. |
| `hasSpecularColorTexture` | `bool hasSpecularColorTexture` | `hasSpecularColorTexture` alanını (field/property) ve ilişkili veriyi saklar. |
| `specularTextureUV` | `int specularTextureUV` | `specularTextureUV` alanını (field/property) ve ilişkili veriyi saklar. |
| `specularColorTextureUV` | `int specularColorTextureUV` | `specularColorTextureUV` alanını (field/property) ve ilişkili veriyi saklar. |

#### `class MaterialProviderResult`

Result of creating a material instance via MaterialProvider.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `instance` | `FilamentMaterialInstance? instance` | `instance` alanını (field/property) ve ilişkili veriyi saklar. |
| `key` | `MaterialKey key` | `key` alanını (field/property) ve ilişkili veriyi saklar. |
| `uvMap` | `List<int> uvMap` | `uvMap` alanını (field/property) ve ilişkili veriyi saklar. |

#### `class FilamentMaterialProvider`

Material provider using ubershader materials for glTF rendering.

**Yapıcı Metotlar (Constructors):**
- `FilamentMaterialProvider._(this._ptr, this.engine)`: `FilamentMaterialProvider._(this._ptr, this.engine)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `engine` | `FilamentEngine engine` | `engine` alanını (field/property) ve ilişkili veriyi saklar. |
| `materialsCount` | `int get materialsCount` | Returns the number of cached Material instances owned by this provider. |
| `materials` | `List<FilamentMaterial?> get materials` | Returns the cached Material instances owned by this provider. |
| `needsDummyData` | `bool needsDummyData(int vertexAttribute)` | Check if the material provider needs dummy data for a vertex attribute (e.g. UV0). |
| `destroyMaterials` | `void destroyMaterials()` | Destroys all cached materials held by this provider. |
| `dispose` | `void dispose()` | Destroys this material provider and frees its cached materials. |
| `isDisposed` | `bool get isDisposed` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |

#### `class FilamentAssetLoader`

Parses glTF and GLB binary files to produce [FilamentAsset] instances.

**Yapıcı Metotlar (Constructors):**
- `FilamentAssetLoader._(this._ptr, this._materialProvider, this.engine, [this.names])`: `FilamentAssetLoader._(this._ptr, this._materialProvider, this.engine, [this.names])` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `engine` | `FilamentEngine engine` | `engine` alanını (field/property) ve ilişkili veriyi saklar. |
| `names` | `NameComponentManager? names` | `names` alanını (field/property) ve ilişkili veriyi saklar. |
| `createAsset` | `FilamentAsset? createAsset(Uint8List bytes)` | Parses a GLB or glTF 2.0 byte buffer and creates a [FilamentAsset]. |
| `createInstance` | `FilamentAssetInstance? createInstance(FilamentAsset asset)` | Creates a new instance of a previously loaded [FilamentAsset].  Fails and returns null if the asset was not loaded as instanced or if `releaseSourceData` was already called. |
| `gc` | `void gc()` | Garbage collects unused internal resources in the asset loader. |
| `destroyAsset` | `void destroyAsset(FilamentAsset asset)` | Destroys an asset. |
| `dispose` | `void dispose()` | Destroys this AssetLoader. |
| `nodeManager` | `FilamentNodeManager get nodeManager` | Gets the NodeManager for accessing node attributes like extras and morph targets. |
| `isDisposed` | `bool get isDisposed` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |

#### `class FilamentAsset`

A loaded glTF 2.0 3D model asset containing entities, transforms, materials, and animations.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `isInstanced` | `bool isInstanced` | `isInstanced` alanını (field/property) ve ilişkili veriyi saklar. |
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
| `popRenderables` | `List<int> popRenderables(int max)` | `popRenderables` işlemini gerçekleştirir. |
| `detachFilamentComponents` | `void detachFilamentComponents()` | Detaches Filament components from this asset's ownership. |
| `dispose` | `void dispose()` | Destroys this asset via its asset loader. |
| `isDisposed` | `bool get isDisposed` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |

#### `class FilamentResourceLoader`

Controls loading external buffer/texture resources for a [FilamentAsset].

**Yapıcı Metotlar (Constructors):**
- `FilamentResourceLoader._(this._ptr)`: `FilamentResourceLoader._(this._ptr)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `loadResources` | `bool loadResources(FilamentAsset asset)` | Loads resources (buffers, textures) for [asset]. |
| `dispose` | `void dispose()` | Destroys this ResourceLoader. |
| `isDisposed` | `bool get isDisposed` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
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

**Yapıcı Metotlar (Constructors):**
- `FilamentWireframeMesh._(this._handle, this._engine)`: `FilamentWireframeMesh._(this._handle, this._engine)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `setColor` | `void setColor(double r, double g, double b, double a)` | Gets the native Filament C++ entity ID for adding to [FilamentScene]. Sets the base color of the wireframe mesh. |
| `hasMaterial` | `bool get hasMaterial` | Whether this mesh owns a compiled material instance.  False means the wireframe material failed to compile and Filament is drawing the lines with its default material, which ignores [setColor]: every wireframe comes out white. That is worth failing a test over, because nothing else about the render looks wrong. |
| `entityId` | `int get entityId` | `entityId` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `dispose` | `void dispose()` | Destroys the native Filament wireframe mesh entity, vertex buffer, and index buffer. |
| `isDisposed` | `bool get isDisposed` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |

#### `class FilamentAnimator`

Controls glTF animation playbacks and skeletal bone matrices.

**Yapıcı Metotlar (Constructors):**
- `FilamentAnimator._(this._ptr)`: `FilamentAnimator._(this._ptr)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
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

**Yapıcı Metotlar (Constructors):**
- `FilamentAssetInstance._(this._ptr, this._asset)`: `FilamentAssetInstance._(this._ptr, this._asset)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `getAsset` | `FilamentAsset getAsset()` | `Asset` bilgisini veya alt nesnesini sorgulayıp döndürür. |
| `root` | `int get root` | `root` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `entityCount` | `int get entityCount` | `entityCount` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `entities` | `List<int> get entities` | `entities` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `animator` | `FilamentAnimator get animator` | `animator` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `skinCount` | `int get skinCount` | `skinCount` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `skinNameAt` | `String? skinNameAt(int skinIndex)` | `skinNameAt` işlemini gerçekleştirir. |
| `jointCountAt` | `int jointCountAt(int skinIndex) => c.filament_gltfio_instance_get_joint_...` | `jointCountAt` işlemini gerçekleştirir. |
| `jointsAt` | `List<int> jointsAt(int skinIndex)` | `jointsAt` işlemini gerçekleştirir. |
| `attachSkin` | `void attachSkin(int skinIndex, int targetEntity)` | `attachSkin` işlemini gerçekleştirir. |
| `detachSkin` | `void detachSkin(int skinIndex, int targetEntity)` | `detachSkin` işlemini gerçekleştirir. |
| `inverseBindMatricesAt` | `Float32List inverseBindMatricesAt(int skinIndex)` | `inverseBindMatricesAt` işlemini gerçekleştirir. |
| `materialInstanceCount` | `int get materialInstanceCount` | `materialInstanceCount` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `materialInstances` | `List<FilamentMaterialInstance> get materialInstances` | `materialInstances` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `detachMaterialInstances` | `void detachMaterialInstances()` | `detachMaterialInstances` işlemini gerçekleştirir. |
| `materialVariantCount` | `int get materialVariantCount` | `materialVariantCount` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `materialVariantName` | `String? materialVariantName(int variantIndex)` | `materialVariantName` işlemini gerçekleştirir. |
| `applyMaterialVariant` | `void applyMaterialVariant(int variantIndex)` | `applyMaterialVariant` işlemini gerçekleştirir. |
| `recomputeBoundingBoxes` | `void recomputeBoundingBoxes()` | `recomputeBoundingBoxes` işlemini gerçekleştirir. |
| `boundingBox` | `Aabb get boundingBox` | `boundingBox` özelliğinin anlık değerini okuyan getter erişimcisi. |

#### `class FilamentNodeManager`

`FilamentNodeManager`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `FilamentNodeManager._(this._ptr)`: `FilamentNodeManager._(this._ptr)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `hasComponent` | `bool hasComponent(int entity)` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `getExtras` | `String? getExtras(int entity)` | `Extras` bilgisini veya alt nesnesini sorgulayıp döndürür. |
| `setExtras` | `void setExtras(int entity, String json)` | `Extras` parametresini günceller ve sisteme uygular. |
| `getMorphTargetNameCount` | `int getMorphTargetNameCount(int entity)` | `MorphTargetNameCount` bilgisini veya alt nesnesini sorgulayıp döndürür. |
| `getMorphTargetNameAt` | `String? getMorphTargetNameAt(int entity, int index)` | `MorphTargetNameAt` bilgisini veya alt nesnesini sorgulayıp döndürür. |
| `setMorphTargetNames` | `void setMorphTargetNames(int entity, List<String> names)` | `MorphTargetNames` parametresini günceller ve sisteme uygular. |
| `getSceneMembership` | `int getSceneMembership(int entity)` | `SceneMembership` bilgisini veya alt nesnesini sorgulayıp döndürür. |
| `setSceneMembership` | `void setSceneMembership(int entity, int mask)` | `SceneMembership` parametresini günceller ve sisteme uygular. |

#### `class FilamentTrsTransformManager`

`FilamentTrsTransformManager`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `FilamentTrsTransformManager._(this._ptr)`: `FilamentTrsTransformManager._(this._ptr)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `hasComponent` | `bool hasComponent(int entity)` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `setTranslation` | `void setTranslation(int entity, double x, double y, double z)` | `Translation` parametresini günceller ve sisteme uygular. |
| `getTranslation` | `Float32List getTranslation(int entity)` | `Translation` bilgisini veya alt nesnesini sorgulayıp döndürür. |
| `setRotation` | `void setRotation(int entity, double qx, double qy, double qz, double qw)` | `Rotation` parametresini günceller ve sisteme uygular. |
| `getRotation` | `Float32List getRotation(int entity)` | `Rotation` bilgisini veya alt nesnesini sorgulayıp döndürür. |
| `setScale` | `void setScale(int entity, double x, double y, double z)` | `Scale` parametresini günceller ve sisteme uygular. |
| `getScale` | `Float32List getScale(int entity)` | `Scale` bilgisini veya alt nesnesini sorgulayıp döndürür. |
| `setTrs` | `void setTrs(int entity, Float32List translation, Float32List rotation, F...` | `Trs` parametresini günceller ve sisteme uygular. |
| `getTransform` | `Float32List getTransform(int entity)` | `Transform` bilgisini veya alt nesnesini sorgulayıp döndürür. |

#### `class GltfLoader`

Helper wrapper / alias for loading glTF and GLB assets.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `assetLoader` | `FilamentAssetLoader get assetLoader` | `assetLoader` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `loadGltf` | `FilamentAsset? loadGltf(Uint8List bytes) => _loader.createAsset(bytes)` | Veriyi diskten veya bellekten okuyarak motora yükler ve kullanılabilir hale getirir. |
| `dispose` | `void dispose() => _loader.dispose()` | Yerel FFI göstericilerini, dinleyicileri ve bellek bloklarını serbest bırakır. |

---

[Önceki: Texture'lar ve görseller](textures-and-images.md) | [Üst: flutter_filament](index.md) | [Sonraki: Matematik tipleri](math.md)

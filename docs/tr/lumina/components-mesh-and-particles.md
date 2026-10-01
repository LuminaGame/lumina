[English](../../en/lumina/components-mesh-and-particles.md)

# Bileşenler: mesh'ler ve parçacıklar

Geometri çizen component'ler: LOD'lu static ve instanced static mesh'ler, mesh asset cache, güncellenebilir section'lara sahip procedural mesh'ler, skeleton ve socket'li skinned mesh'ler, morph target'lar ve emitter yapılandırmasıyla CPU parçacık sistemi. Dosya yolları `lumina/` paket dizinine görelidir.

**Bu sayfada:**

- [`lib/src/components/mesh/instanced_static_mesh_component.dart`](#libsrccomponentsmeshinstanced_static_mesh_componentdart)
- [`lib/src/components/mesh/mesh_asset_cache.dart`](#libsrccomponentsmeshmesh_asset_cachedart)
- [`lib/src/components/mesh/morph_target_set.dart`](#libsrccomponentsmeshmorph_target_setdart)
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

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `vb` | `FilamentVertexBuffer vb` | `vb` alanını (field/property) ve ilişkili veriyi saklar. |
| `ib` | `FilamentIndexBuffer ib` | `ib` alanını (field/property) ve ilişkili veriyi saklar. |
| `indexCount` | `int indexCount` | `indexCount` alanını (field/property) ve ilişkili veriyi saklar. |
| `switchDistance` | `double switchDistance` | `switchDistance` alanını (field/property) ve ilişkili veriyi saklar. |

### `class LuminaInstancedStaticMeshComponent`

Scene component rendering thousands of mesh copies in a single GPU instanced draw call with LOD support.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `lods` | `List<LuminaStaticMeshLod> lods` | `lods` alanını (field/property) ve ilişkili veriyi saklar. |
| `material` | `FilamentMaterialInstance material` | `material` alanını (field/property) ve ilişkili veriyi saklar. |
| `capacity` | `int capacity` | `capacity` alanını (field/property) ve ilişkili veriyi saklar. |
| `lodHysteresis` | `double lodHysteresis` | `lodHysteresis` alanını (field/property) ve ilişkili veriyi saklar. |
| `initialBounds` | `Aabb3? initialBounds` | Bounding box the renderable is built with when the component registers.  Filament bakes a renderable's bounds at build time, so a batch that is registered before (or faster than) its instances arrive would otherwise be culled against a placeholder box. Callers that already know the volume their instances will occupy — a landscape's footprint, a streamed cell — pass it here; everyone else keeps the previous behaviour, which derives the box from the instances added before registration. |
| `instanceCount` | `int get instanceCount` | Number of live active instances. |
| `combinedBounds` | `Aabb3 get combinedBounds` | Combined axis-aligned bounding box encompassing all live instances. |
| `currentLodIndex` | `int get currentLodIndex` | Active LOD index (0 is highest detail). |
| `entity` | `int get entity` | Native Filament entity handle for this instanced renderable. |
| `instanceBuffer` | `InstanceBuffer? get instanceBuffer` | Active GPU instance buffer. |
| `onRegister` | `void onRegister(LuminaActor ownerActor)` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |
| `onUnregister` | `void onUnregister()` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |
| `addInstance` | `int addInstance(Matrix4 transform)` | Adds a new instance transform, returning its instance index. |
| `updateInstanceTransform` | `void updateInstanceTransform(int index, Matrix4 transform)` | Updates the transform for instance at [index]. |
| `removeInstance` | `bool removeInstance(int index)` | Removes instance at [index] using swap-remove, zero-scaling the freed slot. |
| `recalculateBounds` | `void recalculateBounds()` | Recalculates [combinedBounds] tightly over all active instance positions. |
| `flushTransformsToGpu` | `void flushTransformsToGpu()` | Flushes any pending local transform updates to the GPU instance buffer in a single batched upload. |

## `lib/src/components/mesh/mesh_asset_cache.dart`

### `class _CachedMeshEntry`

`_CachedMeshEntry`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `asset` | `FilamentAsset asset` | `asset` alanını (field/property) ve ilişkili veriyi saklar. |
| `bytes` | `Uint8List bytes` | `bytes` alanını (field/property) ve ilişkili veriyi saklar. |
| `refCount` | `int refCount` | `refCount` alanını (field/property) ve ilişkili veriyi saklar. |

### `class LuminaMeshAssetCache`

Refcounted mesh asset cache managing gltfio parsing and shared instancing across components.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `engine` | `FilamentEngine engine` | `engine` alanını (field/property) ve ilişkili veriyi saklar. |
| `materialProvider` | `FilamentMaterialProvider materialProvider` | `materialProvider` alanını (field/property) ve ilişkili veriyi saklar. |
| `assetLoader` | `final FilamentAssetLoader assetLoader` | `assetLoader` alanını (field/property) ve ilişkili veriyi saklar. |
| `resourceLoader` | `final FilamentResourceLoader resourceLoader` | `resourceLoader` alanını (field/property) ve ilişkili veriyi saklar. |
| `releaseInstance` | `void releaseInstance(String meshAssetPath, FilamentAssetInstance instance)` | Releases an acquired [FilamentAssetInstance], destroying the underlying asset when refCount reaches 0. |
| `dispose` | `void dispose()` | Disposes loaders and internal resources. |

## `lib/src/components/mesh/morph_target_set.dart`

### `class MorphTargetHandle`

`MorphTargetHandle`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `MorphTargetHandle(this.name, this.targets)`: `MorphTargetHandle(this.name, this.targets)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `name` | `String name` | `name` alanını (field/property) ve ilişkili veriyi saklar. |

### `class MorphTargetSet`

`MorphTargetSet`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `MorphTargetSet.fromAsset(FilamentAsset asset)`: `MorphTargetSet.fromAsset(FilamentAsset asset)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `names` | `List<String> get names` | `names` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `contains` | `bool contains(String name) => _handles.containsKey(name)` | `contains` işlemini gerçekleştirir. |
| `getHandle` | `MorphTargetHandle? getHandle(String name)` | `Handle` bilgisini veya alt nesnesini sorgulayıp döndürür. |

## `lib/src/components/mesh/procedural_mesh_component.dart`

### `class _ProceduralMeshSection`

`_ProceduralMeshSection`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `sectionIndex` | `int sectionIndex` | `sectionIndex` alanını (field/property) ve ilişkili veriyi saklar. |
| `vertexCount` | `int vertexCount` | `vertexCount` alanını (field/property) ve ilişkili veriyi saklar. |
| `triangleCount` | `int triangleCount` | `triangleCount` alanını (field/property) ve ilişkili veriyi saklar. |
| `stride` | `int stride` | `stride` alanını (field/property) ve ilişkili veriyi saklar. |
| `indexType` | `IndexType indexType` | `indexType` alanını (field/property) ve ilişkili veriyi saklar. |
| `entity` | `int entity` | `entity` alanını (field/property) ve ilişkili veriyi saklar. |
| `vertexBuffer` | `FilamentVertexBuffer? vertexBuffer` | `vertexBuffer` alanını (field/property) ve ilişkili veriyi saklar. |
| `indexBuffer` | `FilamentIndexBuffer? indexBuffer` | `indexBuffer` alanını (field/property) ve ilişkili veriyi saklar. |
| `material` | `FilamentMaterialInstance? material` | `material` alanını (field/property) ve ilişkili veriyi saklar. |
| `stagingByteSize` | `int stagingByteSize` | `stagingByteSize` alanını (field/property) ve ilişkili veriyi saklar. |
| `visible` | `bool visible` | `visible` alanını (field/property) ve ilişkili veriyi saklar. |
| `bounds` | `Aabb3 bounds` | `bounds` alanını (field/property) ve ilişkili veriyi saklar. |
| `hasNormals` | `bool hasNormals` | `hasNormals` alanını (field/property) ve ilişkili veriyi saklar. |
| `hasUv0` | `bool hasUv0` | `hasUv0` alanını (field/property) ve ilişkili veriyi saklar. |
| `hasColors` | `bool hasColors` | `hasColors` alanını (field/property) ve ilişkili veriyi saklar. |
| `hasTangents` | `bool hasTangents` | `hasTangents` alanını (field/property) ve ilişkili veriyi saklar. |
| `normalOffset` | `int normalOffset` | `normalOffset` alanını (field/property) ve ilişkili veriyi saklar. |
| `tangentOffset` | `int tangentOffset` | `tangentOffset` alanını (field/property) ve ilişkili veriyi saklar. |
| `uv0Offset` | `int uv0Offset` | `uv0Offset` alanını (field/property) ve ilişkili veriyi saklar. |
| `colorOffset` | `int colorOffset` | `colorOffset` alanını (field/property) ve ilişkili veriyi saklar. |
| `dispose` | `void dispose(FilamentEngine? engine, FilamentScene? scene)` | Yerel FFI göstericilerini, dinleyicileri ve bellek bloklarını serbest bırakır. |

### `class LuminaProceduralMeshComponent`

Component that allows building and deforming 3D meshes dynamically at runtime.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
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
| `onUnregister` | `void onUnregister()` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |

## `lib/src/components/mesh/skeletal_mesh_component.dart`

### `class LuminaSocket`

`LuminaSocket`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `LuminaSocket(this.name, this.boneName, this.localOffset)`: `LuminaSocket(this.name, this.boneName, this.localOffset)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `name` | `String name` | `name` alanını (field/property) ve ilişkili veriyi saklar. |
| `boneName` | `String boneName` | `boneName` alanını (field/property) ve ilişkili veriyi saklar. |
| `localOffset` | `Matrix4 localOffset` | `localOffset` alanını (field/property) ve ilişkili veriyi saklar. |

### `class _SocketAttachment`

`_SocketAttachment`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `_SocketAttachment(this.component, this.socketName, this.relativeOffset)`: `_SocketAttachment(this.component, this.socketName, this.relativeOffset)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `component` | `LuminaSceneComponent component` | `component` alanını (field/property) ve ilişkili veriyi saklar. |
| `socketName` | `String socketName` | `socketName` alanını (field/property) ve ilişkili veriyi saklar. |
| `relativeOffset` | `Matrix4 relativeOffset` | `relativeOffset` alanını (field/property) ve ilişkili veriyi saklar. |

### `class BoneNode`

`BoneNode`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `id` | `int id` | `id` alanını (field/property) ve ilişkili veriyi saklar. |
| `name` | `String name` | `name` alanını (field/property) ve ilişkili veriyi saklar. |
| `parentIndex` | `int parentIndex` | `parentIndex` alanını (field/property) ve ilişkili veriyi saklar. |
| `localTransform` | `Matrix4 localTransform` | `localTransform` alanını (field/property) ve ilişkili veriyi saklar. |
| `globalTransform` | `Matrix4 globalTransform` | `globalTransform` alanını (field/property) ve ilişkili veriyi saklar. |
| `inverseBindMatrix` | `Matrix4 inverseBindMatrix` | `inverseBindMatrix` alanını (field/property) ve ilişkili veriyi saklar. |
| `composeLocal` | `void composeLocal()` | `composeLocal` işlemini gerçekleştirir. |

### `class Skeleton`

`Skeleton`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `Skeleton(List<BoneNode> bones)`: `Skeleton(List<BoneNode> bones)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `boneCount` | `int get boneCount` | `boneCount` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `indexOfBone` | `int indexOfBone(String name)` | `indexOfBone` işlemini gerçekleştirir. |
| `findBone` | `BoneNode? findBone(String name)` | Belirtilen arama kriterlerine uyan nesneleri veya aktörleri bulup listeler. |
| `rootIndices` | `List<int> get rootIndices` | `rootIndices` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `updateGlobalTransforms` | `void updateGlobalTransforms()` | Mevcut verileri veya durumu günceller. |
| `resetToBindPose` | `void resetToBindPose()` | Değerleri veya durumları varsayılan ayarlarına sıfırlar. |

### `class TransformCurve`

`TransformCurve`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `TransformCurve(this.times, this.translations, this.rotations, this.scales)`: `TransformCurve(this.times, this.translations, this.rotations, this.scales)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `times` | `Float32List times` | `times` alanını (field/property) ve ilişkili veriyi saklar. |
| `translations` | `List<Vector3> translations` | `translations` alanını (field/property) ve ilişkili veriyi saklar. |
| `rotations` | `List<Quaternion> rotations` | `rotations` alanını (field/property) ve ilişkili veriyi saklar. |
| `scales` | `List<Vector3> scales` | `scales` alanını (field/property) ve ilişkili veriyi saklar. |
| `sampleInto` | `void sampleInto(double time, BoneNode bone)` | `sampleInto` işlemini gerçekleştirir. |

### `class LuminaSkinnedMeshComponent`

Skinned mesh component supporting bone hierarchies, sockets, and animation interpolation.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `meshAssetPath` | `String? meshAssetPath` | `meshAssetPath` alanını (field/property) ve ilişkili veriyi saklar. |
| `animInstance` | `LuminaAnimInstance? animInstance` | Active animation instance driving skeletal bone transforms. |
| `skeleton` | `Skeleton? get skeleton` | `skeleton` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `setSkeleton` | `void setSkeleton(Skeleton? s)` | `Skeleton` parametresini günceller ve sisteme uygular. |
| `onRegister` | `void onRegister(LuminaActor ownerActor)` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |
| `onUnregister` | `void onUnregister()` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |
| `onTick` | `void onTick(double deltaTime)` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |
| `addSocket` | `void addSocket(LuminaSocket socket)` | Koleksiyona veya sahneye yeni bir öğe ekler. |
| `removeSocket` | `bool removeSocket(String name)` | Belirtilen `Socket` nesnesini/bileşenini serbest bırakır ve güvenle temizler. |
| `findSocket` | `LuminaSocket? findSocket(String name)` | Belirtilen arama kriterlerine uyan nesneleri veya aktörleri bulup listeler. |
| `socketNames` | `List<String> get socketNames` | `socketNames` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `detachFromSocket` | `void detachFromSocket(LuminaSceneComponent component)` | `detachFromSocket` işlemini gerçekleştirir. |
| `discoverMorphTargets` | `void discoverMorphTargets(FilamentAsset asset)` | `discoverMorphTargets` özelliğine yeni değer atayan setter değiştiricisi. |
| `morphTargetNames` | `List<String> get morphTargetNames` | `morphTargetNames` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `resolveMorphTarget` | `MorphTargetHandle resolveMorphTarget(String name)` | `resolveMorphTarget` işlemini gerçekleştirir. |
| `setMorphTarget` | `void setMorphTarget(String name, double weight)` | `MorphTarget` parametresini günceller ve sisteme uygular. |
| `setMorphTargetByHandle` | `void setMorphTargetByHandle(MorphTargetHandle handle, double weight)` | `MorphTargetByHandle` parametresini günceller ve sisteme uygular. |
| `getMorphTarget` | `double getMorphTarget(String name)` | `MorphTarget` bilgisini veya alt nesnesini sorgulayıp döndürür. |
| `clearMorphTargets` | `void clearMorphTargets()` | Koleksiyon veya tampon içeriğini tamamen temizler. |

## `lib/src/components/mesh/skinning_buffer.dart`

### `class FilamentSkinningBufferBridge`

Bridge for Filament C++ RenderableManager::setSkinningBuffer FFI bindings. Allocates flat Float32List SIMD matrices for zero-GC GPU skinning uploads.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `requestedBoneCount` | `int requestedBoneCount` | `requestedBoneCount` alanını (field/property) ve ilişkili veriyi saklar. |
| `paletteBoneCount` | `int get paletteBoneCount` | The physical capacity of the buffer (rounded up to a multiple of 256). |
| `skinningTransforms` | `Float32List get skinningTransforms` | The memory view used to write matrices before upload. |
| `updateSkinningMatrices` | `void updateSkinningMatrices(Skeleton skeleton)` | Computes final skinning matrices ($M_{skinning} = G_{bone} \times InverseBindMatrix$) into [skinningTransforms]. Does zero memory allocation per frame. |
| `dispose` | `void dispose()` | Frees native memory and destroys the SkinningBuffer. Double-dispose safe. |

## `lib/src/components/mesh/static_mesh_component.dart`

### `class LuminaStaticMeshComponent`

Scene component rendering a static (non-skinned) 3D mesh via Filament and gltfio.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `meshAssetPath` | `String meshAssetPath` | `meshAssetPath` alanını (field/property) ve ilişkili veriyi saklar. |
| `isLoaded` | `bool get isLoaded` | Whether the glTF/GLB asset has completed loading and is active in the scene. |
| `loaded` | `Future<void> get loaded` | Future completing when the mesh asset finishes asynchronous loading and scene attachment. |
| `rootEntity` | `int? get rootEntity` | Root Filament entity of the loaded mesh hierarchy. |
| `entities` | `List<int> get entities` | All Filament entities belonging to the loaded mesh hierarchy (including root transform entity). |
| `localBounds` | `Aabb3? get localBounds` | Local bounding box of the loaded mesh. |
| `materialOverrideAsset` | `final String? materialOverrideAsset` | Mesh'in kendi materyalleri yerine her bölümde çizilen materyal asset'i (materyal `.lmas`'ı ya da `.filamat`; Blueprint Static Mesh bileşeninin Material Override'ı). Null ise mesh'in kendi materyalleri ya da mesh asset'inin slotlarındaki materyaller kalır. |
| `drawsSlotMaterials` | `bool get drawsSlotMaterials` | Mesh asset'inin slotlarına atanan materyallerin (`.lmas`'ındaki `element_<n>` / `material_slot_<n>` referansları) bölümlerde çizilip çizilmediği; yalnızca derlenmiş paketi olan materyal çizilir. Skeletal mesh'te false. |
| `setMaterialOverride` | `void setMaterialOverride(dynamic mi, {int primitiveIndex = 0})` | [mi]'yi [primitiveIndex] bölümünde çizer (renderable'lar entity sırasıyla, her birinin primitive'leri sırayla). Mesh yüklenmeden verilirse yüklenince çizilir. Override kaldırılınca ya da bileşen dünyadan çıkınca bölümün kendi materyali geri gelir. |
| `setMaterialAsset` | `Future<void> setMaterialAsset(String path, {int primitiveIndex = 0})` | [path]'teki materyal asset'ini (Material Editor'ün kaydettiği `.lmas`, kaydedilen parametre değerleriyle, ya da `.filamat`) dünyanın materyal önbelleğinden yükleyip [primitiveIndex] bölümünde çizer (Set Material bunu çalıştırır). Aynı bölüme sonra yapılan atama, hâlâ yüklenen atamanın önüne geçer. Bileşen materyali, bölümün override'ı değiştirilene ya da kaldırılana veya bileşen dünyadan çıkana kadar tutar; sonra instance'ını yok edip materyali bırakır, böylece dünyanın önbelleği onu (ve dokularını) son kullanıcısıyla birlikte yok eder ve sonraki yükleme asset'i yeniden okur. |
| `isMaterialLoading` | `bool isMaterialLoading([int primitiveIndex = 0])` | [primitiveIndex] bölümünün henüz override'ı yok ama hâlâ yüklenen bir materyal asset'inden alabilir mi: mesh (ve onunla `materialOverrideAsset` ya da slot materyalleri) yüklenmedi ya da bir `setMaterialAsset` yüklemesi sürüyor (BeginPlay'deki durum). |
| `materialOverrideWhenLoaded` | `Future<LuminaMaterialInstance?> materialOverrideWhenLoaded([int primitiveIndex = 0])` | Mesh ve materyal asset'leri yüklendiğinde bölümün çizdiği override; hiçbiri gelmezse ya da mesh yüklenemezse null. |
| `castShadows` | `bool get castShadows` | `castShadows` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `castShadows` | `castShadows(bool value)` | `castShadows` işlemini gerçekleştirir. |
| `receiveShadows` | `bool get receiveShadows` | `receiveShadows` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `receiveShadows` | `receiveShadows(bool value)` | `receiveShadows` işlemini gerçekleştirir. |
| `visible` | `bool get visible` | `visible` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `visible` | `visible(bool value)` | `visible` işlemini gerçekleştirir. |
| `onRegister` | `void onRegister(LuminaActor ownerActor)` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |
| `onRenderPrep` | `void onRenderPrep(LuminaWorld world)` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |
| `onUnregister` | `void onUnregister()` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |

## `lib/src/components/particles/particle_emitter_config.dart`

### `class LuminaParticleBurst`

Instantaneous particle burst event at a specific time in the emitter cycle.

**Yapıcı Metotlar (Constructors):**
- `LuminaParticleBurst(this.time, this.count)`: `LuminaParticleBurst(this.time, this.count)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `time` | `double time` | `time` alanını (field/property) ve ilişkili veriyi saklar. |
| `count` | `int count` | `count` alanını (field/property) ve ilişkili veriyi saklar. |

### `class LuminaGradientStop`

Color gradient stop along normalized particle lifetime [0, 1].

**Yapıcı Metotlar (Constructors):**
- `LuminaGradientStop(this.t, this.rgba)`: `LuminaGradientStop(this.t, this.rgba)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `t` | `double t` | `t` alanını (field/property) ve ilişkili veriyi saklar. |
| `rgba` | `Vector4 rgba` | `rgba` alanını (field/property) ve ilişkili veriyi saklar. |

### `class LuminaCurvePoint`

Scale curve point along normalized particle lifetime [0, 1].

**Yapıcı Metotlar (Constructors):**
- `LuminaCurvePoint(this.t, this.scale)`: `LuminaCurvePoint(this.t, this.scale)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `t` | `double t` | `t` alanını (field/property) ve ilişkili veriyi saklar. |
| `scale` | `double scale` | `scale` alanını (field/property) ve ilişkili veriyi saklar. |

### `class LuminaParticleEmitterConfig`

Immutable configuration template for particle emitter simulation and rendering properties.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `spawnRate` | `double spawnRate` | `spawnRate` alanını (field/property) ve ilişkili veriyi saklar. |
| `bursts` | `List<LuminaParticleBurst> bursts` | `bursts` alanını (field/property) ve ilişkili veriyi saklar. |
| `maxParticles` | `int maxParticles` | `maxParticles` alanını (field/property) ve ilişkili veriyi saklar. |
| `lifetimeMin` | `double lifetimeMin` | `lifetimeMin` alanını (field/property) ve ilişkili veriyi saklar. |
| `lifetimeMax` | `double lifetimeMax` | `lifetimeMax` alanını (field/property) ve ilişkili veriyi saklar. |
| `speedMin` | `double speedMin` | `speedMin` alanını (field/property) ve ilişkili veriyi saklar. |
| `speedMax` | `double speedMax` | `speedMax` alanını (field/property) ve ilişkili veriyi saklar. |
| `coneAngleDegrees` | `double coneAngleDegrees` | `coneAngleDegrees` alanını (field/property) ve ilişkili veriyi saklar. |
| `inheritVelocityScale` | `Vector3 inheritVelocityScale` | `inheritVelocityScale` alanını (field/property) ve ilişkili veriyi saklar. |
| `gravity` | `Vector3 gravity` | `gravity` alanını (field/property) ve ilişkili veriyi saklar. |
| `drag` | `double drag` | `drag` alanını (field/property) ve ilişkili veriyi saklar. |
| `colorOverLife` | `List<LuminaGradientStop> colorOverLife` | `colorOverLife` alanını (field/property) ve ilişkili veriyi saklar. |
| `sizeOverLife` | `List<LuminaCurvePoint> sizeOverLife` | `sizeOverLife` alanını (field/property) ve ilişkili veriyi saklar. |
| `looping` | `bool looping` | `looping` alanını (field/property) ve ilişkili veriyi saklar. |
| `duration` | `double duration` | `duration` alanını (field/property) ve ilişkili veriyi saklar. |
| `meshAssetPath` | `String? meshAssetPath` | `meshAssetPath` alanını (field/property) ve ilişkili veriyi saklar. |
| `billboard` | `bool billboard` | `billboard` alanını (field/property) ve ilişkili veriyi saklar. |
| `sampleSizeAt` | `double sampleSizeAt(double t)` | Evaluates the particle scale multiplier at normalized lifetime [t] (0.0 to 1.0). |
| `sampleColorAt` | `Vector4 sampleColorAt(double t)` | Evaluates the particle RGBA color at normalized lifetime [t] (0.0 to 1.0). |

## `lib/src/components/particles/particle_system_component.dart`

### `class LuminaParticleSystemComponent`

Scene component that simulates CPU particles and renders them as a pool of Filament instanced meshes.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `config` | `LuminaParticleEmitterConfig config` | `config` alanını (field/property) ve ilişkili veriyi saklar. |
| `autoActivate` | `bool autoActivate` | `autoActivate` alanını (field/property) ve ilişkili veriyi saklar. |
| `randomSeed` | `int? randomSeed` | `randomSeed` alanını (field/property) ve ilişkili veriyi saklar. |
| `liveParticleCount` | `int get liveParticleCount` | `liveParticleCount` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `isActive` | `bool get isActive` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `getParticlePosition` | `Vector3 getParticlePosition(int index)` | `ParticlePosition` bilgisini veya alt nesnesini sorgulayıp döndürür. |
| `renderedParticleCount` | `int get renderedParticleCount` | Particles drawn at the last render prep. |
| `hasSpriteGeometry` | `bool get hasSpriteGeometry` | Whether the batched sprite geometry currently exists on the scene. |
| `spriteVertexCount` | `int get spriteVertexCount` | Vertices in the batched sprite section (8 per drawn particle). |
| `particleAgeAt` | `double particleAgeAt(int index)` | Normalized age of live particle [index] in `[0, 1]`. |
| `particleColorAt` | `Vector4 particleColorAt(int index) => config.sampleColorAt(particleAgeAt...` | The colour live particle [index] is drawn with, from its own age. |
| `particleSizeAt` | `double particleSizeAt(int index) => config.sampleSizeAt(particleAgeAt(in...` | The size multiplier live particle [index] is drawn with, from its own age. |
| `getParticleVelocity` | `Vector3 getParticleVelocity(int index)` | `ParticleVelocity` bilgisini veya alt nesnesini sorgulayıp döndürür. |
| `deactivate` | `void deactivate()` | Deactivates particle emission. Existing live particles continue until end of life. |
| `resetSimulation` | `void resetSimulation()` | Resets particle simulation and recycles all active particles. |
| `onRegister` | `void onRegister(LuminaActor ownerActor)` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |
| `onUnregister` | `void onUnregister()` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |
| `onTick` | `void onTick(double deltaTime)` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |
| `onRenderPrep` | `void onRenderPrep(LuminaWorld world)` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |

## `lib/src/components/mesh/animated_mesh_component.dart`

### `class LuminaJointOverride`

A local-space delta multiplied onto one animated joint every frame: `joint = animated · T(translation) · R(rotation)`.

**Yapıcı Metotlar (Constructors):**

- `LuminaJointOverride({Quaternion? rotation, Vector3? translation})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `rotation` | `final Quaternion rotation` |  |
| `translation` | `final Vector3 translation` |  |
| `matrix` | `Matrix4 get matrix` | The delta as a matrix (translation, then rotation). |
| `rotationDegrees` | `double get rotationDegrees` | The rotation's angle in degrees. |

### `class LuminaAnimatedMeshComponent`

A skinned glTF/GLB mesh that plays the animation clips stored in it, through gltfio's animator.

gltfio only animates the asset a clip is stored in, so every clip the mesh should play must live in the same GLB — see `GlbAnimationMerger`, which builds such a file from one-clip-per-file exports. Each component draws its own asset instance with its own animator, so characters sharing one cached GLB animate independently.

Clips are addressed by name. A request made before the asset has loaded is remembered and applied on load (an unknown name is then left unplayed and reported through [missingClip]); after load an unknown name throws.

**Yapıcı Metotlar (Constructors):**

- `LuminaAnimatedMeshComponent({super.key, super.location, super.rotation, super.scale, required super.meshAssetPath, super.castShadows, super.receiveShadows, supe...`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `missingClip` | `String? missingClip` | A clip requested before load that the asset turned out not to have. |
| `jointOverrides` | `Map<String, LuminaJointOverride> get jointOverrides` | The joint overrides in force, by bone name. |
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

[Önceki: Bileşenler: temel, hareket, kamera, ışık, ses, çarpışma](components-core.md) | [Üst: lumina (engine çekirdeği)](index.md) | [Sonraki: Bileşenler: çevre ve landscape](components-environment-and-landscape.md)

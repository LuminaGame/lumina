[English](../../../en/lumina_ui/sub-editors/meshes.md)

# Static ve skeletal mesh editörleri

Static Mesh ve Skeletal Mesh editörleri: mesh önizlemesi, static mesh'ler için LOD slot'ları, çarpışma şekilleri ve materyal slot bağlamaları, skeletal mesh'ler için socket'ler. Dosya yolları `lumina_ui/` paket dizinine görelidir.

**Bu sayfada:**

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

`SkeletalMeshSubEditor`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `assetName` | `String assetName` | `assetName` alanını (field/property) ve ilişkili veriyi saklar. |
| `assetPath` | `String? assetPath` | `assetPath` alanını (field/property) ve ilişkili veriyi saklar. |
| `asset` | `RealAssetInfo? asset` | `asset` alanını (field/property) ve ilişkili veriyi saklar. |
| `viewModel` | `SkeletalMeshEditorViewModel? viewModel` | `viewModel` alanını (field/property) ve ilişkili veriyi saklar. |
| `onClose` | `VoidCallback? onClose` | `onClose` alanını (field/property) ve ilişkili veriyi saklar. |
| `onBind` | `SubEditorBindCallback? onBind` | `onBind` alanını (field/property) ve ilişkili veriyi saklar. |
| `createState` | `State<SkeletalMeshSubEditor> createState() => _SkeletalMeshSubEditorState()` | Yeni bir `State` örneği veya ilişkili GPU kaynağını oluşturur ve yapılandırır. |

### `class _SkeletalMeshSubEditorState`

`_SkeletalMeshSubEditorState`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `initState` | `void initState()` | `initState` işlemini gerçekleştirir. |
| `dispose` | `void dispose()` | Yerel FFI göstericilerini, dinleyicileri ve bellek bloklarını serbest bırakır. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

## `lib/ui/features/sub_editors/views/static_mesh_sub_editor.dart`

### `class StaticMeshSubEditor`

`StaticMeshSubEditor`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `assetName` | `String assetName` | `assetName` alanını (field/property) ve ilişkili veriyi saklar. |
| `assetPath` | `String? assetPath` | `assetPath` alanını (field/property) ve ilişkili veriyi saklar. |
| `asset` | `RealAssetInfo? asset` | `asset` alanını (field/property) ve ilişkili veriyi saklar. |
| `onClose` | `VoidCallback? onClose` | `onClose` alanını (field/property) ve ilişkili veriyi saklar. |
| `onBind` | `SubEditorBindCallback? onBind` | `onBind` alanını (field/property) ve ilişkili veriyi saklar. |
| `viewModel` | `StaticMeshEditorViewModel? viewModel` | `viewModel` alanını (field/property) ve ilişkili veriyi saklar. |
| `createState` | `State<StaticMeshSubEditor> createState() => _StaticMeshSubEditorState()` | Yeni bir `State` örneği veya ilişkili GPU kaynağını oluşturur ve yapılandırır. |

### `class _StaticMeshSubEditorState`

`_StaticMeshSubEditorState`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `initState` | `void initState()` | `initState` işlemini gerçekleştirir. |
| `dispose` | `void dispose()` | Yerel FFI göstericilerini, dinleyicileri ve bellek bloklarını serbest bırakır. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

## `lib/ui/features/sub_editors/view_models/skeletal_mesh_editor_view_model.dart`

### `class SkeletalMeshEditorViewModel`

`SkeletalMeshEditorViewModel`: İlgili arayüz modülünün durumunu (state) yöneten, kullanıcı aksiyonlarını yürüten ve görünümü güncelleyen ChangeNotifier ViewModel sınıfıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `assetPath` | `String assetPath` | `assetPath` alanını (field/property) ve ilişkili veriyi saklar. |
| `isLoading` | `bool get isLoading` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `hasError` | `bool get hasError` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `isDirty` | `bool get isDirty` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `asset` | `LuminaAsset? get asset` | `asset` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `glbMesh` | `GlbMeshData? get glbMesh` | `glbMesh` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `triangleCount` | `int get triangleCount` | `triangleCount` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `vertexCount` | `int get vertexCount` | `vertexCount` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `boneCount` | `int get boneCount` | `boneCount` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `maxInfluences` | `int get maxInfluences` | `maxInfluences` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `allBones` | `List<GlbNode> get allBones` | `allBones` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `rootBones` | `List<GlbNode> get rootBones` | `rootBones` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `selectedBone` | `GlbNode? get selectedBone` | İlgili aktör veya varlığı seçili duruma getirir. |
| `selectedSocket` | `SkeletalMeshSocket? get selectedSocket` | İlgili aktör veya varlığı seçili duruma getirir. |
| `sockets` | `List<SkeletalMeshSocket> get sockets` | `sockets` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `boneRetargeting` | `Map<String, String> get boneRetargeting` | `boneRetargeting` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `morphTargets` | `List<GlbMorphTarget> get morphTargets` | `morphTargets` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `morphWeights` | `Map<String, double> get morphWeights` | `morphWeights` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `activeMorphTargetCount` | `int get activeMorphTargetCount` | `activeMorphTargetCount` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `showBones` | `bool get showBones` | `showBones` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `displaySockets` | `bool get displaySockets` | `displaySockets` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `heatmapEnabled` | `bool get heatmapEnabled` | `heatmapEnabled` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `inspectedVertex` | `int? get inspectedVertex` | `inspectedVertex` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `boneSearchFilter` | `String get boneSearchFilter` | `boneSearchFilter` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `allBoneNames` | `List<String> get allBoneNames` | `allBoneNames` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `fileBasename` | `String get fileBasename` | `fileBasename` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `load` | `Future<void> load()` | Veriyi diskten veya bellekten okuyarak motora yükler ve kullanılabilir hale getirir. |
| `setBoneSearchFilter` | `void setBoneSearchFilter(String filter)` | `BoneSearchFilter` parametresini günceller ve sisteme uygular. |
| `selectBone` | `void selectBone(GlbNode? bone)` | İlgili aktör veya varlığı seçili duruma getirir. |
| `selectSocket` | `void selectSocket(SkeletalMeshSocket? socket)` | İlgili aktör veya varlığı seçili duruma getirir. |
| `toggleShowBones` | `void toggleShowBones()` | İlgili özelliğin açık/kapalı durumunu tersine çevirir. |
| `toggleDisplaySockets` | `void toggleDisplaySockets()` | İlgili özelliğin açık/kapalı durumunu tersine çevirir. |
| `toggleHeatmap` | `void toggleHeatmap()` | İlgili özelliğin açık/kapalı durumunu tersine çevirir. |
| `setHeatmapEnabled` | `void setHeatmapEnabled(bool enabled)` | `HeatmapEnabled` parametresini günceller ve sisteme uygular. |
| `setInspectedVertex` | `void setInspectedVertex(int? vertIndex)` | `InspectedVertex` parametresini günceller ve sisteme uygular. |
| `setMorphWeight` | `void setMorphWeight(String name, double weight)` | `MorphWeight` parametresini günceller ve sisteme uygular. |
| `resetMorphs` | `void resetMorphs()` | Değerleri veya durumları varsayılan ayarlarına sıfırlar. |
| `deformedPositions` | `Float32List deformedPositions()` | `deformedPositions` işlemini gerçekleştirir. |
| `heatmapColors` | `Uint8List? heatmapColors(int? boneNodeIndex)` | `heatmapColors` işlemini gerçekleştirir. |
| `getVertexInfluences` | `Map<String, double> getVertexInfluences(int vertIndex)` | `VertexInfluences` bilgisini veya alt nesnesini sorgulayıp döndürür. |
| `getVertexWeightSum` | `double getVertexWeightSum(int vertIndex)` | `VertexWeightSum` bilgisini veya alt nesnesini sorgulayıp döndürür. |
| `renameSocket` | `bool renameSocket(String oldName, String newName)` | `renameSocket` işlemini gerçekleştirir. |
| `reparentSocket` | `bool reparentSocket(String socketName, String newParentBone)` | `reparentSocket` işlemini gerçekleştirir. |
| `setSocketPreviewAsset` | `void setSocketPreviewAsset(String socketName, String? assetPath)` | `SocketPreviewAsset` parametresini günceller ve sisteme uygular. |
| `removeSocket` | `bool removeSocket(String socketName)` | Belirtilen `Socket` nesnesini/bileşenini serbest bırakır ve güvenle temizler. |
| `setBoneRetargeting` | `void setBoneRetargeting(String boneName, String option)` | `BoneRetargeting` parametresini günceller ve sisteme uygular. |
| `getSocketsForBone` | `List<SkeletalMeshSocket> getSocketsForBone(String boneName)` | `SocketsForBone` bilgisini veya alt nesnesini sorgulayıp döndürür. |
| `save` | `Future<bool> save()` | Mevcut durumu veya varlığı diske dosya olarak serileştirip yazar. |

## `lib/ui/features/sub_editors/view_models/static_mesh_editor_view_model.dart`

### `class StaticMeshEditorViewModel`

`StaticMeshEditorViewModel`: İlgili arayüz modülünün durumunu (state) yöneten, kullanıcı aksiyonlarını yürüten ve görünümü güncelleyen ChangeNotifier ViewModel sınıfıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `assetPath` | `String assetPath` | `assetPath` alanını (field/property) ve ilişkili veriyi saklar. |
| `isLoading` | `bool get isLoading` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `hasError` | `bool get hasError` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `isDirty` | `bool get isDirty` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `asset` | `LuminaAsset? get asset` | `asset` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `glbMesh` | `GlbMeshData? get glbMesh` | `glbMesh` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `triangleCount` | `int get triangleCount` | `triangleCount` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `vertexCount` | `int get vertexCount` | `vertexCount` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `uvChannelsCount` | `int get uvChannelsCount` | `uvChannelsCount` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `sectionCount` | `int get sectionCount` | `sectionCount` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `minBounds` | `List<double> get minBounds` | `minBounds` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `maxBounds` | `List<double> get maxBounds` | `maxBounds` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `boundsWidth` | `double get boundsWidth` | `boundsWidth` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `boundsDepth` | `double get boundsDepth` | `boundsDepth` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `boundsHeight` | `double get boundsHeight` | `boundsHeight` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `materialSlots` | `List<MaterialSlotBinding> get materialSlots` | `materialSlots` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `collisionShapes` | `List<StaticMeshCollisionShape> get collisionShapes` | `collisionShapes` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `collisionComplexity` | `String get collisionComplexity` | `collisionComplexity` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `massKg` | `double get massKg` | `massKg` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `centerOfMassOffset` | `List<double> get centerOfMassOffset` | `centerOfMassOffset` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `showCollisionWireframe` | `bool get showCollisionWireframe` | `showCollisionWireframe` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `lods` | `List<LodSlot> get lods` | `lods` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `forcedLod` | `int? get forcedLod` | `forcedLod` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `lodGroup` | `String get lodGroup` | `lodGroup` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `autoComputeLodDistances` | `bool get autoComputeLodDistances` | `autoComputeLodDistances` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `activePreviewLod` | `LodSlot get activePreviewLod` | `activePreviewLod` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `fileBasename` | `String get fileBasename` | `fileBasename` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `load` | `Future<void> load()` | Veriyi diskten veya bellekten okuyarak motora yükler ve kullanılabilir hale getirir. |
| `addLod` | `void addLod()` | Koleksiyona veya sahneye yeni bir öğe ekler. |
| `removeLod` | `void removeLod(int level)` | Belirtilen `Lod` nesnesini/bileşenini serbest bırakır ve güvenle temizler. |
| `setLodRatio` | `void setLodRatio(int level, double ratio)` | `LodRatio` parametresini günceller ve sisteme uygular. |
| `setLodScreenSize` | `bool setLodScreenSize(int level, double screenSize)` | `LodScreenSize` parametresini günceller ve sisteme uygular. |
| `setLodMaterialOverride` | `void setLodMaterialOverride(int level, String slotName, String? material...` | `LodMaterialOverride` parametresini günceller ve sisteme uygular. |
| `setLodGroup` | `void setLodGroup(String group)` | `LodGroup` parametresini günceller ve sisteme uygular. |
| `setAutoComputeLodDistances` | `void setAutoComputeLodDistances(bool enabled)` | `AutoComputeLodDistances` parametresini günceller ve sisteme uygular. |
| `setForcedLod` | `void setForcedLod(int? level)` | `ForcedLod` parametresini günceller ve sisteme uygular. |
| `highlightMaterial` | `void highlightMaterial(int slotIndex, bool enabled)` | `highlightMaterial` işlemini gerçekleştirir. |
| `isolateMaterial` | `void isolateMaterial(int slotIndex, bool enabled)` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `generateCollision` | `void generateCollision(StaticMeshCollisionShapeType type)` | `generateCollision` işlemini gerçekleştirir. |
| `removeCollision` | `void removeCollision()` | Belirtilen `Collision` nesnesini/bileşenini serbest bırakır ve güvenle temizler. |
| `setCollisionComplexity` | `void setCollisionComplexity(String val)` | `CollisionComplexity` parametresini günceller ve sisteme uygular. |
| `setMass` | `void setMass(double val)` | `Mass` parametresini günceller ve sisteme uygular. |
| `setCenterOfMassOffset` | `void setCenterOfMassOffset(List<double> offset)` | `CenterOfMassOffset` parametresini günceller ve sisteme uygular. |
| `toggleCollisionWireframe` | `void toggleCollisionWireframe()` | İlgili özelliğin açık/kapalı durumunu tersine çevirir. |
| `save` | `Future<bool> save()` | Mevcut durumu veya varlığı diske dosya olarak serileştirip yazar. |

## `lib/ui/features/sub_editors/models/skeletal_mesh_socket.dart`

### `class SkeletalMeshSocket`

`SkeletalMeshSocket`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `SkeletalMeshSocket.fromJson(Map<String, dynamic> json)`: `SkeletalMeshSocket.fromJson(Map<String, dynamic> json)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `name` | `String name` | `name` alanını (field/property) ve ilişkili veriyi saklar. |
| `parentBone` | `String parentBone` | `parentBone` alanını (field/property) ve ilişkili veriyi saklar. |
| `relativeLocation` | `List<double> relativeLocation` | `relativeLocation` alanını (field/property) ve ilişkili veriyi saklar. |
| `relativeRotation` | `List<double> relativeRotation` | `relativeRotation` alanını (field/property) ve ilişkili veriyi saklar. |
| `relativeScale` | `List<double> relativeScale` | `relativeScale` alanını (field/property) ve ilişkili veriyi saklar. |
| `previewAssetPath` | `String? previewAssetPath` | `previewAssetPath` alanını (field/property) ve ilişkili veriyi saklar. |
| `toJson` | `Map<String, dynamic> toJson()` | Nesneyi JSON haritasına serileştirir. |

## `lib/ui/features/sub_editors/models/static_mesh_collision.dart`

### `enum StaticMeshCollisionShapeType`

`StaticMeshCollisionShapeType`: Sistemde kullanılan seçenekleri ve durumları listeleyen numaralandırma türüdür.

### `class StaticMeshCollisionShape`

`StaticMeshCollisionShape`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `StaticMeshCollisionShape.fromJson(Map<String, dynamic> json)`: `StaticMeshCollisionShape.fromJson(Map<String, dynamic> json)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `type` | `StaticMeshCollisionShapeType type` | `type` alanını (field/property) ve ilişkili veriyi saklar. |
| `center` | `List<double> center` | `center` alanını (field/property) ve ilişkili veriyi saklar. |
| `extents` | `List<double>? extents` | `extents` alanını (field/property) ve ilişkili veriyi saklar. |
| `radius` | `double? radius` | `radius` alanını (field/property) ve ilişkili veriyi saklar. |
| `halfHeight` | `double? halfHeight` | `halfHeight` alanını (field/property) ve ilişkili veriyi saklar. |
| `axis` | `String? axis` | `axis` alanını (field/property) ve ilişkili veriyi saklar. |
| `points` | `List<List<double>>? points` | `points` alanını (field/property) ve ilişkili veriyi saklar. |
| `toJson` | `Map<String, dynamic> toJson()` | Nesneyi JSON haritasına serileştirir. |
| `createBox` | `static StaticMeshCollisionShape createBox(List<double> minBounds, List<d...` | Yeni bir `Box` örneği veya ilişkili GPU kaynağını oluşturur ve yapılandırır. |
| `createSphere` | `static StaticMeshCollisionShape createSphere(List<double> minBounds, Lis...` | Yeni bir `Sphere` örneği veya ilişkili GPU kaynağını oluşturur ve yapılandırır. |
| `createCapsule` | `static StaticMeshCollisionShape createCapsule(List<double> minBounds, Li...` | Yeni bir `Capsule` örneği veya ilişkili GPU kaynağını oluşturur ve yapılandırır. |

### `class MaterialSlotBinding`

`MaterialSlotBinding`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `index` | `int index` | `index` alanını (field/property) ve ilişkili veriyi saklar. |
| `slotName` | `String slotName` | `slotName` alanını (field/property) ve ilişkili veriyi saklar. |
| `assignedMaterialPath` | `String? assignedMaterialPath` | `assignedMaterialPath` alanını (field/property) ve ilişkili veriyi saklar. |
| `assignedMaterialId` | `String? assignedMaterialId` | `assignedMaterialId` alanını (field/property) ve ilişkili veriyi saklar. |
| `isHighlighted` | `bool isHighlighted` | `isHighlighted` alanını (field/property) ve ilişkili veriyi saklar. |
| `isIsolated` | `bool isIsolated` | `isIsolated` alanını (field/property) ve ilişkili veriyi saklar. |

## `lib/ui/features/sub_editors/models/static_mesh_lod.dart`

### `class LodSlot`

`LodSlot`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `LodSlot.fromJson(Map<String, dynamic> json)`: `LodSlot.fromJson(Map<String, dynamic> json)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `level` | `int level` | `level` alanını (field/property) ve ilişkili veriyi saklar. |
| `reductionRatio` | `double reductionRatio` | `reductionRatio` alanını (field/property) ve ilişkili veriyi saklar. |
| `screenSize` | `double screenSize` | `screenSize` alanını (field/property) ve ilişkili veriyi saklar. |
| `triangleCount` | `int triangleCount` | `triangleCount` alanını (field/property) ve ilişkili veriyi saklar. |
| `vertexCount` | `int vertexCount` | `vertexCount` alanını (field/property) ve ilişkili veriyi saklar. |
| `materialOverrides` | `Map<String, String> materialOverrides` | `materialOverrides` alanını (field/property) ve ilişkili veriyi saklar. |
| `toJson` | `Map<String, dynamic> toJson()` | Nesneyi JSON haritasına serileştirir. |

## `lib/ui/features/sub_editors/models/skeletal_socket_attachment.dart`

### `class SkeletalSocketAttachment`

A mesh previewed on a skeletal socket: the Skeletal Mesh editor's viewport draws [mesh] at `entityWorld × G_bone × offset`, the engine's socket chain, so an attachment follows its bone.

**Yapıcı Metotlar (Constructors):**

- `const SkeletalSocketAttachment({required this.socketName, required this.boneName, required this.assetPath, required this.mesh, required this.localOffset, requir...`

**Üyeler:**

| Üye | İmza | Açıklama |
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

**Üyeler:**

| Üye | İmza | Açıklama |
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

**Yapıcı Metotlar (Constructors):**

- `const SkeletalMaterialSlotsPanel({super.key, required this.viewModel})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `viewModel` | `final SkeletalMeshEditorViewModel viewModel` |  |

---

[Önceki: Sequencer](sequencer.md) | [Üst: Alt editörler](index.md) | [Sonraki: Texture editörü](texture.md)

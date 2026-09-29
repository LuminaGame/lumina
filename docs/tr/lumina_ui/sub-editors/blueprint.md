[English](../../../en/lumina_ui/sub-editors/blueprint.md)

# Blueprint editörü

Actor sınıfları için Blueprint editörü: alt editör view'i ve view model'i, component ağacı, event graph ve hangi component'lerin ve property'lerin eklenebileceğini tanımlayan component registry'si. Dosya yolları `lumina_ui/` paket dizinine görelidir.

**Bu sayfada:**

- [`lib/ui/features/sub_editors/views/blueprint/component_tree.dart`](#libuifeaturessub_editorsviewsblueprintcomponent_treedart)
- [`lib/ui/features/sub_editors/views/blueprint/event_graph.dart`](#libuifeaturessub_editorsviewsblueprintevent_graphdart)
- [`lib/ui/features/sub_editors/views/blueprint/blueprint_sub_editor.dart`](#libuifeaturessub_editorsviewsblueprintblueprint_sub_editordart)
- [`lib/ui/features/sub_editors/view_models/blueprint_editor_view_model.dart`](#libuifeaturessub_editorsview_modelsblueprint_editor_view_modeldart)
- [`lib/ui/features/sub_editors/models/blueprint_component_registry.dart`](#libuifeaturessub_editorsmodelsblueprint_component_registrydart)

## `lib/ui/features/sub_editors/views/blueprint/component_tree.dart`

### `class BlueprintComponentTree`

Real Component Hierarchy Tree for Blueprint Editor.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `viewModel` | `BlueprintEditorViewModel viewModel` | `viewModel` alanını (field/property) ve ilişkili veriyi saklar. |
| `createState` | `State<BlueprintComponentTree> createState() => _BlueprintComponentTreeSt...` | Yeni bir `State` örneği veya ilişkili GPU kaynağını oluşturur ve yapılandırır. |

### `class _BlueprintComponentTreeState`

`_BlueprintComponentTreeState`: Aktörlere bağlanarak 3B uzaysal konum, görsel mesh, aydınlatma veya hareket kabiliyeti kazandıran bileşendir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

### `class _AddComponentDialog`

`_AddComponentDialog`: Kullanıcı arayüzünü (UI) oluşturan ve kullanıcı etkileşimlerini dinleyen shadcn_flutter bileşenidir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `viewModel` | `BlueprintEditorViewModel viewModel` | `viewModel` alanını (field/property) ve ilişkili veriyi saklar. |
| `onClose` | `VoidCallback onClose` | `onClose` alanını (field/property) ve ilişkili veriyi saklar. |
| `createState` | `State<_AddComponentDialog> createState() => _AddComponentDialogState()` | Yeni bir `State` örneği veya ilişkili GPU kaynağını oluşturur ve yapılandırır. |

### `class _AddComponentDialogState`

`_AddComponentDialogState`: Kullanıcı arayüzünü (UI) oluşturan ve kullanıcı etkileşimlerini dinleyen shadcn_flutter bileşenidir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `dispose` | `void dispose()` | Yerel FFI göstericilerini, dinleyicileri ve bellek bloklarını serbest bırakır. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

## `lib/ui/features/sub_editors/views/blueprint/event_graph.dart`

### `class BlueprintEventGraph`

`BlueprintEventGraph`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `viewModel` | `BlueprintEditorViewModel viewModel` | `viewModel` alanını (field/property) ve ilişkili veriyi saklar. |
| `createState` | `State<BlueprintEventGraph> createState() => BlueprintEventGraphState()` | Yeni bir `State` örneği veya ilişkili GPU kaynağını oluşturur ve yapılandırır. |

### `class BlueprintEventGraphState`

`BlueprintEventGraphState`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `openNodePalette` | `void openNodePalette(Offset screenPosition)` | `openNodePalette` özelliğine yeni değer atayan setter değiştiricisi. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

### `class _NodePaletteDialog`

`_NodePaletteDialog`: Kullanıcı arayüzünü (UI) oluşturan ve kullanıcı etkileşimlerini dinleyen shadcn_flutter bileşenidir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `onSelect` | `ValueChanged<String> onSelect` | `onSelect` alanını (field/property) ve ilişkili veriyi saklar. |
| `onClose` | `VoidCallback onClose` | `onClose` alanını (field/property) ve ilişkili veriyi saklar. |
| `createState` | `State<_NodePaletteDialog> createState() => _NodePaletteDialogState()` | Yeni bir `State` örneği veya ilişkili GPU kaynağını oluşturur ve yapılandırır. |

### `class _NodePaletteDialogState`

`_NodePaletteDialogState`: Kullanıcı arayüzünü (UI) oluşturan ve kullanıcı etkileşimlerini dinleyen shadcn_flutter bileşenidir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `dispose` | `void dispose()` | Yerel FFI göstericilerini, dinleyicileri ve bellek bloklarını serbest bırakır. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

### `class _EventGraphPainter`

`_EventGraphPainter`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `panOffset` | `Offset panOffset` | `panOffset` alanını (field/property) ve ilişkili veriyi saklar. |
| `zoomScale` | `double zoomScale` | `zoomScale` alanını (field/property) ve ilişkili veriyi saklar. |
| `nodes` | `List<BlueprintGraphNode> nodes` | `nodes` alanını (field/property) ve ilişkili veriyi saklar. |
| `wires` | `List<BlueprintGraphWire> wires` | `wires` alanını (field/property) ve ilişkili veriyi saklar. |
| `pinPositions` | `Map<String, Offset> pinPositions` | `pinPositions` alanını (field/property) ve ilişkili veriyi saklar. |
| `dragStart` | `Offset? dragStart` | `dragStart` alanını (field/property) ve ilişkili veriyi saklar. |
| `dragEnd` | `Offset? dragEnd` | `dragEnd` alanını (field/property) ve ilişkili veriyi saklar. |
| `dragColor` | `Color dragColor` | `dragColor` alanını (field/property) ve ilişkili veriyi saklar. |
| `marqueeStart` | `Offset? marqueeStart` | `marqueeStart` alanını (field/property) ve ilişkili veriyi saklar. |
| `marqueeEnd` | `Offset? marqueeEnd` | `marqueeEnd` alanını (field/property) ve ilişkili veriyi saklar. |
| `paint` | `void paint(Canvas canvas, Size size)` | `paint` işlemini gerçekleştirir. |
| `shouldRepaint` | `bool shouldRepaint(covariant _EventGraphPainter oldDelegate)` | `shouldRepaint` işlemini gerçekleştirir. |

## `lib/ui/features/sub_editors/views/blueprint/blueprint_sub_editor.dart`

### `class BlueprintSubEditor`

`BlueprintSubEditor`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `assetName` | `String assetName` | `assetName` alanını (field/property) ve ilişkili veriyi saklar. |
| `assetPath` | `String? assetPath` | `assetPath` alanını (field/property) ve ilişkili veriyi saklar. |
| `asset` | `LuminaAsset? asset` | `asset` alanını (field/property) ve ilişkili veriyi saklar. |
| `onClose` | `VoidCallback? onClose` | `onClose` alanını (field/property) ve ilişkili veriyi saklar. |
| `onBind` | `SubEditorBindCallback? onBind` | `onBind` alanını (field/property) ve ilişkili veriyi saklar. |
| `viewModel` | `BlueprintEditorViewModel? viewModel` | `viewModel` alanını (field/property) ve ilişkili veriyi saklar. |
| `createState` | `State<BlueprintSubEditor> createState() => _BlueprintSubEditorState()` | Yeni bir `State` örneği veya ilişkili GPU kaynağını oluşturur ve yapılandırır. |

### `class _BlueprintSubEditorState`

`_BlueprintSubEditorState`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `initState` | `void initState()` | `initState` işlemini gerçekleştirir. |
| `dispose` | `void dispose()` | Yerel FFI göstericilerini, dinleyicileri ve bellek bloklarını serbest bırakır. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

## `lib/ui/features/sub_editors/view_models/blueprint_editor_view_model.dart`

### `class BlueprintEditorViewModel`

`BlueprintEditorViewModel`: İlgili arayüz modülünün durumunu (state) yöneten, kullanıcı aksiyonlarını yürüten ve görünümü güncelleyen ChangeNotifier ViewModel sınıfıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `assetPath` | `String assetPath` | `assetPath` alanını (field/property) ve ilişkili veriyi saklar. |
| `fileBasename` | `String get fileBasename` | `fileBasename` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `document` | `BlueprintDocument get document` | `document` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `selectedComponentId` | `String? get selectedComponentId` | İlgili aktör veya varlığı seçili duruma getirir. |
| `selectedNodeIds` | `Set<String> get selectedNodeIds` | İlgili aktör veya varlığı seçili duruma getirir. |
| `graphNodes` | `List<BlueprintGraphNode> get graphNodes` | `graphNodes` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `graphWires` | `List<BlueprintGraphWire> get graphWires` | `graphWires` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `isDirty` | `bool get isDirty` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `availableSkeletalMeshes` | `List<RealAssetInfo> get availableSkeletalMeshes` | `availableSkeletalMeshes` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `availableStaticMeshes` | `List<RealAssetInfo> get availableStaticMeshes` | `availableStaticMeshes` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `availableAnimations` | `List<RealAssetInfo> get availableAnimations` | `availableAnimations` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `availableMaterials` | `List<RealAssetInfo> get availableMaterials` | `availableMaterials` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `previewGlbMesh` | `GlbMeshData? get previewGlbMesh` | `previewGlbMesh` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `previewMeshPath` | `String? get previewMeshPath` | `previewMeshPath` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `generatedDartCode` | `String get generatedDartCode` | `generatedDartCode` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `setMeshForComponent` | `Future<void> setMeshForComponent(String componentId, String propField, S...` | `MeshForComponent` parametresini günceller ve sisteme uygular. |
| `loadPreviewMesh` | `Future<void> loadPreviewMesh(String relativePath)` | Veriyi diskten veya bellekten okuyarak motora yükler ve kullanılabilir hale getirir. |
| `compile` | `Future<bool> compile()` | Compiles this blueprint into a real Dart file in the active project. |
| `rootComponent` | `BlueprintComponentNode? get rootComponent` | `rootComponent` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `getComponent` | `BlueprintComponentNode? getComponent(String id)` | `Component` bilgisini veya alt nesnesini sorgulayıp döndürür. |
| `isSceneComponent` | `bool isSceneComponent(String id)` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `selectComponent` | `void selectComponent(String? id)` | İlgili aktör veya varlığı seçili duruma getirir. |
| `getGraphNode` | `BlueprintGraphNode? getGraphNode(String id)` | `GraphNode` bilgisini veya alt nesnesini sorgulayıp döndürür. |
| `addGraphNode` | `BlueprintGraphNode? addGraphNode(String registryId, Offset position)` | Koleksiyona veya sahneye yeni bir öğe ekler. |
| `removeGraphNode` | `bool removeGraphNode(String nodeId)` | Belirtilen `GraphNode` nesnesini/bileşenini serbest bırakır ve güvenle temizler. |
| `removeSelectedGraphNodes` | `void removeSelectedGraphNodes()` | Belirtilen `SelectedGraphNodes` nesnesini/bileşenini serbest bırakır ve güvenle temizler. |
| `removeGraphWire` | `bool removeGraphWire(String wireId)` | Belirtilen `GraphWire` nesnesini/bileşenini serbest bırakır ve güvenle temizler. |
| `setPinLiteral` | `void setPinLiteral(String nodeId, String pinId, dynamic value)` | `PinLiteral` parametresini günceller ve sisteme uygular. |
| `toggleSelectGraphNode` | `void toggleSelectGraphNode(String nodeId)` | İlgili özelliğin açık/kapalı durumunu tersine çevirir. |
| `selectGraphNodes` | `void selectGraphNodes(Set<String> nodeIds)` | İlgili aktör veya varlığı seçili duruma getirir. |
| `clearGraphSelection` | `void clearGraphSelection()` | Koleksiyon veya tampon içeriğini tamamen temizler. |
| `moveNodes` | `void moveNodes(Iterable<String> nodeIds, Offset delta)` | `moveNodes` özelliğine yeni değer atayan setter değiştiricisi. |
| `load` | `Future<void> load()` | Veriyi diskten veya bellekten okuyarak motora yükler ve kullanılabilir hale getirir. |
| `removeComponent` | `bool removeComponent(String id)` | Belirtilen `Component` nesnesini/bileşenini serbest bırakır ve güvenle temizler. |
| `renameComponent` | `bool renameComponent(String id, String newName)` | `renameComponent` işlemini gerçekleştirir. |
| `canReparent` | `bool canReparent(String childId, String? targetParentId)` | `canReparent` işlemini gerçekleştirir. |
| `reparent` | `bool reparent(String childId, String? newParentId)` | `reparent` işlemini gerçekleştirir. |
| `duplicateComponent` | `BlueprintComponentNode? duplicateComponent(String id)` | `duplicateComponent` işlemini gerçekleştirir. |
| `setProperty` | `void setProperty(String componentId, String propName, dynamic value)` | `Property` parametresini günceller ve sisteme uygular. |
| `addVariable` | `void addVariable(String name, String type, String defaultValue)` | Koleksiyona veya sahneye yeni bir öğe ekler. |
| `setClassDefault` | `void setClassDefault(String key, dynamic value)` | `ClassDefault` parametresini günceller ve sisteme uygular. |
| `setParentClass` | `void setParentClass(String parentClass)` | `ParentClass` parametresini günceller ve sisteme uygular. |
| `resetToDefaultComponents` | `void resetToDefaultComponents()` | Değerleri veya durumları varsayılan ayarlarına sıfırlar. |
| `save` | `Future<bool> save()` | Mevcut durumu veya varlığı diske dosya olarak serileştirip yazar. |

## `lib/ui/features/sub_editors/models/blueprint_component_registry.dart`

### `enum ComponentPropertyType`

`ComponentPropertyType`: Sistemde kullanılan seçenekleri ve durumları listeleyen numaralandırma türüdür.

### `class ComponentPropertySchema`

`ComponentPropertySchema`: Aktörlere bağlanarak 3B uzaysal konum, görsel mesh, aydınlatma veya hareket kabiliyeti kazandıran bileşendir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `group` | `String group` | `group` alanını (field/property) ve ilişkili veriyi saklar. |
| `name` | `String name` | `name` alanını (field/property) ve ilişkili veriyi saklar. |
| `dartField` | `String dartField` | `dartField` alanını (field/property) ve ilişkili veriyi saklar. |
| `type` | `ComponentPropertyType type` | `type` alanını (field/property) ve ilişkili veriyi saklar. |
| `defaultValue` | `dynamic defaultValue` | `defaultValue` alanını (field/property) ve ilişkili veriyi saklar. |
| `min` | `double min` | `min` alanını (field/property) ve ilişkili veriyi saklar. |
| `max` | `double max` | `max` alanını (field/property) ve ilişkili veriyi saklar. |
| `enumOptions` | `List<String> enumOptions` | `enumOptions` alanını (field/property) ve ilişkili veriyi saklar. |

### `class ComponentTypeDescriptor`

`ComponentTypeDescriptor`: Aktörlere bağlanarak 3B uzaysal konum, görsel mesh, aydınlatma veya hareket kabiliyeti kazandıran bileşendir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `typeName` | `String typeName` | `typeName` alanını (field/property) ve ilişkili veriyi saklar. |
| `displayName` | `String displayName` | `displayName` alanını (field/property) ve ilişkili veriyi saklar. |
| `category` | `String category` | `category` alanını (field/property) ve ilişkili veriyi saklar. |
| `isSceneComponent` | `bool isSceneComponent` | `isSceneComponent` alanını (field/property) ve ilişkili veriyi saklar. |
| `isAvailable` | `bool isAvailable` | `isAvailable` alanını (field/property) ve ilişkili veriyi saklar. |
| `gapReason` | `String? gapReason` | `gapReason` alanını (field/property) ve ilişkili veriyi saklar. |
| `properties` | `List<ComponentPropertySchema> properties` | `properties` alanını (field/property) ve ilişkili veriyi saklar. |

### `class BlueprintComponentRegistry`

`BlueprintComponentRegistry`: Aktörlere bağlanarak 3B uzaysal konum, görsel mesh, aydınlatma veya hareket kabiliyeti kazandıran bileşendir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `getDescriptor` | `static ComponentTypeDescriptor? getDescriptor(String typeName)` | `Descriptor` bilgisini veya alt nesnesini sorgulayıp döndürür. |
| `getSchema` | `static List<ComponentPropertySchema> getSchema(String typeName)` | `Schema` bilgisini veya alt nesnesini sorgulayıp döndürür. |

---

[Önceki: Ses editörü](audio.md) | [Üst: Alt editörler](index.md) | [Sonraki: Blueprint editörü (devamı, bölüm 1)](blueprint-continued.md)

[English](../../../en/lumina_ui/sub-editors/framework.md)

# Alt editör altyapısı

Tüm alt editörlerin paylaştığı parçalar: 3D önizleme viewport'u, hiyerarşi widget'ı, alt editör çalışma alanı ve önizleme mesh fabrikası. Dosya yolları `lumina_ui/` paket dizinine görelidir.

**Bu sayfada:**

- [`lib/ui/features/sub_editors/views/sub_editor_3d_viewport.dart`](#libuifeaturessub_editorsviewssub_editor_3d_viewportdart)
- [`lib/ui/features/sub_editors/views/sub_editor_hierarchy_widget.dart`](#libuifeaturessub_editorsviewssub_editor_hierarchy_widgetdart)
- [`lib/ui/features/sub_editors/views/sub_editor_modal.dart`](#libuifeaturessub_editorsviewssub_editor_modaldart)
- [`lib/ui/features/sub_editors/services/preview_mesh_factory.dart`](#libuifeaturessub_editorsservicespreview_mesh_factorydart)
- [`lib/ui/features/sub_editors/models/sub_editor_line_set.dart`](#libuifeaturessub_editorsmodelssub_editor_line_setdart)
- [`lib/ui/features/sub_editors/models/sub_editor_mesh_component.dart`](#libuifeaturessub_editorsmodelssub_editor_mesh_componentdart)
- [`lib/ui/features/sub_editors/models/sub_editor_transform_gizmo.dart`](#libuifeaturessub_editorsmodelssub_editor_transform_gizmodart)
- [`lib/ui/features/sub_editors/models/viewport_ray.dart`](#libuifeaturessub_editorsmodelsviewport_raydart)
- [`lib/ui/features/sub_editors/services/flutter_filament_web_module.dart`](#libuifeaturessub_editorsservicesflutter_filament_web_moduledart)
- [`lib/ui/features/sub_editors/services/project_icon_packaging.dart`](#libuifeaturessub_editorsservicesproject_icon_packagingdart)
- [`lib/ui/features/sub_editors/services/project_icon_rasterizer.dart`](#libuifeaturessub_editorsservicesproject_icon_rasterizerdart)
- [`lib/ui/features/sub_editors/services/viewport_mesh.dart`](#libuifeaturessub_editorsservicesviewport_meshdart)
- [`lib/ui/features/sub_editors/services/web_preview_server.dart`](#libuifeaturessub_editorsservicesweb_preview_serverdart)
- [`lib/ui/features/sub_editors/sub_editor_binding.dart`](#libuifeaturessub_editorssub_editor_bindingdart)
- [`lib/ui/features/sub_editors/views/appearance_preferences_page.dart`](#libuifeaturessub_editorsviewsappearance_preferences_pagedart)
- [`lib/ui/features/sub_editors/views/editor_preferences_sub_editor.dart`](#libuifeaturessub_editorsviewseditor_preferences_sub_editordart)
- [`lib/ui/features/sub_editors/views/sub_editor_3d_viewport/mesh_painter.dart`](#libuifeaturessub_editorsviewssub_editor_3d_viewportmesh_painterdart)
- [`lib/ui/features/sub_editors/views/sub_editor_3d_viewport/widget.dart`](#libuifeaturessub_editorsviewssub_editor_3d_viewportwidgetdart)
- [`lib/ui/features/sub_editors/views/sub_editor_transform_gizmo_painter.dart`](#libuifeaturessub_editorsviewssub_editor_transform_gizmo_painterdart)

## `lib/ui/features/sub_editors/views/sub_editor_3d_viewport.dart`

**Üst Düzey Fonksiyonlar (Top-level Functions):**

- **`show MaterialParamModel, MaterialParamType`**: `MaterialParamType` işlemini gerçekleştirir.
- **`Color previewBaseColorFromParams(List<MaterialParamModel> params)`**: Base colour for the software-rendered preview, taken from the first colour-typed material parameter (e.g. `baseColor`); cyan when none exists.

### `enum PreviewShape`

`PreviewShape`: Sistemde kullanılan seçenekleri ve durumları listeleyen numaralandırma türüdür.

### `enum ViewportShadingMode`

`ViewportShadingMode`: Sistemde kullanılan seçenekleri ve durumları listeleyen numaralandırma türüdür.

### `class SubEditor3DViewport`

`SubEditor3DViewport`: Kullanıcı arayüzünü (UI) oluşturan ve kullanıcı etkileşimlerini dinleyen shadcn_flutter bileşenidir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `title` | `String title` | `title` alanını (field/property) ve ilişkili veriyi saklar. |
| `glbMesh` | `GlbMeshData? glbMesh` | `glbMesh` alanını (field/property) ve ilişkili veriyi saklar. |
| `selectedNode` | `GlbNode? selectedNode` | `selectedNode` alanını (field/property) ve ilişkili veriyi saklar. |
| `initialShape` | `PreviewShape initialShape` | `initialShape` alanını (field/property) ve ilişkili veriyi saklar. |
| `showShapeSelector` | `bool showShapeSelector` | `showShapeSelector` alanını (field/property) ve ilişkili veriyi saklar. |
| `overlayHUD` | `Widget? overlayHUD` | `overlayHUD` alanını (field/property) ve ilişkili veriyi saklar. |
| `playbackController` | `AnimationPlaybackController? playbackController` | `playbackController` alanını (field/property) ve ilişkili veriyi saklar. |
| `showBones` | `bool showBones` | `showBones` alanını (field/property) ve ilişkili veriyi saklar. |
| `showSockets` | `bool showSockets` | `showSockets` alanını (field/property) ve ilişkili veriyi saklar. |
| `sockets` | `List<SkeletalMeshSocket> sockets` | `sockets` alanını (field/property) ve ilişkili veriyi saklar. |
| `selectedSocket` | `SkeletalMeshSocket? selectedSocket` | `selectedSocket` alanını (field/property) ve ilişkili veriyi saklar. |
| `previewMaterialBytes` | `Uint8List? previewMaterialBytes` | Compiled `.filamat` package to shade the procedural preview primitive with (Material Editor). When set and no [glbMesh] payload exists, the viewport still mounts the real Filament renderer. |
| `previewMaterialParams` | `List<MaterialParamModel> previewMaterialParams` | Editor parameter values pushed into the preview material instance. |
| `previewMaterialRevision` | `int previewMaterialRevision` | Bump to re-apply [previewMaterialParams] without recreating the widget. |
| `yUpCamera` | `bool yUpCamera` | Use a Y-up camera (lumina world convention) instead of inferring the up axis from the mesh bounds. |
| `initialCameraDistance` | `double? initialCameraDistance` | Initial orbit distance override (world units). |
| `statsLabel` | `String? statsLabel` | Replaces the bottom stats strip (used by previews whose content is not a single mesh, so the mesh-derived counts would be meaningless). |
| `floorTapPlaneY` | `double floorTapPlaneY` | Height of the floor plane [onFloorTap] rays are intersected with. |
| `createState` | `State<SubEditor3DViewport> createState() => _SubEditor3DViewportState()` | Yeni bir `State` örneği veya ilişkili GPU kaynağını oluşturur ve yapılandırır. |

### `class _SubEditor3DViewportState`

`_SubEditor3DViewportState`: Kullanıcı arayüzünü (UI) oluşturan ve kullanıcı etkileşimlerini dinleyen shadcn_flutter bileşenidir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `initState` | `void initState()` | `initState` işlemini gerçekleştirir. |
| `didUpdateWidget` | `void didUpdateWidget(covariant SubEditor3DViewport oldWidget)` | `didUpdateWidget` işlemini gerçekleştirir. |
| `dispose` | `void dispose()` | Yerel FFI göstericilerini, dinleyicileri ve bellek bloklarını serbest bırakır. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

### `class _SubEditor3DPainter`

`_SubEditor3DPainter`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `glbMesh` | `GlbMeshData? glbMesh` | `glbMesh` alanını (field/property) ve ilişkili veriyi saklar. |
| `selectedNode` | `GlbNode? selectedNode` | `selectedNode` alanını (field/property) ve ilişkili veriyi saklar. |
| `shape` | `PreviewShape shape` | `shape` alanını (field/property) ve ilişkili veriyi saklar. |
| `shadingMode` | `ViewportShadingMode shadingMode` | `shadingMode` alanını (field/property) ve ilişkili veriyi saklar. |
| `baseColor` | `Color baseColor` | `baseColor` alanını (field/property) ve ilişkili veriyi saklar. |
| `roughness` | `double roughness` | `roughness` alanını (field/property) ve ilişkili veriyi saklar. |
| `metallic` | `double metallic` | `metallic` alanını (field/property) ve ilişkili veriyi saklar. |
| `cameraYaw` | `double cameraYaw` | `cameraYaw` alanını (field/property) ve ilişkili veriyi saklar. |
| `cameraPitch` | `double cameraPitch` | `cameraPitch` alanını (field/property) ve ilişkili veriyi saklar. |
| `cameraDistance` | `double cameraDistance` | `cameraDistance` alanını (field/property) ve ilişkili veriyi saklar. |
| `cameraPan` | `Offset cameraPan` | `cameraPan` alanını (field/property) ve ilişkili veriyi saklar. |
| `paint` | `void paint(Canvas canvas, Size size)` | `paint` işlemini gerçekleştirir. |
| `shouldRepaint` | `bool shouldRepaint(covariant _SubEditor3DPainter oldDelegate)` | `shouldRepaint` işlemini gerçekleştirir. |

### `class _GlobalTriData`

`_GlobalTriData`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `p0` | `Offset p0` | `p0` alanını (field/property) ve ilişkili veriyi saklar. |
| `p1` | `Offset p1` | `p1` alanını (field/property) ve ilişkili veriyi saklar. |
| `p2` | `Offset p2` | `p2` alanını (field/property) ve ilişkili veriyi saklar. |
| `depth` | `double depth` | `depth` alanını (field/property) ve ilişkili veriyi saklar. |
| `shade` | `double shade` | `shade` alanını (field/property) ve ilişkili veriyi saklar. |
| `color` | `Color color` | `color` alanını (field/property) ve ilişkili veriyi saklar. |

### `class _SubEditorGizmoPainter`

`_SubEditorGizmoPainter`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `glbMesh` | `GlbMeshData? glbMesh` | `glbMesh` alanını (field/property) ve ilişkili veriyi saklar. |
| `showBones` | `bool showBones` | `showBones` alanını (field/property) ve ilişkili veriyi saklar. |
| `showSockets` | `bool showSockets` | `showSockets` alanını (field/property) ve ilişkili veriyi saklar. |
| `sockets` | `List<SkeletalMeshSocket> sockets` | `sockets` alanını (field/property) ve ilişkili veriyi saklar. |
| `selectedNode` | `GlbNode? selectedNode` | `selectedNode` alanını (field/property) ve ilişkili veriyi saklar. |
| `selectedSocket` | `SkeletalMeshSocket? selectedSocket` | `selectedSocket` alanını (field/property) ve ilişkili veriyi saklar. |
| `cameraYaw` | `double cameraYaw` | `cameraYaw` alanını (field/property) ve ilişkili veriyi saklar. |
| `cameraPitch` | `double cameraPitch` | `cameraPitch` alanını (field/property) ve ilişkili veriyi saklar. |
| `cameraDistance` | `double cameraDistance` | `cameraDistance` alanını (field/property) ve ilişkili veriyi saklar. |
| `cameraPan` | `Offset cameraPan` | `cameraPan` alanını (field/property) ve ilişkili veriyi saklar. |
| `paint` | `void paint(Canvas canvas, Size size)` | `paint` işlemini gerçekleştirir. |
| `shouldRepaint` | `bool shouldRepaint(covariant _SubEditorGizmoPainter oldDelegate)` | `shouldRepaint` işlemini gerçekleştirir. |

## `lib/ui/features/sub_editors/views/sub_editor_hierarchy_widget.dart`

### `class SubEditorHierarchyWidget`

`SubEditorHierarchyWidget`: Kullanıcı arayüzünü (UI) oluşturan ve kullanıcı etkileşimlerini dinleyen shadcn_flutter bileşenidir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `rootNodes` | `List<GlbNode> rootNodes` | `rootNodes` alanını (field/property) ve ilişkili veriyi saklar. |
| `allNodes` | `List<GlbNode> allNodes` | `allNodes` alanını (field/property) ve ilişkili veriyi saklar. |
| `selectedNode` | `GlbNode? selectedNode` | `selectedNode` alanını (field/property) ve ilişkili veriyi saklar. |
| `onNodeSelected` | `ValueChanged<GlbNode?>? onNodeSelected` | `onNodeSelected` alanını (field/property) ve ilişkili veriyi saklar. |
| `createState` | `State<SubEditorHierarchyWidget> createState() => _SubEditorHierarchyWidg...` | Yeni bir `State` örneği veya ilişkili GPU kaynağını oluşturur ve yapılandırır. |

### `class _SubEditorHierarchyWidgetState`

`_SubEditorHierarchyWidgetState`: Kullanıcı arayüzünü (UI) oluşturan ve kullanıcı etkileşimlerini dinleyen shadcn_flutter bileşenidir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `initState` | `void initState()` | `initState` işlemini gerçekleştirir. |
| `didUpdateWidget` | `void didUpdateWidget(covariant SubEditorHierarchyWidget oldWidget)` | `didUpdateWidget` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `dispose` | `void dispose()` | Yerel FFI göstericilerini, dinleyicileri ve bellek bloklarını serbest bırakır. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

### `class _HierarchyNodeRow`

`_HierarchyNodeRow`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `node` | `GlbNode node` | `node` alanını (field/property) ve ilişkili veriyi saklar. |
| `depth` | `int depth` | `depth` alanını (field/property) ve ilişkili veriyi saklar. |
| `isExpanded` | `bool isExpanded` | `isExpanded` alanını (field/property) ve ilişkili veriyi saklar. |
| `isSelected` | `bool isSelected` | `isSelected` alanını (field/property) ve ilişkili veriyi saklar. |
| `onToggleExpand` | `VoidCallback? onToggleExpand` | `onToggleExpand` alanını (field/property) ve ilişkili veriyi saklar. |
| `onSelect` | `VoidCallback onSelect` | `onSelect` alanını (field/property) ve ilişkili veriyi saklar. |
| `onToggleVisibility` | `VoidCallback onToggleVisibility` | `onToggleVisibility` alanını (field/property) ve ilişkili veriyi saklar. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

## `lib/ui/features/sub_editors/views/sub_editor_modal.dart`

**Üst Düzey Fonksiyonlar (Top-level Functions):**

- **`void showSubEditorModal(BuildContext context, String assetType, String assetName)`**: Helper method to open sub-editor modal if requested outside of tab bar

### `class SubEditorWorkspaceWidget`

Main Dispatcher Widget for rendering full-page Sub-Editor Workspaces in tabs or dialogs

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `assetType` | `String assetType` | `assetType` alanını (field/property) ve ilişkili veriyi saklar. |
| `assetName` | `String assetName` | `assetName` alanını (field/property) ve ilişkili veriyi saklar. |
| `asset` | `RealAssetInfo? asset` | `asset` alanını (field/property) ve ilişkili veriyi saklar. |
| `onClose` | `VoidCallback? onClose` | `onClose` alanını (field/property) ve ilişkili veriyi saklar. |
| `editorViewModel` | `EditorViewModel? editorViewModel` | `editorViewModel` alanını (field/property) ve ilişkili veriyi saklar. |
| `tabId` | `String? tabId` | Id of the hosting workspace tab; when set together with [editorViewModel], the sub-editor's view model is bound to the tab so the shell can save it on close. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

## `lib/ui/features/sub_editors/services/preview_mesh_factory.dart`

### `class PreviewMeshData`

Procedural preview geometry (unit-scale) used by the Material Editor's 3D preview so a compiled material can be shaded on a real Filament renderable even though a material asset carries no mesh payload.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `positions` | `Float32List positions` | `positions` alanını (field/property) ve ilişkili veriyi saklar. |
| `normals` | `Float32List normals` | `normals` alanını (field/property) ve ilişkili veriyi saklar. |
| `uv0` | `Float32List uv0` | `uv0` alanını (field/property) ve ilişkili veriyi saklar. |
| `indices` | `Uint32List indices` | `indices` alanını (field/property) ve ilişkili veriyi saklar. |
| `minBounds` | `List<double> minBounds` | `minBounds` alanını (field/property) ve ilişkili veriyi saklar. |
| `maxBounds` | `List<double> maxBounds` | `maxBounds` alanını (field/property) ve ilişkili veriyi saklar. |
| `vertexCount` | `int get vertexCount` | `vertexCount` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `triangleCount` | `int get triangleCount` | `triangleCount` özelliğinin anlık değerini okuyan getter erişimcisi. |

### `class PreviewMeshFactory`

`PreviewMeshFactory`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `PreviewMeshFactory._()`: `PreviewMeshFactory._()` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `build` | `static PreviewMeshData build(PreviewShape shape)` | Builds the geometry for [shape]. [PreviewShape.mesh] has no procedural form and falls back to the sphere. |

## `lib/ui/features/sub_editors/models/sub_editor_line_set.dart`

### `class SubEditorLineSet`

Line segments a sub-editor viewport draws over its scene: a Blueprint's capsule, spring arm and camera. In the viewport's own frame (the runtime's Y up, world units).

**Yapıcı Metotlar (Constructors):**

- `const SubEditorLineSet({required this.id, required this.positions, required this.indices, required this.r, required this.g, required this.b, required this.signa...`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `id` | `final String id` | Which set this is (a component id); one native line entity per id. |
| `positions` | `final List<double> positions` | Vertex positions, `x, y, z` per vertex. |
| `indices` | `final List<int> indices` | Vertex index pairs, one pair per segment. |
| `r` | `final double r` | Line colour, 0–1. |
| `g` | `final double g` |  |
| `b` | `final double b` |  |
| `selected` | `final bool selected` | The highlighted set (the selected component). |
| `xray` | `final bool xray` | Drawn over the scene with no depth test (a selected component shows through the mesh around it). |
| `signature` | `final String signature` | Changes whenever the geometry or the style does; the viewport rebuilds a set's native lines only then. |
| `segmentCount` | `int get segmentCount` |  |

## `lib/ui/features/sub_editors/models/sub_editor_mesh_component.dart`

### `class SubEditorMeshComponent`

Represents a 3D mesh component (such as a skeletal or static mesh) positioned within an actor composite preview in [SubEditor3DViewport].

**Yapıcı Metotlar (Constructors):**

- `const SubEditorMeshComponent({required this.id, required this.name, required this.glbMesh, this.location = const [0.0, 0.0, 0.0], this.rotation = const [0.0, 0....`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `id` | `final String id` |  |
| `name` | `final String name` |  |
| `glbMesh` | `final GlbMeshData glbMesh` |  |
| `location` | `final List<double> location` |  |
| `rotation` | `final List<double> rotation` |  |
| `scale` | `final List<double> scale` |  |
| `isVisible` | `final bool isVisible` |  |

## `lib/ui/features/sub_editors/models/sub_editor_transform_gizmo.dart`

### `class SubEditorGizmoTarget`

What a sub-editor viewport's transform gizmo sits on: one object with a world transform in the **authoring** frame (Z up, cm — what the Details panel shows), as `SubEditor3DViewport` draws it through `LuminaAxes`.

**Yapıcı Metotlar (Constructors):**

- `const SubEditorGizmoTarget({required this.id, required this.pivot, required this.rotation, this.locked = false, this.lockedHint = 'Transform is fixed',})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `id` | `final String id` |  |
| `pivot` | `final Vector3 pivot` | The object's world location, authoring frame. |
| `rotation` | `final Quaternion rotation` | The object's world rotation, authoring frame (local-space axes). |
| `locked` | `final bool locked` | A gizmo that is drawn but refuses to drag (a Blueprint's root component), with the hint the banner shows. |
| `lockedHint` | `final String lockedHint` |  |

### `class SubEditorGizmoDelta`

One pointer move of a drag, as a world-space delta in the authoring frame since the grab. Exactly one of the three groups is set, by the tool.

**Yapıcı Metotlar (Constructors):**

- `const SubEditorGizmoDelta.translate(this.translation)`
- `const SubEditorGizmoDelta.rotate(this.rotationAxis, this.rotationDegrees)`
- `const SubEditorGizmoDelta.scale(this.scaleHandle, this.scaleDelta)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `translation` | `final Vector3? translation` | Translate: the pivot's offset. |
| `rotationAxis` | `final Vector3? rotationAxis` | Rotate: the world axis turned about and the (snapped) angle, degrees. |
| `rotationDegrees` | `final double? rotationDegrees` |  |
| `scaleHandle` | `final String? scaleHandle` | Scale: the handle (`X`, `Y`, `Z` or `UNIFORM`) and the (snapped) amount to add to each affected scale component. |
| `scaleDelta` | `final double? scaleDelta` |  |

### `class SubEditorTransformGizmo`

The transform gizmo of a sub-editor 3D viewport: the tool (Q/W/E/R), Local/World space and snap settings the viewport's toolbar cluster drives, the [target] it manipulates, and the callbacks the owning editor turns into document edits. The viewport listens to it.

**Yapıcı Metotlar (Constructors):**

- `SubEditorTransformGizmo({GizmoMode mode = GizmoMode.translate, GizmoSpace space = GizmoSpace.world, TransformGizmoSnap snap = TransformGizmoSnap.none, SubEditor...`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `onDragBegin` | `final void Function(String id)? onDragBegin` | A drag on [target] started (snapshot for undo / cancel). |
| `onDragUpdate` | `final void Function(String id, SubEditorGizmoDelta delta)? onDragUpdate` | The pointer moved during a drag. |
| `onDragEnd` | `final void Function(String id)? onDragEnd` | The button came up: commit one undo step. |
| `onDragCancel` | `final void Function(String id)? onDragCancel` | Esc during the drag: restore the snapshot. |
| `pick` | `final String? Function(ViewportRay ray)? pick` | A click that hit no handle: what is under the pointer's camera ray (runtime frame, as the viewport's rays are), or null. |
| `onPick` | `final void Function(String? id)? onPick` | The click's result, so the owner can sync its selection. |
| `mode` | `GizmoMode get mode` |  |
| `space` | `GizmoSpace get space` |  |
| `snap` | `TransformGizmoSnap get snap` |  |
| `target` | `SubEditorGizmoTarget? get target` |  |
| `modeForTool` | `static GizmoMode modeForTool(String tool)` | The level editor's tool names (`select` shows the translate gizmo). |
| `setMode` | `void setMode(GizmoMode mode)` |  |
| `setSpace` | `void setSpace(GizmoSpace space)` |  |
| `toggleSpace` | `void toggleSpace()` |  |
| `setSnap` | `void setSnap(TransformGizmoSnap snap)` |  |
| `setTarget` | `void setTarget(SubEditorGizmoTarget? target)` | Replaces the target; a target with the same id, pivot and rotation is not a change. |

## `lib/ui/features/sub_editors/models/viewport_ray.dart`

### `class ViewportRay`

A camera ray through a viewport pixel: [origin] is the eye, [direction] is unit length.

**Yapıcı Metotlar (Constructors):**

- `const ViewportRay(this.origin, this.direction)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `origin` | `final Vector3 origin` |  |
| `direction` | `final Vector3 direction` |  |
| `at` | `Vector3 at(double t)` | The point [t] units along the ray. |

### `class ViewportBrushInput`

A sub-editor tool that paints with the mouse in the 3D viewport — the Landscape editor's sculpt and foliage brushes.

With one, `SubEditor3DViewport` reports the camera ray under the mouse on every hover, and a plain primary-button press / drag / release (no Alt) becomes a brush stroke instead of an orbit. Alt+LMB orbit, RMB look, Alt+RMB dolly, MMB pan and the wheel keep driving the camera.

**Yapıcı Metotlar (Constructors):**

- `const ViewportBrushInput({required this.onHover, required this.onStrokeStart, required this.onStrokeUpdate, required this.onStrokeEnd,})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `onHover` | `final void Function(ViewportRay ray) onHover` | The mouse moved over the viewport with no button held. |
| `onStrokeStart` | `final bool Function(ViewportRay ray, {required bool invert}) onStrokeStart` | A plain LMB press; [invert] is Shift. Return true to take the press (no orbit until release), false to leave it to the camera. |
| `onStrokeUpdate` | `final void Function(ViewportRay ray) onStrokeUpdate` | The pressed mouse moved. |
| `onStrokeEnd` | `final void Function() onStrokeEnd` | The button came up (or the pointer was cancelled). |

**Üst düzey fonksiyonlar ve değişkenler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `viewportRay` | `ViewportRay? viewportRay({required Offset local, required Size size, required double yawDeg, required double p...` | The ray of the sub-editor's Y-up orbit camera through a viewport pixel. |
| `unprojectViewportToPlaneY` | `Vector3? unprojectViewportToPlaneY({required Offset local, required Size size, required double yawDeg, require...` | Unprojects a viewport pixel of the sub-editor's Y-up orbit camera onto the horizontal plane `y == planeY` (see [viewportRay]). Returns `null` when the ray never reaches the plane (parallel or behind the camera). |
| `projectWorldToViewport` | `Offset? projectWorldToViewport({required Vector3 worldPos, required Size size, required double yawDeg, require...` | Projects a 3D world coordinate onto viewport screen coordinates (in pixels) matching `SubEditor3DViewport._updateNativeCamera`. |

## `lib/ui/features/sub_editors/services/flutter_filament_web_module.dart`

### `class FlutterFilamentWebModule`

flutter_filament's WebAssembly module — `web/flutter_filament.{js,wasm}`, built by its `tool/web/build_module.sh`. A Lumina game can only be built for the web when it exists: the cook serves both files next to the game's `index.html`, where `FilamentWeb.ensureInitialized` loads them.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `directory` | `final Directory directory` | The package's `web/` folder. |
| `fileNames` | `static const List<String> fileNames` |  |
| `missingReason` | `static const String missingReason` | Why web builds are unavailable while the module is missing. |
| `files` | `List<File> get files` |  |
| `sizeBytes` | `int get sizeBytes` |  |
| `at` | `static FlutterFilamentWebModule? at(Directory webDir)` | The module in [webDir], or null when either file is missing. |
| `locate` | `static FlutterFilamentWebModule? locate({List<String>? packageRoots})` | Finds the flutter_filament package through the resolved dependencies (`.dart_tool/package_config.json`) of each of [packageRoots], in order. By default: the engine package the editor scaffolds projects against, then the editor's own working directory. Pass the project first to use exactly the flutter_filament its game links. |
| `stageInto` | `List<File> stageInto(Directory webBuild)` | Copies both files into [webBuild] (a `flutter build web` output) and returns the copies. |

## `lib/ui/features/sub_editors/services/project_icon_packaging.dart`

### `class ProjectIconPackaging`

The project icon's part of a packaging run, plugged into [PackageTargetsStep]: - before a target's `flutter build`, that platform's app-icon files are written from the project icon ([AppIconService]); - after a Linux target is packaged, the bundle gets its `.desktop` entry and the executable its file-manager icon ([LinuxBundleBranding]); - before a web build, the loading screen is generated from the project's Web Loading Style, with the project icon as its default logo ([WebLoadingScreenService]).

The icon is rasterized once per run.

**Yapıcı Metotlar (Constructors):**

- `ProjectIconPackaging({required this.projectDir, required this.project})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `projectDir` | `final String projectDir` |  |
| `project` | `final LuminaProject project` |  |
| `iconLabel` | `String get iconLabel` |  |
| `beforeBuild` | `Future<String?> beforeBuild(BuildStepContext ctx, String target) async` | Writes [target]'s app-icon files. Returns why it could not, or null. |
| `afterPackage` | `Future<void> afterPackage(BuildStepContext ctx, String target, String artifactPath, String packageDir) async` | Finishes a packaged Linux bundle (and Flutter's own bundle it was copied from): `.desktop` entry and file-manager icon. |

## `lib/ui/features/sub_editors/services/project_icon_rasterizer.dart`

### `class ProjectIconRasterizer`

Turns a project's icon into the square master PNG that [AppIconService] resamples for every platform.

SVG icons are drawn by a real vector renderer (flutter_svg's picture, rasterized by `Picture.toImage`), so every size is sharp; raster icons (PNG, JPG, WebP) are decoded by the engine's codecs. Either way the drawing is fitted and centred on a transparent square. A project with no icon of its own uses the editor's Lumina logo.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `defaultIconAsset` | `static const String defaultIconAsset` | The Lumina logo the editor ships (Project Settings shows it as the default Project Icon). |
| `supportedExtensions` | `static const List<String> supportedExtensions` | Extensions Project Settings accepts as a project icon. |
| `masterSize` | `static const int masterSize` | The side of the master PNG: the largest platform icon (macOS, iOS). |
| `iconFile` | `static File? iconFile(String projectDir, ProjectBrandingSettings branding)` | The project's icon file, or null when it uses the default logo. |
| `masterPng` | `static Future<Uint8List> masterPng(String projectDir, ProjectBrandingSettings branding, {int size = masterSize...` | The square master PNG of the project's icon (or the default logo). Throws a [FormatException] when the file is missing or unreadable. |
| `loadDefaultPngBytes` | `static Future<Uint8List> loadDefaultPngBytes() async` | The bytes of the default Lumina logo PNG ([defaultIconAsset]): from the asset bundle, else from the editor's `assets/` folder on disk (tests and tools that run without a bundle). |
| `rasterizeFile` | `static Future<Uint8List> rasterizeFile(File file, {int size = masterSize}) async` | [file] as a square PNG, by its extension. |
| `rasterizeSvg` | `static Future<Uint8List> rasterizeSvg(String svg, {int size = masterSize}) async` | Renders [svg] fitted into a transparent [size] square. |
| `rasterizeImage` | `static Future<Uint8List> rasterizeImage(Uint8List bytes, {int size = masterSize}) async` | Decodes a PNG/JPG/WebP and draws it fitted into a transparent [size] square. |

## `lib/ui/features/sub_editors/services/viewport_mesh.dart`

### `class ViewportMesh`

A sub-editor viewport's mesh: its own instance of the asset its engine shares with every other viewport, behind the part of `FilamentAsset`'s API the viewport uses — so a Skeletal Mesh editor on a mesh the level already shows uploads nothing.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `acquire` | `static Future<ViewportMesh?> acquire(FilamentEngine engine, Uint8List payload, {String? sourcePath}) async` | Loads [payload] through [engine]'s shared cache; [sourcePath] (the asset's `.lmas` or GLB) is recorded, content decides sharing. |
| `handle` | `final LuminaMeshHandle handle` | The shared asset's handle (tests read the cache key and holders). |
| `isDisposed` | `bool get isDisposed` |  |
| `entities` | `List<int> get entities` | This viewport's entities (its instance's, not the other holders'). |
| `entityCount` | `int get entityCount` |  |
| `rootEntity` | `int get rootEntity` |  |
| `animator` | `FilamentAnimator get animator` |  |
| `renderableEntities` | `List<int> get renderableEntities` | This instance's entities that carry a renderable, in instance order. |
| `getEntitiesByName` | `List<int> getEntitiesByName(String name)` | This instance's entities named [name] (the asset's name index spans every instance). |
| `getEntityName` | `String? getEntityName(int entity)` |  |
| `getMorphTargetCountAt` | `int getMorphTargetCountAt(int entity)` |  |
| `getMorphTargetNameAt` | `String? getMorphTargetNameAt(int entity, int target)` |  |
| `addToScene` | `void addToScene(FilamentScene scene)` |  |
| `removeFromScene` | `void removeFromScene(FilamentScene scene)` |  |
| `dispose` | `void dispose()` | Gives the instance back (the asset lives on while others hold it). |

## `lib/ui/features/sub_editors/services/web_preview_server.dart`

### `class WebPreviewServer`

Serves a `flutter build web` output on `127.0.0.1` for "Launch in Browser". A page opened as `file://` cannot fetch its `.wasm`, so the preview goes through HTTP. Single-threaded WebAssembly needs no COOP/COEP headers.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `isRunning` | `bool get isRunning` |  |
| `url` | `Uri? get url` | The served address, while running. |
| `start` | `Future<Uri> start(String rootDir) async` | Serves [rootDir] on a free port, replacing a previous root. |
| `stop` | `Future<void> stop() async` |  |
| `contentTypeFor` | `static ContentType contentTypeFor(String path)` |  |

## `lib/ui/features/sub_editors/sub_editor_binding.dart`

### `typedef SubEditorBindCallback`

Invoked by a sub-editor once its view model exists, so the editor shell can bind the hosting workspace tab to the view model's dirty state and save routine (see `EditorViewModel.bindTabSession`).

## `lib/ui/features/sub_editors/views/appearance_preferences_page.dart`

### `abstract final class AppearanceFilePickers`

Where Import and Export ask for a file. The defaults are the system file dialogs; a test points them at files it created.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `pickImportFile` | `static Future<File?> Function() pickImportFile` |  |
| `pickExportFile` | `static Future<File?> Function(String suggestedName) pickExportFile` |  |
| `reset` | `static void reset()` |  |

### `class AppearancePreferencesPage`

Edit → Editor Preferences → Appearance → Theme: pick a theme, duplicate it, edit any token with a colour picker while a live preview shows the result, reset the edits, import and export `.json` themes. Built-in themes are read-only (duplicate one to edit it). "Apply" saves the edited user theme and makes it the active one; the whole editor recolours at once.

**Yapıcı Metotlar (Constructors):**

- `const AppearancePreferencesPage({super.key})`

## `lib/ui/features/sub_editors/views/editor_preferences_sub_editor.dart`

### `class EditorPreferencesSubEditor`

Edit → Editor Preferences: the user's own editor settings — a category list on the left, the category's sections on the right. Every change is saved at once. General › Appearance picks and edits the JSON editor theme.

**Yapıcı Metotlar (Constructors):**

- `const EditorPreferencesSubEditor({super.key, required this.preferences, this.onClose, this.projectDir})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `projectDir` | `final String? projectDir` | The open project (its editor source copy); null outside one. |
| `preferences` | `final EditorPreferences preferences` |  |
| `onClose` | `final VoidCallback? onClose` |  |
| `viewportsCategory` | `static const String viewportsCategory` |  |
| `appearanceCategory` | `static const String appearanceCategory` |  |

## `lib/ui/features/sub_editors/views/sub_editor_3d_viewport/mesh_painter.dart`

**Üst düzey fonksiyonlar ve değişkenler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `previewBaseColorFromParams` | `Color previewBaseColorFromParams(List<MaterialParamModel> params)` | Base colour for the software-rendered preview, taken from the first colour-typed material parameter (e.g. `baseColor`); cyan when none exists. |
| `previewScalarFromParams` | `double previewScalarFromParams(List<MaterialParamModel> params, String name, double fallback,)` | Scalar parameter lookup by (case-insensitive) name with a default. |
| `previewShadeColor` | `Color previewShadeColor(Color base, double lambert, {double roughness = 0.6, double metallic = 0.0,})` | Lambert + rough specular approximation used by the software fallback: darker facets away from the key light, a highlight that sharpens as roughness drops, and a metallic tint that pulls the highlight toward the base colour. |

## `lib/ui/features/sub_editors/views/sub_editor_3d_viewport/widget.dart`

### `enum PreviewShape`

**Değerler:**

- `mesh`
- `sphere`
- `cube`
- `cylinder`
- `plane`

### `enum ViewportShadingMode`

**Değerler:**

- `lit`
- `wireframe`
- `unlit`

### `class SubEditor3DViewport`

**Yapıcı Metotlar (Constructors):**

- `const SubEditor3DViewport({super.key, required this.title, this.glbMesh, this.meshSourcePath, this.meshComponents, this.selectedNode, PreviewShape? initialShape...`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `title` | `final String title` |  |
| `glbMesh` | `final GlbMeshData? glbMesh` |  |
| `meshSourcePath` | `final String? meshSourcePath` | Where [glbMesh] came from (the asset's `.lmas` or GLB), recorded by the engine's shared mesh cache; sharing itself is decided by the payload's content. |
| `meshComponents` | `final List<SubEditorMeshComponent>? meshComponents` |  |
| `selectedNode` | `final GlbNode? selectedNode` |  |
| `initialShape` | `final PreviewShape initialShape` |  |
| `showShapeSelector` | `final bool showShapeSelector` |  |
| `overlayHUD` | `final Widget? overlayHUD` |  |
| `onNodeVisibilityChanged` | `final void Function(GlbNode, bool)? onNodeVisibilityChanged` |  |
| `playbackController` | `final AnimationPlaybackController? playbackController` |  |
| `showBones` | `final bool showBones` |  |
| `showSockets` | `final bool showSockets` |  |
| `sockets` | `final List<SkeletalMeshSocket> sockets` |  |
| `selectedSocket` | `final SkeletalMeshSocket? selectedSocket` |  |
| `socketAttachments` | `final List<SkeletalSocketAttachment> socketAttachments` | Meshes previewed on sockets: each is parented to its bone's joint in the native preview with the socket offset as its local transform, so it is drawn at `entityWorld × G_bone × offset` and follows the pose. |
| `morphWeights` | `final Map<String, double>? morphWeights` | Active morph target / blendshape weights mapped by target name (0.0 to 1.0). |
| `jointDeltas` | `final Map<String, List<double>>? jointDeltas` | Procedural joint deltas (e.g. from RigLogic DNA facial or body evaluation), keyed by joint name, containing 9 floats: Tx, Ty, Tz (cm), Rx, Ry, Rz (Euler deg), Sx, Sy, Sz (scale delta). |
| `hiddenSectionIndices` | `final Set<int> hiddenSectionIndices` | Geometry section indices to leave out of the preview, driven by the mesh editors' per-slot Isolate toggle. |
| `highlightedSectionIndices` | `final Set<int> highlightedSectionIndices` | Geometry section indices to tint in the preview, driven by the mesh editors' per-slot Highlight toggle. Same CPU-path caveat as [hiddenSectionIndices]. |
| `sectionMaterialOverrides` | `final Map<int, Uint8List> sectionMaterialOverrides` | Compiled `.filamat` bytes to swap onto a geometry section's primitive, keyed by section index. Drives the mesh editors' per-slot material binding on the native path: sections are the primitives of the asset's renderable entities, walked in glTF order — the same order the parser builds `subPrimitives` in. |
| `previewMaterialBytes` | `final Uint8List? previewMaterialBytes` | Compiled `.filamat` package to shade the procedural preview primitive with (Material Editor). When set and no [glbMesh] payload exists, the viewport still mounts the real Filament renderer. |
| `previewMaterialParams` | `final List<MaterialParamModel> previewMaterialParams` | Editor parameter values pushed into the preview material instance. |
| `previewMaterialRevision` | `final int previewMaterialRevision` | Bump to re-apply [previewMaterialParams] without recreating the widget. |
| `onPreviewWorldReady` | `final void Function(LuminaWorld world)? onPreviewWorldReady` | Level/environment preview (Environment Lighting mixer): when set, the viewport mounts the native renderer without a mesh payload, wraps the engine/scene/view in a lumina [LuminaWorld] (editor world type) and hands it over. The caller populates the world through lumina components (lights, sky, meshes, post-process); the built-in studio lights are skipped so the world's own lighting drives the frame. |
| `onPreviewWorldDisposing` | `final void Function(LuminaWorld world)? onPreviewWorldDisposing` | Fired right before the preview world is cleaned up on dispose. |
| `yUpCamera` | `final bool yUpCamera` | Use a Y-up camera (lumina world convention) instead of inferring the up axis from the mesh bounds. |
| `initialCameraDistance` | `final double? initialCameraDistance` | Initial orbit distance override (world units). |
| `initialCameraTarget` | `final Vector3? initialCameraTarget` | What the orbit camera looks at in a preview world (runtime space, world units), with [initialCameraDistance]; the origin when null. The Anim Blueprint preview frames the character's torso rather than its feet. |
| `statsLabel` | `final String? statsLabel` | Replaces the bottom stats strip (used by previews whose content is not a single mesh, so the mesh-derived counts would be meaningless). |
| `onFloorTap` | `final void Function(Vector3 worldPoint)? onFloorTap` | Primary-button click (no drag) on the viewport, unprojected through the Y-up orbit camera onto the horizontal plane `y == floorTapPlaneY` (world units). Used by the Navigation path tester; null disables it. |
| `floorTapPlaneY` | `final double floorTapPlaneY` | Height of the floor plane [onFloorTap] rays are intersected with. |
| `brushInput` | `final ViewportBrushInput? brushInput` | A paint/sculpt tool driven by the mouse (the Landscape editor's brushes): the Y-up camera's ray under the mouse on hover, and plain LMB strokes instead of an orbit. Alt+LMB, RMB, MMB and the wheel keep the camera. Null keeps the plain camera (every other sub-editor). |
| `showGrid` | `final bool showGrid` | Whether the editor grid is drawn. A preview whose content is its own ground (a landscape) turns it off: the grid would z-fight with flat terrain at y = 0. |
| `collisionLines` | `final ({List<double> positions, List<int> indices})? collisionLines` | Line segments drawn over the mesh natively (a Static Mesh's collision view), in the viewport's own frame (the GLB as drawn: metres, Y up); null draws none. Rebuilt when a different instance is passed. |
| `gridExtent` | `final double? gridExtent` | Grid half-extent and cell size in world units, overriding the sizing guessed from [glbMesh]. A preview world whose content is in cm (the Physics Asset editor's character) passes a cm grid; null keeps the guess. |
| `gridStep` | `final double? gridStep` |  |
| `overlayLines` | `final List<SubEditorLineSet> overlayLines` | Coloured line sets drawn over the scene (a Blueprint's capsule, spring arm and camera), in the viewport's own frame. A set's native lines are rebuilt when its [SubEditorLineSet.signature] changes. |
| `initialCameraYaw` | `final double? initialCameraYaw` | The orbit camera's starting (and Reset View) yaw in degrees; -35 when null. A Y-up preview at 145° looks at an actor facing −Z from its front. |
| `transformGizmo` | `final SubEditorTransformGizmo? transformGizmo` | Sahne üzerinde çizilen dönüşüm gizmo'su: hedefi HUD'ın Q/W/E/R kümesi, snap alanları ve Yerel/Dünya geçişiyle kontrol edilen öteleme / döndürme / ölçekleme tutamaçlarına sahip olur; hiçbir tutamaca isabet etmeyen tıklama arkadaki nesneyi seçer. |
| `showTransformGizmo` | `final bool? showTransformGizmo` | Dönüşüm gizmo'sunun gösterilip gösterilmeyeceği. Null olduğunda 3D sahneler için varsayılan olarak true'dur. |
| `hasSceneLights` | `final bool hasSceneLights` | Bu 3D sahnenin yazar tarafından eklenmiş ışık bileşenleri içerip içermediği. True olduğunda viewport araç çubuğunda SCENE LIGHTS geçiş düğmesi görüntülenir. |
| `renderSceneLights` | `final bool renderSceneLights` | Viewport'un stüdyo gün ışığı/gökyüzü yerine sahnede tanımlanan ışıklarla render edilip edilmediği. |
| `onToggleSceneLights` | `final ValueChanged<bool>? onToggleSceneLights` | SCENE LIGHTS geçiş düğmesine tıklandığında tetiklenen geri çağırım. |
| `ghostSkeletons` / `overlayMarkers` / `overlayPaths` | `final List<SubEditorGhostSkeleton> ghostSkeletons` / `final List<SubEditorOverlayMarker> overlayMarkers` / `final List<SubEditorOverlayPath> overlayPaths` | Kemiklerin çizildiği çerçevede tuval katmanları (`models/sub_editor_canvas_overlay.dart`): bir renk, opaklık ve etiketle tüm-poz hayalet iskeletleri (onion skin), işaretler (nokta / elmas / halka, etiket, bir noktaya isteğe bağlı kesikli çizgi; IK hedefleri ve pole'lar) ve numaralı noktalı çoklu çizgiler (çizilmiş kök yolu). Boş liste hiçbir şey çizmez. |
| `usesNativePreview` | `static bool usesNativePreview({GlbMeshData? glbMesh, List<SubEditorMeshComponent>? meshComponents, Uint8List?...` | True when the viewport mounts the native Filament renderer: either a mesh payload or a compiled material to preview on a procedural primitive. |

## `lib/ui/features/sub_editors/views/transform_gizmo_toolbar.dart`

### `class TransformGizmoToolbar`

3D viewport'lar ve alt editörler için yeniden kullanılabilir dönüşüm gizmo araç çubuğu bileşeni. Etkileşimli araç modu düğmeleri (Seç/Ötele/Döndür/Ölçekle), koordinat uzayı geçişi (Dünya/Yerel) ve sayısal yakalama (snap) kontrolleri (Izgara/Dönme/Ölçek) sunar.

**Yapıcı Metotlar (Constructors):**

- `const TransformGizmoToolbar({super.key, required this.gizmo})`

## `lib/ui/features/sub_editors/views/sub_editor_transform_gizmo_painter.dart`

### `class SubEditorTransformGizmoPainter`

Draws a [TransformGizmoModel] over a sub-editor viewport: translate arrows with plane quads, rotate rings with a screen ring, scale stems with cubes and a centre cube — the level viewport's manipulator, on the canvas. The hovered or dragged handle is yellow (`FilamentTransformGizmo.highlightColor`), the others dim during a drag, and a locked target draws the whole gizmo dimmed.

**Yapıcı Metotlar (Constructors):**

- `const SubEditorTransformGizmoPainter({required this.model, this.activeHandle, this.dragging = false, this.locked = false,})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `model` | `final TransformGizmoModel model` |  |
| `activeHandle` | `final String? activeHandle` |  |
| `dragging` | `final bool dragging` |  |
| `locked` | `final bool locked` |  |
| `highlight` | `static const Color highlight` | The highlight the Filament manipulator uses (1, 1, 0). |

---

[Önceki: Alt editörler](index.md) | [Üst: Alt editörler](index.md) | [Sonraki: Animasyon editörü](animation.md)

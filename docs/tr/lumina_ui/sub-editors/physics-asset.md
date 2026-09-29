[English](../../../en/lumina_ui/sub-editors/physics-asset.md)

# Fizik asset editörü

Fizik Asset editörü: kemik başına çarpışma gövdeleri ve kısıtlar, çakışma kontrolleri, görünüm modları ve fizik önizleme sahnesi. Dosya yolları `lumina_ui/` paket dizinine görelidir.

**Bu sayfada:**

- [`lib/ui/features/sub_editors/views/physics_asset_sub_editor.dart`](#libuifeaturessub_editorsviewsphysics_asset_sub_editordart)
- [`lib/ui/features/sub_editors/view_models/physics_asset_editor_view_model.dart`](#libuifeaturessub_editorsview_modelsphysics_asset_editor_view_modeldart)
- [`lib/ui/features/sub_editors/services/physics_preview_scene.dart`](#libuifeaturessub_editorsservicesphysics_preview_scenedart)
- [`lib/ui/features/sub_editors/models/physics_asset_document.dart`](#libuifeaturessub_editorsmodelsphysics_asset_documentdart)

## `lib/ui/features/sub_editors/views/physics_asset_sub_editor.dart`

### `class PhysicsAssetSubEditor`

Lumina Studio's Physics Asset editor.  Authors per-bone bodies, constraints and disabled-collision pairs against a real skeletal mesh, draws them over the live Filament preview, and runs lumina's real narrow phase through `Validate Overlaps`. There is no ragdoll simulation here: the engine has no dynamics solver, so the editor authors data instead of faking a simulation.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `assetName` | `String assetName` | `assetName` alanını (field/property) ve ilişkili veriyi saklar. |
| `assetPath` | `String? assetPath` | `assetPath` alanını (field/property) ve ilişkili veriyi saklar. |
| `asset` | `RealAssetInfo? asset` | `asset` alanını (field/property) ve ilişkili veriyi saklar. |
| `skeletalMeshCandidates` | `List<RealAssetInfo> skeletalMeshCandidates` | Skeletal meshes offered by the binder when the asset has no mesh link. |
| `viewModel` | `PhysicsAssetEditorViewModel? viewModel` | `viewModel` alanını (field/property) ve ilişkili veriyi saklar. |
| `onClose` | `VoidCallback? onClose` | `onClose` alanını (field/property) ve ilişkili veriyi saklar. |
| `onBind` | `SubEditorBindCallback? onBind` | `onBind` alanını (field/property) ve ilişkili veriyi saklar. |
| `createState` | `State<PhysicsAssetSubEditor> createState() => _PhysicsAssetSubEditorState()` | Yeni bir `State` örneği veya ilişkili GPU kaynağını oluşturur ve yapılandırır. |

### `class _PhysicsAssetSubEditorState`

`_PhysicsAssetSubEditorState`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `viewModelForTest` | `PhysicsAssetEditorViewModel get viewModelForTest` | Exposed for smoke tests that drive the real editor shell. |
| `initState` | `void initState()` | `initState` işlemini gerçekleştirir. |
| `dispose` | `void dispose()` | Yerel FFI göstericilerini, dinleyicileri ve bellek bloklarını serbest bırakır. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |
| `Text` | `Text(text, style: const TextStyle(fontSize: 9, color: EditorColors.muted...` | `Text` işlemini gerçekleştirir. |

## `lib/ui/features/sub_editors/view_models/physics_asset_editor_view_model.dart`

### `class PhysicsAssetEditorViewModel`

Drives the Physics Asset sub-editor.  Loads a real PHYSICS_ASSET `.lmas`, resolves the skeletal mesh it references through an `AssetReference{slot_name: 'skeletal_mesh'}`, parses that mesh's real bone hierarchy, and authors per-bone bodies, constraints and disabled-collision pairs into a versioned document persisted back into the asset's metadata.  `Validate Overlaps` runs lumina's real narrow phase (`testPair`) over the authored bodies in **bind pose** — that is the only physics the engine actually runs; there is no dynamics solver, so nothing here simulates.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `assetPath` | `String assetPath` | `assetPath` alanını (field/property) ve ilişkili veriyi saklar. |
| `isLoading` | `bool get isLoading` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `hasError` | `bool get hasError` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `isDirty` | `bool get isDirty` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `lastError` | `String? get lastError` | `lastError` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `asset` | `LuminaAsset? get asset` | `asset` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `glbMesh` | `GlbMeshData? get glbMesh` | `glbMesh` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `skeletalMeshPath` | `String? get skeletalMeshPath` | `skeletalMeshPath` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `skeletalMeshAssetId` | `String? get skeletalMeshAssetId` | `skeletalMeshAssetId` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `hasSkeletalMesh` | `bool get hasSkeletalMesh` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `linkError` | `String? get linkError` | `linkError` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `document` | `PhysicsAssetDocument get document` | `document` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `allBones` | `List<GlbNode> get allBones` | `allBones` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `rootBones` | `List<GlbNode> get rootBones` | `rootBones` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `allBoneNames` | `List<String> get allBoneNames` | `allBoneNames` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `boneGlobals` | `Map<String, Matrix4> get boneGlobals` | `boneGlobals` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `boneGlobal` | `Matrix4? boneGlobal(String boneName)` | `boneGlobal` işlemini gerçekleştirir. |
| `selectedBody` | `PhysicsBody? get selectedBody` | İlgili aktör veya varlığı seçili duruma getirir. |
| `selectedConstraint` | `PhysicsConstraint? get selectedConstraint` | İlgili aktör veya varlığı seçili duruma getirir. |
| `boneFilter` | `String get boneFilter` | `boneFilter` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `viewMode` | `PhysicsViewMode get viewMode` | `viewMode` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `lastValidation` | `List<PhysicsOverlapResult> get lastValidation` | `lastValidation` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `hasValidated` | `bool get hasValidated` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `lastValidationIsBindPose` | `bool get lastValidationIsBindPose` | Overlap validation always runs against the bind pose (no animation). |
| `fileBasename` | `String get fileBasename` | `fileBasename` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `load` | `Future<void> load()` | Veriyi diskten veya bellekten okuyarak motora yükler ve kullanılabilir hale getirir. |
| `selectedBoneName` | `String? get selectedBoneName` | Bone highlighted in the tree (the target of Add / Replace Body). |
| `selectBone` | `void selectBone(String? boneName)` | İlgili aktör veya varlığı seçili duruma getirir. |
| `selectBody` | `void selectBody(String? boneName)` | İlgili aktör veya varlığı seçili duruma getirir. |
| `selectConstraint` | `void selectConstraint(String? name)` | İlgili aktör veya varlığı seçili duruma getirir. |
| `parentBoneOf` | `String? parentBoneOf(String boneName)` | Name of [boneName]'s parent bone, or null for a root bone. |
| `nearestParentBodyBone` | `String? nearestParentBodyBone(String boneName)` | The nearest ancestor bone that already carries a body. |
| `setBoneFilter` | `void setBoneFilter(String filter)` | `BoneFilter` parametresini günceller ve sisteme uygular. |
| `setViewMode` | `void setViewMode(PhysicsViewMode mode)` | `ViewMode` parametresini günceller ve sisteme uygular. |
| `matchesFilter` | `bool matchesFilter(GlbNode node)` | True when a bone row (or one of its descendants / bodies) survives the filter. |
| `addBody` | `bool addBody(String boneName, PhysicsShapeType shape)` | Adds an auto-sized body to [boneName]. Returns false (with [lastError]) when the bone is unknown or already carries a body. |
| `replaceBody` | `bool replaceBody(String boneName, PhysicsShapeType shape)` | Changes the shape of an existing body, keeping its sizing and offsets. |
| `removeBody` | `bool removeBody(String boneName)` | Removes [boneName]'s body plus every constraint and disabled pair that referenced it, so no dangling references survive a save. |
| `boneSegmentLength` | `double boneSegmentLength(String boneName)` | Length of the bone -> first child bone segment (falls back for leaves). |
| `boneSkinRadius` | `double boneSkinRadius(String boneName)` | Radial extent of the skin vertices weighted >= 0.5 to [boneName], measured around the bone's local +Y axis. Returns 0 when the mesh has no skin data. |
| `setBodyShape` | `void setBodyShape(String boneName, PhysicsShapeType shape) => replaceBod...` | `BodyShape` parametresini günceller ve sisteme uygular. |
| `setBodyRadius` | `void setBodyRadius(String boneName, double value)` | `BodyRadius` parametresini günceller ve sisteme uygular. |
| `setBodyHalfHeight` | `void setBodyHalfHeight(String boneName, double value)` | `BodyHalfHeight` parametresini günceller ve sisteme uygular. |
| `setBodyExtent` | `void setBodyExtent(String boneName, int axis, double value)` | `BodyExtent` parametresini günceller ve sisteme uygular. |
| `setBodyOffsetLocation` | `void setBodyOffsetLocation(String boneName, int axis, double value)` | `BodyOffsetLocation` parametresini günceller ve sisteme uygular. |
| `setBodyOffsetRotation` | `void setBodyOffsetRotation(String boneName, int axis, double value)` | `BodyOffsetRotation` parametresini günceller ve sisteme uygular. |
| `setBodyMass` | `void setBodyMass(String boneName, double value)` | `BodyMass` parametresini günceller ve sisteme uygular. |
| `setBodyLinearDamping` | `void setBodyLinearDamping(String boneName, double value)` | `BodyLinearDamping` parametresini günceller ve sisteme uygular. |
| `setBodyAngularDamping` | `void setBodyAngularDamping(String boneName, double value)` | `BodyAngularDamping` parametresini günceller ve sisteme uygular. |
| `setBodyPhysicsMaterial` | `void setBodyPhysicsMaterial(String boneName, String name)` | `BodyPhysicsMaterial` parametresini günceller ve sisteme uygular. |
| `addConstraint` | `bool addConstraint(String boneA, String boneB)` | Adds a constraint between the bodies on [boneA] (parent) and [boneB]. |
| `removeConstraint` | `bool removeConstraint(String name)` | Belirtilen `Constraint` nesnesini/bileşenini serbest bırakır ve güvenle temizler. |
| `setConstraintMode` | `void setConstraintMode(String name, PhysicsAngularMode mode)` | `ConstraintMode` parametresini günceller ve sisteme uygular. |
| `setConstraintSwing1` | `void setConstraintSwing1(String name, double deg)` | `ConstraintSwing1` parametresini günceller ve sisteme uygular. |
| `setConstraintSwing2` | `void setConstraintSwing2(String name, double deg)` | `ConstraintSwing2` parametresini günceller ve sisteme uygular. |
| `setConstraintTwist` | `void setConstraintTwist(String name, double deg)` | `ConstraintTwist` parametresini günceller ve sisteme uygular. |
| `constraintLimitsEnabled` | `bool constraintLimitsEnabled(PhysicsConstraint constraint)` | `constraintLimitsEnabled` işlemini gerçekleştirir. |
| `disableCollisionBetween` | `bool disableCollisionBetween(String boneA, String boneB)` | `disableCollisionBetween` işlemini gerçekleştirir. |
| `enableCollisionBetween` | `bool enableCollisionBetween(String boneA, String boneB)` | `enableCollisionBetween` işlemini gerçekleştirir. |
| `isCollisionDisabled` | `bool isCollisionDisabled(String boneA, String boneB) => _document.isPair...` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `bodyWorldTransform` | `Matrix4 bodyWorldTransform(PhysicsBody body)` | `entityWorld x G_bone x offset` — the same chain sockets use. |
| `validateOverlaps` | `List<PhysicsOverlapResult> validateOverlaps()` | Runs lumina's real narrow phase over every authored body pair in bind pose. Disabled pairs are skipped (and labelled); clean pairs are omitted. |
| `validationErrors` | `List<String> get validationErrors` | Blocking document errors, surfaced inline and gating Save. |
| `buildOverlay` | `List<PhysicsOverlayLineSet> buildOverlay()` | World-space line sets for the current view mode. |
| `buildSolidBodies` | `List<PhysicsSolidMesh> buildSolidBodies()` | Translucent solid bodies — only the `Solid Bodies` view mode draws them. |
| `save` | `Future<bool> save()` | Mevcut durumu veya varlığı diske dosya olarak serileştirip yazar. |

## `lib/ui/features/sub_editors/services/physics_preview_scene.dart`

**Üst Düzey Fonksiyonlar (Top-level Functions):**

- **`show CullingMode, FilamentMaterialInstance, FilamentMaterialProvider, FilamentWireframeMesh, MaterialKey`**: `MaterialKey` işlemini gerçekleştirir.

### `class PhysicsSolidMesh`

Triangulated body geometry for the `Solid Bodies` view mode.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `name` | `String name` | `name` alanını (field/property) ve ilişkili veriyi saklar. |
| `positions` | `Float32List positions` | `positions` alanını (field/property) ve ilişkili veriyi saklar. |
| `normals` | `Float32List normals` | `normals` alanını (field/property) ve ilişkili veriyi saklar. |
| `colors` | `Uint8List colors` | `colors` alanını (field/property) ve ilişkili veriyi saklar. |
| `indices` | `Uint32List indices` | `indices` alanını (field/property) ve ilişkili veriyi saklar. |
| `vertexCount` | `int get vertexCount` | `vertexCount` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `triangleCount` | `int get triangleCount` | `triangleCount` özelliğinin anlık değerini okuyan getter erişimcisi. |

### `class PhysicsOverlayBuilder`

Builds world-space line geometry for the Physics Asset editor's body and constraint overlays.  Capsules go through the engine's own [LuminaCapsuleComponent.buildCapsuleWireframe] so the editor draws exactly the shape the collision stack tests; boxes and spheres are line sets built from the same world transform chain (`entityWorld x G_bone x offset`).

### `class PhysicsPreviewScene`

Mounts the authored body / constraint overlays into the sub-editor viewport's real Filament scene as native LINES entities.  The viewport hands over its [LuminaWorld] (already carrying the native context) through `onPreviewWorldReady`; every line set becomes one [FilamentWireframeMesh]. Only sets whose geometry actually changed are rebuilt, and teardown follows the viewport's `flushAndWait` -> remove -> dispose ordering.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `isAttached` | `bool get isAttached` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `entityCount` | `int get entityCount` | Number of live native wireframe entities (one per visible line set). |
| `solidSectionCount` | `int get solidSectionCount` | Number of live translucent solid-body sections. |
| `attach` | `void attach(LuminaWorld world)` | `attach` işlemini gerçekleştirir. |
| `syncSolid` | `void syncSolid(List<PhysicsSolidMesh> meshes)` | Rebuilds the translucent solid bodies so they match [meshes] exactly. |
| `detach` | `void detach()` | `detach` işlemini gerçekleştirir. |

## `lib/ui/features/sub_editors/models/physics_asset_document.dart`

**Üst Düzey Fonksiyonlar (Top-level Functions):**

- **`Quaternion quaternionFromEulerDegrees(List<double> eulerDeg)`**: Euler XYZ degrees -> quaternion, matching the editor's transform convention.

### `enum PhysicsShapeType`

The three primitive types the Physics Asset editor authors.  The engine's collision module also carries cone and cylinder shapes; the schema's [PhysicsShapeType] can grow later without breaking saved documents because it is persisted by name.

### `extension PhysicsShapeTypeLabel`

`PhysicsShapeTypeLabel`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `extension` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `label` | `String get label` | `label` özelliğinin anlık değerini okuyan getter erişimcisi. |

### `enum PhysicsAngularMode`

Angular constraint modes of a joint between two bodies.

### `extension PhysicsAngularModeLabel`

`PhysicsAngularModeLabel`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `extension` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `label` | `String get label` | `label` özelliğinin anlık değerini okuyan getter erişimcisi. |

### `class PhysicsBody`

One authored rigid body attached to a single bone of the skeletal mesh.  Masses and damping have no solver behind them yet (lumina runs a kinematic collision stack, not dynamics) but they are part of the persisted schema so a future solver consumes the document unchanged.

**Yapıcı Metotlar (Constructors):**
- `PhysicsBody.fromJson(Map<String, dynamic> j)`: `PhysicsBody.fromJson(Map<String, dynamic> j)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `boneName` | `String boneName` | `boneName` alanını (field/property) ve ilişkili veriyi saklar. |
| `shape` | `PhysicsShapeType shape` | `shape` alanını (field/property) ve ilişkili veriyi saklar. |
| `radius` | `double radius` | Capsule / sphere radius, in metres. |
| `halfHeight` | `double halfHeight` | Half-height of the *full* capsule (the inner segment is `halfHeight - radius`). Always clamped to `>= radius`. |
| `halfExtents` | `List<double> halfExtents` | Box half extents (x, y, z) in metres. |
| `offsetLocation` | `List<double> offsetLocation` | Offset of the body relative to its bone. |
| `offsetRotationDeg` | `List<double> offsetRotationDeg` | `offsetRotationDeg` alanını (field/property) ve ilişkili veriyi saklar. |
| `massKg` | `double massKg` | `massKg` alanını (field/property) ve ilişkili veriyi saklar. |
| `linearDamping` | `double linearDamping` | `linearDamping` alanını (field/property) ve ilişkili veriyi saklar. |
| `angularDamping` | `double angularDamping` | `angularDamping` alanını (field/property) ve ilişkili veriyi saklar. |
| `physicsMaterial` | `String physicsMaterial` | Free-text physics-material name (no PM asset type exists yet). |
| `name` | `String get name` | `pelvis_Capsule` — the name shown in the tree, inspector and validation. |
| `effectiveHalfHeight` | `double get effectiveHalfHeight` | Clamped half-height honouring the engine's `halfHeight >= radius` rule. |
| `toCollisionShape` | `CollisionShape toCollisionShape()` | The engine value type this body maps onto for narrow-phase tests. |
| `offsetTransform` | `Matrix4 get offsetTransform` | Body-relative-to-bone transform (`offset` in `entityWorld x G_bone x offset`). |
| `toJson` | `Map<String, dynamic> toJson()` | Nesneyi JSON haritasına serileştirir. |

### `class PhysicsConstraint`

A joint definition between two authored bodies, keyed by their bone names.

**Yapıcı Metotlar (Constructors):**
- `PhysicsConstraint.fromJson(Map<String, dynamic> j)`: `PhysicsConstraint.fromJson(Map<String, dynamic> j)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `bodyA` | `String bodyA` | Parent-side body bone name. |
| `bodyB` | `String bodyB` | Child-side body bone name; the constraint takes its display name from it. |
| `angularMode` | `PhysicsAngularMode angularMode` | `angularMode` alanını (field/property) ve ilişkili veriyi saklar. |
| `swing1Deg` | `double swing1Deg` | `swing1Deg` alanını (field/property) ve ilişkili veriyi saklar. |
| `swing2Deg` | `double swing2Deg` | `swing2Deg` alanını (field/property) ve ilişkili veriyi saklar. |
| `twistDeg` | `double twistDeg` | `twistDeg` alanını (field/property) ve ilişkili veriyi saklar. |
| `name` | `String get name` | `spine_01_Constraint`. |
| `limitsEnabled` | `bool get limitsEnabled` | `limitsEnabled` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `touches` | `bool touches(String bone)` | `touches` işlemini gerçekleştirir. |
| `toJson` | `Map<String, dynamic> toJson()` | Nesneyi JSON haritasına serileştirir. |

### `class PhysicsAssetDocument`

The whole authored PHYSICS_ASSET payload, persisted as versioned JSON in `LuminaAsset.metadata['physics_asset']`.

**Yapıcı Metotlar (Constructors):**
- `PhysicsAssetDocument.fromJson(Map<String, dynamic> j)`: `PhysicsAssetDocument.fromJson(Map<String, dynamic> j)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `bodies` | `List<PhysicsBody> bodies` | `bodies` alanını (field/property) ve ilişkili veriyi saklar. |
| `constraints` | `List<PhysicsConstraint> constraints` | `constraints` alanını (field/property) ve ilişkili veriyi saklar. |
| `disabledCollisionPairs` | `List<List<String>> disabledCollisionPairs` | Unordered bone-name pairs whose bodies never collide. |
| `bodyForBone` | `PhysicsBody? bodyForBone(String boneName)` | `bodyForBone` işlemini gerçekleştirir. |
| `constraintByName` | `PhysicsConstraint? constraintByName(String name)` | `constraintByName` işlemini gerçekleştirir. |
| `constraintsForBone` | `List<PhysicsConstraint> constraintsForBone(String boneName)` | `constraintsForBone` işlemini gerçekleştirir. |
| `isPairDisabled` | `bool isPairDisabled(String a, String b)` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `toJson` | `Map<String, dynamic> toJson()` | Nesneyi JSON haritasına serileştirir. |

### `class PhysicsOverlapResult`

One pair result of the `Validate Overlaps` bind-pose narrow-phase pass.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `bodyA` | `String bodyA` | `bodyA` alanını (field/property) ve ilişkili veriyi saklar. |
| `bodyB` | `String bodyB` | `bodyB` alanını (field/property) ve ilişkili veriyi saklar. |
| `penetrationDepth` | `double penetrationDepth` | `penetrationDepth` alanını (field/property) ve ilişkili veriyi saklar. |
| `isColliding` | `bool isColliding` | `isColliding` alanını (field/property) ve ilişkili veriyi saklar. |
| `disabled` | `bool disabled` | True when the pair is on the disabled-collision list (skipped, not tested). |
| `boneA` | `String boneA` | Bone names, for click-to-select from the result list. |
| `boneB` | `String boneB` | `boneB` alanını (field/property) ve ilişkili veriyi saklar. |

### `enum PhysicsViewMode`

Viewport overlay modes offered by the `View Modes` select.

### `extension PhysicsViewModeLabel`

`PhysicsViewModeLabel`: Kullanıcı arayüzünü (UI) oluşturan ve kullanıcı etkileşimlerini dinleyen shadcn_flutter bileşenidir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `label` | `String get label` | `label` özelliğinin anlık değerini okuyan getter erişimcisi. |

### `class PhysicsOverlayLineSet`

A batch of world-space line segments for one body or constraint marker, ready to hand to `FilamentWireframeMesh.createLineSegments`.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `name` | `String name` | `name` alanını (field/property) ve ilişkili veriyi saklar. |
| `isConstraint` | `bool isConstraint` | `isConstraint` alanını (field/property) ve ilişkili veriyi saklar. |
| `isSelected` | `bool isSelected` | `isSelected` alanını (field/property) ve ilişkili veriyi saklar. |
| `dimmed` | `bool dimmed` | Rendered dimmed because the body sits on a disabled-collision pair. |
| `filled` | `bool filled` | Solid-bodies mode asks the 2D painter for a translucent fill. |
| `positions` | `List<double> positions` | Flat xyz triples in world space. |
| `lineIndices` | `List<int> lineIndices` | Index pairs into [positions] / 3. |

---

[Önceki: Parçacık editörü](particle.md) | [Üst: Alt editörler](index.md) | [Sonraki: Proje ayarları](project-settings.md)

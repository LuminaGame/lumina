[Türkçe](../../../tr/lumina_ui/sub-editors/physics-asset.md)

# Physics asset editor

The Physics Asset editor: collision bodies and constraints per bone, overlap checks, view modes and the physics preview scene. File paths are relative to the `lumina_ui/` package directory.

**On this page:**

- [`lib/ui/features/sub_editors/views/physics_asset_sub_editor.dart`](#libuifeaturessub_editorsviewsphysics_asset_sub_editordart)
- [`lib/ui/features/sub_editors/view_models/physics_asset_editor_view_model.dart`](#libuifeaturessub_editorsview_modelsphysics_asset_editor_view_modeldart)
- [`lib/ui/features/sub_editors/services/physics_preview_scene.dart`](#libuifeaturessub_editorsservicesphysics_preview_scenedart)
- [`lib/ui/features/sub_editors/models/physics_asset_document.dart`](#libuifeaturessub_editorsmodelsphysics_asset_documentdart)

## `lib/ui/features/sub_editors/views/physics_asset_sub_editor.dart`

### `class PhysicsAssetSubEditor`

Lumina Studio's Physics Asset editor.  Authors per-bone bodies, constraints and disabled-collision pairs against a real skeletal mesh, draws them over the live Filament preview, and runs lumina's real narrow phase through `Validate Overlaps`. There is no ragdoll simulation here: the engine has no dynamics solver, so the editor authors data instead of faking a simulation.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `assetName` | `String assetName` | Holds the `assetName` property or configuration state. |
| `assetPath` | `String? assetPath` | Holds the `assetPath` property or configuration state. |
| `asset` | `RealAssetInfo? asset` | Holds the `asset` property or configuration state. |
| `skeletalMeshCandidates` | `List<RealAssetInfo> skeletalMeshCandidates` | Skeletal meshes offered by the binder when the asset has no mesh link. |
| `viewModel` | `PhysicsAssetEditorViewModel? viewModel` | Holds the `viewModel` property or configuration state. |
| `onClose` | `VoidCallback? onClose` | Holds the `onClose` property or configuration state. |
| `onBind` | `SubEditorBindCallback? onBind` | Holds the `onBind` property or configuration state. |
| `createState` | `State<PhysicsAssetSubEditor> createState() => _PhysicsAssetSubEditorState()` | Creates, configures, and returns a new `State` instance or associated GPU resource. |

### `class _PhysicsAssetSubEditorState`

`_PhysicsAssetSubEditorState`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `viewModelForTest` | `PhysicsAssetEditorViewModel get viewModelForTest` | Exposed for smoke tests that drive the real editor shell. |
| `initState` | `void initState()` | Executes `initState` operation. |
| `dispose` | `void dispose()` | Releases native FFI pointers, event subscriptions, and allocated memory. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |
| `Text` | `Text(text, style: const TextStyle(fontSize: 9, color: EditorColors.muted...` | Executes `Text` operation. |

## `lib/ui/features/sub_editors/view_models/physics_asset_editor_view_model.dart`

### `class PhysicsAssetEditorViewModel`

Drives the Physics Asset sub-editor.  Loads a real PHYSICS_ASSET `.lmas`, resolves the skeletal mesh it references through an `AssetReference{slot_name: 'skeletal_mesh'}`, parses that mesh's real bone hierarchy, and authors per-bone bodies, constraints and disabled-collision pairs into a versioned document persisted back into the asset's metadata.  `Validate Overlaps` runs lumina's real narrow phase (`testPair`) over the authored bodies in **bind pose** — that is the only physics the engine actually runs; there is no dynamics solver, so nothing here simulates.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `assetPath` | `String assetPath` | Holds the `assetPath` property or configuration state. |
| `isLoading` | `bool get isLoading` | Checks current state or capability and returns a boolean value. |
| `hasError` | `bool get hasError` | Checks current state or capability and returns a boolean value. |
| `isDirty` | `bool get isDirty` | Checks current state or capability and returns a boolean value. |
| `lastError` | `String? get lastError` | Getter accessor returning the current value of `lastError`. |
| `asset` | `LuminaAsset? get asset` | Getter accessor returning the current value of `asset`. |
| `glbMesh` | `GlbMeshData? get glbMesh` | Getter accessor returning the current value of `glbMesh`. |
| `skeletalMeshPath` | `String? get skeletalMeshPath` | Getter accessor returning the current value of `skeletalMeshPath`. |
| `skeletalMeshAssetId` | `String? get skeletalMeshAssetId` | Getter accessor returning the current value of `skeletalMeshAssetId`. |
| `hasSkeletalMesh` | `bool get hasSkeletalMesh` | Checks current state or capability and returns a boolean value. |
| `linkError` | `String? get linkError` | Getter accessor returning the current value of `linkError`. |
| `document` | `PhysicsAssetDocument get document` | Getter accessor returning the current value of `document`. |
| `allBones` | `List<GlbNode> get allBones` | Getter accessor returning the current value of `allBones`. |
| `rootBones` | `List<GlbNode> get rootBones` | Getter accessor returning the current value of `rootBones`. |
| `allBoneNames` | `List<String> get allBoneNames` | Getter accessor returning the current value of `allBoneNames`. |
| `boneGlobals` | `Map<String, Matrix4> get boneGlobals` | Getter accessor returning the current value of `boneGlobals`. |
| `boneGlobal` | `Matrix4? boneGlobal(String boneName)` | Executes `boneGlobal` operation. |
| `selectedBody` | `PhysicsBody? get selectedBody` | Selects the target actor or asset. |
| `selectedConstraint` | `PhysicsConstraint? get selectedConstraint` | Selects the target actor or asset. |
| `boneFilter` | `String get boneFilter` | Getter accessor returning the current value of `boneFilter`. |
| `viewMode` | `PhysicsViewMode get viewMode` | Getter accessor returning the current value of `viewMode`. |
| `lastValidation` | `List<PhysicsOverlapResult> get lastValidation` | Getter accessor returning the current value of `lastValidation`. |
| `hasValidated` | `bool get hasValidated` | Checks current state or capability and returns a boolean value. |
| `lastValidationIsBindPose` | `bool get lastValidationIsBindPose` | Overlap validation always runs against the bind pose (no animation). |
| `fileBasename` | `String get fileBasename` | Getter accessor returning the current value of `fileBasename`. |
| `load` | `Future<void> load()` | Loads data from disk or memory buffer into the engine. |
| `selectedBoneName` | `String? get selectedBoneName` | Bone highlighted in the tree (the target of Add / Replace Body). |
| `selectBone` | `void selectBone(String? boneName)` | Selects the target actor or asset. |
| `selectBody` | `void selectBody(String? boneName)` | Selects the target actor or asset. |
| `selectConstraint` | `void selectConstraint(String? name)` | Selects the target actor or asset. |
| `parentBoneOf` | `String? parentBoneOf(String boneName)` | Name of [boneName]'s parent bone, or null for a root bone. |
| `nearestParentBodyBone` | `String? nearestParentBodyBone(String boneName)` | The nearest ancestor bone that already carries a body. |
| `setBoneFilter` | `void setBoneFilter(String filter)` | Updates the `BoneFilter` parameter and applies changes to the system. |
| `setViewMode` | `void setViewMode(PhysicsViewMode mode)` | Updates the `ViewMode` parameter and applies changes to the system. |
| `matchesFilter` | `bool matchesFilter(GlbNode node)` | True when a bone row (or one of its descendants / bodies) survives the filter. |
| `addBody` | `bool addBody(String boneName, PhysicsShapeType shape)` | Adds an auto-sized body to [boneName]. Returns false (with [lastError]) when the bone is unknown or already carries a body. |
| `replaceBody` | `bool replaceBody(String boneName, PhysicsShapeType shape)` | Changes the shape of an existing body, keeping its sizing and offsets. |
| `removeBody` | `bool removeBody(String boneName)` | Removes [boneName]'s body plus every constraint and disabled pair that referenced it, so no dangling references survive a save. |
| `boneSegmentLength` | `double boneSegmentLength(String boneName)` | Length of the bone -> first child bone segment (falls back for leaves). |
| `boneSkinRadius` | `double boneSkinRadius(String boneName)` | Radial extent of the skin vertices weighted >= 0.5 to [boneName], measured around the bone's local +Y axis. Returns 0 when the mesh has no skin data. |
| `setBodyShape` | `void setBodyShape(String boneName, PhysicsShapeType shape) => replaceBod...` | Updates the `BodyShape` parameter and applies changes to the system. |
| `setBodyRadius` | `void setBodyRadius(String boneName, double value)` | Updates the `BodyRadius` parameter and applies changes to the system. |
| `setBodyHalfHeight` | `void setBodyHalfHeight(String boneName, double value)` | Updates the `BodyHalfHeight` parameter and applies changes to the system. |
| `setBodyExtent` | `void setBodyExtent(String boneName, int axis, double value)` | Updates the `BodyExtent` parameter and applies changes to the system. |
| `setBodyOffsetLocation` | `void setBodyOffsetLocation(String boneName, int axis, double value)` | Updates the `BodyOffsetLocation` parameter and applies changes to the system. |
| `setBodyOffsetRotation` | `void setBodyOffsetRotation(String boneName, int axis, double value)` | Updates the `BodyOffsetRotation` parameter and applies changes to the system. |
| `setBodyMass` | `void setBodyMass(String boneName, double value)` | Updates the `BodyMass` parameter and applies changes to the system. |
| `setBodyLinearDamping` | `void setBodyLinearDamping(String boneName, double value)` | Updates the `BodyLinearDamping` parameter and applies changes to the system. |
| `setBodyAngularDamping` | `void setBodyAngularDamping(String boneName, double value)` | Updates the `BodyAngularDamping` parameter and applies changes to the system. |
| `setBodyPhysicsMaterial` | `void setBodyPhysicsMaterial(String boneName, String name)` | Updates the `BodyPhysicsMaterial` parameter and applies changes to the system. |
| `addConstraint` | `bool addConstraint(String boneA, String boneB)` | Adds a constraint between the bodies on [boneA] (parent) and [boneB]. |
| `removeConstraint` | `bool removeConstraint(String name)` | Releases and safely disposes the specified `Constraint` resource. |
| `setConstraintMode` | `void setConstraintMode(String name, PhysicsAngularMode mode)` | Updates the `ConstraintMode` parameter and applies changes to the system. |
| `setConstraintSwing1` | `void setConstraintSwing1(String name, double deg)` | Updates the `ConstraintSwing1` parameter and applies changes to the system. |
| `setConstraintSwing2` | `void setConstraintSwing2(String name, double deg)` | Updates the `ConstraintSwing2` parameter and applies changes to the system. |
| `setConstraintTwist` | `void setConstraintTwist(String name, double deg)` | Updates the `ConstraintTwist` parameter and applies changes to the system. |
| `constraintLimitsEnabled` | `bool constraintLimitsEnabled(PhysicsConstraint constraint)` | Executes `constraintLimitsEnabled` operation. |
| `disableCollisionBetween` | `bool disableCollisionBetween(String boneA, String boneB)` | Executes `disableCollisionBetween` operation. |
| `enableCollisionBetween` | `bool enableCollisionBetween(String boneA, String boneB)` | Executes `enableCollisionBetween` operation. |
| `isCollisionDisabled` | `bool isCollisionDisabled(String boneA, String boneB) => _document.isPair...` | Checks current state or capability and returns a boolean value. |
| `bodyWorldTransform` | `Matrix4 bodyWorldTransform(PhysicsBody body)` | `entityWorld x G_bone x offset` — the same chain sockets use. |
| `validateOverlaps` | `List<PhysicsOverlapResult> validateOverlaps()` | Runs lumina's real narrow phase over every authored body pair in bind pose. Disabled pairs are skipped (and labelled); clean pairs are omitted. |
| `validationErrors` | `List<String> get validationErrors` | Blocking document errors, surfaced inline and gating Save. |
| `buildOverlay` | `List<PhysicsOverlayLineSet> buildOverlay()` | World-space line sets for the current view mode. |
| `buildSolidBodies` | `List<PhysicsSolidMesh> buildSolidBodies()` | Translucent solid bodies — only the `Solid Bodies` view mode draws them. |
| `save` | `Future<bool> save()` | Serializes and writes the current state or asset to disk. |

## `lib/ui/features/sub_editors/services/physics_preview_scene.dart`

**Top-level Functions:**

- **`show CullingMode, FilamentMaterialInstance, FilamentMaterialProvider, FilamentWireframeMesh, MaterialKey`**: Executes `MaterialKey` operation.

### `class PhysicsSolidMesh`

Triangulated body geometry for the `Solid Bodies` view mode.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `name` | `String name` | Holds the `name` property or configuration state. |
| `positions` | `Float32List positions` | Holds the `positions` property or configuration state. |
| `normals` | `Float32List normals` | Holds the `normals` property or configuration state. |
| `colors` | `Uint8List colors` | Holds the `colors` property or configuration state. |
| `indices` | `Uint32List indices` | Holds the `indices` property or configuration state. |
| `vertexCount` | `int get vertexCount` | Getter accessor returning the current value of `vertexCount`. |
| `triangleCount` | `int get triangleCount` | Getter accessor returning the current value of `triangleCount`. |

### `class PhysicsOverlayBuilder`

Builds world-space line geometry for the Physics Asset editor's body and constraint overlays.  Capsules go through the engine's own [LuminaCapsuleComponent.buildCapsuleWireframe] so the editor draws exactly the shape the collision stack tests; boxes and spheres are line sets built from the same world transform chain (`entityWorld x G_bone x offset`).

### `class PhysicsPreviewScene`

Mounts the authored body / constraint overlays into the sub-editor viewport's real Filament scene as native LINES entities.  The viewport hands over its [LuminaWorld] (already carrying the native context) through `onPreviewWorldReady`; every line set becomes one [FilamentWireframeMesh]. Only sets whose geometry actually changed are rebuilt, and teardown follows the viewport's `flushAndWait` -> remove -> dispose ordering.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `isAttached` | `bool get isAttached` | Checks current state or capability and returns a boolean value. |
| `entityCount` | `int get entityCount` | Number of live native wireframe entities (one per visible line set). |
| `solidSectionCount` | `int get solidSectionCount` | Number of live translucent solid-body sections. |
| `attach` | `void attach(LuminaWorld world)` | Executes `attach` operation. |
| `syncSolid` | `void syncSolid(List<PhysicsSolidMesh> meshes)` | Rebuilds the translucent solid bodies so they match [meshes] exactly. |
| `detach` | `void detach()` | Executes `detach` operation. |

## `lib/ui/features/sub_editors/models/physics_asset_document.dart`

**Top-level Functions:**

- **`Quaternion quaternionFromEulerDegrees(List<double> eulerDeg)`**: Euler XYZ degrees -> quaternion, matching the editor's transform convention.

### `enum PhysicsShapeType`

The three primitive types the Physics Asset editor authors.  The engine's collision module also carries cone and cylinder shapes; the schema's [PhysicsShapeType] can grow later without breaking saved documents because it is persisted by name.

### `extension PhysicsShapeTypeLabel`

`PhysicsShapeTypeLabel`: `extension` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `label` | `String get label` | Getter accessor returning the current value of `label`. |

### `enum PhysicsAngularMode`

Angular constraint modes of a joint between two bodies.

### `extension PhysicsAngularModeLabel`

`PhysicsAngularModeLabel`: `extension` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `label` | `String get label` | Getter accessor returning the current value of `label`. |

### `class PhysicsBody`

One authored rigid body attached to a single bone of the skeletal mesh.  Masses and damping have no solver behind them yet (lumina runs a kinematic collision stack, not dynamics) but they are part of the persisted schema so a future solver consumes the document unchanged.

**Constructors:**
- `PhysicsBody.fromJson(Map<String, dynamic> j)`: Initializes `PhysicsBody.fromJson(Map<String, dynamic> j)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `boneName` | `String boneName` | Holds the `boneName` property or configuration state. |
| `shape` | `PhysicsShapeType shape` | Holds the `shape` property or configuration state. |
| `radius` | `double radius` | Capsule / sphere radius, in metres. |
| `halfHeight` | `double halfHeight` | Half-height of the *full* capsule (the inner segment is `halfHeight - radius`). Always clamped to `>= radius`. |
| `halfExtents` | `List<double> halfExtents` | Box half extents (x, y, z) in metres. |
| `offsetLocation` | `List<double> offsetLocation` | Offset of the body relative to its bone. |
| `offsetRotationDeg` | `List<double> offsetRotationDeg` | Holds the `offsetRotationDeg` property or configuration state. |
| `massKg` | `double massKg` | Holds the `massKg` property or configuration state. |
| `linearDamping` | `double linearDamping` | Holds the `linearDamping` property or configuration state. |
| `angularDamping` | `double angularDamping` | Holds the `angularDamping` property or configuration state. |
| `physicsMaterial` | `String physicsMaterial` | Free-text physics-material name (no PM asset type exists yet). |
| `name` | `String get name` | `pelvis_Capsule` — the name shown in the tree, inspector and validation. |
| `effectiveHalfHeight` | `double get effectiveHalfHeight` | Clamped half-height honouring the engine's `halfHeight >= radius` rule. |
| `toCollisionShape` | `CollisionShape toCollisionShape()` | The engine value type this body maps onto for narrow-phase tests. |
| `offsetTransform` | `Matrix4 get offsetTransform` | Body-relative-to-bone transform (`offset` in `entityWorld x G_bone x offset`). |
| `toJson` | `Map<String, dynamic> toJson()` | Serializes the object to a JSON map. |

### `class PhysicsConstraint`

A joint definition between two authored bodies, keyed by their bone names.

**Constructors:**
- `PhysicsConstraint.fromJson(Map<String, dynamic> j)`: Initializes `PhysicsConstraint.fromJson(Map<String, dynamic> j)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `bodyA` | `String bodyA` | Parent-side body bone name. |
| `bodyB` | `String bodyB` | Child-side body bone name; the constraint takes its display name from it. |
| `angularMode` | `PhysicsAngularMode angularMode` | Holds the `angularMode` property or configuration state. |
| `swing1Deg` | `double swing1Deg` | Holds the `swing1Deg` property or configuration state. |
| `swing2Deg` | `double swing2Deg` | Holds the `swing2Deg` property or configuration state. |
| `twistDeg` | `double twistDeg` | Holds the `twistDeg` property or configuration state. |
| `name` | `String get name` | `spine_01_Constraint`. |
| `limitsEnabled` | `bool get limitsEnabled` | Getter accessor returning the current value of `limitsEnabled`. |
| `touches` | `bool touches(String bone)` | Executes `touches` operation. |
| `toJson` | `Map<String, dynamic> toJson()` | Serializes the object to a JSON map. |

### `class PhysicsAssetDocument`

The whole authored PHYSICS_ASSET payload, persisted as versioned JSON in `LuminaAsset.metadata['physics_asset']`.

**Constructors:**
- `PhysicsAssetDocument.fromJson(Map<String, dynamic> j)`: Initializes `PhysicsAssetDocument.fromJson(Map<String, dynamic> j)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `bodies` | `List<PhysicsBody> bodies` | Holds the `bodies` property or configuration state. |
| `constraints` | `List<PhysicsConstraint> constraints` | Holds the `constraints` property or configuration state. |
| `disabledCollisionPairs` | `List<List<String>> disabledCollisionPairs` | Unordered bone-name pairs whose bodies never collide. |
| `bodyForBone` | `PhysicsBody? bodyForBone(String boneName)` | Executes `bodyForBone` operation. |
| `constraintByName` | `PhysicsConstraint? constraintByName(String name)` | Executes `constraintByName` operation. |
| `constraintsForBone` | `List<PhysicsConstraint> constraintsForBone(String boneName)` | Executes `constraintsForBone` operation. |
| `isPairDisabled` | `bool isPairDisabled(String a, String b)` | Checks current state or capability and returns a boolean value. |
| `toJson` | `Map<String, dynamic> toJson()` | Serializes the object to a JSON map. |

### `class PhysicsOverlapResult`

One pair result of the `Validate Overlaps` bind-pose narrow-phase pass.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `bodyA` | `String bodyA` | Holds the `bodyA` property or configuration state. |
| `bodyB` | `String bodyB` | Holds the `bodyB` property or configuration state. |
| `penetrationDepth` | `double penetrationDepth` | Holds the `penetrationDepth` property or configuration state. |
| `isColliding` | `bool isColliding` | Holds the `isColliding` property or configuration state. |
| `disabled` | `bool disabled` | True when the pair is on the disabled-collision list (skipped, not tested). |
| `boneA` | `String boneA` | Bone names, for click-to-select from the result list. |
| `boneB` | `String boneB` | Holds the `boneB` property or configuration state. |

### `enum PhysicsViewMode`

Viewport overlay modes offered by the `View Modes` select.

### `extension PhysicsViewModeLabel`

`PhysicsViewModeLabel`: shadcn_flutter UI component rendering interface elements and listening to interactions.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `label` | `String get label` | Getter accessor returning the current value of `label`. |

### `class PhysicsOverlayLineSet`

A batch of world-space line segments for one body or constraint marker, ready to hand to `FilamentWireframeMesh.createLineSegments`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `name` | `String name` | Holds the `name` property or configuration state. |
| `isConstraint` | `bool isConstraint` | Holds the `isConstraint` property or configuration state. |
| `isSelected` | `bool isSelected` | Holds the `isSelected` property or configuration state. |
| `dimmed` | `bool dimmed` | Rendered dimmed because the body sits on a disabled-collision pair. |
| `filled` | `bool filled` | Solid-bodies mode asks the 2D painter for a translucent fill. |
| `positions` | `List<double> positions` | Flat xyz triples in world space. |
| `lineIndices` | `List<int> lineIndices` | Index pairs into [positions] / 3. |

---

[Previous: Particle editor](particle.md) | [Up: Sub-editors](index.md) | [Next: Project settings](project-settings.md)

[Türkçe](../../../tr/lumina_ui/sub-editors/animation.md)

# Animation editor

The animation editor: the sub-editor view and view model, the playback controller, bone track and keyframe models, notifies, curves and blend space data, the dope sheet and the retarget dialog. File paths are relative to the `lumina_ui/` package directory.

**On this page:**

- [Authoring an Animation Sequence from scratch](#authoring-an-animation-sequence-from-scratch)
- [`lib/ui/features/sub_editors/views/animation_sub_editor.dart`](#libuifeaturessub_editorsviewsanimation_sub_editordart)
- [`lib/ui/features/sub_editors/view_models/animation_editor_view_model.dart`](#libuifeaturessub_editorsview_modelsanimation_editor_view_modeldart)
- [`lib/ui/features/sub_editors/models/anim_bone_track_info.dart`](#libuifeaturessub_editorsmodelsanim_bone_track_infodart)
- [`lib/ui/features/sub_editors/models/anim_notify_and_curves.dart`](#libuifeaturessub_editorsmodelsanim_notify_and_curvesdart)
- [`lib/ui/features/sub_editors/models/animation_playback_controller.dart`](#libuifeaturessub_editorsmodelsanimation_playback_controllerdart)
- [`lib/ui/features/sub_editors/models/selected_keyframe_details.dart`](#libuifeaturessub_editorsmodelsselected_keyframe_detailsdart)
- [`lib/ui/features/sub_editors/widgets/animation_dope_sheet_widget.dart`](#libuifeaturessub_editorswidgetsanimation_dope_sheet_widgetdart)
- [`lib/ui/features/sub_editors/widgets/animation_retarget_modal.dart`](#libuifeaturessub_editorswidgetsanimation_retarget_modaldart)
- [`lib/ui/features/sub_editors/services/anim_graph_asset_service.dart`](#libuifeaturessub_editorsservicesanim_graph_asset_servicedart)
- [`lib/ui/features/sub_editors/services/anim_preview_scene.dart`](#libuifeaturessub_editorsservicesanim_preview_scenedart)
- [`lib/ui/features/sub_editors/view_models/anim_blueprint_editor_view_model.dart`](#libuifeaturessub_editorsview_modelsanim_blueprint_editor_view_modeldart)
- [`lib/ui/features/sub_editors/view_models/blend_space_editor_view_model.dart`](#libuifeaturessub_editorsview_modelsblend_space_editor_view_modeldart)
- [`lib/ui/features/sub_editors/views/anim_blueprint/anim_blueprint_sub_editor.dart`](#libuifeaturessub_editorsviewsanim_blueprintanim_blueprint_sub_editordart)
- [`lib/ui/features/sub_editors/views/anim_blueprint/anim_graph_view.dart`](#libuifeaturessub_editorsviewsanim_blueprintanim_graph_viewdart)
- [`lib/ui/features/sub_editors/views/anim_blueprint/anim_preview_editor.dart`](#libuifeaturessub_editorsviewsanim_blueprintanim_preview_editordart)
- [`lib/ui/features/sub_editors/views/anim_blueprint/create_anim_asset_dialog.dart`](#libuifeaturessub_editorsviewsanim_blueprintcreate_anim_asset_dialogdart)
- [`lib/ui/features/sub_editors/views/anim_blueprint/state_machine_graph.dart`](#libuifeaturessub_editorsviewsanim_blueprintstate_machine_graphdart)
- [`lib/ui/features/sub_editors/views/anim_blueprint/state_pose_editor.dart`](#libuifeaturessub_editorsviewsanim_blueprintstate_pose_editordart)
- [`lib/ui/features/sub_editors/views/blend_space/blend_space_grid.dart`](#libuifeaturessub_editorsviewsblend_spaceblend_space_griddart)
- [`lib/ui/features/sub_editors/views/blend_space/blend_space_sub_editor.dart`](#libuifeaturessub_editorsviewsblend_spaceblend_space_sub_editordart)
- [`lib/ui/features/sub_editors/widgets/anim_blueprint_retarget_modal.dart`](#libuifeaturessub_editorswidgetsanim_blueprint_retarget_modaldart)

## Authoring an Animation Sequence from scratch

- **Create**: Content Browser ▸ New Asset ▸ **Animation → Animation Sequence** (or MCP `create_asset {type: "animation", target_mesh, length_frames | length_seconds, frame_rate}`) asks for the target skeletal mesh, a name, the length in frames or seconds and the frame rate (30 by default). The sequence is a glTF animation added to the mesh's GLB (the skeleton root's rest pose keyed at frame 0) with an animation `.lmas` under `contents/animations/<Mesh>/` that points at it (lumina's `AuthoredAnimationStore`), and opens in the Animation editor.
- **Pose**: the Bone Tracks tab lists the skeleton (filter by name); clicking a bone there, or near a joint in the viewport, selects it. The viewport draws the skeleton over the mesh (selected bone in amber) and puts the transform gizmo on the bone: **rotate** (E, the default) for every bone, **translate** (W) for the skeleton root and the pelvis, **scale** (R); World / Local and the snap settings in the viewport's tool cluster. The pose shows live through the same joint transforms and skinning the playback uses (`SubEditor3DViewport.jointLocalPose`).
- **Auto Key** (toolbar, on by default, remembered in `editor_preferences.json` as `animationAutoKey`): releasing the gizmo keys the bone's changed channels (rotation as a quaternion, translation, scale) at the playhead frame, as one undo step, updating a key already there. With Auto Key off a change is a preview that the next seek or play reverts; **Key** (K) keys the pending changes, or the selected bone's whole transform.
- **Keys**: the dope sheet lists every keyed bone with its keys; click selects (Shift adds), drag moves the selected keys by whole frames, Delete removes them. A selected bone key opens the Key panel: frame (editable, moves the key), local rotation in degrees about the bone's X / Y / Z, translation, scale (each field keys that channel at the frame) and the interpolation of the bone's channels (Linear / Step / Cubic — glTF interpolates per channel; Cubic eases in and out of every key). Ctrl+Z / Ctrl+Y undo and redo every authored edit.
- **Save** writes the clip into the mesh's GLB, so Anim Blueprints, Blend Spaces, montages, Play and the generated game play it by name, unchanged; reopening the asset restores the keys exactly from its `authored_clip`.
- **Pose tab** (right panel, authored sequences; every edit one undo step, written as ordinary keys of the same glTF clip):
  - **Onion skin** (viewport HUD toggle, O): ghost skeletons of the nearest keyed poses before (orange) and after (blue) the playhead, the before / after counts (0–5) and opacity in the tab; the nearest ghost is drawn at the opacity, farther ones fainter.
  - **Pose**: Copy Pose (the whole pose at the playhead, Ctrl+C) or Copy Selected (the selected bone and the bones below it), Paste (Ctrl+V) and Paste Mirrored (Ctrl+Shift+V: each copied bone's pose onto its left/right partner, a bone on the plane onto itself), Mirror Selected (the selected limb onto the other side). A paste keys the channels that differ from the pose shown or are already animated; a pasted or mirrored selection keys every rotation, so a later key elsewhere cannot move that frame.
  - **Mirror pairs**: detected from the bone names (`_l`/`_r`, `Left`/`Right`, `.L`/`.R`, `l_`/`r_`) with the plane from the rest pose (lumina's `SkeletonMirror`); pairs set by hand are kept per skeleton in the pose library.
  - **Loop**: the seam (the largest turn between frame 0 and the last frame), Copy First → Last (every keyed channel), Match Selected to First, and "Show frame 0 as a ghost" to see the seam at the end of the clip.
  - **Pose library**: Save Pose (whole pose, or only the selected bone and its children) under a name, Apply with a weight (0–100 %, a blend from the pose shown towards the saved one), rename (to the name field), delete. Stored per skeletal mesh in `contents/animations/<Mesh>/PoseLibrary.lmas`; opening that file shows its mesh and lists the poses.
  - **Two-bone IK** (I): the arm and leg chains found on the skeleton; in IK mode the viewport's translate gizmo moves the chain's end target (yellow diamond) or, with Drag Pole, its pole (magenta ring, a dashed line to the elbow / knee). Releasing keys the chain's rotations (upper, lower and the end, which keeps its world orientation) at the playhead with Auto Key; off, it stays a preview. **Pin & Bake** keeps the hand or foot where it is at the first frame of a range, solving and keying the chain at both ends and every keyed frame between (lumina's `TwoBoneIkSolver`). The saved clip stays forward kinematics.
  - **Root motion**: Extract from Pelvis moves the pelvis's horizontal travel onto the skeleton root (the pelvis keeps its vertical motion, its world path unchanged) and turns Enable Root Motion on; Zero Root puts it back and turns it off. Draw Path: viewport clicks on the floor add points; Key Path keys the root through them, spread evenly over the clip, and turns Enable Root Motion on.
  - Additive layers are not part of the tab: glTF stores none, and a layer baked into the clip could not be edited as one again.
- **Undo, delete, restore**: creating a sequence is one undo step. Undoing it, deleting the asset (to the project trash) or trashing its folder takes its clip out of the mesh's GLB and `animation_clips` with the `.lmas` (the clip's data leaves the GLB); redo, undoing the delete or restoring the trash entry puts the clip back at its place in the mesh's clip list. Other sequences on the same mesh keep their clips.

## Pose Search Database editor

Opened for a `poseSearchDatabase` asset (Content Browser → New → Animation → Pose Search Database, for a skeletal mesh): `lib/ui/features/sub_editors/views/pose_search/` (`PoseSearchDatabaseSubEditor`, `PoseSearchClipTree`, `PoseSearchDatabaseClipList`, `PoseSearchDetailsPanel`) over `PoseSearchDatabaseEditorViewModel` and `PoseSearchDatabaseService`. Three resizable panels: the target mesh's clips as a tree grouped by movement (click adds or removes a clip, "+" adds a group, the filter and **Add matching** add every clip containing the text, **Add all clips** without a filter), the database's clips with Loop / Mirror / Use and the feature cache's state and statistics, and the Details (per clip tags, cost bias and search range; search interval, biases, blend time, excluded end; the schema: sample rate, trajectory times and weights, root bone, mesh yaw offset, bones with position / velocity weights). **Build** saves, then builds the `.posedb` on a background isolate and reports frames, features, build time and a timed sample search; every edit is one undo step. The Animation Blueprint editor's state pose editor has a **Motion Matching** kind with the database picker (databases made for the ABP's target mesh), blend time, pose / trajectory weights, required tags, orient to movement and debug draw. See [Motion matching](../../lumina/motion-matching.md).

## `lib/ui/features/sub_editors/views/animation_sub_editor.dart`

### `class AnimationSubEditor`

`AnimationSubEditor`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `assetName` | `String assetName` | Holds the `assetName` property or configuration state. |
| `assetPath` | `String? assetPath` | Holds the `assetPath` property or configuration state. |
| `asset` | `RealAssetInfo? asset` | Holds the `asset` property or configuration state. |
| `viewModel` | `AnimationEditorViewModel? viewModel` | Holds the `viewModel` property or configuration state. |
| `onClose` | `VoidCallback? onClose` | Holds the `onClose` property or configuration state. |
| `onBind` | `SubEditorBindCallback? onBind` | Holds the `onBind` property or configuration state. |
| `createState` | `State<AnimationSubEditor> createState() => _AnimationSubEditorState()` | Creates, configures, and returns a new `State` instance or associated GPU resource. |

### `class _AnimationSubEditorState`

`_AnimationSubEditorState`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `initState` | `void initState()` | Executes `initState` operation. |
| `dispose` | `void dispose()` | Releases native FFI pointers, event subscriptions, and allocated memory. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

### `class _BlendSpaceCanvasPainter`

`_BlendSpaceCanvasPainter`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `blendSpace` | `BlendSpaceData blendSpace` | Holds the `blendSpace` property or configuration state. |
| `paramX` | `double paramX` | Holds the `paramX` property or configuration state. |
| `paramY` | `double paramY` | Holds the `paramY` property or configuration state. |
| `weights` | `Map<String, double> weights` | Holds the `weights` property or configuration state. |
| `paint` | `void paint(Canvas canvas, Size size)` | Executes `paint` operation. |
| `shouldRepaint` | `bool shouldRepaint(covariant _BlendSpaceCanvasPainter oldDelegate)` | Executes `shouldRepaint` operation. |

## `lib/ui/features/sub_editors/view_models/animation_editor_view_model.dart`

### `class AnimationEditorViewModel`

`AnimationEditorViewModel`: ChangeNotifier ViewModel managing UI state, user actions, and data binding for the view.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `assetPath` | `String assetPath` | Holds the `assetPath` property or configuration state. |
| `initialAsset` | `LuminaAsset? initialAsset` | Holds the `initialAsset` property or configuration state. |
| `isLoading` | `bool get isLoading` | Checks current state or capability and returns a boolean value. |
| `hasError` | `bool get hasError` | Checks current state or capability and returns a boolean value. |
| `isDirty` | `bool get isDirty` | Checks current state or capability and returns a boolean value. |
| `asset` | `LuminaAsset? get asset` | Getter accessor returning the current value of `asset`. |
| `glbMesh` | `GlbMeshData? get glbMesh` | Getter accessor returning the current value of `glbMesh`. |
| `previewMeshAsset` | `RealAssetInfo? get previewMeshAsset` | Getter accessor returning the current value of `previewMeshAsset`. |
| `previewMeshPath` | `String? get previewMeshPath` | Getter accessor returning the current value of `previewMeshPath`. |
| `availableSkeletalMeshes` | `List<RealAssetInfo> get availableSkeletalMeshes` | Getter accessor returning the current value of `availableSkeletalMeshes`. |
| `timelineZoom` | `double get timelineZoom` | Getter accessor returning the current value of `timelineZoom`. |
| `snapToFrames` | `bool get snapToFrames` | Getter accessor returning the current value of `snapToFrames`. |
| `snapInterval` | `int get snapInterval` | Getter accessor returning the current value of `snapInterval`. |
| `selectedKeyframeIds` | `Set<String> get selectedKeyframeIds` | Selects the target actor or asset. |
| `clips` | `List<GlbAnimationClip> get clips` | Getter accessor returning the current value of `clips`. |
| `selectedClip` | `int get selectedClip` | Selects the target actor or asset. |
| `isPlaying` | `bool get isPlaying` | Checks current state or capability and returns a boolean value. |
| `isLooping` | `bool get isLooping` | Checks current state or capability and returns a boolean value. |
| `speed` | `double get speed` | Getter accessor returning the current value of `speed`. |
| `rateScale` | `double get rateScale` | Getter accessor returning the current value of `rateScale`. |
| `positionSeconds` | `double get positionSeconds` | Getter accessor returning the current value of `positionSeconds`. |
| `frameRate` | `double get frameRate` | Getter accessor returning the current value of `frameRate`. |
| `interpolation` | `String get interpolation` | Getter accessor returning the current value of `interpolation`. |
| `additiveType` | `String get additiveType` | Appends a new item to the collection or scene. |
| `notifies` | `List<EditorAnimNotify> get notifies` | Getter accessor returning the current value of `notifies`. |
| `curves` | `List<AnimCurveData> get curves` | Getter accessor returning the current value of `curves`. |
| `blendSpace` | `BlendSpaceData get blendSpace` | Getter accessor returning the current value of `blendSpace`. |
| `blendParamX` | `double get blendParamX` | Getter accessor returning the current value of `blendParamX`. |
| `blendParamY` | `double get blendParamY` | Getter accessor returning the current value of `blendParamY`. |
| `enableRootMotion` | `bool get enableRootMotion` | Getter accessor returning the current value of `enableRootMotion`. |
| `recentlyFiredNotifies` | `List<EditorAnimNotify> get recentlyFiredNotifies` | Getter accessor returning the current value of `recentlyFiredNotifies`. |
| `fileBasename` | `String get fileBasename` | Getter accessor returning the current value of `fileBasename`. |
| `activeClip` | `GlbAnimationClip? get activeClip` | Getter accessor returning the current value of `activeClip`. |
| `duration` | `double get duration` | Getter accessor returning the current value of `duration`. |
| `totalFrames` | `int get totalFrames` | Getter accessor returning the current value of `totalFrames`. |
| `activeClipKeyframes` | `List<double> get activeClipKeyframes` | Getter accessor returning the current value of `activeClipKeyframes`. |
| `allBoneTrackInfos` | `List<AnimBoneTrackInfo> get allBoneTrackInfos` | Getter accessor returning the current value of `allBoneTrackInfos`. |
| `boneSearchQuery` | `String get boneSearchQuery` | Getter accessor returning the current value of `boneSearchQuery`. |
| `setBoneSearchQuery` | `void setBoneSearchQuery(String query)` | Updates the `BoneSearchQuery` parameter and applies changes to the system. |
| `animatedBoneTracks` | `List<AnimBoneTrackInfo> get animatedBoneTracks` | Returns only bones that actively vary (position/rotation/scale) over time. |
| `filteredAnimatedBoneTracks` | `List<AnimBoneTrackInfo> get filteredAnimatedBoneTracks` | Returns animated bones matching the search filter query. |
| `boneKeyframeTracks` | `Map<String, List<double>> get boneKeyframeTracks` | Getter accessor returning the current value of `boneKeyframeTracks`. |
| `currentFrame` | `int get currentFrame` | Getter accessor returning the current value of `currentFrame`. |
| `formattedTime` | `String get formattedTime` | Getter accessor returning the current value of `formattedTime`. |
| `formattedTotalTime` | `String get formattedTotalTime` | Getter accessor returning the current value of `formattedTotalTime`. |
| `activeAnimatedNodeIndices` | `Set<int> get activeAnimatedNodeIndices` | Getter accessor returning the current value of `activeAnimatedNodeIndices`. |
| `allBones` | `List<GlbNode> get allBones` | Getter accessor returning the current value of `allBones`. |
| `rootBones` | `List<GlbNode> get rootBones` | Getter accessor returning the current value of `rootBones`. |
| `currentBlendWeights` | `Map<String, double> get currentBlendWeights` | Getter accessor returning the current value of `currentBlendWeights`. |
| `dominantSample` | `EditorBlendSample? get dominantSample` | Getter accessor returning the current value of `dominantSample`. |
| `load` | `Future<void> load()` | Loads data from disk or memory buffer into the engine. |
| `play` | `void play()` | Executes `play` operation. |
| `pause` | `void pause()` | Executes `pause` operation. |
| `togglePlay` | `void togglePlay()` | Toggles the target feature or visibility on/off. |
| `setLooping` | `void setLooping(bool loop)` | Updates the `Looping` parameter and applies changes to the system. |
| `setSpeed` | `void setSpeed(double s)` | Updates the `Speed` parameter and applies changes to the system. |
| `setRateScale` | `void setRateScale(double r)` | Updates the `RateScale` parameter and applies changes to the system. |
| `setInterpolation` | `void setInterpolation(String interp)` | Updates the `Interpolation` parameter and applies changes to the system. |
| `setAdditiveType` | `void setAdditiveType(String type)` | Updates the `AdditiveType` parameter and applies changes to the system. |
| `setFrameRate` | `void setFrameRate(double fps)` | Updates the `FrameRate` parameter and applies changes to the system. |
| `selectClip` | `void selectClip(int index)` | Selects the target actor or asset. |
| `stepFrame` | `void stepFrame(int delta)` | Executes `stepFrame` operation. |
| `seek` | `void seek(double timeSeconds)` | Executes `seek` operation. |
| `tickDelta` | `void tickDelta(double dt)` | Executes `tickDelta` operation. |
| `moveNotify` | `void moveNotify(String id, double newTime)` | Executes `moveNotify` operation. |
| `renameNotify` | `void renameNotify(String id, String newName)` | Executes `renameNotify` operation. |
| `removeNotify` | `void removeNotify(String id)` | Releases and safely disposes the specified `Notify` resource. |
| `addCurve` | `void addCurve(String name)` | Appends a new item to the collection or scene. |
| `removeCurve` | `void removeCurve(String name)` | Releases and safely disposes the specified `Curve` resource. |
| `addCurveKey` | `void addCurveKey(String curveName, double time, double value)` | Appends a new item to the collection or scene. |
| `removeCurveKey` | `void removeCurveKey(String curveName, int keyIndex)` | Releases and safely disposes the specified `CurveKey` resource. |
| `evaluateCurve` | `double evaluateCurve(String curveName)` | Executes `evaluateCurve` operation. |
| `setTimelineZoom` | `void setTimelineZoom(double z)` | Updates the `TimelineZoom` parameter and applies changes to the system. |
| `setSnap` | `void setSnap(bool snap)` | Updates the `Snap` parameter and applies changes to the system. |
| `setSnapInterval` | `void setSnapInterval(int interval)` | Updates the `SnapInterval` parameter and applies changes to the system. |
| `clearKeyframeSelection` | `void clearKeyframeSelection()` | Clears all elements from the collection or buffer. |
| `selectedKeyframeDetails` | `SelectedKeyframeDetails? get selectedKeyframeDetails` | Selects the target actor or asset. |
| `updateSelectedCurveKeyframeValue` | `void updateSelectedCurveKeyframeValue(double newValue)` | Updates the current state or data values. |
| `deleteSelectedKeys` | `void deleteSelectedKeys()` | Releases and safely disposes the specified `SelectedKeys` resource. |
| `setBlendSpace2D` | `void setBlendSpace2D(bool is2D)` | Updates the `BlendSpace2D` parameter and applies changes to the system. |
| `setBlendParam` | `void setBlendParam(double x, double y)` | Updates the `BlendParam` parameter and applies changes to the system. |
| `addBlendSample` | `void addBlendSample(String assetPath, String assetName, double x, double y)` | Appends a new item to the collection or scene. |
| `moveBlendSample` | `void moveBlendSample(String id, double x, double y)` | Executes `moveBlendSample` operation. |
| `removeBlendSample` | `void removeBlendSample(String id)` | Releases and safely disposes the specified `BlendSample` resource. |
| `toggleRootMotion` | `void toggleRootMotion()` | Toggles the target feature or visibility on/off. |
| `setRootMotion` | `void setRootMotion(bool enable)` | Updates the `RootMotion` parameter and applies changes to the system. |
| `formatTimecode` | `static String formatTimecode(double seconds)` | Executes `formatTimecode` operation. |
| `save` | `Future<bool> save()` | Serializes and writes the current state or asset to disk. |
| `dispose` | `void dispose()` | Releases native FFI pointers, event subscriptions, and allocated memory. |

**Authoring members (sequences created in the editor):**

| Member | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `isAuthored` / `authoredClip` / `skeleton` | `bool get isAuthored` · `AuthoredAnimationClip? get authoredClip` · `GlbSkeleton? get skeleton` | A sequence authored here (its keys in the asset's `authored_clip`), its clip and the mesh's skeleton. |
| `transactions` / `undo` / `redo` | `TransactionManager transactions` | The editor's undo stack for authored edits (Ctrl+Z / Ctrl+Y). |
| `autoKey` / `setAutoKey` / `onAutoKeyChanged` | `bool get autoKey` · `void setAutoKey(bool value)` | Auto Key: a released gizmo keys the changed channels at the playhead; told to the preferences. |
| `selectedBone` / `selectBone` | `String? get selectedBone` · `void selectBone(String? bone)` | The bone the gizmo sits on. |
| `playheadFrame` | `int get playheadFrame` | The frame keys are written at. |
| `currentNodePose` / `jointLocalPose` | `Map<int, BoneTrs> get currentNodePose` · `Map<String, List<double>>? get jointLocalPose` | The pose shown: the clip at the playhead with pending previews over it; per joint for the viewport. |
| `boneLocal` / `boneWorldPosition` / `canTranslateBone` | `BoneTrs? boneLocal(String bone)` · `Vector3? boneWorldPosition(String bone)` · `bool canTranslateBone(String bone)` | A bone's local transform / world position now; only the root and pelvis translate. |
| `gizmoTarget` / `pickBone` | `SubEditorGizmoTarget? gizmoTarget(GizmoMode mode)` · `String? pickBone(Vector3 origin, Vector3 direction)` | The gizmo's target (authoring frame) and the joint nearest a click ray. |
| `beginBonePose` / `previewGizmoDelta` / `previewBonePose` / `endBonePose` / `cancelBonePose` | `void beginBonePose(String bone)` · `void previewGizmoDelta(SubEditorGizmoDelta delta)` · … | The gizmo drag: a world delta turned into the bone's local transform (`R_local' = R_parent⁻¹ · Δ · R_parent · R_local`); release keys it with Auto Key on, Esc restores it. |
| `hasPendingPreview` / `keyPendingOrSelected` | `bool get hasPendingPreview` · `void keyPendingOrSelected()` | The Key button: keys pending previews, or the selected bone's whole transform. |
| `parseBoneKeyId` / `boneKeyId` / `selectedBoneKeys` | `AnimBoneKeyRef? parseBoneKeyId(String id)` · `String boneKeyId(String bone, int frame)` | Dope sheet bone key ids (`bone_<bone>[_<sub-track>]_<time>`) ↔ bone and frame. |
| `setBoneKey` / `moveSelectedBoneKeysBy` / `moveSelectedBoneKeysToFrame` / `deleteSelectedBoneKeys` / `setBoneInterpolation` | `void setBoneKey(String bone, int frame, {List<double>? translation, rotation, scale})` · … | Key panel and dope sheet edits, each one undo step. |
| `authoredGlbClip` / `authoredBoneTracks` / `authoredKeyDetails` | `GlbAnimationClip? get authoredGlbClip` · … | The authored clip as the dope sheet and Key panel read clips. |

## `lib/ui/features/sub_editors/models/anim_bone_track_info.dart`

### `class AnimBoneTrackInfo`

Metadata and active animation range for a bone track.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `boneName` | `String boneName` | Holds the `boneName` property or configuration state. |
| `nodeIndex` | `int nodeIndex` | Holds the `nodeIndex` property or configuration state. |
| `keyframeTimes` | `List<double> keyframeTimes` | Holds the `keyframeTimes` property or configuration state. |
| `startTime` | `double startTime` | Holds the `startTime` property or configuration state. |
| `endTime` | `double endTime` | Holds the `endTime` property or configuration state. |
| `hasVariation` | `bool hasVariation` | Holds the `hasVariation` property or configuration state. |
| `channels` | `List<GlbAnimationChannel> channels` | Holds the `channels` property or configuration state. |
| `duration` | `double get duration` | Getter accessor returning the current value of `duration`. |
| `subTracks` | `List<AnimBoneSubTrack> get subTracks` | Generates the individual component sub-tracks (Location X/Y/Z, Rotation P/Y/R, Scale X/Y/Z) with per-component active variation detection and filtered keyframe lists. |

### `class _ComponentVarInfo`

`_ComponentVarInfo`: Actor component providing spatial 3D transform, visual mesh, lighting, or movement capability.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `hasVariation` | `bool hasVariation` | Holds the `hasVariation` property or configuration state. |
| `startTime` | `double startTime` | Holds the `startTime` property or configuration state. |
| `endTime` | `double endTime` | Holds the `endTime` property or configuration state. |
| `keyframeTimes` | `List<double> keyframeTimes` | Holds the `keyframeTimes` property or configuration state. |
| `staticValue` | `double staticValue` | Holds the `staticValue` property or configuration state. |

### `class AnimBoneSubTrack`

An individual component sub-track (e.g. Location.X, Rotation.Pitch, Scale.Z)

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `id` | `String id` | Holds the `id` property or configuration state. |
| `label` | `String label` | Holds the `label` property or configuration state. |
| `group` | `String group` | Holds the `group` property or configuration state. |
| `color` | `Color color` | Holds the `color` property or configuration state. |
| `keyframeTimes` | `List<double> keyframeTimes` | Holds the `keyframeTimes` property or configuration state. |
| `startTime` | `double startTime` | Holds the `startTime` property or configuration state. |
| `endTime` | `double endTime` | Holds the `endTime` property or configuration state. |
| `hasVariation` | `bool hasVariation` | Holds the `hasVariation` property or configuration state. |
| `staticValue` | `double staticValue` | Holds the `staticValue` property or configuration state. |

## `lib/ui/features/sub_editors/models/anim_notify_and_curves.dart`

### `enum AnimNotifyType`

`AnimNotifyType`: Enumeration listing system options and state constants.

### `class EditorAnimNotify`

`EditorAnimNotify`: `class` representing the data model or functionality of the module.

**Constructors:**
- `EditorAnimNotify.fromJson(Map<String, dynamic> json)`: Initializes `EditorAnimNotify.fromJson(Map<String, dynamic> json)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `id` | `String id` | Holds the `id` property or configuration state. |
| `name` | `String name` | Holds the `name` property or configuration state. |
| `time` | `double time` | Holds the `time` property or configuration state. |
| `type` | `AnimNotifyType type` | Holds the `type` property or configuration state. |
| `isSyncMarker` | `bool isSyncMarker` | Holds the `isSyncMarker` property or configuration state. |
| `toJson` | `Map<String, dynamic> toJson()` | Serializes the object to a JSON map. |

### `class AnimCurveKey`

`AnimCurveKey`: `class` representing the data model or functionality of the module.

**Constructors:**
- `AnimCurveKey.fromJson(Map<String, dynamic> json)`: Initializes `AnimCurveKey.fromJson(Map<String, dynamic> json)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `time` | `double time` | Holds the `time` property or configuration state. |
| `value` | `double value` | Holds the `value` property or configuration state. |
| `toJson` | `Map<String, dynamic> toJson()` | Serializes the object to a JSON map. |

### `class AnimCurveData`

`AnimCurveData`: `class` representing the data model or functionality of the module.

**Constructors:**
- `AnimCurveData.fromJson(Map<String, dynamic> json)`: Initializes `AnimCurveData.fromJson(Map<String, dynamic> json)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `name` | `String name` | Holds the `name` property or configuration state. |
| `keys` | `List<AnimCurveKey> keys` | Holds the `keys` property or configuration state. |
| `sortKeys` | `void sortKeys()` | Executes `sortKeys` operation. |
| `evaluate` | `double evaluate(double t)` | Executes `evaluate` operation. |
| `toJson` | `Map<String, dynamic> toJson()` | Serializes the object to a JSON map. |

### `class BlendSpaceAxis`

`BlendSpaceAxis`: `class` representing the data model or functionality of the module.

**Constructors:**
- `BlendSpaceAxis.fromJson(Map<String, dynamic> json)`: Initializes `BlendSpaceAxis.fromJson(Map<String, dynamic> json)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `name` | `String name` | Holds the `name` property or configuration state. |
| `min` | `double min` | Holds the `min` property or configuration state. |
| `max` | `double max` | Holds the `max` property or configuration state. |
| `toJson` | `Map<String, dynamic> toJson()` | Serializes the object to a JSON map. |

### `class EditorBlendSample`

`EditorBlendSample`: `class` representing the data model or functionality of the module.

**Constructors:**
- `EditorBlendSample.fromJson(Map<String, dynamic> json)`: Initializes `EditorBlendSample.fromJson(Map<String, dynamic> json)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `id` | `String id` | Holds the `id` property or configuration state. |
| `assetPath` | `String assetPath` | Holds the `assetPath` property or configuration state. |
| `assetName` | `String assetName` | Holds the `assetName` property or configuration state. |
| `x` | `double x` | Holds the `x` property or configuration state. |
| `y` | `double y` | Holds the `y` property or configuration state. |
| `toJson` | `Map<String, dynamic> toJson()` | Serializes the object to a JSON map. |

### `class BlendSpaceData`

`BlendSpaceData`: `class` representing the data model or functionality of the module.

**Constructors:**
- `BlendSpaceData.fromJson(Map<String, dynamic> json)`: Initializes `BlendSpaceData.fromJson(Map<String, dynamic> json)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `is2D` | `bool is2D` | Holds the `is2D` property or configuration state. |
| `xAxis` | `BlendSpaceAxis xAxis` | Holds the `xAxis` property or configuration state. |
| `yAxis` | `BlendSpaceAxis yAxis` | Holds the `yAxis` property or configuration state. |
| `samples` | `List<EditorBlendSample> samples` | Holds the `samples` property or configuration state. |
| `computeWeights` | `Map<String, double> computeWeights(double x, double y)` | Executes `computeWeights` operation. |
| `toJson` | `Map<String, dynamic> toJson()` | Serializes the object to a JSON map. |

## `lib/ui/features/sub_editors/models/animation_playback_controller.dart`

### `class AnimationPlaybackController`

Manages and broadcasts frame-by-frame animation playback requests to the 3D viewport.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `callLog` | `List<String> callLog` | Holds the `callLog` property or configuration state. |
| `clipIndex` | `int get clipIndex` | Getter accessor returning the current value of `clipIndex`. |
| `timeSeconds` | `double get timeSeconds` | Getter accessor returning the current value of `timeSeconds`. |
| `recordCall` | `void recordCall(String methodName)` | Executes `recordCall` operation. |

## `lib/ui/features/sub_editors/models/selected_keyframe_details.dart`

### `class SelectedKeyframeDetails`

Detailed properties of a selected keyframe (Bone Transform, Curve Float, or Notify).

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `keyId` | `String keyId` | Holds the `keyId` property or configuration state. |
| `type` | `String type` | Holds the `type` property or configuration state. |
| `targetName` | `String targetName` | Holds the `targetName` property or configuration state. |
| `time` | `double time` | Holds the `time` property or configuration state. |
| `frame` | `int frame` | Holds the `frame` property or configuration state. |
| `location` | `List<double>? location` | Holds the `location` property or configuration state. |
| `rotationEuler` | `List<double>? rotationEuler` | Holds the `rotationEuler` property or configuration state. |
| `rotationQuat` | `List<double>? rotationQuat` | Holds the `rotationQuat` property or configuration state. |
| `scale` | `List<double>? scale` | Holds the `scale` property or configuration state. |
| `interpolation` | `String? interpolation` | Holds the `interpolation` property or configuration state. |
| `curveValue` | `double? curveValue` | Holds the `curveValue` property or configuration state. |
| `notifyType` | `String? notifyType` | Holds the `notifyType` property or configuration state. |
| `subTrackLabel` | `String? subTrackLabel` | Holds the `subTrackLabel` property or configuration state. |
| `quaternionToEuler` | `static List<double> quaternionToEuler(double x, double y, double z, doub...` | Executes `quaternionToEuler` operation. |

## `lib/ui/features/sub_editors/widgets/animation_dope_sheet_widget.dart`

### `class AnimationDopeSheetWidget`

Multi-track dope sheet and animation track strip editor.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `viewModel` | `AnimationEditorViewModel viewModel` | Holds the `viewModel` property or configuration state. |
| `createState` | `State<AnimationDopeSheetWidget> createState() => _AnimationDopeSheetWidg...` | Creates, configures, and returns a new `State` instance or associated GPU resource. |

### `class _AnimationDopeSheetWidgetState`

`_AnimationDopeSheetWidgetState`: shadcn_flutter UI component rendering interface elements and listening to interactions.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `initState` | `void initState()` | Executes `initState` operation. |
| `dispose` | `void dispose()` | Releases native FFI pointers, event subscriptions, and allocated memory. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

### `class _DopeSheetRulerPainter`

`_DopeSheetRulerPainter`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `duration` | `double duration` | Holds the `duration` property or configuration state. |
| `fps` | `double fps` | Holds the `fps` property or configuration state. |
| `currentPosition` | `double currentPosition` | Holds the `currentPosition` property or configuration state. |
| `paint` | `void paint(Canvas canvas, Size size)` | Executes `paint` operation. |
| `shouldRepaint` | `bool shouldRepaint(covariant _DopeSheetRulerPainter oldDelegate)` | Executes `shouldRepaint` operation. |

### `class _DopeSheetGridPainter`

`_DopeSheetGridPainter`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `duration` | `double duration` | Holds the `duration` property or configuration state. |
| `fps` | `double fps` | Holds the `fps` property or configuration state. |
| `paint` | `void paint(Canvas canvas, Size size)` | Executes `paint` operation. |
| `shouldRepaint` | `bool shouldRepaint(covariant _DopeSheetGridPainter oldDelegate)` | Executes `shouldRepaint` operation. |

## `lib/ui/features/sub_editors/widgets/animation_retarget_modal.dart`

### `class AnimationRetargetModal`

Modal dialog for retargeting an animation sequence to a different skeletal mesh character.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `viewModel` | `AnimationEditorViewModel viewModel` | Holds the `viewModel` property or configuration state. |
| `sourceAssetName` | `String sourceAssetName` | Holds the `sourceAssetName` property or configuration state. |
| `createState` | `State<AnimationRetargetModal> createState() => _AnimationRetargetModalSt...` | Creates, configures, and returns a new `State` instance or associated GPU resource. |

### `class _AnimationRetargetModalState`

`_AnimationRetargetModalState`: shadcn_flutter UI component rendering interface elements and listening to interactions.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `initState` | `void initState()` | Executes `initState` operation. |
| `dispose` | `void dispose()` | Releases native FFI pointers, event subscriptions, and allocated memory. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

## `lib/ui/features/sub_editors/services/anim_graph_asset_service.dart`

### `typedef AnimPreviewMeshSource`

A skeletal mesh as a preview component loads it: a GLB path and, for a mesh whose GLB lives inside its `.lmas` payload, a provider handing those bytes over.

### `abstract final class AnimGraphAssetService`

Animation Blueprint and Blend Space assets on disk: lumina's anim graph documents as JSON in the `.lmas` `raw_payload`, next to the mesh's clips under `contents/animations/<Mesh>/`, with the target mesh kept in the metadata and as an asset reference.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `targetMeshKey` | `static const String targetMeshKey` |  |
| `baseName` | `static String baseName(String path)` |  |
| `skeletalMeshes` | `static List<RealAssetInfo> skeletalMeshes(String projectDir)` | The project's skeletal meshes. |
| `meshSource` | `static AnimPreviewMeshSource? meshSource(String projectDir, String meshRelPath)` | Where [meshRelPath]'s GLB is: the `.entity.glb` companion (template content) or the `.lmas` payload (an import). Null when neither exists. |
| `clipNames` | `static List<String> clipNames(String projectDir, String meshRelPath)` | The animation clips stored in [meshRelPath]'s GLB, in gltfio order. |
| `withPrefix` | `static String withPrefix(String name, String prefix)` |  |
| `newAnimBlueprint` | `static LuminaAnimBlueprintDocument newAnimBlueprint(String meshRelPath, List<String> clips)` | What a new Animation Blueprint for [meshRelPath] starts as: an EventGraph with Blueprint Update Animation, and an AnimGraph whose Output Pose is fed by the Locomotion state machine with one Idle state playing the mesh's first clip. |
| `newBlendSpace` | `static LuminaBlendSpaceDocument newBlendSpace()` | A new 2D Blend Space: Direction (−180…180°) × Speed (0…500 cm/s). |
| `createAnimBlueprint` | `static String createAnimBlueprint(String projectDir, {required String name, required String meshRelPath})` | Creates `ABP_<name>.lmas` for [meshRelPath] and returns its project relative path. |
| `createBlendSpace` | `static String createBlendSpace(String projectDir, {required String name, required String meshRelPath, LuminaBl...` | Creates `BS_<name>.lmas` for [meshRelPath] and returns its path; [document] is its content (a new 2D space by default). |
| `createAnimationSequence` | `static String createAnimationSequence(String projectDir, {required String name, required String meshRelPath, required int lengthFrames, double frameRate = 30.0, String? folder})` | Creates an empty Animation Sequence for [meshRelPath] (the skeleton root's rest pose keyed at frame 0), stored as a clip in the mesh's GLB; returns its project relative path. |
| `readAnimBlueprint` | `static LuminaAnimBlueprintDocument? readAnimBlueprint(String projectDir, String relPath)` |  |
| `readBlendSpace` | `static LuminaBlendSpaceDocument? readBlendSpace(String projectDir, String relPath)` |  |
| `blendSpaceTarget` | `static String? blendSpaceTarget(String projectDir, String relPath)` | The mesh a Blend Space was made for (its metadata), or null. |
| `writeAnimBlueprint` | `static void writeAnimBlueprint(String projectDir, String relPath, LuminaAnimBlueprintDocument doc)` |  |
| `writeBlendSpace` | `static void writeBlendSpace(String projectDir, String relPath, LuminaBlendSpaceDocument doc, {required String...` |  |
| `blendSpacesFor` | `static List<String> blendSpacesFor(String projectDir, String meshRelPath)` | Blend Spaces made for [meshRelPath]: named in their metadata, or (for a Blend Space written without one) whose samples all play clips the mesh has. |
| `projectDirOf` | `static String? projectDirOf(String path)` | Walks up from [path] to the project directory (the folder holding the `.lmproject`, or `contents/`). |

## `lib/ui/features/sub_editors/services/anim_preview_scene.dart`

### `class AnimPreviewOwnerMovement`

The Anim Preview's stand-in pawn movement: Get Velocity and Is Falling answer what the Anim Preview Editor's owner controls say; nothing is simulated.

**Constructors:**

- `AnimPreviewOwnerMovement()`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `standInVelocity` | `final Vector3 standInVelocity` | Velocity in runtime space (Y up), cm/s. |
| `standInFalling` | `bool standInFalling` |  |

### `class AnimPreviewScene`

A skeletal mesh on a stand-in owner, played either by an Animation Blueprint instance or by clip requests, in a lumina world: the editor world a sub-editor viewport hands over (the mesh renders through flutter_filament), or a headless world of its own (no native context: clips are requested but nothing draws — widget tests, and the editor before its viewport is up).

Editor worlds do not tick gameplay, so the scene drives the owner itself: the Animation Blueprint instance first (it picks the pose), then the mesh (it applies it), then a zero-length world tick for render prep.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `movement` | `final AnimPreviewOwnerMovement movement` |  |
| `beforeTick` | `void Function(double dt)? beforeTick` | Called before each tick (write overrides into the instance). |
| `afterTick` | `void Function()? afterTick` | Called after each tick (repaint the highlighted state). |
| `tickSeconds` | `static const double tickSeconds` |  |
| `world` | `LuminaWorld? get world` |  |
| `isAttached` | `bool get isAttached` |  |
| `hasNativeWorld` | `bool get hasNativeWorld` |  |
| `mesh` | `LuminaAnimatedMeshComponent? get mesh` |  |
| `animInstance` | `LuminaAnimBlueprintInstance? get animInstance` |  |
| `owner` | `LuminaActor? get owner` |  |
| `currentClip` | `String? get currentClip` | The clip the mesh plays now (the fade target while cross-fading). |
| `attach` | `void attach(LuminaWorld world, {bool startTicker = true})` | Binds the viewport's editor world and starts ticking at 60 Hz. |
| `attachHeadless` | `void attachHeadless({bool startTicker = true})` | A world of its own with no native context. |
| `stopTicker` | `void stopTicker()` |  |
| `setMesh` | `void setMesh(String? path, {LuminaAssetProvider? provider})` | Shows the mesh at [path] (a GLB file, or an `.lmas` read through [provider]); the same path again keeps the loaded mesh. |
| `setAnimInstance` | `void setAnimInstance(LuminaAnimBlueprintInstance? instance, {Map<String, Object?> carryVariables = const {}})` | Plays [instance] on the mesh from now on (null: none). The previous instance is removed; [carryVariables] seeds the new one's variables. |
| `crossFadeTo` | `void crossFadeTo(String clip, {double duration = 0.2})` | Blends the mesh to [clip] (a Blend Space preview's nearest sample). |
| `advance` | `void advance(double dt)` | One preview frame of [dt] seconds. |
| `detach` | `void detach()` | Releases the world: unregisters what the scene added, or cleans up its own headless world. |

## `lib/ui/features/sub_editors/view_models/anim_blueprint_editor_view_model.dart`

### `enum AnimGraphView`

Which graph of an Animation Blueprint the editor shows.

**Values:**

- `animGraph`
- `stateMachine`
- `state`
- `transition`
- `eventGraph`

### `class AnimGraphLocation`

A place in the Animation Blueprint's graph hierarchy: the AnimGraph, a state machine, a state's pose, a transition's rule, or the EventGraph.

**Constructors:**

- `const AnimGraphLocation.animGraph()`
- `const AnimGraphLocation.eventGraph()`
- `const AnimGraphLocation.stateMachine(String machine)`
- `const AnimGraphLocation.state(String machine, String state)`
- `const AnimGraphLocation.transition(String machine, String transition)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `view` | `final AnimGraphView view` |  |
| `machine` | `final String? machine` |  |
| `state` | `final String? state` |  |
| `transition` | `final String? transition` |  |

### `class AnimCompileRow`

One Compiler Results row, with the graph its node lives in.

**Constructors:**

- `const AnimCompileRow(this.diagnostic, this.location, this.nodeTitle)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `diagnostic` | `final LuminaBlueprintDiagnostic diagnostic` |  |
| `location` | `final AnimGraphLocation? location` |  |
| `nodeTitle` | `final String? nodeTitle` |  |

### `class AnimBlueprintEditorViewModel`

The Animation Blueprint editor's state: lumina's [LuminaAnimBlueprintDocument] from the ANIM_BLUEPRINT `.lmas`, its AnimGraph / state machine / transition rules / update event graph, compile through lumina's validator and generator, and a live preview of the Blueprint on its target mesh. Every edit is one undo step.

**Constructors:**

- `AnimBlueprintEditorViewModel({required super.assetPath})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `ruleAccepts` | `static bool ruleAccepts(LuminaBlueprintNodeSpec spec)` | A transition rule takes pure nodes and its Result only. |
| `isDirty` | `bool get isDirty` |  |
| `revision` | `int get revision` |  |
| `blendSpacePaths` | `List<String> get blendSpacePaths` |  |
| `clipAssets` | `List<RealAssetInfo> get clipAssets` | [clips] as assets for the shared asset picker: the project's animation asset of that name (with its thumbnail) where one exists, otherwise the clip inside the target mesh (`<mesh>#<clip>`). |
| `blendSpaceAssets` | `List<RealAssetInfo> get blendSpaceAssets` | [blendSpacePaths] as assets for the shared asset picker. |
| `selectedState` | `String? get selectedState` |  |
| `selectedTransition` | `String? get selectedTransition` |  |
| `selectedVariable` | `String? get selectedVariable` |  |
| `compileStatus` | `BlueprintCompileStatus get compileStatus` |  |
| `compileRows` | `List<AnimCompileRow> get compileRows` |  |
| `generatedCode` | `String get generatedCode` |  |
| `availableSkeletalMeshes` | `List<RealAssetInfo> get availableSkeletalMeshes` | Available skeletal meshes in the project for target mesh selection. |
| `undo` | `void undo()` |  |
| `redo` | `void redo()` |  |
| `className` | `static String className(String rawName)` | The Dart class the Blueprint [rawName] compiles into ([dartTypeName]: `ABP_Character` → `AbpCharacter`). |

## `lib/ui/features/sub_editors/view_models/blend_space_editor_view_model.dart`

### `class BlendSpaceEditorViewModel`

The Blend Space editor's state: lumina's [LuminaBlendSpaceDocument] from the BLEND_SPACE `.lmas`, axes, samples dropped from the target mesh's clips and snapped to the grid divisions, and a preview point whose nearest sample the preview mesh plays (lumina's nearest-sample-plus-crossfade, never a weighted blend). Every edit is one undo step.

**Constructors:**

- `BlendSpaceEditorViewModel({required this.assetPath})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `assetPath` | `final String assetPath` |  |
| `projectDir` | `late final String? projectDir` |  |
| `transactions` | `final TransactionManager transactions` |  |
| `preview` | `final AnimPreviewScene preview` |  |
| `name` | `String get name` |  |
| `relativePath` | `String get relativePath` |  |
| `document` | `LuminaBlendSpaceDocument get document` |  |
| `targetMesh` | `String get targetMesh` |  |
| `clips` | `List<String> get clips` |  |
| `divisionsX` | `int get divisionsX` |  |
| `divisionsY` | `int get divisionsY` |  |
| `selectedSample` | `int? get selectedSample` |  |
| `previewPoint` | `(double, double) get previewPoint` |  |
| `is2D` | `bool get is2D` |  |
| `isDirty` | `bool get isDirty` |  |
| `nearestSample` | `LuminaBlendSpaceSample? get nearestSample` | The sample the preview point picks. |
| `previewClip` | `String? get previewClip` | The clip the preview mesh plays now. |
| `load` | `Future<void> load() async` |  |
| `save` | `Future<bool> save() async` |  |
| `undo` | `void undo()` |  |
| `redo` | `void redo()` |  |
| `setAxis` | `bool setAxis(int index, {String? name, double? min, double? max})` |  |
| `setDivisions` | `void setDivisions({int? x, int? y})` |  |
| `setDimensions` | `bool setDimensions(int count)` | Makes the Blend Space one-dimensional (Direction only) or adds a second axis. |
| `addSample` | `int? addSample(String clip, double x, double y)` | Drops [clip] at ([x], [y]), snapped to the grid divisions. |
| `selectSample` | `void selectSample(int? index)` |  |
| `beginSampleDrag` | `void beginSampleDrag(int index)` |  |
| `dragSample` | `void dragSample(int index, double x, double y)` | Moves sample [index] to ([x], [y]) snapped to the divisions (live, during a drag). |
| `endSampleDrag` | `void endSampleDrag()` |  |
| `setSample` | `bool setSample(int index, {String? clip, double? x, double? y})` |  |
| `removeSample` | `bool removeSample(int index)` |  |
| `setPreviewPoint` | `void setPreviewPoint(double x, double y)` | Moves the preview point (not snapped); the preview mesh blends to the nearest sample. |
| `attachPreviewWorld` | `void attachPreviewWorld(LuminaWorld world)` |  |
| `detachPreviewWorld` | `void detachPreviewWorld(LuminaWorld world)` |  |
| `startHeadlessPreview` | `void startHeadlessPreview({bool ticker = true})` |  |

## `lib/ui/features/sub_editors/views/anim_blueprint/anim_blueprint_sub_editor.dart`

### `class AnimBlueprintSubEditor`

The Animation Blueprint editor: preview viewport and My Blueprint on the left, the AnimGraph / state machine / state pose / transition rule / EventGraph in the centre with breadcrumbs, Details on the right, Compiler Results and the Anim Preview Editor at the bottom.

**Constructors:**

- `const AnimBlueprintSubEditor({super.key, required this.assetName, required this.assetPath, this.onClose, this.onBind, this.viewModel, this.onAssetsModified, thi...`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `assetName` | `final String assetName` |  |
| `assetPath` | `final String assetPath` |  |
| `onClose` | `final VoidCallback? onClose` |  |
| `onBind` | `final SubEditorBindCallback? onBind` |  |
| `viewModel` | `final AnimBlueprintEditorViewModel? viewModel` |  |
| `onAssetsModified` | `final VoidCallback? onAssetsModified` |  |
| `showPreviewViewport` | `final bool showPreviewViewport` | False shows the preview's state as text instead of mounting the Filament viewport; the preview still runs, in a world without a renderer (widget tests, where a native viewport never settles). |

### `class AnimBlueprintSubEditorState`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `viewModel` | `AnimBlueprintEditorViewModel get viewModel` |  |

## `lib/ui/features/sub_editors/views/anim_blueprint/anim_graph_view.dart`

### `class AnimGraphOutputView`

The AnimGraph: the state machine node feeding Output Pose, as lumina's anim blueprint document defines it (the first state machine drives the pose). Double-clicking the state machine opens it.

**Constructors:**

- `const AnimGraphOutputView({super.key, required this.viewModel})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `viewModel` | `final AnimBlueprintEditorViewModel viewModel` |  |

## `lib/ui/features/sub_editors/views/anim_blueprint/anim_preview_editor.dart`

### `class AnimPreviewEditorPanel`

The Anim Preview Editor: the stand-in owner's speed, direction and falling state (what Get Velocity / Is Falling return to the update graph), and per-variable overrides that pin a variable (the update graph stops writing it) while the preview runs.

**Constructors:**

- `const AnimPreviewEditorPanel({super.key, required this.viewModel})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `viewModel` | `final AnimBlueprintEditorViewModel viewModel` |  |

## `lib/ui/features/sub_editors/views/anim_blueprint/create_anim_asset_dialog.dart`

### `enum AnimAssetKind`

Which animation asset the Content Browser's Animation menu creates.

**Values:**

- `animBlueprint`
- `blendSpace`

### `class CreateAnimAssetDialog`

**Constructors:**

- `const CreateAnimAssetDialog({super.key, required this.projectDir, required this.kind, required this.onCreated, required this.onCancel,})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `projectDir` | `final String projectDir` |  |
| `kind` | `final AnimAssetKind kind` |  |
| `onCreated` | `final ValueChanged<String> onCreated` |  |
| `onCancel` | `final VoidCallback onCancel` |  |

**Top-level functions and variables:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `showCreateAnimAssetDialog` | `void showCreateAnimAssetDialog(BuildContext context, {required String projectDir, required AnimAssetKind kind,...` | Content Browser → Animation → Animation Blueprint / Blend Space: pick the target skeletal mesh and a name, then write `ABP_*.lmas` / `BS_*.lmas` next to the mesh's clips. [onCreated] gets the new asset's project relative path. |

## `lib/ui/features/sub_editors/views/anim_blueprint/state_machine_graph.dart`

### `abstract final class AnimStateLayout`

Geometry of the state machine canvas, shared by the painter, the widgets and hit-testing.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `stateSize` | `static const Size stateSize` |  |
| `entrySize` | `static const Size entrySize` |  |
| `stateRect` | `static Rect stateRect(LuminaAnimState s)` |  |
| `entryRect` | `static Rect entryRect(LuminaAnimStateMachine m)` |  |
| `arrow` | `static (Offset, Offset)? arrow(LuminaAnimStateMachine m, LuminaAnimTransition t)` | Where the arrow of [t] runs: centre to centre, shifted sideways when the opposite transition exists so both arrows show, clipped to the rects. |

### `class AnimStateMachineGraph`

A state machine graph (e.g. a "Locomotion" graph): states, the Entry node, transition arrows with rule markers, the preview's active state highlighted. Right-click adds a state; dragging from a state's handle to another state adds a transition; double-clicking a state opens its pose and a marker opens its rule.

**Constructors:**

- `const AnimStateMachineGraph({super.key, required this.viewModel})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `viewModel` | `final AnimBlueprintEditorViewModel viewModel` |  |

### `class AnimStateMachineGraphState`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `frameAll` | `void frameAll()` | Centres the Entry node and every state in the view (on open, and F). |
| `vm` | `AnimBlueprintEditorViewModel get vm` |  |
| `toScreen` | `Offset toScreen(Offset canvas)` |  |
| `stateCenter` | `Offset? stateCenter(String name)` | Screen (widget-local) centre of state [name], for tests and drags. |
| `handleCenter` | `Offset? handleCenter(String name)` | Screen position of state [name]'s transition handle. |
| `transitionMarker` | `Offset? transitionMarker(String id)` | Screen position of transition [id]'s rule marker. |

**Top-level functions and variables:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `showRenameState` | `void showRenameState(BuildContext context, AnimBlueprintEditorViewModel vm, String name)` | Renames a state from a dialog. |

## `lib/ui/features/sub_editors/views/anim_blueprint/state_pose_editor.dart`

### `class AnimStatePoseEditor`

A state's pose (a state graph, reduced to what lumina's anim blueprints play): Play Clip from the target mesh's clips, a Blend Space Player on Blend Spaces made for this mesh sampled by X / Y variables with a play rate from a speed variable, or Hold Pose.

**Constructors:**

- `const AnimStatePoseEditor({super.key, required this.viewModel, required this.state})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `viewModel` | `final AnimBlueprintEditorViewModel viewModel` |  |
| `state` | `final String state` |  |
| `shortName` | `static String shortName(String? path)` |  |

## `lib/ui/features/sub_editors/views/blend_space/blend_space_grid.dart`

### `class BlendSpaceClipDrag`

What a clip row carries when dragged onto a Blend Space grid.

**Constructors:**

- `const BlendSpaceClipDrag(this.clip)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `clip` | `final String clip` |  |

### `class BlendSpaceGridGeometry`

Axis values ↔ grid pixels for a Blend Space of one or two axes.

**Constructors:**

- `const BlendSpaceGridGeometry(this.document, this.size)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `padding` | `static const EdgeInsets padding` |  |
| `document` | `final LuminaBlendSpaceDocument document` |  |
| `size` | `final Size size` |  |
| `is2D` | `bool get is2D` |  |
| `area` | `Rect get area` |  |
| `xAxis` | `LuminaBlendSpaceAxis get xAxis` |  |
| `yAxis` | `LuminaBlendSpaceAxis get yAxis` |  |
| `toPixel` | `Offset toPixel(double x, double y)` |  |
| `toValue` | `(double, double) toValue(Offset pixel)` |  |

### `class BlendSpaceGrid`

The Blend Space grid (the Blend Space editor canvas): axes with their divisions, the samples (dragged clips) and the preview point. The sample nearest the preview point is highlighted: lumina plays the nearest sample with a crossfade, not a weighted blend.

**Constructors:**

- `const BlendSpaceGrid({super.key, required this.document, required this.point, this.highlightClip, this.readOnly = false, this.divisionsX = 4, this.divisionsY =...`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `document` | `final LuminaBlendSpaceDocument document` |  |
| `point` | `final (double, double) point` |  |
| `highlightClip` | `final String? highlightClip` |  |
| `readOnly` | `final bool readOnly` |  |
| `divisionsX` | `final int divisionsX` |  |
| `divisionsY` | `final int divisionsY` |  |
| `selectedSample` | `final int? selectedSample` |  |
| `onDropClip` | `final void Function(String clip, double x, double y)? onDropClip` |  |
| `onSelectSample` | `final ValueChanged<int>? onSelectSample` |  |
| `onSampleDragStart` | `final ValueChanged<int>? onSampleDragStart` |  |
| `onSampleDrag` | `final void Function(int index, double x, double y)? onSampleDrag` |  |
| `onSampleDragEnd` | `final VoidCallback? onSampleDragEnd` |  |
| `onPointChanged` | `final void Function(double x, double y)? onPointChanged` |  |

### `class BlendSpaceGridState`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `geometry` | `BlendSpaceGridGeometry get geometry` |  |
| `globalOf` | `Offset globalOf(double x, double y)` | Global position of axis values ([x], [y]) on screen, for tests and drags. |

## `lib/ui/features/sub_editors/views/blend_space/blend_space_sub_editor.dart`

### `class BlendSpaceSubEditor`

The Blend Space editor: the target mesh's clips on the left to drag onto the grid, the grid with samples snapped to its divisions and a preview point, the preview viewport playing the nearest sample, and axis / sample details.

**Constructors:**

- `const BlendSpaceSubEditor({super.key, required this.assetName, required this.assetPath, this.onClose, this.onBind, this.viewModel, this.showPreviewViewport = tr...`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `assetName` | `final String assetName` |  |
| `assetPath` | `final String assetPath` |  |
| `onClose` | `final VoidCallback? onClose` |  |
| `onBind` | `final SubEditorBindCallback? onBind` |  |
| `viewModel` | `final BlendSpaceEditorViewModel? viewModel` |  |
| `showPreviewViewport` | `final bool showPreviewViewport` | False shows the preview's clip as text instead of mounting the Filament viewport (see AnimBlueprintSubEditor.showPreviewViewport). |

### `class BlendSpaceSubEditorState`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `viewModel` | `BlendSpaceEditorViewModel get viewModel` |  |

## `lib/ui/features/sub_editors/widgets/anim_blueprint_retarget_modal.dart`

### `class AnimBlueprintRetargetModal`

Modal dialog for retargeting an Animation Blueprint and all its linked animation clips and Blend Spaces onto another skeletal mesh character.

**Constructors:**

- `const AnimBlueprintRetargetModal({super.key, required this.viewModel, this.initialTargetMeshPath, this.onCompleted,})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `viewModel` | `final AnimBlueprintEditorViewModel viewModel` |  |
| `initialTargetMeshPath` | `final String? initialTargetMeshPath` |  |
| `onCompleted` | `final VoidCallback? onCompleted` |  |

---

[Previous: Sub-editor framework](framework.md) | [Up: Sub-editors](index.md) | [Next: Audio editor](audio.md)

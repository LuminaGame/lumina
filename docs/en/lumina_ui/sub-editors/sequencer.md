[Türkçe](../../../tr/lumina_ui/sub-editors/sequencer.md)

# Sequencer

The Sequencer for cinematics: the timeline, track tree and curve editor, the sequencer view model, the evaluator that samples tracks, and movie rendering through an offscreen frame source. File paths are relative to the `lumina_ui/` package directory.

**On this page:**

- [`lib/ui/features/sub_editors/views/sequencer/curve_editor_widget.dart`](#libuifeaturessub_editorsviewssequencercurve_editor_widgetdart)
- [`lib/ui/features/sub_editors/views/sequencer/level_viewport.dart`](#libuifeaturessub_editorsviewssequencerlevel_viewportdart)
- [`lib/ui/features/sub_editors/models/sequencer_viewport_camera.dart`](#libuifeaturessub_editorsmodelssequencer_viewport_cameradart)
- [`lib/ui/features/sub_editors/views/sequencer/render_dialog.dart`](#libuifeaturessub_editorsviewssequencerrender_dialogdart)
- [`lib/ui/features/sub_editors/views/sequencer/sequencer_sub_editor.dart`](#libuifeaturessub_editorsviewssequencersequencer_sub_editordart)
- [`lib/ui/features/sub_editors/views/sequencer/timeline_widget.dart`](#libuifeaturessub_editorsviewssequencertimeline_widgetdart)
- [`lib/ui/features/sub_editors/views/sequencer/track_tree_widget.dart`](#libuifeaturessub_editorsviewssequencertrack_tree_widgetdart)
- [`lib/ui/features/sub_editors/view_models/sequencer_view_model.dart`](#libuifeaturessub_editorsview_modelssequencer_view_modeldart)
- [`lib/ui/features/sub_editors/services/sequencer_evaluator.dart`](#libuifeaturessub_editorsservicessequencer_evaluatordart)
- [`lib/ui/features/sub_editors/services/sequencer_movie_render_service.dart`](#libuifeaturessub_editorsservicessequencer_movie_render_servicedart)
- [`lib/ui/features/sub_editors/services/sequencer_offscreen_frame_source.dart`](#libuifeaturessub_editorsservicessequencer_offscreen_frame_sourcedart)

## `lib/ui/features/sub_editors/views/sequencer/curve_editor_widget.dart`

### `class CurveView`

The visible window of the curve canvas in data space (frames × values).

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `minFrame` | `double minFrame` | Holds the `minFrame` property or configuration state. |
| `maxFrame` | `double maxFrame` | Holds the `maxFrame` property or configuration state. |
| `minValue` | `double minValue` | Holds the `minValue` property or configuration state. |
| `maxValue` | `double maxValue` | Holds the `maxValue` property or configuration state. |
| `frameSpan` | `double get frameSpan` | Getter accessor returning the current value of `frameSpan`. |
| `valueSpan` | `double get valueSpan` | Getter accessor returning the current value of `valueSpan`. |
| `frameToX` | `double frameToX(double frame, Size size)` | Executes `frameToX` operation. |
| `valueToY` | `double valueToY(double value, Size size)` | Executes `valueToY` operation. |
| `xToFrame` | `double xToFrame(double x, Size size)` | Executes `xToFrame` operation. |
| `yToValue` | `double yToValue(double y, Size size)` | Executes `yToValue` operation. |
| `toString` | `String toString()` | Executes `toString` operation. |

### `class CurveChannelRef`

A channel shown on the canvas together with the track that owns it.

**Constructors:**
- `CurveChannelRef(this.track, this.channel)`: Initializes `CurveChannelRef(this.track, this.channel)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `track` | `SequencerTrack track` | Holds the `track` property or configuration state. |
| `channel` | `SequencerChannel channel` | Holds the `channel` property or configuration state. |
| `id` | `String get id` | Getter accessor returning the current value of `id`. |

### `class SequencerCurvePainter`

`SequencerCurvePainter`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `channels` | `List<CurveChannelRef> channels` | Holds the `channels` property or configuration state. |
| `view` | `CurveView view` | Holds the `view` property or configuration state. |
| `selectedKeys` | `Set<SequencerKeyRef> selectedKeys` | Holds the `selectedKeys` property or configuration state. |
| `primaryKey` | `SequencerKeyRef? primaryKey` | Holds the `primaryKey` property or configuration state. |
| `playheadFrame` | `double playheadFrame` | Holds the `playheadFrame` property or configuration state. |
| `boxSelect` | `Rect? boxSelect` | Holds the `boxSelect` property or configuration state. |
| `lengthFrames` | `int lengthFrames` | Holds the `lengthFrames` property or configuration state. |
| `channelColor` | `static Color channelColor(String name)` | X → red, Y → green, Z → blue; other channels cycle a distinct palette. |
| `keyScreenPosition` | `static Offset keyScreenPosition(SequencerKey key, CurveView view, Size s...` | Setter mutator assigning a new value to `keyScreenPosition`. |
| `Offset` | `Offset(view.frameToX(key.frame.toDouble(), size), view.valueToY(key.valu...` | Executes `Offset` operation. |
| `slopeFromHandle` | `static double slopeFromHandle(Offset keyPos, Offset handlePos, int direc...` | Converts a dragged handle position back into a tangent slope (value units per frame); [direction] is +1 for the out handle, -1 for in. |
| `niceStep` | `static double niceStep(double span, int targetDivisions)` | Executes `niceStep` operation. |
| `paint` | `void paint(Canvas canvas, Size size)` | Executes `paint` operation. |
| `shouldRepaint` | `bool shouldRepaint(covariant SequencerCurvePainter oldDelegate)` | Executes `shouldRepaint` operation. |

### `class SequencerCurveEditorWidget`

The Curves tab: every keyed channel as a coloured curve with draggable keys and bezier tangent handles, box-select, pan/zoom/fit, per-channel visibility and a key context menu.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `viewModel` | `SequencerViewModel viewModel` | Holds the `viewModel` property or configuration state. |
| `initialView` | `CurveView? initialView` | Holds the `initialView` property or configuration state. |
| `createState` | `State<SequencerCurveEditorWidget> createState() => SequencerCurveEditorW...` | Creates, configures, and returns a new `State` instance or associated GPU resource. |

### `enum _DragMode`

`_DragMode`: Enumeration listing system options and state constants.

### `class SequencerCurveEditorWidgetState`

`SequencerCurveEditorWidgetState`: shadcn_flutter UI component rendering interface elements and listening to interactions.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `vm` | `SequencerViewModel get vm` | Getter accessor returning the current value of `vm`. |
| `view` | `CurveView get view` | Getter accessor returning the current value of `view`. |
| `dispose` | `void dispose()` | Releases native FFI pointers, event subscriptions, and allocated memory. |
| `isChannelVisible` | `bool isChannelVisible(String trackId, String channelName) => !_hiddenCha...` | Checks current state or capability and returns a boolean value. |
| `setChannelVisible` | `void setChannelVisible(String trackId, String channelName, bool visible)` | Updates the `ChannelVisible` parameter and applies changes to the system. |
| `fitAll` | `void fitAll()` | Executes `fitAll` operation. |
| `panBy` | `void panBy(double dFrames, double dValues)` | Executes `panBy` operation. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

## `lib/ui/features/sub_editors/views/sequencer/level_viewport.dart`

### `class SequencerLevelViewport`

The Sequencer's 3D Viewport tab: the level the sequence drives, drawn from the level viewport's own Filament scene (`EditorViewModel.levelScene`) by a second view, so every scrub and playback frame the Sequencer writes onto the level's actors shows here the same frame. It looks through an editor camera of its own (starting where the level viewport's camera is: drag to orbit, middle-drag or Shift+drag to pan, wheel to dolly, right button + W/A/S/D/Q/E to fly, F or the frame button to frame the animated actors) or, locked from the camera menu, through a camera actor bound in the sequence (its location, its +Y forward and the field of view of its camera component, 60° without one) inside a 16:9 film gate, with a `PILOTING <name>` badge. Exposure follows the level viewport's camera. A sequence opened without a level editor shows a notice instead.

| Member | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `editorViewModel` | `EditorViewModel editorViewModel` | The level editor whose scene and actors the view draws. |
| `sequencer` | `SequencerViewModel sequencer` | The sequence; its tracks name the camera actors the view can lock to. |
| `filmAspect` | `static const double filmAspect = 16 / 9` | The film gate a locked camera frames. |

### `class SequencerLevelViewportState`

| Member | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `drawsLevelScene` | `bool get drawsLevelScene` | Whether the view renders the level viewport's scene right now (false before the level viewport is up and after it is gone; the view then draws its own empty scene). |
| `cameraCandidates` | `List<EditorActorNode> get cameraCandidates` | The level's camera actors the sequence animates: what the camera menu offers. |
| `lockedCameraId` | `String? get lockedCameraId` | The camera actor the view looks through, or null for the editor camera. |
| `lockToCamera` | `void lockToCamera(String? actorId)` | Looks through `actorId`, or through the editor camera again when null. |
| `focusAnimatedActors` | `void focusAnimatedActors()` | Frames every bound actor that is not a camera (the whole level when the sequence binds none). |
| `editorCamera` | `SequencerViewportCamera get editorCamera` | The editor camera's navigation state. |
| `viewForTest` / `cameraForTest` | `FilamentView?` / `FilamentCamera?` | The Filament view and camera, for tests. |

## `lib/ui/features/sub_editors/models/sequencer_viewport_camera.dart`

### `class SequencerViewPose`

Where a view of the level looks from: `eye`, `forward` and `up` in runtime axes (Y up, centimetres) and the vertical `fovDegrees`.

### `class SequencerViewportCamera`

The Sequencer viewport's editor camera: the level viewport's orbit camera (yaw, pitch and distance around a stored Z-up target) with its own pose, so navigating the Sequencer's view leaves the level viewport's camera where it was.

| Member | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `fromEditor` | `factory SequencerViewportCamera.fromEditor(EditorViewModel vm)` | Starts where the level viewport's camera is. |
| `editorPose` | `SequencerViewPose editorPose({double fovDegrees = 45.0})` | The pose the editor camera looks through. |
| `orbit` / `pan` / `dolly` | `void orbit(double dx, double dy)` … | Tumbles around the target, slides in the view plane, moves toward or away from the target. |
| `fly` | `void fly({required int forward, required int right, required int up, required double dt, double speed = 400.0})` | Flies along the gaze, the horizontal right and the world up. |
| `focus` | `void focus({required List<double> center, required double radius})` | Frames a sphere (stored axes, centimetres). |
| `lockedPose` | `static SequencerViewPose lockedPose(EditorActorNode camera)` | The pose a camera lock looks through: the actor's location along its forward (+Y stored, rotated by its rotation), with its camera component's `fieldOfView` / `fov`. |
| `cameraFovDegrees` | `static double cameraFovDegrees(EditorActorNode camera)` | The camera actor's vertical field of view; 60° (the runtime camera component's default) without a camera component. |
| `isCamera` | `static bool isCamera(EditorActorNode actor)` | Whether the view can look through the actor. |

## `lib/ui/features/sub_editors/views/sequencer/render_dialog.dart`

### `class _ResolutionPreset`

One entry of the resolution `Select`.

**Constructors:**
- `_ResolutionPreset(this.label, this.width, this.height)`: Initializes `_ResolutionPreset(this.label, this.width, this.height)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `label` | `String label` | Holds the `label` property or configuration state. |
| `width` | `int width` | Holds the `width` property or configuration state. |
| `height` | `int height` | Holds the `height` property or configuration state. |

### `class SequencerRenderDialog`

The Movie Render Queue dialog: configure an offscreen PNG-sequence export, then watch it run with a live progress bar, ETA and a working Cancel.  Honest scope — the only format this stack can write is a numbered PNG sequence (see [MovieRenderFormat]); no MP4/EXR options are offered because no encoder for them exists here.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `sequence` | `SequencerData sequence` | Holds the `sequence` property or configuration state. |
| `sequenceName` | `String sequenceName` | Holds the `sequenceName` property or configuration state. |
| `projectDirPath` | `String projectDirPath` | Holds the `projectDirPath` property or configuration state. |
| `defaultStartFrame` | `int defaultStartFrame` | Holds the `defaultStartFrame` property or configuration state. |
| `defaultEndFrame` | `int defaultEndFrame` | Holds the `defaultEndFrame` property or configuration state. |
| `engineAvailable` | `bool engineAvailable` | False when the native offscreen render capability is missing; the Start button is then disabled with the missing symbol named. |
| `now` | `DateTime? now` | Injected clock so the default output folder name is deterministic in tests. |
| `viewModel` | `SequencerViewModel? viewModel` | Live render state. When null the dialog is a pure form (widget tests). |
| `onCancelRender` | `VoidCallback? onCancelRender` | Holds the `onCancelRender` property or configuration state. |
| `onClose` | `VoidCallback? onClose` | Holds the `onClose` property or configuration state. |
| `createState` | `State<SequencerRenderDialog> createState() => _SequencerRenderDialogState()` | Creates, configures, and returns a new `State` instance or associated GPU resource. |

### `class _SequencerRenderDialogState`

`_SequencerRenderDialogState`: shadcn_flutter UI component rendering interface elements and listening to interactions.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `initState` | `void initState()` | Executes `initState` operation. |
| `dispose` | `void dispose()` | Releases native FFI pointers, event subscriptions, and allocated memory. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |
| `openFolder` | `static Future<void> openFolder(String path)` | Reveals the finished frame folder in the platform file manager. |

## `lib/ui/features/sub_editors/views/sequencer/sequencer_sub_editor.dart`

### `class SequencerSubEditor`

`SequencerSubEditor`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `assetName` | `String assetName` | Holds the `assetName` property or configuration state. |
| `assetPath` | `String? assetPath` | Holds the `assetPath` property or configuration state. |
| `asset` | `RealAssetInfo? asset` | Holds the `asset` property or configuration state. |
| `viewModel` | `SequencerViewModel? viewModel` | Holds the `viewModel` property or configuration state. |
| `levelActors` | `List<EditorActorNode>? levelActors` | Holds the `levelActors` property or configuration state. |
| `editorViewModel` | `EditorViewModel? editorViewModel` | The live level the cinematic drives. Playback and scrubbing write the evaluated samples onto its actors and notify it so the outliner, details and Filament viewport update the same frame; `stop`/close restore them. |
| `onClose` | `VoidCallback? onClose` | Holds the `onClose` property or configuration state. |
| `onBind` | `SubEditorBindCallback? onBind` | Holds the `onBind` property or configuration state. |
| `createState` | `State<SequencerSubEditor> createState() => _SequencerSubEditorState()` | Creates, configures, and returns a new `State` instance or associated GPU resource. |

### `class _SequencerSubEditorState`

`_SequencerSubEditorState`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `initState` | `void initState()` | Executes `initState` operation. |
| `dispose` | `void dispose()` | Releases native FFI pointers, event subscriptions, and allocated memory. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

## `lib/ui/features/sub_editors/views/sequencer/timeline_widget.dart`

### `class SequencerTimelineWidget`

`SequencerTimelineWidget`: shadcn_flutter UI component rendering interface elements and listening to interactions.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `viewModel` | `SequencerViewModel viewModel` | Holds the `viewModel` property or configuration state. |
| `createState` | `State<SequencerTimelineWidget> createState() => _SequencerTimelineWidget...` | Creates, configures, and returns a new `State` instance or associated GPU resource. |

### `class _SequencerTimelineWidgetState`

`_SequencerTimelineWidgetState`: shadcn_flutter UI component rendering interface elements and listening to interactions.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `dispose` | `void dispose()` | Releases native FFI pointers, event subscriptions, and allocated memory. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

### `enum SequencerRangeBracket`

Which playback-range bracket on the ruler a drag targets.

### `class SequencerTimelinePainter`

`SequencerTimelinePainter`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `tracks` | `List<SequencerTrack> tracks` | Holds the `tracks` property or configuration state. |
| `lengthFrames` | `int lengthFrames` | Holds the `lengthFrames` property or configuration state. |
| `playheadFrame` | `int playheadFrame` | Holds the `playheadFrame` property or configuration state. |
| `fps` | `int fps` | Holds the `fps` property or configuration state. |
| `rangeStart` | `int? rangeStart` | Playback range rendered as brackets on the ruler; frames outside it are shaded. Null keeps the whole sequence. |
| `rangeEnd` | `int? rangeEnd` | Holds the `rangeEnd` property or configuration state. |
| `paint` | `void paint(Canvas canvas, Size size)` | Executes `paint` operation. |
| `shouldRepaint` | `bool shouldRepaint(covariant SequencerTimelinePainter oldDelegate)` | Executes `shouldRepaint` operation. |

## `lib/ui/features/sub_editors/views/sequencer/track_tree_widget.dart`

### `class SequencerTrackTreeWidget`

`SequencerTrackTreeWidget`: shadcn_flutter UI component rendering interface elements and listening to interactions.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `viewModel` | `SequencerViewModel viewModel` | Holds the `viewModel` property or configuration state. |
| `levelActors` | `List<EditorActorNode>? levelActors` | Holds the `levelActors` property or configuration state. |
| `createState` | `State<SequencerTrackTreeWidget> createState() => _SequencerTrackTreeWidg...` | Creates, configures, and returns a new `State` instance or associated GPU resource. |

### `class _SequencerTrackTreeWidgetState`

`_SequencerTrackTreeWidgetState`: shadcn_flutter UI component rendering interface elements and listening to interactions.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

## `lib/ui/features/sub_editors/view_models/sequencer_view_model.dart`

### `enum SequencerTimeFormat`

How the transport bar's current-time readout is formatted.

### `class SequencerViewModel`

`SequencerViewModel`: ChangeNotifier ViewModel managing UI state, user actions, and data binding for the view.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `assetPath` | `String assetPath` | Holds the `assetPath` property or configuration state. |
| `initialAsset` | `LuminaAsset? initialAsset` | Holds the `initialAsset` property or configuration state. |
| `transactions` | `TransactionManager transactions` | Holds the `transactions` property or configuration state. |
| `isLoading` | `bool get isLoading` | Checks current state or capability and returns a boolean value. |
| `hasError` | `bool get hasError` | Checks current state or capability and returns a boolean value. |
| `isDirty` | `bool get isDirty` | Checks current state or capability and returns a boolean value. |
| `asset` | `LuminaAsset? get asset` | Getter accessor returning the current value of `asset`. |
| `data` | `SequencerData get data` | Getter accessor returning the current value of `data`. |
| `fps` | `int get fps` | Getter accessor returning the current value of `fps`. |
| `lengthFrames` | `int get lengthFrames` | Getter accessor returning the current value of `lengthFrames`. |
| `playheadFrame` | `int get playheadFrame` | Getter accessor returning the current value of `playheadFrame`. |
| `playheadFrame` | `playheadFrame(int frame) => scrubToFrame(frame)` | Executes `playheadFrame` operation. |
| `playheadPosition` | `double get playheadPosition` | Getter accessor returning the current value of `playheadPosition`. |
| `tracks` | `List<SequencerTrack> get tracks` | Getter accessor returning the current value of `tracks`. |
| `selectedTrackId` | `String? get selectedTrackId` | Selects the target actor or asset. |
| `selectedKey` | `SequencerKeyRef? get selectedKey` | Selects the target actor or asset. |
| `selectedKeys` | `Set<SequencerKeyRef> get selectedKeys` | Selects the target actor or asset. |
| `isPlaying` | `bool get isPlaying` | Checks current state or capability and returns a boolean value. |
| `isLooping` | `bool get isLooping` | Checks current state or capability and returns a boolean value. |
| `rangeStart` | `int get rangeStart` | Getter accessor returning the current value of `rangeStart`. |
| `rangeEnd` | `int get rangeEnd` | Getter accessor returning the current value of `rangeEnd`. |
| `timeFormat` | `SequencerTimeFormat get timeFormat` | Getter accessor returning the current value of `timeFormat`. |
| `hasLevelBinding` | `bool get hasLevelBinding` | Checks current state or capability and returns a boolean value. |
| `isPreviewingLevel` | `bool get isPreviewingLevel` | Checks current state or capability and returns a boolean value. |
| `timeReadout` | `String get timeReadout` | Current-time readout in the selected [timeFormat]. |
| `canUndo` | `bool get canUndo` | Getter accessor returning the current value of `canUndo`. |
| `canRedo` | `bool get canRedo` | Getter accessor returning the current value of `canRedo`. |
| `undo` | `void undo() => transactions.undo()` | Reverts the last executed editor operation. |
| `redo` | `void redo() => transactions.redo()` | Re-applies the last undone editor operation. |
| `fileBasename` | `String get fileBasename` | Getter accessor returning the current value of `fileBasename`. |
| `timecodeStr` | `String get timecodeStr` | Getter accessor returning the current value of `timecodeStr`. |
| `load` | `Future<void> load()` | Loads data from disk or memory buffer into the engine. |
| `scrubToFrame` | `void scrubToFrame(int frame)` | Moves the playhead and writes the sampled pose onto the live level immediately — no play required. |
| `setFps` | `void setFps(int newFps)` | Updates the `Fps` parameter and applies changes to the system. |
| `setLengthFrames` | `void setLengthFrames(int len)` | Updates the `LengthFrames` parameter and applies changes to the system. |
| `selectTrack` | `void selectTrack(String? trackId)` | Selects the target actor or asset. |
| `selectKey` | `void selectKey(String trackId, String channelName, int keyIndex)` | Selects the target actor or asset. |
| `selectKeys` | `void selectKeys(Iterable<SequencerKeyRef> keys)` | Box-select: replaces the selection with [keys]; the first becomes the primary [selectedKey] whose tangent handles are shown. |
| `isKeySelected` | `bool isKeySelected(String trackId, String channelName, int keyIndex)` | Checks current state or capability and returns a boolean value. |
| `clearKeySelection` | `void clearKeySelection()` | Clears all elements from the collection or buffer. |
| `deleteSelectedKeys` | `void deleteSelectedKeys()` | Releases and safely disposes the specified `SelectedKeys` resource. |
| `findTrack` | `SequencerTrack? findTrack(String trackId)` | Searches and retrieves matching items or actors. |
| `findChannel` | `SequencerChannel? findChannel(String trackId, String channelName)` | Searches and retrieves matching items or actors. |
| `deleteTrack` | `void deleteTrack(String trackId)` | Releases and safely disposes the specified `Track` resource. |
| `renameTrack` | `void renameTrack(String trackId, String newActorName)` | Executes `renameTrack` operation. |
| `moveKey` | `void moveKey(String trackId, String channelName, int keyIndex, int newFr...` | Executes `moveKey` operation. |
| `deleteKey` | `void deleteKey(String trackId, String channelName, int keyIndex)` | Releases and safely disposes the specified `Key` resource. |
| `setKeyInterpolation` | `void setKeyInterpolation(String trackId, String channelName, int keyInde...` | Updates the `KeyInterpolation` parameter and applies changes to the system. |
| `isActorMissing` | `bool isActorMissing(String actorId, Set<String> levelActorIds)` | Checks current state or capability and returns a boolean value. |
| `rebindActor` | `void rebindActor(String trackId, String newActorId, String newActorName)` | Executes `rebindActor` operation. |
| `isTangentBroken` | `bool isTangentBroken(String trackId, String channelName, int keyIndex)` | Checks current state or capability and returns a boolean value. |
| `setTangentBroken` | `void setTangentBroken(String trackId, String channelName, int keyIndex, ...` | Updates the `TangentBroken` parameter and applies changes to the system. |
| `beginCurveDrag` | `void beginCurveDrag(String label, String coalesceKey)` | Opens a coalesced transaction so a whole drag lands as one undo step. |
| `endCurveDrag` | `void endCurveDrag()` | Executes `endCurveDrag` operation. |
| `flattenTangents` | `void flattenTangents(String trackId, String channelName, int keyIndex)` | Executes `flattenTangents` operation. |
| `setKeyInterpolationCubicAuto` | `void setKeyInterpolationCubicAuto(String trackId, String channelName, in...` | `Cubic (Auto)`: cubic interpolation with Catmull-Rom tangents computed from the neighbours, in == out (unified handles). |
| `setKeyInterpolationCubicBroken` | `void setKeyInterpolationCubicBroken(String trackId, String channelName, ...` | `Cubic (Broken)`: cubic interpolation whose two handles move independently. |
| `restoreLevel` | `void restoreLevel()` | Puts every touched actor property back to its pre-preview value and forgets the snapshot. A cinematic preview never dirties the level: the writes bypass the transaction/dirty path entirely. |
| `attachTicker` | `void attachTicker(TickerProvider vsync)` | Drives playback from the widget's frame clock. Without a ticker (unit tests) advance the clock manually with [advanceClock]. |
| `detachTicker` | `void detachTicker()` | Drops the widget-owned ticker (the widget is going away while the view model may live on, e.g. when injected by a test or a tab session). |
| `play` | `void play()` | Executes `play` operation. |
| `pause` | `void pause()` | Executes `pause` operation. |
| `togglePlay` | `void togglePlay() => _isPlaying ? pause() : play()` | Toggles the target feature or visibility on/off. |
| `stop` | `void stop()` | Stops playback, returns the playhead to the range start and restores the actors' pre-preview state. |
| `advanceClock` | `void advanceClock(double dt)` | Advances playback by [dt] seconds at the sequence fps, honouring the playback range and loop mode. Fractional frames accumulate; only the displayed frame is rounded. |
| `goToFirstFrame` | `void goToFirstFrame() => scrubToFrame(_rangeStart)` | Executes `goToFirstFrame` operation. |
| `nextKeyframe` | `void nextKeyframe()` | Executes `nextKeyframe` operation. |
| `previousKeyframe` | `void previousKeyframe()` | Executes `previousKeyframe` operation. |
| `setLooping` | `void setLooping(bool loop)` | Updates the `Looping` parameter and applies changes to the system. |
| `setPlaybackRange` | `void setPlaybackRange(int start, int end)` | Updates the `PlaybackRange` parameter and applies changes to the system. |
| `setRangeStart` | `void setRangeStart(int start) => setPlaybackRange(start, rangeEnd)` | Updates the `RangeStart` parameter and applies changes to the system. |
| `setRangeEnd` | `void setRangeEnd(int end) => setPlaybackRange(_rangeStart, end)` | Updates the `RangeEnd` parameter and applies changes to the system. |
| `setTimeFormat` | `void setTimeFormat(SequencerTimeFormat format)` | Updates the `TimeFormat` parameter and applies changes to the system. |
| `dispose` | `void dispose()` | Releases native FFI pointers, event subscriptions, and allocated memory. |
| `projectDirPath` | `String get projectDirPath` | Root of the open project. Explicit when the shell supplies it, otherwise derived from the asset path by walking up past `contents/`. |
| `projectDirPath` | `projectDirPath(String value)` | Executes `projectDirPath` operation. |
| `isRendering` | `bool get isRendering` | Checks current state or capability and returns a boolean value. |
| `renderRequiresSave` | `bool get renderRequiresSave` | True when the last [startRender] was refused because the sequence has unsaved edits — the dialog turns this into a "Save & Render" prompt. |
| `renderProgress` | `MovieRenderProgress? get renderProgress` | Getter accessor returning the current value of `renderProgress`. |
| `renderMessage` | `String? get renderMessage` | Getter accessor returning the current value of `renderMessage`. |
| `renderError` | `String? get renderError` | Getter accessor returning the current value of `renderError`. |
| `lastRenderDir` | `Directory? get lastRenderDir` | Getter accessor returning the current value of `lastRenderDir`. |
| `defaultRenderOutputName` | `String defaultRenderOutputName([DateTime? now])` | Default output folder name for the render dialog. |
| `cancelRender` | `void cancelRender()` | Cooperative cancel — the loop stops between frames, never mid-readback. |
| `save` | `Future<bool> save()` | Serializes and writes the current state or asset to disk. |

### `class _ChannelSnapshot`

One animated actor property: knows how to read/write it on an [EditorActorNode] and keeps the pre-preview value for [restore]. The snapshot is per channel, never a whole-actor copy.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `actorId` | `String actorId` | Holds the `actorId` property or configuration state. |
| `id` | `String id` | Holds the `id` property or configuration state. |
| `capture` | `void capture(EditorActorNode actor) => _original = _read(actor)` | Executes `capture` operation. |
| `write` | `void write(EditorActorNode actor, double value) => _write(actor, value)` | Executes `write` operation. |
| `restore` | `void restore(EditorActorNode actor) => _restore(actor, _original)` | Executes `restore` operation. |
| `resolve` | `static _ChannelSnapshot? resolve(EditorActorNode actor, TrackSample samp...` | Executes `resolve` operation. |

## `lib/ui/features/sub_editors/services/sequencer_evaluator.dart`

### `class TrackSample`

The sampled state of one [SequencerTrack] at a given frame.  [values] holds one entry per channel that has at least one key; channels without keys are omitted so the caller never overwrites an actor property the cinematic does not actually animate.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `trackId` | `String trackId` | Holds the `trackId` property or configuration state. |
| `actorId` | `String actorId` | Holds the `actorId` property or configuration state. |
| `kind` | `SequencerTrackKind kind` | Holds the `kind` property or configuration state. |
| `propertyName` | `String? propertyName` | Holds the `propertyName` property or configuration state. |
| `values` | `Map<String, double> values` | Holds the `values` property or configuration state. |

### `class SequencerEvaluator`

Pure-Dart sampler for [SequencerData].  Deliberately free of Flutter imports so the generated game runtime can reuse it later to play cinematics in shipped games.  Interpolation semantics: * the **left** key of a segment decides how the segment is interpolated; * `constant` holds the left value until the right key's frame; * `linear` lerps between the two key values; * `cubic` evaluates a 1-D cubic Hermite spline built from the key values and their tangents (`outTangent` of the left key, `inTangent` of the right key, in value units per frame), computed with de Casteljau on the equivalent bezier whose time axis is linear in the frame — so the curve is always single-valued over time; * before the first key the first value holds, after the last key the last value holds; a single key is constant everywhere; * visibility tracks always sample as a step, whatever the key says.

**Constructors:**
- `SequencerEvaluator()`: Initializes `SequencerEvaluator()`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `evaluate` | `List<TrackSample> evaluate(SequencerData data, double frame)` | Executes `evaluate` operation. |
| `evaluateChannel` | `static double? evaluateChannel(SequencerChannel channel, double frame)` | Samples [channel] at [frame]; `null` when the channel has no keys. |
| `evaluateStep` | `static double? evaluateStep(SequencerChannel channel, double frame)` | Step sampling: holds the value of the latest key at or before [frame]. |
| `evaluateSegment` | `static double evaluateSegment(SequencerKey a, SequencerKey b, double frame)` | Evaluates the segment `[a, b]` at [frame] using [a]'s interpolation. |
| `cubicBezier1D` | `static double cubicBezier1D(double p0, double p1, double p2, double p3, ...` | De Casteljau evaluation of a 1-D cubic bezier at parameter [t] in [0,1]. |
| `autoTangent` | `static double autoTangent(List<SequencerKey> keys, int index)` | Catmull-Rom style automatic tangent for `keys[index]`: the slope between its two neighbours (value units per frame). End keys get a flat tangent. |
| `mergedKeyFrames` | `static List<int> mergedKeyFrames(SequencerData data)` | Sorted, de-duplicated frames of every key on every channel of [data]. |

## `lib/ui/features/sub_editors/services/sequencer_movie_render_service.dart`

### `enum MovieRenderFormat`

The one output format this stack can honestly produce.  `4K MP4` and `16-bit OpenEXR` are not offered: neither has a pure-Dart encoder here and shelling out to ffmpeg would be an undeclared dependency, so the queue writes a numbered PNG sequence. A future encoder consumes the very same per-frame RGBA stream.

**Constructors:**
- `MovieRenderFormat(this.id, this.label)`: Initializes `MovieRenderFormat(this.id, this.label)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `pngSequence` | `pngSequence('png_sequence', 'PNG Sequence')` | Executes `pngSequence` operation. |
| `id` | `String id` | Holds the `id` property or configuration state. |
| `label` | `String label` | Holds the `label` property or configuration state. |

### `enum MovieRenderPhase`

Lifecycle phase carried by every [MovieRenderProgress] event.

### `class MovieRenderCancellationToken`

Cooperative cancellation: the render loop checks it *between* frames so a readback is never torn down half-way and no partial PNG reaches disk.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `isCancelled` | `bool get isCancelled` | Checks current state or capability and returns a boolean value. |
| `cancel` | `void cancel()` | Executes `cancel` operation. |

### `class MovieRenderJob`

Everything one offscreen render run needs.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `sequence` | `SequencerData sequence` | Holds the `sequence` property or configuration state. |
| `sequenceName` | `String sequenceName` | Holds the `sequenceName` property or configuration state. |
| `width` | `int width` | Holds the `width` property or configuration state. |
| `height` | `int height` | Holds the `height` property or configuration state. |
| `fps` | `int fps` | Sampling rate of the render. Sequence keys stay authored in sequence frames; see [sequenceFrameFor]. |
| `startFrame` | `int startFrame` | Inclusive render-frame range. |
| `endFrame` | `int endFrame` | Holds the `endFrame` property or configuration state. |
| `warmupFrames` | `int warmupFrames` | Frames evaluated and drawn but never written — used to let streaming/temporal effects settle before frame 0. |
| `outputDir` | `Directory outputDir` | Holds the `outputDir` property or configuration state. |
| `format` | `MovieRenderFormat format` | Holds the `format` property or configuration state. |
| `totalFrames` | `int get totalFrames` | Getter accessor returning the current value of `totalFrames`. |
| `sequenceFrameFor` | `double sequenceFrameFor(int renderFrame)` | Maps a render frame onto the (fractional) sequence frame to evaluate. Rounding happens nowhere: `renderFrame * (seqFps / renderFps)`. |
| `resolveOutputDir` | `static Directory resolveOutputDir(String projectDirPath, String outputName)` | `<project>/saved/movie_renders/<name>/` — project data, not an asset, so no `.lmas` wrapper and safe to git-ignore. |
| `Directory` | `Directory('$projectDirPath/saved/movie_renders/$outputName')` | Executes `Directory` operation. |
| `defaultOutputName` | `static String defaultOutputName(String sequenceName, [DateTime? now])` | Executes `defaultOutputName` operation. |
| `toManifestJson` | `Map<String, dynamic> toManifestJson()` | Executes `toManifestJson` operation. |

### `class MovieRenderFrameRequest`

One request handed to a [MovieFrameSource].

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `outputIndex` | `int outputIndex` | Zero-based index of the file this frame becomes; `-1` for warmup frames. |
| `renderFrame` | `int renderFrame` | The render-space frame (`startFrame + i`). |
| `sequenceFrame` | `double sequenceFrame` | The fractional sequence frame the samples were evaluated at. |
| `samples` | `List<TrackSample> samples` | Holds the `samples` property or configuration state. |
| `isWarmup` | `bool isWarmup` | Holds the `isWarmup` property or configuration state. |
| `width` | `int width` | Holds the `width` property or configuration state. |
| `height` | `int height` | Holds the `height` property or configuration state. |

### `class MovieFrameSource`

Produces one RGBA8 frame buffer per request.  The GPU implementation ([SequencerOffscreenFrameSource]) owns the offscreen view + RenderTarget; tests inject a CPU fake so the loop, the numbering and the IO are provable without a GPU.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `rowsAreBottomUp` | `bool get rowsAreBottomUp` | True when row 0 of the returned buffer is the *bottom* of the image, as a GL-backend `readPixels` hands it back. The service flips before encoding so exports are never upside down. |
| `prepare` | `Future<void> prepare(MovieRenderJob job)` | Executes `prepare` operation. |
| `renderFrame` | `Future<Uint8List> renderFrame(MovieRenderFrameRequest request)` | Executes `renderFrame` operation. |
| `dispose` | `Future<void> dispose()` | Releases native FFI pointers, event subscriptions, and allocated memory. |

### `class MovieRenderProgress`

A progress tick. Carries files and counters, never pixel buffers — a 4K readback is ~33 MB and must not travel through the stream.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `phase` | `MovieRenderPhase phase` | Holds the `phase` property or configuration state. |
| `frame` | `int frame` | Zero-based index of the frame just written (`-1` for warmup/terminal). |
| `total` | `int total` | Holds the `total` property or configuration state. |
| `bytesWritten` | `int bytesWritten` | Holds the `bytesWritten` property or configuration state. |
| `file` | `File? file` | Holds the `file` property or configuration state. |
| `elapsed` | `Duration elapsed` | Holds the `elapsed` property or configuration state. |
| `framesDone` | `int get framesDone` | Getter accessor returning the current value of `framesDone`. |
| `fraction` | `double get fraction` | Getter accessor returning the current value of `fraction`. |
| `eta` | `Duration? get eta` | Linear estimate from the frames already written; null until one is done. |
| `fileName` | `String? get fileName` | Getter accessor returning the current value of `fileName`. |
| `formatBytes` | `static String formatBytes(int bytes)` | Executes `formatBytes` operation. |
| `formatDuration` | `static String formatDuration(Duration d)` | Executes `formatDuration` operation. |

### `class MovieRenderService`

Walks a [SequencerData] frame by frame and writes a numbered PNG sequence.  One frame per event-loop turn (`Future.delayed(Duration.zero)` between frames) so the editor keeps painting and the progress UI stays live; the offscreen draw therefore never lands inside the viewport's beginFrame/endFrame.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `evaluator` | `SequencerEvaluator evaluator` | Holds the `evaluator` property or configuration state. |
| `flipRows` | `static Uint8List flipRows(Uint8List rgba, int width, int height)` | Bottom-up RGBA8 -> top-down RGBA8. |

## `lib/ui/features/sub_editors/services/sequencer_offscreen_frame_source.dart`

### `class SequencerRenderActor`

One actor the movie render queue draws: its mesh on disk plus the pose the level gave it, which the sampled channels then override per frame.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `actorId` | `String actorId` | Holds the `actorId` property or configuration state. |
| `name` | `String name` | Holds the `name` property or configuration state. |
| `meshPath` | `String? meshPath` | Absolute path of a `.glb` to load; null renders nothing for this actor (a light or camera binding, for example). |
| `location` | `List<double> location` | Holds the `location` property or configuration state. |
| `rotation` | `List<double> rotation` | Holds the `rotation` property or configuration state. |
| `scale` | `List<double> scale` | Holds the `scale` property or configuration state. |

### `class SequencerOffscreenFrameSource`

Real Filament frame source: an offscreen View bound to its own RenderTarget, drawn with `renderStandaloneView` *outside* any beginFrame/endFrame block (so the editor viewport is never disturbed) and read back with `readPixelsFromRenderTarget`.  One RenderTarget is allocated per job and torn down in the service's `finally`; the readback buffer is reused, never copied into progress events.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `actors` | `List<SequencerRenderActor> actors` | Holds the `actors` property or configuration state. |
| `backend` | `FilamentBackend backend` | Holds the `backend` property or configuration state. |
| `rowsAreBottomUp` | `bool get rowsAreBottomUp` | Getter accessor returning the current value of `rowsAreBottomUp`. |
| `isSupported` | `static bool get isSupported` | Whether the native offscreen render capability is present in this build. Probes a trivial `@ffi.Native` symbol: resolution throws when the native asset was not built, which is exactly the "capability missing" case. |
| `prepare` | `Future<void> prepare(MovieRenderJob job)` | Executes `prepare` operation. |
| `renderFrame` | `Future<Uint8List> renderFrame(MovieRenderFrameRequest request)` | Executes `renderFrame` operation. |
| `dispose` | `Future<void> dispose()` | Releases native FFI pointers, event subscriptions, and allocated memory. |

### `class _Pose`

`_Pose`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `location` | `List<double> location` | Holds the `location` property or configuration state. |
| `rotation` | `List<double> rotation` | Holds the `rotation` property or configuration state. |
| `scale` | `List<double> scale` | Holds the `scale` property or configuration state. |
| `visible` | `bool visible` | Holds the `visible` property or configuration state. |

---

[Previous: Project settings](project-settings.md) | [Up: Sub-editors](index.md) | [Next: Static and skeletal mesh editors](meshes.md)

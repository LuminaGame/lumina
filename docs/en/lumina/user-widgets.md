[Türkçe](../../tr/lumina/user-widgets.md)

# User widgets (the Widget Blueprint script)

The engine side of UMG: the object a Widget Blueprint graph runs on. It holds no Flutter widget; the widgets it scripts are drawn by `lumina_widgets` ([UMG page](../lumina_widgets/umg.md)). File paths are relative to the `lumina/` package directory.

## `lib/src/umg/user_widget.dart`

### `abstract class LuminaUserWidget`

A widget's own script: the object a Widget Blueprint graph runs on, bound to one widget instance map (the one `Create Widget` built). It is a hidden actor with no components so every Blueprint node that reaches `self.world` (the widget subsystem, the player, timers) keeps working.

The VM (`LuminaBlueprintUserWidget`) and each generated `WBP<Name>Graph` override the hooks: Pre Construct and Construct when the widget is added to the viewport, Destruct when it is removed, Tick every world tick while it is on screen, and [onWidgetEvent] when one of its elements is pressed, hovered or changed.

**Constructors:**

- `LuminaUserWidget({super.key})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `widgetInstance` | `Map<String, Object?> get widgetInstance` | The widget instance map this script scripts. |
| `widgetClassName` | `String get widgetClassName` | The widget class (`WBP_Clicker`). |
| `isWidgetConstructed` | `bool get isWidgetConstructed` | Whether Construct ran since the widget last entered the viewport. |
| `isWidgetInViewport` | `bool get isWidgetInViewport` | Whether the widget is on screen now. |
| `widgetElement` | `Map<String, Object?>? widgetElement(String name)` | The state map of the element named [name] (its designer name), or null. |
| `bindWidgetInstance` | `void bindWidgetInstance(Map<String, Object?> instance)` | Binds this script to [instance] (done once, by [LuminaUserWidgets.attach]). |
| `onWidgetPreConstruct` | `void onWidgetPreConstruct(bool isDesignTime)` | Event Pre Construct; [isDesignTime] is false at run time. |
| `onWidgetConstruct` | `void onWidgetConstruct()` | Event Construct. |
| `onWidgetDestruct` | `void onWidgetDestruct()` | Event Destruct. |
| `onWidgetTick` | `void onWidgetTick(double inDeltaTime)` | Event Tick (In Delta Time), while the widget is on screen. |
| `onWidgetEvent` | `void onWidgetEvent(String element, String event, Map<String, Object?> args)` | A bound element event: [event] (`OnClicked`, `OnValueChanged`, …) of the element named [element], with the event's outputs in [args] (`value`, `text`, `commit_method`). |

### `abstract final class LuminaUserWidgets`

The widget classes whose instances run a graph: the factory of each class's script, registered by the generated `widget_registry.g.dart` (the compiled `WBP<Name>Graph`) or by Play-In-Editor (a VM script over the editor's graph). The widget nodes call into here, so the VM and generated code share one lifecycle.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `register` | `static void register(String className, LuminaUserWidget Function() factory)` |  |
| `registerAll` | `static void registerAll(Map<String, LuminaUserWidget Function()> factories)` |  |
| `unregister` | `static void unregister(String className)` |  |
| `clear` | `static void clear()` |  |
| `has` | `static bool has(String className)` |  |
| `classNames` | `static Iterable<String> get classNames` |  |
| `of` | `static LuminaUserWidget? of(Object? instance)` | The script of widget instance [instance], or null (no graph, or not a widget). |
| `attach` | `static LuminaUserWidget? attach(LuminaWorld? world, Map<String, Object?> instance)` | Creates [instance]'s script when its class has a graph, binds it and spawns it into [world] (`Create Widget`). Returns the script, or null. |
| `addedToViewport` | `static void addedToViewport(Object? instance)` | `Add to Viewport`: Pre Construct then Construct, once per stay on screen. |
| `removedFromParent` | `static void removedFromParent(Object? instance)` | `Remove from Parent`: Destruct. |
| `fire` | `static void fire(Map<String, Object?>? instance, String element, String event, [Map<String, Object?> args = co...` | A generated widget's (or Play-In-Editor's) element event: runs the graph's `On <Event> (<element>)` node, if the widget has one. |
| `instanceOfElement` | `static Map<String, Object?>? instanceOfElement(Object? element)` | The widget instance element state [element] belongs to, when that instance runs a graph (remembered by [attach]); a Combo Box setter uses it to run On Selection Changed (`Direct`). |

## `lib/src/umg/combo_box_options.dart`

A Combo Box option pairs the **label** the player sees with a **value** of any Blueprint type (a `Vector2` resolution, an enum name, an actor, …). The element state stores them under `options`; every stored form reads the same:

| Stored form | Where it comes from | Reads as |
| :--- | :--- | :--- |
| `'Low,High'` | widget documents saved before options had values (migrated to the list form when the designer opens them) | labels, each its own value |
| `['Easy', 'Hard']` | Add Option without a value | labels, each its own value |
| `[{'label': '720p', 'value': Vector2(1280, 720)}]` | Add Option with a value | label + the value as is |
| `[{'label': '4K', 'value': [3840.0, 2160.0], 'type': 'vector2D'}]` | the designer's typed literal | label + `luminaBlueprintLiteral(type, value)` (`Vector2(3840, 2160)`) |

The selection is `selectedOption` (the label; the designer seeds it as `selected`) plus `selectedIndex`, which tells duplicate labels apart.

### `class LuminaComboBoxOption`

`LuminaComboBoxOption(label, value)`; `LuminaComboBoxOption.text(label)` stands for its label. Equality compares the label and the value by content.

### `class LuminaComboBoxSelection`

What On Selection Changed delivers: `label` (Selected Item), `value`, `index` (-1 for none), `selectType` (`ESelectInfo`). `eventArgs` is the event's outputs by pin id (`selected_item`, `value`, `index`, `select_type`); `none` is no selection.

### `abstract final class LuminaComboBoxOptions`

| Member | Signature | Description |
| :--- | :--- | :--- |
| `optionsKey`, `selectedKey`, `designerSelectedKey`, `selectedIndexKey` | `static const String` | `options`, `selectedOption`, `selected`, `selectedIndex`. |
| `selectInfoEnum`, `selectInfos` | `static const` | `ESelectInfo`: `Direct`, `OnKeyPress`, `OnNavigation`, `OnMouseClick` (constants `direct`, `onKeyPress`, `onNavigation`, `onMouseClick`). |
| `parse` | `static List<LuminaComboBoxOption> parse(Object? stored)` | Every option of a stored value (table above). |
| `labels` | `static List<String> labels(Object? stored)` | The labels of a stored value. |
| `entry` | `static Object entry(LuminaComboBoxOption option)` | The element state's entry: the label alone when the value is the label, else `{label, value}`. |
| `designerEntry` | `static Map<String, Object?> designerEntry(String label, {Object? value, String? type})` | A designer document entry (`{label}` or `{label, value, type}`). |
| `migrateDesignerOptions` | `static List<Map<String, Object?>> migrateDesignerOptions(Object? stored)` | The legacy comma-separated string (or a list of strings) as `{label}` entries; a list of entries is kept. |
| `of` | `static List<LuminaComboBoxOption> of(Object? element)` | The options of an element state map. |
| `selectedLabel` / `selectedIndex` / `selected` | `static …(Object? element, …)` | The selected label; the stored index while it still points at that label, else the first option with it, else -1; the whole selection. |
| `writeSelection` | `static bool writeSelection(Map<String, Object?> element, List<LuminaComboBoxOption> options, int index)` | Writes the selection of option [index] (-1: none); whether it changed. |
| `indexOfLabel` / `indexOfValue` | `static int …(List<LuminaComboBoxOption> options, …)` | The first option with the label / an equal value, or -1. |
| `valueEquals` | `static bool valueEquals(Object? a, Object? b)` | Lists and maps by content, numbers as numbers, `==` otherwise (vectors and rotators compare their components). |

The Blueprint nodes over this model (Add Option with a wildcard Value, Set Selected Value / Index, Get Selected Option → Label, Value, Index, …) are in the [function library](blueprint/function-library.md); On Selection Changed is in [`LuminaWidgetEvents`](blueprint/runtime.md).

## The Viewport element (`lib/src/umg/viewport/`)

A UMG **Viewport** element (designer type `viewport`) shows a real Filament preview scene inside a widget: a character customisation screen, an item inspection view, an editor panel previewing a mesh or a pose. Its scene is **data in the element state**: Blueprint calls only edit a JSON-plain description at `elements[<name>].scene`; the Viewport widget (`LuminaUmgViewport`, [UMG page](../lumina_widgets/umg.md)) diffs it against what it shows and applies the difference. The VM and generated code therefore behave identically, a plugin process can write the same description, and a `Set Text` on a sibling never touches the 3D scene. Orbiting, gizmo drags, playback and overlay drawing run inside the widget every frame; the graph receives only the element's discrete events.

### `class LuminaViewportScene` (`viewport_scene.dart`)

The description, wrapping the element's `scene` map and editing it in place. Transforms are authoring space (`{location, rotation, scale}`, Z up, centimetres, as the Blueprint Transform pin carries them); only the runtime converts them.

| Key | Content |
| :--- | :--- |
| `nodes` | `{id, kind (staticMesh / skeletalMesh / light / marker), asset (project .lmas), transform, visible, pickable, parent, socket, materialParams {slot: {param: value}}, morphs {name: weight}, animation {asset or file, loop, rate, time, playing, serial}, light {type, color, intensity}}` |
| `environment` | `{mode (sky / color / transparent), ibl, intensity}` |
| `grid` | bool |
| `camera` | `{preset (perspective / front / back / left / right / top), orbitTarget, yaw, pitch, distance, fov, orthographic, frame, frameSerial}` — yaw 0 looks at the front of a glTF model (authoring −Y) |
| `skeletonOverlays` | `{node, color, joints, ghostPose {joint: [x, y, z, qx, qy, qz, qw]} or null, ghostAnimation, ghostColor, label}` |
| `gizmo` | `{node, bone or null, mode (translate / rotate / scale), space (world / local), snap}` or null |
| `markers` | `{id, label, kind (point / line / arrow), from, to, color}` |
| `interaction` | `{orbit, pan, zoom, pick, autoRotate (deg/s)}` |
| `nextId` | the counter node and marker ids come from (`skeletal_1`, `mesh_2`, `marker_3`), so the VM and generated code number alike |

`LuminaViewportScene.of(element)` (created when missing), `encode()` / `decode()` (byte-identical round trip), `copy()`, `addNode`, `removeNode` (also removes nodes attached to it and the overlays / gizmo on them), `clear`, `setNodeTransform`, `setNodeVisible`, `setNodeAsset` (a part swap keeps the transform), `attachToSocket`, `setMaterialParameter`, `setMorphTargetWeight`, `playAnimation`, `playAnimationFile`, `stopAnimation`, `setAnimationTime`, `addLight`, `setEnvironment`, `gridVisible`, `setInteraction`, `setCameraPreset`, `frameNode`, `setOrbit`, `showSkeleton`, `showGhostPose`, `hideSkeleton`, `setGizmo`, `hideGizmo`, `addMarker`, `removeMarker`. The constants live in `LuminaViewportNodeKind`, `LuminaViewportCameraPreset`, `LuminaViewportEnvironmentMode` and `LuminaViewportLightType`.

### `abstract final class LuminaViewportSceneDiff` (`viewport_scene_diff.dart`)

`diff(old, next)` → the minimal `LuminaViewportSceneOp`s (`LuminaViewportSceneOpKind`: add / remove / update node with the changed `fields`, environment, grid, camera, interaction, add / remove / update overlay, gizmo, add / remove / update marker). Changing one node's transform is exactly one `updateNode {transform}`; removing a marker is one `removeMarker`. `jsonEquals` compares JSON values (numbers by value).

### `class LuminaViewportSceneRuntime` (`viewport_runtime.dart`)

The preview on the shared engine: one `FilamentScene`, `FilamentView` and camera (its own, or the ones a `FilamentWidget` handed over) and a preview `LuminaWorld` whose actors are the description's nodes. Meshes load through `LuminaAssets` and the engine's mesh cache (never a `File` read), skeletal meshes animate with gltfio's animator (an animation `.lmas` plays the `clip_name` it names on its mesh; a plain clip name works too), nodes attached to a socket follow the bone every frame (socket names from the mesh's `.lmas` `sockets`, else bone names), material parameters go to the instance's material instances (colour → `float4`, scalar → `float`), morph weights to the mesh's morph targets. Preview views use a fixed feature set: MSAA 4×, one shadowed directional light, IBL; never the game's ray tracing, ReSTIR, SSR, upscalers or frame generation.

| Member | Description |
| :--- | :--- |
| `apply(scene)` | Applies the ops between what is shown and `scene`; returns them (empty when nothing changed). |
| `advance(dt)` | One frame: animation, socket following, auto-rotation, camera. |
| `animating` | Whether something moves on its own (a playing animation, auto-rotation). |
| `whenReady` / `isReady` / `failures` | Every mesh loaded or failed; failures by asset. Events `OnSceneReady` and `OnAssetLoadFailed (asset, message)` go to `onEvent`. |
| `orbit` | The `LuminaViewportCamera` the view shows (the player's drag moves it). |
| `frameNode(id)` / `boundsOf(id)` | Frames a node (`'*'`: every mesh); a skinned mesh is bounded by its joints. |
| `pick(x, y)` | CPU pick: the nearest node whose bounds the ray enters, the nearest bone of a skeletal mesh, and the hit location (authoring). |
| `jointsOf(id)` / `ghostJointsOf(id, pose)` | Joint names, parents and world positions (live, or posed by a ghost pose). |
| `setLocalTransform(id, t)` / `transformOf(id)` | A gizmo drag moves a node without touching the description. |
| `setLocalAnimationTime(id, s)` | A bound timeline's time, without a description diff. |
| `project` / `projectAuthoring` | Points to viewport pixels for the overlays. |
| `allowFiles` | Whether `Play Animation File` may read a file (editor panels); a game reports `OnAssetLoadFailed`. |
| `dispose()` | Destroys the nodes, sky, grid and the scene, view and camera it created. |

### `class LuminaViewportController` (`viewport_controller.dart`)

Drives one Viewport: `sync(scene)` applies only the description's difference, `frame(dt)` decides with a `LuminaViewportFrameClock` whether this frame renders, and input becomes events: `orbitDrag`, `panDrag`, `zoom` then `endCameraGesture` (one `OnCameraChanged (yaw, pitch, distance)` on release; the description takes the camera so `Viewport Get Camera` reads it), `tap` (`OnPicked (node_id, bone, hit_location)`), `frameSelection` (F), `beginGizmoDrag` / `updateGizmoDrag` (the node moves at once; `OnGizmoPreview` at most every 1/30 s) / `commitGizmoDrag` (one `OnGizmoCommit (node_id, bone, transform)`; the description takes the transform) / `cancelGizmoDrag` (Escape: `OnGizmoCancel`, the node goes back).

### `class LuminaViewportBudget` (`viewport_budget.dart`)

`renderSize(w, h, devicePixelRatio, renderScale)`: layout × DPR × render scale (0.25–1), the long side clamped to 2048 px. `acquire(owner)` / `release(owner)`: at most 4 rendering Viewports in a game (`LuminaViewportScope.game`), 8 in the editor, 2 on the web; `maxViewports` (1–8) lowers it (`maxViewportsSetting` names the project setting `umg.maxViewports` a host passes in); a refused Viewport shows a placeholder and the refusal is logged once. `counts(...)`: a Collapsed, Hidden, off-screen, zero-sized or inactive-tab Viewport does not count. `LuminaViewportFrameClock`: an idle Viewport (no animation, no auto-rotate, no input for 1 s) renders nothing until the description, the size or input changes; `maxFps` caps the rest.

### `abstract final class LuminaViewportNodes` (`viewport_nodes.dart`)

The `Widget|Viewport` Blueprint nodes ([function library](blueprint/function-library.md)), written once for the VM and generated code. `LuminaViewportTransforms` converts description transforms through `LuminaAxes` / `LuminaUnits` (a location of (0, 0, 100) cm Z-up is (0, 1, 0) m Y-up).

---

[Previous: Game framework](game.md) | [Up: lumina (engine core)](index.md) | [Next: Save games](save.md)

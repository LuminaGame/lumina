[Türkçe](../../tr/lumina_editor_data/metaxr-posing.md)

# MetaXR posing example project

`lib/src/samples/metaxr_posing/` builds an example project for a Meta Quest. The headset shows the user's room through passthrough, with a MetaHuman standing in it. The user grabs the character's hands, elbows, feet, knees, head, chest or pelvis with the controllers and poses it: the limbs follow through IK, and the pose holds on release.

A MetaHuman character belongs to Epic, so the project stays on the machine that built it, like the Game Animation Sample. The builder, the runner and the tests are part of Lumina; the tests use the test-assets mannequin.

Exported by `package:lumina_editor_data/lumina_editor_data.dart`.

## What it builds

| Step | Class | Result |
| :--- | :--- | :--- |
| Project | `MetaXrPosingBuilder.createProject` | `<projects>/<name>` through `ProjectRepository.createProject` (blank template), unless it exists. |
| Plugins and target | `MetaXrPosingBuilder` | `lumina_plugin_openxr` and `lumina_plugin_metaxr` enabled. The target is Android only, with the Meta Quest profile (`ProjectAndroidSettings.quest`): `com.lumina.metaxr_posing`, 72 Hz, multiview, minSdk 32 / targetSdk 34. |
| Character | | The given GLB imported as a skeletal mesh (kept on a rebuild). |
| Blueprints | `MetaXrPosingContent` | See below. |
| HUD | `MetaXrPosingWidgets` | `W_WristHud`, three texts (slot, held handle, frame rate) whose graph keeps the frame rate current. Lumina has no world-space widget yet, so it is not drawn in the headset. |
| Level | `MetaXrPosingLevel` | `L_Room`, described below. |
| Project | | Input, Maps & Modes (`L_Room`, `BP_PosingGameMode`, `BP_XRPlayer` as the default pawn), the compiled Blueprints, the level code, the Blueprint registry and `lib/main.dart`. With the plugins' descriptors it also composes the Android app and the plugins' runtime modules ([Packaging (Android)](packaging.md)). |

The Blueprints:

- `BP_PosedCharacter`: the mesh with a `LuminaPoseAuthoringComponent` (weight 1, holding the targets). At BeginPlay it runs Enable Input, then handles:
  - Reset: hold Menu for 1 s;
  - the four pose slots: A steps to the next slot and loads it, holding A for 0.8 s saves into the current slot, X steps back;
  - turning (right stick X, 90°/s) and sliding (left stick, 80 cm/s).
- `BP_XRPlayer`: the pawn at the XR origin. It holds:
  - a `LuminaPoseGrabInteractor` (grab radius 10 cm, the mouse on a desktop);
  - Undo (B / Y) and the passthrough toggle (left stick click, through MetaXR's *Set Passthrough Enabled*);
  - a camera at 160 cm for desktop play;
  - the two `LuminaMetaHandTrackingComponent` hands (this declares hand tracking in the manifest, so Horizon OS launches the app without controllers in hand).
- `BP_RoomPassthrough`: a `LuminaMetaPassthroughComponent` underlay.
- `BP_PosingGameMode`.

`L_Room` has no floor or sky. It holds:

- the player start at the origin (LOCAL_FLOOR), bound to the game mode;
- a key light and a fill light;
- the passthrough actor;
- the character 120 cm in front of the player (+Y), facing the user.

Every button has a desktop key too: Z undo, R reset, E/Q slots, P passthrough.

## In the headset

On a Quest build, the openxr plugin's runtime module installs `OpenXrGamePresenter` as the game host's immersive presenter (`LuminaGameHost.immersivePresenter`). The presenter:

- starts the OpenXR session and asks for the project's refresh rate;
- mounts the world on Filament running on the runtime's Vulkan device (multiview, both eyes in the compositor's swapchain);
- ticks the world from the XR frame loop;
- spawns an XR origin at the player's pawn;
- registers both controllers with the world's grab interactions.

The MetaXR runtime module binds the world's passthrough components to the `XR_FB_passthrough` layer. Every 5 s the frame numbers go to logcat as `[lumina_xr] frames … late … missed` lines.

## Running it

```bash
LUMINA_METAXR_MESH=<mobile MetaHuman .glb> [LUMINA_METAXR_COOK=release] \
  flutter test tool/metaxr_posing/build_metaxr_posing_test.dart
```

The runner links the OpenXR and MetaXR checkouts into the project's `plugins/` folder, links the project to the engine, builds it and, with `LUMINA_METAXR_COOK`, cooks the APK. It writes `Saved/MetaXrPosing/report.json`. The character is the mobile MetaHuman export (*Mobile (Quest)* in the MetaHuman plugin's Export dialog).

The desktop smoke (`test/smoke/metaxr_posing_smoke_test.dart`, skipped without the built project) renders `L_Room` on the GPU. A scripted controller grabs the right hand, the left elbow, the head, the right foot and the pelvis. The smoke then saves slot 1, resets and loads slot 1 again, and records the solve and frame times.

---

[Up: lumina_editor_data](index.md)

# Camera, spring arm, control rotation

## Which camera renders in Play

The possessed pawn's camera: its active camera component (`LuminaCameraComponent`, `autoActivate` true by
default; activating one deactivates the pawn's others). A pawn without a camera is seen from its eyes
(`baseEyeHeight` above its location). The editor viewport camera (`set_camera`) is not the game camera.

A placed `Camera` actor (`spawn_actor` type `Camera`) takes the view only as the player's **view target**: set
its `LuminaCameraComponent.autoActivateForPlayer` to true (the player looks through it from login on) or call
`set_view_target` / `set_view_target_with_blend` on the player controller. Play and the generated game then
render with that camera's own projection, clip planes and exposure.

## Camera settings (`LuminaCameraComponent`)

The same names and units on a placed Camera (`set_actor_property` with `LuminaCameraComponent.<name>`, Details ▸
Camera) and on a Blueprint camera component (`set_blueprint_component_property`):

| Property | Unit | Default |
|---|---|---|
| `fieldOfView` | degrees, **vertical**, 5–170 | 60 |
| `projectionMode` | `Perspective` / `Orthographic` | `Perspective` |
| `orthoWidth` | cm, the width the view shows (orthographic) | 1000 |
| `nearClipPlane` / `farClipPlane` | cm | 10 / 100000 |
| `autoExposure` | metered from the level's lights | true |
| `aperture` | f-stops | 16 |
| `shutterSpeed` | seconds (1/125 = 0.008) | 0.008 |
| `sensitivity` | ISO | 100 |
| `autoActivateForPlayer` | placed Camera only | false |

The aspect ratio is the viewport's (no letterboxing in Play; the Sequencer's camera lock frames a 16:9 gate).
`aperture` / `shutterSpeed` / `sensitivity` only set the exposure and are overwritten while `autoExposure` is on;
depth of field comes from a Post Process Volume, not the camera. The Sequencer camera lock looks through a
placed Camera's `fieldOfView`.

## Spring arm (`LuminaSpringArmComponent`)

- A camera attached to a spring arm is placed **`targetArmLength` behind the arm** (along the arm's -forward) and
  looks along the arm's forward; the camera's own relative location is overwritten every frame.
- Properties (`set_blueprint_component_property`): `targetArmLength` (cm, default 300), `usePawnControlRotation`
  (default false), `inheritPitch` / `inheritYaw` / `inheritRoll` (default true), `enableCameraLag`,
  `cameraLagSpeed`, `enableCameraRotationLag`, `cameraRotationLagSpeed`, `doCollisionTest`, `probeSize`. The
  camera: the settings above.
- **Third-person / mouse-look camera**: `usePawnControlRotation` = true on the arm; the arm then follows the
  controller's rotation (`add_controller_yaw_input` / `add_controller_pitch_input` from the look action). A new
  Character Blueprint's `CameraBoom` already has it (arm length 400).
- **Fixed follow camera** (side-scroller, runner, top-down): `usePawnControlRotation` false and a fixed relative
  rotation on the arm with `set_blueprint_component_transform` (rotation `[pitch, roll, yaw]`, as for actors): the
  camera sits behind the arm's forward. A top-down view: pitch the arm's forward down (a negative pitch, e.g.
  `[-60, 0, 0]`) and lengthen it; confirm with a play-test screenshot.

## Control rotation and the pawn's facing

- The player controller's **control rotation starts at 0 when Play starts** (yaw 0 = facing +Y), whatever the
  PlayerStart's rotation. A pawn with `bUseControllerRotationYaw` (the default) turns to the controller's yaw, and
  an arm with `usePawnControlRotation` looks along it.
- To start the player facing +X (yaw 90): `event_beginplay` → `add_controller_yaw_input` with `val` 90 on the pawn
  (positive yaw turns right: +Y → +X). Check the result with a play-test screenshot rather than reasoning about
  signs.
- `add_controller_pitch_input` changes the control pitch (clamped to ±89.9°).

## Orientation cheat sheet (authoring axes, Z up)

- Forward at yaw 0 is +Y; yaw 90 → +X; yaw 180 → -Y; yaw -90 → -X. Right is forward turned by +90 yaw.
- A camera looking at the pawn from behind at yaw 0 is on the pawn's -Y side; for a pawn facing +X it is on the
  -X side.
- On a screen looking along +X, +Y is to the left.

## Checking

`start_pie`, `pie_play_for` with `ms` 1500 and `screenshot` true: the screenshot is the game camera. Earlier
frames or a sub-editor tab in front can show the editor camera (see `play-testing`).

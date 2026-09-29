# Changelog

## Unreleased

- Particles: `LuminaParticleSystemComponent` now draws its own particles. It batches a pair of
  crossed quads per live particle into one procedural mesh section, rebuilt each render prep,
  with each particle's colour and size sampled from its own normalized age. Before this it
  added bare entities to the scene and a running game drew nothing. New surface:
  `renderedParticleCount`, `hasSpriteGeometry`, `spriteVertexCount`, `particleAgeAt`,
  `particleColorAt`, `particleSizeAt`, `spriteHalfSize`. Mesh emitters (`meshAssetPath`) still
  draw sprites.

- Code generator: `generateLevelDart` emits a real `LuminaLevel` subclass with typed runtime
  objects (pawns, static meshes, directional/point/spot lights, colour/HDRI sky) from the
  editor's actor maps and applies the level's environment post-process from a level script
  actor; `generateMainDart` emits a `LuminaGame` subclass mounted through `LuminaGameWidget`
  and imports the active level. Generated code is verified with `dart analyze` in tests.
- `luminaEulerDegreesToQuaternion` shared Rz·Ry·Rx euler helper.
- Fix: `LuminaWorld.spawnActor` registered actors twice (sky components threw, meshes loaded
  twice) and a throwing actor replayed the spawn buffer forever.

- Play control API for editors: `LuminaGame.pause/resume/step/restart`, `playState` +
  `playStateStream`, `LuminaWorld.isPaused`/`step`/`tickCount`, subsystem pause hooks,
  audio pause/resume, `LuminaGameWidget(paused:, onPlayStateChanged:, useHeadlessSwapChain:)`.
- Domain layer (`lib/domain`): `SaveLevelUseCase`, `GenerateDartCodeUseCase`, `ImportAssetUseCase`
  with typed results.
- Project manifest: `description`, Enhanced Input (`input`), `maps_and_modes`, `physics`,
  `packaging` sections; quality presets expand to per-category tiers; defaults
  target FPS 0 (unlimited) and VSync off.
- Plugin tooling: generated registrar targets `lumina_editor_api`; template pins the host's
  shadcn_flutter version. GLB parser tolerates NUL-padded JSON chunks.

- `LuminaCharacterMovementComponent.stopJumping` implemented: releasing the jump
  input scales the remaining upward velocity by `jumpCutMultiplier` (variable jump
  height); `isJumpHeld` exposed. Previously a no-op.
- `docs/` spec names aligned with the code (`LuminaNodeGroup`, `LuminaStreamingSource`,
  `LuminaHlodSubsystem`, `LuminaCollisionSubsystem`, `LuminaPhysicsWorldSubsystem`,
  `LuminaAudioSubsystem`, `LuminaTransformSnapshot`).
- `bin/inspect_lmas.dart` takes a path argument instead of a hardcoded home directory.
- Removed scratch scripts and a stray `.patch` file from the package tree.

## 0.0.1 (2026-08-26)

- Runtime: declarative build tree, `LuminaWorld`/`LuminaLevel`, actors/pawns/characters,
  controllers, scene/mesh/light/camera/spring-arm/movement/audio/particle components,
  collision and physics subsystems, world partition + level streaming + HLOD, input mapping,
  save game subsystem, game framework (game mode/state, player camera manager, HUD), timers,
  gameplay statics and volumes, GPU picking and screenshots, behaviour trees.
- Animation: skeletal animation, keyframe sequences, bone tracks, curve evaluation,
  skeleton retargeting and IK rig.
- Data layer: `.lmas` asset and `.lmproject` models, asset/project/collections repositories,
  GLB/OBJ/TGA parsers (morph targets, skinning, animations), mesh decimation, thumbnails,
  asset reference graph, Dart code generator with user regions, plugin manifest/registry/
  template generator, sequencer data, engine logger, auto-save.
- Testing: `SmokeArtifacts` (PNG + video evidence) and `tool/smoke_report.dart`
  running on GPU 1.

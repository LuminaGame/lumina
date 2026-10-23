# Changelog

## Unreleased

- Material textures upload on the engine's asynchronous path (`FilamentTexture.setImageAsync`): a material's sampler
  textures (`LuminaMaterialTextures`) and a dynamic instance's pixel textures land on the GPU over the next frames
  without holding the calling isolate; the mip chain is generated once the pixels are there.
- Web builds use the bundled pose search caches: the cache fingerprint's document hash no longer depends on how the
  platform prints whole-number doubles (`LuminaPoseSearchBuilder.canonicalJson`), so the Game Animation Sample on the
  web no longer rebuilds every database on the page thread (freezes of 3.4, 2.5 and 2.5 s on the first walk and turn,
  now none over 150 ms). Caches written so far stay valid.
- Frame generation is not applied while a game is shown through Flutter (the player chose Flutter,
  Direct fell back or is starting, a host without Direct, Play-In-Editor): Flutter shows one frame per
  rendered frame, so it only cost frame rate (3440x1440 built game: 48.1 presented frames/s off, 34.9
  FSR3, 29.0 DLSS 2x). It is a rendering fallback (`Frame generation is off: the game presents through
  Flutter (<reason>).`); Get Frame Generation Enabled keeps the choice, the new Is Frame Generation
  Active node / `frameGenerationActive` report it off, and it comes back once Direct runs. The chosen
  frame generation still asks for Direct (`LuminaGamePresentation.setFrameGenerationRequested`,
  replacing `setFrameGenerationActive`; `flutterPresentation` / `setFlutterPresentation`), so a Direct
  fallback is stable.

- Game widget: the view is rendered once per frame. `LuminaGameWidget`'s frame driver no longer renders
  the view a second time into a 1x1 headless swap chain; it only ticks and paces the world
  (`LuminaFrameDriver` without a `swapChain`, new `rendersView` / `renderedFrames`, widget
  `onFrameDriver`). Frame generation on the Flutter presentation path no longer freezes the game on
  readback fence timeouts, and the Flutter path is faster (offscreen, five props: 199 → 405 frames/s at 1024x768, 92.5 → 118 at
  3440x1440).

- Rendering settings: DLSS Ray Reconstruction is a fourth upscaler (`LuminaUpscaler.dlssRayReconstruction`,
  `DLSS RR`) and frame generation has a generator (`LuminaFrameGenerator` FSR3 / DLSS) with DLSS's
  generated frames per rendered frame (1–5). `LuminaRtxController` drives `DlssRayReconstruction` (with
  the view's guide buffers) and `DlssFrameGenerator`; the user settings resolve them with fallbacks
  (DLSS RR → DLSS, DLSS frame generation → FSR3). New Blueprint nodes: Set/Get Frame Generator,
  Set/Get DLSS Generated Frames, Is Ray Reconstruction Supported, Is DLSS Frame Generation
  Supported, Get Max DLSS Generated Frames.

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

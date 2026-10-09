part of '../pie_controller.dart';

/// Declarative game built from the editor's level actors for Play-In-Editor.
///
/// Every editor actor is mapped to a real Lumina runtime object via
/// [mapEditorActor]; the resulting tree is mounted into a [LuminaWorld] on
/// the live Filament engine/scene so the simulated world contains the same
/// meshes, lights and pawn the editor shows.
class EditorPieGame extends LuminaGame {
  final List<EditorActorNode> editorActors;

  /// Which pawn the project's template scaffolds. `blank` plays the level with
  /// no player at all, which is what Simulate means for a level that has no
  /// game framework in it.
  final GameTemplateKind templateKind;

  /// The project's own input actions and mapping contexts, bound to the
  /// runtime. Rebinding a key in Project Settings changes what Play does.
  final BoundProjectInput input;

  /// Absolute path of the Third Person character GLB (mesh + merged clips) the
  /// possessed character plays, or null for a project that has none.
  final String? mannequinMeshPath;

  /// The local player's controller once [startPlayerSession] has run.
  LuminaPlayerController? playerController;

  /// Keys and mouse deltas injected before the world existed are dropped, not
  /// queued: a key held down across Play is re-sent on its next event.
  LuminaInputSubsystem? _inputSubsystem;

  /// The project's Blueprint classes: the GameMode
  /// Blueprint, the pawn class and placed Blueprint actors play through
  /// lumina's registry and VM. Null plays no Blueprints (tests of the
  /// template path).
  final EditorBlueprintClassRegistry? registry;

  /// The project's Maps & Modes: which game mode and pawn class Play uses.
  final ProjectMapsAndModes mapsAndModes;

  /// Called with every Blueprint instance Play creates (placed actors and the
  /// spawned pawn) before its BeginPlay runs.
  final void Function(LuminaBlueprintInstance instance)? onBlueprintInstance;

  /// The level's Blueprint script, attached as the
  /// world's level script so Level Loaded runs before any BeginPlay; null
  /// when the level has none.
  final LuminaLevelScriptActor? levelScript;

  EditorPieGame(
    this.editorActors, {
    this.templateKind = GameTemplateKind.blank,
    this.input = const BoundProjectInput(contexts: [], actions: {}, unboundKeys: []),
    this.mannequinMeshPath,
    this.registry,
    this.mapsAndModes = const ProjectMapsAndModes(),
    this.onBlueprintInstance,
    this.levelScript,
  });

  /// Makes [levelScript] [world]'s level script, before its BeginPlay.
  void _attachLevelScript(LuminaWorld world) {
    final script = levelScript;
    if (script == null || world.persistentLevel.scriptActor == script) return;
    if (script is LuminaBlueprintInstance) onBlueprintInstance?.call(script as LuminaBlueprintInstance);
    world.persistentLevel.scriptActor = script;
  }

  /// The possessed character when it is the Dart template character (First
  /// Person and projects whose game mode names no Blueprint pawn), else null.
  LuminaTemplateCharacter? get playerPawn =>
      playerController?.pawn is LuminaTemplateCharacter
          ? playerController!.pawn as LuminaTemplateCharacter
          : null;

  /// Whatever pawn the local player possesses: a Blueprint pawn running in
  /// the VM, or the template character.
  LuminaPawn? get possessedPawn => playerController?.pawn;

  /// The camera Play looks through: the template character's, or the
  /// possessed Blueprint pawn's active camera component.
  LuminaCameraComponent? get playerCamera {
    final template = playerPawn;
    if (template != null) return template.cameraComponent;
    final pawn = possessedPawn;
    if (pawn == null) return null;
    final cameras = pawn.components.whereType<LuminaCameraComponent>();
    return cameras.where((c) => c.isActive).firstOrNull ?? cameras.firstOrNull;
  }

  /// The camera the player's view goes through: a placed camera actor the
  /// player's camera manager targets (Auto Activate for Player, Set View
  /// Target), else [playerCamera].
  LuminaCameraComponent? get viewCamera => viewTargetPov?.camera ?? playerCamera;

  /// The player camera manager's point of view while the view is not simply
  /// the pawn's own camera (another view target, a blend, an FOV override or
  /// a shake); null otherwise.
  LuminaMinimalViewInfo? get viewTargetPov => gameInstance.world?.viewTargetPov;

  /// What the status bar names as the running pawn: `BP_ThirdPersonCharacter
  /// (VM)` for a Blueprint pawn.
  String? get pawnClassLabel {
    final pawn = possessedPawn;
    if (pawn == null) return null;
    if (pawn is LuminaBlueprintInstance) return '${(pawn as LuminaBlueprintInstance).blueprintClass.name} (VM)';
    return pawn.runtimeType.toString();
  }

  /// Whether Play spawns a Blueprint pawn (a GameMode Blueprint, or a Maps &
  /// Modes Default Pawn Class).
  bool get playsBlueprintPawn =>
      registry != null && (mapsAndModes.gameModeIsBlueprint || mapsAndModes.defaultPawnClass.isNotEmpty);

  /// Whether this project carries a game mode that spawns a player.
  bool get hasPlayerSession => templateKind != GameTemplateKind.blank || playsBlueprintPawn;

  /// Whether the running level lights itself with a directional light, so the
  /// editor's own preview sun would only double it.
  bool get providesSunlight {
    final world = gameInstance.world;
    if (world == null) return false;
    for (final actor in world.persistentLevel.actors) {
      for (final component in actor.components) {
        if (component is LuminaDirectionalLightComponent) return true;
      }
    }
    return false;
  }

  /// Registers the subsystems a playing world needs but a mounted tree does
  /// not create for itself.
  ///
  /// Without the collision subsystem the character movement component has
  /// nothing to sweep against: the character neither falls onto the floor nor
  /// is stopped by a wall, and simply floats through the level. The generated
  /// game registers the same subsystem from its level script actor.
  void installSubsystems(LuminaWorld world) {
    if (world.getSubsystem<LuminaCollisionSubsystem>() != null) return;
    final collision = world.registerSubsystem(LuminaCollisionSubsystem());
    // Actors mounted before the subsystem existed never got the chance to
    // register their colliders, so do it for them.
    for (final actor in world.persistentLevel.actors) {
      for (final component in actor.components) {
        if (component is LuminaCollisionComponent) {
          collision.register(component);
        }
      }
    }
  }

  /// Installs the game mode on [world] **before** `beginPlay`, because
  /// `LuminaWorld.beginPlay` is what calls `initGame` and creates the game
  /// state that `login` adds the player to.
  void installGameMode(LuminaWorld world) {
    if (!hasPlayerSession || world.gameMode != null) return;
    // A GameMode Blueprint plays through lumina's
    // registry, with Maps & Modes' Default Pawn Class overriding its pawn.
    final registry = this.registry;
    if (registry != null && mapsAndModes.gameModeIsBlueprint) {
      final mode = registry.createGameMode(mapsAndModes);
      if (mode != null) {
        _observePawns(mode);
        world.gameMode = mode;
        return;
      }
    }
    final thirdPerson = templateKind == GameTemplateKind.thirdPerson;
    final mode = LuminaGameMode(
      defaultPawnFactory: () => LuminaTemplateCharacter(
        thirdPerson: thirdPerson,
        meshAssetPath: thirdPerson ? mannequinMeshPath : null,
      ),
      playerControllerFactory: () => LuminaPlayerController(playerName: 'Player'),
    );
    // A Dart game mode with a Maps & Modes Default Pawn Class spawns that
    // Blueprint instead of the template character.
    final override = registry?.resolvePawnFactory(mapsAndModes);
    if (override != null) mode.defaultPawnFactory = override;
    _observePawns(mode);
    world.gameMode = mode;
  }

  /// Hands a spawned Blueprint pawn to [onBlueprintInstance] before its
  /// BeginPlay.
  void _observePawns(LuminaGameMode mode) {
    final hook = onBlueprintInstance;
    if (hook == null) return;
    final factory = mode.defaultPawnFactory;
    mode.defaultPawnFactory = () {
      final pawn = factory();
      if (pawn is LuminaBlueprintInstance) hook(pawn as LuminaBlueprintInstance);
      return pawn;
    };
  }

  /// Logs the local player in **after** `beginPlay`: `findPlayerStart` walks the
  /// world's levels, which are only populated once the tree has mounted.
  void startPlayerSession() {
    final world = gameInstance.world;
    final mode = world?.gameMode;
    if (world == null || mode == null) return;

    // A Blueprint pawn binds its own Enhanced Input actions when possessed;
    // the project's mapping contexts are registered for it first, as the
    // generated game's `luminaAddProjectInput` does.
    if (playsBlueprintPawn && input.contexts.isNotEmpty) {
      final subsystem = world.getSubsystem<LuminaInputSubsystem>() ?? world.registerSubsystem(LuminaInputSubsystem());
      for (final bound in input.contexts) {
        subsystem.addMappingContext(bound.context, priority: bound.priority);
      }
    }

    playerController = mode.login();
    // The controller is not a world tickable. As in a generated game, a level
    // script actor ticks it — after the input subsystem has dispatched this
    // frame's look input and before the pawn's spring arm places the camera:
    // the controller clamps the pitch and turns the pawn, and the arm then
    // writes its camera offset for that rotation. Ticked after the world, the
    // camera sat off its socket by each frame's turn and the pitch ran past
    // the clamp for a frame.
    final driver = _PieControllerDriver(playerController!);
    world.persistentLevel.registerActor(driver);
    driver.onInitialize();
    driver.onBeginPlay();
    final pawn = playerPawn;
    if (pawn != null) {
      bindTemplateCharacterInput(character: pawn, world: world, input: input);
    }
    _inputSubsystem = world.getSubsystem<LuminaInputSubsystem>();
  }

  /// Mounts the actor tree into [world] and runs the whole play sequence.
  /// Used by tests, which have no Filament engine to mount into.
  void mountIntoWorldForTest(LuminaWorld world) {
    _mountedForTest = true;
    for (final actor in editorActors
        .map((a) => mapEditorActor(a, registry: registry, onBlueprintInstance: onBlueprintInstance))
        .whereType<LuminaActor>()) {
      world.persistentLevel.registerActor(actor);
    }
    gameInstance = LuminaGameInstance();
    gameInstance.setInitialWorld(world);
    _attachLevelScript(world);
    installSubsystems(world);
    installGameMode(world);
    world.beginPlay();
    startPlayerSession();
  }

  /// Mounted by [mountIntoWorldForTest]: no Filament scene, so the game's
  /// play state never left `stopped`.
  bool _mountedForTest = false;

  /// Frame stepping (the MCP server's `pie_advance`) also in a world mounted
  /// for tests, which the base class refuses as "not mounted".
  @override
  void step(double deltaTime) {
    if (!_mountedForTest) return super.step(deltaTime);
    gameInstance.world?.step(deltaTime);
    gameInstance.primaryPlayerController?.onTick(deltaTime);
  }

  /// Whether the project's mapping contexts bind [key] (PIE swallows only
  /// those; every key is still forwarded).
  bool bindsKey(LuminaKey key) => input.contexts.any((c) => c.context.mappingsForKey(key).isNotEmpty);

  /// Keys forwarded into the world, and keys that arrived with no input
  /// subsystem to take them. The smoke asserts the second stays zero.
  int injectedKeysForTest = 0;
  int droppedKeysForTest = 0;

  /// Forwards a key press from the editor viewport into the running world.
  void injectKeyDown(LuminaKey key) {
    final subsystem = _inputSubsystem;
    if (subsystem == null) {
      droppedKeysForTest++;
      return;
    }
    injectedKeysForTest++;
    subsystem.injectKeyDown(key);
  }

  /// Forwards a key release from the editor viewport into the running world.
  void injectKeyUp(LuminaKey key) => _inputSubsystem?.injectKeyUp(key);

  /// Forwards an analog axis value into the running world.
  void injectAnalog(LuminaKey key, double value) => _inputSubsystem?.injectAnalog(key, value);

  /// The pointer position in the PIE view's pixels (Get Mouse Position).
  void injectMousePosition(double x, double y) => _inputSubsystem?.injectMousePosition(vm64.Vector2(x, y));

  /// Forwards a mouse movement, in pixels, into the running world.
  void injectMouseDelta(double dx, double dy) {
    final input = _inputSubsystem;
    if (input == null) return;
    if (dx != 0.0) input.injectAnalog(LuminaKey.mouseX, dx);
    if (dy != 0.0) input.injectAnalog(LuminaKey.mouseY, dy);
  }

  @override
  LuminaObject? build(LuminaBuildContext context) {
    final world = context.world;
    if (world != null) _attachLevelScript(world);
    return LuminaNodeGroup(
      children: editorActors
          .map((a) => mapEditorActor(a, registry: registry, onBlueprintInstance: onBlueprintInstance))
          .whereType<LuminaObject>()
          .toList(),
    );
  }

  /// The material [actor] assigns, when it can be drawn; one that cannot (not
  /// found, never compiled) is reported to the Output Log and the mesh keeps
  /// its own materials, as in the generated level.
  static String? _assignedMaterial(EditorActorNode actor) {
    final path = LuminaLevelActorMaterial.pathOf(actor.toMap());
    if (path == null) return null;
    final problem = LuminaLevelActorMaterial.problem(path, projectDir: LuminaAssets.projectDir);
    if (problem == null) return path;
    EngineLoggerService().log(
      'Actor "${actor.name}" draws its own materials: its material $problem',
      level: 'warning',
      source: 'PIE',
    );
    return null;
  }

  /// Editor actor types that carry no runtime representation.
  static const Set<String> nonRuntimeTypes = {'Folder'};

  /// Maps an editor actor to its runtime counterpart, or null for
  /// organisational nodes such as folders.
  static LuminaObject? mapEditorActor(
    EditorActorNode actor, {
    EditorBlueprintClassRegistry? registry,
    void Function(LuminaBlueprintInstance instance)? onBlueprintInstance,
  }) {
    final mapped = _mapEditorActor(actor, registry: registry, onBlueprintInstance: onBlueprintInstance);
    // Hidden in the outliner (the folders already baked in by the
    // controller): hidden in Play, whatever class the actor became and
    // however many components it has.
    if (mapped is LuminaActor && !actor.isVisible) mapped.hiddenInGame = true;
    return mapped;
  }

  static LuminaObject? _mapEditorActor(
    EditorActorNode actor, {
    EditorBlueprintClassRegistry? registry,
    void Function(LuminaBlueprintInstance instance)? onBlueprintInstance,
  }) {
    if (nonRuntimeTypes.contains(actor.type)) return null;

    // Stored Z-up (cm) → the runtime's Y-up, by the rule the generated game
    // and the viewport share.
    final location = LuminaAxes.location(actor.location);
    final rotation = LuminaAxes.rotation(actor.rotation);
    final scale = LuminaAxes.scale(actor.scale);

    // A placed Blueprint is an instance of its class,
    // built by lumina's VM from the registry — location and rotation, as the
    // generated level passes them (the class's components carry scale).
    final blueprintClass = actor.blueprintClass;
    if (blueprintClass != null && blueprintClass.isNotEmpty && registry != null) {
      final cls = registry.classFor(blueprintClass);
      if (cls != null && !cls.hasErrors && !cls.isGameMode) {
        final instance = cls.instantiate(key: LuminaObjectKey(actor.id), location: location, rotation: rotation);
        if (instance is LuminaBlueprintInstance) {
          // This placement's collision overrides.
          BlueprintCollisionOverrides.applyTo(instance, actor);
          onBlueprintInstance?.call(instance);
        }
        return instance;
      }
    }

    switch (actor.type) {
      case 'PlayerStart':
        // A real player start, so LuminaGameMode.findPlayerStart can see it.
        return LuminaPlayerStart(
          key: LuminaObjectKey(actor.id),
          location: location,
          rotation: rotation,
        );
      case 'Primitive':
        final properties = _componentProperties(actor, 'LuminaProceduralMeshComponent');
        return LuminaPrimitiveActor.fromComponentProperties(
          properties,
          key: LuminaObjectKey(actor.id),
          location: location,
          rotation: rotation,
          scale: scale,
          materialOverrideAsset: _assignedMaterial(actor),
        );
      case 'Camera':
        // A placed camera, looked through as a view target with its
        // Details settings.
        return LuminaCameraActor(
          key: LuminaObjectKey(actor.id),
          location: location,
          rotation: rotation,
          scale: scale,
          settings: CameraActorProperties.read(actor),
        );
      case 'Pawn':
        return LuminaPawn(
          key: LuminaObjectKey(actor.id),
          location: location,
          rotation: rotation,
        );
      case 'Mesh':
      case 'StaticMesh':
      case 'SkeletalMesh':
        final meshPath = actor.meshAssetPath;
        if (meshPath == null) {
          // No geometry resolved on disk: keep the actor's transform in the
          // world so gameplay logic can still reference it.
          return LuminaActor(
            key: LuminaObjectKey(actor.id),
            root: LuminaSceneComponent(location: location, rotation: rotation, scale: scale, isVisible: actor.isVisible),
          );
        }
        // A skeletal mesh with spring-driven morph targets plays as an
        // animated mesh with its springs, as in the generated game.
        final springs = actor.type == 'SkeletalMesh'
            ? actor.components.where((c) => c.type == 'LuminaSpringMorphComponent').firstOrNull
            : null;
        if (springs != null) {
          // After the mesh, so the springs read its pose of the frame.
          return LuminaActor(
            key: LuminaObjectKey(actor.id),
            root: LuminaAnimatedMeshComponent(
              location: location,
              rotation: rotation,
              scale: scale,
              meshAssetPath: meshPath,
              castShadows: actor.castShadows,
              visible: actor.isVisible,
            ),
          )..addComponent(LuminaSpringMorphComponent.fromProperties(Map<String, Object?>.from(springs.properties)));
        }
        // 06: a mesh's simple collision — imported UCX_
        // hulls and the Static Mesh editor's authored shapes — as in the
        // generated game.
        final collision = actor.type == 'SkeletalMesh'
            ? MeshSimpleCollision.none
            : MeshCollisionService.simpleCollisionForMeshAsset(meshPath);
        // The material assigned in the level, as the generated level draws it.
        final material = _assignedMaterial(actor);
        if (!collision.isEmpty) {
          return LuminaStaticMeshActor(
            key: LuminaObjectKey(actor.id),
            location: location,
            rotation: rotation,
            scale: scale,
            meshAssetPath: meshPath,
            castShadows: actor.castShadows,
            visible: actor.isVisible,
            collisionHulls: collision.hulls,
            collisionPrimitives: collision.primitives,
            materialOverrideAsset: material,
          );
        }
        return LuminaActor(
          key: LuminaObjectKey(actor.id),
          root: LuminaStaticMeshComponent(
            location: location,
            rotation: rotation,
            scale: scale,
            meshAssetPath: meshPath,
            castShadows: actor.castShadows,
            visible: actor.isVisible,
            materialOverrideAsset: material,
          ),
        );
      case 'Light':
      case 'DirectionalLight':
        // The light's Details section, else the actor fields.
        final sun = LightActorProperties.read(actor);
        return LuminaActor(
          key: LuminaObjectKey(actor.id),
          root: LuminaDirectionalLightComponent(
            location: location,
            rotation: rotation,
            color: luminaLightColorFromHex(sun.colorHex),
            intensity: sun.intensity,
            castShadows: sun.castShadows,
            sunAngularRadius: sun.sunAngularRadius,
            visible: actor.isVisible,
          ),
        );
      case 'PointLight':
        final point = LightActorProperties.read(actor);
        return LuminaActor(
          key: LuminaObjectKey(actor.id),
          root: LuminaPointLightComponent(
            location: location,
            rotation: rotation,
            color: luminaLightColorFromHex(point.colorHex),
            intensity: point.intensity,
            falloffRadius: point.attenuationRadius,
            castShadows: point.castShadows,
            visible: actor.isVisible,
          ),
        );
      case 'Landscape':
        final landscapePath = actor.meshAssetPath;
        if (landscapePath == null || landscapePath.isEmpty) {
          return LuminaActor(
            key: LuminaObjectKey(actor.id),
            root: LuminaSceneComponent(location: location, rotation: rotation, scale: scale, isVisible: actor.isVisible),
          );
        }
        return LuminaActor(
          key: LuminaObjectKey(actor.id),
          root: LuminaLandscapeComponent(assetPath: landscapePath, location: location, rotation: rotation, scale: scale, isVisible: actor.isVisible),
        );
      case 'ProceduralSky':
        // The Procedural Sky & Ocean, with whatever the Details panel authored.
        // It is a renderable, not a Filament Skybox, so it coexists with the
        // Environment actor's skybox and image-based lighting — and it lights
        // nothing itself.
        return LuminaActor(
          key: LuminaObjectKey(actor.id),
          root: LuminaProceduralSkyComponent.fromProperties(
            _componentProperties(actor, 'LuminaProceduralSkyComponent'),
          )..visible = actor.isVisible,
        );
      case 'ExponentialHeightFog':
        // Exponential height fog over Filament's per-view fog:
        // the actor's Z is the fog height.
        return LuminaActor(
          key: LuminaObjectKey(actor.id),
          root: LuminaExponentialHeightFogComponent.fromProperties(
            EnvironmentActorProperties.propertiesOf(actor),
            location: location,
            rotation: rotation,
            visible: actor.isVisible,
          ),
        );
      case 'PostProcessVolume':
        // A Post Process Volume: blends by camera
        // position through the world's blender.
        return LuminaActor(
          key: LuminaObjectKey(actor.id),
          root: LuminaPostProcessVolumeComponent.fromProperties(
            EnvironmentActorProperties.propertiesOf(actor),
            location: location,
            rotation: rotation,
            scale: scale,
            visible: actor.isVisible,
          ),
        );
      case 'LocalFogVolume':
        // A Local Fog Volume: a fog-shell
        // approximation — Filament has no volumetric scattering.
        return LuminaActor(
          key: LuminaObjectKey(actor.id),
          root: LuminaLocalFogVolumeComponent.fromProperties(
            EnvironmentActorProperties.propertiesOf(actor),
            location: location,
            rotation: rotation,
            scale: scale,
            visible: actor.isVisible,
          ),
        );
      case 'SpotLight':
        final spot = LightActorProperties.read(actor);
        return LuminaActor(
          key: LuminaObjectKey(actor.id),
          root: LuminaSpotLightComponent(
            location: location,
            rotation: rotation,
            color: luminaLightColorFromHex(spot.colorHex),
            intensity: spot.intensity,
            falloffRadius: spot.attenuationRadius,
            innerConeAngleDegrees: spot.innerConeAngle,
            outerConeAngleDegrees: spot.outerConeAngle,
            castShadows: spot.castShadows,
            visible: actor.isVisible,
          ),
        );
      default:
        // Environment, Trigger and any plugin-defined type: a plain
        // actor at the authored transform.
        return LuminaActor(
          key: LuminaObjectKey(actor.id),
          root: LuminaSceneComponent(location: location, rotation: rotation, scale: scale, isVisible: actor.isVisible),
        );
    }
  }

  /// The `properties` map of [actor]'s first component of [type], or empty.
  static Map<String, dynamic> _componentProperties(EditorActorNode actor, String type) {
    for (final component in actor.components) {
      if (component.type != type) continue;
      return Map<String, dynamic>.from(component.properties);
    }
    return const <String, dynamic>{};
  }

  /// Converts editor Euler angles in degrees (pitch X, yaw Y, roll Z) to a
  /// quaternion using the same XYZ order the viewport applies.
  static vm64.Quaternion eulerDegreesToQuaternion(List<double> eulerDeg) {
    final x = (eulerDeg.isNotEmpty ? eulerDeg[0] : 0.0) * math.pi / 180.0;
    final y = (eulerDeg.length > 1 ? eulerDeg[1] : 0.0) * math.pi / 180.0;
    final z = (eulerDeg.length > 2 ? eulerDeg[2] : 0.0) * math.pi / 180.0;
    final m = vm64.Matrix4.rotationZ(z) *
        vm64.Matrix4.rotationY(y) *
        vm64.Matrix4.rotationX(x);
    return vm64.Quaternion.fromRotation(m.getRotation())..normalize();
  }
}

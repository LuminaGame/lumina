import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

/// A crossfade the mesh was asked for.
typedef AnimFade = ({String clip, double duration, bool sync});

/// What the mesh shows after a tick.
typedef AnimSample = ({String? clip, double rate});

/// A real animated mesh component that remembers every crossfade request. It
/// never loads (no native context), so clip requests stay pending and
/// `currentClip` reports what was asked for.
class RecordingMesh extends LuminaAnimatedMeshComponent {
  final fades = <AnimFade>[];

  /// Clips requested to play once, in request order.
  final oneShots = <String>[];

  RecordingMesh() : super(meshAssetPath: 'never_loaded.glb', location: Vector3(0.0, -90.0, 0.0));

  @override
  void play(String clip, {double startTime = 0.0, bool loop = true}) {
    if (!loop) oneShots.add(clip);
    super.play(clip, startTime: startTime, loop: loop);
  }

  // An unloaded mesh's crossFadeTo delegates to play, which records it.
  @override
  void crossFadeTo(String clip, {double duration = 0.2, bool syncPhase = false, bool loop = true}) {
    fades.add((clip: clip, duration: duration, sync: syncPhase));
    super.crossFadeTo(clip, duration: duration, syncPhase: syncPhase, loop: loop);
  }
}

/// A character on a floor whose mesh is animated either by the Dart
/// locomotion driver or by an Animation Blueprint.
class AnimRig {
  final LuminaWorld world;
  final LuminaCharacter character;
  final RecordingMesh mesh;
  final LuminaAnimBlueprintInstance? anim;

  AnimRig._(this.world, this.character, this.mesh, this.anim);

  /// A rig over a character someone else built and registered (a Blueprint
  /// character whose mesh is a [RecordingMesh]).
  AnimRig.attached(this.world, this.character, this.mesh, this.anim);

  static LuminaWorld floorWorld() {
    final world = LuminaWorld(worldType: LuminaWorldType.game);
    world.subsystems.registerSubsystem<LuminaCollisionSubsystem>(LuminaCollisionSubsystem(), world);
    world.persistentLevel.registerActor(LuminaPrimitiveActor(
      shape: LuminaPrimitiveShape.box,
      size: Vector3(8000.0, 100.0, 8000.0),
      color: Vector3.all(0.5),
      location: Vector3(0.0, -50.0, 0.0),
    ));
    return world;
  }

  static AnimRig _build(LuminaActorComponent Function(RecordingMesh mesh) driverFor, {double maxWalkSpeed = 300}) {
    final world = floorWorld();
    final character = LuminaCharacter(location: Vector3(0.0, 100.0, 0.0));
    character.characterMovement.maxWalkSpeed = maxWalkSpeed;
    character.characterMovement.jumpZVelocity = LuminaTemplateCharacterTuning.jumpZVelocity;
    final mesh = RecordingMesh();
    final driver = driverFor(mesh);
    character.addComponent(driver);
    character.addComponent(mesh);
    world.persistentLevel.registerActor(character);
    world.beginPlay();
    for (var i = 0; i < 30; i++) {
      world.tick(1 / 60);
    }
    if (character.characterMovement.isFalling) throw StateError('the rig must stand on the floor');
    return AnimRig._(world, character, mesh, driver is LuminaAnimBlueprintInstance ? driver : null);
  }

  /// Animated by `LuminaDirectionalLocomotionComponent`, as the template does.
  static AnimRig driver({double maxWalkSpeed = 300}) => _build(
        (mesh) => LuminaDirectionalLocomotionComponent(
          mesh: mesh,
          clips: LuminaThirdPersonContent.mannequinLocomotion,
          crossFadeDuration: LuminaTemplateCharacterTuning.locomotionCrossFade,
        ),
        maxWalkSpeed: maxWalkSpeed,
      );

  /// Animated by an Animation Blueprint instance from [factory].
  static AnimRig abp(LuminaAnimBlueprintFactory factory, {double maxWalkSpeed = 300}) =>
      _build(factory, maxWalkSpeed: maxWalkSpeed);

  AnimSample get sample => (clip: mesh.currentClip, rate: mesh.playRate);

  /// Ticks [frames] frames with [direction] (runtime space) as movement input.
  List<AnimSample> walk(Vector3 direction, int frames) {
    final samples = <AnimSample>[];
    for (var i = 0; i < frames; i++) {
      if (direction.length2 > 0) character.characterMovement.addInputVector(direction);
      world.tick(1 / 60);
      samples.add(sample);
    }
    return samples;
  }

  /// The scripted sequence the parity tests replay: still, forward, strafe
  /// right, turn and walk backward-left, jump (fall) and land walking, stop.
  List<AnimSample> script() => [
        ...walk(Vector3.zero(), 30),
        ...walk(Vector3(0, 0, -1), 60),
        ...walk(Vector3(1, 0, 0), 60),
        ...() {
          character.actorRotation = Quaternion.axisAngle(Vector3(0, 1, 0), 0.6);
          return walk(Vector3(-1, 0, 1), 60);
        }(),
        ...() {
          character.jump();
          return walk(Vector3(-1, 0, 1), 90);
        }(),
        ...walk(Vector3(0, 0, -1), 60),
        ...walk(Vector3.zero(), 60),
      ];
}

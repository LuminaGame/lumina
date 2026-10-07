import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

/// `baseEyeHeight` is measured from the actor location (the
/// capsule centre). It used to be set as a
/// height from the feet (160 cm), so the eye point, and every trace starting
/// there, sat 250 cm above the ground: about 1 m above the head.
void main() {
  const groundY = 0.0;

  /// A world with a 40 m blocking floor whose top is at [groundY].
  LuminaWorld yard() {
    final world = LuminaWorld(worldType: LuminaWorldType.game);
    world.registerSubsystem(LuminaCollisionSubsystem());
    final floor = LuminaActor(location: Vector3(0.0, groundY - 50.0, 0.0));
    final box = LuminaBoxComponent(boxExtent: Vector3(2000.0, 50.0, 2000.0));
    CollisionProfile.applyBlockAll(box);
    floor.addComponent(box);
    world.persistentLevel.registerActor(floor);
    return world;
  }

  /// Registers [character] (possessed, level control rotation), begins play
  /// and lets it fall onto the floor.
  LuminaPlayerController stand(LuminaWorld world, LuminaCharacter character) {
    final pc = LuminaPlayerController();
    world.persistentLevel.registerActor(character);
    pc.possess(character);
    pc.controlRotation.setValues(0.0, 0.0, 0.0);
    world.beginPlay();
    for (var i = 0; i < 120; i++) {
      world.tick(1 / 60);
    }
    final feet = character.actorLocation.y - character.capsuleComponent.halfHeight;
    expect(feet, closeTo(groundY, 2.0), reason: 'the character stands on the floor');
    expect(character.characterMovement.isGrounded, isTrue);
    return pc;
  }

  double eyeAboveGround(LuminaPawn pawn) => pawn.getActorEyesViewPoint().location.y - groundY;

  test('the Third Person template character sees from 160 cm above the ground', () {
    final world = yard();
    final character = LuminaTemplateCharacter(thirdPerson: true, location: Vector3(0.0, 200.0, 0.0));
    stand(world, character);
    expect(eyeAboveGround(character), closeTo(160.0, 5.0));
  });

  test('the First Person template character sees, and films, from 160 cm above the ground', () {
    final world = yard();
    final character = LuminaTemplateCharacter(thirdPerson: false, location: Vector3(0.0, 200.0, 0.0));
    stand(world, character);
    expect(eyeAboveGround(character), closeTo(160.0, 5.0));
    expect(character.cameraComponent.worldLocation.y - groundY, closeTo(160.0, 5.0),
        reason: 'the first-person camera sits at eye height from the feet');
  });

  test('a plain LuminaCharacter keeps its eyes at 90 % of its height from the feet', () {
    final world = yard();
    final character = LuminaCharacter(location: Vector3(0.0, 200.0, 0.0));
    stand(world, character);
    final height = character.capsuleComponent.halfHeight * 2.0;
    expect(eyeAboveGround(character), closeTo(0.9 * height, 1.0));
  });

  test('BP_ThirdPersonCharacter: the eye view point and Line Trace Forward start at head height', () {
    final actions = ProjectInputBinder.bind(GameTemplateCatalog.thirdPerson.input).actions.values.toList();
    final cls = LuminaBlueprintClass.fromDocument(
      LuminaThirdPersonContent.characterBlueprint(inputActions: actions, withMesh: false),
      name: 'BP_ThirdPersonCharacter',
      inputActions: actions,
    );
    expect(cls.diagnostics.where((d) => d.isError), isEmpty, reason: '${cls.diagnostics}');
    final world = yard();
    final character = cls.instantiate(location: Vector3(0.0, 200.0, 0.0)) as LuminaBlueprintCharacter;
    stand(world, character);

    final eyes = LuminaBlueprintFunctionLibrary.getActorEyesViewPoint(character);
    expect(eyes.location.z - groundY, closeTo(160.0, 5.0), reason: 'authoring Z up');

    world.debugShapes.clear();
    LuminaBlueprintFunctionLibrary.lineTraceForward(character, 500.0, 'Visibility', true);
    final line = world.debugShapes.lastWhere((s) => s.kind == LuminaDebugShapeKind.line);
    expect(line.points.first.y - groundY, closeTo(160.0, 5.0), reason: 'the trace starts at eye height: $line');
    expect(line.points.last.y, closeTo(line.points.first.y, 1e-6), reason: 'a level control rotation traces level');
  });
}

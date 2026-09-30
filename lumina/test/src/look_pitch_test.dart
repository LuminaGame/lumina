import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

/// Looking up is one direction everywhere: positive control pitch (what a
/// mouse moved up adds through Add Controller Pitch Input) raises the camera,
/// the control rotation's forward vector, the forward line trace, a pawn that
/// follows the controller's pitch and the aim offset, at every yaw.
void main() {
  const yaws = [0.0, 90.0, 180.0, -135.0];

  /// A Third Person character: capsule, a boom on the control rotation
  /// ([usePawnControlRotation]) without lag, and a follow camera.
  ({LuminaWorld world, LuminaBlueprintCharacter me, LuminaPlayerController pc, LuminaCameraComponent camera}) play(
      {bool usePawnControlRotation = true, bool useControllerPitch = false}) {
    final doc = LuminaBlueprintDocument(parentClass: 'LuminaCharacter', components: [
      LuminaBlueprintComponent(id: 'capsule', name: 'CapsuleComponent', type: 'LuminaCapsuleComponent'),
      LuminaBlueprintComponent(id: 'boom', name: 'CameraBoom', type: 'LuminaSpringArmComponent', parentId: 'capsule', properties: {
        'targetArmLength': 350.0,
        'usePawnControlRotation': usePawnControlRotation,
        'enableCameraLag': false,
        'enableCameraRotationLag': false,
        'doCollisionTest': false,
      }),
      LuminaBlueprintComponent(id: 'camera', name: 'FollowCamera', type: 'LuminaCameraComponent', parentId: 'boom'),
    ]);
    final cls = LuminaBlueprintClass.fromDocument(doc, name: 'BP_Looker');
    expect(cls.diagnostics, isEmpty, reason: '${cls.diagnostics}');
    final me = cls.instantiate(location: Vector3.zero()) as LuminaBlueprintCharacter;
    me.bUseControllerRotationYaw = true;
    me.bUseControllerRotationPitch = useControllerPitch;
    final world = LuminaWorld(worldType: LuminaWorldType.game);
    world.registerSubsystem(LuminaCollisionSubsystem());
    world.persistentLevel.registerActor(me);
    final pc = LuminaPlayerController();
    pc.possess(me);
    world.beginPlay();
    return (world: world, me: me, pc: pc, camera: me.components.whereType<LuminaCameraComponent>().single);
  }

  /// The camera's view direction in authoring axes (Z up).
  Vector3 cameraForward(LuminaCameraComponent camera) =>
      LuminaBlueprintFunctionLibrary.toAuthoring(camera.worldRotation.rotateVector(Vector3(0, 0, -1)));

  void expectSame(Vector3 actual, Vector3 expected, String reason) {
    for (var i = 0; i < 3; i++) {
      expect(actual[i], closeTo(expected[i], 1e-6), reason: '$reason: $actual vs $expected (axis $i)');
    }
  }

  test('pitch input up raises the camera, the control rotation forward and the forward trace together', () {
    for (final yaw in yaws) {
      final r = play();
      r.pc.controlRotation = Vector3(0.0, yaw, 0.0);
      LuminaBlueprintFunctionLibrary.addControllerPitchInput(r.me, 25.0);
      r.pc.onTick(1 / 60);
      r.world.tick(1 / 60);

      final camera = cameraForward(r.camera);
      expect(camera.z, closeTo(0.4226, 1e-3), reason: 'yaw $yaw: the camera looks 25° up');
      final control = LuminaBlueprintFunctionLibrary.getForwardVector(LuminaBlueprintFunctionLibrary.getControlRotation(r.me));
      expectSame(control, camera, 'yaw $yaw: Get Forward Vector of Get Control Rotation');
      expectSame(LuminaBlueprintFunctionLibrary.getLookForwardDirection(r.me), camera, 'yaw $yaw: the forward trace direction');
      final eyes = LuminaBlueprintFunctionLibrary.getActorEyesViewPoint(r.me);
      expectSame(LuminaBlueprintFunctionLibrary.getForwardVector(eyes.rotation), camera, 'yaw $yaw: Get Actor Eyes View Point rotation');
      final end = LuminaBlueprintFunctionLibrary.findLookAtLocation(r.me, 1000.0);
      expect(end.z - eyes.location.z, closeTo(422.6, 0.5), reason: 'yaw $yaw: the traced segment climbs with the camera');
    }
  });

  test('a rotator with positive pitch looks up and Make Rot From X inverts Get Forward Vector', () {
    for (final yaw in yaws) {
      final forward = LuminaBlueprintFunctionLibrary.getForwardVector(LuminaRotator(30.0, 0.0, yaw));
      expect(forward.z, closeTo(0.5, 1e-9), reason: 'yaw $yaw');
      final rot = LuminaBlueprintFunctionLibrary.makeRotFromX(forward);
      expect(rot.pitch, closeTo(30.0, 1e-9), reason: 'yaw $yaw');
      expectSame(LuminaBlueprintFunctionLibrary.getForwardVector(rot), forward, 'yaw $yaw: round trip');
    }
  });

  test('a pawn that follows the controller pitch pitches up, and a boom on the pawn follows it up', () {
    for (final yaw in yaws) {
      final r = play(usePawnControlRotation: false, useControllerPitch: true);
      r.pc.controlRotation = Vector3(20.0, yaw, 0.0);
      r.pc.onTick(1 / 60);
      r.world.tick(1 / 60);
      final body = LuminaBlueprintFunctionLibrary.toAuthoring(r.me.rootComponent.forwardVector);
      expect(body.z, closeTo(0.3420, 1e-3), reason: 'yaw $yaw: the pawn pitches up');
      expectSame(cameraForward(r.camera), body, 'yaw $yaw: the boom follows the pawn');
      final actorRot = LuminaBlueprintFunctionLibrary.getActorRotation(r.me);
      expect(actorRot.pitch, closeTo(20.0, 1e-6), reason: 'yaw $yaw: Get Actor Rotation reports the pitch');
      expectSame(LuminaBlueprintFunctionLibrary.getForwardVector(actorRot), body, 'yaw $yaw: Get Forward Vector of the actor');
    }
  });

  test('the pawn rotation convention is the control rotation convention', () {
    for (final (p, y, rl) in [(25.0, 0.0, 0.0), (-40.0, 90.0, 0.0), (15.0, 180.0, 10.0), (60.0, -135.0, -20.0)]) {
      final pawn = luminaPawnEulerToQuaternion(p, y, rl);
      final control = luminaControlRotationToQuaternion(p, y, rl);
      final dot = (pawn.x * control.x + pawn.y * control.y + pawn.z * control.z + pawn.w * control.w).abs();
      expect(dot, closeTo(1.0, 1e-9), reason: '($p, $y, $rl)');
      final back = luminaPawnQuaternionToEuler(pawn);
      expect(back.x, closeTo(p, 1e-6));
      expect(back.y, closeTo(y, 1e-6));
      expect(back.z, closeTo(rl, 1e-6));
    }
  });
}

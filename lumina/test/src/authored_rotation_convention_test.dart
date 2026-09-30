import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

/// One rotation convention for the numbers a person or an agent types: the
/// Details panel of a placed actor or a Blueprint component
/// (`LuminaAxes.rotation`, what generated level code and Play build), a
/// Blueprint rotator (Make Rotator, Get / Set Actor Rotation, Get Relative
/// Rotation) and the controller all read `[x, y, z]` as pitch, roll, yaw with
/// yaw 0 facing +Y, yaw 90 facing +X (positive yaw turns right) and a positive
/// pitch looking up.
void main() {
  const triples = [
    [0.0, 0.0, 90.0],
    [0.0, 0.0, -90.0],
    [0.0, 0.0, 180.0],
    [30.0, 0.0, 0.0],
    [0.0, 20.0, 0.0],
    [25.0, -10.0, 135.0],
    [-40.0, 15.0, -60.0],
  ];

  void expectVector(Vector3 actual, List<double> expected, String reason) {
    for (var i = 0; i < 3; i++) {
      expect(actual[i], closeTo(expected[i], 1e-6), reason: '$reason: $actual vs $expected (axis $i)');
    }
  }

  double quatDot(Quaternion a, Quaternion b) => (a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w).abs();

  /// The drawn forward (runtime −Z) of [q], in authoring axes.
  Vector3 forwardOf(Quaternion q) => LuminaBlueprintFunctionLibrary.toAuthoring(q.rotateVector(Vector3(0, 0, -1)));

  test('an actor placed at yaw 90 faces +X and Get Actor Rotation reads the placed values back', () {
    final placed = LuminaActor(location: Vector3.zero(), rotation: LuminaAxes.rotation(const [0.0, 0.0, 90.0]));
    expectVector(forwardOf(placed.actorRotation), [1, 0, 0], 'drawn forward at yaw 90');
    expectVector(LuminaBlueprintFunctionLibrary.getActorForwardVector(placed), [1, 0, 0], 'Get Actor Forward Vector');
    final read = LuminaBlueprintFunctionLibrary.getActorRotation(placed);
    expect(read.yaw, closeTo(90.0, 1e-6), reason: 'Get Actor Rotation of an actor placed at yaw 90: $read');

    for (final t in triples) {
      final actor = LuminaActor(location: Vector3.zero(), rotation: LuminaAxes.rotation(t));
      final r = LuminaBlueprintFunctionLibrary.getActorRotation(actor);
      final back = LuminaAxes.rotation(r.toList());
      expect(quatDot(back, actor.actorRotation), closeTo(1.0, 1e-9), reason: 'placed $t reads back as $r');
      expect(r.pitch, closeTo(t[0], 1e-6), reason: 'placed $t: pitch');
      expect(r.roll, closeTo(t[1], 1e-6), reason: 'placed $t: roll');
      expect(r.yaw, closeTo(t[2], 1e-6), reason: 'placed $t: yaw');
    }
  });

  test('Set Actor Rotation with the Details values turns the actor the way the level places it', () {
    for (final t in triples) {
      final actor = LuminaActor(location: Vector3.zero());
      LuminaBlueprintFunctionLibrary.setActorRotation(actor, null, LuminaRotator.fromList(t));
      expect(quatDot(actor.actorRotation, LuminaAxes.rotation(t)), closeTo(1.0, 1e-9), reason: 'rotator $t');
      final forward = LuminaBlueprintFunctionLibrary.getForwardVector(LuminaRotator.fromList(t));
      expectVector(forward, forwardOf(LuminaAxes.rotation(t)).storage.toList(), 'Get Forward Vector of $t');
    }
  });

  test('yaw turns right and pitch looks up in the Details convention', () {
    expectVector(forwardOf(LuminaAxes.rotation(const [0.0, 0.0, 0.0])), [0, 1, 0], 'yaw 0');
    expectVector(forwardOf(LuminaAxes.rotation(const [0.0, 0.0, 90.0])), [1, 0, 0], 'yaw 90');
    expectVector(forwardOf(LuminaAxes.rotation(const [0.0, 0.0, -90.0])), [-1, 0, 0], 'yaw -90');
    expectVector(forwardOf(LuminaAxes.rotation(const [0.0, 0.0, 180.0])), [0, -1, 0], 'yaw 180');
    final up30 = forwardOf(LuminaAxes.rotation(const [30.0, 0.0, 0.0]));
    expect(up30.z, closeTo(0.5, 1e-9), reason: 'pitch 30 looks 30° up: $up30');
    // The controller's yaw is the same yaw: control yaw 90 faces where a
    // placed yaw 90 faces.
    expectVector(forwardOf(luminaControlRotationToQuaternion(0, 90, 0)), [1, 0, 0], 'control yaw 90');
  });

  test('a Blueprint component rotated [0, 0, 90] faces +X and Get Relative Rotation reads it back', () {
    final doc = LuminaBlueprintDocument(parentClass: 'LuminaActor', components: [
      LuminaBlueprintComponent(id: 'root', name: 'Root', type: 'LuminaSceneComponent'),
      LuminaBlueprintComponent(id: 'arrow', name: 'Arrow', type: 'LuminaSceneComponent', parentId: 'root', properties: {
        'location': [0.0, 0.0, 0.0],
        'rotation': [0.0, 0.0, 90.0],
        'scale': [1.0, 1.0, 1.0],
      }),
    ]);
    final cls = LuminaBlueprintClass.fromDocument(doc, name: 'BP_Arrow');
    expect(cls.diagnostics, isEmpty, reason: '${cls.diagnostics}');
    final actor = cls.instantiate(location: Vector3.zero());
    final arrow = (actor as LuminaBlueprintRuntime).blueprintComponents['arrow'] as LuminaSceneComponent;
    expectVector(forwardOf(arrow.worldRotation), [1, 0, 0], 'component forward');
    final rel = LuminaBlueprintFunctionLibrary.getRelativeRotation(arrow);
    expect(rel.yaw, closeTo(90.0, 1e-6), reason: 'Get Relative Rotation: $rel');
  });
}

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

import 'grab_fixture.dart';

void main() {
  test('a cursor over the projected hand in an 800×600 view, left-drag 100 px right: the hand moves along the camera right by the cm of that depth', () {
    final r = GrabRun();
    final hand = r.handle('hand_r');
    final mouse = LuminaMouseGrabber();
    mouse.viewportSize.setValues(800, 600);
    mouse.fovYDegrees = 50;
    // The camera 2.5 m in front of the character, a little above, looking at the chest.
    final eye = Vector3(40, 160, 250);
    final look = (Vector3(0, 130, 0) - eye).normalized();
    final right = look.cross(Vector3(0, 1, 0)).normalized();
    final up = right.cross(look);
    mouse.cameraLocation.setFrom(eye);
    mouse.cameraRotation.setFrom(Quaternion.fromRotation(Matrix3.columns(right, up, -look))..normalize());
    // The hand's pixel.
    final d = hand - eye;
    final z = d.dot(look);
    final tanHalf = math.tan(25 * math.pi / 180);
    mouse.cursor.setValues((d.dot(right) / (z * tanHalf * 800 / 600) + 1) * 400, (1 - d.dot(up) / (z * tanHalf)) * 300);
    r.interactor.registerGrabber(mouse);

    r.tick();
    expect(r.interactor.hoveredBy(mouse)?.handle, 'hand_r', reason: 'the ray through the cursor finds the hand');
    mouse.leftDown = true;
    r.tick();
    expect(r.interactor.heldBy(mouse)?.handle, 'hand_r');
    expect(mouse.depth, closeTo(z, 1e-9), reason: 'the mouse holds at the depth it grabbed at');
    expect(r.handle('hand_r').distanceTo(hand), lessThan(1e-6));
    for (var i = 1; i <= 10; i++) {
      mouse.cursor.x += 10;
      r.tick();
    }
    final cm = 100 * 2 * tanHalf * (800 / 600) * z / 800;
    expect(r.handle('hand_r').distanceTo(hand + right * cm), lessThan(0.05));
    mouse.leftDown = false;
    r.tick();
    expect(r.released, ['hand_r@mouse']);

    // The wheel pushes the held depth away.
    mouse.wheel(-2);
    expect(mouse.depth, closeTo(z + 20, 1e-9));
    expect(mouse.grip, 0);
    expect(mouse.isTracked, isTrue);
  });

  test("syncFromWorld reads the world's view, viewport size, injected cursor and left button", () {
    final world = LuminaWorld(worldType: LuminaWorldType.game);
    addTearDown(world.cleanup);
    final input = world.registerSubsystem(LuminaInputSubsystem());
    world.viewportSize = (640, 480);
    world.viewTargetPov = LuminaMinimalViewInfo()
      ..location = Vector3(1, 2, 3)
      ..fovDegrees = 70;
    input.injectMousePosition(Vector2(100, 50));
    final mouse = LuminaMouseGrabber();
    expect(mouse.syncFromWorld(world), isTrue);
    expect(mouse.viewportSize, Vector2(640, 480));
    expect(mouse.cameraLocation, Vector3(1, 2, 3));
    expect(mouse.fovYDegrees, 70);
    expect(mouse.cursor, Vector2(100, 50));
    expect(mouse.leftDown, isFalse);
  });
}

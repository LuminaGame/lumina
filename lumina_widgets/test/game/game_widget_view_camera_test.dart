import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_widgets/lumina_widgets.dart';
import 'package:vector_math/vector_math_64.dart';

/// A running game must render through its active camera component,
/// not through whatever camera the Filament view was created with.

/// An actor carrying an active camera, yawed so position and direction both
/// differ from the view's default camera at the origin looking down -Z.
LuminaActor _cameraActor(LuminaCameraComponent camera) =>
    LuminaActor(root: camera, location: Vector3(4.0, 2.0, 10.0));

LuminaCameraComponent _activeCamera() => LuminaCameraComponent(
      rotation: Quaternion.axisAngle(Vector3(0, 1, 0), math.pi / 3),
      fieldOfViewInDegrees: 70.0,
    )..isActive = true;

class _CameraGame extends LuminaGame {
  _CameraGame(this.camera);
  final LuminaCameraComponent camera;

  @override
  LuminaObject? build(LuminaBuildContext context) =>
      LuminaNodeGroup(children: [_cameraActor(camera)]);
}

void _expectViewThrough(FilamentCamera viewCamera, LuminaCameraComponent camera, {required double aspect}) {
  final eye = camera.worldLocation;
  final forward = camera.forwardVector..normalize();
  expect(viewCamera.position.x, closeTo(eye.x, 1e-3));
  expect(viewCamera.position.y, closeTo(eye.y, 1e-3));
  expect(viewCamera.position.z, closeTo(eye.z, 1e-3));
  final viewForward = viewCamera.forwardVector..normalize();
  expect(viewForward.dot(forward), closeTo(1.0, 1e-3), reason: 'the view must look where the camera component looks');
  expect(viewCamera.getFieldOfViewInDegrees(FovDirection.vertical), closeTo(camera.fieldOfViewInDegrees, 1e-2));
  final p = viewCamera.projectionMatrix;
  expect(p.entry(1, 1) / p.entry(0, 0), closeTo(aspect, 1e-3), reason: 'aspect ratio from the view viewport');
}

void main() {
  group('a game renders through its active camera', () {
    testWidgets('LuminaGameWidget renders the game through its active camera', (tester) async {
      final camera = _activeCamera();
      final game = _CameraGame(camera);
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(width: 320, height: 180, child: LuminaGameWidget(game: game)),
      ));
      await tester.pump();
      await tester.pump();
      if (game.playState == LuminaPlayState.stopped) {
        await tester.pumpWidget(const SizedBox.shrink());
        markTestSkipped('FilamentWidget did not create a scene in the test binding');
        return;
      }
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump(const Duration(milliseconds: 20));

      final view = game.world!.filamentViewOrNull;
      expect(view, isNotNull, reason: "the widget must bind its Filament view into the game's world");
      final (_, _, w, h) = view!.viewport;
      _expectViewThrough(view.camera!, camera, aspect: w / h);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });
}

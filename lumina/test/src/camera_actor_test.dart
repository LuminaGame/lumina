import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

/// A placed camera's settings: one property map (the level's camera
/// component, the Blueprint camera component) read the same way by the
/// editor, Play, the generated game and the Blueprint component mapping; a
/// camera actor set to auto-activate becomes the player's view target, and
/// the view looks through its own projection, clip planes and exposure.
void main() {
  group('LuminaCameraSettings', () {
    test('reads the shared property names in degrees and centimetres, and writes them back', () {
      final settings = LuminaCameraSettings.fromProperties(const {
        'fieldOfView': 30.0,
        'projectionMode': 'Orthographic',
        'orthoWidth': 2500.0,
        'nearClipPlane': 5.0,
        'farClipPlane': 20000.0,
        'autoExposure': false,
        'aperture': 2.8,
        'shutterSpeed': 1 / 60,
        'sensitivity': 400.0,
        'autoActivateForPlayer': true,
      });
      expect(settings.fieldOfView, 30.0);
      expect(settings.projectionMode, CameraProjectionMode.orthographic);
      expect(settings.orthoWidth, 2500.0);
      expect(settings.nearClipPlane, 5.0);
      expect(settings.farClipPlane, 20000.0);
      expect(settings.autoExposure, isFalse);
      expect(settings.aperture, 2.8);
      expect(settings.shutterSpeed, closeTo(1 / 60, 1e-12));
      expect(settings.sensitivity, 400.0);
      expect(settings.autoActivateForPlayer, isTrue);
      expect(LuminaCameraSettings.fromProperties(settings.toProperties()).toProperties(), settings.toProperties());
    });

    test('a missing or broken value keeps the runtime camera default', () {
      final settings = LuminaCameraSettings.fromProperties(const {'fieldOfView': 'wide', 'nearClipPlane': -3.0, 'farClipPlane': 1.0});
      final camera = LuminaCameraComponent();
      expect(settings.fieldOfView, camera.fieldOfViewInDegrees);
      expect(settings.nearClipPlane, greaterThan(0.0));
      expect(settings.farClipPlane, greaterThan(settings.nearClipPlane));
      expect(settings.projectionMode, CameraProjectionMode.perspective);
      expect(settings.autoActivateForPlayer, isFalse);
    });

    test('the Blueprint camera component reads the same names', () {
      final built = LuminaBlueprintComponents.construct(LuminaActor(), [
        LuminaBlueprintComponent(id: 'cam', name: 'Camera', type: 'LuminaCameraComponent', properties: <String, dynamic>{
          'fieldOfView': 35.0,
          'projectionMode': 'Orthographic',
          'orthoWidth': 800.0,
          'autoExposure': false,
          'aperture': 4.0,
        }),
      ]);
      final camera = built['cam'] as LuminaCameraComponent;
      expect(camera.fieldOfViewInDegrees, 35.0);
      expect(camera.projectionMode, CameraProjectionMode.orthographic);
      expect(camera.orthographicWidth, 800.0);
      expect(camera.autoExposure, isFalse);
      expect(camera.aperture, 4.0);
      expect(camera.isActive, isTrue, reason: 'a Blueprint camera still auto-activates');
    });
  });

  group('LuminaCameraActor', () {
    test('carries its settings on an inactive camera component at its transform', () {
      final actor = LuminaCameraActor(
        location: Vector3(100, 200, 300),
        settings: LuminaCameraSettings.fromProperties(const {'fieldOfView': 30.0, 'nearClipPlane': 2.0, 'aperture': 8.0, 'autoExposure': false}),
      );
      final camera = actor.cameraComponent;
      expect(actor.components, contains(camera));
      expect(camera.fieldOfViewInDegrees, 30.0);
      expect(camera.nearClipPlane, 2.0);
      expect(camera.aperture, 8.0);
      expect(camera.autoExposure, isFalse);
      expect(camera.isActive, isFalse, reason: 'a level camera never takes the view from the pawn by itself');
      expect(camera.worldLocation, Vector3(100, 200, 300));
    });

    test('Auto Activate for Player makes it the player\'s view target, seen with its own field of view and clip planes', () {
      final world = LuminaWorld();
      final mode = LuminaGameMode();
      world.gameMode = mode;
      world.persistentLevel.registerActor(LuminaPlayerStart());
      final camera = LuminaCameraActor(
        location: Vector3(0, 150, 600),
        settings: LuminaCameraSettings.fromProperties(const {'fieldOfView': 30.0, 'nearClipPlane': 4.0, 'farClipPlane': 9000.0, 'autoActivateForPlayer': true}),
      );
      final other = LuminaCameraActor(settings: const LuminaCameraSettings(fieldOfView: 75.0));
      world.persistentLevel.registerActor(other);
      world.persistentLevel.registerActor(camera);
      world.beginPlay();

      final controller = mode.login();
      expect(controller.cameraManager.viewTarget, same(camera));
      controller.cameraManager.updateCamera(1 / 60);
      final pov = world.viewTargetPov;
      expect(pov, isNotNull, reason: 'the world renders the view target, not the pawn');
      expect(pov!.fovDegrees, 30.0);
      expect(pov.camera, same(camera.cameraComponent));
      expect(pov.nearClip, 4.0);
      expect(pov.farClip, 9000.0);
      expect(pov.location, Vector3(0, 150, 600));
    });

    test('without Auto Activate the player keeps looking through the pawn', () {
      final world = LuminaWorld();
      final mode = LuminaGameMode();
      world.gameMode = mode;
      world.persistentLevel.registerActor(LuminaPlayerStart());
      world.persistentLevel.registerActor(LuminaCameraActor(settings: const LuminaCameraSettings(fieldOfView: 30.0)));
      world.beginPlay();
      final controller = mode.login();
      controller.cameraManager.updateCamera(1 / 60);
      expect(controller.cameraManager.viewTarget, same(controller.pawn));
    });
  });
}

import 'dart:math' as math;

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
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
    test('a world bound to a view drives the view camera from its active camera', () {
      final engine = FilamentEngine.create()!;
      final scene = engine.createScene();
      final view = engine.createView();
      final defaultCamera = engine.createCamera(engine.createEntity());
      view.scene = scene;
      view.camera = defaultCamera;
      view.setViewport(0, 0, 1280, 720);

      final world = LuminaWorld(worldType: LuminaWorldType.game);
      world.initializeNativeContext(engine, scene, view: view);
      final camera = _activeCamera();
      world.persistentLevel.registerActor(_cameraActor(camera));
      world.beginPlay();
      world.tick(1 / 60);

      _expectViewThrough(view.camera!, camera, aspect: 1280 / 720);

      // A resized view re-syncs the aspect ratio on the next frame.
      view.setViewport(0, 0, 800, 800);
      world.tick(1 / 60);
      _expectViewThrough(view.camera!, camera, aspect: 1.0);

      world.cleanup();
      view.dispose();
      scene.dispose();
      engine.dispose();
    });

    test("the possessed pawn's camera wins over an active camera on a character placed earlier in the level", () {
      final engine = FilamentEngine.create()!;
      final scene = engine.createScene();
      final view = engine.createView();
      view.scene = scene;
      view.camera = engine.createCamera(engine.createEntity());
      view.setViewport(0, 0, 1280, 720);

      final world = LuminaWorld(worldType: LuminaWorldType.game);
      world.initializeNativeContext(engine, scene, view: view);
      // A character placed in the level, registered first: its spring-arm
      // camera is active, but nobody controls it.
      final placedCamera = _activeCamera();
      world.persistentLevel.registerActor(LuminaPawn(root: placedCamera, location: Vector3(800.0, 0.0, -90.0)));
      // The pawn the game mode spawned for the player.
      final playerCamera = LuminaCameraComponent(fieldOfViewInDegrees: 55.0)..isActive = true;
      final player = LuminaPawn(root: playerCamera, location: Vector3(0.0, 90.0, 1200.0));
      world.persistentLevel.registerActor(player);
      final pc = LuminaPlayerController();
      pc.possess(player);
      world.beginPlay();
      pc.onTick(1 / 60);
      world.tick(1 / 60);

      expect(world.activeCamera, same(playerCamera));
      _expectViewThrough(view.camera!, playerCamera, aspect: 1280 / 720);

      // The player walks: the view follows the pawn, not the placed character.
      player.actorLocation = Vector3(0.0, 90.0, 800.0);
      pc.onTick(1 / 60);
      world.tick(1 / 60);
      _expectViewThrough(view.camera!, playerCamera, aspect: 1280 / 720);

      // Unpossessed, the world falls back to the first active camera.
      pc.unpossess();
      pc.onTick(1 / 60);
      world.tick(1 / 60);
      expect(world.activeCamera, same(placedCamera));

      world.cleanup();
      view.dispose();
      scene.dispose();
      engine.dispose();
    });
  });
}

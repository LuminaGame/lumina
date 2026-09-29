import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/lumina.dart';

void main() {
  group('LuminaViewportStatics Tests', () {
    test('Hit mapping: fake pick resolves entity and maps to registered component and actor', () async {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final actor = LuminaActor();
      final comp = LuminaSceneComponent();
      actor.addComponent(comp);
      world.entityRegistry.registerEntities([6], comp);

      final result = await LuminaViewportStatics.pickAtScreen(
        world,
        100.0,
        100.0,
        pickOverride: (x, y) async {
          return PickingResult(
            FilamentEntity(6),
            0.5,
            (100.0, 500.0),
          );
        },
      );

      expect(result.hasHit, isTrue);
      expect(result.entity, equals(6));
      expect(result.component, same(comp));
      expect(result.actor, same(actor));
      expect(result.depth, equals(0.5));
      expect(result.fragCoords, equals((100.0, 500.0)));
    });

    test('Miss: fake pick resolves null renderable and completes without hanging', () async {
      final world = LuminaWorld(worldType: LuminaWorldType.game);

      final result = await LuminaViewportStatics.pickAtScreen(
        world,
        50.0,
        50.0,
        pickOverride: (x, y) async {
          return PickingResult(null, 0.0, (50.0, 550.0));
        },
      );

      expect(result.hasHit, isFalse);
      expect(result.actor, isNull);
      expect(result.component, isNull);
      expect(result.worldLocation, isNull);
    });

    test('Y-flip: viewport 800x600 top-left (10, 20) translates to bottom-left (10, 579)', () async {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      int? receivedX;
      int? receivedY;

      await LuminaViewportStatics.pickAtScreen(
        world,
        10.0,
        20.0,
        viewportWidth: 800,
        viewportHeight: 600,
        pickOverride: (x, y) async {
          receivedX = x;
          receivedY = y;
          return PickingResult(null, 0.0, (x.toDouble(), y.toDouble()));
        },
      );

      expect(receivedX, equals(10));
      expect(receivedY, equals(579)); // 600 - 20 - 1
    });

    test('Unprojection: camera at origin looking down -Z reconstructs worldLocation', () async {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final proj = makePerspectiveMatrix(math.pi / 2.0, 1.0, 0.1, 100.0);
      final view = makeViewMatrix(Vector3(0, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0));
      final vp = proj * view;
      final invVP = Matrix4.inverted(vp);

      // Project (0, 0, -10)
      final clip = vp.transform(Vector4(0.0, 0.0, -10.0, 1.0));
      final ndcZ = clip.z / clip.w;
      final depth = (ndcZ + 1.0) / 2.0;

      final result = await LuminaViewportStatics.pickAtScreen(
        world,
        400.0,
        300.0,
        viewportWidth: 800,
        viewportHeight: 600,
        customInvViewProj: invVP,
        pickOverride: (x, y) async {
          return PickingResult(
            FilamentEntity(12),
            depth,
            (400.0, 300.0),
          );
        },
      );

      expect(result.hasHit, isTrue);
      expect(result.worldLocation, isNotNull);
      expect(result.worldLocation!.x, closeTo(0.0, 1e-3));
      expect(result.worldLocation!.y, closeTo(0.0, 1e-3));
      expect(result.worldLocation!.z, closeTo(-10.0, 1e-3));
    });

    test('Unregistered entity hit yields hasHit true with null actor and component', () async {
      final world = LuminaWorld(worldType: LuminaWorldType.game);

      final result = await LuminaViewportStatics.pickAtScreen(
        world,
        100.0,
        100.0,
        pickOverride: (x, y) async {
          return PickingResult(
            FilamentEntity(999),
            0.5,
            (100.0, 500.0),
          );
        },
      );

      expect(result.hasHit, isTrue);
      expect(result.entity, equals(999));
      expect(result.component, isNull);
      expect(result.actor, isNull);
    });

    test('Two in-flight picks at different pixels complete independently without cross-talk', () async {
      final world = LuminaWorld(worldType: LuminaWorldType.game);

      final future1 = LuminaViewportStatics.pickAtScreen(
        world,
        10.0,
        10.0,
        pickOverride: (x, y) async {
          await Future.delayed(const Duration(milliseconds: 10));
          return PickingResult(FilamentEntity(1), 0.1, (10.0, 590.0));
        },
      );

      final future2 = LuminaViewportStatics.pickAtScreen(
        world,
        20.0,
        20.0,
        pickOverride: (x, y) async {
          return PickingResult(FilamentEntity(2), 0.2, (20.0, 580.0));
        },
      );

      final res2 = await future2;
      final res1 = await future1;

      expect(res1.entity, equals(1));
      expect(res2.entity, equals(2));
      expect(res1.depth, equals(0.1));
      expect(res2.depth, equals(0.2));
    });

    test('screenToWorldRay calculates ray direction from screen coordinates', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final proj = makePerspectiveMatrix(math.pi / 2.0, 1.0, 0.1, 100.0);
      final view = makeViewMatrix(Vector3(0, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0));
      final invVP = Matrix4.inverted(proj * view);

      final ray = LuminaViewportStatics.screenToWorldRay(
        world,
        400.0,
        300.0,
        viewportWidth: 800,
        viewportHeight: 600,
        customInvViewProj: invVP,
      );

      expect(ray.$1.x, closeTo(0.0, 1e-3));
      expect(ray.$1.y, closeTo(0.0, 1e-3));
      expect(ray.$2.z, lessThan(-0.99));
    });

    test('Row flip: 1x2 fake readback swaps bottom row and top row', () {
      // 1x2 image: Bottom row (row 0 in bottom-left readback) = Red [255, 0, 0, 255]
      // Top row (row 1 in bottom-left readback) = Blue [0, 0, 255, 255]
      final rawBottomUp = Uint8List.fromList([
        255, 0, 0, 255, // Row 0 (bottom)
        0, 0, 255, 255, // Row 1 (top)
      ]);

      final flippedTopDown = LuminaViewportStatics.flipRowsVertically(rawBottomUp, 1, 2);

      // In top-down image order: Row 0 must be Blue, Row 1 must be Red
      expect(flippedTopDown.sublist(0, 4), equals([0, 0, 255, 255]));
      expect(flippedTopDown.sublist(4, 8), equals([255, 0, 0, 255]));
    });

    test('Forcing capture between beginFrame and endFrame throws StateError', () async {
      final world = LuminaWorld(worldType: LuminaWorldType.game);

      expect(
        () => LuminaViewportStatics.captureScreenshot(world, isInsideFrame: true),
        throwsA(isA<StateError>()),
      );
    });

    test('world.cleanup cancels pending picks and screenshots with error', () async {
      final world = LuminaWorld(worldType: LuminaWorldType.game);

      final pickFuture = LuminaViewportStatics.pickAtScreen(
        world,
        100.0,
        100.0,
        pickOverride: (x, y) async {
          final c = Completer<PickingResult>();
          return c.future; // never completes naturally
        },
      );

      expect(LuminaViewportStatics.inFlightPicks, equals(1));
      final errorExpectation = expectLater(pickFuture, throwsA(isA<StateError>()));
      world.cleanup();

      await errorExpectation;
      expect(LuminaViewportStatics.inFlightPicks, equals(0));
    });
  });
}

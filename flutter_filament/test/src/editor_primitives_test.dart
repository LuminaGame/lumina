import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';

void main() {
  group('Editor Primitives API Tests', () {
    test('FilamentEditorGrid lifecycle and scene attachment', () {
      final engine = FilamentEngine.create(backend: FilamentBackend.noop);
      expect(engine, isNotNull);

      final scene = engine!.createScene();
      final grid = FilamentEditorGrid.create(
        engine: engine,
        extent: 500.0,
        step: 50.0,
      );

      expect(grid.entityId, isNotNull);
      expect(grid.isDisposed, isFalse);

      grid.addToScene(scene);
      grid.removeFromScene(scene);

      grid.dispose();
      expect(grid.isDisposed, isTrue);

      scene.dispose();
      engine.dispose();
    });

    test('FilamentSelectionBox bounds update and transforms', () {
      final engine = FilamentEngine.create(backend: FilamentBackend.noop);
      expect(engine, isNotNull);

      final scene = engine!.createScene();
      final selBox = FilamentSelectionBox(engine);

      expect(selBox.isDisposed, isFalse);

      selBox.updateBounds(
        scene: scene,
        minBounds: [-50.0, -50.0, 0.0],
        maxBounds: [50.0, 50.0, 100.0],
      );

      expect(selBox.entityId, isNotNull);

      selBox.addToScene(scene);
      selBox.setTransform([
        1.0,
        0.0,
        0.0,
        0.0,
        0.0,
        1.0,
        0.0,
        0.0,
        0.0,
        0.0,
        1.0,
        0.0,
        10.0,
        20.0,
        30.0,
        1.0,
      ]);
      selBox.removeFromScene(scene);

      selBox.dispose();
      expect(selBox.isDisposed, isTrue);

      scene.dispose();
      engine.dispose();
    });

    test(
      'every handle owns a material instance, so its colour reaches the renderer',
      () {
        // The wireframe material used to be compiled at runtime with filamat and
        // failed here, which left every handle without a material instance.
        // Filament then drew the lines with its own default white material and
        // ignored every setColor: the manipulator, the grid and the selection
        // boxes were all permanently white, with nothing else looking wrong.
        final engine = FilamentEngine.create(backend: FilamentBackend.noop);
        final gizmo = FilamentTransformGizmo(engine!);

        expect(
          gizmo.handlesAreColourable,
          isTrue,
          reason: 'the wireframe material did not compile',
        );

        gizmo.setMode(GizmoMode.rotate);
        expect(
          gizmo.handlesAreColourable,
          isTrue,
          reason: 'after a mode change',
        );

        gizmo.dispose();
        engine.dispose();
      },
    );

    test(
      'gizmo handles are born coloured, per axis, without waiting for a hover',
      () {
        final engine = FilamentEngine.create(backend: FilamentBackend.noop);
        expect(engine, isNotNull);
        final gizmo = FilamentTransformGizmo(engine!);

        // Red X, green Y, blue Z — the arrows used to be white until the editor
        // happened to call setAllHandlesDimmed, so a freshly selected actor got a
        // colourless gizmo with no hint of which arrow is which axis.
        expect(gizmo.colorOf('X'), isNotNull);
        expect(gizmo.colorOf('X')![0], greaterThan(0.8));
        expect(gizmo.colorOf('X')![1], lessThan(0.5));
        expect(gizmo.colorOf('Y')![1], greaterThan(0.8));
        expect(gizmo.colorOf('Y')![0], lessThan(0.5));
        expect(gizmo.colorOf('Z')![2], greaterThan(0.8));
        expect(gizmo.colorOf('Z')![0], lessThan(0.5));

        gizmo.dispose();
        engine.dispose();
      },
    );

    test('switching mode rebuilds the handles already coloured', () {
      final engine = FilamentEngine.create(backend: FilamentBackend.noop);
      final gizmo = FilamentTransformGizmo(engine!);

      gizmo.setMode(GizmoMode.rotate);
      for (final id in gizmo.handleIds) {
        expect(
          gizmo.colorOf(id),
          isNotNull,
          reason: '$id has no colour after a mode change',
        );
      }
      expect(gizmo.colorOf('X')![0], greaterThan(0.8));

      gizmo.dispose();
      engine.dispose();
    });

    test(
      'hovering paints the handle yellow and leaves the other axes coloured',
      () {
        final engine = FilamentEngine.create(backend: FilamentBackend.noop);
        final gizmo = FilamentTransformGizmo(engine!);

        gizmo.setAllHandlesDimmed('X');
        expect(gizmo.colorOf('X')![0], greaterThan(0.8));
        expect(
          gizmo.colorOf('X')![1],
          greaterThan(0.8),
          reason: 'the hovered handle is yellow',
        );
        expect(
          gizmo.colorOf('Y')![1],
          greaterThan(0.8),
          reason: 'the other axes keep their colour',
        );
        expect(gizmo.colorOf('Y')![0], lessThan(0.5));

        gizmo.setAllHandlesDimmed(null);
        expect(gizmo.colorOf('Y')![1], greaterThan(0.8));
        expect(
          gizmo.colorOf('X')![1],
          lessThan(0.5),
          reason: 'X is red again, not yellow',
        );

        gizmo.dispose();
        engine.dispose();
      },
    );

    test('FilamentTransformGizmo creation and positioning', () {
      final engine = FilamentEngine.create(backend: FilamentBackend.noop);
      expect(engine, isNotNull);

      final scene = engine!.createScene();
      final gizmo = FilamentTransformGizmo(engine);

      expect(gizmo.entityIds, isNotEmpty);
      expect(gizmo.handleIds.length, equals(gizmo.entityIds.length));
      expect(
        gizmo.entityIdOf(gizmo.handleIds.first),
        equals(gizmo.entityIds.first),
      );
      expect(gizmo.entityIdOf('no_such_handle'), isNull);
      expect(gizmo.isDisposed, isFalse);

      gizmo.addToScene(scene);
      gizmo.setPosition(100.0, -50.0, 0.0);
      gizmo.removeFromScene(scene);

      gizmo.dispose();
      expect(gizmo.isDisposed, isTrue);

      scene.dispose();
      engine.dispose();
    });

    test(
      'FilamentTransformGizmo matrix correctly maps Z-up to Filament Y-up',
      () {
        final engine = FilamentEngine.create(backend: FilamentBackend.noop);
        final gizmo = FilamentTransformGizmo(engine!);

        gizmo.setPosition(10.0, 20.0, 30.0, 2.0);
        final m = gizmo.lastTransform;
        // Translation: (x, z, -y)
        expect(m[12], equals(10.0));
        expect(m[13], equals(30.0));
        expect(m[14], equals(-20.0));

        // Column 0: X axis (Editor +X -> Filament +X)
        expect(m[0], equals(2.0));
        expect(m[1], equals(0.0));
        expect(m[2], equals(0.0));

        // Column 1: Y axis (Editor +Y -> Filament -Z)
        expect(m[4], equals(0.0));
        expect(m[5], equals(0.0));
        expect(m[6], equals(-2.0));

        // Column 2: Z axis (Editor +Z -> Filament +Y, pointing UP)
        expect(m[8], equals(0.0));
        expect(m[9], equals(2.0));
        expect(m[10], equals(0.0));

        gizmo.dispose();
        engine.dispose();
      },
    );
  });
}

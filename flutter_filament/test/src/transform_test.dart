import 'dart:math' as math;
import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  group('TransformManager Tests', () {
    late FilamentEngine engine;
    late FilamentTransformManager tm;

    setUp(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
      tm = FilamentTransformManager(engine);
    });

    tearDown(() {
      if (!engine.isDisposed) engine.dispose();
    });

    group('Transactions (Task 02)', () {
      test('Local transform transaction batches updates on hierarchy', () {
        final root = engine.createEntity();
        final child = engine.createEntity();
        final grandchild = engine.createEntity();

        tm.create(root);
        tm.create(child, parent: root);
        tm.create(grandchild, parent: child);

        final tRoot = (Matrix4.identity()..setTranslationRaw(10.0, 0.0, 0.0)).storage;
        final tChild = (Matrix4.identity()..setTranslationRaw(0.0, 5.0, 0.0)).storage;
        final tGrandchild = (Matrix4.identity()..setTranslationRaw(0.0, 0.0, 2.0)).storage;

        tm.transaction(() {
          for (var i = 0; i < 100; i++) {
            tm.setTransform(root, tRoot);
            tm.setTransform(child, tChild);
            tm.setTransform(grandchild, tGrandchild);
          }
        });

        final worldGrandchild = tm.getWorldTransform(grandchild);
        expect(worldGrandchild[12], closeTo(10.0, 1e-5));
        expect(worldGrandchild[13], closeTo(5.0, 1e-5));
        expect(worldGrandchild[14], closeTo(2.0, 1e-5));

        engine.destroyEntity(grandchild);
        engine.destroyEntity(child);
        engine.destroyEntity(root);
      });

      test('Exception safety: transaction commits on throw', () {
        final e = engine.createEntity();
        tm.create(e);

        final t1 = (Matrix4.identity()..setTranslationRaw(3.0, 4.0, 5.0)).storage;

        expect(
          () => tm.transaction(() {
            tm.setTransform(e, t1);
            throw Exception('Abort transaction');
          }),
          throwsA(isA<Exception>()),
        );

        // Subsequent update outside transaction works cleanly and world transform is updated
        final t2 = (Matrix4.identity()..setTranslationRaw(7.0, 8.0, 9.0)).storage;
        tm.setTransform(e, t2);

        final world = tm.getWorldTransform(e);
        expect(world[12], closeTo(7.0, 1e-5));
        expect(world[13], closeTo(8.0, 1e-5));
        expect(world[14], closeTo(9.0, 1e-5));

        engine.destroyEntity(e);
      });

      test('Reparenting and moving entities inside a transaction', () {
        final p1 = engine.createEntity();
        final p2 = engine.createEntity();
        final child = engine.createEntity();

        tm.create(p1, localTransform: Matrix4.identity()..setTranslationRaw(10.0, 0.0, 0.0));
        tm.create(p2, localTransform: Matrix4.identity()..setTranslationRaw(20.0, 0.0, 0.0));
        tm.create(child, parent: p1, localTransform: Matrix4.identity()..setTranslationRaw(1.0, 2.0, 3.0));

        tm.transaction(() {
          tm.setParent(child, p2);
          tm.setTransform(child, (Matrix4.identity()..setTranslationRaw(2.0, 3.0, 4.0)).storage);
        });

        expect(tm.getParent(child), equals(p2));
        final world = tm.getWorldTransform(child);
        expect(world[12], closeTo(22.0, 1e-5)); // 20 + 2
        expect(world[13], closeTo(3.0, 1e-5));
        expect(world[14], closeTo(4.0, 1e-5));

        engine.destroyEntity(child);
        engine.destroyEntity(p2);
        engine.destroyEntity(p1);
      });

      test('Nested transaction throws StateError', () {
        expect(
          () => tm.transaction(() {
            tm.transaction(() {});
          }),
          throwsStateError,
        );
      });

      test('Behavioral equivalence with and without transaction', () {
        final eA = engine.createEntity();
        final eB = engine.createEntity();
        tm.create(eA);
        tm.create(eB);

        final t = (Matrix4.identity()..setTranslationRaw(1.5, 2.5, 3.5)).storage;

        tm.setTransform(eA, t);
        tm.transaction(() {
          tm.setTransform(eB, t);
        });

        final wA = tm.getWorldTransform(eA);
        final wB = tm.getWorldTransform(eB);
        for (var i = 0; i < 16; i++) {
          expect(wB[i], equals(wA[i]));
        }

        engine.destroyEntity(eA);
        engine.destroyEntity(eB);
      });

      test('1000 setTransform calls inside transaction smoke', () {
        final e = engine.createEntity();
        tm.create(e);

        tm.transaction(() {
          for (var i = 0; i < 1000; i++) {
            final t = (Matrix4.identity()..setTranslationRaw(i.toDouble(), 0.0, 0.0)).storage;
            tm.setTransform(e, t);
          }
        });

        final w = tm.getWorldTransform(e);
        expect(w[12], closeTo(999.0, 1e-5));

        engine.destroyEntity(e);
      });
    });

    group('Single-Call Create (Task 03)', () {
      test('getTransformAt returns local transform via instance handle', () {
        final parent = engine.createEntity();
        final child = engine.createEntity();
        tm.create(parent, localTransform: Matrix4.identity()..setTranslationRaw(10.0, 0.0, 0.0));
        tm.create(child, parent: parent,
            localTransform: Matrix4.identity()..setTranslationRaw(1.0, 2.0, 3.0));

        final inst = tm.getInstance(child);
        expect(inst.isValid, isTrue);
        final local = tm.getTransformAt(inst);
        expect(local.length, equals(16));
        expect(local[12], closeTo(1.0, 1e-5));
        expect(local[13], closeTo(2.0, 1e-5));
        expect(local[14], closeTo(3.0, 1e-5));
        expect(local, equals(tm.getTransform(child)));

        tm.setTransformAt(inst, (Matrix4.identity()..setTranslationRaw(5.0, 6.0, 7.0)).storage);
        expect(tm.getTransformAt(inst)[12], closeTo(5.0, 1e-5));
        expect(() => tm.getTransformAt(const TransformInstance(0)), throwsArgumentError);

        engine.destroyEntity(child);
        engine.destroyEntity(parent);
      });

      test('Create bare root entity', () {
        final e = engine.createEntity();
        tm.create(e);

        expect(tm.hasComponent(e), isTrue);
        expect(tm.getParent(e), equals(0));

        final local = tm.getTransform(e);
        expect(local[0], equals(1.0)); // diagonal
        expect(local[5], equals(1.0));
        expect(local[10], equals(1.0));
        expect(local[15], equals(1.0));
        expect(local[12], equals(0.0));

        engine.destroyEntity(e);
      });

      test('Create parented entity with local transform', () {
        final parent = engine.createEntity();
        final child = engine.createEntity();

        tm.create(parent, localTransform: Matrix4.identity()..setTranslationRaw(10.0, 0.0, 0.0));
        tm.create(
          child,
          parent: parent,
          localTransform: Matrix4.identity()..setTranslationRaw(1.0, 2.0, 3.0),
        );

        expect(tm.getParent(child), equals(parent));

        final localChild = tm.getTransform(child);
        expect(localChild[12], closeTo(1.0, 1e-5));
        expect(localChild[13], closeTo(2.0, 1e-5));
        expect(localChild[14], closeTo(3.0, 1e-5));

        final worldChild = tm.getWorldTransform(child);
        expect(worldChild[12], closeTo(11.0, 1e-5));
        expect(worldChild[13], closeTo(2.0, 1e-5));
        expect(worldChild[14], closeTo(3.0, 1e-5));

        engine.destroyEntity(child);
        engine.destroyEntity(parent);
      });

      test('Create with rotation transform', () {
        final e = engine.createEntity();
        final rot = Matrix4.rotationZ(math.pi / 2);
        tm.create(e, localTransform: rot);

        final local = tm.getTransform(e);
        final world = tm.getWorldTransform(e);

        expect(local[0], closeTo(0.0, 1e-5)); // cos(pi/2)
        expect(local[1], closeTo(1.0, 1e-5)); // sin(pi/2)
        expect(world[0], closeTo(local[0], 1e-5));
        expect(world[1], closeTo(local[1], 1e-5));

        engine.destroyEntity(e);
      });

      test('Parent without transform component creates as root', () {
        final parentWithoutTransform = engine.createEntity();
        final child = engine.createEntity();

        tm.create(child, parent: parentWithoutTransform);

        expect(tm.hasComponent(child), isTrue);
        expect(tm.getParent(child), equals(0));

        engine.destroyEntity(child);
        engine.destroyEntity(parentWithoutTransform);
      });

      test('Re-create replaces existing component without crash', () {
        final e = engine.createEntity();
        tm.create(e, localTransform: Matrix4.identity()..setTranslationRaw(1.0, 0.0, 0.0));
        expect(tm.getTransform(e)[12], closeTo(1.0, 1e-5));

        tm.create(e, localTransform: Matrix4.identity()..setTranslationRaw(5.0, 0.0, 0.0));
        expect(tm.getTransform(e)[12], closeTo(5.0, 1e-5));

        engine.destroyEntity(e);
      });

      test('Single-call create produces identical world transform to 3-call sequence', () {
        final pA = engine.createEntity();
        final cA = engine.createEntity();

        // 3-call sequence
        tm.create(pA);
        tm.setTransform(pA, (Matrix4.identity()..setTranslationRaw(10.0, 0.0, 0.0)).storage);
        tm.create(cA);
        tm.setParent(cA, pA);
        tm.setTransform(cA, (Matrix4.identity()..setTranslationRaw(1.0, 2.0, 3.0)).storage);

        final pB = engine.createEntity();
        final cB = engine.createEntity();

        // Single-call sequence
        tm.create(pB, localTransform: Matrix4.identity()..setTranslationRaw(10.0, 0.0, 0.0));
        tm.create(cB, parent: pB, localTransform: Matrix4.identity()..setTranslationRaw(1.0, 2.0, 3.0));

        final wA = tm.getWorldTransform(cA);
        final wB = tm.getWorldTransform(cB);

        for (var i = 0; i < 16; i++) {
          expect(wB[i], equals(wA[i]));
        }

        engine.destroyEntity(cA);
        engine.destroyEntity(pA);
        engine.destroyEntity(cB);
        engine.destroyEntity(pB);
      });
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

void main() {
  group('CollisionFiltering Tests (Collision Task 02)', () {
    test('Fresh component defaults: layer 1, mask 0xFFFFFFFF, objectType worldDynamic', () {
      final comp = LuminaCollisionComponent(shapeType: CollisionShapeType.box);

      expect(comp.collisionLayer, equals(1)); // 1 << 0
      expect(comp.collisionLayerMask, equals(0xFFFFFFFF));
      expect(comp.objectType, equals(CollisionObjectType.worldDynamic));
      expect(comp.collisionEnabled, isTrue);
    });

    test('setLayer(3) sets layer to 1<<2, setLayer(32) sets 1<<31, setLayer(33) throws RangeError', () {
      final comp = LuminaCollisionComponent(shapeType: CollisionShapeType.sphere);

      comp.setLayer(3);
      expect(comp.collisionLayer, equals(1 << 2));

      comp.setLayer(32);
      expect(comp.collisionLayer, equals(1 << 31));

      expect(() => comp.setLayer(0), throwsRangeError);
      expect(() => comp.setLayer(33), throwsRangeError);
    });

    test('Asymmetric masks: A targeting 2, B targeting 3 -> canInteractWith is false in both directions', () {
      final a = LuminaCollisionComponent(shapeType: CollisionShapeType.box);
      a.setLayer(1);
      a.collisionLayerMask = CollisionLayers.layer(2);

      final b = LuminaCollisionComponent(shapeType: CollisionShapeType.box);
      b.setLayer(2);
      b.collisionLayerMask = CollisionLayers.layer(3);

      expect(a.canInteractWith(b), isFalse);
      expect(b.canInteractWith(a), isFalse);
    });

    test('Symmetric matching masks: A(L1 -> L2), B(L2 -> L1) -> canInteractWith is true both directions', () {
      final a = LuminaCollisionComponent(shapeType: CollisionShapeType.box);
      a.setLayer(1);
      a.collisionLayerMask = CollisionLayers.layer(2);

      final b = LuminaCollisionComponent(shapeType: CollisionShapeType.box);
      b.setLayer(2);
      b.collisionLayerMask = CollisionLayers.layer(1);

      expect(a.canInteractWith(b), isTrue);
      expect(b.canInteractWith(a), isTrue);
    });

    test('CollisionLayers.maskOf([1, 4]) produces 0b1001 (9)', () {
      final mask = CollisionLayers.maskOf([1, 4]);
      expect(mask, equals(0x9));
    });

    test('Response matrix: A blocks pawn, B (pawn) overlaps A -> effectiveResponse is overlap (min-wins)', () {
      final a = LuminaCollisionComponent(shapeType: CollisionShapeType.box);
      a.objectType = CollisionObjectType.worldDynamic;
      a.setResponse(CollisionObjectType.pawn, CollisionResponse.block);

      final b = LuminaCollisionComponent(shapeType: CollisionShapeType.capsule);
      b.objectType = CollisionObjectType.pawn;
      b.setResponse(CollisionObjectType.worldDynamic, CollisionResponse.overlap);

      expect(effectiveResponse(a, b), equals(CollisionResponse.overlap));
      expect(effectiveResponse(b, a), equals(CollisionResponse.overlap));
    });

    test('A ignores worldDynamic -> effectiveResponse is ignore regardless of B settings', () {
      final a = LuminaCollisionComponent(shapeType: CollisionShapeType.box);
      a.objectType = CollisionObjectType.worldStatic;
      a.setResponse(CollisionObjectType.worldDynamic, CollisionResponse.ignore);

      final b = LuminaCollisionComponent(shapeType: CollisionShapeType.box);
      b.objectType = CollisionObjectType.worldDynamic;
      b.setResponse(CollisionObjectType.worldStatic, CollisionResponse.block);

      expect(effectiveResponse(a, b), equals(CollisionResponse.ignore));
      expect(effectiveResponse(b, a), equals(CollisionResponse.ignore));
    });

    test('Layer rule failure dominates: matching Block responses with disjoint masks yields ignore', () {
      final a = LuminaCollisionComponent(shapeType: CollisionShapeType.box);
      a.setLayer(1);
      a.collisionLayerMask = CollisionLayers.layer(1);
      a.setResponseToAll(CollisionResponse.block);

      final b = LuminaCollisionComponent(shapeType: CollisionShapeType.box);
      b.setLayer(2);
      b.collisionLayerMask = CollisionLayers.layer(2);
      b.setResponseToAll(CollisionResponse.block);

      expect(effectiveResponse(a, b), equals(CollisionResponse.ignore));
    });

    test('CollisionProfile.applyPawn sets objectType to pawn, blocks static/dynamic, overlaps pawn', () {
      final c = LuminaCollisionComponent(shapeType: CollisionShapeType.capsule);
      CollisionProfile.applyPawn(c);

      expect(c.objectType, equals(CollisionObjectType.pawn));
      expect(c.getResponse(CollisionObjectType.worldStatic), equals(CollisionResponse.block));
      expect(c.getResponse(CollisionObjectType.worldDynamic), equals(CollisionResponse.block));
      expect(c.getResponse(CollisionObjectType.pawn), equals(CollisionResponse.overlap));
    });

    test('collisionEnabled = false makes canInteractWith and effectiveResponse return false/ignore', () {
      final a = LuminaCollisionComponent(shapeType: CollisionShapeType.box);
      final b = LuminaCollisionComponent(shapeType: CollisionShapeType.box);

      a.collisionEnabled = false;

      expect(a.canInteractWith(b), isFalse);
      expect(b.canInteractWith(a), isFalse);
      expect(effectiveResponse(a, b), equals(CollisionResponse.ignore));
    });
  });
}

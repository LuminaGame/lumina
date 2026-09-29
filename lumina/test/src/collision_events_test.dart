import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/lumina.dart';

void main() {
  group('Collision Events & Broad-Phase Tests (Collision Task 04)', () {
    test('Two overlap-response spheres moved into contact -> onComponentBeginOverlap fires once on both with correct self/other', () {
      final subsystem = LuminaCollisionSubsystem();

      final a = LuminaCollisionComponent(shapeType: CollisionShapeType.sphere, radius: 1.0)
        ..location = Vector3(0.0, 0.0, 0.0);
      CollisionProfile.applyOverlapAll(a);

      final b = LuminaCollisionComponent(shapeType: CollisionShapeType.sphere, radius: 1.0)
        ..location = Vector3(1.5, 0.0, 0.0);
      CollisionProfile.applyOverlapAll(b);

      subsystem.register(a);
      subsystem.register(b);

      LuminaCollisionComponent? beginSelfA, beginOtherA;
      LuminaCollisionComponent? beginSelfB, beginOtherB;
      int countA = 0, countB = 0;

      a.onComponentBeginOverlap = (self, other) {
        countA++;
        beginSelfA = self;
        beginOtherA = other;
      };

      b.onComponentBeginOverlap = (self, other) {
        countB++;
        beginSelfB = self;
        beginOtherB = other;
      };

      subsystem.updateCollision(1.0 / 60.0);

      expect(countA, equals(1));
      expect(countB, equals(1));
      expect(beginSelfA, equals(a));
      expect(beginOtherA, equals(b));
      expect(beginSelfB, equals(b));
      expect(beginOtherB, equals(a));
      expect(a.overlappingComponents, contains(b));
      expect(b.overlappingComponents, contains(a));
    });

    test('Second updateCollision with no movement -> no additional begin event; moving apart fires onComponentEndOverlap once', () {
      final subsystem = LuminaCollisionSubsystem();

      final a = LuminaCollisionComponent(shapeType: CollisionShapeType.sphere, radius: 1.0)
        ..location = Vector3(0.0, 0.0, 0.0);
      CollisionProfile.applyOverlapAll(a);

      final b = LuminaCollisionComponent(shapeType: CollisionShapeType.sphere, radius: 1.0)
        ..location = Vector3(1.5, 0.0, 0.0);
      CollisionProfile.applyOverlapAll(b);

      subsystem.register(a);
      subsystem.register(b);

      int beginCount = 0;
      int endCount = 0;

      a.onComponentBeginOverlap = (self, other) => beginCount++;
      a.onComponentEndOverlap = (self, other) => endCount++;

      subsystem.updateCollision(1.0 / 60.0);
      expect(beginCount, equals(1));
      expect(endCount, equals(0));

      // Second tick without movement
      subsystem.updateCollision(1.0 / 60.0);
      expect(beginCount, equals(1));
      expect(endCount, equals(0));

      // Move apart
      b.location = Vector3(5.0, 0.0, 0.0);
      subsystem.updateCollision(1.0 / 60.0);
      expect(beginCount, equals(1));
      expect(endCount, equals(1));
      expect(a.overlappingComponents, isEmpty);
      expect(b.overlappingComponents, isEmpty);
    });

    test('Component unregistered while overlapping -> onComponentEndOverlap fires during unregister', () {
      final subsystem = LuminaCollisionSubsystem();

      final a = LuminaCollisionComponent(shapeType: CollisionShapeType.sphere, radius: 1.0)
        ..location = Vector3(0.0, 0.0, 0.0);
      CollisionProfile.applyOverlapAll(a);

      final b = LuminaCollisionComponent(shapeType: CollisionShapeType.sphere, radius: 1.0)
        ..location = Vector3(1.5, 0.0, 0.0);
      CollisionProfile.applyOverlapAll(b);

      subsystem.register(a);
      subsystem.register(b);

      int endCountA = 0;
      int endCountB = 0;
      a.onComponentEndOverlap = (self, other) => endCountA++;
      b.onComponentEndOverlap = (self, other) => endCountB++;

      subsystem.updateCollision(1.0 / 60.0);
      expect(a.overlappingComponents.length, equals(1));

      subsystem.unregister(b);
      expect(endCountA, equals(1));
      expect(endCountB, equals(1));
      expect(a.overlappingComponents, isEmpty);
    });

    test('Two block-response boxes interpenetrating -> onComponentHit fires with blockingHit==true and penetrationDepth>0', () {
      final subsystem = LuminaCollisionSubsystem();

      final a = LuminaCollisionComponent(shapeType: CollisionShapeType.box)
        ..boxExtent = Vector3(1.0, 1.0, 1.0)
        ..location = Vector3(0.0, 0.0, 0.0);
      CollisionProfile.applyBlockAll(a);

      final b = LuminaCollisionComponent(shapeType: CollisionShapeType.box)
        ..boxExtent = Vector3(1.0, 1.0, 1.0)
        ..location = Vector3(1.5, 0.0, 0.0);
      CollisionProfile.applyBlockAll(b);

      subsystem.register(a);
      subsystem.register(b);

      HitResult? hitResult;
      int hitCount = 0;
      int overlapCount = 0;

      a.onComponentHit = (self, other, hit) {
        hitCount++;
        hitResult = hit;
      };
      a.onComponentBeginOverlap = (self, other) => overlapCount++;

      subsystem.updateCollision(1.0 / 60.0);

      expect(hitCount, equals(1));
      expect(overlapCount, equals(0));
      expect(hitResult, isNotNull);
      expect(hitResult!.blockingHit, isTrue);
      expect(hitResult!.penetrationDepth, greaterThan(0.0));
      expect(hitResult!.component, equals(b));
    });

    test('Early-exit order verified: disjoint-layer pair whose AABBs overlap keeps narrowPhaseTestCount at 0', () {
      final subsystem = LuminaCollisionSubsystem();

      final a = LuminaCollisionComponent(shapeType: CollisionShapeType.box)
        ..boxExtent = Vector3(1.0, 1.0, 1.0)
        ..location = Vector3(0.0, 0.0, 0.0);
      a.setLayer(1);
      a.collisionLayerMask = CollisionLayers.layer(1);

      final b = LuminaCollisionComponent(shapeType: CollisionShapeType.box)
        ..boxExtent = Vector3(1.0, 1.0, 1.0)
        ..location = Vector3(0.5, 0.0, 0.0); // AABBs heavily overlap!
      b.setLayer(2);
      b.collisionLayerMask = CollisionLayers.layer(2); // Disjoint layer mask

      subsystem.register(a);
      subsystem.register(b);

      subsystem.updateCollision(1.0 / 60.0);

      expect(subsystem.narrowPhaseTestCount, equals(0));
    });

    test('Pawn-profile capsule vs worldStatic box generates hit event; vs pawn capsule generates overlap event', () {
      final subsystem = LuminaCollisionSubsystem();

      final pawn1 = LuminaCapsuleComponent(radius: 0.4, halfHeight: 0.9)
        ..location = Vector3(0.0, 0.0, 0.0);
      CollisionProfile.applyPawn(pawn1);

      final wall = LuminaCollisionComponent(shapeType: CollisionShapeType.box)
        ..location = Vector3(0.5, 0.0, 0.0);
      CollisionProfile.applyBlockAll(wall);
      wall.objectType = CollisionObjectType.worldStatic;

      final pawn2 = LuminaCapsuleComponent(radius: 0.4, halfHeight: 0.9)
        ..location = Vector3(0.0, 0.0, 0.5);
      CollisionProfile.applyPawn(pawn2);

      subsystem.register(pawn1);
      subsystem.register(wall);
      subsystem.register(pawn2);

      bool hitWall = false;
      bool overlapPawn = false;

      pawn1.onComponentHit = (self, other, hit) {
        if (other == wall) hitWall = true;
      };
      pawn1.onComponentBeginOverlap = (self, other) {
        if (other == pawn2) overlapPawn = true;
      };

      subsystem.updateCollision(1.0 / 60.0);

      expect(hitWall, isTrue);
      expect(overlapPawn, isTrue);
    });
  });
}

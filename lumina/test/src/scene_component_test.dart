import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

/// `worldLocation` is a getter; reading it must not move anything.
void main() {
  group('LuminaSceneComponent.worldLocation', () {
    final yaw90 = Quaternion.axisAngle(Vector3(0.0, 1.0, 0.0), math.pi / 2);

    test('repeated reads under a rotated parent agree and leave relativeLocation alone', () {
      final parent = LuminaSceneComponent(location: Vector3(10.0, 1.0, 5.0), rotation: yaw90);
      final child = LuminaSceneComponent(location: Vector3(-3.0, 0.0, 0.0))..attachToComponent(parent);

      final first = child.worldLocation;
      final second = child.worldLocation;
      final third = child.worldLocation;

      expect(second.x, closeTo(first.x, 1e-12));
      expect(second.z, closeTo(first.z, 1e-12));
      expect(third.x, closeTo(first.x, 1e-12));
      expect(third.z, closeTo(first.z, 1e-12));
      expect(child.relativeLocation.x, -3.0);
      expect(child.relativeLocation.y, 0.0);
      expect(child.relativeLocation.z, 0.0);

      // And the answer is the parent's rotation applied once to the offset
      // (the rotation `Matrix4.compose` draws).
      final expected = Vector3(10.0, 1.0, 5.0) + (Vector3(-3.0, 0.0, 0.0)..applyQuaternion(yaw90));
      expect(first.x, closeTo(expected.x, 1e-9));
      expect(first.y, closeTo(expected.y, 1e-9));
      expect(first.z, closeTo(expected.z, 1e-9));
    });

    test('a grandchild under two rotated parents is stable too', () {
      final root = LuminaSceneComponent(rotation: yaw90);
      final middle = LuminaSceneComponent(location: Vector3(0.0, 0.0, -2.0), rotation: yaw90)..attachToComponent(root);
      final leaf = LuminaSceneComponent(location: Vector3(1.0, 0.0, 0.0))..attachToComponent(middle);

      final a = leaf.worldLocation;
      final b = leaf.worldLocation;
      expect(b.x, closeTo(a.x, 1e-12));
      expect(b.z, closeTo(a.z, 1e-12));
      expect(middle.relativeLocation.z, -2.0);
      expect(leaf.relativeLocation.x, 1.0);
    });
  });

  /// A rotation means what `Matrix4.compose` draws. Directions and
  /// child positions used to go through `Quaternion.rotate` (the inverse
  /// rotation), so a yawed actor's logic was the mirror image of its meshes.
  group('LuminaSceneComponent rotation convention', () {
    const deg = math.pi / 180.0;
    final yaw30 = Quaternion.euler(30.0 * deg, 0.0, 0.0);

    void expectVec(Vector3 actual, Vector3 expected, String what) {
      expect(actual.x, closeTo(expected.x, 1e-9), reason: '$what.x');
      expect(actual.y, closeTo(expected.y, 1e-9), reason: '$what.y');
      expect(actual.z, closeTo(expected.z, 1e-9), reason: '$what.z');
    }

    test('a child mesh offset (1, 0, 0) under a parent yawed 30° is drawn where the parent\'s rendered +X points', () {
      final parent = LuminaSceneComponent(location: Vector3(2.0, 0.5, -3.0), rotation: yaw30);
      final mesh = LuminaStaticMeshComponent(
        meshAssetPath: 'unused.glb',
        location: Vector3(1.0, 0.0, 0.0),
        assetUnitScale: 1.0,
      )..attachToComponent(parent);

      final parentPlusX = parent.worldTransform.transformed3(Vector3(1.0, 0.0, 0.0));
      expectVec(mesh.renderTransform.getTranslation(), parentPlusX, 'drawn child origin');
      expectVec(mesh.worldLocation, parentPlusX, 'child worldLocation');
      // The yaw turns +X towards −Z: (cos 30°, 0, −sin 30°) from the parent.
      expectVec(parentPlusX, Vector3(2.0 + math.cos(30.0 * deg), 0.5, -3.0 - math.sin(30.0 * deg)), 'rendered +X');
    });

    test('forwardVector, rightVector and upVector are the rendered −Z, +X and +Y', () {
      for (final q in [
        yaw30,
        Quaternion.euler(0.0, 30.0 * deg, 0.0),
        Quaternion.euler(-75.0 * deg, 20.0 * deg, 10.0 * deg),
      ]) {
        final c = LuminaSceneComponent(rotation: q);
        final drawn = c.worldTransform.getRotation();
        expectVec(c.forwardVector, drawn.transformed(Vector3(0.0, 0.0, -1.0)), 'forward of $q');
        expectVec(c.rightVector, drawn.transformed(Vector3(1.0, 0.0, 0.0)), 'right of $q');
        expectVec(c.upVector, drawn.transformed(Vector3(0.0, 1.0, 0.0)), 'up of $q');
      }
    });

    test('a nested child\'s world rotation and position follow the drawn parent chain', () {
      final root = LuminaSceneComponent(location: Vector3(0.0, 1.0, 0.0), rotation: yaw30);
      final middle = LuminaSceneComponent(location: Vector3(0.0, 0.0, -2.0), rotation: Quaternion.euler(0.0, 15.0 * deg, 0.0))
        ..attachToComponent(root);
      final leaf = LuminaSceneComponent(location: Vector3(1.0, 0.5, 0.0))..attachToComponent(middle);

      final drawnLeaf = root.worldTransform * middle.relativeTransformForTest * leaf.relativeTransformForTest;
      expectVec(leaf.worldLocation, drawnLeaf.getTranslation(), 'leaf origin');
      expectVec(leaf.forwardVector, drawnLeaf.getRotation().transformed(Vector3(0.0, 0.0, -1.0)), 'leaf forward');
    });

    test('a pawn facing control yaw 30° walks, looks and is drawn the same way', () {
      final pawn = LuminaPawn();
      pawn.faceRotation(Vector3(0.0, 30.0, 0.0), 1.0 / 60.0);

      // Positive yaw turns right: the template character's W direction.
      final walk = Vector3(math.sin(30.0 * deg), 0.0, -math.cos(30.0 * deg));
      expectVec(pawn.rootComponent.forwardVector, walk, 'pawn forward');
      expectVec(pawn.rootComponent.worldTransform.getRotation().transformed(Vector3(0.0, 0.0, -1.0)), walk, 'pawn drawn −Z');
      expectVec(luminaPawnQuaternionToEuler(pawn.actorRotation), Vector3(0.0, 30.0, 0.0), 'control yaw round trip');
    });
  });
}

extension on LuminaSceneComponent {
  /// The component's own transform relative to its parent, as drawn.
  Matrix4 get relativeTransformForTest => Matrix4.compose(relativeLocation, relativeRotation, relativeScale);
}

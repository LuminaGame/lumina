import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

/// A light travels along the −Z of its *drawn* transform, the way
/// the editor shows it, not along the mirrored `forwardVector`.
Vector3 _drawnForward(LuminaSceneComponent c) =>
    c.worldTransform.getRotation().transformed(Vector3(0, 0, -1))..normalize();

void main() {
  test('the template sun, stored 50° down, shines down along its drawn transform', () {
    final stored = GameTemplateCatalog.thirdPerson.levelActors
        .firstWhere((a) => a['type'] == 'DirectionalLight')['rotation'] as List;
    final sun = LuminaDirectionalLightComponent(rotation: LuminaAxes.rotation(stored.cast<num>()));
    final dir = sun.lightDirection;
    expect(dir.y, lessThan(-0.7), reason: 'pitch −50° points the sun down, got $dir');
    expect(dir.y, closeTo(-math.sin(50 * math.pi / 180), 1e-9));
    final drawn = _drawnForward(sun);
    for (var i = 0; i < 3; i++) {
      expect(dir[i], closeTo(drawn[i], 1e-9), reason: 'component $i: light $dir vs drawn $drawn');
    }
  });

  test('a spot light pitched −90° points straight down; a yawed one follows its drawn transform', () {
    final down = LuminaSpotLightComponent(rotation: luminaAuthoringRotation(-90, 0, 0));
    expect(down.lightDirection.y, closeTo(-1, 1e-9));
    final yawed = LuminaSpotLightComponent(rotation: luminaAuthoringRotation(-30, 0, 70));
    final drawn = _drawnForward(yawed);
    for (var i = 0; i < 3; i++) {
      expect(yawed.lightDirection[i], closeTo(drawn[i], 1e-9));
    }
  });
}

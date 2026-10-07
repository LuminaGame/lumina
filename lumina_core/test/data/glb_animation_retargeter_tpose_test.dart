import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/services/glb_animation_retargeter.dart';

void main() {
  group('GlbAnimationRetargeter T-pose to A-pose alignment', () {
    final superheroPath = 'assets/templates/third_person/SKM_Superhero_Female.glb';

    test('retargeting Idle_Loop preserves bone animation without errors', () {
      final file = File(superheroPath);
      if (!file.existsSync()) {
        markTestSkipped('$superheroPath not found');
        return;
      }

      final bytes = file.readAsBytesSync();
      final res = GlbAnimationRetargeter.retargetInto(
        target: bytes,
        clip: bytes,
        clipName: 'Idle_Loop_Retargeted',
        animationIndex: 0,
      );

      expect(res.glb.isNotEmpty, isTrue);
      expect(res.clipName, 'Idle_Loop_Retargeted');
      expect(res.duration, greaterThan(0.0));
      expect(res.mappedBones, contains('upperarm_l'));
      expect(res.mappedBones, contains('lowerarm_l'));
      expect(res.mappedBones, contains('hand_l'));
    });
  });
}

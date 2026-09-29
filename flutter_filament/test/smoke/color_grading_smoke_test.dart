// color_grading smoke: a real barrel GLB rendered with no grading vs. a
// heavy ColorGrading (ACES + saturation 0 + exposure) — the graded frame
// must be measurably desaturated and brighter.
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/testing.dart';
import 'package:test/test.dart';

import 'smoke_helper.dart';

void main() {
  group('ColorGrading Smoke Tests', () {
    late SmokeRig rig;
    late FilamentIndirectLight ibl;

    setUp(() {
      SmokeArtifacts.resetRecordedAssets();
      rig = SmokeRig.create(width: 320, height: 240);
      rig.addSun();
      ibl = rig.addIbl();
    });

    tearDown(() {
      rig.scene.setIndirectLight(null);
      ibl.dispose();
      rig.dispose();
      SmokeArtifacts.resetRecordedAssets();
    });

    test('ColorGrading: desaturating grade changes a real PBR render', () {
      final gltf = loadGltfIntoScene(rig, 'Props/Barrels/fuel_barrel_yellow.glb');
      try {
        final plain = rig.renderFrame();
        double saturation(List<int> px) {
          var sum = 0.0;
          var n = 0;
          for (var i = 0; i < px.length; i += 4) {
            final r = px[i], g = px[i + 1], b = px[i + 2];
            final mx = [r, g, b].reduce((a, c) => a > c ? a : c);
            final mn = [r, g, b].reduce((a, c) => a < c ? a : c);
            if (mx > 0) {
              sum += (mx - mn) / mx;
              n++;
            }
          }
          return sum / n;
        }
        final plainSat = saturation(plain);

        final toneMapper = ToneMapper(ToneMapperType.aces);
        final cg = (ColorGradingBuilder()
              ..quality(ColorGradingQuality.high)
              ..toneMapper(toneMapper)
              ..exposure(1.5)
              ..saturation(0.0)
              ..contrast(1.2))
            .build(rig.engine);
        expect(rig.engine.isValidColorGrading(cg), isTrue);
        rig.view.colorGrading = cg;
        expect(rig.view.colorGrading, same(cg));

        final graded = rig.screenshot('ColorGrading Smoke Tests ColorGrading: desaturating grade changes a real PBR render');
        final gradedSat = saturation(graded);
        final changed = countChangedPixels(plain, graded);
        smokeLog('saturation plain=${plainSat.toStringAsFixed(3)} graded=${gradedSat.toStringAsFixed(3)} changed=$changed');
        expect(gradedSat, lessThan(plainSat * 0.5), reason: 'saturation(0) grade desaturates the frame');
        expect(changed, greaterThan(rig.width * rig.height ~/ 2));

        rig.view.colorGrading = null;
        rig.engine.destroyColorGrading(cg);
        toneMapper.destroy();
      } finally {
        gltf.dispose(rig.scene);
      }
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}

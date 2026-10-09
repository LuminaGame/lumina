import 'dart:io';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';

import '../../tool/dlss/check_neural_rendering.dart';
import '../smoke/smoke_helper.dart';

/// What a Neural Rendering pass (an official DLSS 5 style network, once NVIDIA
/// publishes one for Vulkan) would need from the external post pass hook, and
/// the check that tells whether the pinned NVIDIA SDKs offer one.
void main() {
  group('the Neural Rendering check script', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('nr_check'));
    tearDown(() => tmp.deleteSync(recursive: true));

    Future<String> check(Directory dir) async => checkDirectory(dir);

    test(
      'the headers of the pinned DLSS SDK have no Neural Rendering feature',
      () async {
        final sdk = Directory('build/dlss-sdk/include');
        if (!sdk.existsSync()) {
          markTestSkipped(
            'the DLSS SDK is not fetched (tool/dlss/fetch_sdk.dart)',
          );
          return;
        }
        for (final f in sdk.listSync().whereType<File>()) {
          f.copySync('${tmp.path}/${f.uri.pathSegments.last}');
        }
        expect(await check(tmp), contains('Neural Rendering absent'));
      },
    );

    test('a header declaring a Neural Rendering feature id is found', () async {
      File('${tmp.path}/nvsdk_ngx_defs.h').writeAsStringSync('''
typedef enum NVSDK_NGX_Feature {
    NVSDK_NGX_Feature_RayReconstruction = 13,
    NVSDK_NGX_Feature_NeuralRendering = 19,
} NVSDK_NGX_Feature;
''');
      final out = await check(tmp);
      expect(out, contains('Neural Rendering found'));
      expect(out, contains('NVSDK_NGX_Feature_NeuralRendering'));
    });
  });

  group('the external post pass gives a neural pass what it needs (Vulkan)', () {
    SmokeRig? rig;
    final materials = <FilamentMaterial>[];
    final instances = <FilamentMaterialInstance>[];
    final quads = <SmokeQuad>[];
    DebugPostPass? pass;

    setUp(() {
      FilamentEngine? engine;
      try {
        engine = FilamentEngine.create(backend: FilamentBackend.vulkan);
      } catch (_) {
        engine = null;
      }
      if (engine == null) return;
      rig = SmokeRig.adopt(engine, width: 1024, height: 768);
    });

    tearDown(() {
      pass?.destroy();
      pass = null;
      final r = rig;
      if (r != null) {
        for (final e in r.entities) {
          r.engine.destroyEntity(e);
        }
        r.entities.clear();
      }
      for (final mi in instances) {
        mi.dispose();
      }
      instances.clear();
      for (final m in materials) {
        m.dispose();
      }
      materials.clear();
      for (final q in quads) {
        q.dispose();
      }
      quads.clear();
      rig?.dispose();
      rig = null;
    });

    test(
      'HDR colour above 1 before grading, output-resolution images after FSR3, usable history',
      () {
        if (rig == null) {
          markTestSkipped('needs a Vulkan device');
          return;
        }
        final r = rig!;
        if (!r.view.motionVectorsSupported) {
          markTestSkipped('FSR3 needs the structure pass motion vectors');
          return;
        }
        // an unlit quad four times brighter than white: HDR values before colour grading
        final material = buildUnlitMaterial(r.engine);
        materials.add(material);
        final mi = material.createInstance()..setFloat3('baseColor', 4, 4, 4);
        instances.add(mi);
        final quad = SmokeQuad.create(r.engine, size: 1.5);
        quads.add(quad);
        addQuadRenderable(r, quad, mi, extent: 1.5);
        r.camera.lookAt(
          eyeX: 0,
          eyeY: 0,
          eyeZ: 3,
          centerX: 0,
          centerY: 0,
          centerZ: 0,
        );
        r.view.temporalAntiAliasingOptions = const TemporalAntiAliasingOptions(
          enabled: true,
          algorithm: TaaAlgorithm.fsr3,
          upscaling: 1.5,
        );
        r.view.dynamicResolutionOptions = const DynamicResolutionOptions(
          enabled: true,
          minScaleX: 1 / 1.5,
          minScaleY: 1 / 1.5,
          maxScaleX: 1 / 1.5,
          maxScaleY: 1 / 1.5,
        );
        pass = DebugPostPass.create(engine: r.engine, view: r.view);
        final through = r.renderFrame(warmup: 8);
        final (w, h) = pass!.lastSize;
        expect(
          w,
          inInclusiveRange(1024, 1040),
          reason: 'the pass runs after FSR3 upscaling',
        );
        expect(h, inInclusiveRange(768, 776));
        final (tr, tg, tb) = pixelAt(through, 1024, 512, 384);
        expect(
          tr + tg + tb,
          greaterThan(3 * 200),
          reason: 'the quad is bright',
        );

        // max(0, 1 - c) is black only where the colour was at least 1: values above 1 reach the pass
        pass!.mode = DebugPostPassMode.invert;
        final inverted = r.renderFrame(warmup: 2);
        final (ir, ig, ib) = pixelAt(inverted, 1024, 512, 384);
        smokeLog(
          'quad centre: passthrough ($tr, $tg, $tb), inverted ($ir, $ig, $ib)',
        );
        expect(
          ir + ig + ib,
          lessThan(6),
          reason: 'the colour before grading is above 1 (HDR)',
        );

        // history: a still camera keeps it, a reset drops it
        pass!.mode = DebugPostPassMode.history;
        final still = r.renderFrame(warmup: 2);
        final (sr, sg, _) = pixelAt(still, 1024, 100, 100);
        expect(sg, greaterThan(sr), reason: 'usable history on a still camera');
        r.view.resetExternalPostPassHistory();
        final reset = r.renderFrame(warmup: 0);
        final (rr, rg, _) = pixelAt(reset, 1024, 100, 100);
        expect(rr, greaterThan(rg), reason: 'no history after a reset');
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });
}

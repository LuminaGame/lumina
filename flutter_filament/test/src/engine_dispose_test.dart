import 'dart:io' show Platform;

import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';

import '../smoke/smoke_helper.dart';

/// Disposing an engine that still owns a view, a scene and a camera: the
/// engine cleans up after the application. A view that rendered shadows owns
/// cameras of its own (one pair per shadow map) and must be terminated while
/// those still exist; the heap churn of TAA frames made the stale read crash.
void main() {
  group('engine dispose with leaked viewport objects', () {
    FilamentEngine? create() {
      try {
        final backend = Platform.environment['FILAMENT_TEST_BACKEND'] == 'opengl'
            ? FilamentBackend.opengl
            : FilamentBackend.vulkan;
        return FilamentEngine.create(backend: backend);
      } catch (_) {
        return null;
      }
    }

    for (final taa in [false, true]) {
      test('survives after 30 shadowed frames with TAA ${taa ? 'on' : 'off'} and the view left to the engine', () {
        final engine = create();
        if (engine == null) {
          markTestSkipped('needs a GPU device');
          return;
        }
        final rig = SmokeRig.adopt(engine, width: 256, height: 256);
        rig.addSun();
        final gltf = loadGltfIntoScene(rig, 'Props/Barrels/empty_barrel.glb');
        rig.view.temporalAntiAliasingOptions = TemporalAntiAliasingOptions(enabled: taa);
        for (var i = 0; i < 30; i++) {
          rig.renderFrame(warmup: 0);
        }
        gltf.dispose(rig.scene);
        // Destroys the renderer and the engine; the view, scene, camera and
        // swap chain are left for the engine to terminate.
        rig.dispose();
      }, timeout: const Timeout(Duration(minutes: 3)));
    }
  });
}

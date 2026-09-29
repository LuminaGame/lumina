import 'dart:io';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';

/// A disposed glTF asset looked as if it left materials, transforms
/// and entities alive. It does not: the renderer creates its own on the first
/// frames (2 materials and 256 entities with transforms on Vulkan), and
/// Filament drops the components of destroyed entities during the next
/// frames' garbage collection. A leak check therefore takes its baseline
/// after the first frames and reads the counts a few frames after dispose.
/// A real barrel from test-assets, rendered on the noop backend.
void main() {
  final barrel = File('../test-assets/Props/Barrels/fuel_barrel_red.glb');

  Map<String, int> counts(FilamentEngine e) {
    final c = e.resourceCounts;
    return {
      'textures': c.textures,
      'materials': c.materials,
      'vertexBuffers': c.vertexBuffers,
      'indexBuffers': c.indexBuffers,
      'bufferObjects': c.bufferObjects,
      'renderables': c.renderables,
      'lights': c.lights,
      'transforms': c.transforms,
      'entities': c.entities,
    };
  }

  test('after the first frames, load → render → dispose → a few frames returns every counter to its baseline', () {
    if (!barrel.existsSync()) return markTestSkipped('test-assets not present');
    final engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
    final swapChain = engine.createHeadlessSwapChain(64, 64);
    final renderer = engine.createRenderer();
    final scene = engine.createScene();
    final view = engine.createView();
    final cameraEntity = engine.createEntity();
    final camera = engine.createCamera(cameraEntity);
    view.scene = scene;
    view.camera = camera;
    view.setViewport(0, 0, 64, 64);
    addTearDown(() {
      engine.destroyCamera(camera);
      engine.destroyEntity(cameraEntity);
      engine.destroyView(view);
      engine.destroyScene(scene);
      renderer.dispose();
      engine.dispose();
    });

    void frames(int n) {
      var rendered = 0;
      for (var attempt = 0; rendered < n && attempt < 200; attempt++) {
        if (renderer.beginFrame(swapChain)) {
          renderer.render(view);
          renderer.endFrame();
          rendered++;
        }
      }
      expect(rendered, n, reason: 'the noop backend renders');
      engine.flushAndWait();
    }

    final beforeFirstFrame = counts(engine);
    frames(3);
    final baseline = counts(engine);

    for (var round = 0; round < 2; round++) {
      final provider = FilamentMaterialProvider.createUbershader(engine: engine);
      final loader = FilamentAssetLoader.create(engine: engine, materialProvider: provider);
      final asset = loader.createAsset(barrel.readAsBytesSync())!;
      final resources = FilamentResourceLoader.create(engine: engine)..registerDefaultProviders(engine);
      expect(resources.loadResources(asset), isTrue);
      asset.addToScene(scene);
      frames(2);
      expect(counts(engine)['entities'], greaterThan(baseline['entities']!), reason: 'the asset made entities');

      asset.removeFromScene(scene);
      loader.destroyAsset(asset);
      resources.dispose();
      loader.dispose();
      provider.dispose();
      frames(3);

      expect(counts(engine), baseline, reason: 'round $round: nothing of the barrel is left');
    }
    // What the old check compared against: counts from before any frame, which
    // the renderer's own lazily created objects make look like a leak.
    // ignore: avoid_print
    print('renderer-owned after the first frames: '
        '${[for (final k in baseline.keys) if (baseline[k] != beforeFirstFrame[k]) '$k +${baseline[k]! - beforeFirstFrame[k]!}'].join(', ')}');
  });
}

// Gltfio's NodeManager and TrsTransformManager must follow the
// engine's reclamation epoch, or Filament logs "EBR Stall Warning" every 64
// epochs for the rest of the process once a gltfio entity is destroyed
// through the entity manager (lumina's mesh cache does exactly that when a
// shared instance is released).
import 'dart:async';
import 'dart:io';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const model = 'example/assets/models/WaterBottle.glb';

  group('gltfio epoch reclamation', () {
    late FilamentEngine engine;
    late FilamentMaterialProvider provider;
    late FilamentAssetLoader loader;
    late FilamentResourceLoader resources;
    final logs = <FilamentLogRecord>[];
    late StreamSubscription<FilamentLogRecord> logSub;

    setUp(() {
      FilamentDiagnostics.installLogHandler();
      logs.clear();
      logSub = FilamentDiagnostics.onLog.listen(logs.add);
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
      provider = FilamentMaterialProvider.ubershader(engine);
      loader = FilamentAssetLoader.create(engine: engine, materialProvider: provider);
      resources = FilamentResourceLoader.create(engine: engine);
    });

    tearDown(() async {
      resources.dispose();
      loader.dispose();
      provider.dispose();
      engine.dispose();
      await logSub.cancel();
      FilamentDiagnostics.clearLogHandler();
    });

    /// Pumps the message loop so the native log callback (a listener
    /// NativeCallable) delivers everything Filament wrote.
    Future<void> drainLogs() => Future<void>.delayed(const Duration(milliseconds: 200));

    List<String> stallWarnings() =>
        [for (final r in logs) if (r.message.contains('EBR Stall')) '${r.tag}: ${r.message}'];

    test('two viewports over 100 frames after a gltfio instance is destroyed entity-by-entity: no stall warning',
        () async {
      final file = File(model);
      expect(file.existsSync(), isTrue, reason: '$model is the fixture');
      final asset = loader.createAsset(file.readAsBytesSync())!;
      resources.loadResources(asset);
      final instance = asset.instance!;
      final entities = {...instance.entities, instance.root};
      expect(entities, isNotEmpty);

      // Two viewports on the shared engine: two renderers, two
      // swap chains, one scene each.
      final viewports = [
        for (var i = 0; i < 2; i++)
          (
            renderer: engine.createRenderer(),
            swapChain: engine.createHeadlessSwapChain(64, 64),
            view: engine.createView(),
            scene: engine.createScene(),
            cameraEntity: engine.createEntity(),
          ),
      ];
      for (final vp in viewports) {
        vp.view.scene = vp.scene;
        vp.view.camera = engine.createCamera(vp.cameraEntity);
        vp.view.setViewport(0, 0, 64, 64);
        vp.scene.addEntities(instance.entities);
      }

      Future<void> frames(int n) async {
        for (var i = 0; i < n; i++) {
          for (final vp in viewports) {
            if (vp.renderer.beginFrame(vp.swapChain)) {
              vp.renderer.render(vp.view);
              vp.renderer.endFrame();
            }
          }
        }
      }

      await frames(5);

      // What LuminaMeshAssetCache._destroyInstance does to a shared asset's
      // released instance: its entities die through the entity manager while
      // NodeManager / TrsTransformManager still hold components for them.
      for (final vp in viewports) {
        vp.scene.removeEntities(instance.entities);
      }
      instance.detachMaterialInstances();
      for (final e in entities) {
        engine.destroyEntity(e);
      }

      // Two renderers → two epochs per frame; the warning needs a watermark
      // 64+ epochs behind and a timeline over 128 epochs, so 100 frames
      // (200 epochs) log it at least once without the per-frame gc.
      await frames(100);
      await drainLogs();

      expect(stallWarnings(), isEmpty,
          reason: 'gltfio managers must follow the epoch the renderer advances');

      for (final vp in viewports) {
        vp.view.dispose();
        vp.scene.dispose();
        vp.swapChain.dispose();
        vp.renderer.dispose();
        engine.destroyEntity(vp.cameraEntity);
      }
      loader.destroyAsset(asset);
    });

    test('collectGarbage sees the loaders of its engine only and forgets a disposed one', () {
      expect(FilamentAssetLoader.liveLoaderCount(engine), 1);
      final other = FilamentEngine.create(backend: FilamentBackend.noop)!;
      final otherProvider = FilamentMaterialProvider.ubershader(other);
      final otherLoader = FilamentAssetLoader.create(engine: other, materialProvider: otherProvider);
      expect(FilamentAssetLoader.liveLoaderCount(engine), 1);
      expect(FilamentAssetLoader.liveLoaderCount(other), 1);
      // Both engines' loaders are alive; a gc pass on either engine returns.
      expect(() => FilamentAssetLoader.collectGarbage(engine), returnsNormally);
      expect(() => FilamentAssetLoader.collectGarbage(other), returnsNormally);
      otherLoader.dispose();
      expect(FilamentAssetLoader.liveLoaderCount(other), 0);
      expect(() => FilamentAssetLoader.collectGarbage(other), returnsNormally);
      otherProvider.dispose();
      other.dispose();
      expect(() => FilamentAssetLoader.collectGarbage(other), returnsNormally,
          reason: 'a disposed engine is a no-op, never a native call');
    });
  });
}

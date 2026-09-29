import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';

void main() {
  group('glTF Loader API Tests', () {
    late FilamentEngine engine;

    setUp(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
    });

    tearDown(() {
      if (!engine.isDisposed) engine.dispose();
    });

    test('FilamentResourceLoader lifecycle', () {
      final resourceLoader = FilamentResourceLoader.create(
        engine: engine,
        defaultPath: '/tmp',
        normalizeSkinningWeights: true,
      );

      expect(resourceLoader.isDisposed, isFalse);
      resourceLoader.dispose();
      expect(resourceLoader.isDisposed, isTrue);
    });

    test('addResourceData and hasResourceData', () {
      final resourceLoader = FilamentResourceLoader.create(engine: engine);
      expect(resourceLoader.hasResourceData('test.bin'), isFalse);

      resourceLoader.addResourceData('test.bin', Uint8List.fromList([1, 2, 3, 4]));
      expect(resourceLoader.hasResourceData('test.bin'), isTrue);

      resourceLoader.evictResourceData();
      expect(resourceLoader.hasResourceData('test.bin'), isFalse);

      resourceLoader.dispose();
    });

    test('asyncBeginLoad and asyncUpdateLoad', () async {
      final materialProvider = FilamentMaterialProvider.createUbershader(engine: engine);
      final assetLoader = FilamentAssetLoader.create(engine: engine, materialProvider: materialProvider);
      final resourceLoader = FilamentResourceLoader.create(engine: engine);
      
      final glbBytes = Uint8List.fromList([0x67, 0x6C, 0x54, 0x46, 2, 0, 0, 0, 12, 0, 0, 0]); // dummy header
      final asset = assetLoader.createAsset(glbBytes);
      if (asset != null) {
        expect(() => resourceLoader.asyncBeginLoad(asset), returnsNormally);
        expect(resourceLoader.asyncGetLoadProgress(), greaterThanOrEqualTo(0.0));
        resourceLoader.asyncUpdateLoad();
        resourceLoader.asyncCancelLoad();
        asset.dispose();
      }
      
      resourceLoader.dispose();
      assetLoader.dispose();
      materialProvider.dispose();
    });

    // loadAsync polled with an uncancellable `Future.delayed`, so a
    // loader disposed (or cancelled) mid-load left a pending timer behind —
    // a widget test that closed a viewport while its mesh loaded failed with
    // `!timersPending`.
    for (final teardown in ['dispose', 'asyncCancelLoad']) {
      test('$teardown stops a loadAsync in flight: no poll timer left, the future fails', () async {
        final file = File('../test-assets/fixtures/attackhelicopter.entity.glb');
        if (!file.existsSync()) return markTestSkipped('attackhelicopter.entity.glb not found');
        final materialProvider = FilamentMaterialProvider.createUbershader(engine: engine);
        final assetLoader = FilamentAssetLoader.create(engine: engine, materialProvider: materialProvider);
        final resourceLoader = FilamentResourceLoader.create(engine: engine);
        final asset = assetLoader.createAsset(file.readAsBytesSync())!;

        final timers = <Timer>[];
        late Future<void> load;
        runZoned(() {
          load = resourceLoader.loadAsync(asset);
        }, zoneSpecification: ZoneSpecification(createTimer: (self, parent, zone, duration, callback) {
          final t = parent.createTimer(zone, duration, callback);
          timers.add(t);
          return t;
        }));
        final outcome = load.then<Object?>((_) => 'completed', onError: (Object e) => e);
        expect(timers.where((t) => t.isActive), isNotEmpty, reason: 'the textures are still decoding: a poll is pending');

        if (teardown == 'dispose') {
          resourceLoader.dispose();
        } else {
          resourceLoader.asyncCancelLoad();
        }
        expect(timers.where((t) => t.isActive), isEmpty, reason: 'the poll timer is cancelled synchronously');
        expect(await outcome, isA<StateError>());

        if (!resourceLoader.isDisposed) resourceLoader.dispose();
        assetLoader.destroyAsset(asset);
        assetLoader.dispose();
        materialProvider.dispose();
      });
    }

    test('addTextureProvider', () {
      final resourceLoader = FilamentResourceLoader.create(engine: engine);
      final provider = TextureProvider.stb(engine: engine);
      
      expect(() => resourceLoader.addTextureProvider('image/png', provider), returnsNormally);
      
      resourceLoader.dispose();
      provider.dispose();
    });
  });
}

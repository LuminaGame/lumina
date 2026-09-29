// ignore_for_file: file_names

import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/testing.dart';
import 'package:test/test.dart';

import 'smoke_helper.dart';

void main() {
  group('00_infrastructure Smoke Tests', () {
    late FilamentEngine engine;

    setUp(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
      engine.createHeadlessSwapChain(800, 600);
    });

    tearDown(() {
      engine.dispose();
    });

    test('NativeBuffer allocation and zero-copy transfer validation', () async {
      // 1. Allocate a NativeBuffer
      final buffer = NativeBuffer.allocate(64);
      expect(buffer.sizeInBytes, 64);
      expect(buffer.isReleased, isFalse);

      // Write pattern
      for (var i = 0; i < 64; i++) {
        buffer.asTypedList[i] = i;
      }

      // Zero-copy verification via peekAddress
      final peeked = BufferOwnershipRegistry.peekAddress(buffer.pointer.cast());
      expect(peeked.address, buffer.pointer.address);

      // 2. Register and consume
      final (user, callback, token) = BufferOwnershipRegistry.instance.register(
        buffer,
        onFree: () => buffer.free(),
      );

      BufferOwnershipRegistry.consumeTestBuffer(
        engine: engine,
        data: buffer.pointer.cast(),
        size: 64,
        callback: callback,
        user: user,
      );

      // 3. Flush and wait for release
      engine.flushAndWait();
      engine.pumpMessageQueues();
      
      await BufferOwnershipRegistry.instance.whenReleased(token).timeout(const Duration(seconds: 1));

      expect(buffer.isReleased, isTrue);
    });

    test('CallbackBridge async delivery with headless engine', () async {
      // 1. Register a callback
      final (requestId, future) = CallbackBridge.instance.register(kind: 1); // 1 = arbitrary kind for test
      
      // 2. Fire the callback
      CallbackBridge.testFire(requestId: requestId, kind: 1, status: 0, payload: ffi.nullptr, size: 0);

      // 3. Pump message queues
      engine.pumpMessageQueues();

      // 4. Verify
      final result = await future.timeout(const Duration(seconds: 1));
      expect(result.kind, 1);
      expect(result.status, 0);
      expect(result.payload, isEmpty);
    });

    test('Verify Math ABI struct sizes and column-major memory layout', () {
      // Verify Float3 is 12 bytes
      expect(ffi.sizeOf<Float3>(), 12);
      
      // Verify Mat4f is 64 bytes
      expect(ffi.sizeOf<Mat4f>(), 64);
      
      // Column major layout check
      final ptr = calloc<Mat4f>();
      try {
        final elements = [
          1.0, 0.0, 0.0, 0.0,
          0.0, 1.0, 0.0, 0.0,
          0.0, 0.0, 1.0, 0.0,
          1.0, 2.0, 3.0, 1.0,
        ];
        ptr.ref.setFromList(elements);
        
        final list = ptr.ref.toList();
        expect(list[12], 1.0);
        expect(list[13], 2.0);
        expect(list[14], 3.0);
        expect(list[15], 1.0);
      } finally {
        calloc.free(ptr);
      }
    });

    test('Verify Enum fidelity', () {
      // PrimitiveType
      expect(PrimitiveType.points.value, 0);
      expect(PrimitiveType.lines.value, 1);
      expect(PrimitiveType.lineStrip.value, 3);
      expect(PrimitiveType.triangles.value, 4);
      expect(PrimitiveType.triangleStrip.value, 5);

      // IndexType
      expect(IndexType.ushort.value, 12);
      expect(IndexType.uint.value, 17);
      
      // BuilderResult
      expect(BuilderResult.success.value, 0);
      expect(BuilderResult.error.value, -1);
    });

    test('Verify EntityInstance handles creation and querying', () {
      final entity = engine.createEntity();
      final transformManager = FilamentTransformManager(engine);
      
      // Initially, hasComponent should be false and getInstance should be 0
      expect(transformManager.hasComponent(entity), isFalse);
      expect(transformManager.getInstance(entity).isValid, isFalse);

      // Create a transform component
      transformManager.create(entity);
      
      expect(transformManager.hasComponent(entity), isTrue);
      
      final instance = transformManager.getInstance(entity);
      expect(instance.isValid, isTrue);
      expect(instance.handle, isNot(0));
      
      // Destroy entity
      engine.destroyEntity(entity);
      
      expect(transformManager.hasComponent(entity), isFalse);
      expect(transformManager.getInstance(entity).isValid, isFalse);
    });

    // The library this process runs is a complete
    // entry of the machine-wide native cache (what a cache hit bundles), and
    // it renders a real barrel headless with no leaked handles.
    test('prebuilt native library cache', () {
      SmokeArtifacts.resetRecordedAssets();
      final libName = Platform.isWindows ? 'flutter_filament.dll' : (Platform.isMacOS ? 'libflutter_filament.dylib' : 'libflutter_filament.so');
      final bundled = File('build/native_assets/${Platform.operatingSystem}/$libName');
      final cacheRoot = Directory(Platform.environment['LUMINA_NATIVE_CACHE_DIR'] ??
          (Platform.isWindows
              ? '${Platform.environment['LOCALAPPDATA']}/lumina/native'
              : '${Platform.environment['XDG_CACHE_HOME'] ?? '${Platform.environment['HOME']}/.cache'}/lumina/native'));
      if (!bundled.existsSync() || !Directory('${cacheRoot.path}/flutter_filament').existsSync()) {
        markTestSkipped('no bundled library at ${bundled.path} or no native cache at ${cacheRoot.path}');
        return;
      }
      final bytes = bundled.readAsBytesSync();
      final entries = [
        for (final e in Directory('${cacheRoot.path}/flutter_filament').listSync().whereType<Directory>())
          if (File('${e.path}/complete').existsSync() && File('${e.path}/$libName').existsSync()) File('${e.path}/$libName'),
      ];
      expect(entries.any((f) => f.lengthSync() == bytes.length && _sameBytes(f.readAsBytesSync(), bytes)), isTrue,
          reason: 'the running library is byte-identical to a complete cache entry');

      final rig = SmokeRig.create(width: 480, height: 320)..addSun();
      // The renderer creates its own objects on the first frames (2 materials,
      // 256 entities with transforms on Vulkan): the baseline follows them.
      rig.renderFrame(warmup: 2);
      final baseline = rig.engine.resourceCounts;
      final barrel = loadGltfIntoScene(rig, 'Props/Barrels/fuel_barrel_red.glb');
      final pixels = rig.renderFrame(warmup: 2); // three frames
      expect(countForegroundPixels(pixels, rig.width), greaterThan(rig.width * rig.height ~/ 50), reason: 'the barrel is drawn');
      SmokeArtifacts.saveScreenshot('prebuilt native library cache', SmokeArtifacts.encodePng(rig.width, rig.height, pixels));
      barrel.dispose(rig.scene);
      // Filament drops a destroyed entity's components during the next
      // frames' garbage collection, so read the counts a few frames later.
      rig.renderFrame(warmup: 2);
      final after = rig.engine.resourceCounts;
      Map<String, int> all(FilamentEngineResourceCounts c) => {
            'textures': c.textures, 'materials': c.materials, 'vertexBuffers': c.vertexBuffers,
            'indexBuffers': c.indexBuffers, 'bufferObjects': c.bufferObjects, 'skinningBuffers': c.skinningBuffers,
            'morphTargetBuffers': c.morphTargetBuffers, 'instanceBuffers': c.instanceBuffers,
            'views': c.views, 'scenes': c.scenes, 'swapChains': c.swapChains, 'indirectLights': c.indirectLights,
            'skyboxes': c.skyboxes, 'colorGradings': c.colorGradings, 'renderTargets': c.renderTargets,
            'renderables': c.renderables, 'lights': c.lights, 'transforms': c.transforms, 'entities': c.entities,
          };
      expect(all(after), all(baseline), reason: 'nothing the barrel took is left');
      rig.dispose();
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}

bool _sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
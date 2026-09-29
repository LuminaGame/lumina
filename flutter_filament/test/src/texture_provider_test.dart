import 'dart:typed_data';
import 'dart:convert';
import 'package:test/test.dart';
import 'package:flutter_filament/src/engine.dart';
import 'package:flutter_filament/src/texture_provider.dart';

// Helper to create a minimal 2x2 RGBA PNG.
// (1x1 PNG is the absolute minimum, but 2x2 is fine).
final Uint8List _minimalPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAFElEQVQIW2P8z8AARAwMDEw'
  'MKAAAFn8B/79N2dMAAAAASUVORK5CYII='
);

// A known corrupt string as bytes
final Uint8List _corruptBytes = Uint8List.fromList([0, 1, 2, 3, 4, 5, 6, 7]);

void main() {
  group('TextureProvider', () {
    late FilamentEngine engine;

    setUp(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
    });

    tearDown(() {
      engine.dispose();
    });

    test('stb provider decodes minimal PNG', () {
      final provider = TextureProvider.stb(engine: engine);

      // We expect the counters to be 0 initially
      expect(provider.pushedCount, 0);
      expect(provider.poppedCount, 0);
      expect(provider.decodedCount, 0);

      // Push valid PNG
      final tex = provider.pushTexture(
        _minimalPng, 
        mime: 'image/png', 
        flags: TextureProviderFlags.srgb,
      );

      expect(tex, isNotNull, reason: 'pushTexture should succeed on well-formed header');
      expect(provider.pushedCount, 1);
      expect(provider.pushMessage, isNull);

      // Flush queue
      provider.updateQueue();
      provider.waitForCompletion();
      provider.updateQueue();

      // Check decode counters
      expect(provider.decodedCount, 1);
      
      final poppedTex = provider.popTexture();
      expect(poppedTex?.nativePointer, equals(tex?.nativePointer));
      expect(provider.poppedCount, 1);
      expect(provider.popMessage, isNull);

      // Clean up texture
      poppedTex?.dispose();

      provider.destroy();
    });

    test('pushing a corrupt byte array returns null or pop error', () {
      final provider = TextureProvider.stb(engine: engine);

      // STB usually fails synchronously during push because it reads the header to find width/height
      final tex = provider.pushTexture(_corruptBytes, mime: 'image/png');
      
      if (tex == null) {
        expect(provider.pushMessage, isNotNull);
        expect(provider.pushedCount, 0);
      } else {
        expect(provider.pushedCount, 1);
        provider.updateQueue();
        provider.waitForCompletion();
        provider.updateQueue();
        
        final popped = provider.popTexture();
        expect(popped?.nativePointer, equals(tex?.nativePointer));
        expect(provider.popMessage, isNotNull, reason: 'Decode should fail');
        popped?.dispose();
      }

      provider.destroy();
    });

    test('isWebpSupported is boolean, fails gracefully if false', () {
      final supported = TextureProvider.isWebpSupported();
      if (!supported) {
        expect(() => TextureProvider.webp(engine: engine), throwsUnsupportedError);
      } else {
        final webp = TextureProvider.webp(engine: engine);
        webp.destroy();
      }
    });

    test('cancelDecoding cleans up pending textures safely', () {
      final provider = TextureProvider.stb(engine: engine);
      
      for (int i = 0; i < 4; i++) {
        provider.pushTexture(_minimalPng, mime: 'image/png');
      }
      expect(provider.pushedCount, 4);

      provider.cancelDecoding();
      provider.waitForCompletion();
      provider.updateQueue();

      // Cancel makes textures "poppable", possibly with incomplete levels.
      int popCount = 0;
      while (true) {
        final tex = provider.popTexture();
        if (tex == null) break;
        tex.dispose();
        popCount++;
      }

      expect(popCount, lessThanOrEqualTo(4));
      expect(provider.poppedCount, popCount);
      
      provider.destroy();
    });

    test('create/destroy ktx2 provider headless does not crash', () {
      final ktx2 = TextureProvider.ktx2(engine: engine);
      expect(ktx2, isNotNull);
      ktx2.destroy();
    });
    
    test('standalone decodeImage helper works seamlessly', () async {
      // Decode image manages a temporary provider internally
      final tex = await TextureProvider.decodeImage(engine, _minimalPng, mime: 'image/png', srgb: true);
      expect(tex, isNotNull);
      tex.dispose();
    });
  });
}

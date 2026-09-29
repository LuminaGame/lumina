// index_buffer smoke: ushort and uint index buffers, byte-offset partial
// setBuffer, rendered on the GPU (the index patch flips which half of a
// quad is drawn).
import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/testing.dart';
import 'package:test/test.dart';

import 'smoke_helper.dart';

void main() {
  group('IndexBuffer Smoke Tests', () {
    late SmokeRig rig;

    setUp(() {
      SmokeArtifacts.resetRecordedAssets();
      rig = SmokeRig.create(width: 256, height: 256);
      rig.camera.setProjectionOrtho(left: -1, right: 1, bottom: -1, top: 1, near: 0.1, far: 10);
      rig.camera.lookAt(eyeX: 0, eyeY: 0, eyeZ: 2, centerX: 0, centerY: 0, centerZ: 0);
      rig.view.postProcessingEnabled = false;
    });

    tearDown(() => rig.dispose());

    test('IndexBuffer: uint32 indices with byte-offset patch select triangles', () {
      final quad = SmokeQuad.create(rig.engine, size: 1.6);
      // Replace the ushort IB with a uint one drawing only the lower-right triangle
      // then patch the second triangle in at byte offset 12.
      final ib = FilamentIndexBuffer.create(engine: rig.engine, indexCount: 6, type: IndexType.uint);
      expect(ib.type, IndexType.uint);
      expect(ib.byteCapacity, 24);
      ib.setUint32Data(Uint32List.fromList([0, 1, 2, 0, 0, 0])); // degenerate 2nd tri
      expect(() => ib.setIndicesU16(Uint16List(6)), throwsArgumentError);

      final material = buildUnlitMaterial(rig.engine);
      final mi = material.createInstance()..setFloat3('baseColor', 1.0, 0.6, 0.1);
      addQuadRenderable(rig, SmokeQuad(quad.vb, ib), mi);

      final half = rig.renderFrame();
      final halfFg = countForegroundPixels(half, rig.width);

      ib.setBuffer(rig.engine, NativeBuffer.copy(Uint32List.fromList([0, 2, 3]).buffer.asUint8List()),
          byteOffset: 12, autoFree: true);
      final full = rig.screenshot('IndexBuffer Smoke Tests IndexBuffer: uint32 indices with byte-offset patch select triangles');
      final fullFg = countForegroundPixels(full, rig.width);
      print('half=$halfFg full=$fullFg');
      expect(halfFg, greaterThan(rig.width * rig.height ~/ 5));
      expect(fullFg, greaterThan(halfFg * 1.7), reason: 'patched indices add the second triangle');

      rig.releaseEntities(); // Renderables before their material instance
      mi.dispose();
      material.dispose();
      ib.dispose();
      quad.dispose();
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('IndexBuffer: ushort vs uint capacity and type guards', () {
      // Moved from vertex_index_buffer_smoke_test.dart.
      final ib16 = FilamentIndexBuffer.create(engine: rig.engine, indexCount: 6, type: IndexType.ushort);
      expect(ib16.byteCapacity, 12);
      ib16.setIndicesU16(Uint16List.fromList([0, 1, 2, 2, 3, 0]));
      expect(() => ib16.setIndicesU32(Uint32List(6)), throwsArgumentError);
      final ib32 = FilamentIndexBuffer.create(engine: rig.engine, indexCount: 12, type: IndexType.uint);
      expect(ib32.byteCapacity, 48);
      final big = Uint32List(12);
      for (var i = 0; i < 12; i++) {
        big[i] = i * 100000;
      }
      ib32.setIndicesU32(big);
      expect(() => ib32.setIndicesU16(Uint16List(12)), throwsArgumentError);
      rig.engine.flushAndWait();
      rig.engine.pumpMessageQueues();
      ib16.dispose();
      ib32.dispose();
    });
  });
}

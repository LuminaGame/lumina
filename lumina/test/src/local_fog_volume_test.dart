import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

/// The Local Fog Volume's honest approximation: an inward
/// wound, unlit, blended fog shell with baked vertex alpha, plus a blender
/// volume scaling the global fog while the camera is inside.
void main() {
  Map<String, dynamic> jsonChunk(Uint8List glb) {
    final bd = glb.buffer.asByteData();
    expect(bd.getUint32(0, Endian.little), 0x46546C67, reason: 'glTF magic');
    final jsonLength = bd.getUint32(12, Endian.little);
    expect(bd.getUint32(16, Endian.little), 0x4E4F534A, reason: 'JSON chunk');
    return jsonDecode(utf8.decode(glb.sublist(20, 20 + jsonLength))) as Map<String, dynamic>;
  }

  ({Float32List positions, Uint8List colors, Uint32List indices}) buffers(Uint8List glb, Map<String, dynamic> gltf) {
    final bd = glb.buffer.asByteData();
    final jsonLength = bd.getUint32(12, Endian.little);
    final binStart = 20 + jsonLength + 8;
    final views = (gltf['bufferViews'] as List).cast<Map>();
    Uint8List view(int i) =>
        glb.sublist(binStart + (views[i]['byteOffset'] as int), binStart + (views[i]['byteOffset'] as int) + (views[i]['byteLength'] as int));
    final p = view(0);
    final c = view(1);
    final ix = view(2);
    return (
      positions: Float32List.view(Uint8List.fromList(p).buffer),
      colors: Uint8List.fromList(c),
      indices: Uint32List.view(Uint8List.fromList(ix).buffer),
    );
  }

  group('LuminaFogShellGlbFactory', () {
    test('a sphere shell is a valid unlit, blended, single-sided GLB wound inward with baked vertex alpha', () {
      const density = 0.4;
      const radial = 0.5;
      final glb = LuminaFogShellGlbFactory.build(
        shape: LuminaLocalFogShape.sphere,
        radius: 500.0,
        extent: Vector3.all(500.0),
        albedo: Vector3(1.0, 0.5, 0.25),
        density: density,
        heightFalloff: 0.0,
        radialAttenuation: radial,
      );
      final gltf = jsonChunk(glb);
      expect((gltf['extensionsUsed'] as List), contains('KHR_materials_unlit'));
      final material = (gltf['materials'] as List).first as Map;
      expect(material['alphaMode'], 'BLEND');
      expect(material['doubleSided'], isFalse);
      expect((material['extensions'] as Map).containsKey('KHR_materials_unlit'), isTrue);
      final accessors = (gltf['accessors'] as List).cast<Map>();
      expect(accessors[1]['type'], 'VEC4');
      expect(accessors[1]['normalized'], isTrue);
      final primitive = ((gltf['meshes'] as List).first['primitives'] as List).first as Map;
      expect((primitive['attributes'] as Map)['COLOR_0'], 1);

      final b = buffers(glb, gltf);
      // Inward winding: the first triangle's normal points towards the centre.
      Vector3 at(int i) => Vector3(b.positions[i * 3], b.positions[i * 3 + 1], b.positions[i * 3 + 2]);
      var found = false;
      for (var t = 0; t + 2 < b.indices.length && !found; t += 3) {
        final v0 = at(b.indices[t]);
        final v1 = at(b.indices[t + 1]);
        final v2 = at(b.indices[t + 2]);
        final n = (v1 - v0).cross(v2 - v0);
        if (n.length < 1e-6) continue;
        expect(n.dot(v0), lessThan(0.0), reason: 'a face normal must point inward');
        found = true;
      }
      expect(found, isTrue);
      // Every sphere vertex sits on the rim: alpha = density · (1 − radial).
      for (var i = 0; i < b.colors.length; i += 4) {
        expect(b.colors[i], 255);
        expect(b.colors[i + 1], 128);
        expect(b.colors[i + 3], (density * (1 - radial) * 255).round());
      }
    });

    test('alphaAt: centre alpha is the density, rim alpha is attenuated, height falloff kills alpha above the centre only', () {
      double a(Vector3 p, {double falloff = 0.0}) => LuminaFogShellGlbFactory.alphaAt(
            p,
            reach: 500.0,
            density: 0.5,
            heightFalloff: falloff,
            radialAttenuation: 0.7,
          );
      expect(a(Vector3.zero()), closeTo(0.5, 1e-9));
      expect(a(Vector3(500.0, 0, 0)), closeTo(0.15, 1e-9));
      expect(a(Vector3(0, 500.0, 0), falloff: 2.0), lessThan(0.001), reason: '5 m above the centre at 2/m');
      expect(a(Vector3(0, -500.0, 0), falloff: 2.0), closeTo(0.15, 1e-9), reason: 'no falloff below the centre');
    });

    test('a box shell has six subdivided faces', () {
      final glb = LuminaFogShellGlbFactory.build(
        shape: LuminaLocalFogShape.box,
        radius: 0.0,
        extent: Vector3(100.0, 200.0, 300.0),
        albedo: Vector3.all(1.0),
        density: 0.3,
        heightFalloff: 0.0,
        radialAttenuation: 0.0,
      );
      final gltf = jsonChunk(glb);
      final accessors = (gltf['accessors'] as List).cast<Map>();
      const perFace = (LuminaFogShellGlbFactory.boxSubdivisions + 1) * (LuminaFogShellGlbFactory.boxSubdivisions + 1);
      expect(accessors[0]['count'], 6 * perFace);
      expect((accessors[0]['max'] as List)[2], closeTo(300.0, 1e-6));
    });
  });

  group('LuminaLocalFogVolumeComponent', () {
    test('fromProperties round-trips shape, box extent (Z-up → runtime), albedo, density, falloff, radial, enabled', () {
      final c = LuminaLocalFogVolumeComponent.fromProperties(const {
        'shape': 'box',
        'extentX': 100.0,
        'extentY': 300.0,
        'extentZ': 200.0,
        'fogAlbedoHex': '#FF8040',
        'fogDensity': 0.6,
        'heightFalloff': 1.5,
        'radialAttenuation': 0.2,
        'enabled': false,
      });
      expect(c.shape, LuminaLocalFogShape.box);
      expect(c.extent, Vector3(100.0, 200.0, 300.0));
      expect(c.fogAlbedo.x, closeTo(1.0, 1e-6));
      expect(c.fogAlbedo.y, closeTo(0x80 / 255.0, 1e-6));
      expect(c.fogDensity, 0.6);
      expect(c.heightFalloff, 1.5);
      expect(c.radialAttenuation, 0.2);
      expect(c.enabled, isFalse);
      expect(LuminaLocalFogVolumeComponent.fromProperties(const {'shape': 'nonsense'}).shape, LuminaLocalFogShape.sphere);
    });

    test('registering adds a shadowless shell child and a blender volume; disabling hides both; unregister removes both', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      addTearDown(world.cleanup);
      final fog = LuminaLocalFogVolumeComponent(radius: 400.0, fogDensity: 0.35, fogAlbedo: Vector3(0.1, 0.2, 0.3));
      final actor = LuminaActor(root: fog);
      world.persistentLevel.registerActor(actor);

      final shell = fog.shell;
      expect(shell, isNotNull);
      expect(shell!.castShadows, isFalse);
      expect(shell.receiveShadows, isFalse);
      expect(actor.components, contains(shell));
      expect(shell.parentComponent, same(fog));
      expect(shell.meshAssetPath, startsWith('lumina-fogshell:sphere:400.0'));

      final volumes = world.postProcessBlender.volumes;
      expect(volumes, hasLength(1));
      final v = volumes.single;
      expect(v.priority, LuminaLocalFogVolumeComponent.blenderPriority);
      expect(v.sphereRadius, 400.0);
      expect(v.blendRadius, 200.0);
      expect(v.overrides.fogDensityScale, closeTo(1 + 10 * 0.35, 1e-9));
      expect(v.overrides.fogColor, Vector3(0.1, 0.2, 0.3));

      world.beginPlay();
      fog.enabled = false;
      world.tick(1 / 60);
      expect(shell.visible, isFalse);
      expect(v.enabled, isFalse);

      world.persistentLevel.unregisterActor(actor);
      expect(world.postProcessBlender.volumes, isEmpty);
      expect(fog.shell, isNull);
    });

    test('a density edit rebuilds the shell under a new key; an unrelated tick keeps it', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      addTearDown(world.cleanup);
      final fog = LuminaLocalFogVolumeComponent();
      final actor = LuminaActor(root: fog);
      world.persistentLevel.registerActor(actor);
      world.beginPlay();
      final first = fog.shell!;
      world.tick(1 / 60);
      expect(fog.shell, same(first));
      fog.fogDensity = 0.8;
      world.tick(1 / 60);
      expect(fog.shell, isNot(same(first)));
      expect(fog.shell!.meshAssetPath, isNot(first.meshAssetPath));
      expect(actor.components, isNot(contains(first)));
      expect(world.postProcessBlender.volumes.single.overrides.fogDensityScale, closeTo(9.0, 1e-9));
    });
  });
}

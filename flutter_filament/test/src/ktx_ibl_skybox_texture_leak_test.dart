// An IndirectLight or Skybox made from KTX bytes owns the cubemap
// texture the wrapper created for it; destroying it must destroy that too.
import 'dart:io';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const dir = 'example/assets/ibl/lightroom_14b';
  final ibl = File('$dir/lightroom_14b_ibl.ktx');
  final sky = File('$dir/lightroom_14b_skybox.ktx');

  test('IndirectLight.fromKtx: dispose frees its reflections cubemap', () {
    final engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
    addTearDown(engine.dispose);
    final base = engine.resourceCounts;
    for (var i = 0; i < 3; i++) {
      final light = FilamentIndirectLight.fromKtx(engine, ibl.readAsBytesSync(), intensity: 30000);
      expect((engine.resourceCounts - base).textures, 1);
      light.dispose();
      expect((engine.resourceCounts - base).nonZero, isEmpty, reason: 'round $i');
    }
  });

  test('Skybox.fromKtx: dispose frees its environment cubemap', () {
    final engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
    addTearDown(engine.dispose);
    final base = engine.resourceCounts;
    final skybox = FilamentSkybox.fromKtx(engine, sky.readAsBytesSync());
    expect((engine.resourceCounts - base).textures, 1);
    skybox.dispose();
    expect((engine.resourceCounts - base).textures, 0);
  });

  test('an IndirectLight built on a caller\'s texture leaves that texture alone', () {
    final engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
    addTearDown(engine.dispose);
    final cube = FilamentTexture.create(
      engine: engine,
      desc: const TextureDescriptor(
        width: 16,
        height: 16,
        levels: 1,
        samplerType: TextureSamplerType.samplerCubemap,
        format: TextureFormat.rgba8,
      ),
    );
    final light = FilamentIndirectLight.build(engine, reflections: cube, intensity: 1000);
    light.dispose();
    expect(engine.isValidTexture(cube.nativePointer), isTrue, reason: 'the caller owns it');
    cube.dispose();
  });
}

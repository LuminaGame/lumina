import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';

import '../smoke/smoke_helper.dart';

/// Ray tracing foundation: acceleration structures per scene (Vulkan ray
/// query), a visibility-ray test hook and ray-traced directional shadows.
void main() {
  group('ray tracing without a GPU (noop backend)', () {
    late FilamentEngine engine;
    late FilamentScene scene;

    setUp(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
      scene = engine.createScene();
    });
    tearDown(() {
      scene.dispose();
      engine.dispose();
    });

    test('reports no ray query support, accepts the scene flag and traces nothing', () async {
      expect(engine.supportsRayQuery, isFalse);
      scene.rayTracingEnabled = true;
      expect(scene.rayTracingEnabled, isTrue);
      expect(scene.tlasInstanceCount, 0);
      expect(scene.lastTlasBuildTime, Duration.zero);
      final hit = await scene.traceVisibility(0, 0, -5, 0, 0, 1);
      expect(hit, isNull);
      expect(ShadowOptions().rayTraced, isFalse);
    });
  });

  group('ray tracing on the RTX GPU (Vulkan)', () {
    const size = 256;
    SmokeRig? rig;
    final materials = <FilamentMaterial>[];
    final instances = <FilamentMaterialInstance>[];
    final quads = <SmokeQuad>[];

    setUp(() {
      if (Platform.environment['FILAMENT_TEST_BACKEND'] == 'opengl') return;
      RayTracing.requestExtensions();
      FilamentEngine? engine;
      try {
        engine = FilamentEngine.create(backend: FilamentBackend.vulkan);
      } catch (_) {
        engine = null;
      }
      if (engine == null) return;
      rig = SmokeRig.adopt(engine, width: size, height: size);
      // Orthographic 2.56 world units across: 1 unit = 100 texels. The camera
      // looks down -Z from z = 10.
      rig!.camera.setProjectionOrtho(left: -1.28, right: 1.28, bottom: -1.28, top: 1.28, near: 0.1, far: 100);
      rig!.camera.lookAt(eyeX: 0, eyeY: 0, eyeZ: 10, centerX: 0, centerY: 0, centerZ: 0);
    });

    tearDown(() {
      // renderables go before the material instances and buffers they use
      if (rig != null) {
        for (final e in rig!.entities) {
          rig!.engine.destroyEntity(e);
        }
        rig!.entities.clear();
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
      RayTracing.clearExtensionRequest();
    });

    bool skipWithoutRayQuery() {
      if (rig == null) {
        markTestSkipped('needs a Vulkan device');
        return true;
      }
      if (!rig!.engine.supportsRayQuery) {
        markTestSkipped('this GPU or driver has no Vulkan ray query support');
        return true;
      }
      return false;
    }

    /// A unit quad (1 x 1 world units) facing +Z at depth [z], shifted by [x];
    /// unlit by default, [lit] when it has to receive shadows.
    int addQuad(
      SmokeRig r, {
      double z = 0,
      double x = 0,
      double sizeUnits = 1.0,
      (double, double, double) color = (0.8, 0.8, 0.8),
      bool lit = false,
    }) {
      final quad = SmokeQuad.create(r.engine, size: sizeUnits, z: 0, tangents: lit);
      quads.add(quad);
      final material = lit ? buildLitMaterial(r.engine) : buildUnlitMaterial(r.engine);
      materials.add(material);
      final mi = material.createInstance()..setFloat3('baseColor', color.$1, color.$2, color.$3);
      instances.add(mi);
      final entity = addQuadRenderable(r, quad, mi, extent: sizeUnits);
      FilamentTransformManager(r.engine).setTransform(entity, [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, x, 0, z, 1]);
      return entity;
    }

    test('three props build one TLAS instance each after a frame, with a measured build time', () {
      if (skipWithoutRayQuery()) return;
      final r = rig!;
      rig!.addSun();
      final a = loadGltfIntoScene(r, 'Props/Barrels/empty_barrel.glb', frameCamera: false);
      final b = loadGltfIntoScene(r, 'Props/AC_units/ac_unit_a_300x300.glb', frameCamera: false);
      final c = loadGltfIntoScene(r, 'Props/Access_cards/access_card_blue.glb', frameCamera: false);
      try {
        r.scene.rayTracingEnabled = true;
        r.renderFrame(warmup: 1);
        expect(r.scene.tlasInstanceCount, 3, reason: 'one instance per renderable');
        // the GPU timer of a build resolves a few frames later
        for (var i = 0; i < 20 && r.scene.lastTlasBuildTime == Duration.zero; i++) {
          r.renderFrame(warmup: 0);
        }
        expect(r.scene.lastTlasBuildTime, greaterThan(Duration.zero));
      } finally {
        a.dispose(r.scene);
        b.dispose(r.scene);
        c.dispose(r.scene);
      }
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('a visibility ray hits the quad at the right distance, respects maxDistance and misses', () async {
      if (skipWithoutRayQuery()) return;
      final r = rig!;
      final front = addQuad(r, z: 0.5);
      r.scene.rayTracingEnabled = true;
      r.renderFrame(warmup: 1);

      final hit = await r.scene.traceVisibility(0, 0, -5, 0, 0, 1);
      expect(hit, isNotNull);
      expect(hit!.t, closeTo(5.5, 0.01), reason: 'from z=-5 to the quad at z=0.5');
      expect(hit.entity, front);

      final tooShort = await r.scene.traceVisibility(0, 0, -5, 0, 0, 1, maxDistance: 1);
      expect(tooShort, isNull);

      final miss = await r.scene.traceVisibility(3, 3, -5, 0, 0, 1);
      expect(miss, isNull);
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('hiding a renderable from ray tracing lets the ray reach the mesh behind it', () async {
      if (skipWithoutRayQuery()) return;
      final r = rig!;
      final front = addQuad(r, z: 0.5);
      final back = addQuad(r, z: 2.0, sizeUnits: 2.0);
      r.scene.rayTracingEnabled = true;
      r.renderFrame(warmup: 1);
      expect(r.scene.tlasInstanceCount, 2);
      final first = await r.scene.traceVisibility(0, 0, -5, 0, 0, 1);
      expect(first!.entity, front);

      final rm = FilamentRenderableManager(r.engine);
      rm.setRayTracingVisible(front, false);
      expect(rm.isRayTracingVisible(front), isFalse);
      r.renderFrame(warmup: 0);
      expect(r.scene.tlasInstanceCount, 1);
      final second = await r.scene.traceVisibility(0, 0, -5, 0, 0, 1);
      expect(second, isNotNull);
      expect(second!.entity, back);
      expect(second.t, closeTo(7.0, 0.01));
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('moving a renderable between frames moves the hit distance', () async {
      if (skipWithoutRayQuery()) return;
      final r = rig!;
      final quad = addQuad(r, z: 0.5);
      r.scene.rayTracingEnabled = true;
      r.renderFrame(warmup: 1);
      final before = await r.scene.traceVisibility(0, 0, -5, 0, 0, 1);
      FilamentTransformManager(r.engine).setTransform(quad, [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0.8, 1]);
      r.renderFrame(warmup: 0);
      final after = await r.scene.traceVisibility(0, 0, -5, 0, 0, 1);
      expect(after!.t - before!.t, closeTo(0.3, 0.01));
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('a skinned renderable is traced in its bind pose: the hit does not follow the animation', () async {
      // The acceleration structures read the vertex buffers; hardware skinning happens in
      // the vertex shader, and there is no compute pre-pass applying the palette yet, so a
      // skinned character keeps its bind-pose geometry for rays whatever pose it renders.
      if (skipWithoutRayQuery()) return;
      final r = rig!;
      final gltf = loadGltfIntoScene(r, 'mannequin/MF_Unarmed_Walk_Fwd.glb', frameCamera: false);
      try {
        r.scene.rayTracingEnabled = true;
        final animator = gltf.asset.animator;
        final duration = animator.getAnimationDuration(0);
        final box = gltf.asset.getBoundingBox();
        final center = box.center;
        // a ray through the middle of the torso, from the front
        final oz = box.max.z + 1.0;
        Future<RayHit?> probe(double time) async {
          animator.applyAnimation(0, time);
          animator.updateBoneMatrices();
          r.renderFrame(warmup: 0);
          return r.scene.traceVisibility(center.x, center.y, oz, 0, 0, -1, maxDistance: 10);
        }

        final first = await probe(0);
        expect(first, isNotNull, reason: 'the torso is in the bind pose too');
        for (var i = 1; i < 4; i++) {
          final hit = await probe(duration * i / 4);
          expect(hit, isNotNull);
          expect(hit!.t, closeTo(first!.t, 1e-4), reason: 'the geometry rays see does not move with the pose');
        }
      } finally {
        gltf.dispose(r.scene);
      }
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('a Draco-compressed barrel is solid for rays: lid or bottom from above, walls from every side', () async {
      if (skipWithoutRayQuery()) return;
      final r = rig!;
      for (final barrel in ['Props/Barrels/fuel_barrel_red.glb', 'Props/Barrels/dented_barrel.glb']) {
        final gltf = loadGltfIntoScene(r, barrel, frameCamera: false);
        try {
          r.scene.rayTracingEnabled = true;
          r.renderFrame(warmup: 1);
          final box = gltf.asset.getBoundingBox();
          final c = box.center;
          final radius = (box.max.x - box.min.x) / 2;
          final misses = <String>[];
          // straight down over the inner disc: the closed barrel's lid, the open one's bottom
          for (var i = -3; i <= 3; i++) {
            for (var j = -3; j <= 3; j++) {
              final dx = i / 3 * radius * 0.7, dz = j / 3 * radius * 0.7;
              if (dx * dx + dz * dz > radius * radius * 0.49) continue;
              final hit = await r.scene.traceVisibility(c.x + dx, box.max.y + 1, c.z + dz, 0, -1, 0, maxDistance: 10);
              if (hit == null) misses.add('down ($dx, $dz)');
            }
          }
          // horizontally through the side walls at several heights
          for (var k = 1; k < 10; k++) {
            final y = box.min.y + (box.max.y - box.min.y) * k / 10;
            for (var a = 0; a < 8; a++) {
              final ang = a * math.pi / 4;
              final hit = await r.scene.traceVisibility(
                c.x + (radius + 1) * math.cos(ang),
                y,
                c.z + (radius + 1) * math.sin(ang),
                -math.cos(ang),
                0,
                -math.sin(ang),
                maxDistance: 10,
              );
              if (hit == null || hit.t > 1 + radius * 0.5) misses.add('wall y=$y a=$a t=${hit?.t}');
            }
          }
          expect(misses, isEmpty, reason: barrel);
        } finally {
          gltf.dispose(r.scene);
        }
      }
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('ray-traced sun shadows of a barrel in a centimetre-scale scene are as solid as the shadow map ones', () {
      // A level in centimetres: a 115 cm barrel on a 20 m floor, a camera 13 m away with a
      // 10 cm near plane. The shadow ray's self-intersection offset must stay a few pixels
      // wide in world units, not grow with the scene's unit, or it jumps over the occluder.
      if (skipWithoutRayQuery()) return;
      final r = rig!;
      final floor = addQuad(r, sizeUnits: 2000, color: (0.9, 0.9, 0.9), lit: true);
      expect(floor, isNonZero);
      final gltf = loadGltfIntoScene(r, 'Props/Barrels/fuel_barrel_red.glb', frameCamera: false);
      try {
        // the barrel is Y-up in metres: stand it on the Z-up floor, scaled to centimetres
        FilamentTransformManager(
          r.engine,
        ).setTransform(gltf.asset.rootEntity, [100, 0, 0, 0, 0, 0, 100, 0, 0, -100, 0, 0, 0, 0, 0, 1]);
        r.camera.setProjection(fovDegrees: 45, aspect: 1, near: 10, far: 100000);
        r.camera.lookAt(eyeX: 0, eyeY: -900, eyeZ: 950, centerX: 30, centerY: 0, centerZ: 40);
        final lm = FilamentLightManager(r.engine);
        final sun = r.addSun();
        lm.setDirection(sun, 0.5, 0.3, -1);
        r.scene.rayTracingEnabled = true;

        Uint8List render({required bool shadows, bool rayTraced = false}) {
          lm.setShadowCaster(sun, shadows);
          lm.setShadowOptions(sun, ShadowOptions(mapSize: 2048, rayTraced: rayTraced));
          return r.renderFrame(warmup: 3);
        }

        final unshadowed = render(shadows: false);
        final csm = render(shadows: true);
        final rt = render(shadows: true, rayTraced: true);
        int darkened(Uint8List img) {
          var n = 0;
          for (var y = 0; y < size; y++) {
            for (var x = 0; x < size; x++) {
              final (a, _, _) = pixelAt(unshadowed, size, x, y);
              final (b, _, _) = pixelAt(img, size, x, y);
              if (a - b > 30) n++;
            }
          }
          return n;
        }

        final csmDark = darkened(csm);
        final rtDark = darkened(rt);
        expect(csmDark, greaterThan(150), reason: 'the shadow map draws the barrel shadow');
        expect(rtDark, greaterThan(csmDark * 0.8), reason: 'ray-traced: $rtDark darkened texels, shadow map: $csmDark');
      } finally {
        gltf.dispose(r.scene);
      }
    }, timeout: const Timeout(Duration(minutes: 3)));
    test('ray-traced directional shadows darken the floor under an occluder with a hard edge', () {
      if (skipWithoutRayQuery()) return;
      final r = rig!;
      // Floor: a big quad facing the camera; occluder: a small quad in front of it.
      // The sun shines straight down the view axis, so the occluder's shadow lands
      // right behind it on the floor.
      addQuad(r, z: 0, sizeUnits: 2.4, color: (0.9, 0.9, 0.9), lit: true);
      addQuad(r, z: 1.0, sizeUnits: 0.6, color: (0.3, 0.3, 0.3), lit: true);
      final lm = FilamentLightManager(r.engine);
      final sun = r.addSun();
      lm.setDirection(sun, 0, 0, -1);
      lm.setShadowCaster(sun, true);
      r.scene.rayTracingEnabled = true;

      Uint8List render(bool rayTraced) {
        lm.setShadowOptions(sun, ShadowOptions(mapSize: 1024, rayTraced: rayTraced));
        return r.renderFrame(warmup: 3);
      }

      // The floor right behind the occluder is hidden by the occluder itself at
      // this camera, so the sun is tilted: light travelling towards +X moves the
      // occluder's shadow 0.5 units (50 texels) to the right, next to it.
      lm.setDirection(sun, 0.5, 0, -1);
      final csm = render(false);
      final rt = render(true);
      final cx = size ~/ 2;
      final cy = size ~/ 2;
      final shadowX = cx + 65; // inside the offset shadow, right of the occluder (occluder spans +-30 texels)
      final litX = cx + 110;
      final (csmShadow, _, _) = pixelAt(csm, size, shadowX, cy);
      final (csmLit, _, _) = pixelAt(csm, size, litX, cy);
      final (rtShadow, _, _) = pixelAt(rt, size, shadowX, cy);
      final (rtLit, _, _) = pixelAt(rt, size, litX, cy);
      expect(rtLit - rtShadow, greaterThanOrEqualTo(csmLit - csmShadow), reason: 'at least the CSM contrast');
      expect(rtLit - rtShadow, greaterThan(40), reason: 'a visible shadow');
      // Hard edge: along the row, the transition between shadow and lit spans at most 2 texels.
      var transition = 0;
      for (var x = shadowX; x < litX; x++) {
        final (v, _, _) = pixelAt(rt, size, x, cy);
        if (v > rtShadow + 8 && v < rtLit - 8) transition++;
      }
      expect(transition, lessThanOrEqualTo(2));
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('destroying scene and engine with acceleration structures alive leaks nothing', () {
      if (skipWithoutRayQuery()) return;
      final r = rig!;
      final gltf = loadGltfIntoScene(r, 'Props/Barrels/empty_barrel.glb', frameCamera: false);
      r.scene.rayTracingEnabled = true;
      r.renderFrame(warmup: 2);
      expect(r.scene.tlasInstanceCount, greaterThan(0));
      gltf.dispose(r.scene);
      r.engine.flushAndWait();
      // The rig's dispose() leaves scene and view to the engine; the engine
      // shutdown must release the acceleration structures with them.
      r.dispose();
      rig = null;
    }, timeout: const Timeout(Duration(minutes: 3)));
  });

  group('ray tracing on an engine created without the extensions', () {
    test('ray query is unsupported and rayTraced shadows fall back to the shadow maps', () {
      if (Platform.environment['FILAMENT_TEST_BACKEND'] == 'opengl') {
        markTestSkipped('Vulkan only');
        return;
      }
      RayTracing.clearExtensionRequest();
      FilamentEngine? engine;
      try {
        engine = FilamentEngine.create(backend: FilamentBackend.vulkan);
      } catch (_) {
        engine = null;
      }
      if (engine == null) {
        markTestSkipped('needs a Vulkan device');
        return;
      }
      final rig = SmokeRig.adopt(engine, width: 256, height: 256);
      final gltf = loadGltfIntoScene(rig, 'Props/Barrels/empty_barrel.glb');
      try {
        expect(engine.supportsRayQuery, isFalse);
        final lm = FilamentLightManager(engine);
        final sun = rig.addSun();
        lm.setShadowCaster(sun, true);
        rig.scene.rayTracingEnabled = true;
        lm.setShadowOptions(sun, ShadowOptions(rayTraced: false));
        final csmA = rig.renderFrame(warmup: 3);
        final csmB = rig.renderFrame(warmup: 3);
        // two CSM frames of the same scene differ by a few shadow-edge texels
        final noise = countChangedPixels(csmA, csmB, tolerance: 3);
        lm.setShadowOptions(sun, ShadowOptions(rayTraced: true));
        final fallback = rig.renderFrame(warmup: 3);
        expect(
          countChangedPixels(fallback, csmB, tolerance: 3),
          lessThanOrEqualTo(noise + 16),
          reason: 'without ray query the CSM render is used unchanged',
        );
        expect(rig.scene.tlasInstanceCount, 0);
      } finally {
        gltf.dispose(rig.scene);
        rig.dispose();
      }
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}

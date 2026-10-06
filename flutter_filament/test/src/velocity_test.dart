import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/src/ffi_platform.dart' as ffi;
import 'package:flutter_filament/src/third_party/filament_c.g.dart' as c;
import 'package:test/test.dart';

import '../smoke/smoke_helper.dart';

/// Motion vectors: `TemporalAntiAliasingOptions.motionVectors` makes the
/// structure pass render, per pixel, how far the visible surface moved on
/// screen since the previous frame (in texels, x right, y up), exported
/// through `MotionVectorBuffer`.
void main() {
  group('motion vector options (noop backend)', () {
    late FilamentEngine engine;
    late FilamentView view;

    setUp(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
      view = engine.createView();
    });

    tearDown(() => engine.dispose());

    test('motionVectors defaults to off and round-trips through the view', () {
      expect(const TemporalAntiAliasingOptions().motionVectors, isFalse);
      view.temporalAntiAliasingOptions = const TemporalAntiAliasingOptions(enabled: true, motionVectors: true);
      expect(view.temporalAntiAliasingOptions.motionVectors, isTrue);
      expect(view.temporalAntiAliasingOptions.enabled, isTrue);
      view.temporalAntiAliasingOptions = view.temporalAntiAliasingOptions.copyWith(motionVectors: false);
      expect(view.temporalAntiAliasingOptions.motionVectors, isFalse);
    });

    test('the Dart mirror of the TAA options has the native size', () {
      expect(c.filament_options_sizeof(8), ffi.sizeOf<c.filament_temporal_anti_aliasing_options>());
    });

    test('the noop backend reports no motion vector support and attaching a buffer throws', () {
      expect(view.motionVectorsSupported, isFalse);
      expect(view.motionVectorTexture, isNull);
      expect(
        () => MotionVectorBuffer.attach(engine: engine, view: view, width: 64, height: 64),
        throwsStateError,
      );
      // A frame with the option on renders without the second attachment and without errors.
      final swapChain = engine.createHeadlessSwapChain(64, 64);
      final renderer = engine.createRenderer();
      view.temporalAntiAliasingOptions = const TemporalAntiAliasingOptions(enabled: true, motionVectors: true);
      view.setViewport(0, 0, 64, 64);
      if (renderer.beginFrame(swapChain)) {
        renderer.render(view);
        renderer.endFrame();
      }
      engine.flushAndWait();
      renderer.dispose();
    });
  });

  group('motion vectors on the GPU', () {
    const size = 256;
    SmokeRig? rig;
    LoadedGltf? gltf;
    MotionVectorBuffer? motion;

    setUp(() {
      FilamentEngine? engine;
      try {
        // Vulkan by default; FILAMENT_TEST_BACKEND=opengl runs the same tests on OpenGL.
        final backend = Platform.environment['FILAMENT_TEST_BACKEND'] == 'opengl'
            ? FilamentBackend.opengl
            : FilamentBackend.vulkan;
        engine = FilamentEngine.create(backend: backend);
      } catch (_) {
        engine = null;
      }
      if (engine == null) return;
      rig = SmokeRig.adopt(engine, width: size, height: size);
      // An orthographic window of 2.56 world units: 1 unit = 100 texels, so
      // a move of 0.08 units is exactly 8 texels on screen.
      rig!.camera.setProjectionOrtho(left: -1.28, right: 1.28, bottom: -1.28, top: 1.28, near: 0.1, far: 100);
      rig!.camera.lookAt(eyeX: 0, eyeY: 0, eyeZ: 10, centerX: 0, centerY: 0, centerZ: 0);
      rig!.addSun();
    });

    tearDown(() {
      motion?.dispose();
      motion = null;
      if (gltf != null && rig != null) gltf!.dispose(rig!.scene);
      gltf = null;
      rig?.dispose();
      rig = null;
    });

    /// Loads a real prop, centres it on the origin and returns its root entity.
    int loadCentredProp(SmokeRig r) {
      gltf = loadGltfIntoScene(r, 'Props/Barrels/empty_barrel.glb', frameCamera: false);
      final box = gltf!.asset.getBoundingBox();
      final center = box.center;
      FilamentTransformManager(r.engine).setTransform(gltf!.asset.rootEntity, _translation(-center.x, -center.y, -center.z));
      return gltf!.asset.rootEntity;
    }

    test('a renderable moved by 8 texels reports (8, 0) and the background stays (0, 0)', () async {
      final r = rig;
      if (r == null) {
        markTestSkipped('needs a Vulkan device');
        return;
      }
      expect(r.view.motionVectorsSupported, isTrue);
      final root = loadCentredProp(r);
      motion = MotionVectorBuffer.attach(engine: r.engine, view: r.view, width: size, height: size);
      expect(r.view.motionVectorTexture, same(motion!.texture));
      r.view.temporalAntiAliasingOptions = const TemporalAntiAliasingOptions(enabled: false, motionVectors: true);

      final tm = FilamentTransformManager(r.engine);
      final box = gltf!.asset.getBoundingBox();
      final center = box.center;
      // Two still frames, then the move: frame N-1 and frame N differ by +0.08 units in x.
      r.renderFrame(warmup: 1);
      tm.setTransform(root, _translation(-center.x + 0.08, -center.y, -center.z));
      r.renderFrame(warmup: 0);

      final velocity = await motion!.read(r.renderer);
      final (vx, vy) = motion!.velocityAt(velocity, size ~/ 2 + 8, size ~/ 2);
      expect(vx, closeTo(8.0, 0.5), reason: 'x motion of the surface now at the centre + 8');
      expect(vy, closeTo(0.0, 0.5));
      final (bx, by) = motion!.velocityAt(velocity, 6, 6);
      expect(bx.abs(), lessThan(1e-3), reason: 'background x');
      expect(by.abs(), lessThan(1e-3), reason: 'background y');
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('camera motion alone yields the matrix-reprojection velocity', () async {
      final r = rig;
      if (r == null) {
        markTestSkipped('needs a Vulkan device');
        return;
      }
      loadCentredProp(r);
      motion = MotionVectorBuffer.attach(engine: r.engine, view: r.view, width: size, height: size);
      r.view.temporalAntiAliasingOptions = const TemporalAntiAliasingOptions(enabled: false, motionVectors: true);

      r.renderFrame(warmup: 1);
      // Panning the camera 0.06 units to the left moves everything 6 texels to the right.
      r.camera.lookAt(eyeX: -0.06, eyeY: 0, eyeZ: 10, centerX: -0.06, centerY: 0, centerZ: 0);
      r.renderFrame(warmup: 0);

      final velocity = await motion!.read(r.renderer);
      final (vx, vy) = motion!.velocityAt(velocity, size ~/ 2 + 6, size ~/ 2);
      expect(vx, closeTo(6.0, 0.5));
      expect(vy, closeTo(0.0, 0.5));
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('a still scene reports zero motion everywhere, and off leaves the export untouched', () async {
      final r = rig;
      if (r == null) {
        markTestSkipped('needs a Vulkan device');
        return;
      }
      loadCentredProp(r);
      motion = MotionVectorBuffer.attach(engine: r.engine, view: r.view, width: size, height: size);
      r.view.temporalAntiAliasingOptions = const TemporalAntiAliasingOptions(enabled: false, motionVectors: true);
      r.renderFrame(warmup: 2);
      final still = await motion!.read(r.renderer);
      var maxAbs = 0.0;
      for (final v in still) {
        if (v.abs() > maxAbs) maxAbs = v.abs();
      }
      expect(maxAbs, lessThan(0.05), reason: 'nothing moved between the last two frames');

      // With motion vectors off the structure pass no longer writes the texture.
      r.view.temporalAntiAliasingOptions = const TemporalAntiAliasingOptions(enabled: false, motionVectors: false);
      final tm = FilamentTransformManager(r.engine);
      final center = gltf!.asset.getBoundingBox().center;
      tm.setTransform(gltf!.asset.rootEntity, _translation(-center.x + 0.3, -center.y, -center.z));
      r.renderFrame(warmup: 1);
      final off = await motion!.read(r.renderer);
      var maxOff = 0.0;
      for (final v in off) {
        if (v.abs() > maxOff) maxOff = v.abs();
      }
      expect(maxOff, lessThan(0.05), reason: 'the export texture keeps its last (zero) content');
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('TAA with motion vectors keeps a moving prop sharper than matrix reprojection', () async {
      final r = rig;
      if (r == null) {
        markTestSkipped('needs a Vulkan device');
        return;
      }
      final root = loadCentredProp(r);
      final tm = FilamentTransformManager(r.engine);
      final center = gltf!.asset.getBoundingBox().center;
      const frames = 24;
      const step = 0.03; // 3 texels per frame

      Uint8List run({required bool taa, required bool motionVectors}) {
        r.view.temporalAntiAliasingOptions = TemporalAntiAliasingOptions(enabled: taa, motionVectors: motionVectors);
        var x = -center.x - step * frames / 2;
        tm.setTransform(root, _translation(x, -center.y, -center.z));
        r.renderFrame(warmup: 3);
        Uint8List? last;
        for (var f = 0; f < frames; f++) {
          x += step;
          tm.setTransform(root, _translation(x, -center.y, -center.z));
          last = r.renderFrame(warmup: 0);
        }
        return last!;
      }

      final reference = run(taa: false, motionVectors: false);
      final withVelocity = run(taa: true, motionVectors: true);
      final withMatrix = run(taa: true, motionVectors: false);

      // Mean absolute difference to the un-antialiased reference over the
      // centre region the prop sweeps through.
      double diff(Uint8List a) {
        var sum = 0.0;
        var n = 0;
        for (var y = size ~/ 2 - 40; y < size ~/ 2 + 40; y++) {
          for (var x = size ~/ 2 - 60; x < size ~/ 2 + 60; x++) {
            final i = (y * size + x) * 4;
            for (var k = 0; k < 3; k++) {
              sum += (a[i + k] - reference[i + k]).abs();
              n++;
            }
          }
        }
        return sum / n;
      }

      final velocityError = diff(withVelocity);
      final matrixError = diff(withMatrix);
      expect(velocityError, lessThan(matrixError * 0.9),
          reason: 'per-pixel reprojection must ghost less than the camera-matrix one '
              '(error vs reference: motion vectors=${velocityError.toStringAsFixed(2)}, '
              'matrix=${matrixError.toStringAsFixed(2)})');
    }, timeout: const Timeout(Duration(minutes: 5)));

    test('a skinned character playing a clip has motion on its limbs', () async {
      final r = rig;
      if (r == null) {
        markTestSkipped('needs a Vulkan device');
        return;
      }
      gltf = loadGltfIntoScene(r, 'mannequin/MF_Unarmed_Walk_Fwd.glb');
      final animator = gltf!.asset.animator;
      final duration = animator.getAnimationDuration(0);
      motion = MotionVectorBuffer.attach(engine: r.engine, view: r.view, width: size, height: size);
      r.view.temporalAntiAliasingOptions = const TemporalAntiAliasingOptions(enabled: false, motionVectors: true);

      animator.applyAnimation(0, 0.0);
      animator.updateBoneMatrices();
      r.renderFrame(warmup: 2);
      animator.applyAnimation(0, duration * 0.25);
      animator.updateBoneMatrices();
      r.renderFrame(warmup: 0);

      final velocity = await motion!.read(r.renderer);
      var moving = 0;
      for (var i = 0; i < velocity.length; i += 2) {
        if (velocity[i].abs() + velocity[i + 1].abs() > 1.0) moving++;
      }
      expect(moving, greaterThan(size * size ~/ 400), reason: 'limbs moving by over a texel must show up');
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('a morphed quad moves only where its target displaces it', () async {
      final r = rig;
      if (r == null) {
        markTestSkipped('needs a Vulkan device');
        return;
      }
      // A 1-unit (100 texel) quad whose single morph target pushes its two
      // right-hand vertices by +0.3 units in x; the left edge stays put.
      final quad = SmokeQuad.create(r.engine);
      final mtb = MorphTargetBuffer.create(r.engine, vertexCount: 4, count: 1);
      mtb.setPositionsAt(0, Float32List.fromList([0, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0, 0, 0]));
      final material = buildUnlitMaterial(r.engine);
      final mi = material.createInstance()..setFloat3('baseColor', 0.9, 0.5, 0.1);
      final entity = r.engine.createEntity();
      RenderableBuilder(1)
        ..boundingBox(-1, -1, -1, 1, 1, 1)
        ..culling(false)
        ..material(0, mi)
        ..morphing(1)
        ..morphingBuffer(mtb)
        ..geometry(0, PrimitiveType.triangles, quad.vb, ib: quad.ib)
        ..build(r.engine, entity);
      r.scene.addEntity(entity);
      r.entities.add(entity);
      final rm = FilamentRenderableManager(r.engine);
      motion = MotionVectorBuffer.attach(engine: r.engine, view: r.view, width: size, height: size);
      r.view.temporalAntiAliasingOptions = const TemporalAntiAliasingOptions(enabled: false, motionVectors: true);

      try {
        rm.setMorphWeights(entity, Float32List.fromList([0.0]));
        r.renderFrame(warmup: 2);
        rm.setMorphWeights(entity, Float32List.fromList([1.0]));
        r.renderFrame(warmup: 0);

        final velocity = await motion!.read(r.renderer);
        // The surface now at x = +0.4 came from x = -0.5 + 1.3 t with
        // t = 0.9 / 1.3, i.e. from x = 0.19: about 21 texels of motion.
        final (rightX, rightY) = motion!.velocityAt(velocity, size ~/ 2 + 40, size ~/ 2);
        expect(rightX, closeTo(20.8, 2.0), reason: 'the displaced half moves');
        expect(rightY.abs(), lessThan(0.5));
        // Two texels in from the undisplaced left edge the motion is under a texel.
        final (leftX, _) = motion!.velocityAt(velocity, size ~/ 2 - 48, size ~/ 2);
        expect(leftX.abs(), lessThan(1.0), reason: 'the fixed edge barely moves');
        final (bx, by) = motion!.velocityAt(velocity, size ~/ 2 - 60, size ~/ 2);
        expect(bx.abs() + by.abs(), lessThan(1e-3), reason: 'background outside the quad');
      } finally {
        r.scene.removeEntity(entity);
        r.engine.destroyEntity(entity);
        r.entities.remove(entity);
        mi.dispose();
        material.dispose();
        mtb.dispose();
        quad.dispose();
      }
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}

List<double> _translation(double x, double y, double z) =>
    [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, x, y, z, 1];

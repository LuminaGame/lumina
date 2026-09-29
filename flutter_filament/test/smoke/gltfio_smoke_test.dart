// gltfio smoke: real GLB assets from test-assets/ loaded through
// AssetLoader + ResourceLoader (Draco + WebP textures), rendered on the GPU
// backend, with a skinned mannequin walk cycle recorded as a WebM.
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/testing.dart';
import 'package:test/test.dart';

import 'smoke_helper.dart';

void main() {
  group('gltfio Smoke Tests', () {
    late SmokeRig rig;
    FilamentIndirectLight? ibl;

    setUp(() {
      SmokeArtifacts.resetRecordedAssets();
      rig = SmokeRig.create(width: smokeVideoWidth, height: smokeVideoHeight);
      rig.addSun();
      ibl = rig.addIbl();
    });

    tearDown(() {
      rig.scene.setIndirectLight(null);
      ibl?.dispose();
      rig.dispose();
      SmokeArtifacts.resetRecordedAssets();
    });

    test('gltfio: Draco+WebP helicopter GLB renders with ubershader materials', () {
      final gltf = loadGltfIntoScene(rig, 'fixtures/attackhelicopter.entity.glb');
      try {
        expect(gltf.asset.renderableEntities, isNotEmpty);
        expect(gltf.asset.renderableEntityCount, gltf.asset.renderableEntities.length);
        final box = gltf.asset.getBoundingBox();
        expect(box.max.x, greaterThan(box.min.x));
        for (final e in gltf.asset.renderableEntities) {
          expect(rig.scene.hasEntity(e), isTrue);
        }
        expect(gltf.asset.lightEntities.length, gltf.asset.lightEntityCount);

        final pixels = rig.screenshot('gltfio Smoke Tests gltfio: Draco+WebP helicopter GLB renders with ubershader materials');
        final stats = frameStats(pixels);
        final fg = countForegroundPixels(pixels, rig.width);
        print('helicopter renderables=${gltf.asset.renderableEntityCount} $stats foreground=$fg');
        expect(fg, greaterThan(rig.width * rig.height ~/ 40), reason: 'mesh must cover >2.5% of the frame');
        expect(fg, lessThan(rig.width * rig.height * 95 ~/ 100), reason: 'background must remain visible');
        expect(stats.distinct, greaterThan(200), reason: 'shaded PBR mesh expected');
      } finally {
        gltf.dispose(rig.scene);
      }
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('gltfio: skinned mannequin walk animation plays (video)', () {
      final gltf = loadGltfIntoScene(rig, 'mannequin/MF_Unarmed_Walk_Fwd.glb');
      try {
        final animator = gltf.asset.animator;
        expect(animator.animationCount, 1, reason: 'fixture carries one clip');
        final duration = animator.getAnimationDuration(0);
        expect(duration, greaterThan(0));
        expect(animator.getAnimationName(0), contains('Walk'));
        print('mannequin clip=${animator.getAnimationName(0)} duration=${duration.toStringAsFixed(2)}s');

        // The clip plays in real time, looping, for the whole 10 s video.
        final last = rig.video(
          'gltfio Smoke Tests gltfio: skinned mannequin walk animation plays (video)',
          onFrame: (frame, t) {
            animator.applyAnimation(0, (frame / smokeVideoFps) % duration);
            animator.updateBoneMatrices();
          },
        );
        expect(countForegroundPixels(last, rig.width), greaterThan(rig.width * rig.height ~/ 60));
        expect(frameStats(last).distinct, greaterThan(200));

        // Two distinct poses must produce different frames.
        animator.applyAnimation(0, 0.0);
        animator.updateBoneMatrices();
        final a = rig.renderFrame(warmup: 1);
        animator.applyAnimation(0, duration * 0.5);
        animator.updateBoneMatrices();
        final b = rig.renderFrame(warmup: 1);
        final changed = countChangedPixels(a, b);
        print('mannequin pose delta pixels=$changed');
        expect(changed, greaterThan(50), reason: 'animation must move geometry');
      } finally {
        gltf.dispose(rig.scene);
      }
    }, timeout: const Timeout(Duration(minutes: 3)));

  // Filament's SSR pass turned a skinned renderable's special SSR
  // variant into a depth/picking one (SKN is outside SPECIAL_SSR_MASK). GL
  // tolerated it; Vulkan lost the device on the first frame
  // (`vkGetQueryPoolResults error=-4`), so any skinned character killed an
  // editor viewport running at its default quality. Vulkan on purpose.
  test('gltfio: a skinned mannequin with screen-space reflections renders on Vulkan', () {
    final vk = SmokeRig.create(width: smokeVideoWidth, height: smokeVideoHeight, backend: FilamentBackend.vulkan);
    vk.addSun();
    final vkIbl = vk.addIbl();
    vk.view.screenSpaceReflectionsOptions = const ScreenSpaceReflectionsOptions(enabled: true);
    final gltf = loadGltfIntoScene(vk, 'mannequin/MM_Idle.glb');
    try {
      final animator = gltf.asset.animator;
      expect(animator.animationCount, 1);
      final idle = animator.getAnimationDuration(0);
      expect(idle, greaterThan(0));
      // The idle clip plays in real time, looping, for the whole 10 s video.
      final last = vk.video(
        'gltfio Smoke Tests gltfio: a skinned mannequin with screen-space reflections renders on Vulkan',
        onFrame: (frame, t) {
          animator.applyAnimation(0, (frame / smokeVideoFps) % idle);
          animator.updateBoneMatrices();
        },
      );
      expect(countForegroundPixels(last, vk.width), greaterThan(vk.width * vk.height ~/ 60),
          reason: 'the skinned mannequin must still be drawn with SSR on');
    } finally {
      gltf.dispose(vk.scene);
      vk.scene.setIndirectLight(null);
      vkIbl.dispose();
      // A view that ran SSR holds history textures; left for the engine's own
      // shutdown to clean up, Filament destroys them after its texture cache
      // and segfaults. Destroy it first.
      vk.view.dispose();
      vk.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
  });
}

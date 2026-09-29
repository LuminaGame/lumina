import 'dart:io';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

/// The animation libraries' mannequin has other bone lengths than
/// SKM_Superhero_Female; merged verbatim its clips would move the character's
/// joints to the mannequin's offsets. With the shipped bundle loaded through
/// gltfio, the head joint's height above the mesh origin during the idle
/// breaks must stay within ±3 % of Idle_Loop's. `LUMINA_BUNDLE=<path>`
/// samples another bundle.
void main() {
  test('the head stays at the idle height through the idle breaks', () async {
    final engine = FilamentEngine.create();
    if (engine == null) {
      markTestSkipped('no Filament engine (native assets absent)');
      return;
    }
    final bundle = Platform.environment['LUMINA_BUNDLE'] ?? LuminaThirdPersonContent.bundledMeshPath;
    expect(File(bundle).existsSync(), isTrue, reason: bundle);
    final tempDir = Directory.systemTemp.createTempSync('lumina_bug40_');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    final meshPath = '${tempDir.path}/SKM_Superhero_Female.entity.glb';
    File(meshPath).writeAsBytesSync(await GlbParserService.convertGlbTgaToPngAsync(File(bundle).readAsBytesSync()));

    final scene = engine.createScene();
    final world = LuminaWorld(worldType: LuminaWorldType.game);
    world.initializeNativeContext(engine, scene);
    final mesh = LuminaAnimatedMeshComponent(meshAssetPath: meshPath);
    final actor = LuminaActor(root: mesh);
    world.persistentLevel.registerActor(actor);
    world.beginPlay();
    await mesh.loaded;
    expect(mesh.clipNames, containsAll(['Idle_Loop', ...LuminaThirdPersonClips.idleBreaks]));

    final transforms = FilamentTransformManager(engine);
    final asset = mesh.assetInstance!.getAsset();
    final head = asset.getFirstEntityByName('Head');
    final pelvis = asset.getFirstEntityByName('pelvis');
    expect(head, isNot(0));
    expect(pelvis, isNot(0));
    double heightOf(int entity) {
      final m = Matrix4.fromList(transforms.getWorldTransform(entity));
      return m.getTranslation().y - mesh.worldLocation.y;
    }

    /// Plays [clip] from its start and samples the head and pelvis heights
    /// every [step] s over [seconds].
    List<(double head, double pelvis)> sample(String clip, {double seconds = 1.5, double step = 0.25}) {
      mesh.play(clip);
      final out = <(double, double)>[];
      for (var t = 0.0; t < seconds; t += 1 / 60) {
        world.tick(1 / 60);
        if ((t / step) - (t / step).floorToDouble() < 1 / 60 / step) out.add((heightOf(head), heightOf(pelvis)));
      }
      return out;
    }

    final idle = sample('Idle_Loop');
    final idleHead = idle.map((s) => s.$1).reduce((a, b) => a + b) / idle.length;
    expect(idleHead, greaterThan(0.0));
    for (final clip in LuminaThirdPersonClips.idleBreaks) {
      final samples = sample(clip, seconds: 2.5);
      for (final (i, s) in samples.indexed) {
        expect(s.$1, closeTo(idleHead, idleHead * 0.03),
            reason: '$clip sample $i: head at ${s.$1.toStringAsFixed(3)} vs idle ${idleHead.toStringAsFixed(3)} '
                '(${((s.$1 / idleHead - 1) * 100).toStringAsFixed(1)} %)');
      }
    }

    world.cleanup();
    scene.dispose();
    engine.dispose();
  }, timeout: const Timeout(Duration(minutes: 3)));
}

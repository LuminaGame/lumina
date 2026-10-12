import 'dart:io';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

Directory get _assets => Directory(Platform.environment['LUMINA_TEST_ASSETS'] ?? '${Directory.current.parent.path}/test-assets');

/// A Skeletal Mesh component in "Use Animation Asset" mode loops its Anim
/// to Play: the clip an animation `.lmas` names (`clip_name`) on the mesh.
/// The Blueprint editor preview, the VM (Play-In-Editor) and generated
/// games all build components through [LuminaBlueprintComponents.construct].
void main() {
  final source = File('${_assets.path}/mannequin/MM_Idle.glb');
  late Directory project;
  late String clip;
  const mesh = 'contents/meshes/skeletal/SKM_Mannequin.lmas';
  const anim = 'contents/animations/SKM_Mannequin/Idle_Breath.lmas';

  late FilamentEngine engine;
  late FilamentScene scene;
  late LuminaWorld world;

  setUpAll(() {
    if (!source.existsSync()) return;
    project = Directory.systemTemp.createTempSync('lumina_anim_asset_');
    final glb = source.readAsBytesSync();
    clip = GlbAnimationMerger.animationNames(glb).first;
    File('${project.path}/contents/meshes/skeletal/SKM_Mannequin.entity.glb')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(glb);
    File('${project.path}/$mesh').writeAsBytesSync(
        LuminaAsset(assetId: 'mesh', name: 'SKM_Mannequin', type: AssetType.filameshSk, rawPayload: glb).toProtoBufferBytes());
    File('${project.path}/$anim')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(LuminaAsset(
        assetId: 'idle',
        name: 'Idle_Breath',
        type: AssetType.animation,
        references: [AssetReference(slotName: 'skeletal_mesh', assetId: 'mesh', assetPath: mesh)],
        metadata: {'source_mesh': mesh, 'clip_name': clip, 'clip_index': '0'},
      ).toProtoBufferBytes());
  });

  tearDownAll(() {
    if (!source.existsSync()) return;
    try {
      project.deleteSync(recursive: true);
    } catch (_) {}
  });

  setUp(() {
    engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
    scene = engine.createScene();
    world = LuminaWorld(worldType: LuminaWorldType.game);
    world.initializeNativeContext(engine, scene);
  });

  tearDown(() {
    world.cleanup();
    scene.dispose();
    engine.dispose();
  });

  Future<LuminaAnimatedMeshComponent> build(String mode, String animToPlay) async {
    final actor = LuminaActor();
    final built = LuminaBlueprintComponents.construct(
      actor,
      [
        LuminaBlueprintComponent(id: 'mesh', name: 'Mesh', type: 'LuminaSkeletalMeshComponent', properties: {
          'skeletalMeshAsset': mesh,
          'animMode': mode,
          'animToPlay': animToPlay,
        }),
      ],
      resolveAsset: (stored) => '${project.path}/${luminaBlueprintMeshPath(stored)}',
      assetProvider: (path) => File(path.startsWith('contents/') ? '${project.path}/$path' : path).readAsBytes(),
    );
    final component = built['mesh']! as LuminaAnimatedMeshComponent;
    world.persistentLevel.registerActor(actor);
    world.beginPlay();
    await component.loaded;
    for (var i = 0; i < 100 && component.currentClip == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    return component;
  }

  test('Use Animation Asset loops the clip its Anim to Play names on the mesh', () async {
    if (!source.existsSync()) return markTestSkipped('test-assets/mannequin/MM_Idle.glb is missing');
    final component = await build('Use Animation Asset', anim);
    expect(component.currentClip, clip);
    final duration = component.clipDuration(clip);
    world.tick(0.25);
    expect(component.currentTime, closeTo(0.25, 1e-6));
    for (var i = 0; i < 4; i++) {
      world.tick(duration / 3);
    }
    expect(component.currentClip, clip, reason: 'it loops');
    expect(component.currentTime, lessThan(duration));
  });

  test('the Anim to Play is ignored unless the mode is Use Animation Asset', () async {
    if (!source.existsSync()) return markTestSkipped('test-assets/mannequin/MM_Idle.glb is missing');
    final component = await build('Disabled', anim);
    expect(component.currentClip, isNull);
  });
}

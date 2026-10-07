import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/anim_notify_and_curves.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/animation_editor_view_model.dart';
import 'animation_editor_view_model_test.dart';

void main() {
  late Directory tempDir;
  late String lmasPath;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('anim_advanced_test_');
    lmasPath = '${tempDir.path}/A_Hero_Anim.lmas';

    final glbBytes = buildTestGlbWithTwoClips();
    final asset = LuminaAsset(
      assetId: 'hero-anim-advanced-uuid',
      name: 'A_Hero_Anim',
      type: AssetType.animation,
      rawPayload: glbBytes,
      metadata: {},
    );

    final lmasBytes = asset.toProtoBufferBytes();
    File(lmasPath).writeAsBytesSync(lmasBytes);
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('Notify dispatch fires in time order on crossing, and seek fires nothing', () async {
    final vm = AnimationEditorViewModel(assetPath: lmasPath);
    await vm.load();

    vm.addNotify('Footstep_L', 0.30, type: AnimNotifyType.footstep);
    vm.addNotify('Footstep_R', 0.35, type: AnimNotifyType.footstep);

    // Initial position is 0.0
    vm.seek(0.28);
    expect(vm.recentlyFiredNotifies, isEmpty);

    // Tick 0.1s -> 0.28 to 0.38
    vm.play();
    vm.tickDelta(0.10);
    expect(vm.recentlyFiredNotifies.length, equals(2));
    expect(vm.recentlyFiredNotifies[0].name, equals('Footstep_L'));
    expect(vm.recentlyFiredNotifies[1].name, equals('Footstep_R'));

    // Seeking over notifies does NOT fire them
    vm.seek(0.20);
    expect(vm.recentlyFiredNotifies, isEmpty);
    vm.seek(0.50);
    expect(vm.recentlyFiredNotifies, isEmpty);
  });

  test('Loop wrap dispatch fires notify on post-wrap sub-interval exactly once', () async {
    final vm = AnimationEditorViewModel(assetPath: lmasPath);
    await vm.load();

    // Clip 0 duration is 2.0s
    vm.setLooping(true);
    vm.addNotify('SpawnFX', 0.05, type: AnimNotifyType.spawnParticle);

    // Tick from 1.95 with dt 0.08 -> wraps to 0.03
    vm.seek(1.95);
    vm.play();
    vm.tickDelta(0.08); // 1.95 -> 0.03 (does not reach 0.05)
    expect(vm.positionSeconds, closeTo(0.03, 1e-4));
    expect(vm.recentlyFiredNotifies, isEmpty);

    // Next tick from 0.03 with dt 0.05 -> advances to 0.08 (crosses 0.05)
    vm.tickDelta(0.05);
    expect(vm.positionSeconds, closeTo(0.08, 1e-4));
    expect(vm.recentlyFiredNotifies.length, equals(1));
    expect(vm.recentlyFiredNotifies[0].name, equals('SpawnFX'));
  });

  test('Notify CRUD persists and round-trips to .lmas', () async {
    final vm = AnimationEditorViewModel(assetPath: lmasPath);
    await vm.load();

    vm.addNotify('FootstepNotify', 0.5, type: AnimNotifyType.footstep);
    expect(vm.notifies.length, equals(1));
    final notifyId = vm.notifies.first.id;

    vm.moveNotify(notifyId, 0.6);
    expect(vm.notifies.first.time, equals(0.6));

    await vm.save();

    final vm2 = AnimationEditorViewModel(assetPath: lmasPath);
    await vm2.load();

    expect(vm2.notifies.length, equals(1));
    expect(vm2.notifies.first.name, equals('FootstepNotify'));
    expect(vm2.notifies.first.time, equals(0.6));
    expect(vm2.notifies.first.type, equals(AnimNotifyType.footstep));

    // Delete and re-save
    vm2.removeNotify(vm2.notifies.first.id);
    expect(vm2.notifies, isEmpty);
    await vm2.save();

    final vm3 = AnimationEditorViewModel(assetPath: lmasPath);
    await vm3.load();
    expect(vm3.notifies, isEmpty);
  });

  test('Curve evaluate with linear interpolation and clamped ends', () async {
    final curve = AnimCurveData(
      name: 'JumpIntensity',
      keys: [
        AnimCurveKey(time: 0.0, value: 0.0),
        AnimCurveKey(time: 0.2, value: 1.0),
        AnimCurveKey(time: 1.0, value: 0.0),
      ],
    );

    expect(curve.evaluate(0.1), closeTo(0.5, 1e-6));
    expect(curve.evaluate(0.6), closeTo(0.5, 1e-6));
    expect(curve.evaluate(1.5), closeTo(0.0, 1e-6));
    expect(curve.evaluate(-0.5), closeTo(0.0, 1e-6));
  });

  test('BlendSpace 1D bracketing-pair weighting', () {
    final bs = BlendSpaceData(
      is2D: false,
      xAxis: BlendSpaceAxis(name: 'Speed', min: 0.0, max: 600.0),
      samples: [
        EditorBlendSample(id: 'idle', assetPath: 'contents/animations/A_Idle.lmas', assetName: 'A_Idle', x: 0.0),
        EditorBlendSample(id: 'walk', assetPath: 'contents/animations/A_Walk.lmas', assetName: 'A_Walk', x: 2.0),
        EditorBlendSample(id: 'run', assetPath: 'contents/animations/A_Run.lmas', assetName: 'A_Run', x: 6.0),
      ],
    );

    // parameter 1.0 is halfway between 0 and 2
    final w1 = bs.computeWeights(1.0, 0.0);
    expect(w1['idle'], closeTo(0.5, 1e-6));
    expect(w1['walk'], closeTo(0.5, 1e-6));
    expect(w1['run'], closeTo(0.0, 1e-6));

    // parameter 9.0 clamps to run (1.0)
    final w9 = bs.computeWeights(9.0, 0.0);
    expect(w9['idle'], closeTo(0.0, 1e-6));
    expect(w9['walk'], closeTo(0.0, 1e-6));
    expect(w9['run'], closeTo(1.0, 1e-6));
  });

  test('BlendSpace 2D 4-corner normalized weighting and sum to 1.0', () {
    final bs = BlendSpaceData(
      is2D: true,
      xAxis: BlendSpaceAxis(name: 'Direction', min: -1.0, max: 1.0),
      yAxis: BlendSpaceAxis(name: 'Speed', min: -1.0, max: 1.0),
      samples: [
        EditorBlendSample(id: 'c_bl', assetPath: 'a.lmas', assetName: 'BL', x: -1.0, y: -1.0),
        EditorBlendSample(id: 'c_br', assetPath: 'b.lmas', assetName: 'BR', x: 1.0, y: -1.0),
        EditorBlendSample(id: 'c_tl', assetPath: 'c.lmas', assetName: 'TL', x: -1.0, y: 1.0),
        EditorBlendSample(id: 'c_tr', assetPath: 'd.lmas', assetName: 'TR', x: 1.0, y: 1.0),
      ],
    );

    // Center (0,0) -> 0.25 on each corner
    final centerWeights = bs.computeWeights(0.0, 0.0);
    expect(centerWeights['c_bl'], closeTo(0.25, 1e-4));
    expect(centerWeights['c_br'], closeTo(0.25, 1e-4));
    expect(centerWeights['c_tl'], closeTo(0.25, 1e-4));
    expect(centerWeights['c_tr'], closeTo(0.25, 1e-4));

    // Exact corner (1,1) -> 1.0 on c_tr
    final cornerWeights = bs.computeWeights(1.0, 1.0);
    expect(cornerWeights['c_tr'], closeTo(1.0, 1e-6));
    expect(cornerWeights['c_bl'], closeTo(0.0, 1e-6));

    // 5x5 sweep check that sum of weights is always 1.0
    for (double x = -1.0; x <= 1.0; x += 0.5) {
      for (double y = -1.0; y <= 1.0; y += 0.5) {
        final w = bs.computeWeights(x, y);
        final sum = w.values.fold(0.0, (prev, elem) => prev + elem);
        expect(sum, closeTo(1.0, 1e-6));
      }
    }
  });

  test('BlendSpace and Curves round-trip persistence and AssetReferences', () async {
    final vm = AnimationEditorViewModel(assetPath: lmasPath);
    await vm.load();

    // 1. Add Curve
    vm.addCurve('AimPitch');
    vm.addCurveKey('AimPitch', 0.0, -90.0);
    vm.addCurveKey('AimPitch', 1.0, 90.0);

    // 2. Configure BlendSpace
    vm.setBlendSpace2D(true);
    vm.addBlendSample('contents/animations/A_Idle.lmas', 'A_Idle', 0.0, 0.0);
    vm.addBlendSample('contents/animations/A_Walk.lmas', 'A_Walk', 0.0, 300.0);

    // 3. Save
    await vm.save();

    // 4. Reopen and verify
    final vm2 = AnimationEditorViewModel(assetPath: lmasPath);
    await vm2.load();

    expect(vm2.curves.length, equals(1));
    expect(vm2.curves.first.name, equals('AimPitch'));
    expect(vm2.curves.first.keys.length, equals(2));
    expect(vm2.evaluateCurve('AimPitch'), closeTo(-90.0, 1e-4));

    expect(vm2.blendSpace.is2D, isTrue);
    expect(vm2.blendSpace.samples.length, equals(2));
    expect(vm2.blendSpace.samples[0].assetName, equals('A_Idle'));
    expect(vm2.blendSpace.samples[1].assetName, equals('A_Walk'));

    // Check raw asset references in .lmas
    final bytes = File(lmasPath).readAsBytesSync();
    final asset = LuminaAsset.fromBytes(bytes);
    expect(asset.references.length, equals(2));
    expect(asset.references.any((r) => r.assetPath == 'contents/animations/A_Idle.lmas'), isTrue);
  });
}

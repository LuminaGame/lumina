import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/anim_notify_and_curves.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/animation_sub_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/animation_editor_view_model.dart';
import '../view_models/animation_editor_view_model_test.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

void main() {
  late Directory tempDir;
  late String lmasPath;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('anim_widget_adv_test_');
    lmasPath = '${tempDir.path}/A_Hero_Anim.lmas';

    final glbBytes = buildTestGlbWithTwoClips();
    final asset = LuminaAsset(
      assetId: 'hero-anim-widget-adv-uuid',
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

  testWidgets('AnimationSubEditor renders AnimNotifies tab, AnimCurves, BlendSpace grid, and Keyframe Details inspector', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final vm = AnimationEditorViewModel(assetPath: lmasPath);
    await tester.runAsync(() => vm.load());

    // Pre-populate one notify, one curve, and one blend sample
    vm.addNotify('Footstep_R', 0.5, type: AnimNotifyType.footstep);
    vm.addCurve('JumpHeight');
    vm.addCurveKey('JumpHeight', 0.0, 0.0);
    vm.addCurveKey('JumpHeight', 1.0, 1.5);
    vm.addBlendSample('contents/animations/A_Idle.lmas', 'A_Idle', 0.0, 0.0);

    await tester.pumpWidget(
      ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(
          child: AnimationSubEditor(
            assetName: 'A_Hero_Anim',
            assetPath: lmasPath,
            viewModel: vm,
          ),
        ),
      ),
    );
    await tester.pump();

    // 1. Root Motion Toggle in Viewport Top-Right
    expect(find.text('Enable Root Motion'), findsOneWidget);
    vm.setRootMotion(true);
    await tester.pump();
    expect(vm.enableRootMotion, isTrue);

    // 2. Notifies Tab in Left Panel
    await tester.tap(find.textContaining('Notifies (1)'));
    await tester.pump();

    expect(find.text('ANIM NOTIFIES'), findsOneWidget);
    expect(find.text('Footstep_R'), findsAtLeastNWidgets(1));
    expect(find.textContaining('0.500s'), findsAtLeastNWidgets(1));

    // 3. Key Details Tab in Right Panel (Default empty state)
    expect(find.text('No Keyframe Selected'), findsOneWidget);

    // Select a bone keyframe and assert inspector updates
    vm.selectKeyframe('bone_pelvis_0.000');
    await tester.pump();
    expect(find.text('pelvis'), findsAtLeastNWidgets(1));
    expect(find.text('Bone Keyframe'), findsOneWidget);
    expect(find.text('LOCATION / TRANSLATION'), findsOneWidget);
    expect(find.text('ROTATION (EULER DEGREES)'), findsOneWidget);

    // 4. Curves Tab in Right Panel
    await tester.tap(find.textContaining('Curves (1)'));
    await tester.pump();

    expect(find.text('ANIMATION CURVES'), findsOneWidget);
    expect(find.text('JumpHeight'), findsAtLeastNWidgets(1));
    expect(find.textContaining('Live: 0.00'), findsOneWidget);

    // 5. BlendSpace Tab in Right Panel
    await tester.tap(find.text('BlendSpace'));
    await tester.pump();

    expect(find.text('BLENDSPACE EDITOR'), findsOneWidget);
    expect(find.text('A_Idle'), findsOneWidget);
    expect(find.text('Place Sample at Crosshair'), findsOneWidget);

    // 6. Change Blend Parameter and assert weight calculation updates
    vm.setBlendParam(10.0, 20.0);
    await tester.pump();

    expect(find.textContaining('Param: X=10.0 Y=20.0'), findsOneWidget);
    expect(find.textContaining('100.0%'), findsOneWidget); // Single sample gets 100%
  });
}

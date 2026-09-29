import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/animation_sub_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/animation_editor_view_model.dart';
import '../view_models/animation_editor_view_model_test.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

void main() {
  late Directory tempDir;
  late String lmasPath;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('anim_widget_test_');
    lmasPath = '${tempDir.path}/A_Hero_Anim.lmas';

    final glbBytes = buildTestGlbWithTwoClips();
    final asset = LuminaAsset(
      assetId: 'hero-anim-widget-uuid',
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

  testWidgets('AnimationSubEditor renders transport controls, scrubber, clip selector, and keyboard shortcuts', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final vm = AnimationEditorViewModel(assetPath: lmasPath);
    await tester.runAsync(() => vm.load());

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

    // 1. Assert Header and badges
    expect(find.text('ANIMATION'), findsWidgets);
    expect(find.text('A_Hero_Anim'), findsWidgets);
    expect(find.text('2 Clips'), findsOneWidget);

    // 2. Assert Viewport Overlay HUD
    expect(find.textContaining('Frame: 0 / 60'), findsOneWidget);
    expect(find.textContaining('00:00:000 / 00:02:000'), findsWidgets);
    expect(find.textContaining('30 FPS'), findsWidgets);
    expect(find.textContaining('Clip: Idle'), findsWidgets);

    // 3. Switch to Bone Tracks Tab in Left Panel
    await tester.tap(find.text('Bone Tracks'));
    await tester.pump();

    expect(find.text('Armature'), findsWidgets);
    expect(find.text('pelvis'), findsWidgets);
    expect(find.text('spine_01'), findsWidgets);

    // 4. Test Step Forward and Step Back buttons
    final stepForwardBtn = find.byKey(const ValueKey('anim_step_forward'));
    expect(stepForwardBtn, findsOneWidget);
    await tester.tap(stepForwardBtn);
    await tester.pump();

    expect(vm.currentFrame, equals(1));
    expect(find.textContaining('Frame: 1 / 60'), findsOneWidget);

    final stepBackBtn = find.byKey(const ValueKey('anim_step_back'));
    expect(stepBackBtn, findsOneWidget);
    await tester.tap(stepBackBtn);
    await tester.pump();

    expect(vm.currentFrame, equals(0));
    expect(find.textContaining('Frame: 0 / 60'), findsOneWidget);

    // 5. Test Keyboard Shortcuts (Space for Play/Pause, ArrowRight for Step)
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(vm.isPlaying, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(vm.isPlaying, isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(vm.currentFrame, equals(1));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(vm.currentFrame, equals(0));

    // 6. Test Scrubber seek
    vm.seek(1.0); // 50% of 2.0s
    await tester.pump();
    expect(vm.currentFrame, equals(30));
    expect(find.textContaining('Frame: 30 / 60'), findsOneWidget);
    expect(find.textContaining('00:01:000'), findsWidgets);

    // 7. Test Clip Switch
    vm.selectClip(1); // Walk (1.5s -> 45 frames)
    await tester.pump();
    expect(vm.selectedClip, equals(1));
    expect(vm.currentFrame, equals(0));
    expect(find.textContaining('Frame: 0 / 45'), findsOneWidget);
    expect(find.textContaining('Clip: Walk'), findsWidgets);
  });
}

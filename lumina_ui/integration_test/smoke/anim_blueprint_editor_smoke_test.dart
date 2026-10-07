import 'dart:io';

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart' hide BoxShape;
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/anim_blueprint/anim_blueprint.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blend_space/blend_space.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../test/helpers/anim_test_project.dart';
import '../../test/helpers/scaffold_game_project.dart';

/// A launcher Third Person project, ABP_Character
/// opened in the Animation Blueprint editor with the Quinn mannequin running
/// the Blueprint in the Filament preview, the GroundSpeed / Direction
/// overrides swept with the Anim Preview Editor's sliders while the state
/// machine highlights the active state, IsFalling toggled into InAir, then
/// BS_Walk opened and its preview point dragged across the samples.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('anim blueprint editor: ABP_Character previews locomotion', (tester) async {
    final root = Directory.systemTemp.createTempSync('lumina_smoke_abp_');
    addTearDown(() => root.deleteSync(recursive: true));
    final projectDir = (await tester.runAsync(
        () => scaffoldGameProject(root, name: 'abp_third_person', widgetLibrary: 'flutter')))!;
    ensureTemplateAnimAssets(projectDir);

    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final boundaryKey = GlobalKey();
    Future<void> mount(Widget editor) async {
      await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: ShadcnApp(theme: luminaEditorTheme(), home: Scaffold(child: editor)),
      ));
    }

    Future<void> settle([int frames = 20]) async {
      for (var i = 0; i < frames; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
      }
    }

    await mount(AnimBlueprintSubEditor(
      assetName: LuminaThirdPersonContent.animBlueprintName,
      assetPath: '$projectDir/${LuminaThirdPersonContent.projectAnimBlueprintPath}',
    ));
    final vm = tester.state<AnimBlueprintSubEditorState>(find.byType(AnimBlueprintSubEditor)).viewModel;
    // Wait for Filament to hand the viewport's world over and the mannequin to load.
    for (var i = 0; i < 300 && !(vm.preview.hasNativeWorld && vm.previewState != null); i++) {
      await settle(1);
    }
    expect(vm.preview.hasNativeWorld, isTrue, reason: 'the preview renders through flutter_filament');
    await settle(60);
    expect(vm.previewState, 'Idle', reason: vm.previewError ?? '');

    final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
    await rec.hold(const Duration(milliseconds: 1200));

    // The state machine, to watch the active state.
    await tester.tap(find.byKey(const ValueKey('animgraph_open_machine')));
    await rec.hold(const Duration(milliseconds: 800));

    Offset sliderAt(String key, double value, {double min = -180, double max = 600}) {
      // The slider of the row's SliderField (the typed field sits beside it).
      final r = tester.getRect(find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(Slider)));
      final inset = 8.0;
      return Offset(r.left + inset + (value - min) / (max - min) * (r.width - 2 * inset), r.center.dy);
    }

    // GroundSpeed: pin it and sweep it up to a walk.
    await tester.tap(find.byKey(const ValueKey('override_toggle_GroundSpeed')));
    await rec.hold(const Duration(milliseconds: 400));
    await rec.drag(sliderAt('override_value_GroundSpeed', 0), sliderAt('override_value_GroundSpeed', 260), steps: 45);
    await rec.hold(const Duration(milliseconds: 1200));
    expect(vm.overrides['GroundSpeed'] as double, greaterThan(200));
    expect(vm.previewState, 'Walk');

    // Direction: sweep from strafing left through forward to strafing right.
    // The drag shows the sweep; the exact strafe angles are then typed into
    // the row's number field. shadcn's Slider moves by the drag's
    // delta (the pointer slop is lost) and this one is ~90 px for its
    // -180..600 range, ~9° a pixel: the drag alone lands tens of degrees off
    // -90 (-57° on 2026-09-27, which Fwd_Left rightly wins).
    Future<void> typeDirection(double degrees) async {
      final field = find.descendant(of: find.byKey(const ValueKey('override_value_Direction')), matching: find.byType(EditableText));
      await tester.tap(field, kind: PointerDeviceKind.mouse);
      await rec.hold(const Duration(milliseconds: 200));
      await rec.typeText(field, degrees.toStringAsFixed(0));
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await rec.hold(const Duration(milliseconds: 1000));
      expect(vm.overrides['Direction'] as double, degrees, reason: 'the typed Direction is pinned');
    }

    await tester.tap(find.byKey(const ValueKey('override_toggle_Direction')));
    await rec.hold(const Duration(milliseconds: 300));
    await rec.drag(sliderAt('override_value_Direction', 0), sliderAt('override_value_Direction', -90), steps: 30);
    await rec.hold(const Duration(milliseconds: 600));
    expect(vm.overrides['Direction'] as double, lessThan(-30.0), reason: 'dragging left turns the direction left');
    // A pure-left input (-90°) plays the Left clip.
    await typeDirection(-90);
    final left = vm.previewClip;
    await rec.drag(sliderAt('override_value_Direction', -90), sliderAt('override_value_Direction', 90), steps: 60);
    await rec.hold(const Duration(milliseconds: 600));
    expect(vm.overrides['Direction'] as double, greaterThan(30.0), reason: 'dragging right turns the direction right');
    await typeDirection(90);
    expect(left, 'Walk_Left_Loop');
    expect(vm.previewClip, 'Walk_Right_Loop');
    expect(find.descendant(of: find.byKey(const ValueKey('anim_state_Walk')), matching: find.byKey(const ValueKey('anim_state_active_marker'))),
        findsOneWidget);
    SmokeArtifacts.saveScreenshot('anim_blueprint_state_machine_walk_active',
        await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey)));

    // IsFalling: pin it true without a rise, the machine drops into the fall
    // loop (the old InAir state is split into Jump → FallLoop → Land).
    await tester.tap(find.byKey(const ValueKey('override_toggle_IsFalling')));
    await rec.hold(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('override_value_IsFalling')));
    await rec.hold(const Duration(milliseconds: 1500));
    expect(vm.previewState, 'FallLoop');
    expect(find.descendant(of: find.byKey(const ValueKey('anim_state_FallLoop')), matching: find.byKey(const ValueKey('anim_state_active_marker'))),
        findsOneWidget);
    SmokeArtifacts.saveScreenshot('anim_blueprint_state_machine_fall_loop_active',
        await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey)));

    // Land again (FallLoop → Land → Walk, still moving) and open the Walk
    // state's Blend Space player.
    await tester.tap(find.byKey(const ValueKey('override_value_IsFalling')));
    await rec.hold(const Duration(milliseconds: 1000));
    expect(vm.previewState, 'Walk');
    await tester.tap(find.byKey(const ValueKey('graph_link_state_Walk')));
    await rec.hold(const Duration(milliseconds: 1500));

    // --- BS_Walk ---------------------------------------------------------------
    await mount(BlendSpaceSubEditor(
      assetName: LuminaThirdPersonContent.walkBlendSpaceName,
      assetPath: '$projectDir/${LuminaThirdPersonContent.projectWalkBlendSpacePath}',
    ));
    final bs = tester.state<BlendSpaceSubEditorState>(find.byType(BlendSpaceSubEditor)).viewModel;
    for (var i = 0; i < 300 && !(bs.preview.hasNativeWorld && bs.previewClip != null); i++) {
      await settle(1);
    }
    await settle(30);
    await rec.hold(const Duration(milliseconds: 800));
    final grid = tester.state<BlendSpaceGridState>(find.byType(BlendSpaceGrid));
    // Below the 1D strip, clear of the sample labels on it.
    Offset at(double x) => grid.globalOf(x, 0) + const Offset(0, 40);
    await rec.drag(at(-170), at(170), steps: 90);
    await rec.hold(const Duration(milliseconds: 600));
    expect(bs.previewClip, 'Walk_Bwd_Loop');
    await rec.drag(at(170), at(92), steps: 30);
    await rec.hold(const Duration(milliseconds: 1200));
    expect(bs.previewClip, 'Walk_Right_Loop');
    SmokeArtifacts.saveScreenshot('blend_space_bs_walk_preview_right',
        await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey)));

    final video = rec.save('anim blueprint editor: ABP_Character previews locomotion',
        usedAssets: [LuminaThirdPersonContent.bundledMeshPath]);
    expect(SmokeArtifacts.videoDurationSeconds(video)!, greaterThanOrEqualTo(10.0));

    await tester.pumpWidget(const SizedBox());
    await settle(10);
  });
}

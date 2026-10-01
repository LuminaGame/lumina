import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart' hide BoxShape;
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/anim_notify_and_curves.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/anim_graph_asset_service.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/animation_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/widgets/animation_dope_sheet_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Quaternion, Vector3;

import '../helpers/temp_project.dart';

/// The dope sheet lays out its range bars and key diamonds whatever room it
/// gets: a bone whose only key sits on the clip's last frame, and a timeline
/// squeezed narrower than a bar (two editors side by side).
void main() {
  final assets = Directory(Platform.environment['LUMINA_TEST_ASSETS'] ?? '${Directory.current.parent.path}/test-assets');
  final mannyGlb = File('${assets.path}/mannequin/SKM_Manny_Simple.glb');
  const meshRel = 'contents/meshes/skeletal/SKM_Manny_Simple.lmas';

  late Directory project;
  var counter = 0;

  setUpAll(() {
    project = Directory.systemTemp.createTempSync('lumina_dope_narrow_');
    Directory('${project.path}/contents/meshes/skeletal').createSync(recursive: true);
    if (!mannyGlb.existsSync()) return;
    File('${project.path}/$meshRel').writeAsBytesSync(LuminaAsset(
      assetId: 'manny-mesh',
      name: 'SKM_Manny_Simple',
      type: AssetType.filameshSk,
      rawPayload: mannyGlb.readAsBytesSync(),
      metadata: const {'payload_format': 'glb'},
    ).toProtoBufferBytes());
  });
  tearDownAll(() => deleteTempProject(project));

  /// A 60-frame sequence whose `upperarm_r` has one key, on frame 60, plus a
  /// notify and a curve key so every kind of row is drawn.
  Future<AnimationEditorViewModel> sequenceWithLastFrameKey(WidgetTester tester) async {
    final rel = AnimGraphAssetService.createAnimationSequence(project.path,
        name: 'LastFrame_${++counter}', meshRelPath: meshRel, lengthFrames: 60, frameRate: 30);
    final vm = AnimationEditorViewModel(assetPath: '${project.path}/$rel');
    await tester.runAsync(() => vm.load());
    final q = Quaternion.axisAngle(Vector3(1, 0, 0), 0.5);
    vm.setBoneKey('upperarm_r', 60, rotation: [q.x, q.y, q.z, q.w]);
    vm.addNotify('Footstep_L', 0.5, type: AnimNotifyType.footstep);
    vm.addCurve('Weight');
    vm.addCurveKey('Weight', 1.0, 1.0);
    return vm;
  }

  /// Pumps the dope sheet [width] wide and returns the errors thrown while
  /// building it, apart from the header's overflow stripes (a cosmetic matter
  /// of a header squeezed below its natural width).
  Future<List<FlutterErrorDetails>> pumpDopeSheet(WidgetTester tester, AnimationEditorViewModel vm, double width) async {
    final errors = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) return;
      errors.add(details);
    };
    try {
      await tester.pumpWidget(
        ShadcnApp(
          theme: luminaEditorTheme(),
          home: Scaffold(
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: width, height: 400, child: AnimationDopeSheetWidget(viewModel: vm)),
            ),
          ),
        ),
      );
      await tester.pump();
    } finally {
      FlutterError.onError = previous;
    }
    return errors;
  }

  testWidgets('a bone whose only key is on the last frame draws its bar and key at the end of the track', (tester) async {
    if (!mannyGlb.existsSync()) return markTestSkipped('test-assets/mannequin/SKM_Manny_Simple.glb is missing');
    await tester.binding.setSurfaceSize(const Size(1400, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final vm = await sequenceWithLastFrameKey(tester);
    addTearDown(vm.dispose);

    final errors = await pumpDopeSheet(tester, vm, 1200);
    expect(errors.map((e) => e.exceptionAsString()), isEmpty);
    final key = find.byKey(const ValueKey('dope_bone_key_upperarm_r_60'));
    expect(key, findsOneWidget);
    // The key stays on the track (its right edge inside the dope sheet).
    expect(tester.getRect(key).right, lessThanOrEqualTo(1200));
  });

  testWidgets('a timeline narrower than a bone bar still lays out every row', (tester) async {
    if (!mannyGlb.existsSync()) return markTestSkipped('test-assets/mannequin/SKM_Manny_Simple.glb is missing');
    await tester.binding.setSurfaceSize(const Size(1400, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final vm = await sequenceWithLastFrameKey(tester);
    addTearDown(vm.dispose);

    // Track headers are 230 px and a divider 1 px: 233 leaves a 2 px timeline.
    for (final width in [233.0, 231.0]) {
      final errors = await pumpDopeSheet(tester, vm, width);
      expect(errors.map((e) => e.exceptionAsString()), isEmpty, reason: 'dope sheet $width px wide');
    }
  });
}

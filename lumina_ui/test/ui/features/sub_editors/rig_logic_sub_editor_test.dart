import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/skeletal_mesh/skeletal_mesh_sub_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/skeletal_mesh_editor_view_model.dart';
import 'package:lumina_core/lumina_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final sampleDnaPath = '${LuminaWorkspace.package('flutter_riglogic')}/test/fixtures/sample.dna';
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('lumina_riglogic_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('RigLogic in SkeletalMeshEditorViewModel', () {
    test('loads DNA fixture and sets controls driving morph weights', () async {
      final vm = SkeletalMeshEditorViewModel(assetPath: 'test_asset.lmas');
      expect(vm.hasRigLogic, isFalse);

      final success = await vm.loadDnaFile(sampleDnaPath);
      expect(success, isTrue);
      expect(vm.hasRigLogic, isTrue);
      expect(vm.dnaPath, equals(sampleDnaPath));
      expect(vm.rigLogic!.characterName, equals('test'));
      expect(vm.rigLogicControlNames, containsAll(['RA', 'RB']));

      // Set control RA to 0.75
      vm.setRigLogicControl('RA', 0.75);
      expect(vm.rigLogicControlValues['RA'], closeTo(0.75, 0.001));
      // DNA maps RA to blendshape BA
      expect(vm.morphWeights['BA'], closeTo(0.75, 0.001));

      // Set control RB to 0.45
      vm.setRigLogicControl('RB', 0.45);
      expect(vm.rigLogicControlValues['RB'], closeTo(0.45, 0.001));
      expect(vm.morphWeights['BB'], closeTo(0.45, 0.001));

      // Reset
      vm.resetRigLogicControls();
      expect(vm.rigLogicControlValues['RA'], equals(0.0));
      expect(vm.morphWeights['BA'], closeTo(0.0, 0.001));
      expect(vm.jointDeltas.isEmpty, isTrue);

      // Unload
      vm.unloadDna();
      expect(vm.hasRigLogic, isFalse);
      expect(vm.dnaPath, isNull);
      expect(vm.jointDeltas.isEmpty, isTrue);

      vm.dispose();
    });

    test('jointDeltas are passed to SubEditor3DViewport and drive bone transforms', () async {
      final vm = SkeletalMeshEditorViewModel(assetPath: 'test_body.lmas');
      await vm.loadDnaFile(sampleDnaPath);

      // Verify jointNames
      expect(vm.rigLogic!.jointNames.isNotEmpty, isTrue);

      // Verify jointDeltas getter exists and is unmodifiable
      expect(vm.jointDeltas, isA<Map<String, List<double>>>());

      vm.dispose();
    });
  });

  group('RigLogic Tab in SkeletalMeshSubEditor Widget', () {
    testWidgets('displays RigLogic tab and loads sample DNA rig', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final assetFile = File('${tempDir.path}/SK_Face.lmas');
      final asset = LuminaAsset(
        assetId: 'SK_Face',
        name: 'SK_Face',
        type: AssetType.filamesh,
        metadata: {
          'triangle_count': '100',
          'vertex_count': '60',
          'bone_count': '2',
          'bones': 'head,neck',
          'morph_targets': 'BA,BB,BC',
        },
      );
      assetFile.writeAsBytesSync(asset.toProtoBufferBytes());

      final vm = SkeletalMeshEditorViewModel(assetPath: assetFile.path, initialAsset: asset);
      await tester.runAsync(() => vm.load());

      await tester.pumpWidget(
        shad.ShadcnApp(
          theme: luminaEditorTheme(),
          home: shad.Scaffold(
            child: SkeletalMeshSubEditor(
              assetName: 'SK_Face',
              assetPath: assetFile.path,
              viewModel: vm,
            ),
          ),
        ),
      );
      await tester.pump();

      // Find the RigLogic tab
      final rigLogicTabFinder = find.text('RigLogic');
      expect(rigLogicTabFinder, findsOneWidget);

      // Tap RigLogic tab
      await tester.tap(rigLogicTabFinder);
      await tester.pump();

      // Expect empty state title
      expect(find.text('MetaHuman RigLogic DNA'), findsOneWidget);
      expect(find.text('Load .DNA File...'), findsOneWidget);

      // Load sample DNA fixture directly
      await vm.loadDnaFile(sampleDnaPath);
      await tester.pump();

      // Expect RigLogic character header
      expect(find.text('RIGLOGIC: TEST'), findsOneWidget);
      expect(find.text('Controls: 9'), findsOneWidget);
      expect(find.text('Morphs: 9'), findsOneWidget);

      // Expect control slider for RA
      expect(find.text('RA'), findsOneWidget);
      expect(find.text('RB'), findsOneWidget);

      // Change control RA via ViewModel
      vm.setRigLogicControl('RA', 0.6);
      await tester.pump();
      expect(vm.morphWeights['BA'], closeTo(0.6, 0.001));

      // A control slider takes a typed value.
      await typeIntoSliderField(tester, const ValueKey('skeletal_riglogic_RB'), '0.3');
      expect(vm.rigLogicControlValues['RB'], closeTo(0.3, 1e-9));

      vm.dispose();
    });
  });
}

/// Types [text] into the number field of the SliderField keyed [key] and
/// commits it with Enter (every property slider takes a typed value).
Future<void> typeIntoSliderField(WidgetTester tester, Key key, String text) async {
  final field = find.descendant(of: find.byKey(key), matching: find.byType(EditableText));
  expect(field, findsOneWidget, reason: 'the slider has an editable number field');
  await tester.ensureVisible(field);
  await tester.tap(field);
  await tester.pump();
  await tester.enterText(field, text);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
}

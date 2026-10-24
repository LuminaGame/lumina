import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/core/theme/asset_type_style.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/services/asset_editor_category.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/garment_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/garment/garment.dart';
import 'package:lumina_ui/ui/core/property_editors/asset_ref_field.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The Garment editor's panels on a real temp project: three resizable
/// panels, the gizmo and pick buttons, landmark rows added and removed, a
/// thickness edit that marks the asset dirty and a save that clears it.
void main() {
  late Directory project;
  late String garmentPath;

  setUp(() async {
    project = await Directory.systemTemp.createTemp('garment_ui_');
    await Directory('${project.path}/contents/characters').create(recursive: true);
    await File('${project.path}/GarmentUi.lmproject').writeAsString('{"projectName":"GarmentUi"}');
    garmentPath = '${project.path}/contents/characters/G_Coat.lmas';
    await File(garmentPath).writeAsBytes(const LuminaGarmentDocument().toAsset(name: 'G_Coat').toProtoBufferBytes());
  });

  tearDown(() async {
    try {
      await project.delete(recursive: true);
    } catch (_) {}
  });

  test('the Garment asset type has its style, editor category and reference filter', () {
    expect(AssetTypeStyle.of(AssetType.garment).displayName, 'Garment');
    final info = RealAssetInfo(fileName: 'G_Coat.lmas', relativePath: 'contents/characters/G_Coat.lmas', type: AssetType.garment, bytes: 1);
    expect(subEditorCategoryFor(info), 'Garment');
    expect(AssetRefField.acceptedTypes('LuminaGarment', 'garment'), {AssetType.garment});
  });

  testWidgets('panels, toolbar, landmark rows, thickness, save', (tester) async {
    final vm = GarmentEditorViewModel(assetPath: garmentPath);
    addTearDown(vm.dispose);
    await tester.runAsync(vm.load);
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(child: GarmentSubEditor(assetName: 'G_Coat', assetPath: garmentPath, viewModel: vm, showViewport: false)),
    ));
    await tester.pumpAndSettle();
    expect(find.text('GARMENT'), findsOneWidget);
    expect(find.text('LANDMARKS'), findsOneWidget);
    expect(find.byType(ResizablePanel), findsOneWidget);
    // Three islands with a resizable gutter between each pair.
    expect(find.byKey(const ValueKey('island_gap')), findsNWidgets(2));
    for (final key in ['garment_move', 'garment_rotate', 'garment_scale', 'garment_pick_garment', 'garment_pick_body', 'garment_align', 'garment_save']) {
      expect(find.byKey(ValueKey(key)), findsOneWidget, reason: key);
    }
    expect(find.byKey(const ValueKey('garment_viewport_text')), findsOneWidget);

    // A custom landmark: a 24 px tree row with its two point rows.
    await tester.enterText(find.descendant(of: find.byKey(const ValueKey('garment_custom_name')), matching: find.byType(EditableText)), 'Hood');
    await tester.tap(find.byKey(const ValueKey('garment_add_custom')));
    await tester.pumpAndSettle();
    expect(vm.doc.landmark('Hood'), isNotNull);
    expect(vm.selectedLandmark, 'Hood');
    expect(tester.getSize(find.byKey(const ValueKey('garment_landmark_Hood'))).height, 24);
    expect(find.text('not placed'), findsNWidgets(2));

    // The pick buttons switch the hint.
    await tester.tap(find.byKey(const ValueKey('garment_pick_body')));
    await tester.pumpAndSettle();
    expect(vm.pickMode, GarmentPickMode.body);
    expect(find.text('Click on the body where "Hood" belongs.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('garment_move')));
    await tester.pumpAndSettle();
    expect(vm.pickMode, GarmentPickMode.none);

    await tester.tap(find.byKey(const ValueKey('garment_remove_Hood')));
    await tester.pumpAndSettle();
    expect(vm.doc.landmarks, isEmpty);

    expect(find.byKey(const ValueKey('garment_settle_steps')), findsOneWidget);
    vm.setSettleSteps(500);
    expect(vm.doc.settleSteps, LuminaGarmentDocument.maxSettleSteps, reason: 'clamped');
    vm.setSettleSteps(30);
    vm.setThickness(2.5);
    await tester.pumpAndSettle();
    expect(find.text('G_Coat *'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('garment_save')));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    expect(vm.isDirty, isFalse);
    expect(find.text('G_Coat'), findsOneWidget);
    final saved = LuminaGarmentDocument.fromAsset(LuminaAsset.fromBytes(File(garmentPath).readAsBytesSync()));
    expect(saved.thickness, 2.5);
    expect(saved.settleSteps, 30);
    await tester.pumpWidget(const SizedBox());
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart' hide BoxShape;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/property_editors/asset_ref_field.dart';
import 'package:lumina_ui/ui/core/theme/asset_type_style.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/services/asset_editor_category.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/cloth_settings_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/cloth_settings/cloth_settings.dart';

/// The Cloth Settings editor edits a real cloth settings `.lmas`: it reads
/// the file, changes, reverts and saves settings, and its tab lists the
/// setting groups and edits the selected one. Cloth components pick the
/// asset through an asset reference that accepts cloth settings only.
void main() {
  Future<String> writeAsset(Directory dir, LuminaClothSettingsDocument doc) async {
    final path = '${dir.path}/contents/physics/CS_Flag.lmas';
    await File(path).parent.create(recursive: true);
    await File(path).writeAsBytes(doc.toAsset(name: 'CS_Flag', assetId: 'cs_flag').toProtoBufferBytes());
    return path;
  }

  test('the view model loads, edits, reverts and saves the asset', () async {
    final dir = await Directory.systemTemp.createTemp('cloth_settings_vm_');
    addTearDown(() => dir.delete(recursive: true));
    final path = await writeAsset(dir, const LuminaClothSettingsDocument(massKg: 2));
    final vm = ClothSettingsEditorViewModel(assetPath: path);
    addTearDown(vm.dispose);
    await vm.load();
    expect(vm.doc.massKg, 2);
    expect(vm.isDirty, isFalse);
    vm.set('stiffness', 0.5);
    vm.set('selfCollision', true);
    expect(vm.isDirty, isTrue);
    vm.revert();
    expect(vm.doc.stiffness, 0.95);
    vm.set('iterations', 40);
    expect(vm.doc.iterations, 32, reason: 'clamped to its range');
    vm.set('windDrag', 3.0);
    expect(await vm.save(), isTrue);
    expect(vm.isDirty, isFalse);
    final saved = LuminaAsset.fromBytes(await File(path).readAsBytes());
    expect(saved.assetId, 'cs_flag', reason: 'the asset keeps its id');
    final doc = LuminaClothSettingsDocument.fromAsset(saved);
    expect(doc.iterations, 32);
    expect(doc.windDrag, 3.0);
    expect(doc.massKg, 2);
  });

  test('cloth settings open in their editor; components accept only them', () {
    final asset = RealAssetInfo(
      fileName: 'CS_Flag.lmas',
      relativePath: 'contents/physics/CS_Flag.lmas',
      type: AssetType.clothSettings,
      bytes: 10,
      lastModified: DateTime(2026),
      lmasPath: 'contents/physics/CS_Flag.lmas',
    );
    expect(subEditorCategoryFor(asset), 'ClothSettings');
    expect(AssetRefField.acceptedTypes('LuminaClothSettings', 'clothSettingsAsset'), {AssetType.clothSettings});
    expect(AssetTypeStyle.of(AssetType.clothSettings).displayName, 'Cloth Settings');
  });

  testWidgets('the tab lists the groups, edits the selected one and saves', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final dir = Directory.systemTemp.createTempSync('cloth_settings_tab_');
    addTearDown(() => dir.deleteSync(recursive: true));
    late String path;
    late ClothSettingsEditorViewModel vm;
    await tester.runAsync(() async {
      path = await writeAsset(dir, const LuminaClothSettingsDocument());
      vm = ClothSettingsEditorViewModel(assetPath: path);
      await vm.load();
    });
    addTearDown(vm.dispose);

    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(child: ClothSettingsSubEditor(assetName: 'CS_Flag', viewModel: vm)),
    ));
    await tester.pumpAndSettle();
    for (final section in ClothSettingsEditorViewModel.sections) {
      expect(find.byKey(ValueKey('cloth_settings_section_${section.id}')), findsOneWidget);
    }
    expect(find.text('Mass'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('cloth_settings_section_collision')));
    await tester.pumpAndSettle();
    expect(find.text('Self Collision Distance'), findsOneWidget);
    expect(find.text('Mass'), findsNothing);
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('cloth_settings_selfCollision')), matching: find.byType(Switch)));
    await tester.pumpAndSettle();
    expect(vm.doc.selfCollision, isTrue);
    expect(find.text('CS_Flag *'), findsOneWidget);

    await tester.runAsync(() async {
      await vm.save();
    });
    await tester.pumpAndSettle();
    expect(find.text('CS_Flag'), findsOneWidget);
    final saved = await tester.runAsync(() async => LuminaClothSettingsDocument.fromAsset(LuminaAsset.fromBytes(await File(path).readAsBytes())));
    expect(saved!.selfCollision, isTrue);
  });
}

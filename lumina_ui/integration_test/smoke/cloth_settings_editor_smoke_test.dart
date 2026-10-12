import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/cloth_settings/cloth_settings.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Cloth Settings smoke: boot the real editor on a temp project, create a
/// Cloth Settings asset the way Content Browser → New Asset does, open it
/// in its editor tab, edit the mass (typed), the wind drag (typed) and
/// self-collision (switch) through the editor's own widgets, save, and read
/// the `.lmas` back from disk. PNG + WebM evidence goes to SmokeArtifacts.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const title = 'Cloth Settings Smoke: create a cloth settings asset, edit mass, wind and self-collision, save';

  testWidgets(title, (tester) async {
    final tempProjectsDir = Directory.systemTemp.createTempSync('lumina_smoke_cloth_');
    final pDir = Directory('${tempProjectsDir.path}/SmokeCloth')..createSync(recursive: true);
    const project = LuminaProject(projectName: 'SmokeCloth', activeLevel: 'contents/levels/L_Main.lmas');
    File('${pDir.path}/SmokeCloth.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    try {
      final vm = EditorViewModel(initialProject: project, projectLocation: tempProjectsDir.path);
      await tester.runAsync(() => vm.ensureDefaultLevelAssets());
      // Content Browser → New Asset → Physics → Cloth Settings.
      await tester.runAsync(() => vm.createNewAsset(type: AssetType.clothSettings, subFolder: 'physics'));
      final created = vm.realAssets.firstWhere((a) => a.type == AssetType.clothSettings);
      expect(created.relativePath, startsWith('contents/physics/'));

      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)),
      ));
      await tester.pump(const Duration(milliseconds: 300));

      Future<void> settle([int frames = 20]) async {
        for (var i = 0; i < frames; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
        }
      }

      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      await rec.hold(const Duration(seconds: 1));

      vm.openSubEditorTab('ClothSettings', asset: created);
      await settle(30);
      expect(find.byType(ClothSettingsSubEditor), findsOneWidget);
      await rec.hold(const Duration(seconds: 2));

      /// Types [value] into the number field of setting [key].
      Future<void> type(String key, String value) async {
        final field = find.descendant(of: find.byKey(ValueKey('cloth_settings_$key')), matching: find.byType(EditableText));
        await tester.tap(field.first);
        await settle(3);
        await tester.enterText(field.first, value);
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await settle(5);
      }

      await type('massKg', '2.5');
      await rec.hold(const Duration(seconds: 1));
      final materialPng = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
      SmokeArtifacts.saveScreenshot('cloth_settings_editor_material', materialPng);

      await tester.tap(find.byKey(const ValueKey('cloth_settings_section_wind')));
      await settle(10);
      await type('windDrag', '3');
      await rec.hold(const Duration(seconds: 1));

      await tester.tap(find.byKey(const ValueKey('cloth_settings_section_collision')));
      await settle(10);
      await tester.tap(find.descendant(of: find.byKey(const ValueKey('cloth_settings_selfCollision')), matching: find.byType(Switch)));
      await settle(10);
      expect(find.textContaining(' *'), findsWidgets, reason: 'the tab shows unsaved changes');
      await rec.hold(const Duration(seconds: 2));
      final collisionPng = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
      SmokeArtifacts.saveScreenshot('cloth_settings_editor_self_collision', collisionPng);

      await tester.tap(find.byKey(const ValueKey('cloth_settings_save')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
      await settle(10);
      await rec.hold(const Duration(seconds: 3));
      rec.save(title);

      final saved = LuminaClothSettingsDocument.fromAsset(LuminaAsset.fromBytes(File('${pDir.path}/${created.relativePath}').readAsBytesSync()));
      debugPrint('[cloth_settings_smoke] saved ${saved.toProperties()}');
      expect(saved.massKg, 2.5);
      expect(saved.windDrag, 3.0);
      expect(saved.selfCollision, isTrue);
      vm.dispose();
    } finally {
      if (tempProjectsDir.existsSync()) tempProjectsDir.deleteSync(recursive: true);
    }
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart' show kSecondaryMouseButton;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The editor viewport ticks while mounted, so `pumpAndSettle` never settles:
/// pump a bounded run of frames on the live clock instead.
Future<void> settle(WidgetTester tester, {int frames = 20}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const scenario = 'Content Browser Smoke Scenario: Reference Viewer, Size Info and Migrate an asset';
  testWidgets(scenario, (tester) async {
    const barrelRel = 'Props/Barrels/fuel_barrel_red.glb';
    final barrelGlb = File('${SmokeArtifacts.testAssetsDir.path}/$barrelRel');
    expect(barrelGlb.existsSync(), isTrue, reason: 'test-assets must hold $barrelRel');
    final root = Directory.systemTemp.createTempSync('content_browser_refs_smoke_');
    final pDir = Directory('${root.path}/RefSmoke')..createSync(recursive: true);
    const project = LuminaProject(projectName: 'RefSmoke', activeLevel: 'contents/levels/L_Main.lmas');
    File('${pDir.path}/RefSmoke.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    final other = Directory('${root.path}/OtherSmoke')..createSync(recursive: true);
    File('${other.path}/OtherSmoke.lmproject').writeAsStringSync(jsonEncode(const LuminaProject(projectName: 'OtherSmoke').toMap()));
    EditorViewModel? vm;
    try {
      vm = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false);
      final editor = vm..migrateTargetPicker = () async => other.path;
      await tester.runAsync(() => editor.ensureDefaultLevelAssets());
      await tester.runAsync(() => editor.processImportPipeline(sourceFilePath: barrelGlb.path));
      editor.refreshAssets();
      final mesh = editor.realAssets.firstWhere((a) => a.fileName == 'fuel_barrel_red.lmas' && a.type == AssetType.filamesh);
      final dependencies = editor.dependenciesOf(mesh.assetId!);
      expect(dependencies, isNotEmpty, reason: 'the import extracted the barrel\'s material');
      await tester.runAsync(() => editor.spawnActorFromAsset(mesh, location: [0.0, 0.0, 0.0]));

      final boundary = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: boundary,
        child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: editor)),
      ));
      await settle(tester);
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundary));
      await rec.hold(const Duration(milliseconds: 1500));

      editor.selectedFolder = 'contents/meshes/static';
      await settle(tester);
      Finder tile(String fileName) => find.byWidgetPredicate((w) {
            final k = w.key;
            return k is ValueKey<String> && k.value.startsWith('asset_item_') && k.value.endsWith(fileName);
          });
      Future<void> menu(String entry) async {
        await tester.tapAt(tester.getCenter(tile('fuel_barrel_red.lmas')), buttons: kSecondaryMouseButton);
        await settle(tester);
        await rec.hold(const Duration(milliseconds: 700));
        await tester.tap(find.text(entry));
        await settle(tester);
      }

      Future<void> shot(String name) async {
        await rec.hold(const Duration(milliseconds: 1500));
        final png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundary));
        SmokeArtifacts.saveScreenshot('$scenario: $name', png, usedAssets: [barrelGlb.path]);
      }

      // Reference Viewer: the barrel depends on its extracted material.
      await menu('Reference Viewer...');
      final deps = find.byKey(const ValueKey('reference_viewer_dependencies'));
      for (final d in dependencies) {
        expect(find.descendant(of: deps, matching: find.text(d.relativePath)), findsOneWidget, reason: d.relativePath);
      }
      await shot('the Reference Viewer');
      // A click on the material browses the Content Browser to it.
      await tester.tap(find.byKey(ValueKey('reference_viewer_dependencies_${dependencies.first.relativePath}')));
      await settle(tester, frames: 30);
      expect(editor.selectedFolder, dependencies.first.relativePath.substring(0, dependencies.first.relativePath.lastIndexOf('/')));
      await rec.hold(const Duration(seconds: 1));

      // Size Info, from the mesh's own folder.
      editor.selectedFolder = 'contents/meshes/static';
      await settle(tester);
      await menu('Size Info...');
      final info = editor.sizeInfo(mesh.lmasPath!);
      expect(info['file'], File(mesh.lmasPath!).lengthSync());
      expect(info['payload']!, greaterThan(0));
      expect(info['closure']!, greaterThan(info['file']!));
      expect(find.byKey(const ValueKey('size_info_closure')), findsOneWidget);
      await shot('Size Info');
      await tester.tap(find.text('Close'));
      await settle(tester);

      // Migrate into the second project: preview, copy, then every copied
      // reference resolves there.
      await menu('Migrate...');
      await shot('the Migrate preview');
      await tester.tap(find.byKey(const ValueKey('migrate_confirm')));
      await settle(tester, frames: 30);
      expect(tester.widget<Text>(find.byKey(const ValueKey('migrate_message'))).data, contains('0 skipped'));
      await shot('Migrate complete');
      final repo = AssetRepository();
      final targetAssets = repo.scanProjectContents(other.path);
      final graph = AssetReferenceGraph()..build(targetAssets);
      final copied = targetAssets.firstWhere((a) => a.relativePath == mesh.relativePath);
      expect(copied.assetId, mesh.assetId);
      for (final ref in copied.references) {
        expect(graph.resolve(ref).broken, isFalse, reason: ref.assetPath);
      }
      await tester.tap(find.text('OK'));
      await settle(tester);
      await rec.hold(const Duration(seconds: 1));
      rec.save(scenario, usedAssets: [barrelGlb.path]);
    } finally {
      vm?.dispose();
      try {
        root.deleteSync(recursive: true);
      } catch (_) {}
    }
  });
}

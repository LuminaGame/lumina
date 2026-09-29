import 'dart:io';

import 'package:flutter/gestures.dart' show kSecondaryButton, PointerDeviceKind;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina/testing.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/import_jobs_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// File → Import Asset Folder… walks a real folder
/// (built from test-assets/Props in a temp dir), groups companions, skips
/// what the pipeline cannot take, mirrors the folder tree into the target
/// folder, applies the conflict policy and imports on the background queue.
void main() {
  final skip = ImportFolderFixture.available ? null : 'test-assets missing';

  late Directory temp;
  setUp(() => temp = Directory.systemTemp.createTempSync('lumina_ui_import_folder_'));
  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  EditorViewModel openProject(String name) {
    final dir = Directory('${temp.path}/$name')..createSync(recursive: true);
    Directory('${dir.path}/contents/levels').createSync(recursive: true);
    File('${dir.path}/$name.lmproject').writeAsStringSync('{"project_name": "$name", "active_level": "contents/levels/L_Main.lmas"}');
    return EditorViewModel(
      initialProject: LuminaProject(projectName: name),
      projectLocation: temp.path,
      enableTimers: false,
      autoInitAssets: false,
    );
  }

  ImportFolderFixture fixture() => ImportFolderFixture.build(Directory('${temp.path}/src')..createSync());

  group('scanner', () {
    test('lists every supported primary once, groups the .bin with its .gltf, skips the .psd and ignores the hidden folder', () {
      final f = fixture();
      final scan = ImportFolderScanner.scan(f.root);
      expect(scan.files.map((x) => x.relativePath).toList(), ImportFolderFixture.expectedPrimaries);

      final gltf = scan.files.singleWhere((x) => x.relativePath.endsWith('.gltf'));
      // Companions are absolute, OS-native paths (`\` on Windows); compare
      // them as project-style relative paths.
      final companions = gltf.companions.map((c) => c.substring(f.root.length + 1).replaceAll(r'\', '/')).toList();
      expect(companions, contains('Props/Gltf/lootbarrel_split.bin'));
      expect(companions.where((c) => c.startsWith('Props/Gltf/textures/')), hasLength(1), reason: 'its image travels with it');
      expect(gltf.bytes, greaterThan(File(gltf.path).lengthSync()), reason: 'the size counts the companions');
      expect(scan.files.where((x) => x.relativePath.contains('Gltf/textures/')), isEmpty, reason: 'the image does not import alone');

      final skipped = {for (final s in scan.skipped) s.relativePath: s.reason};
      expect(skipped.keys, unorderedEquals(['Props/Source/barrel_texture.psd', 'Props/orphan_buffer.bin']));
      expect(skipped['Props/Source/barrel_texture.psd'], contains('Photoshop'));
      expect(skipped['Props/orphan_buffer.bin'], contains('no .gltf'));

      expect(scan.files.any((x) => x.relativePath.contains('.hidden') || x.fileName == 'radbarrel.glb'), isFalse);
      expect(scan.ignored, 2, reason: '.hidden/ and .DS_Store');
      expect(scan.countsByKind, {ImportFormatKind.mesh: 9, ImportFormatKind.texture: 1});
      expect(scan.folders, containsAll(['Props/Barrels', 'Props/AC_units', 'Props/Banana Bunch', 'Props/Gltf', 'Props/Textures']));
      final distinct = {
        for (final x in scan.files) ...[x.path, ...x.companions],
      };
      expect(scan.totalBytes, distinct.fold<int>(0, (n, p) => n + File(p).lengthSync()));
    }, skip: skip);

    test('symbolic links are not followed unless asked', () {
      final f = fixture();
      final outside = Directory('${temp.path}/outside')..createSync();
      File('${f.root}/Props/Barrels/bent_barrel.glb').copySync('${outside.path}/linked_barrel.glb');
      Link('${f.root}/Props/Linked').createSync(outside.path);
      final plain = ImportFolderScanner.scan(f.root);
      expect(plain.files.any((x) => x.fileName == 'linked_barrel.glb'), isFalse);
      expect(plain.skipped.map((s) => s.relativePath), contains('Props/Linked'));
      final followed = ImportFolderScanner.scan(f.root, followLinks: true);
      expect(followed.files.map((x) => x.relativePath), contains('Props/Linked/linked_barrel.glb'));
    }, skip: skip);

    test('the picker and the scanner use the import pipeline table', () {
      expect(ImportFormats.isImportable('a.TGA'), isTrue);
      expect(ImportFormats.isImportable('a.bin'), isFalse);
      expect(ImportFormats.companionExtensions, containsAll(['bin', 'mtl']));
    });
  });

  group('plan', () {
    test('Mirror folder structure on: Props/Barrels/bent_barrel.glb → contents/Imported/Props/Barrels/; off: contents/Imported/', () {
      final f = fixture();
      final scan = ImportFolderScanner.scan(f.root);
      final project = Directory('${temp.path}/P')..createSync();
      final mirrored = ImportFolderPlan.build(scan, projectPath: project.path, options: const ImportFolderOptions(targetFolder: 'contents/Imported/'));
      final barrel = mirrored.imports.singleWhere((i) => i.file.relativePath == 'Props/Barrels/bent_barrel.glb');
      expect(barrel.request.targetSubFolder, 'contents/Imported/Props/Barrels');
      expect(barrel.request.autoOrganize, isFalse);
      expect(barrel.targetPath, 'contents/Imported/Props/Barrels/bent_barrel.lmas');
      expect(mirrored.imports.singleWhere((i) => i.file.fileName == 'banana_bunch_short.glb').request.targetSubFolder,
          'contents/Imported/Props/Banana Bunch');

      final flat = ImportFolderPlan.build(scan,
          projectPath: project.path, options: const ImportFolderOptions(targetFolder: 'contents/Imported', mirrorFolderStructure: false));
      expect(flat.requests.map((r) => r.targetSubFolder).toSet(), {'contents/Imported'});

      final organized = ImportFolderPlan.build(scan, projectPath: project.path, options: const ImportFolderOptions(autoOrganize: true));
      expect(organized.requests.every((r) => r.autoOrganize && r.targetSubFolder == null), isTrue);
    }, skip: skip);

    test('assets land in the mirrored folders; re-importing with skip enqueues nothing, rename imports bent_barrel_1', () async {
      final f = fixture();
      final vm = openProject('FolderGame');
      addTearDown(vm.dispose);
      const options = ImportFolderOptions(targetFolder: 'contents/Imported');
      final scan = ImportFolderScanner.scan(f.root);
      final results = await vm.importAssetFolder(scan, options);
      expect(results, hasLength(ImportFolderFixture.expectedPrimaries.length));
      expect(results.where((r) => r.stage != ImportStage.done).map((r) => '${r.request.fileName}: ${r.error}'), isEmpty);
      final project = vm.projectDirPath;
      for (final p in [
        'contents/Imported/Props/Barrels/bent_barrel.lmas',
        'contents/Imported/Props/Barrels/empty_barrel.lmas',
        'contents/Imported/Props/AC_units/aircon_small.lmas',
        'contents/Imported/Props/Access_cards/access_card_red.lmas',
        'contents/Imported/Props/Banana Bunch/banana_bunch_short.lmas',
        'contents/Imported/Props/Gltf/lootbarrel_split.lmas',
        'contents/Imported/Props/Textures/loot_barrel_bc.lmas',
      ]) {
        expect(File('$project/$p').existsSync(), isTrue, reason: p);
      }
      final gltfAsset = LuminaAsset.fromBytes(File('$project/contents/Imported/Props/Gltf/lootbarrel_split.lmas').readAsBytesSync());
      expect(gltfAsset.rawPayload!.sublist(0, 4), [0x67, 0x6C, 0x54, 0x46], reason: 'the .gltf + .bin became one GLB');
      expect(LuminaAsset.fromBytes(File('$project/contents/Imported/Props/Textures/loot_barrel_bc.lmas').readAsBytesSync()).type,
          AssetType.texture);
      expect(vm.selectedFolder, 'contents/Imported');
      expect(vm.visibleFolders, ['contents/Imported/Props']);
      vm.selectedFolder = 'contents/Imported/Props/Barrels';
      expect(vm.visibleAssets.map((a) => a.fileName), containsAll(['bent_barrel.lmas', 'dented_barrel.lmas', 'empty_barrel.lmas']));

      // Skip existing: nothing to enqueue.
      final again = ImportFolderPlan.build(scan, projectPath: project, options: options);
      expect(again.requests, isEmpty);
      expect(again.skippedExisting, hasLength(scan.files.length));
      expect(again.conflicts, scan.files.length);
      expect(await vm.importAssetFolder(scan, options), isEmpty);

      // Overwrite: everything again, same paths, the ids kept.
      final beforeId = LuminaAsset.fromBytes(File('$project/contents/Imported/Props/Barrels/bent_barrel.lmas').readAsBytesSync()).assetId;
      final overwrite = ImportFolderPlan.build(scan, projectPath: project, options: options.copyWith(conflictPolicy: ImportConflictPolicy.overwrite));
      expect(overwrite.requests, hasLength(scan.files.length));
      expect(overwrite.requests.every((r) => r.targetBaseName == null), isTrue);

      // Rename: bent_barrel_1 beside bent_barrel.
      final barrels = ImportFolderScan(
        root: scan.root,
        files: scan.files.where((x) => x.relativeDir == 'Props/Barrels').toList(),
        skipped: const [],
        ignored: 0,
        totalBytes: 0,
      );
      final renamed = await vm.importAssetFolder(barrels, options.copyWith(conflictPolicy: ImportConflictPolicy.rename));
      expect(renamed.map((r) => r.result!.relativePath), [
        'contents/Imported/Props/Barrels/bent_barrel_1.lmas',
        'contents/Imported/Props/Barrels/dented_barrel_1.lmas',
        'contents/Imported/Props/Barrels/empty_barrel_1.lmas',
      ]);
      final original = LuminaAsset.fromBytes(File('$project/contents/Imported/Props/Barrels/bent_barrel.lmas').readAsBytesSync());
      final copy = LuminaAsset.fromBytes(File('$project/contents/Imported/Props/Barrels/bent_barrel_1.lmas').readAsBytesSync());
      expect(original.assetId, beforeId);
      expect(copy.name, 'bent_barrel_1');
      expect(copy.assetId, isNot(original.assetId));
      final renamedAgain = ImportFolderPlan.build(barrels, projectPath: project, options: options.copyWith(conflictPolicy: ImportConflictPolicy.rename));
      expect(renamedAgain.requests.first.targetBaseName, 'bent_barrel_2');
    }, skip: skip);

    test('two same-named files mapped to one folder conflict with each other', () {
      final f = fixture();
      Directory('${f.root}/Other').createSync();
      File('${f.root}/Props/Barrels/bent_barrel.glb').copySync('${f.root}/Other/bent_barrel.glb');
      final scan = ImportFolderScanner.scan(f.root);
      final project = Directory('${temp.path}/P')..createSync();
      final flat = ImportFolderPlan.build(scan,
          projectPath: project.path,
          options: const ImportFolderOptions(targetFolder: 'contents/Flat', mirrorFolderStructure: false, conflictPolicy: ImportConflictPolicy.rename));
      final names = flat.requests.where((r) => r.fileName == 'bent_barrel.glb').map((r) => r.targetBaseName).toList();
      expect(names, [null, 'bent_barrel_1']);
    }, skip: skip);
  });

  group('editor', () {
    Future<void> bigWindow(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    }

    Future<void> settle(WidgetTester tester, {int frames = 12}) async {
      for (var i = 0; i < frames; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    /// The picker returns, then the scan runs in an isolate (real time).
    Future<void> waitForDialog(WidgetTester tester) async {
      final clock = Stopwatch()..start();
      while (find.byKey(const ValueKey('import_folder_dialog')).evaluate().isEmpty && clock.elapsed < const Duration(seconds: 20)) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await settle(tester, frames: 6);
      expect(find.byKey(const ValueKey('import_folder_dialog')), findsOneWidget);
    }

    Future<void> drive(WidgetTester tester, bool Function() done, {Duration limit = const Duration(seconds: 120)}) async {
      final clock = Stopwatch()..start();
      while (!done() && clock.elapsed < limit) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 15)));
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(done(), isTrue, reason: 'timed out after $limit');
    }

    String text(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(ValueKey(key))).data!;

    testWidgets('File → Import Asset Folder… opens the summary; Import shows the progress panel and the mirrored folders fill',
        (tester) async {
      await bigWindow(tester);
      final f = fixture();
      final vm = openProject('MenuGame');
      addTearDown(vm.dispose);
      var picked = 0;
      vm.importFolderPicker = () async {
        picked++;
        return f.root;
      };
      await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)));
      await tester.pump();

      await tester.tap(find.text('File'));
      await settle(tester, frames: 6);
      expect(find.text('Ctrl+Shift+I'), findsOneWidget);
      await tester.tap(find.text('Import Asset Folder...'));
      await waitForDialog(tester);
      expect(picked, 1);
      expect(text(tester, 'import_folder_headline'), startsWith('10 files to import · '));
      expect(find.text('9 meshes'), findsOneWidget);
      expect(find.text('1 texture'), findsOneWidget);
      expect(find.text('Skipped (2)'), findsOneWidget);
      expect(find.textContaining('Photoshop'), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const ValueKey('import_folder_target_field'))).controller!.text, 'contents');

      // Target contents/Imported; the example line follows it.
      await tester.enterText(find.byKey(const ValueKey('import_folder_target_field')), 'contents/Imported');
      await settle(tester, frames: 3);
      expect(text(tester, 'import_folder_example'), 'Props/AC_units/ac_unit_a_300x300.glb → contents/Imported/Props/AC_units/');
      expect(text(tester, 'import_folder_plan'), 'Imports 10 files');
      await tester.tap(find.byKey(const ValueKey('import_folder_mirror')));
      await settle(tester, frames: 3);
      expect(text(tester, 'import_folder_example'), 'Props/AC_units/ac_unit_a_300x300.glb → contents/Imported/');
      await tester.tap(find.byKey(const ValueKey('import_folder_mirror')));
      await settle(tester, frames: 3);
      // A target outside contents/ cannot import.
      await tester.enterText(find.byKey(const ValueKey('import_folder_target_field')), 'elsewhere');
      await settle(tester, frames: 3);
      expect(find.text('The target folder must be under contents/'), findsOneWidget);
      expect(tester.widget<PrimaryButton>(find.byKey(const ValueKey('import_folder_confirm'))).onPressed, isNull);
      await tester.enterText(find.byKey(const ValueKey('import_folder_target_field')), 'contents/Imported');
      await settle(tester, frames: 3);

      await tester.runAsync(() async {
        await tester.tap(find.byKey(const ValueKey('import_folder_confirm')));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('import_folder_dialog')), findsNothing, reason: 'closed at once');
      expect(find.byKey(const ValueKey('import_progress_panel')), findsOneWidget);
      expect(text(tester, 'import_progress_headline'), startsWith('Importing 1 / 10 · '));
      expect(vm.selectedFolder, 'contents/Imported');

      // The mirrored folders appear as files land. Waits on the grid, not on
      // the disk: a worker creates contents/Imported/Props/… when it
      // writes a file, but the file lands — and the editor redraws — only
      // after its index step, which queues behind the other files' UI-isolate
      // steps; under load that gap outlasted the single pump that followed.
      await drive(tester, () => find.text('Props').evaluate().isNotEmpty || !vm.isBatchImporting);
      expect(find.text('Props'), findsWidgets, reason: 'the Props folder tile is in the grid');
      expect(vm.importJobs.finished, lessThan(10), reason: 'it appears while the batch is still running');
      await drive(tester, () => !vm.isBatchImporting);
      expect(vm.importJobs.imported, 10);
      expect(text(tester, 'import_progress_headline'), 'Imported 10 of 10');
      vm.selectedFolder = 'contents/Imported/Props';
      await tester.pump();
      expect(vm.visibleFolders.map((x) => x.split('/').last),
          ['AC_units', 'Access_cards', 'Banana Bunch', 'Barrels', 'Gltf', 'Textures']);
      await tester.pump(ImportJobsViewModel.autoDismissAfter);

      // Ctrl+Shift+I opens it again; everything exists now, so Import is off.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await waitForDialog(tester);
      expect(picked, 2);
      expect(tester.widget<TextField>(find.byKey(const ValueKey('import_folder_target_field'))).controller!.text, 'contents/Imported/Props');
      await tester.enterText(find.byKey(const ValueKey('import_folder_target_field')), 'contents/Imported');
      await settle(tester, frames: 3);
      expect(text(tester, 'import_folder_plan'), 'Imports 0 files · 10 already exist: skipped');
      expect(tester.widget<PrimaryButton>(find.byKey(const ValueKey('import_folder_confirm'))).onPressed, isNull);
      // Rename: all ten again, as _1.
      await tester.tap(find.byKey(const ValueKey('import_folder_conflict_select')));
      await settle(tester, frames: 6);
      await tester.tap(find.byKey(const ValueKey('import_folder_conflict_rename')));
      await settle(tester, frames: 6);
      expect(text(tester, 'import_folder_plan'), 'Imports 10 files · 10 already exist: renamed');
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(find.byKey(const ValueKey('import_folder_dialog')), findsNothing);
    }, skip: skip != null, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    testWidgets('the folder context menu and the Import dropdown open it with that folder as the target', (tester) async {
      await bigWindow(tester);
      final f = fixture();
      final vm = openProject('ContextGame');
      addTearDown(vm.dispose);
      vm.importFolderPicker = () async => f.root;
      Directory('${vm.projectDirPath}/contents/Kits').createSync(recursive: true);
      await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)));
      await tester.pump();
      vm.selectedFolder = 'contents';
      await tester.pump();

      // Right-click the Kits folder tile → Import Folder Here...
      final kits = find.text('Kits');
      expect(kits, findsWidgets);
      await tester.tap(kits.last, buttons: kSecondaryButton, kind: PointerDeviceKind.mouse);
      await settle(tester, frames: 6);
      await tester.tap(find.text('Import Folder Here...'));
      await waitForDialog(tester);
      expect(tester.widget<TextField>(find.byKey(const ValueKey('import_folder_target_field'))).controller!.text, 'contents/Kits');
      await tester.tap(find.text('Cancel'));
      await settle(tester);

      // The toolbar's Import dropdown → Import Asset Folder...
      await tester.tap(find.text('Import'));
      await settle(tester, frames: 6);
      expect(find.byKey(const ValueKey('content_browser_import_files')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('content_browser_import_folder')));
      await waitForDialog(tester);
      expect(tester.widget<TextField>(find.byKey(const ValueKey('import_folder_target_field'))).controller!.text, 'contents');
      await tester.tap(find.text('Cancel'));
      await settle(tester);
    }, skip: skip != null, variant: TargetPlatformVariant.only(TargetPlatform.linux));
  });
}

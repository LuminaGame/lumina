import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/services/game_template_service.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/services/viewport_picker.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/import_target_skeleton_select.dart';
import 'package:lumina_ui/ui/features/main_editor/views/import_textures_folder_row.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// FBX import in the editor: Unreal FBX props arrive at
/// their real size and upright, an `AS_*.FBX` animation is retargeted onto the
/// Third Person mannequin, and the Import dialog offers the target skeleton.
File _fbx(String relative) =>
    File('${Platform.environment['LUMINA_TEST_ASSETS'] ?? '${Directory.current.parent.path}/test-assets'}/FBX/$relative');

void main() {
  group('EditorViewModel.processImportPipeline with FBX', () {
    late Directory root;
    late Directory configDir;
    const name = 'fbx_game';

    // The project is scaffolded for real by ProjectRepository (Third Person
    // template: the Quinn mannequin and its clips); only `flutter create` and
    // `pub get` are replaced by their filesystem effects.
    Future<ProcessResult> runner(String exec, List<String> args, {String? workingDirectory, bool runInShell = false}) async {
      if (args.isNotEmpty && args.first == 'create') {
        final target = args.last;
        final projectName = args[args.indexOf('--project-name') + 1];
        Directory('$target/lib').createSync(recursive: true);
        File('$target/pubspec.yaml').writeAsStringSync(
          'name: $projectName\nenvironment:\n  sdk: ^3.12.0\ndependencies:\n  flutter:\n    sdk: flutter\nflutter:\n  uses-material-design: true\n',
        );
        File('$target/lib/main.dart').writeAsStringSync('void main() {}\n');
      }
      return ProcessResult(0, 0, '', '');
    }

    setUp(() {
      root = Directory.systemTemp.createTempSync('lumina_fbx_ui_');
      configDir = Directory.systemTemp.createTempSync('lumina_fbx_ui_cfg_');
    });
    tearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
      if (configDir.existsSync()) configDir.deleteSync(recursive: true);
    });

    test('an FBX prop imports upright at its real size and an AS_ clip binds to the mannequin', () async {
      final chair = _fbx('StaticMeshes/SM_Casino_Chair.FBX');
      final clip = _fbx('Animations/AS_Poker_Dealer_Idle_01.FBX');
      if (!chair.existsSync() || !clip.existsSync()) return markTestSkipped('test-assets/FBX missing');

      final project = await ProjectRepository(configDir: configDir, processRunner: runner)
          .createProject(projectName: name, projectLocation: root.path, template: kThirdPersonTemplateId);
      final vm = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false, autoInitAssets: false);
      addTearDown(vm.dispose);
      final errors = <String>[];
      final sub = EngineLoggerService().logStream.listen((e) {
        if (e.level == 'error') errors.add(e.message);
      });
      addTearDown(sub.cancel);

      await vm.processImportPipeline(sourceFilePath: chair.path);
      vm.refreshAssets();
      final mesh = vm.realAssets.firstWhere((a) => a.fileName == 'SM_Casino_Chair.lmas');
      expect(mesh.type, AssetType.filamesh);
      expect(mesh.relativePath, 'contents/meshes/static/SM_Casino_Chair.lmas');

      await vm.spawnActorFromAsset(mesh, location: [0.0, 0.0, 0.0]);
      final box = ViewportPicker.editorSpaceBounds(vm.actors.last)!;
      final size = box.max - box.min;
      expect(size.z, closeTo(96.8, 1.5), reason: 'the chair is 96.8 cm tall along the editor\'s Z (up)');
      expect(size.x, lessThan(60));
      expect(size.y, lessThan(70));

      await vm.processImportPipeline(sourceFilePath: clip.path);
      vm.refreshAssets();
      final anim = vm.realAssets.firstWhere((a) => a.fileName == 'AS_Poker_Dealer_Idle_01.lmas');
      expect(anim.type, AssetType.animation);
      final asset = LuminaAsset.fromBytes(File(anim.lmasPath!).readAsBytesSync());
      expect(asset.metadata['source_mesh'], LuminaThirdPersonContent.projectMeshAssetPath);
      expect(asset.metadata['clip_name'], 'AS_Poker_Dealer_Idle_01');
      final meshGlb = File('${vm.projectDirPath}/${LuminaThirdPersonContent.projectMeshGlbPath}').readAsBytesSync();
      expect(GlbAnimationMerger.animationNames(meshGlb).last, 'AS_Poker_Dealer_Idle_01');
      expect(errors.where((m) => m.contains('FBX')), isEmpty, reason: 'no FBX refusal or conversion error');
    });
  });

  group('ImportTargetSkeletonSelect', () {
    test('shows only when an FBX is among the files', () {
      expect(ImportTargetSkeletonSelect.appliesTo(['/a/SM_Chair.FBX']), isTrue);
      expect(ImportTargetSkeletonSelect.appliesTo(['/a/barrel.glb', '/a/walk.fbx']), isTrue);
      expect(ImportTargetSkeletonSelect.appliesTo(['/a/barrel.glb', '/a/t.png']), isFalse);
    });

    testWidgets('offers Auto, each skeletal mesh and None', (tester) async {
      const quinn = RealAssetInfo(
        fileName: 'SKM_Superhero_Female.lmas',
        relativePath: 'contents/meshes/skeletal/SKM_Superhero_Female.lmas',
        type: AssetType.filameshSk,
        bytes: 0,
      );
      final picked = <String?>[];
      String? value;
      await tester.pumpWidget(ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(
          child: Center(
            child: StatefulBuilder(
              builder: (context, setState) => SizedBox(
                width: 360,
                child: ImportTargetSkeletonSelect(
                  skeletalMeshes: const [quinn],
                  value: value,
                  onChanged: (v) => setState(() {
                    value = v;
                    picked.add(v);
                  }),
                ),
              ),
            ),
          ),
        ),
      ));
      expect(find.text('Target Skeleton (FBX animations)'), findsOneWidget);
      expect(find.text('Auto (match bone names)'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('import_target_skeleton')));
      await tester.pumpAndSettle();
      expect(find.text('SKM_Superhero_Female'), findsOneWidget);
      expect(find.text('None (keep unbound)'), findsOneWidget);

      await tester.tap(find.text('SKM_Superhero_Female'));
      await tester.pumpAndSettle();
      expect(picked.last, 'contents/meshes/skeletal/SKM_Superhero_Female.lmas');

      await tester.tap(find.byKey(const ValueKey('import_target_skeleton')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('None (keep unbound)').last);
      await tester.pumpAndSettle();
      expect(picked.last, '');

      await tester.tap(find.byKey(const ValueKey('import_target_skeleton')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Auto (match bone names)').last);
      await tester.pumpAndSettle();
      expect(picked.last, isNull, reason: 'Auto is null: match by bone names');
    });
  });

  // The FBX's textures folder import option.
  group('ImportTexturesFolderRow', () {
    test('shows only when an FBX is among the files', () {
      expect(ImportTexturesFolderRow.appliesTo(['/a/SM_Slot_Machine.FBX']), isTrue);
      expect(ImportTexturesFolderRow.appliesTo(['/a/barrel.glb', '/a/t.png']), isFalse);
    });

    testWidgets('Browse picks a real folder, Clear goes back to next-to-the-FBX', (tester) async {
      final folder = Directory.systemTemp.createTempSync('fbx_textures_folder_');
      addTearDown(() => folder.deleteSync(recursive: true));
      String? value;
      await tester.pumpWidget(ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(
          child: Center(
            child: StatefulBuilder(
              builder: (context, setState) => SizedBox(
                width: 380,
                child: ImportTexturesFolderRow(
                  value: value,
                  picker: () async => folder.path,
                  onChanged: (v) => setState(() => value = v),
                ),
              ),
            ),
          ),
        ),
      ));
      expect(find.text('Textures Folder (FBX)'), findsOneWidget);
      expect(find.text('Next to the FBX (and its Textures/ folders)'), findsOneWidget);
      expect(find.byKey(const ValueKey('import_textures_folder_clear')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('import_textures_folder_browse')));
      await tester.pumpAndSettle();
      expect(value, folder.path);
      expect(find.text(folder.path), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('import_textures_folder_clear')));
      await tester.pumpAndSettle();
      expect(value, isNull);
      expect(find.text('Next to the FBX (and its Textures/ folders)'), findsOneWidget);
    });
  });
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/features/launcher/view_models/launcher_view_model.dart';
import 'package:lumina_ui/ui/features/launcher/views/launcher_view.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/main_editor/views/viewport_widget.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/build_pipeline_service.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/build_manager_sub_editor.dart';
import 'package:puppeteer/puppeteer.dart' as pptr;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import '../helpers/shared_editor_preferences.dart';

/// Build Manager smoke: boot the real editor on a real
/// temp project seeded with real GLB imports from test-assets plus two
/// deliberately broken `.lmas` files, open Build → Build Manager, run
/// `Regenerate Thumbnails` + `Validate Assets`, capture the UI (step badges
/// + live log + issue table) as PNG and a multi-frame WebM, and assert the
/// on-screen validation results match the seeded breakage.
/// Records a long wait as a time-lapse: a frame whenever [progress] moves
/// (a build log gaining lines), otherwise one every 0.6 s, so a quiet
/// stretch of the build is compressed rather than seconds of one still frame.
Future<void> _timeLapse(
  WidgetTester tester,
  SmokeRecorder rec, {
  required bool Function() until,
  required int Function() progress,
  required Duration budget,
}) async {
  final sw = Stopwatch()..start();
  var last = -1;
  var quiet = 0;
  while (sw.elapsed < budget && !until()) {
    await tester.pump(const Duration(milliseconds: 200));
    final now = progress();
    if (now != last || ++quiet >= 3) {
      last = now;
      quiet = 0;
      await rec.captureIfChanged();
    }
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Build Manager Smoke: Validate Assets + Regenerate Thumbnails over real imported assets', (tester) async {
    final tempProjectsDir = Directory.systemTemp.createTempSync('lumina_smoke_build_manager_');
    final usedAssets = [
      '${Directory.current.parent.path}/test-assets/Props/Barrels/fuel_barrel_red.glb',
      '${Directory.current.parent.path}/test-assets/Props/AC_units/ac_unit_a_300x300.glb',
    ];
    final vm = EditorViewModel(projectDirPath: tempProjectsDir.path, enableTimers: false, autoInitAssets: false);
    try {
      final projDir = vm.projectDirPath;
      await vm.ensureDefaultLevelAssets();
      // Real assets through the real import pipeline (mesh + auto-extracted materials/textures).
      for (final glb in usedAssets) {
        await vm.processImportPipeline(sourceFilePath: glb);
      }
      vm.refreshAssets();
      final imported = vm.realAssets.where((a) => a.type == AssetType.filamesh && a.lmasPath != null).toList();
      expect(imported, isNotEmpty, reason: 'GLB import must produce real FILAMESH .lmas files');
      final barrel = imported.first;

      // Seeded breakage: one missing target, one dangling asset_id (path valid, id unknown).
      final meshesDir = Directory('$projDir/contents/meshes')..createSync(recursive: true);
      File('${meshesDir.path}/SM_BrokenRef.lmas').writeAsBytesSync(const LuminaAsset(
        assetId: 'smoke-broken',
        name: 'SM_BrokenRef',
        type: AssetType.filamesh,
        references: [AssetReference(slotName: 'material_0', assetId: 'mat-deleted', assetPath: 'contents/materials/M_Deleted.lmas')],
      ).toProtoBufferBytes());
      File('${meshesDir.path}/SM_DanglingId.lmas').writeAsBytesSync(LuminaAsset(
        assetId: 'smoke-dangling',
        name: 'SM_DanglingId',
        type: AssetType.filamesh,
        references: [AssetReference(slotName: 'lod_source', assetId: 'id-that-does-not-exist', assetPath: barrel.relativePath)],
      ).toProtoBufferBytes());
      final seededPaths = {'contents/meshes/SM_BrokenRef.lmas', 'contents/meshes/SM_DanglingId.lmas'};

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: ShadcnApp(
            theme: luminaEditorTheme(),
            home: MainEditorView(viewModel: vm),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      await rec.hold(const Duration(seconds: 1));

      // Build → Build Manager, from the menu bar, opens the workspace tab
      // bound to the editor's view model.
      await tester.tap(find.text('Build'));
      await tester.pump(const Duration(milliseconds: 300));
      await rec.hold(const Duration(milliseconds: 800));
      await tester.tap(find.text('Build Manager...').last);
      await tester.pump(const Duration(milliseconds: 300));
      expect(vm.openTabs.any((t) => t.category == 'buildManager'), isTrue);
      expect(find.byType(BuildManagerSubEditor), findsOneWidget);
      final bm = vm.buildManagerViewModel;
      // Let the real `flutter doctor -v` probe finish so the header shows the
      // real version (a frame every half second while it runs).
      for (var i = 0; i < 100 && bm.hostTargets == null; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (i % 5 == 0) await rec.captureIfChanged();
      }
      await rec.hold(const Duration(seconds: 1));

      // Every platform is
      // listed; one is buildable only when the host, its toolchain and the
      // engine all can (Web: exactly when flutter_filament's WebAssembly
      // module is built), and the others show their reasons.
      expect(bm.buildableTargets, contains('linux'));
      expect(bm.buildableTargets.contains('web'), bm.availableTargets.contains('web') && bm.webModule != null);
      expect(bm.selectedTargets, ['linux']);
      expect(bm.reasonsFor('android'), isNotEmpty, reason: 'flutter_filament has no Android build');
      await tester.pump();
      expect(find.textContaining('no Android build of the Filament libraries'), findsWidgets);
      SmokeArtifacts.saveScreenshot(
        'build_manager_unbuildable_targets_disabled',
        await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey)),
      );

      // Only the two asset-side steps this scenario is about: untick the
      // other two, one at a time.
      await tester.tap(find.byKey(const ValueKey('build_manager_step_precompileMaterials')));
      await tester.pump();
      await rec.hold(const Duration(milliseconds: 800));
      await tester.tap(find.byKey(const ValueKey('build_manager_step_buildNavigation')));
      await tester.pump();
      expect(bm.isStepEnabled(BuildStepKind.precompileMaterials), isFalse);
      expect(bm.isStepEnabled(BuildStepKind.buildNavigation), isFalse);
      await rec.hold(const Duration(milliseconds: 1200));

      // The pipeline is recorded while it runs.
      await tester.tap(find.byKey(const ValueKey('build_manager_build_all')));
      await tester.pump();
      for (var i = 0; i < 300 && (bm.isRunning || bm.lastPipelineStatus == null); i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await rec.captureIfChanged();
      }
      await tester.pump(const Duration(milliseconds: 200));
      expect(bm.isRunning, isFalse, reason: 'pipeline must finish');
      await rec.hold(const Duration(milliseconds: 1200));

      final png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
      SmokeArtifacts.saveScreenshot('build_manager_validation_and_thumbnails', png, usedAssets: usedAssets);

      // Truthful per-step results.
      expect(bm.stepState(BuildStepKind.regenerateThumbnails).status, BuildStepStatus.ok,
          reason: bm.stepState(BuildStepKind.regenerateThumbnails).message);
      expect(bm.stepState(BuildStepKind.validateAssets).status, BuildStepStatus.failed);
      expect(bm.stepState(BuildStepKind.regenerateThumbnails).duration, isNotNull);
      expect(find.byKey(const ValueKey('build_manager_duration_validateAssets')), findsOneWidget);
      expect(find.text('FAILED'), findsOneWidget);
      // The seeded .lmas files had no thumbnails; they were really rendered and rewritten.
      for (final rel in seededPaths) {
        final asset = LuminaAsset.fromBytes(File('$projDir/$rel').readAsBytesSync());
        expect(asset.hasThumbnail, isTrue, reason: '$rel thumbnail regenerated');
        expect(asset.thumbnailPng, isNotNull);
      }

      // On-screen validation results match the seeded breakage exactly.
      final seededIssues = bm.issues.where((i) => seededPaths.contains(i.assetPath)).toList();
      expect(seededIssues.length, 2, reason: bm.issues.map((i) => i.message).join('\n'));
      expect(seededIssues.map((i) => i.kind).toSet(), {ValidationIssueKind.missingTarget, ValidationIssueKind.danglingAssetId});
      expect(bm.issues.length, seededIssues.length, reason: 'the real import pipeline leaves no broken references');
      expect(find.byKey(const ValueKey('build_manager_issue_row_0')), findsOneWidget);
      expect(find.byKey(const ValueKey('build_manager_issue_row_1')), findsOneWidget);
      expect(find.byKey(const ValueKey('build_manager_issue_row_2')), findsNothing);
      expect(find.text('material_0'), findsWidgets);
      expect(find.text('lod_source'), findsWidgets);
      expect(find.text('contents/materials/M_Deleted.lmas'), findsWidgets);
      // The live log holds the real per-asset lines; nothing fabricated.
      expect(bm.logLines.any((l) => l.message.contains('SM_BrokenRef') && l.level == 'success'), isTrue, reason: 'thumbnail log line');
      expect(bm.logLines.any((l) => l.message.contains('missing target contents/materials/M_Deleted.lmas')), isTrue);
      expect(find.textContaining('Threads'), findsNothing);
      // Every line was mirrored into the main Output Log.
      expect(vm.logs.any((l) => l.source == 'BuildManager' && l.message.contains('M_Deleted')), isTrue);

      // Reveal in Content Browser drives the real content browser state, for
      // each broken asset in turn.
      final revealed = <String>{};
      for (var row = 0; row < 2; row++) {
        await tester.tap(find.byKey(ValueKey('build_manager_reveal_$row')));
        await tester.pump();
        expect(vm.selectedFolder, 'contents/meshes');
        expect(vm.searchQuery, anyOf('SM_BrokenRef', 'SM_DanglingId'));
        revealed.add(vm.searchQuery);
        await rec.hold(const Duration(milliseconds: 1500));
      }
      expect(revealed, {'SM_BrokenRef', 'SM_DanglingId'});

      // Tick the two skipped steps back on for the next build.
      for (final step in const ['precompileMaterials', 'buildNavigation']) {
        await tester.tap(find.byKey(ValueKey('build_manager_step_$step')));
        await tester.pump();
        await rec.hold(const Duration(milliseconds: 800));
      }
      expect(bm.isStepEnabled(BuildStepKind.precompileMaterials), isTrue);
      expect(bm.isStepEnabled(BuildStepKind.buildNavigation), isTrue);
      rec.save('Build Manager Smoke: Validate Assets + Regenerate Thumbnails over real imported assets', usedAssets: usedAssets);

      expect(png.length, greaterThan(1000));
    } finally {
      vm.dispose();
      if (tempProjectsDir.existsSync()) tempProjectsDir.deleteSync(recursive: true);
    }
  });

  testWidgets('Build Manager Smoke: Cook & Package runs a real flutter build linux on a launcher-created project', (tester) async {
    final tempProjectsDir = Directory.systemTemp.createTempSync('lumina_smoke_build_cook_');
    const projectName = 'smoke_cook_game';
    EditorViewModel? vm;
    try {
      // The real launcher pipeline: flutter create + pubspec patch (lumina path dep) + contents/ + manifest.
      final repo = ProjectRepository();
      await for (final p in repo.createProjectStream(projectName: projectName, projectLocation: tempProjectsDir.path)) {
        // ignore: avoid_print
        print('[create] ${p.message}');
      }
      final project = await repo.loadProject('${tempProjectsDir.path}/$projectName/$projectName.lmproject');
      expect(project, isNotNull);
      vm = EditorViewModel(initialProject: project, projectLocation: tempProjectsDir.path, enableTimers: false, autoInitAssets: false);
      await vm.ensureDefaultLevelAssets();
      await vm.processImportPipeline(sourceFilePath: '${Directory.current.parent.path}/test-assets/Props/Barrels/empty_barrel.glb');
      vm.refreshAssets();

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: ShadcnApp(
            theme: luminaEditorTheme(),
            home: MainEditorView(viewModel: vm),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      await rec.hold(const Duration(seconds: 1));
      await tester.tap(find.text('Build'));
      await tester.pump(const Duration(milliseconds: 300));
      await rec.hold(const Duration(milliseconds: 800));
      await tester.tap(find.text('Build Manager...').last);
      await tester.pump(const Duration(milliseconds: 300));
      final bm = vm.buildManagerViewModel;
      for (var i = 0; i < 300 && bm.hostTargets == null; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (i % 5 == 0) await rec.captureIfChanged();
      }
      await rec.hold(const Duration(seconds: 1));
      if (!bm.buildableTargets.contains('linux')) {
        // ignore: avoid_print
        print('SKIP cook scenario: host cannot build linux (${bm.reasonsFor('linux')})');
        return;
      }
      expect(bm.selectedTargets, ['linux']);
      expect(bm.configuration, BuildConfiguration.shipping);
      expect(bm.cookEnabled, isTrue, reason: bm.cookDisabledReason);

      // The configuration list: Debug / Development / Shipping, Shipping kept.
      await tester.tap(find.byKey(const ValueKey('build_manager_config')));
      await tester.pump(const Duration(milliseconds: 300));
      await rec.hold(const Duration(seconds: 1));
      await tester.tap(find.text('Shipping  (--release)').last);
      await tester.pump(const Duration(milliseconds: 300));
      expect(bm.configuration, BuildConfiguration.shipping);
      await rec.hold(const Duration(milliseconds: 800));

      // The target list: every platform, Linux ticked (the project's list).
      await tester.ensureVisible(find.byKey(const ValueKey('build_manager_target_linux')));
      await tester.pump(const Duration(milliseconds: 300));
      await rec.hold(const Duration(seconds: 1));
      expect(tester.widget<Checkbox>(find.byKey(const ValueKey('build_manager_target_linux'))).state, CheckboxState.checked);
      expect(bm.cookArgumentsFor('linux'), ['build', 'linux', '--release']);
      await rec.hold(const Duration(milliseconds: 800));

      await tester.tap(find.byKey(const ValueKey('build_manager_cook')));
      await tester.pump();
      // A real flutter build of a lumina-dependent project (native assets
      // included) takes ~1 minute here. Recorded as a time-lapse: a frame
      // whenever the build log grows, else one every 0.6 s.
      await _timeLapse(tester, rec, until: () => !(bm.isRunning || bm.lastPipelineStatus == null),
          progress: () => bm.logLines.length, budget: const Duration(minutes: 8));
      await tester.pump(const Duration(milliseconds: 200));
      await rec.hold(const Duration(milliseconds: 1200));

      // Scroll back through the build log with the wheel, and down again.
      final logCenter = tester.getCenter(find.byKey(const ValueKey('build_manager_log')));
      final wheel = TestPointer(21, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(wheel.hover(logCenter));
      for (final dy in [-80.0, 80.0]) {
        for (var i = 0; i < 18; i++) {
          await tester.sendEventToBinding(wheel.scroll(Offset(0, dy)));
          await rec.hold(const Duration(milliseconds: 66));
        }
      }
      await rec.hold(const Duration(milliseconds: 600));
      final png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
      SmokeArtifacts.saveScreenshot('build_manager_cook_and_package', png,
          usedAssets: ['${Directory.current.parent.path}/test-assets/Props/Barrels/empty_barrel.glb']);
      rec.save('Build Manager Smoke: Cook & Package runs a real flutter build linux on a launcher-created project', usedAssets: ['${Directory.current.parent.path}/test-assets/Props/Barrels/empty_barrel.glb']);

      final log = bm.logLines.map((l) => '${l.timestamp} [${l.level}] ${l.message}').join('\n');
      expect(bm.isRunning, isFalse, reason: 'cook must finish within the budget\n$log');
      expect(bm.stepState(BuildStepKind.cookAndPackage).status, BuildStepStatus.ok, reason: log);
      expect(bm.lastPipelineStatus, BuildStepStatus.ok, reason: log);
      // Code-gen really ran through the editor before the spawn.
      final projDir = vm.projectDirPath;
      expect(File('$projDir/lib/main.dart').readAsStringSync(), contains('package:lumina/lumina_runtime.dart'));
      expect(File('$projDir/lib/levels/${dartFileName(vm.activeLevelName)}').existsSync(), isTrue);
      // The real flutter output streamed into the console, and the artifact is a real executable.
      expect(bm.logLines.any((l) => l.message.contains('flutter build linux --release')), isTrue, reason: log);
      expect(bm.logLines.any((l) => l.message.contains('Built build/linux/x64/release/bundle')), isTrue, reason: log);
      expect(File('$projDir/build/linux/x64/release/bundle/$projectName').existsSync(), isTrue, reason: 'built executable exists');
      final package = bm.targetState('linux').packageDir;
      expect(package, '$projDir/build/package/linux', reason: 'each target gets its own package folder');
      expect(File('$package/$projectName').existsSync(), isTrue, reason: 'the bundle was copied into the package folder');
      expect(find.text('OK'), findsWidgets);
      expect(find.textContaining('build/linux/x64/release/bundle'), findsWidgets);
      expect(find.textContaining('build/package/linux'), findsWidgets);
      expect(vm.logs.any((l) => l.source == 'BuildManager' && l.message.contains('Built build/linux')), isTrue, reason: 'Output Log mirrors the build');
    } finally {
      vm?.dispose();
      if (tempProjectsDir.existsSync()) tempProjectsDir.deleteSync(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 12)));

  testWidgets('Build Manager Smoke: a launcher-created Third Person game cooks for the web and plays in Chrome', (tester) async {
    const name = 'build manager: third person web build in Chrome';
    const fasterWalk = 612.5;
    final chrome = const ['/usr/bin/google-chrome', '/usr/bin/chromium', '/snap/bin/chromium'].where((p) => File(p).existsSync()).firstOrNull;
    if (FlutterFilamentWebModule.locate() == null || chrome == null) {
      // ignore: avoid_print
      print('SKIP web cook scenario: needs flutter_filament/web/flutter_filament.wasm and Chrome');
      return;
    }
    final tempProjectsDir = Directory.systemTemp.createTempSync('lumina_smoke_build_web_');
    final tempConfigDir = Directory.systemTemp.createTempSync('lumina_smoke_build_web_cfg_');
    pptr.Browser? browser;
    try {
      // 1. Launcher → New Project → Third Person → Create: real flutter create, pub get and template content.
      final boundaryKey = GlobalKey();
      useSharedEditor(tempConfigDir);
      final launcher = LauncherViewModel(configDir: tempConfigDir);
      await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: ShadcnApp(theme: luminaEditorTheme(), home: LauncherView(viewModel: launcher)),
      ));
      await _settle(tester);
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      await rec.hold(const Duration(seconds: 1));
      final newProject = find.text('New Project...').evaluate().isNotEmpty ? find.text('New Project...').last : find.text('Create New Project').last;
      await tester.tap(newProject);
      await _settle(tester);
      await rec.hold(const Duration(seconds: 1));
      final nameField = find.widgetWithText(TextField, 'my_lumina_game').first;
      await tester.tap(nameField);
      await rec.typeText(nameField, 'tp_web_game');
      await _settle(tester, frames: 6);
      await tester.enterText(find.byType(TextField).last, tempProjectsDir.path);
      await _settle(tester, frames: 6);
      await tester.tap(find.text('Third Person'));
      await _settle(tester, frames: 6);
      await rec.hold(const Duration(seconds: 1));
      await tester.tap(find.text('Create Project'));
      await _settle(tester, frames: 6);
      expect(await _pumpUntil(tester, () => find.byType(ViewportWidget).evaluate().isNotEmpty, maxSeconds: 420, rec: rec), isTrue,
          reason: 'the Third Person project did not open in Lumina Studio');
      await _settle(tester, frames: 30);
      await rec.hold(const Duration(milliseconds: 1500));
      final vm = tester.widget<ViewportWidget>(find.byType(ViewportWidget)).viewModel;
      final projDir = vm.projectDirPath;
      expect(File('$projDir/web/index.html').existsSync(), isTrue, reason: 'flutter create gave the project its web platform');

      // 2. A developer's change, the Blueprint way (the Third
      // Person character is BP_ThirdPersonCharacter, compiled into
      // lib/actors/): a faster walk on its CharacterMovement component,
      // written back to the .lmas and recompiled.
      const characterPath = 'contents/blueprints/BP_ThirdPersonCharacter.lmas';
      final characterFile = File('$projDir/$characterPath');
      final characterAsset = LuminaAsset.fromBytes(characterFile.readAsBytesSync());
      final doc = jsonDecode(utf8.decode(characterAsset.rawPayload!)) as Map<String, dynamic>;
      final movement = (doc['components'] as List).cast<Map<String, dynamic>>().firstWhere((c) => c['type'] == 'LuminaCharacterMovementComponent');
      (movement['properties'] as Map<String, dynamic>)['maxWalkSpeed'] = fasterWalk;
      characterFile.writeAsBytesSync(LuminaAsset(
        assetId: characterAsset.assetId,
        name: characterAsset.name,
        type: characterAsset.type,
        rawPayload: Uint8List.fromList(utf8.encode(jsonEncode(doc))),
        references: characterAsset.references,
        metadata: characterAsset.metadata,
      ).toProtoBufferBytes());
      final compiled = await tester.runAsync(() => DartCodeGeneratorService().compileAndWriteActor(
            projDir, 'BP_ThirdPersonCharacter', doc,
            assetPath: characterPath, inputActions: DartCodeGeneratorService.projectInputActions(projDir)));
      expect(compiled, isTrue, reason: 'the edited Blueprint compiles');
      expect(File('$projDir/lib/actors/bp_third_person_character.dart').readAsStringSync(), contains('$fasterWalk'),
          reason: 'the compiled character carries the new walk speed');

      // 3. Build → Build Manager, target Web.
      await tester.tap(find.text('Build'));
      await _settle(tester, frames: 10);
      await rec.hold(const Duration(milliseconds: 800));
      await tester.tap(find.text('Build Manager...').last);
      await _settle(tester, frames: 10);
      final bm = vm.buildManagerViewModel;
      expect(await _pumpUntil(tester, () => bm.hostTargets != null, maxSeconds: 60, rec: rec), isTrue);
      await _settle(tester, frames: 10); // the probe's result reaches the screen
      await rec.hold(const Duration(seconds: 1));
      expect(bm.buildableTargets, contains('web'), reason: '${bm.hostTargets?.targets}: ${bm.reasonsFor('web')}');
      // Web instead of Linux: tick one, untick the other.
      await tester.ensureVisible(find.byKey(const ValueKey('build_manager_target_web')));
      await tester.tap(find.byKey(const ValueKey('build_manager_target_web')));
      await _settle(tester, frames: 10);
      await rec.hold(const Duration(seconds: 1));
      await tester.tap(find.byKey(const ValueKey('build_manager_target_linux')));
      await _settle(tester, frames: 10);
      expect(bm.selectedTargets, ['web']);
      expect(vm.project.packaging.targets, ['web'], reason: 'the Build Manager edits the project\'s own list');
      // CanvasKit from the build itself, so the headless browser needs no network.
      final bundle = find.byKey(const ValueKey('build_manager_web_bundle_resources'));
      await tester.ensureVisible(bundle);
      await _settle(tester, frames: 6);
      await tester.tap(bundle);
      await _settle(tester, frames: 6);
      expect(bm.bundleWebResources, isTrue);
      await rec.hold(const Duration(seconds: 1));
      expect(bm.cookArgumentsFor('web'), ['build', 'web', '--release', '--no-web-resources-cdn']);
      // Launch in Browser opens the served build in headless Chrome, not the desktop's browser.
      final opened = Completer<Uri>();
      bm.openUrl = (url) async => opened.complete(url);

      // 4. Cook & Package: the real flutter build web, recorded as a
      // time-lapse (a frame every fifth poll: the build takes minutes).
      await tester.tap(find.byKey(const ValueKey('build_manager_cook')));
      await tester.pump();
      await _timeLapse(tester, rec, until: () => !(bm.isRunning || bm.lastPipelineStatus == null),
          progress: () => bm.logLines.length, budget: const Duration(minutes: 10));
      await _settle(tester, frames: 6);
      await rec.hold(const Duration(milliseconds: 1500));
      final log = bm.logLines.map((l) => '${l.timestamp} [${l.level}] [${l.source}] ${l.message}').join('\n');
      expect(bm.lastPipelineStatus, BuildStepStatus.ok, reason: log);
      expect(bm.webPackageDir, '$projDir/build/package/web');
      expect(File('$projDir/build/web/main.dart.js').existsSync(), isTrue, reason: 'dart2js output');
      expect(File('$projDir/build/web/flutter_filament.wasm').existsSync(), isTrue, reason: 'module staged next to index.html');
      expect(File('$projDir/build/package/web/flutter_filament.wasm').existsSync(), isTrue, reason: 'the package carries the module');
      expect(find.byKey(const ValueKey('build_manager_artifact_size_web')), findsOneWidget);

      // 5. Launch in Browser: served on localhost.
      // The Output section sits at the bottom of the scrolling right panel.
      final launch = find.byKey(const ValueKey('build_manager_launch_browser'));
      await tester.ensureVisible(launch);
      await _settle(tester, frames: 6);
      await tester.tap(launch);
      expect(await _pumpUntil(tester, () => opened.isCompleted, maxSeconds: 30), isTrue, reason: 'Launch in Browser opened nothing');
      final url = await opened.future;
      await _settle(tester, frames: 6);
      await rec.hold(const Duration(seconds: 1));
      expect(find.text(url.toString()), findsOneWidget);

      // 6. The page in Chrome: wait until the game draws its level (sky above,
      // ground below), then capture it.
      final pageShot = await tester.runAsync(() async {
        browser = await pptr.puppeteer.launch(
          executablePath: chrome,
          headless: true,
          args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--no-sandbox'],
        );
        final page = await browser!.newPage();
        final errors = <String>[];
        final external = <String>[];
        page.onRequest.listen((r) {
          if (r.url.startsWith('http') && !r.url.startsWith(url.toString())) external.add(r.url);
        });
        page.onError.listen((e) => errors.add('pageerror: ${e.message}'));
        page.onConsole.listen((m) {
          if (m.type == pptr.ConsoleMessageType.error) errors.add('console: ${m.text}');
        });
        await page.setViewport(pptr.DeviceViewport(width: 960, height: 540));
        await page.goto(url.toString(), wait: pptr.Until.load);
        bool levelDrawn(Uint8List png) {
          final shot = img.decodePng(png)!;
          final sky = shot.getPixel(shot.width ~/ 2, 8);
          final ground = shot.getPixel(shot.width ~/ 2, shot.height * 3 ~/ 5);
          return (ground.r - sky.r).abs() + (ground.g - sky.g).abs() + (ground.b - sky.b).abs() > 60;
        }
        final deadline = DateTime.now().add(const Duration(minutes: 3));
        while (!levelDrawn(Uint8List.fromList(await page.screenshot()))) {
          if (DateTime.now().isAfter(deadline)) fail('the game never drew its level in Chrome:\n${errors.join('\n')}');
          await Future<void>.delayed(const Duration(seconds: 2));
        }
        // Give the mannequin time to stream in before the evidence frame.
        await Future<void>.delayed(const Duration(seconds: 5));
        final png = Uint8List.fromList(await page.screenshot());
        expect(errors, isEmpty, reason: errors.join('\n'));
        expect(external, isEmpty, reason: 'a bundled build fetches nothing off-origin: ${external.join(', ')}');
        return png;
      });
      SmokeArtifacts.saveScreenshot(name, pageShot!, usedAssets: const ['contents/meshes/skeletal/SKM_Superhero_Female.entity.glb']);
      await rec.hold(const Duration(milliseconds: 500));
      rec.save('Build Manager Smoke: a launcher-created Third Person game cooks for the web and plays in Chrome', usedAssets: const ['contents/meshes/skeletal/SKM_Superhero_Female.entity.glb']);

      final shot = img.decodePng(pageShot)!;
      final sky = shot.getPixel(shot.width ~/ 2, 8);
      final ground = shot.getPixel(shot.width ~/ 2, shot.height * 3 ~/ 5);
      expect((ground.r - sky.r).abs() + (ground.g - sky.g).abs() + (ground.b - sky.b).abs(), greaterThan(60),
          reason: 'the level renders below the sky in Chrome');
      expect(vm.logs.any((l) => l.source == 'BuildManager' && l.message.contains('Serving $projDir/build/package/web')), isTrue);
    } finally {
      await tester.runAsync(() async => browser?.close());
      if (tempProjectsDir.existsSync()) tempProjectsDir.deleteSync(recursive: true);
      if (tempConfigDir.existsSync()) tempConfigDir.deleteSync(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 20)));
}

Future<void> _settle(WidgetTester tester, {int frames = 30}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
  }
}

/// Pumps until [condition] holds. With [rec], the wait is recorded as a
/// time-lapse: a frame a second (the waits here run for minutes).
Future<bool> _pumpUntil(WidgetTester tester, bool Function() condition, {int maxSeconds = 300, SmokeRecorder? rec}) async {
  final deadline = DateTime.now().add(Duration(seconds: maxSeconds));
  final sinceFrame = Stopwatch()..start();
  while (DateTime.now().isBefore(deadline)) {
    if (condition()) return true;
    await _settle(tester, frames: 6);
    if (rec != null && sinceFrame.elapsedMilliseconds >= 1000) {
      await rec.captureIfChanged();
      sinceFrame.reset();
    }
  }
  return condition();
}

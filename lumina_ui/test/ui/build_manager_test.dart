import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/build_pipeline_service.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/build_manager_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/build_manager_sub_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

import '../helpers/flutter_build_stand_in.dart';

/// Widget + view-model
/// scenarios over a real temp project.
void main() {
  late Directory tempDir;
  late Directory projDir;
  late LuminaProject project;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('lumina_build_manager_ui_');
    // The editor's downloaded web module stays out: only what a test sets up counts.
    LuminaDataDir.override = Directory('${tempDir.path}/lumina_data');
    projDir = Directory('${tempDir.path}/bm_game')..createSync(recursive: true);
    Directory('${projDir.path}/contents/levels').createSync(recursive: true);
    Directory('${projDir.path}/contents/materials').createSync(recursive: true);
    Directory('${projDir.path}/contents/meshes').createSync(recursive: true);
    project = const LuminaProject(projectName: 'bm_game', activeLevel: 'contents/levels/L_Main.lmas');
    File('${projDir.path}/bm_game.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    File('${projDir.path}/contents/levels/L_Main.lmas').writeAsStringSync(jsonEncode({
      'assetId': 'level_L_Main',
      'name': 'L_Main',
      'type': 'level',
      'relativePath': 'contents/levels/L_Main.lmas',
      'metadata': {'actors': <Map<String, dynamic>>[]},
    }));
  });

  tearDown(() {
    LuminaDataDir.override = null;
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  void writeLmas(String rel, LuminaAsset a) {
    final f = File('${projDir.path}/$rel');
    f.parent.createSync(recursive: true);
    f.writeAsBytesSync(a.toProtoBufferBytes(), flush: true);
  }

  const linuxHost =
      HostBuildTargets(flutterAvailable: true, flutterVersion: '3.47.0', targets: ['linux', 'web'], operatingSystem: 'linux');

  Future<void> pumpEditor(WidgetTester tester, BuildManagerViewModel vm, {void Function(ValidationIssue)? onReveal}) async {
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(
        child: BuildManagerSubEditor(key: ObjectKey(vm), assetName: 'Build Manager', projectDirPath: projDir.path, viewModel: vm, onRevealIssue: onReveal),
      ),
    ));
    await tester.pump();
  }

  testWidgets('during a run exactly one step is running, finished steps show durations, no fabricated worker gauge', (tester) async {
    writeLmas('contents/materials/M_Slow.lmas',
        LuminaAsset(assetId: 'm-slow', name: 'M_Slow', type: AssetType.filamat, rawPayload: Uint8List.fromList([1])));
    final gate = Completer<void>();
    final vm = BuildManagerViewModel(
      projectDirPath: projDir.path,
      project: project,
      hostTargets: linuxHost,
      materialCompiler: (_) async {
        await gate.future;
        return const MaterialCompileOutcome.ok();
      },
    );
    addTearDown(vm.dispose);
    vm.setStepEnabled(BuildStepKind.buildNavigation, false);
    vm.setStepEnabled(BuildStepKind.regenerateThumbnails, false);
    await pumpEditor(tester, vm);

    // The doc's fabricated gauge is gone from the widget source and the tree.
    final src = File('lib/ui/features/sub_editors/views/build_manager_sub_editor.dart').readAsStringSync();
    expect(src.contains('450 / 1024'), isFalse);
    expect(src.contains('16 Threads'), isFalse);
    expect(src.contains('Cooked 1,240'), isFalse);
    expect(find.textContaining('Threads'), findsNothing);
    expect(find.textContaining('Lightmap'), findsNothing, reason: 'engine-blocked features surface nowhere');

    await tester.tap(find.byKey(const ValueKey('build_manager_build_all')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(vm.isRunning, isTrue);
    expect(find.byKey(const ValueKey('build_manager_badge_precompileMaterials')), findsOneWidget);
    final running = BuildStepKind.values.where((k) => vm.stepState(k).status == BuildStepStatus.running).toList();
    expect(running, [BuildStepKind.precompileMaterials]);
    expect(find.text('RUNNING'), findsOneWidget);
    expect(vm.stepState(BuildStepKind.validateAssets).status, BuildStepStatus.pending);
    expect(find.byKey(const ValueKey('build_manager_cancel')), findsOneWidget);

    gate.complete();
    for (var i = 0; i < 20 && vm.isRunning; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump();
    expect(vm.isRunning, isFalse);
    expect(vm.stepState(BuildStepKind.precompileMaterials).status, BuildStepStatus.ok);
    expect(vm.stepState(BuildStepKind.validateAssets).status, BuildStepStatus.ok);
    expect(vm.stepState(BuildStepKind.precompileMaterials).duration, isNotNull);
    expect(find.byKey(const ValueKey('build_manager_duration_precompileMaterials')), findsOneWidget);
    expect(find.byKey(const ValueKey('build_manager_duration_validateAssets')), findsOneWidget);
    // The materials counter came from a real progress event.
    expect(vm.stepState(BuildStepKind.precompileMaterials).progressLabel, 'Materials: 1/1 compiled, 0 failed');
    final counter = tester.widget<Text>(find.byKey(const ValueKey('build_manager_counter')));
    expect(counter.data, 'Materials: 1/1 compiled, 0 failed');
    // Every log line reached the engine log too.
    expect(EngineLoggerService().logs.any((l) => l.source == 'BuildManager' && l.message.contains('M_Slow')), isTrue);
    expect(vm.logLines.any((l) => l.message.contains('M_Slow')), isTrue);
  });

  testWidgets('validation issues render as a table with one row per issue and Reveal in Content Browser', (tester) async {
    writeLmas('contents/materials/M_Ok.lmas', const LuminaAsset(assetId: 'mat-ok', name: 'M_Ok', type: AssetType.filamat));
    writeLmas('contents/meshes/SM_Other.lmas', const LuminaAsset(assetId: 'mesh-other', name: 'SM_Other', type: AssetType.filamesh));
    writeLmas(
      'contents/meshes/SM_Crate.lmas',
      const LuminaAsset(assetId: 'mesh-crate', name: 'SM_Crate', type: AssetType.filamesh, references: [
        AssetReference(slotName: 'material_0', assetId: 'mat-ok', assetPath: 'contents/materials/M_Ok.lmas'),
        AssetReference(slotName: 'material_1', assetId: 'mat-gone', assetPath: 'contents/materials/M_Gone.lmas'),
        AssetReference(slotName: 'lod_source', assetId: 'no-such-id', assetPath: 'contents/meshes/SM_Other.lmas'),
      ]),
    );
    final revealed = <String>[];
    final vm = BuildManagerViewModel(projectDirPath: projDir.path, project: project, hostTargets: linuxHost);
    addTearDown(vm.dispose);
    for (final k in [BuildStepKind.precompileMaterials, BuildStepKind.buildNavigation, BuildStepKind.regenerateThumbnails]) {
      vm.setStepEnabled(k, false);
    }
    await pumpEditor(tester, vm, onReveal: (i) => revealed.add(i.assetPath));
    await tester.tap(find.byKey(const ValueKey('build_manager_build_all')));
    for (var i = 0; i < 40 && (vm.isRunning || vm.lastPipelineStatus == null); i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump();
    expect(vm.issues.length, 2);
    expect(vm.stepState(BuildStepKind.validateAssets).status, BuildStepStatus.failed);
    expect(find.text('FAILED'), findsOneWidget);
    expect(find.byKey(const ValueKey('build_manager_issue_row_0')), findsOneWidget);
    expect(find.byKey(const ValueKey('build_manager_issue_row_1')), findsOneWidget);
    expect(find.byKey(const ValueKey('build_manager_issue_row_2')), findsNothing);
    expect(find.text('material_1'), findsWidgets);
    expect(find.text('lod_source'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('build_manager_reveal_0')));
    await tester.pump();
    expect(revealed, ['contents/meshes/SM_Crate.lmas']);
  });

  testWidgets('the target list mirrors the project; Shipping → --release per ticked target; cook disabled without flutter', (tester) async {
    final vm = BuildManagerViewModel(projectDirPath: projDir.path, project: project, hostTargets: linuxHost);
    addTearDown(vm.dispose);
    expect(vm.selectedTargets, ['linux'], reason: 'the manifest default');
    expect(vm.configuration, BuildConfiguration.shipping);
    expect(vm.cookArguments, {'linux': ['build', 'linux', '--release']});
    expect(vm.packageDirFor('linux'), '${projDir.path}/build/package/linux');
    vm.setConfiguration(BuildConfiguration.development);
    vm.setExtraFlags('--verbose');
    expect(vm.cookArgumentsFor('linux'), ['build', 'linux', '--profile', '--verbose']);
    expect(vm.cookArgumentsFor('android'), ['build', 'apk', '--profile', '--verbose']);
    expect(vm.cookEnabled, isTrue);
    await pumpEditor(tester, vm);
    // Every platform is listed, ticked or not.
    for (final t in kPackagingPlatforms) {
      expect(find.byKey(ValueKey('build_manager_target_$t')), findsOneWidget);
    }
    expect(tester.widget<Checkbox>(find.byKey(const ValueKey('build_manager_target_linux'))).state, CheckboxState.checked);
    expect(tester.widget<Checkbox>(find.byKey(const ValueKey('build_manager_target_macos'))).state, CheckboxState.unchecked);
    expect(find.text('3.47.0'), findsOneWidget, reason: 'real Flutter version from the probe');

    final noFlutter = BuildManagerViewModel(
      projectDirPath: projDir.path,
      project: project,
      hostTargets: const HostBuildTargets(flutterAvailable: false, error: 'flutter is not available: ProcessException'),
    );
    addTearDown(noFlutter.dispose);
    expect(noFlutter.cookEnabled, isFalse);
    expect(noFlutter.cookDisabledReason, contains('not available'));
    await pumpEditor(tester, noFlutter);
    final cook = tester.widget<PrimaryButton>(find.byKey(const ValueKey('build_manager_cook')));
    expect(cook.onPressed, isNull);
    expect(find.textContaining('not available'), findsWidgets);
  });

  testWidgets('unbuildable targets stay tickable, show their reasons, and fail at cook time without spawning', (tester) async {
    const host = HostBuildTargets(flutterAvailable: true, flutterVersion: '3.47.0', targets: ['linux', 'web'], operatingSystem: 'linux');
    final recordDir = Directory('${tempDir.path}/record')..createSync();
    // No package config under the temp dir, so no flutter_filament web module is found.
    final vm = BuildManagerViewModel(
      projectDirPath: projDir.path,
      project: project,
      hostTargets: host,
      webModulePackageRoots: [tempDir.path],
      processStarter: flutterBuildStandIn(recordDir),
    );
    addTearDown(vm.dispose);
    for (final k in [BuildStepKind.precompileMaterials, BuildStepKind.buildNavigation, BuildStepKind.regenerateThumbnails, BuildStepKind.validateAssets]) {
      vm.setStepEnabled(k, false);
    }
    expect(vm.buildableTargets, ['linux']);
    expect(vm.reasonsFor('web').single, contains('flutter_filament.wasm'));
    expect(vm.reasonsFor('android'), hasLength(2), reason: 'no ready Android toolchain, and no Filament build for Android');
    expect(vm.reasonsFor('windows').first, contains('Windows host'));

    await pumpEditor(tester, vm);
    for (final t in ['web', 'android']) {
      await tester.ensureVisible(find.byKey(ValueKey('build_manager_target_$t')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('build_manager_target_$t')));
      await tester.pump();
    }
    expect(vm.selectedTargets, ['linux', 'android', 'web'], reason: 'unbuildable targets can be ticked');
    final manifest = File('${projDir.path}/bm_game.lmproject');
    await tester.runAsync(() async {
      for (var i = 0; i < 100 && !manifest.readAsStringSync().contains('"android"'); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    final saved = LuminaProject.fromMap(jsonDecode(manifest.readAsStringSync()) as Map<String, dynamic>);
    expect(saved.packaging.targets, ['linux', 'android', 'web'], reason: 'a standalone Build Manager saves the manifest itself');
    expect(find.byKey(const ValueKey('build_manager_target_reason_web_0')), findsOneWidget);
    expect(find.textContaining('build_module.sh'), findsWidgets, reason: 'the reason is shown next to the target');
    expect(find.textContaining('no Android build of the Filament libraries'), findsWidgets);
    expect(vm.cookEnabled, isTrue, reason: 'unbuildable targets are reported at cook time, not hidden');

    final cook = tester.widget<PrimaryButton>(find.byKey(const ValueKey('build_manager_cook')));
    await tester.runAsync(() async {
      cook.onPressed!();
      for (var i = 0; i < 600 && (vm.isRunning || vm.lastPipelineStatus == null); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }
    });
    await tester.pump();
    expect(vm.targetState('linux').status, PackageTargetStatus.ok, reason: vm.logText);
    expect(vm.targetState('android').status, PackageTargetStatus.unbuildable);
    expect(vm.targetState('web').status, PackageTargetStatus.unbuildable);
    expect(vm.lastPipelineStatus, BuildStepStatus.failed);
    expect(File('${recordDir.path}/argv.log').readAsLinesSync(), ['flutter build linux --release'], reason: 'nothing unbuildable is spawned');
    expect(find.byKey(const ValueKey('build_manager_target_status_android')), findsOneWidget);
    expect(find.text('NOT BUILDABLE'), findsNWidgets(2));
    expect(vm.logLines.any((l) => l.source == 'Cook & Package [android]' && l.level == 'error'), isTrue);
  });

  testWidgets('ticking a target in the Build Manager saves it into the editor project and the .lmproject', (tester) async {
    final editor = EditorViewModel(initialProject: project, projectLocation: tempDir.path, enableTimers: false, autoInitAssets: false);
    addTearDown(editor.dispose);
    final bm = editor.buildManagerViewModel;
    expect(bm.selectedTargets, ['linux']);
    bm.setTargetSelected('web', true);
    expect(editor.project.packaging.targets, ['linux', 'web']);
    expect(bm.selectedTargets, ['linux', 'web'], reason: 'the Build Manager reads the editor project');
    final manifest = File('${editor.projectDirPath}/${project.projectName}.lmproject');
    await tester.runAsync(() async {
      for (var i = 0; i < 100; i++) {
        if (manifest.existsSync() && manifest.readAsStringSync().contains('"web"')) break;
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    final raw = jsonDecode(manifest.readAsStringSync()) as Map<String, dynamic>;
    expect((raw['packaging'] as Map)['targets'], ['linux', 'web']);
  });

  testWidgets('Launch in Browser appears only after a web package and serves it', (tester) async {
    final module = FlutterFilamentWebModule.locate();
    if (module == null) return markTestSkipped('flutter_filament web module not built');
    writeFlutterWebPlatform(projDir.path);
    final opened = <Uri>[];
    final vm = BuildManagerViewModel(
      projectDirPath: projDir.path,
      project: project,
      hostTargets: linuxHost,
      processStarter: flutterBuildStandIn(tempDir),
      openUrl: (url) async => opened.add(url),
    );
    addTearDown(vm.dispose);
    for (final k in [BuildStepKind.precompileMaterials, BuildStepKind.buildNavigation, BuildStepKind.regenerateThumbnails, BuildStepKind.validateAssets]) {
      vm.setStepEnabled(k, false);
    }
    expect(vm.buildableTargets, ['linux', 'web'], reason: 'the module is built, so web is buildable');
    await pumpEditor(tester, vm);
    const launch = ValueKey('build_manager_launch_browser');

    // The cook spawns a real process and the preview binds a real socket, so
    // the buttons' own callbacks run in real time rather than the test clock.
    Future<void> press(ValueKey<String> key, bool Function() done) async {
      final button = tester.widget<PrimaryButton>(find.byKey(key));
      expect(button.onPressed, isNotNull, reason: '$key is enabled');
      await tester.runAsync(() async {
        button.onPressed!();
        for (var i = 0; i < 600 && !done(); i++) {
          await Future<void>.delayed(const Duration(milliseconds: 25));
        }
      });
      await tester.pump();
    }

    Future<void> cook() => press(const ValueKey('build_manager_cook'), () => !vm.isRunning && vm.lastPipelineStatus != null);

    // A Linux package: no browser action.
    await cook();
    expect(vm.lastPipelineStatus, BuildStepStatus.ok, reason: vm.logText);
    expect(vm.targetState('linux').packageDir, '${projDir.path}/build/package/linux');
    expect(find.byKey(launch), findsNothing);

    // Tick Web: one run packages both, and the action appears with the web package and its size.
    await tester.ensureVisible(find.byKey(const ValueKey('build_manager_target_web')));
    await tester.tap(find.byKey(const ValueKey('build_manager_target_web')));
    await tester.pumpAndSettle();
    expect(vm.selectedTargets, ['linux', 'web']);
    expect(find.byKey(launch), findsNothing, reason: 'nothing to launch before the web package');
    await cook();
    expect(vm.lastPipelineStatus, BuildStepStatus.ok, reason: vm.logText);
    expect(vm.targetState('linux').status, PackageTargetStatus.ok);
    expect(vm.webPackageDir, '${projDir.path}/build/package/web');
    expect(find.byKey(launch), findsOneWidget);
    // The Output section is open: the button can be scrolled to and clicked.
    await tester.ensureVisible(find.byKey(launch));
    await tester.pumpAndSettle();
    expect(find.byKey(launch).hitTestable(), findsOneWidget, reason: 'Launch in Browser must not sit inside a collapsed section');
    await tester.ensureVisible(find.byKey(const ValueKey('build_manager_argv_web')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('build_manager_argv_web')).hitTestable(), findsOneWidget, reason: 'every section of the panel is open');
    expect(vm.artifactSizeBytes, greaterThan(module.sizeBytes));
    expect(find.byKey(const ValueKey('build_manager_artifact_size_web')), findsOneWidget);
    expect(find.textContaining('MB'), findsWidgets);

    await press(launch, () => opened.isNotEmpty);
    expect(opened, hasLength(1));
    expect(opened.single.host, '127.0.0.1');
    expect(vm.previewUrl, opened.single);
    expect(find.text(opened.single.toString()), findsOneWidget, reason: 'the served URL is on screen');
    expect(File('${projDir.path}/build/package/web/flutter_filament.wasm').lengthSync(), module.files.last.lengthSync(),
        reason: 'the served package carries the module (serving itself: web_preview_server_test)');

    // Another run without Web takes the preview down.
    vm.setTargetSelected('web', false);
    await cook();
    expect(find.byKey(launch), findsNothing);
    expect(vm.previewUrl, isNull);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  });

  testWidgets('the Bundle web resources checkbox shows while Web is ticked and drives its argv', (tester) async {
    if (FlutterFilamentWebModule.locate() == null) return markTestSkipped('flutter_filament web module not built');
    final vm = BuildManagerViewModel(projectDirPath: projDir.path, project: project, hostTargets: linuxHost);
    addTearDown(vm.dispose);
    await pumpEditor(tester, vm);
    const box = ValueKey('build_manager_web_bundle_resources');
    String argvText(String t) => tester.widget<Text>(find.byKey(ValueKey('build_manager_argv_$t'))).data!;
    expect(vm.selectedTargets, ['linux']);
    expect(find.byKey(box), findsNothing, reason: 'a Linux cook has no web resources');

    await tester.ensureVisible(find.byKey(const ValueKey('build_manager_target_web')));
    await tester.tap(find.byKey(const ValueKey('build_manager_target_web')));
    await tester.pumpAndSettle();
    expect(vm.isTargetSelected('web'), isTrue);
    expect(find.byKey(box), findsOneWidget);
    expect(tester.widget<Checkbox>(find.byKey(box)).state, CheckboxState.unchecked);
    expect(vm.cookArgumentsFor('web'), ['build', 'web', '--release']);
    expect(find.text('Bundle web resources (works offline)'), findsOneWidget);

    await tester.ensureVisible(find.byKey(box));
    await tester.tap(find.byKey(box));
    await tester.pumpAndSettle();
    expect(vm.bundleWebResources, isTrue);
    expect(tester.widget<Checkbox>(find.byKey(box)).state, CheckboxState.checked);
    expect(vm.cookArgumentsFor('web'), ['build', 'web', '--release', '--no-web-resources-cdn']);
    expect(argvText('web'), 'flutter build web --release --no-web-resources-cdn');
    expect(argvText('linux'), 'flutter build linux --release', reason: 'the flag is for web only');

    vm.setTargetSelected('web', false);
    await tester.pumpAndSettle();
    expect(find.byKey(box), findsNothing);
    expect(find.byKey(const ValueKey('build_manager_argv_web')), findsNothing);
  });

  testWidgets('cook after failed validation asks for confirmation; declining never spawns flutter', (tester) async {
    writeLmas(
      'contents/meshes/SM_Broken.lmas',
      const LuminaAsset(assetId: 'mesh-broken', name: 'SM_Broken', type: AssetType.filamesh, references: [
        AssetReference(slotName: 'material_0', assetId: 'mat-x', assetPath: 'contents/materials/M_X.lmas'),
      ]),
    );
    var spawned = false;
    var asked = 0;
    final vm = BuildManagerViewModel(
      projectDirPath: projDir.path,
      project: project,
      hostTargets: linuxHost,
      processStarter: (exe, args, {workingDirectory}) {
        spawned = true;
        throw StateError('must not spawn');
      },
      confirmCookDespiteValidation: (issues) async {
        asked++;
        return false;
      },
    );
    addTearDown(vm.dispose);
    for (final k in [BuildStepKind.precompileMaterials, BuildStepKind.buildNavigation, BuildStepKind.regenerateThumbnails]) {
      vm.setStepEnabled(k, false);
    }
    await pumpEditor(tester, vm);
    await tester.tap(find.byKey(const ValueKey('build_manager_cook')));
    for (var i = 0; i < 40 && (vm.isRunning || vm.lastPipelineStatus == null); i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(asked, 1);
    expect(spawned, isFalse);
    expect(vm.stepState(BuildStepKind.cookAndPackage).status, BuildStepStatus.pending);
    expect(vm.lastPipelineStatus, BuildStepStatus.failed);
  });

  testWidgets('Build → Build All / Cook & Package commands dispatch into the shared view model', (tester) async {
    final editor = EditorViewModel(initialProject: project, projectLocation: tempDir.path, enableTimers: false, autoInitAssets: false);
    addTearDown(editor.dispose);
    expect(editor.commands.byId('build.buildAll'), isNotNull);
    expect(editor.commands.byId('build.cookAndPackage'), isNotNull);
    expect(editor.commands.byId('build.buildManager'), isNotNull);
    final bm = editor.buildManagerViewModel;
    expect(identical(bm, editor.buildManagerViewModel), isTrue, reason: 'one view model per editor');
    // Real asset steps only (no cook) against the temp project.
    bm.setStepEnabled(BuildStepKind.precompileMaterials, false);
    editor.commands.execute('build.buildAll');
    expect(editor.openTabs.any((t) => t.category == 'buildManager'), isTrue);
    for (var i = 0; i < 60 && (bm.isRunning || bm.lastPipelineStatus == null); i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(bm.lastPipelineStatus, BuildStepStatus.ok);
    expect(bm.stepState(BuildStepKind.buildNavigation).status, BuildStepStatus.skipped);
    expect(bm.stepState(BuildStepKind.validateAssets).status, BuildStepStatus.ok);
    expect(bm.stepState(BuildStepKind.regenerateThumbnails).status, BuildStepStatus.ok);
    // Reveal goes through the editor's content browser state.
    editor.revealAssetInContentBrowser('contents/meshes/SM_Crate.lmas');
    expect(editor.selectedFolder, 'contents/meshes');
    expect(editor.searchQuery, 'SM_Crate');
  });
}

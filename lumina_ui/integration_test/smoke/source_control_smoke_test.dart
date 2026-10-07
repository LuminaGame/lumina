import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/source_control/services/git_service.dart';
import 'package:lumina_ui/ui/features/source_control/views/commit_dialog.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

/// Source Control smoke: boot the
/// real editor on a temp project seeded with a real GLB from `test-assets/`,
/// accept the init-repo prompt (real `git init` + initial commit), modify the
/// seeded `.lmas`, watch the `M` badge appear on the Content Browser tile, open
/// the commit dialog (binary diff summary), commit, and assert HEAD advanced
/// and the badge cleared. PNGs + a video land in build/smoke_report.html.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Source Control Smoke: init prompt → M badge → commit dialog → HEAD advances', (tester) async {
    final probe = await tester.runAsync(() async {
      try {
        return (await Process.run('git', ['--version'])).exitCode == 0;
      } on ProcessException {
        return false;
      }
    });
    if (probe != true) {
      // ignore: avoid_print
      print('SKIPPED: git is not installed on this host; the source control smoke needs the real CLI.');
      return;
    }

    final tempProjectsDir = Directory.systemTemp.createTempSync('lumina_smoke_source_control_');
    final pDir = Directory('${tempProjectsDir.path}/SmokeGit')..createSync(recursive: true);
    final repo = AssetRepository();
    await repo.createAsset(projectPath: pDir.path, subFolder: 'levels', fileName: 'L_Main.lmas', type: AssetType.level);
    await repo.createAsset(projectPath: pDir.path, subFolder: 'meshes', fileName: 'SM_FuelBarrel.lmas', type: AssetType.filamesh);

    // Real 3D asset: a barrel GLB from test-assets sits next to its .lmas.
    const glbRel = 'Props/Barrels/fuel_barrel_red.glb';
    final glbSrc = File('${SmokeArtifacts.testAssetsDir.path}/$glbRel');
    expect(glbSrc.existsSync(), isTrue, reason: 'real test asset must exist: ${glbSrc.path}');
    final glbBytes = glbSrc.readAsBytesSync();
    File('${pDir.path}/contents/meshes/fuel_barrel_red.glb').writeAsBytesSync(glbBytes);

    const project = LuminaProject(projectName: 'SmokeGit', activeLevel: 'contents/levels/L_Main.lmas');
    File('${pDir.path}/SmokeGit.lmproject').writeAsStringSync(jsonEncode(project.toMap()));

    final vm = EditorViewModel(initialProject: project, projectLocation: tempProjectsDir.path, enableTimers: false);
    await tester.runAsync(() => vm.ensureDefaultLevelAssets());
    final sc = vm.sourceControl;

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
    await tester.runAsync(() => sc.whenIdle);
    await tester.pump(const Duration(milliseconds: 100));
    final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));

    // 1. Project without .git → the init prompt banner is shown under the menu bar.
    expect(sc.isAvailable, isTrue);
    expect(sc.isRepo, isFalse);
    expect(sc.shouldPromptInit, isTrue);
    expect(find.byKey(const ValueKey('sc_init_prompt')), findsOneWidget);
    expect(find.text('Initialize Git Repository'), findsOneWidget);
    final pngPrompt = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
    SmokeArtifacts.saveScreenshot('source_control_init_prompt', pngPrompt, usedAssets: [glbRel]);
    await rec.hold(const Duration(milliseconds: 1500));

    // 2. Accept → real git init + .gitignore + initial commit (repo-local identity if the host has none).
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('sc_init_button')));
      await sc.whenIdle;
      if (sc.identityRequired) {
        await sc.configureIdentity(name: 'Lumina Smoke', email: 'smoke@lumina.local');
        await sc.whenIdle;
      }
    });
    await tester.pump(const Duration(milliseconds: 300));
    expect(Directory('${pDir.path}/.git').existsSync(), isTrue);
    expect(File('${pDir.path}/.gitignore').readAsStringSync(), contains('saved/'));
    expect(sc.isRepo, isTrue);
    expect(sc.shouldPromptInit, isFalse);
    expect(find.byKey(const ValueKey('sc_init_prompt')), findsNothing);
    expect(sc.changes, isEmpty, reason: 'initial commit captured the whole project');
    final head0 = (await tester.runAsync(() => sc.service.headHash()))!;
    expect(head0.length, 40);
    await rec.hold(const Duration(milliseconds: 1500));

    // 3. Modify the seeded .lmas (embed the real GLB payload) → `M` badge on its tile.
    const lmasRel = 'contents/meshes/SM_FuelBarrel.lmas';
    final modified = LuminaAsset(
      assetId: 'asset_SM_FuelBarrel',
      name: 'SM_FuelBarrel',
      type: AssetType.filamesh,
      rawPayload: Uint8List.fromList(glbBytes),
    ).toProtoBufferBytes();
    File('${pDir.path}/$lmasRel').writeAsBytesSync(modified);
    vm.selectedFolder = 'contents/meshes';
    await tester.runAsync(() => sc.refresh());
    await tester.pump(const Duration(milliseconds: 300));
    expect(sc.stateFor(lmasRel), GitFileState.modified);
    expect(find.byKey(const ValueKey('sc_badge_$lmasRel')), findsOneWidget, reason: 'M badge on the asset tile');
    expect(find.byKey(const ValueKey('sc_badge_folder:contents/meshes')), findsOneWidget, reason: 'folder badge aggregates');
    final pngBadges = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
    SmokeArtifacts.saveScreenshot('source_control_status_badges', pngBadges, usedAssets: [glbRel, lmasRel]);
    await rec.hold(const Duration(milliseconds: 1500));

    // 4. Tools → Source Control → Commit… (command dispatch) shows the changelist with a binary summary.
    final ctx = tester.element(find.byType(MainEditorView));
    expect(vm.commands.byId('sourceControl.commit')!.canExecute(), isTrue);
    vm.commands.execute('sourceControl.commit', ctx);
    // Build the dialog first (its initState kicks off the diff summaries),
    // then wait for those git calls to settle.
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(CommitDialog), findsOneWidget);
    await tester.runAsync(() => sc.whenIdle);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Assets (.lmas)'), findsOneWidget);
    expect(find.byKey(const ValueKey('sc_row_check_$lmasRel')), findsOneWidget);
    final summary = tester.widget<Text>(find.byKey(const ValueKey('sc_row_summary_$lmasRel')));
    expect(summary.data, startsWith('binary'), reason: '.lmas diff summary is binary · old → new');
    expect(sc.summaryFor(lmasRel)!.newSize, modified.length);
    await rec.hold(const Duration(milliseconds: 800));
    // The commit message, typed.
    // (the TextArea hands its key to the TextField inside it)
    final message = find.byKey(const ValueKey('sc_commit_message')).last;
    await tester.tap(message);
    await rec.typeText(message, 'Embed fuel barrel GLB payload', perCharacter: const Duration(milliseconds: 60));
    await tester.pump(const Duration(milliseconds: 100));
    final pngDialog = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
    SmokeArtifacts.saveScreenshot('source_control_commit_dialog', pngDialog, usedAssets: [glbRel, lmasRel]);
    await rec.hold(const Duration(milliseconds: 800));

    // 5. Commit → HEAD advances, badges clear.
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('sc_commit_button')));
      await sc.whenIdle;
    });
    await tester.pump(const Duration(milliseconds: 400));
    final head1 = (await tester.runAsync(() => sc.service.headHash()))!;
    expect(head1, isNot(head0), reason: 'HEAD advanced');
    expect(sc.lastCommitHash, head1);
    expect(sc.lastError, isNull);
    expect(sc.changes, isEmpty);
    expect(find.byKey(const ValueKey('sc_commit_result')), findsOneWidget);
    final subject = await tester.runAsync(() => Process.run('git', ['log', '-1', '--format=%s'], workingDirectory: pDir.path));
    expect((subject!.stdout as String).trim(), 'Embed fuel barrel GLB payload');
    await rec.hold(const Duration(milliseconds: 1500));

    await tester.tap(find.byKey(const ValueKey('sc_commit_close')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(CommitDialog), findsNothing);
    expect(find.byKey(const ValueKey('sc_badge_$lmasRel')), findsNothing, reason: 'badge cleared after commit');
    final pngAfter = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
    SmokeArtifacts.saveScreenshot('source_control_after_commit', pngAfter, usedAssets: [glbRel, lmasRel]);
    await rec.hold(const Duration(milliseconds: 1200));

    // 6. Per-asset history follows the file: initial commit + the new one.
    final history = await tester.runAsync(() => sc.history(lmasRel));
    expect(history!.map((e) => e.subject).toList(), ['Embed fuel barrel GLB payload', 'Initial Lumina project']);

    rec.save('Source Control Smoke: init prompt → M badge → commit dialog → HEAD advances', usedAssets: [glbRel, lmasRel]);

    // Let the success toast expire before teardown, then clean up.
    await tester.pump(const Duration(seconds: 6));
    vm.dispose();
    if (tempProjectsDir.existsSync()) tempProjectsDir.deleteSync(recursive: true);
  });

  testWidgets('Source Control Smoke: large change set — 2 000 changes open at once with a progress bar, grouped by folder, committed in one go', (tester) async {
    final probe = await tester.runAsync(() async {
      try {
        return (await Process.run('git', ['--version'])).exitCode == 0;
      } on ProcessException {
        return false;
      }
    });
    if (probe != true) {
      // ignore: avoid_print
      print('SKIPPED: git is not installed on this host; the source control smoke needs the real CLI.');
      return;
    }
    const testTitle = 'Source Control Smoke: large change set';
    const glbRel = 'Props/Barrels/fuel_barrel_red.glb';
    final glbBytes = File('${SmokeArtifacts.testAssetsDir.path}/$glbRel').readAsBytesSync();

    final tempProjectsDir = Directory.systemTemp.createTempSync('lumina_smoke_sc_large_');
    final pDir = Directory('${tempProjectsDir.path}/BigGit')..createSync(recursive: true);
    final repo = AssetRepository();
    await repo.createAsset(projectPath: pDir.path, subFolder: 'levels', fileName: 'L_Main.lmas', type: AssetType.level);
    const project = LuminaProject(projectName: 'BigGit', activeLevel: 'contents/levels/L_Main.lmas');
    File('${pDir.path}/BigGit.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    Uint8List png(int seed) => SmokeArtifacts.encodeRgbaToPng(Uint8List.fromList(List<int>.generate(8 * 8 * 4, (i) => (i * seed) & 0xFF)), 8, 8);
    Uint8List mesh(int seed) => LuminaAsset(
          assetId: 'mesh_$seed',
          name: 'SM_Barrel_$seed',
          type: AssetType.filamesh,
          rawPayload: seed == 0 ? glbBytes : Uint8List.fromList(List<int>.generate(128, (i) => (i * seed) & 0xFF)),
        ).toProtoBufferBytes();
    // 1 260 tracked files (committed below, then modified) and 740 new ones.
    const layout = <String, (int, int)>{
      'contents/imports': (600, 600),
      'contents/sounds': (0, 40),
      'contents/meshes': (300, 0),
      'contents/levels/variants': (60, 0),
      'lib/gen': (300, 0),
      'notes': (0, 100),
    };
    void write(String folder, int i, {required bool tracked, required int version}) {
      final dir = Directory('${pDir.path}/$folder')..createSync(recursive: true);
      final prefix = tracked ? 'T' : 'N';
      if (folder == 'contents/meshes') {
        File('${dir.path}/SM_${prefix}_$i.lmas').writeAsBytesSync(mesh(i + version));
      } else if (folder.startsWith('contents/imports') || folder.startsWith('contents/sounds')) {
        File('${dir.path}/${prefix}_$i.png').writeAsBytesSync(png(i + version + 1));
      } else {
        File('${dir.path}/${prefix}_$i.${folder.startsWith('lib') ? 'dart' : 'txt'}').writeAsStringSync('// $i\n${'// v\n' * (version + 1)}');
      }
    }

    layout.forEach((folder, counts) {
      for (var i = 0; i < counts.$1; i++) {
        write(folder, i, tracked: true, version: 0);
      }
    });
    await tester.runAsync(() async {
      final svc = GitService(projectRoot: pDir.path, configOverrides: const ['-c', 'user.name=Lumina Smoke', '-c', 'user.email=smoke@lumina.local']);
      await svc.init(gitignoreContent: GitService.defaultGitignore, initialCommitMessage: 'Initial Lumina project');
      await Process.run('git', ['config', 'user.name', 'Lumina Smoke'], workingDirectory: pDir.path);
      await Process.run('git', ['config', 'user.email', 'smoke@lumina.local'], workingDirectory: pDir.path);
    });
    layout.forEach((folder, counts) {
      for (var i = 0; i < counts.$1; i++) {
        write(folder, i, tracked: true, version: 1);
      }
      for (var i = 0; i < counts.$2; i++) {
        write(folder, i, tracked: false, version: 0);
      }
    });

    final vm = EditorViewModel(initialProject: project, projectLocation: tempProjectsDir.path, enableTimers: false);
    await tester.runAsync(() => vm.ensureDefaultLevelAssets());
    final sc = vm.sourceControl;
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.runAsync(() => sc.whenIdle);
    await tester.pump(const Duration(milliseconds: 100));
    expect(sc.isRepo, isTrue);
    expect(sc.changes.length, greaterThanOrEqualTo(2000));
    final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
    await rec.hold(const Duration(milliseconds: 1200));

    // Tools → Source Control → Commit…: the dialog and its progress bar are
    // on screen in the very next frame.
    final invocationsBefore = sc.service.invocationCount;
    final logsBefore = vm.logger.logs.length;
    final ctx = tester.element(find.byType(MainEditorView));
    final openWatch = Stopwatch()..start();
    vm.commands.execute('sourceControl.commit', ctx);
    await tester.pump();
    openWatch.stop();
    expect(find.byType(CommitDialog), findsOneWidget);
    expect(find.byKey(const ValueKey('sc_commit_progress')), findsOneWidget, reason: 'progress bar in the first frame');
    final openLabel = tester.widget<Text>(find.byKey(const ValueKey('sc_commit_progress_label'))).data;
    // (the dialog fades in over a few frames before it is on the PNG)
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump(const Duration(milliseconds: 120));
    await rec.capture();
    final pngOpen = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
    SmokeArtifacts.saveScreenshot('source_control_large_change_set_opening', pngOpen, usedAssets: [glbRel]);

    // The summaries arrive while frames keep coming (recorded as they do).
    final loadWatch = Stopwatch()..start();
    var progressFrames = 0;
    while (sc.statusLoading || sc.summariesLoading || sc.isBusy) {
      await rec.hold(const Duration(milliseconds: 100));
      progressFrames++;
      if (loadWatch.elapsed > const Duration(seconds: 30)) break;
    }
    loadWatch.stop();
    await tester.pump();
    final gitProcesses = sc.service.invocationCount - invocationsBefore;
    final newLogs = vm.logger.logs.skip(logsBefore).where((l) => l.source == 'SourceControl').toList();
    for (final c in sc.changes) {
      expect(sc.summaryFor(c.path), isNotNull, reason: c.path);
    }
    expect(gitProcesses, lessThanOrEqualTo(5), reason: 'status + batched diff, not one per file');
    expect(newLogs.length, lessThanOrEqualTo(3), reason: newLogs.map((l) => l.message).join('\n'));
    expect(find.text('contents/imports/'), findsOneWidget);
    await rec.hold(const Duration(milliseconds: 1500));

    // The collapsed 1 200-file folder opens; the filter narrows the list.
    await tester.tap(find.byKey(const ValueKey('sc_folder_toggle_Assets (.lmas)|contents/imports')));
    await rec.hold(const Duration(milliseconds: 1200));
    final filter = find.byKey(const ValueKey('sc_commit_filter')).last;
    await tester.tap(filter);
    await rec.typeText(filter, 'SM_T_1', perCharacter: const Duration(milliseconds: 90));
    await rec.hold(const Duration(milliseconds: 1200));
    final pngDialog = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
    await tester.enterText(filter, '');
    await rec.hold(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const ValueKey('sc_folder_toggle_Assets (.lmas)|contents/imports')));
    await rec.hold(const Duration(milliseconds: 800));
    final pngGrouped = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));

    // Commit everything: "Committing 2 000 files…" with progress, then clean.
    final message = find.byKey(const ValueKey('sc_commit_message')).last;
    await tester.tap(message);
    await rec.typeText(message, 'Commit the whole change set', perCharacter: const Duration(milliseconds: 50));
    final head0 = (await tester.runAsync(() => sc.service.headHash()))!;
    final total = sc.changes.length;
    final commitWatch = Stopwatch()..start();
    await tester.tap(find.byKey(const ValueKey('sc_commit_button')));
    await tester.pump();
    var sawCommitBar = false;
    while (sc.isBusy) {
      if (find.textContaining('Committing $total files').evaluate().isNotEmpty) sawCommitBar = true;
      await rec.hold(const Duration(milliseconds: 100));
      if (commitWatch.elapsed > const Duration(seconds: 60)) break;
    }
    commitWatch.stop();
    await tester.pump();
    final head1 = (await tester.runAsync(() => sc.service.headHash()))!;
    expect(head1, isNot(head0), reason: 'HEAD advanced');
    expect(sc.lastError, isNull);
    expect(sc.changes, isEmpty);
    expect(sawCommitBar, isTrue, reason: '"Committing $total files…" was on screen');
    await rec.hold(const Duration(milliseconds: 1500));

    final metrics = <String, Object?>{
      'changes': total,
      'dialog_open_ms': openWatch.elapsedMilliseconds,
      'first_frame_progress_label': openLabel,
      'status_and_summaries_ms': loadWatch.elapsedMilliseconds,
      'progress_frames_recorded': progressFrames,
      'git_processes_for_open': gitProcesses,
      'source_control_log_lines_for_open': newLogs.length,
      'commit_ms': commitWatch.elapsedMilliseconds,
    };
    // ignore: avoid_print
    print('[source_control smoke large] $metrics');
    SmokeArtifacts.saveScreenshot(testTitle, pngGrouped, usedAssets: [glbRel], metrics: metrics);
    SmokeArtifacts.saveScreenshot('source_control_large_change_set_filtered', pngDialog, usedAssets: [glbRel]);
    rec.save(testTitle, usedAssets: [glbRel]);

    await tester.tap(find.byKey(const ValueKey('sc_commit_close')));
    await tester.pump(const Duration(seconds: 6));
    vm.dispose();
    if (tempProjectsDir.existsSync()) tempProjectsDir.deleteSync(recursive: true);
  });
}

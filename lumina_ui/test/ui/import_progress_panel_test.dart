import 'dart:io';
import 'dart:ui' show AppExitResponse;

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/import_jobs_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/content_browser_widget.dart';
import 'package:lumina_ui/ui/features/main_editor/views/import_asset_options_dialog.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Content Browser imports run on the background import
/// queue — the Import Asset Options dialog closes at once, a progress panel
/// shows the batch (counts, bar, per-file list, Cancel, Show errors), assets
/// land in the grid one by one, frames keep coming, and leaving the project
/// mid-batch asks to wait or cancel.
void main() {
  final assets = Platform.environment['LUMINA_TEST_ASSETS'] ?? '${Directory.current.parent.path}/test-assets';
  List<String> glbs(String folder, int count) {
    final dir = Directory('$assets/Props/$folder');
    if (!dir.existsSync()) return const [];
    final files = [
      for (final e in dir.listSync())
        if (e is File && e.path.endsWith('.glb')) e.path,
    ]..sort();
    return files.take(count).toList();
  }

  final twenty = glbs('rain_gutters', 20);
  final fiftyOne = [...glbs('signs_backlit', 51)];
  final skip = twenty.length == 20 && fiftyOne.length == 51 ? null : 'test-assets missing';

  late Directory temp;
  setUp(() => temp = Directory.systemTemp.createTempSync('lumina_ui_import_panel_'));
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

  Future<void> bigWindow(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  /// Lets the queue's isolates run (real time) and draws a frame, until
  /// [done] or [limit]; returns how long each frame took to pump.
  Future<List<Duration>> drive(WidgetTester tester, bool Function() done, {Duration limit = const Duration(seconds: 90)}) async {
    final frames = <Duration>[];
    final clock = Stopwatch()..start();
    while (!done() && clock.elapsed < limit) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 15)));
      final sw = Stopwatch()..start();
      await tester.pump(const Duration(milliseconds: 16));
      frames.add(sw.elapsed);
    }
    expect(done(), isTrue, reason: 'timed out after $limit');
    return frames;
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  String headline(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const ValueKey('import_progress_headline'))).data!;

  Finder tile(String fileName) =>
      find.byWidgetPredicate((w) => w is Draggable<RealAssetInfo> && w.data?.fileName == fileName);

  testWidgets('a 20-file batch keeps frames coming, lands assets one by one and shows its progress', (tester) async {
    await bigWindow(tester);
    final vm = openProject('PanelGame');
    addTearDown(vm.dispose);
    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)));
    await tester.pump();
    vm.selectedFolder = 'contents/meshes/static';
    await tester.pump();

    late Future<List<ImportProgress>> results;
    await tester.runAsync(() async {
      results = vm.importAssetFiles(twenty);
    });
    await tester.pump();
    expect(find.byKey(const ValueKey('import_progress_panel')), findsOneWidget);
    expect(headline(tester), startsWith('Importing 1 / 20 · '));

    // The assets land one at a time; while they do, a tap elsewhere is handled.
    final landedCounts = <int>[];
    final frames = await drive(tester, () {
      landedCounts.add(vm.visibleAssets.length);
      return !vm.isBatchImporting;
    });
    expect(landedCounts.toSet().length, greaterThan(3), reason: 'the grid grew file by file, not all at once');
    for (var i = 1; i < landedCounts.length; i++) {
      expect(landedCounts[i], greaterThanOrEqualTo(landedCounts[i - 1]));
    }
    expect(vm.visibleAssets, hasLength(20));
    final last = File(twenty.last).uri.pathSegments.last.replaceAll('.glb', '.lmas');
    expect(tile(last), findsOneWidget, reason: 'its tile is in the grid');

    // Frames kept coming, and no UI-isolate step of the queue held a frame
    // for more than 100 ms.
    expect(frames.length, greaterThan(10));
    expect(vm.importQueue.longestMainIsolateStep, lessThan(const Duration(milliseconds: 100)),
        reason: '${vm.importQueue.longestMainIsolateStepByKind}');
    expect(vm.importQueue.mainIsolateSteps, greaterThanOrEqualTo(40));

    final done = await tester.runAsync(() => results);
    expect(done!.every((r) => r.stage == ImportStage.done), isTrue);
    expect(headline(tester), 'Imported 20 of 20');

    // The per-file list, then auto-dismiss 5 s after a clean batch.
    await tester.tap(find.byKey(const ValueKey('import_progress_details')));
    await tester.pump();
    expect(find.byKey(const ValueKey('import_progress_file_0')), findsOneWidget);
    expect(
      find.descendant(of: find.byKey(const ValueKey('import_progress_files')), matching: find.text('done')),
      findsWidgets,
    );
    await tester.pump(const Duration(seconds: 6));
    expect(find.byKey(const ValueKey('import_progress_panel')), findsNothing);
  }, skip: skip != null);

  testWidgets('a tap in another panel is handled while a batch runs', (tester) async {
    await bigWindow(tester);
    final vm = openProject('TapGame');
    addTearDown(vm.dispose);
    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)));
    await tester.pump();
    await tester.runAsync(() async {
      vm.importAssetFiles(twenty);
    });
    await drive(tester, () => vm.importJobs.finished >= 3);
    expect(vm.isBatchImporting, isTrue);
    expect(vm.layoutState.activeBottomTab, 0);
    await tester.tap(find.text('Output Log'));
    await tester.pump();
    expect(vm.layoutState.activeBottomTab, 1, reason: 'the tab switched mid-batch');
    await drive(tester, () => !vm.isBatchImporting);
    expect(vm.importJobs.imported, 20);
    await tester.pump(ImportJobsViewModel.autoDismissAfter);
  }, skip: skip != null);

  testWidgets('Import Asset Options closes at once and the panel shows Importing 1 / 51; Cancel stops after the file in progress',
      (tester) async {
    await bigWindow(tester);
    final vm = openProject('DialogGame');
    addTearDown(vm.dispose);
    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)));
    await tester.pump();

    showImportAssetOptionsDialog(tester.element(find.byType(ContentBrowserWidget)), vm, fiftyOne);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Import Asset Options'), findsOneWidget);
    expect(find.text('Source Files: 51 files selected'), findsOneWidget);

    await tester.tap(find.text('Import Asset'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Import Asset Options'), findsNothing, reason: 'the dialog closed at once');
    final first = File(fiftyOne.first).uri.pathSegments.last;
    expect(headline(tester), 'Importing 1 / 51 · $first');
    expect(find.byKey(const ValueKey('import_progress_cancel')), findsOneWidget);

    // Collapse to the status-bar chip and back.
    await tester.tap(find.byKey(const ValueKey('import_progress_collapse')));
    await tester.pump();
    expect(find.byKey(const ValueKey('import_progress_panel')), findsNothing);
    expect(find.byKey(const ValueKey('status_bar_import_chip')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('status_bar_import_chip')));
    await tester.pump();
    expect(find.byKey(const ValueKey('import_progress_panel')), findsOneWidget);

    // Let a few land, then Cancel: the files in progress finish, the rest are skipped.
    await drive(tester, () => vm.importJobs.imported >= 2);
    await tester.tap(find.byKey(const ValueKey('import_progress_cancel')));
    await tester.pump();
    await drive(tester, () => !vm.isBatchImporting);
    final jobs = vm.importJobs;
    expect(jobs.imported, greaterThanOrEqualTo(2));
    expect(jobs.imported + jobs.cancelled, 51);
    expect(jobs.cancelled, greaterThan(30));
    expect(headline(tester), 'Imported ${jobs.imported} of 51 · ${jobs.cancelled} cancelled');
    final written = Directory('${vm.projectDirPath}/contents/meshes/static')
        .listSync()
        .where((e) => e.path.endsWith('.lmas'))
        .length;
    expect(written, jobs.imported, reason: 'what finished is kept, nothing else is written');
    // A cancelled batch stays until dismissed.
    await tester.pump(const Duration(seconds: 6));
    expect(find.byKey(const ValueKey('import_progress_panel')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('import_progress_collapse')));
    await tester.pump();
    expect(find.byKey(const ValueKey('import_progress_panel')), findsNothing);
  }, skip: skip != null);

  testWidgets('a failed file shows "Show errors", which opens the Output Log filtered to errors', (tester) async {
    await bigWindow(tester);
    final vm = openProject('ErrorsGame');
    addTearDown(vm.dispose);
    final whole = File(twenty.first).readAsBytesSync();
    final broken = File('${temp.path}/SM_Broken.glb')..writeAsBytesSync(whole.sublist(0, whole.length ~/ 3));
    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)));
    await tester.pump();
    await tester.runAsync(() async {
      vm.importAssetFiles([twenty[1], broken.path, twenty[2]]);
    });
    await drive(tester, () => !vm.isBatchImporting);
    expect(vm.importJobs.failed, 1);
    expect(vm.importJobs.imported, 2);
    expect(headline(tester), 'Imported 2 of 3 · 1 failed');

    await tester.tap(find.byKey(const ValueKey('import_progress_details')));
    await tester.pump();
    expect(find.textContaining('failed: SM_Broken.glb is truncated'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('import_progress_show_errors')));
    await tester.pump();
    await tester.pump();
    expect(vm.layoutState.activeBottomTab, 1);
    expect(vm.outputLogFilter.value, 'error');
    expect(find.textContaining('Import failed for SM_Broken.glb'), findsOneWidget);
    // Not auto-dismissed: it failed.
    await tester.pump(const Duration(seconds: 6));
    expect(find.byKey(const ValueKey('import_progress_panel')), findsOneWidget);
  }, skip: skip != null);

  Future<void> openEditorFromLauncher(WidgetTester tester, EditorViewModel vm) async {
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Builder(
        builder: (context) => Center(
          child: PrimaryButton(
            onPressed: () => Navigator.of(context).push(PageRouteBuilder<void>(
              pageBuilder: (_, _, _) => MainEditorView(viewModel: vm),
              transitionDuration: Duration.zero,
            )),
            child: const Text('Open Launcher Project'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Open Launcher Project'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(MainEditorView), findsOneWidget);
  }

  testWidgets('Exit Studio mid-batch asks to wait or cancel; Wait closes the project once the batch is done', (tester) async {
    await bigWindow(tester);
    final vm = openProject('ExitWaitGame');
    addTearDown(vm.dispose);
    await openEditorFromLauncher(tester, vm);
    final ctx = tester.element(find.byType(ContentBrowserWidget));

    await tester.runAsync(() async {
      vm.importAssetFiles(twenty.take(6).toList());
    });
    await tester.pump();
    vm.commands.byId('file.exitStudio')!.execute(ctx);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Import in Progress'), findsOneWidget);
    expect(find.text('Wait'), findsOneWidget);
    expect(find.text('Cancel Import'), findsOneWidget);

    // Keep Editing: nothing happens.
    await tester.tap(find.text('Keep Editing'));
    await settle(tester);
    expect(find.text('Import in Progress'), findsNothing);
    expect(find.byType(MainEditorView), findsOneWidget);
    expect(vm.isBatchImporting, isTrue);

    vm.commands.byId('file.exitStudio')!.execute(ctx);
    await settle(tester);
    await tester.tap(find.text('Wait'));
    await settle(tester);
    expect(find.byType(MainEditorView), findsOneWidget, reason: 'still open while the batch runs');
    await drive(tester, () => !vm.isBatchImporting);
    await tester.pump(const Duration(milliseconds: 500));
    expect(vm.importJobs.imported, 6);
    expect(find.byType(MainEditorView), findsNothing, reason: 'closed once the batch finished');
    expect(find.text('Open Launcher Project'), findsOneWidget);
    await tester.pump(ImportJobsViewModel.autoDismissAfter);
  }, skip: skip != null);

  testWidgets('Exit Studio mid-batch → Cancel Import closes the project after the file in progress', (tester) async {
    await bigWindow(tester);
    final vm = openProject('ExitCancelGame');
    addTearDown(vm.dispose);
    await openEditorFromLauncher(tester, vm);
    final ctx = tester.element(find.byType(ContentBrowserWidget));

    await tester.runAsync(() async {
      vm.importAssetFiles(twenty);
    });
    await drive(tester, () => vm.importJobs.imported >= 1);
    vm.commands.byId('file.exitStudio')!.execute(ctx);
    await settle(tester);
    await tester.tap(find.text('Cancel Import'));
    await settle(tester);
    await drive(tester, () => !vm.isBatchImporting);
    await tester.pump(const Duration(milliseconds: 500));
    expect(vm.importJobs.cancelled, greaterThan(10));
    expect(vm.importJobs.imported + vm.importJobs.cancelled, 20);
    expect(find.byType(MainEditorView), findsNothing);
  }, skip: skip != null);

  testWidgets('quitting the app mid-batch is held back by the wait / cancel prompt', (tester) async {
    await bigWindow(tester);
    final vm = openProject('QuitGame');
    addTearDown(vm.dispose);
    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)));
    await tester.pump();
    expect(await tester.binding.handleRequestAppExit(), AppExitResponse.exit, reason: 'nothing importing: quit');

    await tester.runAsync(() async {
      vm.importAssetFiles(twenty.take(4).toList());
    });
    await tester.pump();
    late AppExitResponse response;
    await tester.runAsync(() async {
      response = await tester.binding.handleRequestAppExit();
    });
    await settle(tester);
    expect(response, AppExitResponse.cancel, reason: 'the quit waits for the answer');
    expect(find.text('Import in Progress'), findsOneWidget);
    await tester.tap(find.text('Keep Editing'));
    await settle(tester);
    expect(find.text('Import in Progress'), findsNothing);
    await drive(tester, () => !vm.isBatchImporting);
    await tester.pump(ImportJobsViewModel.autoDismissAfter);
  }, skip: skip != null);

  test('the Editor Preferences worker count (1–4) is saved and drives the queue', () async {
    final vm = openProject('WorkersGame');
    addTearDown(vm.dispose);
    vm.editorPreferences.setImportWorkers(9);
    expect(vm.editorPreferences.importWorkers, 4);
    vm.editorPreferences.setImportWorkers(2);
    expect(savedWorkers(vm.editorPreferences.file), 2);
    final results = await vm.importAssetFiles(twenty.take(4).toList());
    expect(vm.importQueue.workers, 2);
    expect(results.map((r) => r.stage), everyElement(ImportStage.done));
    // The single-file API is a thin wrapper over the same queue.
    final one = await vm.importAssetFileAndReturn(twenty[5]);
    expect(one, isNotNull);
    expect(one!.lmasPath, endsWith('.lmas'));
    expect(vm.importQueue.lastSummary!.total, 1);
    expect(vm.realAssets.where((a) => a.relativePath == one.relativePath), hasLength(1));
  }, skip: skip);
}

/// The worker count as saved in the preferences file.
int? savedWorkers(File file) {
  final decoded = ConfigJsonFile(file).read();
  return decoded is Map ? decoded['importWorkers'] as int? : null;
}

import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/gestures.dart' show kSecondaryButton, kSecondaryMouseButton, PointerDeviceKind;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/features/launcher/view_models/launcher_view_model.dart';
import 'package:lumina_ui/ui/features/launcher/views/launcher_view.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/main_editor/views/viewport_widget.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import '../helpers/shared_editor_preferences.dart';

Future<LuminaProject> createMockProject(ProjectRepository repo, {required String projectName, required String projectLocation}) async {
  final dir = Directory('$projectLocation/$projectName');
  dir.createSync(recursive: true);
  final p = LuminaProject(
    projectName: projectName,
    activeLevel: 'contents/levels/L_DefaultLevel.lmas',
  );
  final file = File('${dir.path}/$projectName.lmproject');
  file.writeAsStringSync(jsonEncode(p.toMap()));
  await repo.addRecentProject(p, projectDir: dir.path);
  return p;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Launcher Smoke Scenario: Hub loads real projects, renders cover, detects missing, and captures smoke screenshot', (tester) async {
    final tempConfigDir = Directory.systemTemp.createTempSync('launcher_smoke_config_');
    final tempProjectsDir = Directory.systemTemp.createTempSync('launcher_smoke_projects_');

    try {
      final repo = ProjectRepository(configDir: tempConfigDir);

      // Project 1: Valid project with real assets from test-assets/ and a cover thumbnail
      await createMockProject(
        repo,
        projectName: 'SmokeRealmProject',
        projectLocation: tempProjectsDir.path,
      );

      final p1Dir = '${tempProjectsDir.path}/SmokeRealmProject';
      final testAssets = SmokeArtifacts.testAssetsDir;
      final barrelAsset = File('${testAssets.path}/Props/Barrels/dented_barrel.glb');
      final acAsset = File('${testAssets.path}/Props/AC_units/ac_unit_a_300x300.glb');
      final usedAssets = <String>[];

      if (barrelAsset.existsSync()) {
        final targetMesh = File('$p1Dir/contents/meshes/dented_barrel.glb');
        targetMesh.createSync(recursive: true);
        targetMesh.writeAsBytesSync(barrelAsset.readAsBytesSync());
        usedAssets.add('Props/Barrels/dented_barrel.glb');
      }

      if (acAsset.existsSync()) {
        final targetMesh = File('$p1Dir/contents/meshes/ac_unit.glb');
        targetMesh.createSync(recursive: true);
        targetMesh.writeAsBytesSync(acAsset.readAsBytesSync());
        usedAssets.add('Props/AC_units/ac_unit_a_300x300.glb');
      }

      // Add cover PNG
      final coverDir = Directory('$p1Dir/contents/.thumbnails')..createSync(recursive: true);
      final coverFile = File('${coverDir.path}/cover.png');
      final coverBytes = SmokeArtifacts.encodeRgbaToPng(
        Uint8List.fromList(List.generate(32 * 32 * 4, (i) => i % 4 == 3 ? 255 : (i % 255))),
        32,
        32,
      );
      coverFile.writeAsBytesSync(coverBytes);

      // Project 2: Missing on disk project
      await createMockProject(
        repo,
        projectName: 'MissingSmokeProject',
        projectLocation: tempProjectsDir.path,
      );
      final p2Dir = Directory('${tempProjectsDir.path}/MissingSmokeProject');
      if (p2Dir.existsSync()) {
        p2Dir.deleteSync(recursive: true);
      }

      useSharedEditor(tempConfigDir);
      final vm = LauncherViewModel(configDir: tempConfigDir);

      final repaintBoundaryKey = GlobalKey();

      await tester.pumpWidget(
        RepaintBoundary(
          key: repaintBoundaryKey,
          child: ShadcnApp(
            theme: luminaEditorTheme(),
            home: LauncherView(viewModel: vm),
          ),
        ),
      );

      await tester.pumpAndSettle();
      final rec = SmokeRecorder(tester, boundary: find.byKey(repaintBoundaryKey));
      await rec.hold(const Duration(seconds: 1));

      expect(find.text('SmokeRealmProject'), findsOneWidget);
      expect(find.text('0.0.1'), findsWidgets);

      // Search the hub: typing narrows the grid, clearing brings it back.
      final search = find.byWidgetPredicate((w) =>
          w is TextField && w.placeholder is Text && ((w.placeholder as Text).data ?? '').startsWith('Search projects'));
      await tester.tap(search);
      await rec.typeText(search, 'realm', perCharacter: const Duration(milliseconds: 150));
      await tester.pumpAndSettle();
      expect(find.text('SmokeRealmProject'), findsOneWidget);
      await rec.hold(const Duration(seconds: 1));
      await tester.enterText(search, 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('SmokeRealmProject'), findsNothing);
      await rec.hold(const Duration(milliseconds: 800));
      await tester.enterText(search, '');
      await tester.pumpAndSettle();
      await rec.hold(const Duration(milliseconds: 600));

      // Unreachable projects are left out of the list by default (launcher
      // 5e9637f); the count brings them back with their Missing badge.
      expect(find.text('MissingSmokeProject'), findsNothing);
      await tester.tap(find.text('1 hidden — path not found'));
      await tester.pumpAndSettle();
      expect(find.text('MissingSmokeProject'), findsOneWidget);
      expect(find.text('Missing'), findsOneWidget);
      await rec.hold(const Duration(seconds: 1));

      // Its context menu offers Locate… and Remove from Hub; remove it.
      await tester.tap(find.text('MissingSmokeProject'), buttons: kSecondaryButton, kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      expect(find.text('Locate...'), findsWidgets);
      expect(find.text('Remove from Hub'), findsOneWidget);
      await rec.hold(const Duration(seconds: 1));
      await tester.tap(find.text('Remove from Hub'));
      await tester.pumpAndSettle();
      expect(find.byType(LauncherView), findsOneWidget,
          reason: 'Remove from Hub must close only the menu, not the launcher page');
      expect(find.text('MissingSmokeProject'), findsNothing);
      expect(find.text('SmokeRealmProject'), findsOneWidget);
      await rec.hold(const Duration(seconds: 1));

      // Switch to Templates tab
      await tester.tap(find.text('Templates'));
      await tester.pumpAndSettle();
      expect(find.text('Blank 3D'), findsOneWidget);
      expect(find.text('First Person'), findsOneWidget);
      expect(find.text('Third Person'), findsOneWidget);
      await rec.hold(const Duration(milliseconds: 1500));

      // Switch back to Recent Projects tab
      await tester.tap(find.text('Recent Projects'));
      await tester.pumpAndSettle();
      await rec.hold(const Duration(seconds: 1));

      // Capture widget frame screenshot
      final pngScreenshot = await SmokeArtifacts.captureIntegrationPng(
        binding,
        tester,
        boundary: find.byKey(repaintBoundaryKey),
      );

      const testTitle = 'Launcher Smoke Scenario: Hub loads real projects, renders cover, detects missing, and captures smoke screenshot';
      SmokeArtifacts.saveScreenshot(
        testTitle,
        pngScreenshot,
        usedAssets: usedAssets,
      );
      rec.save(testTitle, usedAssets: usedAssets);

      expect(pngScreenshot.length, greaterThan(0));
    } finally {
      if (tempConfigDir.existsSync()) {
        tempConfigDir.deleteSync(recursive: true);
      }
      if (tempProjectsDir.existsSync()) {
        tempProjectsDir.deleteSync(recursive: true);
      }
    }
  });

  testWidgets('Launcher Smoke Scenario 2: Pipeline execution creates full project and navigates to main editor', (tester) async {
    final tempConfigDir = Directory.systemTemp.createTempSync('launcher_smoke_config2_');
    final tempProjectsDir = Directory.systemTemp.createTempSync('launcher_smoke_projects2_');
    
    try {
      useSharedEditor(tempConfigDir);
      final vm = LauncherViewModel(configDir: tempConfigDir);
      final repaintBoundaryKey = GlobalKey();

      await tester.pumpWidget(
        RepaintBoundary(
          key: repaintBoundaryKey,
          child: ShadcnApp(
            theme: luminaEditorTheme(),
            home: LauncherView(viewModel: vm),
          ),
        ),
      );

      await tester.pumpAndSettle();
      final rec = SmokeRecorder(tester, boundary: find.byKey(repaintBoundaryKey));
      await rec.hold(const Duration(seconds: 1));

      // Open new project dialog. The hub shows "New Project..." in its action
      // bar; with no recents at all only the empty state's "Create New
      // Project" is on screen.
      await tester.tap(find.text('New Project...').evaluate().isNotEmpty
          ? find.text('New Project...').last
          : find.text('Create New Project').last);
      await tester.pumpAndSettle();
      await rec.hold(const Duration(seconds: 1));

      // Type valid name
      final nameField = find.widgetWithText(TextField, 'my_lumina_game').first;
      await tester.tap(nameField);
      await rec.typeText(nameField, 'epic_smoke_game');
      await tester.pumpAndSettle();
      await rec.hold(const Duration(milliseconds: 600));

      // Location is already correct default, but we should set it to tempProjectsDir
      final locField = find.byType(TextField).last;
      await tester.enterText(locField, tempProjectsDir.path);
      await tester.pumpAndSettle();
      await rec.hold(const Duration(seconds: 1));

      // Click Create
      await tester.tap(find.text('Create Project'));
      await tester.pump(const Duration(milliseconds: 100)); // wait for stream to start
      
      // Capture in-progress dialog
      final pngInProgress = await SmokeArtifacts.captureIntegrationPng(
        binding,
        tester,
        boundary: find.byKey(repaintBoundaryKey),
      );
      SmokeArtifacts.saveScreenshot(
        'Launcher Smoke Scenario 2: Project Creation Pipeline In-Progress Dialog',
        pngInProgress,
      );

      // Wait for it to finish and navigate to main editor (give it a generous timeout like 45 seconds for flutter create / pub get).
      // The pipeline's progress is recorded as it runs: a frame per poll
      // whenever the dialog changed (a still dialog adds no copies).
      for (var i = 0; i < 90; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        await rec.captureIfChanged();
        if (find.byType(MainEditorView).evaluate().isNotEmpty) {
          break;
        }
      }
      
      expect(find.byType(MainEditorView), findsOneWidget);

      // Capture main editor
      final pngEditor = await SmokeArtifacts.captureIntegrationPng(
        binding,
        tester,
        boundary: find.byKey(repaintBoundaryKey),
      );
      SmokeArtifacts.saveScreenshot(
        'Launcher Smoke Scenario 2: Main Editor loaded newly created project',
        pngEditor,
      );
      await rec.hold(const Duration(seconds: 1));
      // Look around the new level: a right-button drag turns the camera.
      final viewportRect = tester.getRect(find.byType(ViewportWidget));
      await rec.drag(viewportRect.center, viewportRect.center + const Offset(240, 40),
          steps: 40, buttons: kSecondaryMouseButton);
      await rec.hold(const Duration(seconds: 1));
      // And select the new level's first actor in the outliner.
      final firstRow = find.byWidgetPredicate(
          (w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('row_gesture_'));
      expect(firstRow, findsWidgets, reason: 'the new level has actors in the outliner');
      await tester.tap(firstRow.first);
      await tester.pump(const Duration(milliseconds: 100));
      await rec.hold(const Duration(milliseconds: 1200));
      rec.save('Launcher Smoke Scenario 2: Pipeline execution creates full project and navigates to main editor');

      final projectDir = Directory('${tempProjectsDir.path}/epic_smoke_game');
      expect(projectDir.existsSync(), isTrue);
      expect(File('${projectDir.path}/epic_smoke_game.lmproject').existsSync(), isTrue);
      expect(File('${projectDir.path}/pubspec.yaml').existsSync(), isTrue);

    } finally {
      if (tempConfigDir.existsSync()) {
        tempConfigDir.deleteSync(recursive: true);
      }
      if (tempProjectsDir.existsSync()) {
        tempProjectsDir.deleteSync(recursive: true);
      }
    }
  });

  // Pick each discrete GPU in Settings, then create a Third
  // Person project; its viewport engine must render on that GPU.
  testWidgets('launcher: choose the graphics device', (tester) async {
    const name = 'launcher: choose the graphics device';
    final discrete = LuminaGraphicsDevices.list().where((d) => d.isDiscrete).toList();
    if (discrete.isEmpty) {
      markTestSkipped('no discrete Vulkan GPU on this host');
      return;
    }
    final projects = Directory.systemTemp.createTempSync('lumina_smoke_gpu_');
    final config = Directory.systemTemp.createTempSync('lumina_smoke_gpu_cfg_');
    useSharedEditor(config);
    addTearDown(() {
      LuminaGraphicsDevices.usePreferred(null, environment: const {});
      projects.deleteSync(recursive: true);
      config.deleteSync(recursive: true);
    });
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> settle([int frames = 20]) async {
      for (var i = 0; i < frames; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
      }
    }

    // One recording across every GPU: the same boundary key is reused by
    // each launcher instance.
    final boundaryKey = GlobalKey();
    final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
    for (final gpu in discrete) {
      LuminaGraphicsDevices.inUse.value = null;
      // The smoke runs with VK_DEVICE_INDEX set; the launcher is given an
      // empty environment so the choice made here is the one applied.
      await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: ShadcnApp(
          theme: luminaEditorTheme(),
          home: LauncherView(viewModel: LauncherViewModel(configDir: config, environment: const {})),
        ),
      ));
      await settle(30);
      await rec.hold(const Duration(milliseconds: 1500));
      await tester.tap(find.text('Settings').first);
      await settle();
      await rec.hold(const Duration(seconds: 1));
      await tester.tap(find.byKey(const ValueKey('graphics_device_select')));
      await settle();
      await rec.hold(const Duration(seconds: 1));
      await tester.tap(find.text(gpu.label).last);
      await settle();
      SmokeArtifacts.saveScreenshot('$name 01 settings ${gpu.name}',
          await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey)));
      await rec.hold(const Duration(milliseconds: 1500));

      final newProject = find.text('New Project...');
      await tester.tap(newProject.last);
      await settle();
      await rec.hold(const Duration(seconds: 1));
      final projectName = 'gpu_${gpu.index}';
      await tester.enterText(find.widgetWithText(TextField, 'my_lumina_game').first, projectName);
      await settle(6);
      await tester.enterText(find.byType(TextField).last, projects.path);
      await settle(6);
      await tester.tap(find.text('Third Person'));
      await settle(6);
      await rec.hold(const Duration(seconds: 1));
      await tester.tap(find.text('Create Project'));
      // Project creation is recorded as a time-lapse: a frame every half
      // second of the (minutes long) scaffolding run.
      final deadline = DateTime.now().add(const Duration(minutes: 7));
      final sinceFrame = Stopwatch()..start();
      while (LuminaGraphicsDevices.inUse.value == null && DateTime.now().isBefore(deadline)) {
        await settle(6);
        if (sinceFrame.elapsedMilliseconds >= 500) {
          await rec.captureIfChanged();
          sinceFrame.reset();
        }
      }
      await settle(40);
      expect(LuminaGraphicsDevices.inUse.value, gpu.name, reason: 'the viewport engine renders on the chosen GPU');
      expect(find.textContaining('RHI: Vulkan · ${gpu.name}'), findsOneWidget);
      SmokeArtifacts.saveScreenshot('$name ${gpu.name}',
          await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey)));
      await rec.hold(const Duration(seconds: 2));
      await tester.pumpWidget(const SizedBox());
      await settle(10);
    }
    rec.save(name);
  }, timeout: const Timeout(Duration(minutes: 20)));
}

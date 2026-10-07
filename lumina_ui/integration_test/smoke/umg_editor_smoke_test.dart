import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/launcher/view_models/launcher_view_model.dart';
import 'package:lumina_ui/ui/features/launcher/views/launcher_view.dart';
import 'package:lumina_ui/ui/features/main_editor/views/viewport_widget.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/project_settings_sub_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/umg_document.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/umg_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/umg/widget_sub_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/blueprint_sub_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/core/property_editors/scrub_numeric_field.dart';
import 'package:lumina_ui/ui/core/property_editors/slider_field.dart';
import '../helpers/shared_editor_preferences.dart';

/// UMG editor smoke: boot the real editor on a real temp
/// project, open a WIDGET `.lmas` through the shell's own tab path, drag a
/// Progress Bar and a Text out of the palette onto the designer canvas, bind a
/// real imported texture to an Image element, anchor the bar to the bottom-left,
/// switch the resolution simulator (PNG + WebM evidence), then Save and Compile
/// and assert both the on-disk `.lmas` tree and the generated Flutter widget
/// file under the project's `lib/widgets/`.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('UMG Smoke: palette drops + anchors + resolution simulator round-trip through the .lmas and real codegen', (tester) async {
    final tempProjectsDir = Directory.systemTemp.createTempSync('lumina_smoke_umg_');
    final pDir = Directory('${tempProjectsDir.path}/SmokeHud')..createSync(recursive: true);
    const project = LuminaProject(projectName: 'SmokeHud', activeLevel: 'contents/levels/L_Main.lmas');
    File('${pDir.path}/SmokeHud.lmproject').writeAsStringSync(jsonEncode(project.toMap()));

    try {
      final vm = EditorViewModel(initialProject: project, projectLocation: tempProjectsDir.path);
      await tester.runAsync(() => vm.ensureDefaultLevelAssets());

      // A real PNG on disk goes through the real import pipeline so the Image
      // brush binds an actual TEXTURE asset.
      final source = img.Image(width: 128, height: 128);
      for (var y = 0; y < 128; y++) {
        for (var x = 0; x < 128; x++) {
          final ring = ((x - 64) * (x - 64) + (y - 64) * (y - 64)) < 3200;
          source.setPixelRgba(x, y, ring ? 250 : 20, ring ? 190 : 24, ring ? 40 : 32, 255);
        }
      }
      final texturePng = File('${tempProjectsDir.path}/hud_dial.png')..writeAsBytesSync(img.encodePng(source));
      await tester.runAsync(() => vm.processImportPipeline(sourceFilePath: texturePng.path));

      // The WIDGET asset the designer opens.
      await tester.runAsync(() => AssetRepository().createAsset(
            projectPath: pDir.path,
            subFolder: 'widgets',
            fileName: 'WBP_PlayerHUD.lmas',
            type: AssetType.widget,
          ));
      vm.refreshAssets();
      final widgetAsset = vm.realAssets.firstWhere((a) => a.fileName == 'WBP_PlayerHUD.lmas');
      final textureAsset = vm.realAssets.firstWhere((a) => a.type == AssetType.texture);

      tester.view.physicalSize = const Size(1920, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

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

      // The live binding runs animations on the real clock: every frame waits.
      Future<void> settle([int frames = 20]) async {
        for (var i = 0; i < frames; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
        }
      }

      await settle(30);
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      await rec.hold(const Duration(seconds: 1));

      // Open the widget through the real shell tab path.
      vm.openSubEditorTab('WIDGET', asset: widgetAsset);
      await settle(20);
      await rec.hold(const Duration(milliseconds: 1500));
      expect(find.byType(UMGWidgetSubEditor), findsOneWidget);
      expect(find.text('UMG Visual Designer Canvas'), findsNothing, reason: 'the placeholder canvas is gone');
      final umg = (tester.state(find.byType(UMGWidgetSubEditor)) as dynamic).viewModelForTest as UmgEditorViewModel;
      expect(umg.isLoaded, isTrue);
      expect(umg.document.root.type, UmgWidgetType.canvasPanel);
      expect(umg.document.root.children, isEmpty, reason: 'a fresh WIDGET asset starts empty');
      umg.snapToGrid = false;

      /// Drags [type] out of the palette onto the canvas at [fraction] of the
      /// design surface and returns the node it created.
      Future<UmgNode> dropFromPalette(UmgWidgetType type, Offset fraction) async {
        final item = find.byKey(ValueKey('umg_palette_${type.name}'));
        expect(item, findsOneWidget, reason: '${type.displayName} sits in the palette');
        final surface = find.byKey(const ValueKey('umg_canvas_surface'));
        expect(surface, findsOneWidget);
        final rect = tester.getRect(surface);
        final target = rect.topLeft + Offset(rect.width * fraction.dx, rect.height * fraction.dy);
        final start = tester.getCenter(item);
        final gesture = await tester.startGesture(start);
        await settle(4);
        // The drag is recorded as it crosses from the palette to the canvas.
        for (var i = 1; i <= 12; i++) {
          await gesture.moveTo(Offset.lerp(start, target, i / 12)!);
          await settle(1);
          await rec.capture();
        }
        await settle(4);
        await gesture.moveTo(target + const Offset(1, 0));
        await settle(4);
        await gesture.up();
        await settle(8);
        await rec.hold(const Duration(milliseconds: 800));
        return umg.document.root.children.last;
      }

      final bar = await dropFromPalette(UmgWidgetType.progressBar, const Offset(0.22, 0.78));
      expect(bar.type, UmgWidgetType.progressBar);
      final label = await dropFromPalette(UmgWidgetType.text, const Offset(0.5, 0.2));
      expect(label.type, UmgWidgetType.text);
      final dial = await dropFromPalette(UmgWidgetType.image, const Offset(0.78, 0.7));
      expect(dial.type, UmgWidgetType.image);
      expect(umg.document.root.children.length, 3);

      // Real texture on the Image brush, real text on the label.
      umg.setProp(dial.id, 'texture', textureAsset.relativePath);
      umg.setProp(label.id, 'text', 'SHIELD 87%');
      umg.setProp(bar.id, 'value', 0.87);
      await settle(6);
      await rec.hold(const Duration(seconds: 1));
      expect(umg.document.findNode(dial.id)!.props['texture'], textureAsset.relativePath);

      // Anchor the bar to the bottom-left through the real preset button.
      umg.select(bar.id);
      await settle(6);
      final anchorButton = find.byKey(const ValueKey('umg_anchor_bottomLeft'));
      await tester.ensureVisible(anchorButton);
      await settle(6);
      await tester.tap(anchorButton);
      await settle(8);
      await rec.hold(const Duration(seconds: 1));
      expect(umg.document.findNode(bar.id)!.slot.anchorMin, UmgAnchorPreset.bottomLeft.min);
      expect(umg.document.findNode(bar.id)!.slot.anchorMax, UmgAnchorPreset.bottomLeft.max);

      final designerPng = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
      SmokeArtifacts.saveScreenshot('umg_editor_designer', designerPng);

      // Resolution simulator: the anchored bar must follow the corner as the
      // design surface changes shape. Each step is held on video.
      Future<void> grabFrame() => rec.hold(const Duration(seconds: 1));

      Rect barRect() => tester.getRect(find.byKey(ValueKey('umg_canvas_child_${bar.id}')));
      /// The gap between the bar's bottom edge and the design surface's bottom
      /// edge, measured in the simulated frame's own logical pixels.
      double bottomGapLogical() {
        final surface = tester.getRect(find.byKey(const ValueKey('umg_canvas_surface')));
        final scale = surface.height / umg.logicalSize.height;
        return (surface.bottom - barRect().bottom) / scale;
      }

      final wideRect = barRect();
      final wideGap = bottomGapLogical();
      for (final preset in UmgResolution.presets) {
        // The preset already showing changes nothing on screen.
        if (preset == umg.resolution) continue;
        umg.setResolution(preset);
        await settle(10);
        await grabFrame();
      }
      expect(umg.resolution, UmgResolution.presets.last, reason: 'the phone preset is the last step');
      final phoneRect = barRect();
      expect(bottomGapLogical(), closeTo(wideGap, 1.5),
          reason: 'a bottom-anchored element keeps its distance from the bottom edge at 393x852');
      expect(phoneRect.width, greaterThan(0));
      expect(wideRect.width, greaterThan(0));
      final surfaceNow = tester.getRect(find.byKey(const ValueKey('umg_canvas_surface')));
      expect(surfaceNow.width / surfaceNow.height, closeTo(393 / 852, 0.02),
          reason: 'the design surface took the phone aspect ratio');
      umg.setResolution(UmgResolution.presets.first);
      await settle(8);
      await rec.hold(const Duration(seconds: 1));

      // Save + Compile through the real toolbar buttons.
      expect(umg.isDirty, isTrue);
      await tester.tap(find.byKey(const ValueKey('umg_save')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
      await settle(12);
      expect(umg.isDirty, isFalse, reason: 'Save cleared the dirty flag');
      await rec.hold(const Duration(milliseconds: 800));

      await tester.tap(find.byKey(const ValueKey('umg_compile')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 600)));
      await settle(12);
      expect(umg.compileError, isNull, reason: 'compile must not fail');
      final compile = umg.lastCompile;
      expect(compile, isNotNull);

      final compiledPng = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
      SmokeArtifacts.saveScreenshot('umg_editor_compiled', compiledPng);
      await rec.hold(const Duration(seconds: 1));
      rec.save('UMG Smoke: palette drops + anchors + resolution simulator round-trip through the .lmas and real codegen');

      // The `.lmas` on disk carries the tree the designer built.
      final lmasFile = File(widgetAsset.lmasPath!);
      final reopened = LuminaAsset.fromBytes(lmasFile.readAsBytesSync());
      final doc = UmgDocument.fromJson(jsonDecode(utf8.decode(reopened.rawPayload!)) as Map<String, dynamic>);
      expect(doc.root.children.map((n) => n.type), containsAll(<UmgWidgetType>[
        UmgWidgetType.progressBar,
        UmgWidgetType.text,
        UmgWidgetType.image,
      ]));
      final savedBar = doc.root.children.firstWhere((n) => n.type == UmgWidgetType.progressBar);
      expect(savedBar.slot.anchorMin, UmgAnchorPreset.bottomLeft.min);
      expect(savedBar.props['value'], closeTo(0.87, 1e-9));
      final savedImage = doc.root.children.firstWhere((n) => n.type == UmgWidgetType.image);
      expect(savedImage.props['texture'], textureAsset.relativePath);
      expect(reopened.references.any((r) => r.assetPath == textureAsset.relativePath), isTrue,
          reason: 'the bound texture is recorded as a real asset reference');

      // The generated Flutter widget is real source in the project.
      final generated = File(compile!.filePath);
      expect(generated.existsSync(), isTrue, reason: 'compile wrote ${compile.filePath}');
      expect(generated.path.endsWith('lib/widgets/wbp_player_hud.dart'), isTrue, reason: compile.filePath);
      final source2 = generated.readAsStringSync();
      expect(source2, contains('class ${umg.className}'));
      expect(source2, contains('Progress('));
      expect(source2, contains('SHIELD 87%'));
      expect(source2, contains('Image.memory'));
      expect(source2, contains('BEGIN USER CODE'), reason: 'guarded regions survive regeneration');
    } finally {
      if (tempProjectsDir.existsSync()) tempProjectsDir.deleteSync(recursive: true);
    }
  });

  testWidgets('UMG Smoke: a plain-Flutter project designs a menu that compiles, then switches to shadcn_flutter in Project Settings', (tester) async {
    const name = 'umg widget library: plain Flutter then shadcn_flutter';
    final tempProjectsDir = Directory.systemTemp.createTempSync('lumina_smoke_umg_lib_');
    final tempConfigDir = Directory.systemTemp.createTempSync('lumina_smoke_umg_lib_cfg_');
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    Future<void> settle([int frames = 20]) async {
      for (var i = 0; i < frames; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
      }
    }

    SmokeRecorder? rec;
    // Long waits (flutter create, pub get) are recorded as a time-lapse: a
    // frame a second.
    Future<bool> pumpUntil(bool Function() done, {int seconds = 300}) async {
      final deadline = DateTime.now().add(Duration(seconds: seconds));
      final sinceFrame = Stopwatch()..start();
      while (DateTime.now().isBefore(deadline)) {
        if (done()) return true;
        await settle(6);
        if (rec != null && sinceFrame.elapsedMilliseconds >= 1000) {
          await rec.capture();
          sinceFrame.reset();
        }
      }
      return done();
    }

    Future<ProcessResult> analyze(String dir) => tester.runAsync(() => Process.run('dart', ['analyze', 'lib'], workingDirectory: dir)).then((r) => r!);

    try {
      // 1. Launcher: New Project, Blank 3D, "Plain Flutter widgets", Create (real flutter create + pub get).
      final boundaryKey = GlobalKey();
      useSharedEditor(tempConfigDir);
      final launcher = LauncherViewModel(configDir: tempConfigDir);
      await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: ShadcnApp(theme: luminaEditorTheme(), home: LauncherView(viewModel: launcher)),
      ));
      await settle(30);
      rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      await rec.hold(const Duration(seconds: 1));
      final newProject = find.text('New Project...').evaluate().isNotEmpty ? find.text('New Project...').last : find.text('Create New Project').last;
      await tester.tap(newProject);
      await settle();
      await rec.hold(const Duration(seconds: 1));
      await tester.enterText(find.widgetWithText(TextField, 'my_lumina_game'), 'ui_lib_game');
      await settle(6);
      await tester.enterText(find.byType(TextField).last, tempProjectsDir.path);
      await settle(6);
      final plainTile = find.byKey(const ValueKey('create_project_widget_library_flutter'));
      await tester.ensureVisible(plainTile);
      await settle(6);
      await tester.tap(find.text('Plain Flutter widgets'));
      await settle(6);
      await rec.hold(const Duration(seconds: 1));
      await tester.tap(find.text('Create Project'));
      await settle(6);
      expect(await pumpUntil(() => find.byType(ViewportWidget).evaluate().isNotEmpty, seconds: 420), isTrue, reason: 'the project did not open');
      await settle(30);
      await rec.hold(const Duration(seconds: 1));
      final vm = tester.widget<ViewportWidget>(find.byType(ViewportWidget)).viewModel;
      final projDir = vm.projectDirPath;
      expect(vm.project.ui.widgetLibrary, kUmgWidgetLibraryFlutter);
      expect(File('$projDir/pubspec.yaml').readAsStringSync(), isNot(contains('shadcn_flutter')));

      // 2. Design a pause menu: button, slider, check box, progress bar.
      await tester.runAsync(() => AssetRepository().createAsset(projectPath: projDir, subFolder: 'widgets', fileName: 'WBP_PauseMenu.lmas', type: AssetType.widget));
      vm.refreshAssets();
      final widgetAsset = vm.realAssets.firstWhere((a) => a.fileName == 'WBP_PauseMenu.lmas');
      vm.openSubEditorTab('WIDGET', asset: widgetAsset);
      await settle(20);
      UmgEditorViewModel umgVm() => (tester.state(find.byType(UMGWidgetSubEditor)) as dynamic).viewModelForTest as UmgEditorViewModel;
      var umg = umgVm();
      expect(umg.widgetLibrary, kUmgWidgetLibraryFlutter);
      final root = umg.document.root.id;
      await rec.hold(const Duration(seconds: 1));
      umg.addWidget(UmgWidgetType.button, parentId: root, canvasPosition: const Offset(760, 420));
      await settle(4);
      await rec.hold(const Duration(milliseconds: 600));
      umg.addWidget(UmgWidgetType.slider, parentId: root, canvasPosition: const Offset(760, 500));
      await settle(4);
      await rec.hold(const Duration(milliseconds: 600));
      umg.addWidget(UmgWidgetType.checkBox, parentId: root, canvasPosition: const Offset(760, 560));
      await settle(4);
      await rec.hold(const Duration(milliseconds: 600));
      umg.addWidget(UmgWidgetType.progressBar, parentId: root, canvasPosition: const Offset(760, 620));
      await settle(10);
      await rec.hold(const Duration(seconds: 1));
      final plainPng = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
      final compiled = await tester.runAsync(umg.compile);
      await settle(6);
      final widgetFile = File('$projDir/lib/widgets/wbp_pause_menu.dart');
      expect(compiled!.written, isTrue);
      expect(widgetFile.readAsStringSync(), contains('LuminaUmgButton('));
      expect(widgetFile.readAsStringSync(), isNot(contains('shadcn')));
      final plainAnalysis = await analyze(projDir);
      expect(plainAnalysis.exitCode, 0, reason: '${plainAnalysis.stdout}${plainAnalysis.stderr}');

      // 3. Project Settings > User Interface > shadcn_flutter > Apply & Save (real flutter pub get).
      vm.commands.execute('edit.projectSettings');
      await settle(20);
      final settings = (tester.state(find.byType(ProjectSettingsSubEditor)) as dynamic).viewModelForTest;
      await rec.hold(const Duration(seconds: 1));
      await tester.tap(find.text('User Interface'));
      await settle(10);
      await rec.hold(const Duration(seconds: 1));
      settings.setWidgetLibrary(kUmgWidgetLibraryShadcn);
      await settle(6);
      await rec.hold(const Duration(seconds: 1));
      await tester.tap(find.byKey(const ValueKey('project_settings_apply')));
      await settle(6);
      expect(await pumpUntil(() => settings.widgetLibraryStatus?.toString().startsWith('Widget library set') == true || settings.widgetLibraryError != null, seconds: 240), isTrue);
      expect(settings.widgetLibraryError, isNull);
      await settle(10);
      await rec.hold(const Duration(milliseconds: 1500));
      expect(File('$projDir/pubspec.yaml').readAsStringSync(), contains('shadcn_flutter: $kGameShadcnFlutterVersion'));
      expect(widgetFile.readAsStringSync(), contains("import 'package:shadcn_flutter/shadcn_flutter.dart';"));
      expect(await pumpUntil(() => File('$projDir/lib/main.dart').readAsStringSync().contains('shadcn.ShadcnLayer('), seconds: 30), isTrue,
          reason: 'the launcher regenerates with the shadcn wrap');
      final shadcnAnalysis = await analyze(projDir);
      expect(shadcnAnalysis.exitCode, 0, reason: '${shadcnAnalysis.stdout}${shadcnAnalysis.stderr}');

      // 4. Reopen the widget: the designer previews shadcn now.
      vm.openSubEditorTab('WIDGET', asset: widgetAsset);
      await settle(20);
      umg = umgVm();
      final shadcnPng = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
      SmokeArtifacts.saveScreenshot('$name 01 plain', plainPng);
      SmokeArtifacts.saveScreenshot(name, shadcnPng);
      await rec.hold(const Duration(seconds: 2));
      rec.save('UMG Smoke: a plain-Flutter project designs a menu that compiles, then switches to shadcn_flutter in Project Settings');
    } finally {
      if (tempProjectsDir.existsSync()) tempProjectsDir.deleteSync(recursive: true);
      if (tempConfigDir.existsSync()) tempConfigDir.deleteSync(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 15)));

  testWidgets('UMG Smoke: Widget Blueprints made from the Content Browser open the widget designer, not the 3D Blueprint editor', (tester) async {
    final tempProjectsDir = Directory.systemTemp.createTempSync('lumina_smoke_wbp_');
    final pDir = Directory('${tempProjectsDir.path}/SmokeWbp')..createSync(recursive: true);
    const project = LuminaProject(projectName: 'SmokeWbp', activeLevel: 'contents/levels/L_Main.lmas');
    File('${pDir.path}/SmokeWbp.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    try {
      final vm = EditorViewModel(initialProject: project, projectLocation: tempProjectsDir.path);
      await tester.runAsync(() => vm.ensureDefaultLevelAssets());

      // What the old code wrote for a LuminaWidget parent: an actor Blueprint.
      final legacyDoc = BlueprintEditorViewModel.createDefaultDocument('WBP_Legacy', parentClass: 'LuminaWidget').toFormattedJson();
      Directory('${pDir.path}/contents/blueprints').createSync(recursive: true);
      File('${pDir.path}/contents/blueprints/WBP_Legacy.lmas').writeAsBytesSync(LuminaAsset(
        assetId: 'WBP_Legacy',
        name: 'WBP_Legacy',
        type: AssetType.actor,
        rawPayload: Uint8List.fromList(utf8.encode(legacyDoc)),
        rawMatSource: legacyDoc,
        metadata: const {'parent_class': 'LuminaWidget'},
      ).toProtoBufferBytes());
      vm.refreshAssets();

      tester.view.physicalSize = const Size(1920, 1200);
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

      Future<void> settle([int frames = 20]) async {
        for (var i = 0; i < frames; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
        }
      }

      await settle(30);
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      await rec.hold(const Duration(seconds: 1));

      // The grid lists the selected folder only. Walk
      // into [folder] from the root through its folder tiles, as a user does.
      Future<void> enterFolder(String folder) async {
        await tester.tap(find.descendant(
            of: find.byKey(const ValueKey('content_browser_breadcrumb')), matching: find.text('contents')));
        await settle(6);
        var path = 'contents';
        for (final part in folder.split('/').skip(1)) {
          path = '$path/$part';
          final tile = find.byKey(ValueKey('folder_tile_$path'));
          await tester.tap(tile);
          await tester.pump(const Duration(milliseconds: 60));
          await tester.tap(tile);
          await settle(10);
          expect(vm.selectedFolder, path);
        }
      }

      // A real double-click on a Content Browser tile.
      Future<void> doubleClick(String label) async {
        final tile = find.text(label).first;
        await tester.tap(tile);
        await tester.pump();
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 90)));
        await tester.tap(tile);
        await settle(20);
      }

      Future<void> expectWidgetDesigner(String name) async {
        for (var i = 0; i < 100 && find.byType(UMGWidgetSubEditor).evaluate().isEmpty; i++) {
          await settle(2);
        }
        expect(find.byType(UMGWidgetSubEditor), findsOneWidget, reason: '$name did not open in the widget designer');
        expect(find.byType(BlueprintSubEditor), findsNothing, reason: '$name opened the actor Blueprint editor');
        expect(find.text('3D Viewport'), findsNothing);
        await rec.hold(const Duration(milliseconds: 1500));
      }

      Future<void> backToLevel() async {
        vm.selectTab(0);
        await settle(10);
        await rec.hold(const Duration(milliseconds: 500));
      }

      // 1. The user's own flow: New Asset → Blueprint → parent LuminaWidget.
      await tester.tap(find.text('New Asset').first);
      await settle(10);
      await rec.hold(const Duration(milliseconds: 700));
      await tester.tap(find.text('New Blueprint / Actor (.lmas)'));
      await settle(10);
      await tester.enterText(find.widgetWithText(TextField, 'BP_NewBlueprint'), 'WBP_Menu');
      // The class list builds lazily; search for the class as a user would.
      await tester.enterText(find.widgetWithText(TextField, 'Search classes...'), 'Widget');
      await settle(6);
      await tester.tap(find.text('LuminaWidget').first);
      await settle(6);
      await rec.hold(const Duration(milliseconds: 900));
      await tester.tap(find.text('Create Blueprint'));
      await settle(20);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await settle(10);
      final menuFile = File('${pDir.path}/contents/widgets/WBP_Menu.lmas');
      expect(menuFile.existsSync(), isTrue, reason: 'the LuminaWidget parent must make a Widget Blueprint');
      expect(LuminaAsset.fromBytes(menuFile.readAsBytesSync()).type, AssetType.widget);
      await rec.hold(const Duration(milliseconds: 800));
      await enterFolder('contents/widgets');
      await doubleClick('WBP_Menu');
      await expectWidgetDesigner('WBP_Menu');
      final designerPng = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
      SmokeArtifacts.saveScreenshot('umg_editor_widget_blueprint_from_parent_class', designerPng);
      await backToLevel();

      // 2. New Asset → User Interface → Widget Blueprint.
      await tester.tap(find.text('New Asset').first);
      await settle(10);
      await rec.hold(const Duration(milliseconds: 700));
      await tester.tap(find.text('User Interface → Widget Blueprint (.lmas)'));
      await settle(20);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await settle(10);
      expect(File('${pDir.path}/contents/widgets/WBP_NewWidget.lmas').existsSync(), isTrue);
      await rec.hold(const Duration(milliseconds: 800));
      await enterFolder('contents/widgets');
      await doubleClick('WBP_NewWidget');
      await expectWidgetDesigner('WBP_NewWidget');
      await backToLevel();

      // 3. A Widget Blueprint the old code wrote as an actor opens the designer.
      await enterFolder('contents/blueprints');
      await doubleClick('WBP_Legacy');
      await expectWidgetDesigner('WBP_Legacy');
      final legacyPng = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
      SmokeArtifacts.saveScreenshot('umg_editor_legacy_widget_blueprint', legacyPng);
      await rec.hold(const Duration(seconds: 2));
      rec.save('UMG Smoke: Widget Blueprints made from the Content Browser open the widget designer, not the 3D Blueprint editor');
    } finally {
      if (tempProjectsDir.existsSync()) tempProjectsDir.deleteSync(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 10)));

  testWidgets('UMG Smoke: text shadow and outline', (tester) async {
    const name = 'UMG Smoke: text shadow and outline';
    final tempProjectsDir = Directory.systemTemp.createTempSync('lumina_smoke_umg_shadow_');
    final pDir = Directory('${tempProjectsDir.path}/SmokeTitle')..createSync(recursive: true);
    const project = LuminaProject(projectName: 'SmokeTitle', activeLevel: 'contents/levels/L_Main.lmas');
    File('${pDir.path}/SmokeTitle.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    try {
      final vm = EditorViewModel(initialProject: project, projectLocation: tempProjectsDir.path);
      await tester.runAsync(() => vm.ensureDefaultLevelAssets());
      await tester.runAsync(() => AssetRepository().createAsset(projectPath: pDir.path, subFolder: 'widgets', fileName: 'WBP_Title.lmas', type: AssetType.widget));
      vm.refreshAssets();
      final widgetAsset = vm.realAssets.firstWhere((a) => a.fileName == 'WBP_Title.lmas');

      tester.view.physicalSize = const Size(1920, 1200);
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
      Future<void> settle([int frames = 20]) async {
        for (var i = 0; i < frames; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
        }
      }

      await settle(30);
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      await rec.hold(const Duration(seconds: 1));
      vm.openSubEditorTab('WIDGET', asset: widgetAsset);
      await settle(20);
      final umg = (tester.state(find.byType(UMGWidgetSubEditor)) as dynamic).viewModelForTest as UmgEditorViewModel;
      final root = umg.document.root.id;

      // A big title and a button, both text-bearing.
      final title = umg.addWidget(UmgWidgetType.text, parentId: root, canvasPosition: const Offset(560, 300))!;
      umg.setCanvasSize(title.id, const Size(800, 140));
      umg.setProp(title.id, 'text', 'LUMINA');
      umg.setProp(title.id, 'fontSize', 110.0);
      umg.setProp(title.id, 'color', '#FFD166');
      final play = umg.addWidget(UmgWidgetType.button, parentId: root, canvasPosition: const Offset(840, 560))!;
      umg.setCanvasSize(play.id, const Size(240, 64));
      umg.setProp(play.id, 'label', 'PLAY');
      umg.setProp(play.id, 'fontSize', 28.0);
      umg.select(title.id);
      await settle(10);
      await rec.hold(const Duration(milliseconds: 1500));

      // Inspector: Shadow Enabled, colour with alpha, offset, blur.
      final enabled = find.byKey(ValueKey('umg_shadow_enabled_${title.id}'));
      await tester.ensureVisible(enabled);
      await settle(6);
      await rec.hold(const Duration(milliseconds: 800));
      await tester.tap(enabled);
      await settle(6);
      await rec.hold(const Duration(milliseconds: 1000));
      final shadowColor = find.descendant(of: find.byKey(ValueKey('umg_prop_shadowColor_${title.id}')), matching: find.byType(TextField));
      await tester.tap(shadowColor);
      await tester.enterText(shadowColor, '#000000CC');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(6);
      await rec.hold(const Duration(milliseconds: 1000));
      ScrubNumericField scrub(String key) => tester.widget<ScrubNumericField>(find.byKey(ValueKey(key)));
      for (var i = 1; i <= 8; i++) {
        // The offset scrubbed out step by step, as a drag would.
        scrub('umg_prop_shadowOffsetX_${title.id}').onChanged(i.toDouble());
        scrub('umg_prop_shadowOffsetY_${title.id}').onChanged(i.toDouble());
        await settle(2);
        await rec.capture();
      }
      scrub('umg_prop_shadowOffsetX_${title.id}').onCommit(8);
      scrub('umg_prop_shadowOffsetY_${title.id}').onCommit(8);
      tester.widget<SliderField>(find.byKey(ValueKey('umg_prop_shadowBlur_${title.id}'))).onCommit(6);
      await settle(6);
      await rec.hold(const Duration(milliseconds: 1200));

      // Outline: size and colour.
      tester.widget<SliderField>(find.byKey(ValueKey('umg_prop_outlineSize_${title.id}'))).onCommit(4);
      await settle(4);
      final outlineColor = find.descendant(of: find.byKey(ValueKey('umg_prop_outlineColor_${title.id}')), matching: find.byType(TextField));
      await tester.ensureVisible(outlineColor);
      await tester.tap(outlineColor);
      await tester.enterText(outlineColor, '#7C3AEDFF');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(6);
      await rec.hold(const Duration(milliseconds: 1500));

      // The button label gets a soft shadow too.
      for (final e in {'shadowEnabled': true, 'shadowColor': '#000000B3', 'shadowOffsetX': 2.0, 'shadowOffsetY': 3.0, 'shadowBlur': 3.0}.entries) {
        umg.setProp(play.id, e.key, e.value);
      }
      umg.select(null);
      await settle(10);
      await rec.hold(const Duration(milliseconds: 1500));

      final layers = tester
          .widgetList<Text>(find.descendant(of: find.byKey(ValueKey('umg_rt_${title.id}')), matching: find.text('LUMINA')))
          .toList();
      expect(layers, hasLength(2), reason: 'the outline is a stroked layer under the fill');
      expect(layers.first.style!.foreground!.strokeWidth, 8.0);
      // Paint keeps its colour as floats: compare the 8-bit value.
      expect(layers.first.style!.foreground!.color.toARGB32(), 0xFF7C3AED);
      expect(layers.first.style!.shadows, [const Shadow(color: Color(0xCC000000), offset: Offset(8, 8), blurRadius: 6)]);
      expect(layers.last.style!.color, const Color(0xFFFFD166));
      final playText = tester.widget<Text>(find.descendant(of: find.byKey(ValueKey('umg_rt_${play.id}')), matching: find.text('PLAY')));
      expect(playText.style!.shadows!.single.offset, const Offset(2, 3));

      final png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
      SmokeArtifacts.saveScreenshot(name, png);

      // Saved in the .lmas, emitted by the codegen.
      expect(await tester.runAsync(umg.save), isTrue);
      final saved = UmgDocument.fromJson(Map<String, dynamic>.from(jsonDecode(utf8.decode(
          LuminaAsset.fromBytes(File('${pDir.path}/contents/widgets/WBP_Title.lmas').readAsBytesSync()).rawPayload!)) as Map));
      final savedTitle = saved.findNode(title.id)!.props;
      expect([savedTitle['shadowEnabled'], savedTitle['shadowColor'], savedTitle['shadowOffsetX'], savedTitle['shadowBlur']], [true, '#000000CC', 8.0, 6.0]);
      expect([savedTitle['outlineSize'], savedTitle['outlineColor']], [4.0, '#7C3AEDFF']);
      final compiled = await tester.runAsync(umg.compile);
      await settle(6);
      expect(compiled!.source, contains('const LuminaUmgTextShadow(enabled: true, color: Color(0xCC000000), offsetX: 8.0, offsetY: 8.0, blur: 6.0)'));
      expect(compiled.source, contains('const LuminaUmgTextOutline(size: 4.0, color: Color(0xFF7C3AED))'));
      await rec.hold(const Duration(seconds: 2));
      rec.save(name);
    } finally {
      if (tempProjectsDir.existsSync()) tempProjectsDir.deleteSync(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 10)));

  testWidgets('UMG Smoke: container and shadcn components', (tester) async {
    const name = 'UMG Smoke: container and shadcn components';
    final tempProjectsDir = Directory.systemTemp.createTempSync('lumina_smoke_umg_container_');
    final pDir = Directory('${tempProjectsDir.path}/SmokeHudKit')..createSync(recursive: true);
    const project = LuminaProject(projectName: 'SmokeHudKit', activeLevel: 'contents/levels/L_Main.lmas');
    File('${pDir.path}/SmokeHudKit.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    try {
      final vm = EditorViewModel(initialProject: project, projectLocation: tempProjectsDir.path);
      await tester.runAsync(() => vm.ensureDefaultLevelAssets());
      await tester.runAsync(() => AssetRepository().createAsset(projectPath: pDir.path, subFolder: 'widgets', fileName: 'WBP_Hud.lmas', type: AssetType.widget));
      vm.refreshAssets();
      final widgetAsset = vm.realAssets.firstWhere((a) => a.fileName == 'WBP_Hud.lmas');

      tester.view.physicalSize = const Size(1920, 1200);
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
      Future<void> settle([int frames = 20]) async {
        for (var i = 0; i < frames; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
        }
      }

      await settle(30);
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      await rec.hold(const Duration(seconds: 1));
      vm.openSubEditorTab('WIDGET', asset: widgetAsset);
      await settle(20);
      final umg = (tester.state(find.byType(UMGWidgetSubEditor)) as dynamic).viewModelForTest as UmgEditorViewModel;
      expect(umg.widgetLibrary, kUmgWidgetLibraryShadcn);
      expect(find.byKey(const ValueKey('umg_palette_category_shadcn')), findsOneWidget);
      final root = umg.document.root.id;
      await rec.hold(const Duration(milliseconds: 800));

      // A styled Container panel: gradient, rounded border, drop shadow, padding.
      final panel = umg.addWidget(UmgWidgetType.container, parentId: root, canvasPosition: const Offset(520, 180))!;
      umg.setCanvasSize(panel.id, const Size(880, 560));
      umg.select(panel.id);
      await settle(6);
      await rec.hold(const Duration(milliseconds: 800));
      for (final e in <String, Object?>{
        'backgroundColor': '#1E1E2AFF',
        'gradient': {'type': 'linear', 'colors': ['#2A1A40FF', '#101018FF'], 'begin': 'topLeft', 'end': 'bottomRight'},
        'borderColor': '#FB7C01FF',
        'borderWidth': 2.0,
        'cornerRadius': 16.0,
        'padding': [24.0, 24.0, 24.0, 24.0],
        'shadows': [
          {'color': '#000000AA', 'offsetX': 0.0, 'offsetY': 8.0, 'blur': 24.0, 'spread': 0.0},
        ],
      }.entries) {
        umg.setProp(panel.id, e.key, e.value);
        await settle(3);
        await rec.capture();
        await rec.hold(const Duration(milliseconds: 400));
      }
      // A vertical box inside, holding shadcn components.
      final column = umg.addWidget(UmgWidgetType.verticalBox, parentId: panel.id)!;
      await settle(4);
      final card = umg.addWidget(UmgWidgetType.shadcnCard, parentId: column.id)!;
      umg.setProp(card.id, 'title', 'Mission');
      umg.setProp(card.id, 'description', 'Reach the extraction point before dawn.');
      final cardText = umg.addWidget(UmgWidgetType.shadcnBadge, parentId: card.id)!;
      umg.setProp(cardText.id, 'text', 'Priority');
      await settle(4);
      await rec.hold(const Duration(milliseconds: 800));
      final progress = umg.addWidget(UmgWidgetType.shadcnProgress, parentId: column.id)!;
      umg.setProp(progress.id, 'percent', 0.72);
      await settle(4);
      await rec.hold(const Duration(milliseconds: 800));
      final sw = umg.addWidget(UmgWidgetType.shadcnSwitch, parentId: column.id)!;
      umg.setProp(sw.id, 'label', 'Night Vision');
      umg.setProp(sw.id, 'checked', true);
      await settle(4);
      await rec.hold(const Duration(milliseconds: 800));
      // The loading placeholder pulses while the recording runs.
      final skeleton = umg.addWidget(UmgWidgetType.shadcnSkeleton, parentId: column.id)!;
      umg.setProp(skeleton.id, 'lines', 2);
      await settle(4);
      await rec.hold(const Duration(milliseconds: 800));
      final button = umg.addWidget(UmgWidgetType.shadcnPrimaryButton, parentId: column.id)!;
      umg.setProp(button.id, 'label', 'Deploy');
      umg.select(null);
      await settle(10);
      await rec.hold(const Duration(milliseconds: 1500));

      Finder inNode(UmgNode n, Type t) => find.descendant(of: find.byKey(ValueKey('umg_rt_${n.id}')), matching: find.byType(t));
      final decoration = tester.widget<Container>(find.descendant(of: find.byType(LuminaUmgContainer), matching: find.byType(Container)).first).decoration! as BoxDecoration;
      expect(decoration.gradient, isA<LinearGradient>());
      expect(decoration.borderRadius, BorderRadius.circular(16));
      expect(decoration.boxShadow!.single.blurRadius, 24);
      expect(inNode(card, Card), findsOneWidget);
      expect(inNode(progress, Progress), findsOneWidget);
      expect(inNode(sw, Switch), findsOneWidget);
      expect(inNode(button, PrimaryButton), findsOneWidget);
      expect(inNode(skeleton, LuminaUmgSkeleton), findsOneWidget);

      final png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
      SmokeArtifacts.saveScreenshot(name, png);

      final compiled = await tester.runAsync(umg.compile);
      await settle(6);
      expect(compiled!.written, isTrue);
      expect(compiled.source, contains('LuminaUmgContainer('));
      expect(compiled.source, contains('Card('));
      expect(compiled.source, contains('Progress('));
      expect(compiled.source, contains('Switch('));
      expect(compiled.source, contains('LuminaUmgSkeleton('));
      await rec.hold(const Duration(seconds: 2));
      rec.save(name);
    } finally {
      if (tempProjectsDir.existsSync()) tempProjectsDir.deleteSync(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 10)));
}

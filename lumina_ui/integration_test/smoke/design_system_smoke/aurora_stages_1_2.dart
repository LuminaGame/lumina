part of '../design_system_smoke_test.dart';

/// Stages 1 and 2 of the Aurora design language: tokens and chrome, islands and the Content Drawer.
void _auroraStages12Scenarios(IntegrationTestWidgetsFlutterBinding binding) {
  // Stage 1 of the Aurora design language on the real editor: the Obsidian
  // tokens, Manrope and JetBrains Mono, the 48 px Prism L menu bar and the
  // typed workspace tabs. A barrel and the mannequin are imported through
  // the real pipeline; the Static Mesh and Skeletal Mesh editors open as
  // typed tabs (cyan and magenta), the tab switches are on video with the
  // viewport orbiting between them.
  testWidgets('Design System Smoke: aurora design language', (WidgetTester tester) async {
    const String testName = 'Design System Smoke: aurora design language';
    final Directory tempDir = Directory.systemTemp.createTempSync('design_system_aurora_smoke_');
    final Directory pDir = Directory('${tempDir.path}/AuroraSmoke')..createSync(recursive: true);
    Directory('${pDir.path}/contents/levels').createSync(recursive: true);
    File('${pDir.path}/AuroraSmoke.lmproject').writeAsStringSync('{}');
    addTearDown(() => deleteTempProject(tempDir));
    final String barrel = '${SmokeArtifacts.testAssetsDir.path}/Props/Barrels/fuel_barrel_red.glb';
    final String manny = '${SmokeArtifacts.testAssetsDir.path}/mannequin/SKM_Manny_Simple.glb';
    final List<String> usedAssets = <String>[barrel, manny];
    expect(File(barrel).existsSync(), isTrue, reason: 'the smoke loads real models from test-assets/');

    final EditorViewModel vm = EditorViewModel(
      initialProject: LuminaProject(
        projectName: 'AuroraSmoke',
        activeLevel: 'contents/levels/L_Main.lmas',
        settings: EngineScalabilitySettings(targetFps: 60),
      ),
      projectLocation: tempDir.path,
    );
    addTearDown(vm.dispose);
    await tester.runAsync(() => vm.ensureDefaultLevelAssets());
    await tester.runAsync(() => vm.processImportPipeline(sourceFilePath: barrel));
    await tester.runAsync(() => vm.processImportPipeline(sourceFilePath: manny));
    vm.refreshAssets();
    final RealAssetInfo barrelAsset = vm.realAssets.firstWhere((a) => a.type == AssetType.filamesh && a.fileName.startsWith('fuel_barrel'));
    final RealAssetInfo mannyAsset = vm.realAssets.firstWhere(
        (a) => (a.type == AssetType.filameshSk || a.type == AssetType.filamesh) && a.fileName.startsWith('SKM_Manny'));

    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final GlobalKey boundaryKey = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: boundaryKey,
      child: ShadcnApp(theme: luminaEditorTheme(), home: Scaffold(child: MainEditorView(viewModel: vm))),
    ));
    await settle(tester);
    await tester.runAsync(() => vm.spawnActorFromAsset(barrelAsset, location: [0, 0, 0]));
    await settle(tester, frames: 30);
    final SmokeRecorder rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
    await rec.hold(const Duration(seconds: 2));

    final double dpr = tester.view.devicePixelRatio;
    Uint8List crop(Uint8List png, Rect r) {
      final img.Image im = img.decodePng(png)!;
      final int x = (r.left * dpr).round().clamp(0, im.width - 1);
      final int y = (r.top * dpr).round().clamp(0, im.height - 1);
      final int w = (r.width * dpr).round().clamp(1, im.width - x);
      final int h = (r.height * dpr).round().clamp(1, im.height - y);
      return Uint8List.fromList(img.encodePng(img.copyCrop(im, x: x, y: y, width: w, height: h)));
    }
    final StringBuffer report = StringBuffer('MEASURE aurora stage 1:\n');
    final List<String> failures = <String>[];
    void measure(String name, Uint8List png, Rect r, Color expected) {
      final ({int rgb, int count, int total}) d = dominantColorIn(png, r, dpr: dpr);
      final int want = expected.toARGB32() & 0xFFFFFF;
      report.writeln('  $name: ${hex(d.rgb)} on ${d.count}/${d.total} px (expected ${hex(want)})');
      if (d.rgb != want) failures.add('$name is ${hex(d.rgb)}, expected ${hex(want)}');
    }

    // 1. The menu bar: 48 px on the rail, lockup, menus, command field, chip, window controls.
    Uint8List png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
    // The bar itself: under it the widget may carry the source-control or
    // units banner.
    final Rect barRect = tester.getRect(find.byKey(const ValueKey<String>('window_title_drag_area')));
    final Rect menuRow = Rect.fromLTWH(0, barRect.top, tester.getRect(find.byType(MenuBarWidget).first).width, MenuBarWidget.height);
    expect(barRect.height, closeTo(MenuBarWidget.height - 1, 0.5), reason: 'the 48 px row (its last pixel is the border)');
    final Rect field = tester.getRect(find.byKey(const ValueKey<String>('menu_bar_command_field')));
    measure('menu bar rail', png, Rect.fromLTWH(field.left - 90, menuRow.top + 4, 60, 40), EditorColors.rail);
    measure('command field', png, Rect.fromLTWH(field.left + 160, field.top + 4, 30, field.height - 8), EditorColors.card);
    final Rect chip = tester.getRect(find.byKey(const ValueKey<String>('menu_bar_project_chip')));
    measure('project chip', png, Rect.fromLTWH(chip.left + 2, chip.top + 2, 4, chip.height - 4), EditorColors.sidebar);
    SmokeArtifacts.saveScreenshot('$testName — menu bar', crop(png, menuRow), usedAssets: usedAssets);

    // 2. The typed tab strip with the level tab.
    final Rect strip = tester.getRect(find.byType(EditorTypedTabBar));
    final Rect levelTab = tester.getRect(find.byKey(const ValueKey<String>('workspace_tab_0')));
    measure('tab strip rail', png, Rect.fromLTWH(levelTab.right + 60, strip.top + 2, 200, strip.height - 6), EditorColors.rail);
    measure('level tab underline', png, Rect.fromLTWH(levelTab.left + 3, levelTab.bottom - 2, levelTab.width - 6, 2), EditorColors.assetTypeLevel);

    // 3. Static Mesh and Skeletal Mesh editors as typed tabs.
    vm.openSubEditorTab('Mesh', asset: barrelAsset);
    await settle(tester, frames: 40);
    expect(find.byType(StaticMeshSubEditor), findsOneWidget);
    await rec.hold(const Duration(milliseconds: 1500));
    png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
    final Rect meshTab = tester.getRect(find.byKey(const ValueKey<String>('workspace_tab_1')));
    measure('static mesh tab underline', png, Rect.fromLTWH(meshTab.left + 3, meshTab.bottom - 2, meshTab.width - 6, 2), EditorColors.assetTypeStaticMesh);
    SmokeArtifacts.saveScreenshot('$testName — typed tabs, Static Mesh editor', crop(png, Rect.fromLTWH(strip.left, menuRow.top, 900, strip.bottom - menuRow.top + 2)), usedAssets: usedAssets);

    vm.openSubEditorTab('SKELETAL', asset: mannyAsset);
    await settle(tester, frames: 40);
    expect(find.byType(SkeletalMeshSubEditor), findsOneWidget);
    await rec.hold(const Duration(milliseconds: 1500));
    png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
    final Rect skelTab = tester.getRect(find.byKey(const ValueKey<String>('workspace_tab_2')));
    measure('skeletal mesh tab underline', png, Rect.fromLTWH(skelTab.left + 3, skelTab.bottom - 2, skelTab.width - 6, 2), EditorColors.assetTypeSkeletalMesh);
    SmokeArtifacts.saveScreenshot('$testName — typed tabs, Skeletal Mesh editor', crop(png, Rect.fromLTWH(strip.left, menuRow.top, 900, strip.bottom - menuRow.top + 2)), usedAssets: usedAssets);
    SmokeArtifacts.saveScreenshot(testName, png, usedAssets: usedAssets);

    // 4. On video: back to the level, orbit, through the tabs again.
    for (final int i in <int>[0, 1, 2, 0]) {
      vm.selectTab(i);
      await settle(tester, frames: 12);
      await rec.hold(const Duration(milliseconds: 900));
      if (i == 0) {
        final Rect viewport = tester.getRect(find.byType(ViewportWidget));
        await rec.drag(viewport.center + const Offset(-120, 0), viewport.center + const Offset(120, 20), steps: 45);
        await rec.hold(const Duration(milliseconds: 600));
      }
    }
    await rec.hold(const Duration(seconds: 2));
    rec.save(testName, usedAssets: usedAssets);
    // ignore: avoid_print
    print(report);
    expect(failures, isEmpty, reason: '${failures.join('\n')}\n$report');
  }, timeout: const Timeout(Duration(minutes: 10)));

  // Stage 2 of the Aurora design language on the real editor: every docked
  // panel an island on the window's ground (island fill, 1 px border, 12 px
  // radius, 8 px gutters, the grip between stacked islands), the Outliner's
  // amber selection starting at the row's indent, and the Content Drawer: a
  // bar under the viewport whose panel slides up over it, the Output Log
  // from the same bar, and the pin that docks it. A barrel, an AC unit and a
  // banana bunch are imported and placed; the viewport orbits on video
  // while the drawer opens and closes.
  testWidgets('Design System Smoke: aurora islands and content drawer', (WidgetTester tester) async {
    const String testName = 'Design System Smoke: aurora islands and content drawer';
    final Directory tempDir = Directory.systemTemp.createTempSync('design_system_islands_smoke_');
    final Directory pDir = Directory('${tempDir.path}/IslandSmoke')..createSync(recursive: true);
    Directory('${pDir.path}/contents/levels').createSync(recursive: true);
    File('${pDir.path}/IslandSmoke.lmproject').writeAsStringSync('{}');
    addTearDown(() => deleteTempProject(tempDir));
    final List<String> usedAssets = <String>[
      for (final String rel in <String>[
        'Props/Barrels/fuel_barrel_red.glb',
        'Props/AC_units/ac_unit_a_300x300.glb',
        'Props/Banana Bunch/banana_bunch_long.glb',
      ])
        '${SmokeArtifacts.testAssetsDir.path}/$rel',
    ]..removeWhere((String path) => !File(path).existsSync());
    expect(usedAssets, isNotEmpty, reason: 'the smoke loads real models from test-assets/');

    final EditorViewModel vm = EditorViewModel(
      initialProject: LuminaProject(
        projectName: 'IslandSmoke',
        activeLevel: 'contents/levels/L_Main.lmas',
        settings: EngineScalabilitySettings(targetFps: 60),
      ),
      projectLocation: tempDir.path,
    );
    addTearDown(vm.dispose);
    await tester.runAsync(() => vm.ensureDefaultLevelAssets());
    for (final String path in usedAssets) {
      await tester.runAsync(() => vm.processImportPipeline(sourceFilePath: path));
    }
    vm.refreshAssets();
    // Unpinned: the bottom panel is the Content Drawer.
    vm.setBottomPinned(false);

    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final GlobalKey boundaryKey = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: boundaryKey,
      child: ShadcnApp(theme: luminaEditorTheme(), home: Scaffold(child: MainEditorView(viewModel: vm))),
    ));
    await settle(tester);
    double x = -150;
    for (final RealAssetInfo asset in vm.realAssets.where((RealAssetInfo a) => a.type == AssetType.filamesh)) {
      await tester.runAsync(() => vm.spawnActorFromAsset(asset, location: <double>[x, 0, 0]));
      x += 150;
    }
    await settle(tester, frames: 40);
    final SmokeRecorder rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
    await rec.hold(const Duration(seconds: 2));

    final double dpr = tester.view.devicePixelRatio;
    final StringBuffer report = StringBuffer('MEASURE aurora stage 2:\n');
    final List<String> failures = <String>[];
    void measure(String name, Uint8List png, Rect r, Color expected) {
      final ({int rgb, int count, int total}) d = dominantColorIn(png, r, dpr: dpr);
      final int want = expected.toARGB32() & 0xFFFFFF;
      report.writeln('  $name: ${hex(d.rgb)} on ${d.count}/${d.total} px (expected ${hex(want)})');
      if (d.rgb != want) failures.add('$name is ${hex(d.rgb)}, expected ${hex(want)}');
    }

    Rect island(String key) => tester.getRect(find.byKey(ValueKey<String>(key)));
    final Rect outliner = island('island_outliner');
    final Rect details = island('island_details');
    final Rect viewport = island('island_viewport');

    // 1. Islands on the ground with their gutters and the grip.
    Uint8List png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
    measure('ground in the gutter beside the Outliner', png, Rect.fromLTWH(outliner.right + 2, outliner.center.dy, 4, 40), EditorColors.background);
    measure('Outliner island fill', png, Rect.fromLTWH(outliner.left + 8, outliner.bottom - 40, outliner.width - 16, 30), EditorColors.sidebar);
    measure('Outliner island border', png, Rect.fromLTWH(outliner.left + 40, outliner.top, 60, 1), EditorColors.border);
    measure('Details island fill', png, Rect.fromLTWH(details.left + 8, details.bottom - 30, details.width - 16, 20), EditorColors.sidebar);
    measure('grip between Outliner and Details', png,
        Rect.fromLTWH(outliner.center.dx - 10, outliner.bottom + EditorIslandStyle.gripGap / 2 - 1, 20, 2), EditorColors.fieldBorder);
    // The rounded corner: the outermost corner pixel shows the ground.
    measure('rounded Outliner corner', png, Rect.fromLTWH(outliner.left, outliner.top, 2, 2), EditorColors.background);
    report.writeln('  gutters: outliner→viewport ${(viewport.left - outliner.right).toStringAsFixed(1)} px, '
        'outliner→details ${(details.top - outliner.bottom).toStringAsFixed(1)} px');
    if ((viewport.left - outliner.right - EditorIslandStyle.gap).abs() > 0.5) failures.add('the column gutter is not 8 px');
    SmokeArtifacts.saveScreenshot('$testName — islands', png, usedAssets: usedAssets);

    // 2. A selected outliner row: the amber fill starts at the row's indent.
    vm.selectActorById(vm.actors.where((EditorActorNode a) => a.type != 'Folder').last.id);
    await settle(tester, frames: 12);
    await rec.hold(const Duration(seconds: 1));
    png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
    final Finder selectedRow = find.byKey(ValueKey<String>('outliner_row_${vm.selectedActorId}'));
    final Rect row = tester.getRect(selectedRow);
    measure('selected row fill', png, Rect.fromLTWH(row.left + 40, row.top + 4, 30, row.height - 8), EditorColors.primary);
    measure('left of the selected row (its indent)', png, Rect.fromLTWH(outliner.left + 2, row.center.dy, 3, 2), EditorColors.sidebar);
    SmokeArtifacts.saveScreenshot('$testName — outliner selection at the indent',
        _cropTo(png, outliner.inflate(4), dpr), usedAssets: usedAssets);

    // 3. The Content Drawer: bar, open over the viewport, Output Log, closed.
    final Rect bar = tester.getRect(find.byKey(const ValueKey<String>('content_drawer_bar')));
    measure('drawer bar', png, Rect.fromLTWH(bar.center.dx - 40, bar.top + 4, 80, 4), EditorColors.sidebar);
    expect(bar.height, ContentDrawerBar.height);
    await tester.tap(find.byKey(const ValueKey<String>('content_drawer_toggle')));
    for (int i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await settle(tester, frames: 10);
    await rec.hold(const Duration(seconds: 1));
    final Rect panel = tester.getRect(find.byKey(const ValueKey<String>('content_drawer_panel')));
    report.writeln('  drawer panel ${panel.height.toStringAsFixed(0)} px over a ${viewport.height.toStringAsFixed(0)} px viewport island');
    if ((panel.height - ContentDrawer.height).abs() > 0.5) failures.add('the open drawer is ${panel.height} px, not 322');
    if ((island('island_viewport').height - viewport.height).abs() > 0.5) failures.add('the drawer resized the viewport island');
    expect(find.byType(ContentBrowserWidget), findsOneWidget);
    png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
    SmokeArtifacts.saveScreenshot('$testName — content drawer open', png, usedAssets: usedAssets);
    SmokeArtifacts.saveScreenshot(testName, png, usedAssets: usedAssets);

    await tester.tap(find.byKey(const ValueKey<String>('content_drawer_output_log')));
    await settle(tester, frames: 12);
    await rec.hold(const Duration(milliseconds: 1500));
    expect(vm.layoutState.isOutputLogOpen, isTrue);
    await tester.tap(find.byKey(const ValueKey<String>('content_drawer_toggle')));
    await settle(tester, frames: 12);
    await rec.hold(const Duration(milliseconds: 1000));
    await tester.tap(find.byKey(const ValueKey<String>('content_drawer_toggle')));
    await settle(tester, frames: 20);
    expect(vm.layoutState.bottomVisible, isFalse);

    // 4. On video: orbit the open viewport, open the drawer again, pin it.
    final Rect view = tester.getRect(find.byType(ViewportWidget));
    await rec.drag(view.center + const Offset(-140, -60), view.center + const Offset(140, -40), steps: 50);
    await rec.hold(const Duration(milliseconds: 600));
    await tester.tap(find.byKey(const ValueKey<String>('content_drawer_toggle')));
    await settle(tester, frames: 20);
    await rec.hold(const Duration(milliseconds: 1200));
    await tester.tap(find.byKey(const ValueKey<String>('bottom_panel_pin')));
    await settle(tester, frames: 20);
    expect(vm.layoutState.bottomPinned, isTrue);
    expect(find.byKey(const ValueKey<String>('island_bottom_panel')), findsOneWidget);
    await rec.hold(const Duration(seconds: 2));
    png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
    SmokeArtifacts.saveScreenshot('$testName — pinned bottom panel island', png, usedAssets: usedAssets);
    rec.save(testName, usedAssets: usedAssets);
    // ignore: avoid_print
    print(report);
    expect(failures, isEmpty, reason: '${failures.join('\n')}\n$report');
  }, timeout: const Timeout(Duration(minutes: 10)));
}

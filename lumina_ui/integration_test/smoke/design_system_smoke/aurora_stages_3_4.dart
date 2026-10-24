part of '../design_system_smoke_test.dart';

/// Stages 3 and 4 of the Aurora design language: the viewport chrome and the sub-editors.
void _auroraStages34Scenarios(IntegrationTestWidgetsFlutterBinding binding) {
  // Stage 3 of the Aurora design language: the viewport chrome. The level
  // viewport shows the pill row (camera, view mode, snaps, grid, World,
  // Show) with the tool column under it and the stats pill at the right;
  // the Static Mesh editor shows the same chrome with its Show menu (the
  // collision view and the bounds box). The pills drive the editor: the tool
  // column switches tools, Show toggles an overlay, the view mode pill turns
  // Wireframe on; all on video while the camera orbits.
  testWidgets('Design System Smoke: aurora viewport pills and tool column', (WidgetTester tester) async {
    const String testName = 'Design System Smoke: aurora viewport pills and tool column';
    final Directory tempDir = Directory.systemTemp.createTempSync('design_system_pills_smoke_');
    final Directory pDir = Directory('${tempDir.path}/PillSmoke')..createSync(recursive: true);
    Directory('${pDir.path}/contents/levels').createSync(recursive: true);
    File('${pDir.path}/PillSmoke.lmproject').writeAsStringSync('{}');
    addTearDown(() => deleteTempProject(tempDir));
    final String barrel = '${SmokeArtifacts.testAssetsDir.path}/Props/Barrels/fuel_barrel_red.glb';
    final String acUnit = '${SmokeArtifacts.testAssetsDir.path}/Props/AC_units/ac_unit_a_300x300.glb';
    final List<String> usedAssets = <String>[barrel, acUnit];
    expect(File(barrel).existsSync(), isTrue, reason: 'the smoke loads real models from test-assets/');

    final EditorViewModel vm = EditorViewModel(
      initialProject: LuminaProject(
        projectName: 'PillSmoke',
        activeLevel: 'contents/levels/L_Main.lmas',
        settings: EngineScalabilitySettings(targetFps: 60),
      ),
      projectLocation: tempDir.path,
    );
    addTearDown(vm.dispose);
    await tester.runAsync(() => vm.ensureDefaultLevelAssets());
    await tester.runAsync(() => vm.processImportPipeline(sourceFilePath: barrel));
    await tester.runAsync(() => vm.processImportPipeline(sourceFilePath: acUnit));
    vm.refreshAssets();
    final RealAssetInfo barrelAsset = vm.realAssets.firstWhere((a) => a.type == AssetType.filamesh && a.fileName.startsWith('fuel_barrel'));
    final RealAssetInfo acAsset = vm.realAssets.firstWhere((a) => a.type == AssetType.filamesh && a.fileName.startsWith('ac_unit'));

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
    await tester.runAsync(() => vm.spawnActorFromAsset(barrelAsset, location: <double>[-80, 0, 0]));
    await tester.runAsync(() => vm.spawnActorFromAsset(acAsset, location: <double>[80, 0, 0]));
    await settle(tester, frames: 40);
    vm.selectActorById(vm.actors.last.id);
    await settle(tester, frames: 12);
    final SmokeRecorder rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
    await rec.hold(const Duration(seconds: 2));

    final double dpr = tester.view.devicePixelRatio;
    final StringBuffer report = StringBuffer('MEASURE aurora stage 3:\n');
    final List<String> failures = <String>[];
    void measure(String name, Uint8List png, Rect r, Color expected) {
      final ({int rgb, int count, int total}) d = dominantColorIn(png, r, dpr: dpr);
      final int want = expected.toARGB32() & 0xFFFFFF;
      report.writeln('  $name: ${hex(d.rgb)} on ${d.count}/${d.total} px (expected ${hex(want)})');
      if (d.rgb != want) failures.add('$name is ${hex(d.rgb)}, expected ${hex(want)}');
    }

    // 1. The level chrome: pills, tool column, stats; the active tool amber.
    await tester.tap(find.byKey(const ValueKey<String>('viewport_tool_translate')));
    await settle(tester, frames: 12);
    expect(vm.activeTool, 'translate');
    Uint8List png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
    final Rect move = tester.getRect(find.byKey(const ValueKey<String>('viewport_tool_translate')));
    measure('active tool (Move)', png, Rect.fromLTWH(move.left + 2, move.top + 2, 6, 6), EditorColors.primary);
    final Rect camera = tester.getRect(find.byKey(const ValueKey<String>('viewport_pill_camera')));
    report.writeln('  camera pill ${camera.width.toStringAsFixed(0)}x${camera.height.toStringAsFixed(0)} at '
        '(${camera.left.toStringAsFixed(0)}, ${camera.top.toStringAsFixed(0)})');
    if ((camera.height - ViewportPillStyle.height).abs() > 0.5) failures.add('the camera pill is not 28 px tall');
    expect(find.byKey(const ValueKey<String>('viewport_stats_pill')), findsOneWidget);
    final Rect viewport = tester.getRect(find.byType(ViewportWidget));
    SmokeArtifacts.saveScreenshot('$testName — level viewport chrome', png, usedAssets: usedAssets);
    SmokeArtifacts.saveScreenshot('$testName — pill row and tool column',
        _cropTo(png, Rect.fromLTWH(viewport.left, viewport.top, 760, 260), dpr), usedAssets: usedAssets);

    // 2. The pills drive the editor: rotate tool, Show toggles Selection Bounds, Wireframe.
    await tester.tap(find.byKey(const ValueKey<String>('viewport_tool_rotate')));
    await settle(tester, frames: 12);
    expect(vm.activeTool, 'rotate');
    await rec.hold(const Duration(milliseconds: 800));
    final bool boundsBefore = vm.showFlags['Selection Bounds'] == true;
    await tester.tap(find.byKey(const ValueKey<String>('viewport_pill_show')));
    await settle(tester, frames: 30);
    await rec.hold(const Duration(milliseconds: 800));
    await tester.tap(find.text('Selection Bounds').last);
    await settle(tester, frames: 30);
    expect(vm.showFlags['Selection Bounds'] == true, !boundsBefore);
    await tester.tap(find.byKey(const ValueKey<String>('viewport_pill_view_mode')));
    await settle(tester, frames: 30);
    await tester.tap(find.text('Wireframe').last);
    await settle(tester, frames: 40);
    expect(vm.viewMode, 'Wireframe');
    await rec.hold(const Duration(seconds: 1));
    await rec.drag(viewport.center + const Offset(-160, 40), viewport.center + const Offset(160, 60), steps: 50);
    await rec.hold(const Duration(milliseconds: 600));
    await tester.tap(find.byKey(const ValueKey<String>('viewport_pill_view_mode')));
    await settle(tester, frames: 30);
    await tester.tap(find.text('Lit').last);
    await settle(tester, frames: 40);

    // 3. The Static Mesh editor: the same chrome, Show · Collision / Bounds.
    vm.openSubEditorTab('Mesh', asset: barrelAsset);
    await settle(tester, frames: 60);
    await rec.hold(const Duration(seconds: 1));
    expect(find.byKey(const ValueKey<String>('sub_viewport_shading')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('sub_viewport_show')));
    await settle(tester, frames: 30);
    await rec.hold(const Duration(milliseconds: 800));
    await tester.tap(find.byKey(const ValueKey<String>('sub_viewport_show_bounds')));
    await settle(tester, frames: 40);
    await rec.hold(const Duration(seconds: 1));
    final Rect sub = tester.getRect(find.byType(SubEditor3DViewport).first);
    await rec.drag(sub.center + const Offset(-140, 0), sub.center + const Offset(140, 20), steps: 50);
    await rec.hold(const Duration(seconds: 1));
    png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
    SmokeArtifacts.saveScreenshot('$testName — static mesh chrome with bounds', png, usedAssets: usedAssets);
    SmokeArtifacts.saveScreenshot(testName, png, usedAssets: usedAssets);
    expect(find.text('Show · 2'), findsOneWidget, reason: 'collision and bounds both on');
    await rec.hold(const Duration(seconds: 2));
    rec.save(testName, usedAssets: usedAssets);
    // ignore: avoid_print
    print(report);
    expect(failures, isEmpty, reason: '${failures.join('\n')}\n$report');
  }, timeout: const Timeout(Duration(minutes: 10)));

  // Stage 4 of the Aurora design language: the sub-editors. Every editor
  // lays its panes out as islands on the window's ground: Static Mesh (LODs
  // over the mesh stats, the viewport, the details), Skeletal Mesh (the
  // skeleton tree over the morphs), Animation (the viewport with its
  // transport bar over the dope sheet), Material, Blueprint, Sequencer, UMG,
  // Landscape, Plugins, Project Settings and Build Manager. Real models from
  // test-assets/ are imported; each editor is opened as a tab, its islands
  // and the ground between them are measured, and the viewports orbit on
  // video between the tab switches.
  testWidgets('Design System Smoke: aurora sub-editors', (WidgetTester tester) async {
    const String testName = 'Design System Smoke: aurora sub-editors';
    final Directory tempDir = Directory.systemTemp.createTempSync('design_system_sub_smoke_');
    final Directory pDir = Directory('${tempDir.path}/SubSmoke')..createSync(recursive: true);
    Directory('${pDir.path}/contents/levels').createSync(recursive: true);
    File('${pDir.path}/SubSmoke.lmproject').writeAsStringSync('{}');
    addTearDown(() => deleteTempProject(tempDir));
    final String barrel = '${SmokeArtifacts.testAssetsDir.path}/Props/Barrels/fuel_barrel_red.glb';
    final String manny = '${SmokeArtifacts.testAssetsDir.path}/mannequin/SKM_Manny_Simple.glb';
    final String idle = '${SmokeArtifacts.testAssetsDir.path}/mannequin/MM_Idle.glb';
    final List<String> usedAssets = <String>[barrel, manny, idle];
    for (final String path in usedAssets) {
      expect(File(path).existsSync(), isTrue, reason: 'the smoke loads real models from test-assets/: $path');
    }

    final EditorViewModel vm = EditorViewModel(
      initialProject: LuminaProject(
        projectName: 'SubSmoke',
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
    await tester.runAsync(() async {
      await vm.createNewAssetOnDisk('blueprints', 'BP_Door.lmas', AssetType.actor);
      await vm.createNewAssetOnDisk('materials', 'M_Rust.lmas', AssetType.filamat);
      await vm.createNewAssetOnDisk('ui', 'WBP_HUD.lmas', AssetType.widget);
      await vm.createNewAssetOnDisk('cinematics', 'Seq_Intro.lmas', AssetType.sequencer);
      await vm.createNewAssetOnDisk('landscapes', 'L_Valley.lmas', AssetType.landscape);
    });
    vm.refreshAssets();
    RealAssetInfo assetNamed(String prefix, bool Function(RealAssetInfo) ok) =>
        vm.realAssets.firstWhere((RealAssetInfo a) => ok(a) && a.fileName.startsWith(prefix));
    final RealAssetInfo barrelAsset = assetNamed('fuel_barrel', (RealAssetInfo a) => a.type == AssetType.filamesh);
    final RealAssetInfo mannyAsset =
        assetNamed('SKM_Manny', (RealAssetInfo a) => a.type == AssetType.filameshSk || a.type == AssetType.filamesh);
    final RealAssetInfo? idleAsset = vm.realAssets.where((RealAssetInfo a) => a.type == AssetType.animation).firstOrNull;

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
    final SmokeRecorder rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
    await rec.hold(const Duration(seconds: 1));

    final double dpr = tester.view.devicePixelRatio;
    final StringBuffer report = StringBuffer('MEASURE aurora stage 4:\n');
    final List<String> failures = <String>[];
    void measure(String name, Uint8List png, Rect r, Color expected) {
      final ({int rgb, int count, int total}) d = dominantColorIn(png, r, dpr: dpr);
      final int want = expected.toARGB32() & 0xFFFFFF;
      report.writeln('  $name: ${hex(d.rgb)} on ${d.count}/${d.total} px (expected ${hex(want)})');
      if (d.rgb != want) failures.add('$name is ${hex(d.rgb)}, expected ${hex(want)}');
    }

    // Opens [type] (with [asset]) as a tab, finds its islands, measures the
    // header strip of [measured] (the island fill) and the ground right of
    // it, and saves the screenshot.
    Future<void> openAndCheck(String label, String type, RealAssetInfo? asset, List<String> islands, String measured,
        {String? title, bool orbit = false}) async {
      vm.openSubEditorTab(type, asset: asset, title: title);
      await settle(tester, frames: 50);
      for (int i = 0; i < 60 && find.byKey(ValueKey<String>(islands.first)).evaluate().isEmpty; i++) {
        await rec.hold(const Duration(milliseconds: 100));
      }
      for (final String key in islands) {
        expect(find.byKey(ValueKey<String>(key)), findsOneWidget, reason: '$label: island $key');
      }
      await rec.hold(const Duration(milliseconds: 1200));
      if (orbit) {
        final Finder viewport = find.byKey(ValueKey<String>(islands.firstWhere((String k) => k.contains('viewport'))));
        final Rect r = tester.getRect(viewport);
        await rec.drag(r.center + const Offset(-140, 30), r.center + const Offset(140, 50), steps: 50);
        await rec.hold(const Duration(milliseconds: 600));
      }
      final Uint8List png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
      final Rect island = tester.getRect(find.byKey(ValueKey<String>(measured)));
      measure('$label · island fill', png,
          Rect.fromLTWH(island.left + island.width * 0.55, island.top + 3, island.width * 0.3, EditorIslandStyle.headerHeight - 8),
          EditorColors.sidebar);
      measure('$label · ground beside the island', png, Rect.fromLTWH(island.left - 6, island.top + 60, 4, 80), EditorColors.background);
      SmokeArtifacts.saveScreenshot('$testName — $label', png, usedAssets: usedAssets);
    }

    await openAndCheck('Static Mesh', 'Mesh', barrelAsset,
        <String>['static_mesh_island_lods', 'static_mesh_island_stats', 'static_mesh_island_viewport', 'static_mesh_island_details'],
        'static_mesh_island_details', orbit: true);
    await openAndCheck('Skeletal Mesh', 'SKELETAL', mannyAsset,
        <String>['skeletal_mesh_island_skeleton', 'skeletal_mesh_island_morphs', 'skeletal_mesh_island_viewport', 'skeletal_mesh_island_details'],
        'skeletal_mesh_island_details', orbit: true);
    if (idleAsset != null) {
      await openAndCheck('Animation', 'ANIMATION', idleAsset,
          <String>['anim_island_left', 'anim_island_viewport', 'anim_island_timeline', 'anim_island_right'], 'anim_island_right');
      expect(find.byKey(const ValueKey<String>('anim_transport_bar')), findsOneWidget);
    } else {
      report.writeln('  (no animation asset from MM_Idle.glb: the Animation editor is not shown)');
    }
    await openAndCheck('Material', 'Material', assetNamed('M_Rust', (RealAssetInfo a) => a.type == AssetType.filamat),
        <String>['material_island_preview', 'material_island_settings', 'material_island_graph', 'material_island_compiler_log', 'material_island_parameters'],
        'material_island_parameters');
    await openAndCheck('Blueprint', 'Blueprint', assetNamed('BP_Door', (RealAssetInfo a) => a.type == AssetType.actor),
        <String>['blueprint_island_components', 'blueprint_island_my_blueprint', 'blueprint_island_graph', 'blueprint_island_results', 'blueprint_island_details'],
        'blueprint_island_details');
    await openAndCheck('Sequencer', 'SEQUENCER', assetNamed('Seq_Intro', (RealAssetInfo a) => a.type == AssetType.sequencer),
        <String>['seq_island_tracks', 'seq_island_viewport', 'seq_island_key_details', 'seq_island_timeline'], 'seq_island_key_details');
    await openAndCheck('UMG', 'WIDGET', assetNamed('WBP_HUD', (RealAssetInfo a) => a.type == AssetType.widget),
        <String>['umg_island_palette', 'umg_island_hierarchy', 'umg_island_designer', 'umg_island_details'], 'umg_island_details');
    await openAndCheck('Landscape', 'Landscape', assetNamed('L_Valley', (RealAssetInfo a) => a.type == AssetType.landscape),
        <String>['landscape_island_tools', 'landscape_island_viewport', 'landscape_island_foliage'], 'landscape_island_foliage');
    for (int i = 0; i < 100 && !vm.isPluginRegistryReady; i++) {
      await rec.hold(const Duration(milliseconds: 100));
    }
    await openAndCheck('Plugins', 'plugins', null,
        <String>['plugins_island_categories', 'plugins_island_list', 'plugins_island_details'], 'plugins_island_details', title: 'Plugins');
    await openAndCheck('Project Settings', 'projectSettings', null,
        <String>['project_settings_island_nav', 'project_settings_island_body'], 'project_settings_island_body', title: 'Project Settings');
    await openAndCheck('Build Manager', 'buildManager', null,
        <String>['build_manager_island_steps', 'build_manager_island_log', 'build_manager_island_settings'], 'build_manager_island_settings',
        title: 'Build Manager');

    // Back through the 3D editors on video, the Static Mesh viewport orbiting.
    vm.selectTab(1);
    await settle(tester, frames: 12);
    final Rect sub = tester.getRect(find.byKey(const ValueKey<String>('static_mesh_island_viewport')));
    await rec.drag(sub.center + const Offset(140, 0), sub.center + const Offset(-140, 20), steps: 50);
    final Uint8List finalPng = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
    SmokeArtifacts.saveScreenshot(testName, finalPng, usedAssets: usedAssets);
    await rec.hold(const Duration(seconds: 2));
    rec.save(testName, usedAssets: usedAssets);
    // ignore: avoid_print
    print(report);
    expect(failures, isEmpty, reason: '${failures.join('\n')}\n$report');
  }, timeout: const Timeout(Duration(minutes: 15)));
}

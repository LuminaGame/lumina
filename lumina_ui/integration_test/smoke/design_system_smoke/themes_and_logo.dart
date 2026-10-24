part of '../design_system_smoke_test.dart';

/// The editor themes and the Prism L logo and lockup.
void _themesAndLogoScenarios(IntegrationTestWidgetsFlutterBinding binding) {
  testWidgets('Design System Smoke: editor themes', (WidgetTester tester) async {
    const String testName = 'Design System Smoke: editor themes';
    final Directory tempDir = Directory.systemTemp.createTempSync('design_system_themes_smoke_');
    final Directory pDir = Directory('${tempDir.path}/ThemeSmoke')..createSync(recursive: true);
    Directory('${pDir.path}/contents/meshes').createSync(recursive: true);
    Directory('${pDir.path}/contents/levels').createSync(recursive: true);
    File('${pDir.path}/ThemeSmoke.lmproject').writeAsStringSync('{}');
    final Directory configDir = Directory('${tempDir.path}/config')..createSync();
    addTearDown(() async {
      EditorTheme.apply(EditorThemeData.luminaDark);
      await deleteTempProject(tempDir);
    });
    const List<String> assetRels = <String>[
      'Props/Barrels/fuel_barrel_red.glb',
      'Props/Banana Bunch/banana_bunch_long.glb',
      'Props/Access_cards/access_card_green.glb',
    ];
    final List<String> usedAssets = <String>[];
    for (final String rel in assetRels) {
      final File src = File('${SmokeArtifacts.testAssetsDir.path}/$rel');
      if (!src.existsSync()) continue;
      src.copySync('${pDir.path}/contents/meshes/${rel.split('/').last}');
      usedAssets.add(src.path);
    }
    expect(usedAssets, isNotEmpty, reason: 'the smoke must load real models from test-assets/');

    // The real theme store on a temp config dir: the built-ins, and the
    // active theme remembered in editor_preferences.json.
    final EditorThemeController themes = EditorThemeController(store: EditorThemeStore(configDir: configDir));
    final EditorViewModel vm = EditorViewModel(
      initialProject: LuminaProject(
        projectName: 'ThemeSmoke',
        activeLevel: 'contents/levels/L_Main.lmas',
        settings: EngineScalabilitySettings(targetFps: 60),
      ),
      projectLocation: tempDir.path,
    );
    addTearDown(vm.dispose);
    await tester.runAsync(() => vm.ensureDefaultLevelAssets());

    final GlobalKey boundaryKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: EditorThemeScope(
          controller: themes,
          child: Builder(
            builder: (BuildContext context) {
              EditorThemeScope.of(context);
              return ShadcnApp(
                theme: luminaEditorTheme(),
                home: Scaffold(child: MainEditorView(viewModel: vm)),
              );
            },
          ),
        ),
      ),
    );
    await settle(tester);
    final SmokeRecorder rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
    await rec.hold(const Duration(seconds: 1));
    vm.spawnNewActor('StaticMesh');
    await settle(tester, frames: 20);
    if (vm.actors.isNotEmpty) vm.selectActorById(vm.actors.last.id);
    await settle(tester, frames: 20);

    final double dpr = tester.view.devicePixelRatio;
    final StringBuffer report = StringBuffer('MEASURE editor themes:\n');
    final List<String> failures = <String>[];
    for (final EditorThemeData theme in EditorThemeData.builtIns) {
      themes.activate(theme.name);
      await settle(tester, frames: 30);
      await rec.hold(const Duration(milliseconds: 3500));
      final Uint8List png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
      SmokeArtifacts.saveScreenshot('$testName — ${theme.name}', png, usedAssets: usedAssets);

      final Rect outliner = tester.getRect(find.byType(OutlinerWidget));
      final ({int rgb, int count, int total}) body = dominantColorIn(
          png, Rect.fromLTWH(outliner.left + 4, outliner.bottom - 60, outliner.width - 8, 50), dpr: dpr);
      final ({int rgb, int count, int total}) header = dominantColorIn(
          png, Rect.fromLTWH(outliner.left + 2, outliner.top + 2, outliner.width - 4, EditorDensity.panelHeaderHeight - 4), dpr: dpr);
      final Rect menuRow = tester.getRect(find.byType(MenuBarWidget).first);
      final ({int rgb, int count, int total}) title = dominantColorIn(
          png, Rect.fromLTWH(tester.getRect(find.byKey(const ValueKey<String>('menu_bar_command_field'))).left - 20, menuRow.top + 4, 12, 40), dpr: dpr);
      final Rect tab = tester.getRect(find.byKey(const ValueKey<String>('workspace_tab_0')));
      final ({int rgb, int count, int total}) tabFill = dominantColorIn(
          png, Rect.fromLTWH(tab.left + 3, tab.top + 4, tab.width - 6, tab.height - 8), dpr: dpr);
      // The Outliner is an island: header and body on the island fill.
      final int wantBody = theme.color('sidebar').toARGB32() & 0xFFFFFF;
      final int wantHeader = theme.color('sidebar').toARGB32() & 0xFFFFFF;
      report.writeln('  ${theme.name}: outliner body ${hex(body.rgb)} (${body.count}/${body.total}, expected ${hex(wantBody)}), '
          'header ${hex(header.rgb)} (expected ${hex(wantHeader)}), title bar ${hex(title.rgb)}');
      if (body.rgb != wantBody) failures.add('${theme.name}: outliner body ${hex(body.rgb)} != ${hex(wantBody)}');
      if (header.rgb != wantHeader) failures.add('${theme.name}: outliner header ${hex(header.rgb)} != ${hex(wantHeader)}');
      // The menu bar sits on the rail; the active typed tab on the island fill.
      final int wantRail = theme.color('rail').toARGB32() & 0xFFFFFF;
      final int wantIsland = theme.color('sidebar').toARGB32() & 0xFFFFFF;
      if (title.rgb != wantRail) failures.add('${theme.name}: title bar ${hex(title.rgb)} != ${hex(wantRail)}');
      report.writeln('    active workspace tab (BoxDecoration) ${hex(tabFill.rgb)} (${tabFill.count}/${tabFill.total})');
      if (tabFill.rgb != wantIsland) failures.add('${theme.name}: active tab fill ${hex(tabFill.rgb)} != ${hex(wantIsland)}');
    }
    themes.activate(EditorThemeData.luminaDark.name);
    await settle(tester, frames: 20);
    await rec.hold(const Duration(seconds: 1));
    rec.save(testName, usedAssets: usedAssets);
    // ignore: avoid_print
    print(report);
    expect(File('${configDir.path}/editor_preferences.json').readAsStringSync(), contains('"theme": "Lumina Dark"'));
    expect(failures, isEmpty, reason: '${failures.join('\n')}\n$report');
  }, timeout: const Timeout(Duration(minutes: 8)));

  testWidgets('Design System Smoke: prism l logo and lockup', (WidgetTester tester) async {
    const String testName = 'Design System Smoke: prism l logo and lockup';
    final Directory tempDir = Directory.systemTemp.createTempSync('design_system_logo_smoke_');
    final Directory configDir = Directory('${tempDir.path}/config')..createSync();
    final Directory pDir = Directory('${tempDir.path}/LogoSmoke')..createSync(recursive: true);
    Directory('${pDir.path}/contents/meshes').createSync(recursive: true);
    Directory('${pDir.path}/contents/levels').createSync(recursive: true);
    File('${pDir.path}/LogoSmoke.lmproject').writeAsStringSync('{}');
    addTearDown(() => deleteTempProject(tempDir));
    final List<String> usedAssets = <String>[];
    final File barrel = File('${SmokeArtifacts.testAssetsDir.path}/Props/Barrels/fuel_barrel_red.glb');
    if (barrel.existsSync()) {
      barrel.copySync('${pDir.path}/contents/meshes/fuel_barrel_red.glb');
      usedAssets.add(barrel.path);
    }
    expect(usedAssets, isNotEmpty, reason: 'the smoke must load a real model from test-assets/');

    final GlobalKey boundaryKey = GlobalKey();
    final double dpr = tester.view.devicePixelRatio;
    Uint8List crop(Uint8List png, Rect r) {
      final img.Image im = img.decodePng(png)!;
      final int x = (r.left * dpr).round().clamp(0, im.width - 1);
      final int y = (r.top * dpr).round().clamp(0, im.height - 1);
      final int w = (r.width * dpr).round().clamp(1, im.width - x);
      final int h = (r.height * dpr).round().clamp(1, im.height - y);
      return Uint8List.fromList(img.encodePng(img.copyCrop(im, x: x, y: y, width: w, height: h)));
    }

    // The mark's three blues must be painted inside the rectangle: the proof
    // that the Prism L, not a fallback icon, is on screen.
    final StringBuffer report = StringBuffer('MEASURE prism l mark:\n');
    final List<String> failures = <String>[];
    void expectMark(String where, Uint8List png, Rect r) {
      final Map<int, int> hist = chromeHistogram(crop(png, r));
      final int deep = hist[LuminaBrand.blueDeep.toARGB32() & 0xFFFFFF] ?? 0;
      final int mid = hist[LuminaBrand.blueMid.toARGB32() & 0xFFFFFF] ?? 0;
      final int light = hist[LuminaBrand.blueLight.toARGB32() & 0xFFFFFF] ?? 0;
      report.writeln('  $where: deep $deep px, mid $mid px, light $light px');
      if (deep == 0 || mid == 0 || light == 0) failures.add('$where: the three blues are not all painted');
    }

    // --- 1. the launcher: the lockup in the header, the mono mark in the empty state
    final LauncherViewModel launcher = LauncherViewModel(configDir: configDir);
    await tester.pumpWidget(RepaintBoundary(
      key: boundaryKey,
      child: ShadcnApp(theme: luminaEditorTheme(), home: LauncherView(viewModel: launcher)),
    ));
    await settle(tester, frames: 40);
    final SmokeRecorder rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
    await rec.hold(const Duration(seconds: 3));
    expect(find.byType(LuminaLockup), findsWidgets, reason: 'the launcher header shows the lockup');
    Uint8List png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
    final Rect header = tester.getRect(find.byType(LuminaLockup).first);
    expectMark('launcher header lockup', png, header.inflate(4));
    SmokeArtifacts.saveScreenshot('$testName — launcher header', crop(png, Rect.fromLTWH(0, 0, 720, 80)), usedAssets: usedAssets);

    // --- 2. the splash: the mark alone over the gradient
    await tester.pumpWidget(RepaintBoundary(
      key: boundaryKey,
      child: ShadcnApp(
        theme: luminaEditorTheme(),
        home: const LuminaSplashScreen(subtitle: 'Lumina Editor · LogoSmoke', statusText: 'Loading…', manageWindow: false),
      ),
    ));
    await settle(tester, frames: 30);
    await rec.hold(const Duration(seconds: 3));
    png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
    final Rect splashMark = tester.getRect(find.byType(LuminaMark).first);
    expectMark('splash mark', png, splashMark.inflate(4));
    SmokeArtifacts.saveScreenshot('$testName — splash', png, usedAssets: usedAssets);

    // --- 3. the editor: the menu bar lockup and the About dialog's mark
    final EditorViewModel vm = EditorViewModel(
      initialProject: LuminaProject(
        projectName: 'LogoSmoke',
        activeLevel: 'contents/levels/L_Main.lmas',
        settings: EngineScalabilitySettings(targetFps: 60),
      ),
      projectLocation: tempDir.path,
    );
    addTearDown(vm.dispose);
    await tester.runAsync(() => vm.ensureDefaultLevelAssets());
    await tester.pumpWidget(RepaintBoundary(
      key: boundaryKey,
      child: ShadcnApp(theme: luminaEditorTheme(), home: Scaffold(child: MainEditorView(viewModel: vm))),
    ));
    await settle(tester);
    await rec.hold(const Duration(seconds: 3));
    png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
    final Rect menuRow = tester.getRect(find.byType(MenuBarWidget).first);
    final Rect lockup = tester.getRect(find.descendant(of: find.byType(MenuBarWidget), matching: find.byType(LuminaLockup)).first);
    expectMark('menu bar lockup', png, lockup.inflate(4));
    SmokeArtifacts.saveScreenshot('$testName — menu bar lockup', crop(png, Rect.fromLTWH(menuRow.left, menuRow.top, 480, 56)), usedAssets: usedAssets);

    vm.commands.execute('help.about', tester.element(find.byType(MainEditorView)));
    await settle(tester, frames: 30);
    await rec.hold(const Duration(seconds: 2));
    expect(find.text('About Lumina Studio'), findsOneWidget);
    png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
    final Rect aboutMark = tester.getRect(find.descendant(of: find.byType(AlertDialog), matching: find.byType(LuminaMark)).first);
    expectMark('about dialog mark', png, aboutMark.inflate(4));
    SmokeArtifacts.saveScreenshot('$testName — about dialog', png, usedAssets: usedAssets);
    SmokeArtifacts.saveScreenshot(testName, png, usedAssets: usedAssets);
    rec.save(testName, usedAssets: usedAssets);
    // ignore: avoid_print
    print(report);
    expect(failures, isEmpty, reason: '${failures.join('\n')}\n$report');
  }, timeout: const Timeout(Duration(minutes: 8)));
}

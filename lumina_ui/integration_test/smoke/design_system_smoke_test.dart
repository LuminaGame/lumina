// Design system smoke: proves Lumina Studio's main view renders the Figma
// Make prototype's palette, and not the editor's old blue-tinted one.
//
// Comparison method (stated, because a screenshot with "looks right" under it
// is not evidence):
//
//  1. The real editor boots on a real project on disk, with real GLB assets
//     copied out of `test-assets/` into its `contents/`.
//  2. The frame is captured through a RepaintBoundary around the whole shell.
//  3. The 3D viewport's rectangle is **excluded** from every measurement. It
//     draws a live amber HUD (Tris / FPS / CPU) that changes every frame, and
//     its pixels are rendered geometry, not chrome.
//  4. Over the remaining chrome pixels the test builds an exact-colour
//     histogram and then asserts, with numbers printed into the log:
//       · each of the prototype's tokens is actually painted, and how many
//         pixels each one covers;
//       · **zero** pixels carry any colour from the editor's retired palette
//         (#0F0F12, #16161B, #282832, #FF8C00) — the old neutrals were tinted
//         blue and the old accent was a flat orange;
//       · the named panel surfaces are hueless: max channel − min channel is
//         0 for each one, which is what `oklch(L 0 0)` means. The old
//         neutrals were tinted blue by 3–10/255.
//  5. Specific panel rectangles are sampled by their widget bounds so the
//     measurement names what it measured: the World Outliner's header strip,
//     its body, and the Content Browser's sources rail.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme_data.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme_store.dart';
import 'package:lumina_ui/ui/core/window/lumina_window.dart';
import 'package:lumina_ui/ui/core/window/window_controls.dart';
import 'package:lumina_ui/ui/core/window/window_state_store.dart';
import 'package:window_manager/window_manager.dart' show windowManager;
import 'package:lumina_ui/ui/features/main_editor/views/details_widget.dart';
import 'package:lumina_ui/ui/features/main_editor/views/menu_bar_widget.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/content_browser_widget.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/main_editor/views/outliner_widget.dart';
import 'package:lumina_ui/ui/features/main_editor/views/viewport_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The prototype's retired predecessors. None of these may survive anywhere in
/// the editor's chrome.
const Map<String, int> retiredPalette = <String, int>{
  'old background #0F0F12': 0x0F0F12,
  'old panel #16161B': 0x16161B,
  'old border #282832': 0x282832,
  'old accent #FF8C00': 0xFF8C00,
};

/// The tokens that are actually painted as flat fills: the
/// grey ramp (which replaced the prototype's near-black surfaces) and the
/// prototype's orange.
Map<String, int> paintedTokens() => <String, int>{
      'background': EditorColors.background.toARGB32() & 0xFFFFFF,
      'sidebar (tab strips)': EditorColors.sidebar.toARGB32() & 0xFFFFFF,
      'card': EditorColors.card.toARGB32() & 0xFFFFFF,
      'panel header': EditorColors.cardHeader.toARGB32() & 0xFFFFFF,
      'rail': EditorColors.rail.toARGB32() & 0xFFFFFF,
      '--primary oklch(0.72 0.185 52)': EditorColors.primary.toARGB32() & 0xFFFFFF,
    };

/// An exact-colour histogram of [png], skipping every pixel inside [exclude].
Map<int, int> chromeHistogram(Uint8List png, {Rect? exclude, double dpr = 1.0}) {
  final img.Image im = img.decodePng(png)!;
  final Map<int, int> hist = <int, int>{};
  final int ex0 = exclude == null ? 0 : (exclude.left * dpr).floor();
  final int ex1 = exclude == null ? 0 : (exclude.right * dpr).ceil();
  final int ey0 = exclude == null ? 0 : (exclude.top * dpr).floor();
  final int ey1 = exclude == null ? 0 : (exclude.bottom * dpr).ceil();
  for (int y = 0; y < im.height; y++) {
    for (int x = 0; x < im.width; x++) {
      if (exclude != null && x >= ex0 && x < ex1 && y >= ey0 && y < ey1) continue;
      final img.Pixel p = im.getPixel(x, y);
      final int key =
          (p.r.toInt() << 16) | (p.g.toInt() << 8) | p.b.toInt();
      hist[key] = (hist[key] ?? 0) + 1;
    }
  }
  return hist;
}

/// The single most common colour inside [rect], in the PNG's pixel space.
({int rgb, int count, int total}) dominantColorIn(
  Uint8List png,
  Rect rect, {
  double dpr = 1.0,
}) {
  final img.Image im = img.decodePng(png)!;
  final Map<int, int> hist = <int, int>{};
  int total = 0;
  final int x0 = (rect.left * dpr).round().clamp(0, im.width - 1);
  final int x1 = (rect.right * dpr).round().clamp(0, im.width);
  final int y0 = (rect.top * dpr).round().clamp(0, im.height - 1);
  final int y1 = (rect.bottom * dpr).round().clamp(0, im.height);
  for (int y = y0; y < y1; y++) {
    for (int x = x0; x < x1; x++) {
      final img.Pixel p = im.getPixel(x, y);
      final int key = (p.r.toInt() << 16) | (p.g.toInt() << 8) | p.b.toInt();
      hist[key] = (hist[key] ?? 0) + 1;
      total++;
    }
  }
  int best = 0, bestN = 0;
  hist.forEach((int k, int n) {
    if (n > bestN) {
      best = k;
      bestN = n;
    }
  });
  return (rgb: best, count: bestN, total: total);
}

/// Chroma (max channel − min channel) of a packed RGB. `oklch(L 0 0)` is 0.
int chromaOf(int rgb) {
  final int r = (rgb >> 16) & 0xFF, g = (rgb >> 8) & 0xFF, b = rgb & 0xFF;
  final int lo = r < g ? (r < b ? r : b) : (g < b ? g : b);
  final int hi = r > g ? (r > b ? r : b) : (g > b ? g : b);
  return hi - lo;
}

/// The large flat fills in [hist] that are dark enough to be a neutral
/// surface, brightest first, with their chroma. Used to report what is on
/// screen rather than only what was expected.
List<String> darkSurfaces(Map<int, int> hist, {int minArea = 2000}) {
  final List<({int rgb, int count})> big = <({int rgb, int count})>[];
  hist.forEach((int rgb, int count) {
    if (count < minArea) return;
    final int r = (rgb >> 16) & 0xFF, g = (rgb >> 8) & 0xFF, b = rgb & 0xFF;
    if (r > 64 || g > 64 || b > 64) return;
    big.add((rgb: rgb, count: count));
  });
  big.sort((({int rgb, int count}) a, ({int rgb, int count}) b) =>
      b.count.compareTo(a.count));
  return big
      .map((({int rgb, int count}) e) =>
          '${hex(e.rgb)} ${e.count}px chroma=${chromaOf(e.rgb)}')
      .toList();
}

String hex(int rgb) => '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';

Future<void> settle(WidgetTester tester, {int frames = 60}) async {
  for (int i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 16)));
  }
}

void main() {
  final IntegrationTestWidgetsFlutterBinding binding =
      IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'Design System Smoke: the main view is painted in the prototype\'s palette',
      (WidgetTester tester) async {
    // --- a real project on disk, with real assets --------------------------
    final Directory tempDir =
        Directory.systemTemp.createTempSync('design_system_smoke_');
    final Directory pDir = Directory('${tempDir.path}/DesignSystemSmoke')
      ..createSync(recursive: true);
    Directory('${pDir.path}/contents/meshes').createSync(recursive: true);
    Directory('${pDir.path}/contents/levels').createSync(recursive: true);
    File('${pDir.path}/DesignSystemSmoke.lmproject').writeAsStringSync('{}');
    addTearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    const List<String> assetRels = <String>[
      'Props/AC_units/roof_aircon_unit_150x150_a.glb',
      'Props/Barrels/barrel_small_a.glb',
      'Props/Banana Bunch/banana_bunch_long.glb',
    ];
    final List<String> usedAssets = <String>[];
    for (final String rel in assetRels) {
      final File src = File('${SmokeArtifacts.testAssetsDir.path}/$rel');
      if (!src.existsSync()) continue;
      final String name = rel.split('/').last;
      src.copySync('${pDir.path}/contents/meshes/$name');
      usedAssets.add(src.path);
    }
    expect(usedAssets, isNotEmpty,
        reason: 'the smoke must load real models from test-assets/');

    final EditorViewModel vm = EditorViewModel(
      initialProject: LuminaProject(
        projectName: 'DesignSystemSmoke',
        activeLevel: 'contents/levels/L_Main.lmas',
        settings: EngineScalabilitySettings(targetFps: 60),
      ),
      projectLocation: tempDir.path,
    );
    addTearDown(vm.dispose);
    // The view model loads the level asynchronously and replaces its actor
    // list wholesale; let that land before anything is seeded or selected.
    await tester.runAsync(() => vm.ensureDefaultLevelAssets());

    final GlobalKey boundaryKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        // The one theme the app itself runs on, so this PNG is evidence of
        // the real palette rather than of a hand-rolled test theme.
        child: ShadcnApp(
          theme: luminaEditorTheme(),
          home: Scaffold(child: MainEditorView(viewModel: vm)),
        ),
      ),
    );
    await settle(tester);
    final SmokeRecorder rec =
        SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
    await rec.hold(const Duration(seconds: 2));

    // Give the outliner something to select, so the selection accent is on
    // screen and measurable.
    vm.spawnNewActor('StaticMesh');
    await settle(tester, frames: 20);
    await rec.hold(const Duration(seconds: 2));
    if (vm.actors.isNotEmpty) {
      vm.selectActorById(vm.actors.last.id);
    }
    await settle(tester, frames: 30);
    await rec.hold(const Duration(seconds: 2));

    final double dpr = tester.view.devicePixelRatio;
    final Rect viewportRect = find.byType(ViewportWidget).evaluate().isEmpty
        ? Rect.zero
        : tester.getRect(find.byType(ViewportWidget));

    final Uint8List png = await SmokeArtifacts.captureIntegrationPng(
        binding, tester,
        boundary: find.byKey(boundaryKey));

    // --- 1. the chrome histogram ------------------------------------------
    final Map<int, int> hist =
        chromeHistogram(png, exclude: viewportRect, dpr: dpr);
    final int chromePixels = hist.values.fold(0, (int a, int b) => a + b);
    expect(chromePixels, greaterThan(100000),
        reason: 'the editor chrome must actually be on screen');

    final StringBuffer report = StringBuffer();
    report.writeln('MEASURE design_system: chromePixels=$chromePixels '
        '(viewport ${viewportRect.width.toStringAsFixed(0)}x'
        '${viewportRect.height.toStringAsFixed(0)} excluded), '
        'distinctColours=${hist.length}');

    // Every token the prototype paints as a flat fill must be present.
    final List<String> missing = <String>[];
    paintedTokens().forEach((String name, int rgb) {
      final int n = hist[rgb] ?? 0;
      report.writeln('  token $name ${hex(rgb)}: $n px '
          '(${(100 * n / chromePixels).toStringAsFixed(2)}%)');
      if (n == 0) missing.add('$name ${hex(rgb)}');
    });

    // Not one pixel of the palette this task replaced.
    final List<String> survivors = <String>[];
    retiredPalette.forEach((String name, int rgb) {
      final int n = hist[rgb] ?? 0;
      report.writeln('  retired $name ${hex(rgb)}: $n px');
      if (n > 0) survivors.add('$name ${hex(rgb)} — $n px');
    });

    report.writeln('  dark flat fills on screen (≥2000 px): '
        '${darkSurfaces(hist).join(', ')}');

    // --- 2. named panel rectangles ----------------------------------------
    final Rect outlinerRect = tester.getRect(find.byType(OutlinerWidget));
    final ({int rgb, int count, int total}) header = dominantColorIn(
      png,
      Rect.fromLTWH(outlinerRect.left + 2, outlinerRect.top + 2,
          outlinerRect.width - 4, EditorDensity.panelHeaderHeight - 4),
      dpr: dpr,
    );
    report.writeln('  World Outliner header strip: ${hex(header.rgb)} on '
        '${header.count}/${header.total} px '
        '(expected ${hex(EditorColors.cardHeader.toARGB32() & 0xFFFFFF)})');

    final Finder browser = find.byType(ContentBrowserWidget);
    ({int rgb, int count, int total})? rail;
    if (browser.evaluate().isNotEmpty) {
      final Rect cb = tester.getRect(browser);
      rail = dominantColorIn(
        png,
        Rect.fromLTWH(cb.left + 4, cb.top + EditorDensity.panelHeaderHeight + 8,
            EditorDensity.sourcesRailWidth - 8, 60),
        dpr: dpr,
      );
      report.writeln('  Content Browser sources rail: ${hex(rail.rgb)} on '
          '${rail.count}/${rail.total} px '
          '(expected ${hex(EditorColors.rail.toARGB32() & 0xFFFFFF)})');
    }

    // Every named surface must be hueless, the way `oklch(L 0 0)` is. The
    // retired neutrals were tinted blue by 3–10/255 per channel, so any
    // non-zero chroma here means they are back.
    final Map<String, int> namedSurfaces = <String, int>{
      'World Outliner header': header.rgb,
      if (rail != null) 'Content Browser sources rail': rail.rgb,
    };
    final List<String> tintedSurfaces = <String>[];
    namedSurfaces.forEach((String name, int rgb) {
      final int c = chromaOf(rgb);
      report.writeln('  chroma of $name ${hex(rgb)}: $c');
      if (c != 0) tintedSurfaces.add('$name ${hex(rgb)} chroma=$c');
    });

    // ignore: avoid_print
    print(report.toString());

    // --- evidence ----------------------------------------------------------
    SmokeArtifacts.saveScreenshot(
      'Design System Smoke: the main view is painted in the prototype\'s palette',
      png,
      usedAssets: usedAssets,
    );
    await rec.hold(const Duration(milliseconds: 1500));
    // The selection accent goes off and comes back on.
    final String? selected = vm.selectedActorIds.isEmpty ? null : vm.selectedActorIds.first;
    vm.clearSelection();
    await settle(tester, frames: 6);
    await rec.hold(const Duration(milliseconds: 1500));
    if (selected != null) vm.selectActorById(selected);
    await settle(tester, frames: 6);
    await rec.hold(const Duration(milliseconds: 2500));
    rec.save(
      'Design System Smoke: the main view is painted in the prototype\'s palette',
      usedAssets: usedAssets,
    );

    // --- assertions --------------------------------------------------------
    expect(missing, isEmpty,
        reason: 'these prototype tokens are not painted anywhere in the '
            'editor chrome:\n${missing.join('\n')}\n$report');
    expect(survivors, isEmpty,
        reason: 'the retired palette is still on screen:\n'
            '${survivors.join('\n')}\n$report');
    expect(tintedSurfaces, isEmpty,
        reason: 'the prototype\'s neutrals carry no hue at all:\n'
            '${tintedSurfaces.join('\n')}\n$report');
    expect(header.rgb, EditorColors.cardHeader.toARGB32() & 0xFFFFFF,
        reason: 'the World Outliner header strip must be EditorColors.cardHeader\n$report');
  }, timeout: const Timeout(Duration(minutes: 8)));

  testWidgets('Design System Smoke: custom chrome and lifted surfaces', (WidgetTester tester) async {
    const String testName = 'Design System Smoke: custom chrome and lifted surfaces';
    // --- a real project on disk, with real assets --------------------------
    final Directory tempDir = Directory.systemTemp.createTempSync('design_system_chrome_smoke_');
    final Directory pDir = Directory('${tempDir.path}/ChromeSmoke')..createSync(recursive: true);
    Directory('${pDir.path}/contents/meshes').createSync(recursive: true);
    Directory('${pDir.path}/contents/levels').createSync(recursive: true);
    File('${pDir.path}/ChromeSmoke.lmproject').writeAsStringSync('{}');
    final Directory configDir = Directory('${tempDir.path}/config')..createSync();
    addTearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });
    const List<String> assetRels = <String>[
      'Props/Access_cards/access_card_blue.glb',
      'Props/Barrels/barrel_small_a.glb',
      'Props/AC_units/roof_aircon_unit_150x150_a.glb',
    ];
    final List<String> usedAssets = <String>[];
    for (final String rel in assetRels) {
      final File src = File('${SmokeArtifacts.testAssetsDir.path}/$rel');
      if (!src.existsSync()) continue;
      src.copySync('${pDir.path}/contents/meshes/${rel.split('/').last}');
      usedAssets.add(src.path);
    }
    expect(usedAssets, isNotEmpty, reason: 'the smoke must load real models from test-assets/');

    // --- the real window, through the real window_manager plugin ----------
    // The integration test app runs on the same GTK runner as the editor, so
    // this hides the WM title bar for real; the placement store is a temp dir.
    final LuminaWindow window = LuminaWindow(store: WindowStateStore(configDir: configDir));
    addTearDown(window.dispose);
    await tester.runAsync(() => window.startup(const WindowOptions(titleBarStyle: TitleBarStyle.hidden)));

    final EditorViewModel vm = EditorViewModel(
      initialProject: LuminaProject(
        projectName: 'ChromeSmoke',
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
        child: ShadcnApp(
          theme: luminaEditorTheme(),
          home: Scaffold(child: MainEditorView(viewModel: vm)),
          builder: (BuildContext context, Widget? child) => LuminaWindowFrame(window: window, child: child!),
        ),
      ),
    );
    await settle(tester);
    final SmokeRecorder rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
    await rec.hold(const Duration(seconds: 2));

    Future<bool> waitFor(bool Function() done) async {
      for (int i = 0; i < 150 && !done(); i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump(const Duration(milliseconds: 16));
      }
      return done();
    }

    final double dpr = tester.view.devicePixelRatio;
    Uint8List crop(Uint8List png, Rect r) {
      final img.Image im = img.decodePng(png)!;
      final int x = (r.left * dpr).round().clamp(0, im.width - 1);
      final int y = (r.top * dpr).round().clamp(0, im.height - 1);
      final int w = (r.width * dpr).round().clamp(1, im.width - x);
      final int h = (r.height * dpr).round().clamp(1, im.height - y);
      return Uint8List.fromList(img.encodePng(img.copyCrop(im, x: x, y: y, width: w, height: h)));
    }

    final StringBuffer report = StringBuffer('MEASURE design system tokens:\n');
    final List<String> failures = <String>[];
    void measure(String name, Uint8List png, Rect r, Color expected) {
      final ({int rgb, int count, int total}) d = dominantColorIn(png, r, dpr: dpr);
      final int want = expected.toARGB32() & 0xFFFFFF;
      report.writeln('  $name: ${hex(d.rgb)} on ${d.count}/${d.total} px (expected ${hex(want)})');
      if (d.rgb != want) failures.add('$name is ${hex(d.rgb)}, expected ${hex(want)}');
    }

    // --- 1. menu row with our own window controls -------------------------
    final Uint8List full = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
    final Rect menuRow = tester.getRect(find.byType(MenuBarWidget).first);
    final Rect menuBar = Rect.fromLTWH(menuRow.left, menuRow.top, menuRow.width, 30);
    for (final String k in <String>['window_control_minimize', 'window_control_maximize', 'window_control_fullscreen', 'window_control_close']) {
      expect(find.byKey(ValueKey<String>(k)), findsOneWidget, reason: '$k in the menu row');
    }
    final Rect close = tester.getRect(find.byKey(const ValueKey<String>('window_control_close')));
    report.writeln('  close button right edge ${close.right.toStringAsFixed(0)} of menu row ${menuBar.right.toStringAsFixed(0)}');
    measure('menu row (title bar)', full, Rect.fromLTWH(menuBar.left + 700, menuBar.top + 4, 200, 22), EditorColors.cardHeader);
    SmokeArtifacts.saveScreenshot('$testName — menu row with window controls', crop(full, menuBar), usedAssets: usedAssets);

    // --- 2. the tab strip: the active tab has no bottom edge ---------------
    final Rect tab = tester.getRect(find.byKey(const ValueKey<String>('workspace_tab_0')));
    final Rect strip = Rect.fromLTWH(menuBar.left, tab.top - 4, menuBar.width, 28);
    measure('workspace tab strip', full, Rect.fromLTWH(tab.right + 20, strip.top + 2, 300, strip.height - 6), EditorColors.sidebar);
    measure('active workspace tab fill', full, Rect.fromLTWH(tab.left + 2, tab.top + 3, tab.width - 4, tab.height - 4), EditorColors.cardHeader);
    // The last pixel row of the active tab is the toolbar's colour, not a
    // border line; under an inactive stretch of the strip the line is there.
    measure('bottom row under the active tab', full, Rect.fromLTWH(tab.left + 3, tab.bottom - 1, tab.width - 6, 1), EditorColors.cardHeader);
    SmokeArtifacts.saveScreenshot('$testName — tab strip, active tab without bottom edge',
        crop(full, Rect.fromLTWH(strip.left, strip.top - 2, 700, strip.height + 40)), usedAssets: usedAssets);

    // --- 3. the lifted panels ----------------------------------------------
    final Rect outliner = tester.getRect(find.byType(OutlinerWidget));
    final Rect details = tester.getRect(find.byType(DetailsWidget));
    measure('World Outliner header', full,
        Rect.fromLTWH(outliner.left + 2, outliner.top + 2, outliner.width - 4, EditorDensity.panelHeaderHeight - 4), EditorColors.cardHeader);
    measure('World Outliner body', full,
        Rect.fromLTWH(outliner.left + 4, outliner.bottom - 60, outliner.width - 8, 50), EditorColors.background);
    final Finder browser = find.byType(ContentBrowserWidget);
    Rect panels = outliner.expandToInclude(details);
    if (browser.evaluate().isNotEmpty) {
      final Rect cb = tester.getRect(browser);
      measure('Content Browser sources rail', full,
          Rect.fromLTWH(cb.left + 4, cb.bottom - 40, EditorDensity.sourcesRailWidth - 8, 30), EditorColors.rail);
      panels = panels.expandToInclude(cb);
    }
    // ignore: avoid_print
    print(report);
    SmokeArtifacts.saveScreenshot('$testName — outliner, details and content browser panels', crop(full, panels), usedAssets: usedAssets);
    SmokeArtifacts.saveScreenshot(testName, full, usedAssets: usedAssets);
    await rec.hold(const Duration(seconds: 2));

    // The bottom panel's tabs: the attached (fill = content, no bottom edge)
    // tab follows the selection.
    for (final int i in <int>[1, 2, 0]) {
      await tester.tap(find.byKey(ValueKey<String>('bottom_tab_$i')));
      await settle(tester, frames: 10);
      await rec.hold(const Duration(milliseconds: 900));
    }
    // The close button turns red under the pointer.
    final TestGesture mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(find.byKey(const ValueKey<String>('window_control_close'))));
    await settle(tester, frames: 10);
    await rec.hold(const Duration(milliseconds: 1200));
    await mouse.moveTo(tester.getCenter(find.byKey(const ValueKey<String>('window_title_drag_area'))));
    await settle(tester, frames: 6);
    await mouse.removePointer();

    // --- 4. the real window: maximize ⇄ restore, fullscreen ----------------
    await tester.tap(find.byKey(const ValueKey<String>('window_control_maximize')));
    final bool maximized = await waitFor(() => window.isMaximized);
    await settle(tester, frames: 20);
    report.writeln('  maximize button → window.isMaximized=$maximized (from the plugin\'s event)');
    expect(maximized, isTrue, reason: 'the real GTK window reports maximize');
    expect(find.byKey(const ValueKey<String>('window_control_restore_icon')), findsOneWidget);
    await rec.hold(const Duration(seconds: 2));
    SmokeArtifacts.saveScreenshot('$testName — maximized, restore icon',
        crop(await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey)),
            Rect.fromLTWH(0, 0, tester.getRect(find.byType(MenuBarWidget).first).width, 30)),
        usedAssets: usedAssets);
    await tester.tap(find.byKey(const ValueKey<String>('window_control_maximize')));
    final bool restored = await waitFor(() => !window.isMaximized);
    await settle(tester, frames: 20);
    expect(restored, isTrue, reason: 'restore un-maximizes the real window');
    await rec.hold(const Duration(seconds: 1));

    await tester.sendKeyEvent(LogicalKeyboardKey.f11);
    final bool wentFull = await waitFor(() => window.isFullScreen);
    await settle(tester, frames: 20);
    expect(wentFull, isTrue, reason: 'F11 puts the real window in fullscreen');
    await rec.hold(const Duration(seconds: 1));
    await tester.sendKeyEvent(LogicalKeyboardKey.f11);
    final bool leftFull = await waitFor(() => !window.isFullScreen);
    await settle(tester, frames: 20);
    expect(leftFull, isTrue);

    // --- 5. close asks about the dirty level --------------------------------
    vm.spawnNewActor('PointLight');
    await settle(tester, frames: 10);
    await tester.tap(find.byKey(const ValueKey<String>('window_control_close')));
    await settle(tester, frames: 20);
    expect(find.byKey(const ValueKey<String>('quit_unsaved_prompt')), findsOneWidget);
    await rec.hold(const Duration(seconds: 2));
    SmokeArtifacts.saveScreenshot('$testName — close asks about the unsaved level',
        await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey)), usedAssets: usedAssets);
    await tester.tap(find.byKey(const ValueKey<String>('quit_unsaved_cancel')));
    await settle(tester, frames: 20);
    expect(find.byKey(const ValueKey<String>('quit_unsaved_prompt')), findsNothing, reason: 'Cancel keeps the editor open');
    await rec.hold(const Duration(seconds: 1));
    rec.save(testName, usedAssets: usedAssets);
    // Hand the integration-test window back to the runner as it found it.
    await tester.runAsync(() => windowManager.setPreventClose(false));

    // ignore: avoid_print
    print(report);
    expect(failures, isEmpty, reason: '${failures.join('\n')}\n$report');
  }, timeout: const Timeout(Duration(minutes: 8)));

  testWidgets('Design System Smoke: editor themes', (WidgetTester tester) async {
    const String testName = 'Design System Smoke: editor themes';
    final Directory tempDir = Directory.systemTemp.createTempSync('design_system_themes_smoke_');
    final Directory pDir = Directory('${tempDir.path}/ThemeSmoke')..createSync(recursive: true);
    Directory('${pDir.path}/contents/meshes').createSync(recursive: true);
    Directory('${pDir.path}/contents/levels').createSync(recursive: true);
    File('${pDir.path}/ThemeSmoke.lmproject').writeAsStringSync('{}');
    final Directory configDir = Directory('${tempDir.path}/config')..createSync();
    addTearDown(() {
      EditorTheme.apply(EditorThemeData.luminaDark);
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
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
          png, Rect.fromLTWH(menuRow.left + 700, menuRow.top + 4, 200, 22), dpr: dpr);
      final Rect tab = tester.getRect(find.byKey(const ValueKey<String>('workspace_tab_0')));
      final ({int rgb, int count, int total}) tabFill = dominantColorIn(
          png, Rect.fromLTWH(tab.left + 3, tab.top + 4, tab.width - 6, tab.height - 6), dpr: dpr);
      final int wantBody = theme.color('background').toARGB32() & 0xFFFFFF;
      final int wantHeader = theme.color('cardHeader').toARGB32() & 0xFFFFFF;
      report.writeln('  ${theme.name}: outliner body ${hex(body.rgb)} (${body.count}/${body.total}, expected ${hex(wantBody)}), '
          'header ${hex(header.rgb)} (expected ${hex(wantHeader)}), title bar ${hex(title.rgb)}');
      if (body.rgb != wantBody) failures.add('${theme.name}: outliner body ${hex(body.rgb)} != ${hex(wantBody)}');
      if (header.rgb != wantHeader) failures.add('${theme.name}: outliner header ${hex(header.rgb)} != ${hex(wantHeader)}');
      if (title.rgb != wantHeader) failures.add('${theme.name}: title bar ${hex(title.rgb)} != ${hex(wantHeader)}');
      report.writeln('    active workspace tab (BoxDecoration) ${hex(tabFill.rgb)} (${tabFill.count}/${tabFill.total})');
      if (tabFill.rgb != wantHeader) failures.add('${theme.name}: active tab fill ${hex(tabFill.rgb)} != ${hex(wantHeader)}');
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
}

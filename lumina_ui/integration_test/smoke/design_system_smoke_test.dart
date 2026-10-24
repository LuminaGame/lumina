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
import 'package:lumina_editor_data/lumina_editor.dart';
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
import 'package:lumina_ui/ui/core/widgets/lumina_logo.dart';
import 'package:lumina_ui/ui/core/widgets/typed_tab_bar.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sub_editor_3d_viewport.dart';
import 'package:lumina_ui/ui/core/widgets/viewport_pills.dart';
import 'package:lumina_ui/ui/core/widgets/editor_island.dart';
import 'package:lumina_ui/ui/features/main_editor/views/content_drawer.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/static_mesh_sub_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/skeletal_mesh/skeletal_mesh_sub_editor.dart';
import 'package:lumina_ui/ui/features/launcher/view_models/launcher_view_model.dart';
import 'package:lumina_ui/ui/features/launcher/views/launcher_view.dart';
import 'package:lumina_ui/ui/features/launcher/views/lumina_splash_screen.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The prototype's retired predecessors. None of these may survive anywhere in
/// the editor's chrome.
const Map<String, int> retiredPalette = <String, int>{
  // The pre-prototype #0F0F12 and #16161B are left out: they sit within two
  // steps of the Aurora ramp (#0F1013, #15171B), so antialiased edges
  // between Aurora surfaces land on them and they no longer tell anything.
  'old border #282832': 0x282832,
  'old accent #FF8C00': 0xFF8C00,
  // The lifted grey ramp and orange that Aurora replaced.
  'grey ramp background #1C1C1C': 0x1C1C1C,
  'grey ramp card #373737': 0x373737,
  'grey ramp header #2E2E2E': 0x2E2E2E,
  'grey ramp primary #FB7C01': 0xFB7C01,
};

/// The tokens that are actually painted as flat fills: the Aurora ramp and
/// its amber.
Map<String, int> paintedTokens() => <String, int>{
      'background': EditorColors.background.toARGB32() & 0xFFFFFF,
      'sidebar (tab strips)': EditorColors.sidebar.toARGB32() & 0xFFFFFF,
      'card': EditorColors.card.toARGB32() & 0xFFFFFF,
      'panel header': EditorColors.cardHeader.toARGB32() & 0xFFFFFF,
      'rail': EditorColors.rail.toARGB32() & 0xFFFFFF,
      'primary (amber)': EditorColors.primary.toARGB32() & 0xFFFFFF,
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

/// Deletes a smoke's temp project. On Windows a level save that the view
/// model's dispose started may still hold a file in it, so the delete waits
/// and retries for a few seconds instead of failing a passed scenario.
Future<void> deleteTempProject(Directory dir) async {
  for (int attempt = 0; attempt < 20; attempt++) {
    if (!dir.existsSync()) return;
    try {
      dir.deleteSync(recursive: true);
      return;
    } on FileSystemException {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
  }
  // ignore: avoid_print
  print('The temp project ${dir.path} is still locked; left for the OS to clean up.');
}

/// [png] cropped to [r] (logical pixels at [dpr]).
Uint8List _cropTo(Uint8List png, Rect r, double dpr) {
  final img.Image im = img.decodePng(png)!;
  final int x = (r.left * dpr).round().clamp(0, im.width - 1);
  final int y = (r.top * dpr).round().clamp(0, im.height - 1);
  final int w = (r.width * dpr).round().clamp(1, im.width - x);
  final int h = (r.height * dpr).round().clamp(1, im.height - y);
  return Uint8List.fromList(img.encodePng(img.copyCrop(im, x: x, y: y, width: w, height: h)));
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
      'Design System Smoke: the main view is painted in the Aurora palette',
      (WidgetTester tester) async {
    // --- a real project on disk, with real assets --------------------------
    final Directory tempDir =
        Directory.systemTemp.createTempSync('design_system_smoke_');
    final Directory pDir = Directory('${tempDir.path}/DesignSystemSmoke')
      ..createSync(recursive: true);
    Directory('${pDir.path}/contents/meshes').createSync(recursive: true);
    Directory('${pDir.path}/contents/levels').createSync(recursive: true);
    File('${pDir.path}/DesignSystemSmoke.lmproject').writeAsStringSync('{}');
    addTearDown(() => deleteTempProject(tempDir));

    const List<String> assetRels = <String>[
      'Props/AC_units/roof_aircon_unit_150x150_a.glb',
      'Props/Barrels/fuel_barrel_red.glb',
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
        '(expected ${hex(EditorColors.sidebar.toARGB32() & 0xFFFFFF)}, the island fill)');

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

    // Every named surface carries at most the Obsidian cast (blue a few
    // steps over red, at most 8/255); a real hue means another palette is back.
    final Map<String, int> namedSurfaces = <String, int>{
      'World Outliner header': header.rgb,
      if (rail != null) 'Content Browser sources rail': rail.rgb,
    };
    final List<String> tintedSurfaces = <String>[];
    namedSurfaces.forEach((String name, int rgb) {
      final int c = chromaOf(rgb);
      report.writeln('  chroma of $name ${hex(rgb)}: $c');
      if (c > 8) tintedSurfaces.add('$name ${hex(rgb)} chroma=$c');
    });

    // ignore: avoid_print
    print(report.toString());

    // --- evidence ----------------------------------------------------------
    SmokeArtifacts.saveScreenshot(
      'Design System Smoke: the main view is painted in the Aurora palette',
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
      'Design System Smoke: the main view is painted in the Aurora palette',
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
        reason: 'the Aurora neutrals carry only the Obsidian cast:\n'
            '${tintedSurfaces.join('\n')}\n$report');
    expect(header.rgb, EditorColors.sidebar.toARGB32() & 0xFFFFFF,
        reason: 'the World Outliner header sits on its island fill (EditorColors.sidebar)\n$report');
  }, timeout: const Timeout(Duration(minutes: 8)));

  testWidgets('Design System Smoke: custom chrome and Aurora surfaces', (WidgetTester tester) async {
    const String testName = 'Design System Smoke: custom chrome and Aurora surfaces';
    // --- a real project on disk, with real assets --------------------------
    final Directory tempDir = Directory.systemTemp.createTempSync('design_system_chrome_smoke_');
    final Directory pDir = Directory('${tempDir.path}/ChromeSmoke')..createSync(recursive: true);
    Directory('${pDir.path}/contents/meshes').createSync(recursive: true);
    Directory('${pDir.path}/contents/levels').createSync(recursive: true);
    File('${pDir.path}/ChromeSmoke.lmproject').writeAsStringSync('{}');
    final Directory configDir = Directory('${tempDir.path}/config')..createSync();
    addTearDown(() => deleteTempProject(tempDir));
    const List<String> assetRels = <String>[
      'Props/Access_cards/access_card_blue.glb',
      'Props/Barrels/fuel_barrel_red.glb',
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
    final Rect menuBar = Rect.fromLTWH(menuRow.left, menuRow.top, menuRow.width, MenuBarWidget.height);
    for (final String k in <String>['window_control_minimize', 'window_control_maximize', 'window_control_fullscreen', 'window_control_close']) {
      expect(find.byKey(ValueKey<String>(k)), findsOneWidget, reason: '$k in the menu row');
    }
    final Rect close = tester.getRect(find.byKey(const ValueKey<String>('window_control_close')));
    report.writeln('  close button right edge ${close.right.toStringAsFixed(0)} of menu row ${menuBar.right.toStringAsFixed(0)}');
    measure('menu row (title bar)', full, Rect.fromLTWH(menuBar.left + 560, menuBar.top + 4, 80, 40), EditorColors.rail);
    SmokeArtifacts.saveScreenshot('$testName — menu row with window controls', crop(full, menuBar), usedAssets: usedAssets);

    // --- 2. the typed tab strip: the active tab on the island fill with
    // the level type's underline; the strip itself on the rail.
    final Rect tab = tester.getRect(find.byKey(const ValueKey<String>('workspace_tab_0')));
    final Rect strip = tester.getRect(find.byType(EditorTypedTabBar));
    measure('workspace tab strip', full, Rect.fromLTWH(tab.right + 60, strip.top + 2, 300, strip.height - 6), EditorColors.rail);
    measure('active workspace tab fill', full, Rect.fromLTWH(tab.left + 2, tab.top + 3, tab.width - 4, tab.height - 6), EditorColors.sidebar);
    measure('underline under the active tab', full, Rect.fromLTWH(tab.left + 3, tab.bottom - 2, tab.width - 6, 2), EditorColors.assetTypeLevel);
    SmokeArtifacts.saveScreenshot('$testName — typed tab strip, the level tab underlined',
        crop(full, Rect.fromLTWH(strip.left, strip.top - 2, 700, strip.height + 40)), usedAssets: usedAssets);

    // --- 3. the lifted panels ----------------------------------------------
    final Rect outliner = tester.getRect(find.byType(OutlinerWidget));
    final Rect details = tester.getRect(find.byType(DetailsWidget));
    measure('World Outliner header', full,
        Rect.fromLTWH(outliner.left + 2, outliner.top + 2, outliner.width - 4, EditorDensity.panelHeaderHeight - 4), EditorColors.sidebar);
    measure('World Outliner body', full,
        Rect.fromLTWH(outliner.left + 4, outliner.bottom - 60, outliner.width - 8, 50), EditorColors.sidebar);
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
}

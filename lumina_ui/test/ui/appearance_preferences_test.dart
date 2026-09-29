import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart' hide BoxShape;
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme_data.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme_store.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/main_editor/views/menu_bar_widget.dart';
import 'package:lumina_ui/ui/features/main_editor/views/outliner_widget.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/appearance_preferences_page.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Edit → Editor Preferences → Appearance picks, duplicates,
/// edits, imports and exports JSON themes, and a switch recolours the running
/// editor without a restart — checked on rendered pixels, not only on the
/// token values.
void main() {
  late Directory config;
  late EditorThemeController themes;

  setUp(() {
    config = Directory.systemTemp.createTempSync('lumina_appearance_');
    themes = EditorThemeController(store: EditorThemeStore(configDir: config));
  });
  tearDown(() {
    EditorTheme.resetForTest();
    AppearanceFilePickers.reset();
    if (config.existsSync()) config.deleteSync(recursive: true);
  });

  Future<void> settle(WidgetTester tester, {int frames = 12}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  final boundary = GlobalKey();

  Future<EditorViewModel> pumpEditor(WidgetTester tester) async {
    final dir = Directory.systemTemp.createTempSync('lumina_appearance_editor_');
    addTearDown(() => dir.deleteSync(recursive: true));
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final vm = EditorViewModel(
      initialProject: const LuminaProject(projectName: 'ThemeGame'),
      projectLocation: dir.path,
      enableTimers: false,
      autoInitAssets: false,
    );
    addTearDown(vm.dispose);
    await tester.pumpWidget(RepaintBoundary(
      key: boundary,
      child: EditorThemeScope(
        controller: themes,
        child: Builder(
          builder: (context) {
            EditorThemeScope.of(context);
            return ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm));
          },
        ),
      ),
    ));
    await settle(tester);
    return vm;
  }

  Future<ui.Image> capture(WidgetTester tester) async {
    final render = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    return (await tester.runAsync(() => render.toImage()))!;
  }

  /// The most common colour inside [rect] of [image].
  Future<int> dominant(WidgetTester tester, ui.Image image, Rect rect, {int? excluding}) async {
    final ByteData bytes = (await tester.runAsync(() async => (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!))!;
    final counts = <int, int>{};
    for (var y = rect.top.round(); y < rect.bottom.round(); y++) {
      for (var x = rect.left.round(); x < rect.right.round(); x++) {
        final i = (y * image.width + x) * 4;
        final rgb = (bytes.getUint8(i) << 16) | (bytes.getUint8(i + 1) << 8) | bytes.getUint8(i + 2);
        if (rgb == excluding) continue;
        counts[rgb] = (counts[rgb] ?? 0) + 1;
      }
    }
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  int rgbOf(EditorThemeData t, String token) => t.color(token).toARGB32() & 0xFFFFFF;

  Future<void> openAppearance(WidgetTester tester, EditorViewModel vm) async {
    vm.openSubEditorTab('editorPreferences', title: 'Editor Preferences');
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('editor_prefs_category_appearance')));
    await settle(tester);
    expect(find.byType(AppearancePreferencesPage), findsOneWidget);
  }

  testWidgets('switching Lumina Dark → Lumina Light recolours the outliner and the menu bar text without restart', (tester) async {
    final vm = await pumpEditor(tester);
    final outliner = tester.getRect(find.byType(OutlinerWidget));
    final body = Rect.fromLTWH(outliner.left + 6, outliner.bottom - 50, outliner.width - 12, 40);
    final title = tester.getRect(find.text('Lumina Studio'));
    var shot = await capture(tester);
    expect(await dominant(tester, shot, body), rgbOf(EditorThemeData.luminaDark, 'background'));
    final darkHeader = rgbOf(EditorThemeData.luminaDark, 'cardHeader');
    expect(await dominant(tester, shot, title, excluding: darkHeader), rgbOf(EditorThemeData.luminaDark, 'foreground'));

    await openAppearance(tester, vm);
    await tester.tap(find.byKey(const ValueKey('appearance_theme_Lumina Light')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('appearance_apply')));
    await settle(tester);
    expect(themes.activeName, 'Lumina Light');
    vm.selectTab(0);
    await settle(tester);

    shot = await capture(tester);
    expect(await dominant(tester, shot, body), rgbOf(EditorThemeData.luminaLight, 'background'),
        reason: 'the outliner body is repainted in the new theme');
    final lightHeader = rgbOf(EditorThemeData.luminaLight, 'cardHeader');
    expect(await dominant(tester, shot, title, excluding: lightHeader), rgbOf(EditorThemeData.luminaLight, 'foreground'),
        reason: 'the menu bar text is re-laid out in the new foreground (a paragraph keeps the colour it was built with)');
    // A box decoration caches its Paint: the menu bar's level chip (a const
    // BoxDecoration filled with background, so the rebuilt widget compares
    // equal and keeps its painter) must be repainted too.
    final chip = tester.getRect(find.ancestor(
      of: find.descendant(of: find.byType(MenuBarWidget), matching: find.byIcon(LucideIcons.map)),
      matching: find.byType(Container),
    ).first);
    expect(await dominant(tester, shot, Rect.fromLTWH(chip.left + 2, chip.top + 2, 5, chip.height - 4)),
        rgbOf(EditorThemeData.luminaLight, 'background'),
        reason: 'decorated boxes drop their cached paint on a theme switch');
    final prefs = jsonDecode(File('${config.path}/editor_preferences.json').readAsStringSync()) as Map;
    expect(prefs['theme'], 'Lumina Light', reason: 'remembered for the next start');
  });

  testWidgets('duplicate, set primary to #22C55E and apply: saved to themes/<name>.json and primary buttons recolour', (tester) async {
    final vm = await pumpEditor(tester);
    await openAppearance(tester, vm);
    await tester.tap(find.byKey(const ValueKey('appearance_theme_Lumina Dark')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('appearance_duplicate')));
    await settle(tester);
    expect(themes.byName('Lumina Dark Copy'), isNotNull);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('appearance_token_primary')),
      300,
      scrollable: find.descendant(of: find.byKey(const ValueKey('appearance_tokens')), matching: find.byType(Scrollable)).first,
    );
    await settle(tester);
    final field = find.descendant(of: find.byKey(const ValueKey('appearance_token_primary')), matching: find.byType(TextField));
    await tester.tap(field);
    await tester.pump();
    await tester.enterText(field, '#22C55E');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('appearance_apply')),
      -300,
      scrollable: find.descendant(of: find.byKey(const ValueKey('appearance_tokens')), matching: find.byType(Scrollable)).first,
    );
    await settle(tester);
    expect(find.textContaining('unsaved edits'), findsOneWidget, reason: 'the edit is a draft until Apply');
    await tester.tap(find.byKey(const ValueKey('appearance_apply')));
    await settle(tester, frames: 20);

    final file = File('${config.path}/themes/Lumina_Dark_Copy.json');
    expect(file.existsSync(), isTrue);
    final saved = jsonDecode(file.readAsStringSync()) as Map;
    expect((saved['colors'] as Map)['primary'], '#22C55E');
    expect(themes.activeName, 'Lumina Dark Copy');
    expect(EditorColors.primary.toARGB32(), 0xFF22C55E);

    final context = tester.element(find.byKey(const ValueKey('appearance_apply')));
    expect(Theme.of(context).colorScheme.primary.toARGB32(), 0xFF22C55E, reason: 'shadcn\'s theme follows');
    final shot = await capture(tester);
    final button = tester.getRect(find.byKey(const ValueKey('appearance_apply')));
    final painted = await dominant(tester, shot, button.deflate(2));
    // The just-pressed button still blends its hover overlay a few levels in,
    // so compare per channel; the old orange is 0xFB7C01.
    int channelDistance(int a, int b) => [16, 8, 0].map((s) => (((a >> s) & 0xFF) - ((b >> s) & 0xFF)).abs()).reduce((x, y) => x > y ? x : y);
    expect(channelDistance(painted, 0x22C55E), lessThanOrEqualTo(12),
        reason: 'the Apply primary button is painted green, not orange (got 0x${painted.toRadixString(16)})');
  });

  testWidgets('export writes the JSON; importing it back lists the theme', (tester) async {
    final vm = await pumpEditor(tester);
    final exportFile = File('${config.path}/out/Exported.json');
    AppearanceFilePickers.pickExportFile = (suggested) async => exportFile;
    await openAppearance(tester, vm);
    await tester.tap(find.byKey(const ValueKey('appearance_theme_Lumina Classic')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('appearance_export')));
    await settle(tester);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await settle(tester);
    expect(exportFile.existsSync(), isTrue);
    expect(exportFile.readAsStringSync(), EditorThemeData.luminaClassic.encode());

    // Rename the exported theme on disk so the import is a new theme.
    final shared = File('${config.path}/out/Shared Classic.json')
      ..writeAsStringSync(exportFile.readAsStringSync().replaceFirst('"Lumina Classic"', '"Shared Classic"'));
    AppearanceFilePickers.pickImportFile = () async => shared;
    await tester.tap(find.byKey(const ValueKey('appearance_import')));
    await settle(tester);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await settle(tester);
    expect(themes.byName('Shared Classic'), isNotNull);
    expect(find.byKey(const ValueKey('appearance_theme_Shared Classic')), findsOneWidget, reason: 'listed on the page');
    expect(File('${config.path}/themes/Shared_Classic.json').existsSync(), isTrue);
  });
}

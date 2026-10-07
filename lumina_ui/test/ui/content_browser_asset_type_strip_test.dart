import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart' hide BoxShape;
import 'package:lumina_ui/ui/core/property_editors/asset_picker_select.dart';
import 'package:lumina_ui/ui/core/services/content_folders.dart';
import 'package:lumina_ui/ui/core/theme/asset_type_style.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme_data.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme_store.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/content_browser_widget.dart';
import 'package:lumina_ui/ui/features/source_control/services/git_service.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Every asset tile carries a strip in its
/// asset type's colour under the thumbnail, and the type's name under the
/// asset name. Everything runs on a real temp project on disk.
void main() {
  late Directory root;
  late String dir;
  const name = 'strip_proj';

  /// One real `.lmas` per kind the browser knows, with the display name the
  /// tile must show.
  const kinds = <String, (AssetType, String, String)>{
    'SKM_Hero': (AssetType.filameshSk, 'Skeletal Mesh', 'assetTypeSkeletalMesh'),
    'SM_Crate': (AssetType.filamesh, 'Static Mesh', 'assetTypeStaticMesh'),
    'Idle': (AssetType.animation, 'Animation Sequence', 'assetTypeAnimation'),
    'M_Wood': (AssetType.filamat, 'Material', 'assetTypeMaterial'),
    'BP_Door': (AssetType.actor, 'Blueprint Class', 'assetTypeBlueprint'),
    'ABP_Hero': (AssetType.animBlueprint, 'Animation Blueprint', 'assetTypeAnimBlueprint'),
    'BS_Walk': (AssetType.blendSpace, 'Blend Space', 'assetTypeBlendSpace'),
    'PHYS_Hero': (AssetType.physicsAsset, 'Physics Asset', 'assetTypePhysicsAsset'),
    'L_Main': (AssetType.level, 'Level', 'assetTypeLevel'),
    'T_Wood': (AssetType.texture, 'Texture', 'assetTypeTexture'),
    'S_Step': (AssetType.audio, 'Sound', 'assetTypeAudio'),
    'WBP_Hud': (AssetType.widget, 'Widget Blueprint', 'assetTypeWidget'),
    'PS_Sparks': (AssetType.particle, 'Particle System', 'assetTypeParticle'),
    'LS_Hills': (AssetType.landscape, 'Landscape', 'assetTypeLandscape'),
    'SEQ_Intro': (AssetType.sequencer, 'Level Sequence', 'assetTypeSequencer'),
  };

  setUp(() {
    root = Directory.systemTemp.createTempSync('lumina_cb_strip_');
    dir = '${root.path}/$name';
    Directory(dir).createSync(recursive: true);
    File('$dir/$name.lmproject').writeAsStringSync(jsonEncode({'project_name': name}));
    ContentFolders.writeMarker((Directory('$dir/contents/props')..createSync(recursive: true)).path);
    for (final e in kinds.entries) {
      File('$dir/contents/${e.key}.lmas')
          .writeAsBytesSync(LuminaAsset(assetId: 'asset_${e.key}', name: e.key, type: e.value.$1).toProtoBufferBytes());
    }
  });
  tearDown(() {
    EditorTheme.resetForTest();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  EditorViewModel newVm() => EditorViewModel(
        initialProject: const LuminaProject(projectName: name),
        projectLocation: root.path,
        enableTimers: false,
        autoInitAssets: false,
      )..refreshAssets();

  Future<EditorViewModel> openBrowser(WidgetTester tester, {EditorViewModel? existing}) async {
    tester.view.physicalSize = const Size(1700, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final vm = existing ?? newVm();
    addTearDown(vm.dispose);
    vm.selectedFolder = 'contents';
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(
        child: ListenableBuilder(
          listenable: vm,
          builder: (context, _) => SizedBox(width: 1600, height: 800, child: ContentBrowserWidget(viewModel: vm)),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    return vm;
  }

  String pathOf(EditorViewModel vm, String base) => vm.realAssets.firstWhere((a) => a.fileName == '$base.lmas').relativePath;
  Finder strip(String path) => find.byKey(ValueKey('asset_type_strip_$path'));
  Finder label(String path) => find.byKey(ValueKey('asset_type_label_$path'));
  Finder card(String path) => find.byKey(ValueKey('asset_tile_card_$path'));
  int stripArgb(WidgetTester tester, String path) =>
      tester.widget<ColoredBox>(find.descendant(of: strip(path), matching: find.byType(ColoredBox))).color.toARGB32();
  String hex(int v) => '0x${v.toRadixString(16).toUpperCase()}';

  testWidgets('every asset tile paints its kind\'s token as a 3 px strip under the thumbnail', (tester) async {
    final vm = await openBrowser(tester);
    for (final e in kinds.entries) {
      final path = pathOf(vm, e.key);
      expect(strip(path), findsOneWidget, reason: e.key);
      final token = EditorColors.token(e.value.$3);
      expect(stripArgb(tester, path), token.toARGB32(),
          reason: '${e.key} strip is ${hex(stripArgb(tester, path))}, ${e.value.$3} is ${hex(token.toARGB32())}');
      expect(AssetTypeStyle.of(e.value.$1).color.toARGB32(), token.toARGB32());
      final s = tester.getRect(strip(path));
      final c = tester.getRect(card(path));
      expect(s.height, 3, reason: e.key);
      expect(s.width, closeTo(c.width - 2, 1.0), reason: 'spans the tile inside its 1 px border');
      final nameRect = tester.getRect(find.descendant(of: card(path), matching: find.text(e.key)));
      expect(s.bottom, lessThanOrEqualTo(nameRect.top + 0.5), reason: 'the strip sits above the name');
      expect(s.top, greaterThan(c.top + c.height / 3), reason: 'the strip sits under the thumbnail');
    }
  });

  testWidgets('each tile names its type under its name; the size moves off the tile', (tester) async {
    final vm = await openBrowser(tester);
    for (final e in kinds.entries) {
      final path = pathOf(vm, e.key);
      expect(tester.widget<Text>(label(path)).data, e.value.$2, reason: e.key);
      final a = vm.realAssets.firstWhere((x) => x.relativePath == path);
      expect(find.descendant(of: card(path), matching: find.text(a.formattedSize)), findsNothing, reason: e.key);
      final style = tester.widget<Text>(label(path)).style!;
      expect(style.color!.toARGB32(), EditorColors.mutedForeground.toARGB32());
    }
  });

  testWidgets('a folder tile has no strip and no type label', (tester) async {
    await openBrowser(tester);
    final folder = find.byKey(const ValueKey('folder_tile_contents/props'));
    expect(folder, findsOneWidget);
    expect(find.descendant(of: folder, matching: find.byType(AssetTypeStrip)), findsNothing);
    expect(
        find.descendant(
            of: folder,
            matching: find.byWidgetPredicate(
                (w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('asset_type_'))),
        findsNothing);
  });

  testWidgets('switching to Lumina Light recolours the strips to that theme\'s tokens', (tester) async {
    final vm = await openBrowser(tester);
    final mesh = pathOf(vm, 'SM_Crate');
    expect(stripArgb(tester, mesh), 0xFF00C8C8);
    EditorTheme.apply(EditorThemeData.luminaLight);
    await tester.pump();
    expect(stripArgb(tester, mesh), 0xFF00989B);
    for (final e in kinds.entries) {
      final light = EditorThemeData.luminaLight.color(e.value.$3).toARGB32();
      expect(light, isNot(EditorThemeData.luminaDark.color(e.value.$3).toARGB32()), reason: '${e.value.$3} is tuned for Light');
      expect(stripArgb(tester, pathOf(vm, e.key)), light, reason: e.key);
    }
  });

  testWidgets('hovering a tile shows a TooltipContainer with the type swatch, name and size', (tester) async {
    final vm = await openBrowser(tester);
    final path = pathOf(vm, 'SKM_Hero');
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);
    await gesture.addPointer(location: Offset.zero);
    await gesture.moveTo(tester.getCenter(card(path)));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 300));
    final tip = find.byType(TooltipContainer);
    expect(tip, findsOneWidget);
    final swatch = find.descendant(of: tip, matching: find.byType(AssetTypeSwatch));
    expect(swatch, findsOneWidget);
    final box = tester.widget<Container>(find.descendant(of: swatch, matching: find.byType(Container)).first);
    expect((box.decoration as BoxDecoration).color!.toARGB32(), EditorColors.assetTypeSkeletalMesh.toARGB32());
    expect(find.descendant(of: tip, matching: find.text('Skeletal Mesh')), findsOneWidget);
    expect(find.descendant(of: tip, matching: find.text('SKM_Hero')), findsOneWidget);
    final a = vm.realAssets.firstWhere((x) => x.relativePath == path);
    expect(find.descendant(of: tip, matching: find.textContaining(a.formattedSize)), findsOneWidget);
  });

  testWidgets('a selected tile keeps its selection border around the strip', (tester) async {
    final vm = await openBrowser(tester);
    final path = pathOf(vm, 'Idle');
    await tester.tap(find.byKey(ValueKey('asset_item_$path')));
    await tester.pump(const Duration(milliseconds: 400));
    final deco = tester.widget<Container>(card(path)).decoration as BoxDecoration;
    final border = deco.border as Border;
    expect(border.top.color.toARGB32(), EditorColors.primary.toARGB32());
    expect(border.top.width, 1.8);
    final s = tester.getRect(strip(path));
    final c = tester.getRect(card(path));
    expect(s.left, greaterThanOrEqualTo(c.left + 1.8 - 0.01), reason: 'inside the selection border');
    expect(s.right, lessThanOrEqualTo(c.right - 1.8 + 0.01));
    expect(stripArgb(tester, path), EditorColors.assetTypeAnimation.toARGB32(), reason: 'selection does not recolour the strip');
  });

  testWidgets('a source-control badge stays in the corner, clear of the strip', (tester) async {
    if ((await tester.runAsync(() => Process.run('git', ['--version'])))!.exitCode != 0) return;
    final seeded = (await tester.runAsync(() async {
      final vm = newVm();
      await vm.sourceControl.service.init(gitignoreContent: GitService.defaultGitignore, initialCommitMessage: 'init');
      File('$dir/contents/SM_Crate.lmas').writeAsBytesSync(
          LuminaAsset(assetId: 'asset_SM_Crate', name: 'SM_Crate_v2', type: AssetType.filamesh).toProtoBufferBytes());
      await vm.sourceControl.refresh();
      await vm.sourceControl.whenIdle;
      return vm;
    }))!;
    final vm = await openBrowser(tester, existing: seeded);
    vm.refreshAssets();
    await tester.pump(const Duration(milliseconds: 200));
    final path = pathOf(vm, 'SM_Crate');
    final badge = find.byKey(ValueKey('sc_badge_$path'));
    expect(badge, findsOneWidget);
    expect(find.descendant(of: badge, matching: find.text('M')), findsOneWidget);
    final b = tester.getRect(badge);
    final s = tester.getRect(strip(path));
    final c = tester.getRect(card(path));
    expect(b.overlaps(s), isFalse);
    expect(b.top, lessThan(c.top + 10), reason: 'top-right corner');
    expect(b.right, greaterThan(c.right - 10));
  });

  testWidgets('the filter chips carry a swatch in each kind\'s colour', (tester) async {
    await openBrowser(tester);
    for (final e in kinds.values) {
      final chip = find.byKey(ValueKey('asset_type_filter_swatch_${e.$1.name}'));
      expect(chip, findsOneWidget, reason: e.$1.name);
      final box = tester.widget<Container>(find.descendant(of: chip, matching: find.byType(Container)).first);
      expect((box.decoration as BoxDecoration).color!.toARGB32(), EditorColors.token(e.$3).toARGB32());
    }
  });

  testWidgets('an asset picker thumbnail draws the type strip along its bottom edge', (tester) async {
    final vm = newVm();
    addTearDown(vm.dispose);
    final wood = vm.realAssets.firstWhere((a) => a.fileName == 'M_Wood.lmas');
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(
        child: Row(children: [
          AssetThumbnail(key: const ValueKey('with'), asset: wood, size: 24),
          const AssetThumbnail(key: ValueKey('without'), asset: null, size: 24),
        ]),
      ),
    ));
    final s = find.descendant(of: find.byKey(const ValueKey('with')), matching: find.byType(AssetTypeStrip));
    expect(s, findsOneWidget);
    expect(tester.widget<ColoredBox>(find.descendant(of: s, matching: find.byType(ColoredBox))).color.toARGB32(),
        EditorColors.assetTypeMaterial.toARGB32());
    final thumb = tester.getRect(find.byKey(const ValueKey('with')));
    expect(tester.getRect(s).bottom, closeTo(thumb.bottom - 1, 1.01), reason: 'the bottom edge, inside the border');
    expect(find.descendant(of: find.byKey(const ValueKey('without')), matching: find.byType(AssetTypeStrip)), findsNothing);
  });

  test('every asset kind has a style; the tokens are theme slots in the Asset types group', () {
    for (final t in AssetType.values) {
      final s = AssetTypeStyle.of(t);
      expect(s.displayName, isNotEmpty);
      expect(s.filterLabel, isNotEmpty);
    }
    for (final e in kinds.values) {
      final token = EditorThemeData.tokens.firstWhere((t) => t.key == e.$3);
      expect(token.group, EditorThemeData.assetTypes);
      expect(EditorColors.all.containsKey(e.$3), isTrue);
    }
    expect(EditorThemeData.groups, contains(EditorThemeData.assetTypes));
    // Unchanged chip labels.
    expect(AssetTypeStyle.of(AssetType.filamesh).filterLabel, 'Mesh');
    expect(AssetTypeStyle.of(AssetType.filamat).filterLabel, 'Material');
    expect(AssetTypeStyle.of(AssetType.actor).filterLabel, 'Blueprint');
    expect(AssetTypeStyle.of(AssetType.filameshSk).filterLabel, 'filameshSk');
    expect(EditorTheme.current, EditorThemeData.luminaDark);
  });
}

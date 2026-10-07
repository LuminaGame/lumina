import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/content_browser_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Right-clicking an asset tile shows the asset's menu only. With shadcn's
/// ContextMenu the tile's menu and the grid background's menu (nested around
/// it) both opened, stacked on top of each other.
void main() {
  late Directory projectDir;
  late EditorViewModel vm;

  setUp(() {
    projectDir = Directory.systemTemp.createTempSync('lumina_cb_menu_');
    const name = 'cb_menu';
    final dir = Directory('${projectDir.path}/$name')..createSync(recursive: true);
    File('${dir.path}/$name.lmproject').writeAsStringSync('{"project_name": "$name"}');
    final contents = Directory('${dir.path}/contents')..createSync(recursive: true);
    File('${contents.path}/SM_Box.lmas')
        .writeAsBytesSync(const LuminaAsset(assetId: 'box-id', name: 'SM_Box', type: AssetType.filamesh).toProtoBufferBytes());
    vm = EditorViewModel(
      initialProject: const LuminaProject(projectName: name),
      projectLocation: projectDir.path,
      enableTimers: false,
      autoInitAssets: false,
    );
    vm.refreshAssets();
  });
  tearDown(() {
    vm.dispose();
    if (projectDir.existsSync()) projectDir.deleteSync(recursive: true);
  });

  // The tile key carries the asset's path on disk.
  Finder boxTile() => find.byWidgetPredicate((w) {
        final k = w.key;
        return k is ValueKey<String> && k.value.startsWith('asset_item_') && k.value.endsWith('SM_Box.lmas');
      });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(child: ContentBrowserWidget(viewModel: vm)),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('right-clicking an asset opens only the asset menu', (tester) async {
    await pump(tester);
    final tile = boxTile();
    expect(tile, findsOneWidget);
    final at = tester.getCenter(tile);
    await tester.tapAt(at, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    expect(find.byType(DropdownMenu), findsOneWidget, reason: 'one menu, not the tile menu plus the background menu');
    expect(find.text('Open Sub-Editor'), findsOneWidget);
    expect(find.text('Refresh Assets'), findsNothing, reason: 'the background menu must not open for a tile click');
    // The menu opens at the pointer.
    expect((tester.getTopLeft(find.byType(DropdownMenu)) - at).distance, lessThan(80));
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('right-clicking empty grid space opens the background menu', (tester) async {
    await pump(tester);
    final tile = boxTile();
    final empty = tester.getBottomRight(tile) + const Offset(400, 120);
    await tester.tapAt(empty, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    expect(find.byType(DropdownMenu), findsOneWidget);
    expect(find.text('Refresh Assets'), findsOneWidget);
    expect(find.text('Open Sub-Editor'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
}

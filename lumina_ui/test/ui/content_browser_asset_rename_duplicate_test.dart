import 'dart:io';

import 'package:flutter/gestures.dart' show kSecondaryMouseButton;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/content_browser_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../helpers/temp_project.dart';

/// Asset cards had no Rename / Duplicate although both were planned.
/// No mocks: a real temp project with a real `.lmas`
/// and a placed actor that references it by path.
void main() {
  late Directory projectDir;
  late Directory dir;
  late EditorViewModel vm;
  late File box;

  setUp(() {
    projectDir = Directory.systemTemp.createTempSync('lumina_cb_rename_');
    const name = 'cb_rename';
    dir = Directory('${projectDir.path}/$name')..createSync(recursive: true);
    File('${dir.path}/$name.lmproject').writeAsStringSync('{"project_name": "$name"}');
    final meshes = Directory('${dir.path}/contents/meshes')..createSync(recursive: true);
    box = File('${meshes.path}/SM_Box.lmas')
      ..writeAsBytesSync(const LuminaAsset(assetId: 'box-id', name: 'SM_Box', type: AssetType.filamesh).toProtoBufferBytes());
    File('${meshes.path}/SM_Taken.lmas')
        .writeAsBytesSync(const LuminaAsset(assetId: 'taken-id', name: 'SM_Taken', type: AssetType.filamesh).toProtoBufferBytes());
    vm = EditorViewModel(
      initialProject: const LuminaProject(projectName: name),
      projectLocation: projectDir.path,
      enableTimers: false,
      autoInitAssets: false,
    );
    vm.refreshAssets();
    vm.selectedFolder = 'contents/meshes';
    // A placed actor that renders the box.
    vm.addActorNodeForTest(EditorActorNode(id: 'act_box', name: 'Box', type: 'Mesh', location: [0, 0, 0], meshAssetPath: box.path));
  });
  // A widget test cannot await vm.close() (see deleteTempProject).
  tearDown(() async {
    vm.dispose();
    await deleteTempProject(projectDir);
  });

  Finder tile(String fileName) => find.byWidgetPredicate((w) {
        final k = w.key;
        return k is ValueKey<String> && k.value.startsWith('asset_item_') && k.value.endsWith(fileName);
      });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: Scaffold(child: ContentBrowserWidget(viewModel: vm))));
    await tester.pumpAndSettle();
  }

  Future<void> openMenu(WidgetTester tester, String fileName) async {
    await tester.tapAt(tester.getCenter(tile(fileName)), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
  }

  testWidgets('right-click → Rename… renames the file and keeps the placed actor pointing at it', (tester) async {
    await pump(tester);
    await openMenu(tester, 'SM_Box.lmas');
    expect(find.text('Rename...'), findsOneWidget);
    await tester.tap(find.text('Rename...'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('asset_rename_field')), 'SM_Crate');
    await tester.tap(find.byKey(const ValueKey('asset_rename_confirm')));
    await tester.pumpAndSettle();
    // The refresh reloads the placed actor's mesh with async reads.
    await drainRealIo(tester);

    expect(box.existsSync(), isFalse);
    final crate = File('${dir.path}/contents/meshes/SM_Crate.lmas');
    expect(crate.existsSync(), isTrue);
    expect(LuminaAsset.fromBytes(crate.readAsBytesSync()).assetId, 'box-id', reason: 'same asset, new name');
    expect(tile('SM_Crate.lmas'), findsOneWidget);
    expect(vm.actors.firstWhere((a) => a.id == 'act_box').meshAssetPath, crate.path,
        reason: 'the open level keeps resolving the mesh');
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('renaming onto an existing name or an invalid name is refused with a message', (tester) async {
    await pump(tester);
    await openMenu(tester, 'SM_Box.lmas');
    await tester.tap(find.text('Rename...'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('asset_rename_field')), 'SM_Taken');
    await tester.tap(find.byKey(const ValueKey('asset_rename_confirm')));
    await tester.pumpAndSettle();
    expect(find.textContaining('already exists'), findsOneWidget);
    expect(box.existsSync(), isTrue);

    await tester.enterText(find.byKey(const ValueKey('asset_rename_field')), '1 bad name');
    await tester.tap(find.byKey(const ValueKey('asset_rename_confirm')));
    await tester.pumpAndSettle();
    expect(find.textContaining('letters, digits and underscores'), findsOneWidget);
    expect(box.existsSync(), isTrue);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('right-click → Duplicate makes SM_Box_1 with a fresh asset id', (tester) async {
    await pump(tester);
    await openMenu(tester, 'SM_Box.lmas');
    expect(find.text('Duplicate'), findsOneWidget);
    await tester.tap(find.text('Duplicate'));
    await tester.pumpAndSettle();
    // The refresh reloads the placed actor's mesh with async reads.
    await drainRealIo(tester);

    final copy = File('${dir.path}/contents/meshes/SM_Box_1.lmas');
    expect(copy.existsSync(), isTrue);
    expect(box.existsSync(), isTrue);
    expect(LuminaAsset.fromBytes(copy.readAsBytesSync()).assetId, isNot('box-id'));
    expect(tile('SM_Box_1.lmas'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
}

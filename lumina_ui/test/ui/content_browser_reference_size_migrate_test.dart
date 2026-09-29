import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/gestures.dart' show kSecondaryMouseButton;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/content_browser_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../helpers/temp_project.dart';

/// The asset menu had no Reference Viewer, Size Info or Migrate
/// although they were planned. No mocks: real
/// `.lmas` files on disk forming a mesh → material → texture chain, and a
/// real second project to migrate into.
void main() {
  late Directory root;
  late Directory dir;
  late Directory other;
  late EditorViewModel vm;

  const meshPath = 'contents/meshes/SM_Crate.lmas';
  const materialPath = 'contents/materials/M_Crate.lmas';
  const texturePath = 'contents/textures/T_Crate.lmas';

  void write(String rel, LuminaAsset asset) {
    File('${dir.path}/$rel')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(asset.toProtoBufferBytes());
  }

  setUp(() {
    root = Directory.systemTemp.createTempSync('lumina_cb_refs_');
    dir = Directory('${root.path}/RefGame')..createSync(recursive: true);
    File('${dir.path}/RefGame.lmproject').writeAsStringSync('{"project_name": "RefGame"}');
    other = Directory('${root.path}/OtherGame')..createSync(recursive: true);
    File('${other.path}/OtherGame.lmproject').writeAsStringSync('{"project_name": "OtherGame"}');

    write(texturePath, LuminaAsset(assetId: 'tex-id', name: 'T_Crate', type: AssetType.texture, rawPayload: Uint8List(4096)));
    write(
        materialPath,
        const LuminaAsset(assetId: 'mat-id', name: 'M_Crate', type: AssetType.filamat, references: [
          AssetReference(slotName: 'baseColor', assetId: 'tex-id', assetPath: texturePath),
        ]));
    write(
        meshPath,
        LuminaAsset(
          assetId: 'mesh-id',
          name: 'SM_Crate',
          type: AssetType.filamesh,
          rawPayload: Uint8List(2048),
          hasThumbnail: true,
          thumbnailPng: Uint8List(512),
          references: const [AssetReference(slotName: 'material_slot_0', assetId: 'mat-id', assetPath: materialPath)],
        ));

    vm = EditorViewModel(
      initialProject: const LuminaProject(projectName: 'RefGame'),
      projectLocation: root.path,
      enableTimers: false,
      autoInitAssets: false,
    );
    vm.refreshAssets();
  });
  // A widget test cannot await vm.close() (see deleteTempProject).
  tearDown(() async {
    vm.dispose();
    await deleteTempProject(root);
  });

  Finder tile(String fileName) => find.byWidgetPredicate((w) {
        final k = w.key;
        return k is ValueKey<String> && k.value.startsWith('asset_item_') && k.value.endsWith(fileName);
      });

  Future<void> pump(WidgetTester tester, String folder) async {
    vm.selectedFolder = folder;
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: Scaffold(child: ContentBrowserWidget(viewModel: vm))));
    await tester.pumpAndSettle();
  }

  Future<void> menu(WidgetTester tester, String fileName, String entry) async {
    await tester.tapAt(tester.getCenter(tile(fileName)), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    expect(find.text(entry), findsOneWidget);
    await tester.tap(find.text(entry));
    await tester.pumpAndSettle();
  }

  testWidgets('Reference Viewer lists what the material depends on and what references it; a row browses to it', (tester) async {
    await pump(tester, 'contents/materials');
    await menu(tester, 'M_Crate.lmas', 'Reference Viewer...');

    final deps = find.byKey(const ValueKey('reference_viewer_dependencies'));
    final refs = find.byKey(const ValueKey('reference_viewer_referencers'));
    expect(find.descendant(of: deps, matching: find.text(texturePath)), findsOneWidget);
    expect(find.descendant(of: refs, matching: find.text(meshPath)), findsOneWidget);
    expect(find.descendant(of: deps, matching: find.text(meshPath)), findsNothing);

    await tester.tap(find.byKey(const ValueKey('reference_viewer_referencers_$meshPath')));
    await tester.pumpAndSettle();
    expect(vm.selectedFolder, 'contents/meshes', reason: 'the browser follows the click');
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('Size Info shows the file, payload, thumbnail and closure sizes read from disk', (tester) async {
    await pump(tester, 'contents/meshes');
    await menu(tester, 'SM_Crate.lmas', 'Size Info...');

    String shown(String key) => tester.widget<Text>(find.byKey(ValueKey('size_info_$key'))).data!;
    int size(String rel) => File('${dir.path}/$rel').lengthSync();
    String fmt(int b) => b < 1024 ? '$b B' : '${(b / 1024).toStringAsFixed(1)} KB';
    expect(shown('file'), fmt(size(meshPath)));
    expect(shown('payload'), fmt(2048));
    expect(shown('thumbnail'), fmt(512));
    expect(shown('closure'), fmt(size(meshPath) + size(materialPath) + size(texturePath)));
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('Migrate copies the closure into another project with ids preserved; a second run skips all', (tester) async {
    vm.migrateTargetPicker = () async => other.path;
    await pump(tester, 'contents/meshes');
    await menu(tester, 'SM_Crate.lmas', 'Migrate...');

    for (final rel in [meshPath, materialPath, texturePath]) {
      expect(find.byKey(ValueKey('migrate_row_$rel')), findsOneWidget, reason: rel);
    }
    await tester.tap(find.byKey(const ValueKey('migrate_confirm')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const ValueKey('migrate_message'))).data, startsWith('3 copied, 0 skipped'));
    for (final (rel, id) in [(meshPath, 'mesh-id'), (materialPath, 'mat-id'), (texturePath, 'tex-id')]) {
      final copied = File('${other.path}/$rel');
      expect(copied.existsSync(), isTrue, reason: rel);
      expect(LuminaAsset.fromBytes(copied.readAsBytesSync()).assetId, id);
    }
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await menu(tester, 'SM_Crate.lmas', 'Migrate...');
    expect(find.textContaining('3 already in the target'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('migrate_confirm')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const ValueKey('migrate_message'))).data, startsWith('0 copied, 3 skipped'));
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('Migrate into a folder that is not a project says so and copies nothing', (tester) async {
    final plain = Directory('${root.path}/NotAProject')..createSync();
    vm.migrateTargetPicker = () async => plain.path;
    await pump(tester, 'contents/meshes');
    await menu(tester, 'SM_Crate.lmas', 'Migrate...');
    expect(find.text('Cannot migrate'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const ValueKey('migrate_message'))).data, contains('.lmproject'));
    expect(plain.listSync(), isEmpty);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
}

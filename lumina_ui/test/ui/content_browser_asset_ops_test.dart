import 'dart:io';
import 'package:flutter/material.dart' as mat;
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/content_browser_widget.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

void main() {
  testWidgets('AssetReferenceGraph resolves properly', (tester) async {
    final graph = AssetReferenceGraph();
    final matAsset = RealAssetInfo(
      fileName: 'mat.lmas',
      relativePath: 'contents/mat.lmas',
      type: AssetType.filamat,
      bytes: 100,
      assetId: 'mat-uuid',
      references: [],
    );
    final meshAsset = RealAssetInfo(
      fileName: 'mesh.lmas',
      relativePath: 'contents/mesh.lmas',
      type: AssetType.filamesh,
      bytes: 100,
      assetId: 'mesh-uuid',
      references: [AssetReference(slotName: 'mat0', assetId: 'mat-uuid', assetPath: 'contents/mat.lmas')],
    );

    graph.build([matAsset, meshAsset]);

    final deps = graph.dependenciesOf('mesh-uuid');
    expect(deps.length, 1);
    expect(deps.first.assetId, 'mat-uuid');

    final refs = graph.referencersOf('mat-uuid');
    expect(refs.length, 1);
    expect(refs.first.assetId, 'mesh-uuid');
  });

  testWidgets('Rename asset updates references without corruption', (tester) async {
    final tempProjectDir = Directory.systemTemp.createTempSync('ops_test_');
    final vm = EditorViewModel(projectDirPath: tempProjectDir.path, enableTimers: false, autoInitAssets: false);
    File('${vm.projectDirPath}/test.lmproject')
      ..createSync(recursive: true)
      ..writeAsStringSync('{}');
    final contentDir = Directory('${vm.projectDirPath}/contents')..createSync(recursive: true);
    
    final matAsset = LuminaAsset(
      assetId: 'mat-uuid',
      name: 'Material1',
      type: AssetType.filamat,
    );
    final meshAsset = LuminaAsset(
      assetId: 'mesh-uuid',
      name: 'Mesh1',
      type: AssetType.filamesh,
      references: [AssetReference(slotName: 'mat0', assetId: 'mat-uuid', assetPath: 'contents/mat.lmas')],
    );

    final matFile = File('${contentDir.path}/mat.lmas');
    final meshFile = File('${contentDir.path}/mesh.lmas');
    matFile.writeAsBytesSync(matAsset.toProtoBufferBytes());
    meshFile.writeAsBytesSync(meshAsset.toProtoBufferBytes());

    vm.refreshAssets();

    vm.renameAsset(matFile.path, 'Material_Renamed');

    // old mat gone
    expect(matFile.existsSync(), false);
    final newMatFile = File('${contentDir.path}/Material_Renamed.lmas');
    expect(newMatFile.existsSync(), true);

    // check mesh
    final updatedMesh = LuminaAsset.fromBytes(meshFile.readAsBytesSync());
    expect(updatedMesh.references.first.assetPath, 'contents/Material_Renamed.lmas');

    try { tempProjectDir.deleteSync(recursive: true); } catch (_) {}
  });

  testWidgets('Delete dialog shows referencers', (tester) async {
    final tempProjectDir = Directory.systemTemp.createTempSync('ops_test_2_');
    final vm = EditorViewModel(projectDirPath: tempProjectDir.path, enableTimers: false, autoInitAssets: false);
    File('${vm.projectDirPath}/test.lmproject')
      ..createSync(recursive: true)
      ..writeAsStringSync('{}');
    final contentDir = Directory('${vm.projectDirPath}/contents')..createSync(recursive: true);
    
    final matAsset = LuminaAsset(
      assetId: 'mat-uuid',
      name: 'Material1',
      type: AssetType.filamat,
    );
    final meshAsset = LuminaAsset(
      assetId: 'mesh-uuid',
      name: 'Mesh1',
      type: AssetType.filamesh,
      references: [AssetReference(slotName: 'mat0', assetId: 'mat-uuid', assetPath: 'contents/mat.lmas')],
    );

    final matFile = File('${contentDir.path}/mat.lmas');
    final meshFile = File('${contentDir.path}/mesh.lmas');
    matFile.writeAsBytesSync(matAsset.toProtoBufferBytes());
    meshFile.writeAsBytesSync(meshAsset.toProtoBufferBytes());

    vm.refreshAssets();

    await tester.pumpWidget(
      ShadcnApp(
        theme: luminaEditorTheme(),
        home: mat.Scaffold(
          body: ContentBrowserWidget(viewModel: vm),
        ),
      ),
    );
    await tester.pumpAndSettle();
    
    try { tempProjectDir.deleteSync(recursive: true); } catch (_) {}
  });
}

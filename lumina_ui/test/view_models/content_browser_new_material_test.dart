// A material made with Content Browser ▸ New ▸ Material starts from the
// Material Editor's new-material template (the source MCP `create_asset`
// and the editor opened on a missing file use), so its node graph opens as
// the template's nodes wired into the Material node, not as one Custom
// (Fragment) node, and it compiles. Real temp project, real `.lmas` files.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/material_graph.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/material_editor_view_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Directory projDir;

  const project = LuminaProject(projectName: 'NewMaterialGame', activeLevel: 'contents/levels/L_Main.lmas');

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('lumina_new_material_');
    projDir = Directory('${tempDir.path}/NewMaterialGame')..createSync(recursive: true);
    Directory('${projDir.path}/contents/materials').createSync(recursive: true);
    File('${projDir.path}/NewMaterialGame.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
  });

  tearDown(() => tempDir.deleteSync(recursive: true));

  /// The source the Material Editor authors for a new material named [name]
  /// (it opens a missing file on the template).
  Future<String> templateFor(String name) async {
    final vm = MaterialEditorViewModel(assetPath: '${tempDir.path}/template_probe/$name.lmas');
    await vm.load();
    final code = vm.currentCode;
    vm.dispose();
    return code;
  }

  Future<void> expectTemplateMaterial(File file, String name) async {
    expect(file.existsSync(), isTrue);
    final saved = LuminaAsset.fromBytes(file.readAsBytesSync());
    expect(saved.type, AssetType.filamat);
    expect(saved.rawMatSource, await templateFor(name));
    expect(saved.rawMatSource, contains('flipUV : false'));

    final vm = MaterialEditorViewModel(assetPath: file.path);
    addTearDown(vm.dispose);
    await vm.load();
    final graph = vm.graph..ensureSynced();
    final nodes = graph.graph.nodes;
    expect(nodes.where((n) => n.registryId == MaterialNodes.customFragment), isEmpty,
        reason: 'the template fragment reads as nodes: ${nodes.map((n) => n.registryId).toList()}');
    final intoOutput = {
      for (final w in graph.graph.wires)
        if (w.toNodeId == MaterialNodes.outputNodeId) w.toPinId,
    };
    expect(intoOutput, containsAll([MaterialNodes.baseColor, MaterialNodes.roughness, MaterialNodes.metallic]));
    expect(await vm.compile(), isTrue, reason: '${vm.issues.map((i) => i.message)}\n${vm.currentCode}');
  }

  test('Content Browser ▸ New ▸ Material writes the new-material template, whose graph is nodes and compiles',
      () async {
    final vm = EditorViewModel(initialProject: project, projectLocation: tempDir.path, enableTimers: false, autoInitAssets: false);
    await vm.createNewAsset(type: AssetType.filamat, subFolder: 'materials');
    final created = Directory('${projDir.path}/contents/materials')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.lmas'))
        .toList();
    expect(created, hasLength(1));
    final name = created.single.uri.pathSegments.last.replaceAll('.lmas', '');
    await expectTemplateMaterial(created.single, name);
  });

  test('the starter material a new project is seeded with is the new-material template', () async {
    final vm = EditorViewModel(initialProject: project, projectLocation: tempDir.path, enableTimers: false);
    await vm.ensureDefaultLevelAssets();
    await expectTemplateMaterial(File('${projDir.path}/contents/materials/M_Ground_PBR.lmas'), 'M_Ground_PBR');
  });
}

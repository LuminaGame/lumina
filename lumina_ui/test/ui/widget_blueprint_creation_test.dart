import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/features/main_editor/services/widget_blueprint_assets.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/umg_document.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_editor_view_model.dart';

/// A Blueprint whose parent is `LuminaWidget` is a Widget Blueprint, so it
/// opens in the
/// widget designer, never the actor Blueprint editor and its 3D viewport.
void main() {
  late Directory projectsDir;
  late String projectDir;
  late EditorViewModel vm;

  setUp(() async {
    projectsDir = Directory.systemTemp.createTempSync('widget_bp_test_');
    const projectName = 'WidgetBpGame';
    projectDir = '${projectsDir.path}/$projectName';
    for (final folder in const ['contents/levels', 'contents/blueprints', 'contents/ui']) {
      Directory('$projectDir/$folder').createSync(recursive: true);
    }
    const project = LuminaProject(
      projectName: projectName,
      engineVersion: '0.0.1',
      activeLevel: 'contents/levels/L_Main.lmas',
    );
    File('$projectDir/$projectName.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    vm = EditorViewModel(initialProject: project, projectLocation: projectsDir.path);
    expect(vm.projectDirPath, projectDir);
    await vm.ensureDefaultLevelAssets();
    vm.refreshAssets();
  });

  tearDown(() {
    vm.dispose();
    if (projectsDir.existsSync()) projectsDir.deleteSync(recursive: true);
  });

  test('a Blueprint with the LuminaWidget parent is a Widget Blueprint under contents/widgets', () async {
    await vm.createBlueprintWithParent(name: 'WBP_Hud', parentClass: 'LuminaWidget');

    final file = File('$projectDir/contents/widgets/WBP_Hud.lmas');
    expect(file.existsSync(), isTrue, reason: 'it was written as an actor Blueprint under contents/blueprints');
    expect(File('$projectDir/contents/blueprints/WBP_Hud.lmas').existsSync(), isFalse);

    final asset = LuminaAsset.fromBytes(file.readAsBytesSync());
    expect(asset.type, AssetType.widget);
    final doc = UmgDocument.fromJson(Map<String, dynamic>.from(jsonDecode(utf8.decode(asset.rawPayload!)) as Map));
    expect(doc.root.id, isNotEmpty, reason: 'a designer document the widget editor opens as-is');
    expect(vm.realAssets.where((a) => a.type == AssetType.widget && a.fileName.startsWith('WBP_Hud')), hasLength(1));
  });

  test('New Asset → Widget Blueprint never overwrites an existing widget', () async {
    final first = await vm.createWidgetBlueprint();
    final second = await vm.createWidgetBlueprint();
    expect(first, 'contents/widgets/WBP_NewWidget.lmas');
    expect(second, 'contents/widgets/WBP_NewWidget_1.lmas');
    for (final path in [first, second]) {
      expect(LuminaAsset.fromBytes(File('$projectDir/$path').readAsBytesSync()).type, AssetType.widget);
    }
    expect(isWidgetBlueprintLmas('$projectDir/$first'), isTrue);
  });

  test('an actor Blueprint made with the LuminaWidget parent by the old code opens in the widget designer', () {
    // What createBlueprintWithParent used to write: an actor asset.
    String writeActorBlueprint(String name, String parentClass) {
      final doc = BlueprintEditorViewModel.createDefaultDocument(name, parentClass: parentClass).toFormattedJson();
      final path = '$projectDir/contents/blueprints/$name.lmas';
      File(path).writeAsBytesSync(LuminaAsset(
        assetId: name,
        name: name,
        type: AssetType.actor,
        rawPayload: Uint8List.fromList(utf8.encode(doc)),
        rawMatSource: doc,
        metadata: {'parent_class': parentClass},
      ).toProtoBufferBytes());
      return path;
    }

    expect(isWidgetBlueprintLmas(writeActorBlueprint('WBP_Legacy', 'LuminaWidget')), isTrue);
    expect(isWidgetBlueprintLmas(writeActorBlueprint('BP_Hero', 'LuminaCharacter')), isFalse);
    expect(isWidgetBlueprintLmas('$projectDir/contents/blueprints/missing.lmas'), isFalse);
  });
}

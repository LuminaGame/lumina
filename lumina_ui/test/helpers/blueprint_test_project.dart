import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:lumina/data/services/game_template_service.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_editor_view_model.dart';

/// A real project on disk for Blueprint editor tests: a `.lmproject` carrying
/// the Third Person template's Enhanced Input actions (IA_Move axis2D,
/// IA_Look axis2D, IA_Jump digital) and a `contents/` tree.
class BlueprintTestProject {
  final Directory root;
  final String dir;

  BlueprintTestProject._(this.root, this.dir);

  static BlueprintTestProject create({String name = 'BpProject', String template = kThirdPersonTemplateId}) {
    final root = Directory.systemTemp.createTempSync('lumina_bp_project_');
    final dir = '${root.path}/$name';
    Directory('$dir/contents/blueprints').createSync(recursive: true);
    Directory('$dir/contents/levels').createSync(recursive: true);
    final project = LuminaProject(
      projectName: name,
      template: template,
      input: GameTemplateCatalog.byId(template).input,
    );
    File('$dir/$name.lmproject').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(project.toMap()));
    return BlueprintTestProject._(root, dir);
  }

  /// A new Blueprint class, as Content Browser → Blueprint Class writes it.
  String createBlueprint(String name, {String parentClass = 'LuminaCharacter'}) =>
      writeBlueprint(dir, name, BlueprintEditorViewModel.createDefaultDocument(name, parentClass: parentClass));

  void dispose() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  }
}

/// Writes [document] as `contents/blueprints/<name>.lmas` in [projectDir]
/// and returns the file's path.
String writeBlueprint(String projectDir, String name, LuminaBlueprintDocument document) {
  final json = document.toFormattedJson();
  final asset = LuminaAsset(
    assetId: 'bp_$name',
    name: name,
    type: AssetType.actor,
    rawPayload: Uint8List.fromList(utf8.encode(json)),
    rawMatSource: json,
    metadata: {'parent_class': document.parentClass},
  );
  final file = File('$projectDir/contents/blueprints/$name.lmas')..parent.createSync(recursive: true);
  file.writeAsBytesSync(asset.toProtoBufferBytes());
  return file.path;
}

/// The document stored in the Blueprint `.lmas` at [path].
LuminaBlueprintDocument readBlueprint(String path) {
  final payload = LuminaAsset.fromBytes(File(path).readAsBytesSync()).rawPayload!;
  return LuminaBlueprintDocument.fromJson(Map<String, dynamic>.from(jsonDecode(utf8.decode(payload)) as Map));
}

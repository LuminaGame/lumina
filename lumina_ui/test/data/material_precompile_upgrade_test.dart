import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_filament/filament.dart' show filamentExpectedMaterialVersion;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/build_pipeline_service.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/material_asset_upgrader.dart';

/// A build of a project saved before the Filament upgrade: the precompile
/// step brings its materials to the linked release on disk, so the game packs
/// packages the engine accepts.
void main() {
  late Directory tempDir;
  late Directory projDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('lumina_precompile_upgrade_');
    LuminaDataDir.override = Directory('${tempDir.path}/lumina_data');
    projDir = Directory('${tempDir.path}/upgrade_game')..createSync(recursive: true);
    Directory('${projDir.path}/contents/materials').createSync(recursive: true);
    const project = LuminaProject(projectName: 'upgrade_game', activeLevel: 'contents/levels/L_Main.lmas');
    File('${projDir.path}/upgrade_game.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
  });

  tearDown(() {
    LuminaDataDir.override = null;
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('a material compiled for material version 77 is compiled again, written back and packed current', () async {
    final old = File('test/fixtures/materials/ui_overlay_material_version_77.filamat').readAsBytesSync();
    const source = 'material { name : "M_Old", shadingModel : unlit, variantFilter : [ directionalLighting ] }\n'
        'fragment { void material(inout MaterialInputs material) { prepareMaterial(material); } }\n';
    final file = File('${projDir.path}/contents/materials/M_Old.lmas')
      ..writeAsBytesSync(
        LuminaAsset(assetId: 'id-old', name: 'M_Old', type: AssetType.filamat, rawPayload: old, rawMatSource: source)
            .toProtoBufferBytes(),
      );

    Uint8List? compiledPackage;
    final step = MaterialPrecompileStep(compiler: (input) async {
      compiledPackage = input.package;
      return const MaterialCompileOutcome.ok();
    });
    final project = LuminaProject.fromMap(
      jsonDecode(File('${projDir.path}/upgrade_game.lmproject').readAsStringSync()) as Map<String, dynamic>,
    );
    final events = await BuildPipelineService().run(BuildPlan(steps: [step]), projectDir: projDir.path, project: project).toList();
    final logs = events.whereType<BuildLogEvent>().map((e) => e.message).join('\n');

    expect(MaterialAssetUpgrader.packageVersion(compiledPackage), filamentExpectedMaterialVersion, reason: logs);
    final saved = LuminaAsset.fromBytes(file.readAsBytesSync());
    expect(MaterialAssetUpgrader.packageVersion(saved.rawPayload), filamentExpectedMaterialVersion);
    expect(saved.rawMatSource, contains('variantFilter : []'));
    expect(logs, contains('Upgraded material M_Old.lmas (compiled for material version 77'));
    expect(events.whereType<BuildStepFinished>().single.status, BuildStepStatus.ok, reason: logs);
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';

/// A new Cloth Settings asset (Content Browser → New Asset) is written with
/// the cloth defaults and scanned back as a cloth settings asset.
void main() {
  test('a new cloth settings asset holds the defaults and scans as clothSettings', () async {
    final dir = await Directory.systemTemp.createTemp('cloth_settings_project_');
    addTearDown(() => dir.delete(recursive: true));
    final projectRepo = ProjectRepository();
    final assetRepo = AssetRepository();
    await projectRepo.createProjectStream(projectName: 'cloth_settings_test', projectLocation: dir.path).drain();
    final projectPath = '${dir.path}/cloth_settings_test';
    await assetRepo.createAsset(projectPath: projectPath, subFolder: 'physics', fileName: 'CS_Flag.lmas', type: AssetType.clothSettings);
    final file = File('$projectPath/contents/physics/CS_Flag.lmas');
    final asset = LuminaAsset.fromBytes(await file.readAsBytes());
    expect(asset.type, AssetType.clothSettings);
    expect(LuminaClothSettingsDocument.fromAsset(asset), const LuminaClothSettingsDocument());
    expect(asset.rawPayload, isNotEmpty);
    final scanned = assetRepo.scanProjectContents(projectPath).firstWhere((a) => a.fileName == 'CS_Flag.lmas');
    expect(scanned.type, AssetType.clothSettings);
  });
}

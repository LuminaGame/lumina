import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';

/// A new Garment asset (Content Browser → New Asset → Character) is written
/// with the garment defaults and scanned back as a garment.
void main() {
  test('a new garment asset holds the defaults and scans as garment', () async {
    final dir = await Directory.systemTemp.createTemp('garment_project_');
    addTearDown(() => dir.delete(recursive: true));
    final projectRepo = ProjectRepository();
    final assetRepo = AssetRepository();
    await projectRepo.createProjectStream(projectName: 'garment_test', projectLocation: dir.path).drain();
    final projectPath = '${dir.path}/garment_test';
    await assetRepo.createAsset(projectPath: projectPath, subFolder: 'characters', fileName: 'G_Shirt.lmas', type: AssetType.garment);
    final file = File('$projectPath/contents/characters/G_Shirt.lmas');
    final asset = LuminaAsset.fromBytes(await file.readAsBytes());
    expect(asset.type, AssetType.garment);
    expect(LuminaGarmentDocument.fromAsset(asset), const LuminaGarmentDocument());
    expect(asset.rawPayload, isNotEmpty);
    final scanned = assetRepo.scanProjectContents(projectPath).firstWhere((a) => a.fileName == 'G_Shirt.lmas');
    expect(scanned.type, AssetType.garment);
  });
}

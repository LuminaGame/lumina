import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late AssetRepository assetRepo;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('lumina_thumb_test_');
    assetRepo = AssetRepository();
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('scanProjectContents never reads a .thumbnails/ sidecar: thumbnails live in the .lmas', () async {
    final projDir = Directory('${tempDir.path}/TestProj')..createSync(recursive: true);
    final texturesDir = Directory('${projDir.path}/contents/textures')..createSync(recursive: true);
    final thumbDir = Directory('${texturesDir.path}/.thumbnails')..createSync(recursive: true);

    // 1. Create asset with NO thumbnailPng in LMAS
    final asset = LuminaAsset(
      assetId: 'tex-01',
      name: 'T_Wood_Albedo',
      type: AssetType.texture,
      thumbnailPng: null, // explicitly null
      rawPayload: Uint8List.fromList([1, 2, 3, 4]),
    );
    final lmasFile = File('${texturesDir.path}/T_Wood_Albedo.lmas');
    lmasFile.writeAsBytesSync(asset.toProtoBufferBytes());

    // 2. Put companion PNG in .thumbnails
    final samplePng = Uint8List.fromList([
      137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0,
      31, 21, 196, 137, 0, 0, 0, 10, 73, 68, 65, 84, 120, 156, 99, 0, 1, 0, 0, 5, 0, 1, 13, 10, 45, 180,
      0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130
    ]);
    final thumbFile = File('${thumbDir.path}/T_Wood_Albedo.png');
    thumbFile.writeAsBytesSync(samplePng);

    final results = assetRepo.scanProjectContents(projDir.path);
    expect(results.length, equals(1));
    expect(results.first.fileName, equals('T_Wood_Albedo.lmas'));
    expect(results.first.thumbnailBytes, isNot(equals(samplePng)), reason: 'the sidecar is not a thumbnail source any more');
    expect(results.first.thumbnailBytes, equals([1, 2, 3, 4]), reason: 'a texture without one shows its image');
  });

  test('scanProjectContents falls back to rawPayload for textures when thumbnailPng is null', () async {
    final projDir = Directory('${tempDir.path}/TestProj2')..createSync(recursive: true);
    final texturesDir = Directory('${projDir.path}/contents/textures')..createSync(recursive: true);

    final pngImagePayload = Uint8List.fromList([
      137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0,
      31, 21, 196, 137, 0, 0, 0, 10, 73, 68, 65, 84, 120, 156, 99, 0, 1, 0, 0, 5, 0, 1, 13, 10, 45, 180,
      0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130
    ]);

    final asset = LuminaAsset(
      assetId: 'tex-02',
      name: 'T_Manny_01_BN',
      type: AssetType.texture,
      thumbnailPng: null,
      rawPayload: pngImagePayload,
    );
    final lmasFile = File('${texturesDir.path}/T_Manny_01_BN.lmas');
    lmasFile.writeAsBytesSync(asset.toProtoBufferBytes());

    final results = assetRepo.scanProjectContents(projDir.path);
    expect(results.length, equals(1));
    expect(results.first.fileName, equals('T_Manny_01_BN.lmas'));
    expect(results.first.thumbnailBytes, isNotNull, reason: 'Texture rawPayload should be used as fallback thumbnail');
    expect(results.first.thumbnailBytes, equals(pngImagePayload));
  });

  test('ThumbnailService renders rich distinct thumbnails for Blueprint, Level, Sequencer, Widget', () async {
    final thumbService = ThumbnailService();
    final bpAsset = LuminaAsset(assetId: 'bp-1', name: 'BP_Player', type: AssetType.actor);
    final levelAsset = LuminaAsset(assetId: 'lvl-1', name: 'L_Main', type: AssetType.level);
    final seqAsset = LuminaAsset(assetId: 'seq-1', name: 'SEQ_Intro', type: AssetType.sequencer);

    final bpThumb = await thumbService.renderAssetThumbnail(bpAsset);
    final lvlThumb = await thumbService.renderAssetThumbnail(levelAsset);
    final seqThumb = await thumbService.renderAssetThumbnail(seqAsset);

    expect(bpThumb.length, greaterThan(100), reason: 'Should generate non-trivial PNG bytes');
    expect(lvlThumb.length, greaterThan(100));
    expect(seqThumb.length, greaterThan(100));
    expect(bpThumb, isNot(equals(lvlThumb)), reason: 'Different asset types must produce distinct thumbnail badges');
  });
}

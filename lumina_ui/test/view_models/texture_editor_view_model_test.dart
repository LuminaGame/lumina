import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina/testing.dart' show ImportFolderFixture;
import 'package:lumina_ui/testing/smoke_artifacts.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/texture_editor_view_model.dart';

Uint8List buildTestPng4x4() {
  // 4x4 image:
  // Top-left pixel (0,0): Red (255, 0, 0, 255)
  // (1,0): Green (0, 255, 0, 255)
  // (0,1): Blue (0, 0, 255, 255)
  // (1,1): White (255, 255, 255, 255)
  final rgba = Uint8List(4 * 4 * 4);
  for (int y = 0; y < 4; y++) {
    for (int x = 0; x < 4; x++) {
      final idx = (y * 4 + x) * 4;
      if (x < 2 && y < 2) {
        if (x == 0 && y == 0) {
          rgba[idx] = 255; rgba[idx + 1] = 0; rgba[idx + 2] = 0; rgba[idx + 3] = 255;
        } else if (x == 1 && y == 0) {
          rgba[idx] = 0; rgba[idx + 1] = 255; rgba[idx + 2] = 0; rgba[idx + 3] = 255;
        } else if (x == 0 && y == 1) {
          rgba[idx] = 0; rgba[idx + 1] = 0; rgba[idx + 2] = 255; rgba[idx + 3] = 255;
        } else {
          rgba[idx] = 255; rgba[idx + 1] = 255; rgba[idx + 2] = 255; rgba[idx + 3] = 255;
        }
      } else {
        rgba[idx] = 128; rgba[idx + 1] = 128; rgba[idx + 2] = 128; rgba[idx + 3] = 255;
      }
    }
  }
  return SmokeArtifacts.encodeRgbaToPng(rgba, 4, 4);
}

Uint8List buildTestPng8x8() {
  final rgba = Uint8List(8 * 8 * 4);
  for (int i = 0; i < 8 * 8; i++) {
    final idx = i * 4;
    // Checkerboard
    final x = i % 8;
    final y = i ~/ 8;
    final isWhite = (x + y) % 2 == 0;
    final val = isWhite ? 255 : 0;
    rgba[idx] = val;
    rgba[idx + 1] = val;
    rgba[idx + 2] = val;
    rgba[idx + 3] = 255;
  }
  return SmokeArtifacts.encodeRgbaToPng(rgba, 8, 8);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late String lmasPath;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('tex_vm_test_');
    lmasPath = '${tempDir.path}/T_Hero_BaseColor.lmas';

    final pngBytes = buildTestPng4x4();
    final asset = LuminaAsset(
      assetId: 'hero-tex-uuid',
      name: 'T_Hero_BaseColor',
      type: AssetType.texture,
      rawPayload: pngBytes,
      metadata: {},
    );

    final lmasBytes = asset.toProtoBufferBytes();
    File(lmasPath).writeAsBytesSync(lmasBytes);
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('TextureEditorViewModel loads 4x4 image and reports exact resolution, size, and pixels', () async {
    final vm = TextureEditorViewModel(assetPath: lmasPath);
    await vm.load();

    expect(vm.width, equals(4));
    expect(vm.height, equals(4));
    expect(vm.uncompressedSizeBytes, equals(64)); // 4 * 4 * 4 = 64
    expect(vm.aspectRatioStr, equals('1:1'));

    // Pixel (0,0) is Red (255, 0, 0, 255)
    final p0 = vm.pixelAt(0, 0, 0);
    expect(p0, equals((255, 0, 0, 255)));

    // Pixel (1,0) is Green (0, 255, 0, 255)
    final p1 = vm.pixelAt(0, 1, 0);
    expect(p1, equals((0, 255, 0, 255)));

    // Pixel (0,1) is Blue (0, 0, 255, 255)
    final p2 = vm.pixelAt(0, 0, 1);
    expect(p2, equals((0, 0, 255, 255)));
  });

  test('Mip chain generation for 8x8 image produces 4 levels (8, 4, 2, 1) and box filter averaging', () async {
    final png8x8 = buildTestPng8x8();
    final path8 = '${tempDir.path}/T_8x8.lmas';
    final asset8 = LuminaAsset(
      assetId: 'tex-8x8',
      name: 'T_8x8',
      type: AssetType.texture,
      rawPayload: png8x8,
    );
    File(path8).writeAsBytesSync(asset8.toProtoBufferBytes());

    final vm = TextureEditorViewModel(assetPath: path8);
    await vm.load();

    // Default mip chain: 8x8 -> 4x4 -> 2x2 -> 1x1 (4 mips)
    expect(vm.mipChain.length, equals(4));
    expect(vm.mipChain[0].width, equals(8));
    expect(vm.mipChain[1].width, equals(4));
    expect(vm.mipChain[2].width, equals(2));
    expect(vm.mipChain[3].width, equals(1));

    // Checkerboard 2x2 box average of (0, 255, 255, 0) should be ~127 or 128
    final mip1Pixel = vm.pixelAt(1, 0, 0);
    expect(mip1Pixel.$1, inInclusiveRange(127, 128));

    // Set NoMipmaps
    vm.setMipGenSettings('NoMipmaps');
    expect(vm.mipChain.length, equals(1));
    expect(vm.mipChain[0].width, equals(8));
  });

  test('Channel isolation filters displayed buffer while pixelAt preserves originals', () async {
    final vm = TextureEditorViewModel(assetPath: lmasPath);
    await vm.load();

    // Set R only
    vm.setChannelMask(r: true, g: false, b: false, a: false);
    expect(vm.channelMaskStr, equals('R'));

    // pixelAt still returns full original RGBA
    final orig = vm.pixelAt(0, 0, 0);
    expect(orig, equals((255, 0, 0, 255)));

    // Isolated buffer has greyscale from R: (255, 255, 255, 255)
    final filtered = vm.getFilteredPixels(0);
    expect(filtered[0], equals(255));
    expect(filtered[1], equals(255));
    expect(filtered[2], equals(255));
    expect(filtered[3], equals(255));
  });

  test('Estimated size calculation for 1024x1024 RGBA8 with mips and format scaling', () {
    final vm = TextureEditorViewModel(assetPath: lmasPath);
    // 1024x1024 RGBA8 with full mips: 1024*1024*4 * 4/3 ≈ 5.33 MB
    final sizeRgba8 = vm.computeEstimatedSizeBytes(1024, 1024, mipCount: 11, format: 'Uncompressed RGBA8', quality: 'Default');
    expect(sizeRgba8, closeTo(5592405, 1000)); // (4194304 * 4/3)

    // ETC2 quarters RGBA8 (8 bpp vs 32 bpp)
    final sizeEtc2 = vm.computeEstimatedSizeBytes(1024, 1024, mipCount: 11, format: 'ETC2', quality: 'Default');
    expect(sizeEtc2, closeTo(sizeRgba8 / 4.0, 1000));
  });

  test('Persistence and round-trip of texture settings', () async {
    final vm = TextureEditorViewModel(assetPath: lmasPath);
    await vm.load();

    vm.setSrgb(false);
    vm.setTextureGroup('Normalmap');
    vm.setCompressionFormat('ASTC');
    vm.setCompressionQuality('High Quality / Lossless');
    vm.setFilter('Anisotropic 16x');
    vm.setAddressModeX('Mirror');
    vm.setAddressModeY('Clamp');

    expect(vm.isDirty, isTrue);
    await vm.save();

    final vm2 = TextureEditorViewModel(assetPath: lmasPath);
    await vm2.load();

    expect(vm2.settings.srgb, isFalse);
    expect(vm2.settings.group, equals('Normalmap'));
    expect(vm2.settings.format, equals('ASTC'));
    expect(vm2.settings.quality, equals('High Quality / Lossless'));
    expect(vm2.settings.filter, equals('Anisotropic 16x'));
    expect(vm2.settings.addressX, equals('Mirror'));
    expect(vm2.settings.addressY, equals('Clamp'));
  });

  test('Reimport refreshes payload and pixels when source file is updated', () async {
    final srcFile = File('${tempDir.path}/source.png');
    srcFile.writeAsBytesSync(buildTestPng4x4());

    final vm = TextureEditorViewModel(assetPath: lmasPath);
    await vm.load();
    vm.setSourceFilePath(srcFile.path);
    await vm.save();

    // Now overwrite source.png with 8x8 image
    srcFile.writeAsBytesSync(buildTestPng8x8());

    final reimported = await vm.reimport();
    expect(reimported, isTrue);
    expect(vm.width, equals(8));
    expect(vm.height, equals(8));
  });

  // Reimport reads the source through the import's conversion, so
  // a TGA source becomes a PNG payload again (it used to hand the raw TGA
  // bytes to the image codec and fail).
  test('Reimport of a TGA-imported texture converts the source to PNG like the import', () async {
    if (!ImportFolderFixture.available) return markTestSkipped('test-assets missing');
    final fixture = ImportFolderFixture.build(tempDir);
    final project = (Directory('${tempDir.path}/P/contents')..createSync(recursive: true)).parent.path;
    final tga = '${fixture.root}/Props/Textures/loot_barrel_bc.tga';
    final info = await AssetRepository().importExternalFile(
        projectPath: project, sourceFilePath: tga, targetSubFolder: 'contents/T', autoOrganize: false);
    final lmas = '$project/${info.relativePath}';

    final vm = TextureEditorViewModel(assetPath: lmas);
    await vm.load();
    expect(vm.sourceFilePath, isNotNull);
    final width = vm.width;
    final height = vm.height;
    expect(width, greaterThan(0));

    expect(await vm.reimport(), isTrue);
    final stored = LuminaAsset.fromBytes(File(lmas).readAsBytesSync());
    expect(EncodedImageFormat.sniff(Uint8List.fromList(stored.rawPayload!)), EncodedImageFormat.png);
    expect(stored.thumbnailPng, isNotNull);
    expect(vm.width, width);
    expect(vm.height, height);
    expect(vm.mipChain.length, greaterThan(1));
  });
}

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/models/lumina_asset.dart';
import 'package:lumina/data/services/tga_decoder_service.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/material_preview_renderer.dart';

/// Regression coverage: assigned textures never reached the material
/// preview instance.
///
/// `applyParameters` skipped every sampler, so a texture assigned in the panel
/// never reached the preview's material instance and Filament reported the
/// sampler as unset.
void main() {
  late Directory projectDir;

  setUp(() {
    projectDir = Directory.systemTemp.createTempSync('mat_preview_tex_');
    Directory('${projectDir.path}/contents/textures').createSync(recursive: true);
  });

  tearDown(() {
    if (projectDir.existsSync()) projectDir.deleteSync(recursive: true);
  });

  File writeTextureAsset(String name, Uint8List payload) {
    final file = File('${projectDir.path}/contents/textures/$name.lmas');
    file.writeAsBytesSync(
      LuminaAsset(
        assetId: name,
        name: name,
        type: AssetType.texture,
        rawPayload: payload,
      ).toProtoBufferBytes(),
    );
    return file;
  }

  Uint8List solidPng(int width, int height, List<int> rgba) {
    final pixels = Uint8List(width * height * 4);
    for (var i = 0; i < pixels.length; i += 4) {
      pixels[i] = rgba[0];
      pixels[i + 1] = rgba[1];
      pixels[i + 2] = rgba[2];
      pixels[i + 3] = rgba[3];
    }
    return TgaDecoderService.encodePng(pixels, width, height);
  }

  test('a texture .lmas decodes to RGBA at its real dimensions', () {
    final file = writeTextureAsset('T_Red', solidPng(8, 4, [200, 30, 40, 255]));

    final decoded = MaterialPreviewRenderer.decodeTextureAsset(file.path);

    expect(decoded, isNotNull);
    expect(decoded!.width, equals(8));
    expect(decoded.height, equals(4));
    expect(decoded.rgba, hasLength(8 * 4 * 4));
    expect(decoded.rgba.sublist(0, 4), equals([200, 30, 40, 255]));
  });

  test('a raw PNG on disk decodes too, not just an .lmas container', () {
    final file = File('${projectDir.path}/contents/textures/plain.png')
      ..writeAsBytesSync(solidPng(2, 2, [10, 20, 30, 255]));

    final decoded = MaterialPreviewRenderer.decodeTextureAsset(file.path);

    expect(decoded, isNotNull);
    expect(decoded!.width, equals(2));
    expect(decoded.height, equals(2));
  });

  test('a missing or undecodable file yields null rather than throwing', () {
    expect(
      MaterialPreviewRenderer.decodeTextureAsset('${projectDir.path}/nope.lmas'),
      isNull,
    );

    final junk = File('${projectDir.path}/contents/textures/junk.lmas')
      ..writeAsBytesSync(Uint8List.fromList([1, 2, 3, 4, 5]));
    expect(MaterialPreviewRenderer.decodeTextureAsset(junk.path), isNull);
  });

  test('an unassigned sampler gets a neutral fallback, keyed by its name', () {
    final white = MaterialPreviewRenderer.fallbackPixelFor('albedoMap');
    expect(white, equals([255, 255, 255, 255]),
        reason: 'a colour sampler with nothing assigned should not darken the material');

    // A flat normal is (0.5, 0.5, 1.0) — anything else tilts every surface.
    expect(MaterialPreviewRenderer.fallbackPixelFor('normalMap'), equals([128, 128, 255, 255]));
    expect(MaterialPreviewRenderer.fallbackPixelFor('NormalTexture'), equals([128, 128, 255, 255]));
  });
}

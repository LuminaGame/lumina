import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart' show Ktx2Decoder;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';

import '../../helpers/ktx2_glb_fixture.dart';

/// A GLB whose textures are KTX2 (Basis Universal) images referenced through
/// `KHR_texture_basisu` keeps them in the editor: the import's material
/// slots reference the right texture assets, the texture assets keep the
/// KTX2 bytes as KTX2, and the CPU paths (vertex colours, thumbnails) see the
/// texture's pixels instead of the flat base colour factor.
void main() {
  late Uint8List baseColor;
  late Uint8List normal;
  late Uint8List glb;

  setUpAll(() {
    // A red base colour and a flat (0.5, 0.5, 1) normal map.
    baseColor = solidKtx2(const [1.0, 0.0, 0.0]);
    normal = solidKtx2(const [0.5, 0.5, 1.0], linear: true);
    glb = ktx2TexturedQuadGlb(baseColorKtx2: baseColor, normalKtx2: normal);
  });

  /// The mean of [rgba]'s texels, [stride] bytes each (RGB first).
  ({double r, double g, double b}) meanColour(Uint8List rgba, {int stride = 4}) {
    var r = 0.0, g = 0.0, b = 0.0;
    final n = rgba.length ~/ stride;
    for (var i = 0; i < rgba.length; i += stride) {
      r += rgba[i];
      g += rgba[i + 1];
      b += rgba[i + 2];
    }
    return (r: r / n, g: g / n, b: b / n);
  }

  test('the parsed mesh bakes the KTX2 base colour into its vertex colours, not the flat factor', () async {
    final mesh = (await GlbParserService.parseGlb(glb))!;
    final colours = mesh.vertexColors;
    expect(colours, isNotNull);
    final mean = meanColour(colours!, stride: 3); // RGB per vertex
    expect(mean.r, greaterThan(200), reason: 'mean vertex colour $mean');
    expect(mean.g, lessThan(60), reason: 'mean vertex colour $mean');
    expect(mean.b, lessThan(60), reason: 'mean vertex colour $mean');
  });

  test('the sanitizer keeps KTX2 images as KTX2 and needs no decode for them', () {
    final work = GlbParserService.inspectImageWork(glb);
    expect(work.needsDecoding, isFalse, reason: 'a KTX2 within the budget is read from its header');
    final sanitized = GlbParserService.convertGlbTgaToPng(glb);
    final doc = GlbDocument.parse(sanitized);
    for (final image in (doc.json['images'] as List).cast<Map>()) {
      expect(image['mimeType'], 'image/ktx2');
      final view = (doc.json['bufferViews'] as List)[image['bufferView'] as int] as Map;
      final at = (view['byteOffset'] as int?) ?? 0;
      expect(EncodedImageFormat.sniff(doc.bin.sublist(at, at + 16)), EncodedImageFormat.ktx2);
    }
  });

  test('an import references each KTX2 texture from its own material slot and keeps it as KTX2', () async {
    final root = Directory.systemTemp.createTempSync('ktx2_import_');
    addTearDown(() => root.deleteSync(recursive: true));
    File('${root.path}/P.lmproject').writeAsStringSync(jsonEncode(const LuminaProject(projectName: 'P').toMap()));
    final source = File('${root.path}/Ktx2Quad.glb')..writeAsBytesSync(glb);

    await AssetRepository().importExternalFile(projectPath: root.path, sourceFilePath: source.path);

    final files = Directory('${root.path}/contents').listSync(recursive: true).whereType<File>().toList();
    final assets = {
      for (final f in files.where((f) => f.path.endsWith('.lmas')))
        f.path.replaceAll(r'\', '/').substring(root.path.length + 1): LuminaAsset.fromBytes(f.readAsBytesSync()),
    };
    final material = assets.values.firstWhere((a) => a.type == AssetType.filamat);
    final slots = {for (final r in material.references) r.slotName: r.assetPath.replaceAll(r'\', '/')};
    expect(slots.keys, containsAll(['baseColorMap', 'normalMap']));

    LuminaAsset textureAt(String path) => assets.entries.firstWhere((e) => path.endsWith(e.key)).value;
    final base = textureAt(slots['baseColorMap']!);
    final normalMap = textureAt(slots['normalMap']!);
    expect(base.type, AssetType.texture);
    expect(base.name, contains('BaseColor'));
    expect(normalMap.name, contains('Normal'));
    expect(base.rawPayload, baseColor, reason: 'the base colour slot holds the base colour image');
    expect(normalMap.rawPayload, normal, reason: 'the normal slot holds the normal map image');
    expect(base.metadata['format'], 'KTX2');
    expect(jsonDecode(normalMap.metadata['texture_settings']!), containsPair('srgb', false));

    // The companion image beside the texture asset is a .ktx2, not KTX2 bytes named .png.
    final companions = files.where((f) => !f.path.endsWith('.lmas') && f.path.contains('T_Ktx2')).map((f) => f.path).toList();
    expect(companions, isNotEmpty);
    expect(companions.where((p) => p.endsWith('.png')), isEmpty, reason: '$companions');
    expect(companions.where((p) => p.endsWith('.ktx2')), hasLength(2), reason: '$companions');

    // The base colour texture's own pixels are red.
    final pixels = Ktx2Decoder.decodeRgba8(base.rawPayload!)!;
    expect(meanColour(pixels.rgba).r, greaterThan(200));
  });
}

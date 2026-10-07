import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';

/// Regression coverage: imported materials must keep every texture they
/// detected.
///
/// The importer detected every texture a glTF material referenced and then
/// emitted the same baseColor-only stub shader for all of them, so a mesh
/// imported with its textures came back with materials that could not sample
/// any of them.
void main() {
  late Directory projectDir;

  setUp(() {
    projectDir = Directory.systemTemp.createTempSync('imported_mat_');
    Directory('${projectDir.path}/contents/textures').createSync(recursive: true);
  });

  tearDown(() {
    if (projectDir.existsSync()) projectDir.deleteSync(recursive: true);
  });

  Future<String> importAndReadMaterialSource() async {
    final staged = File('${projectDir.path}/SM_Textured.glb');
    staged.writeAsBytesSync(_texturedGlb());

    final converted = await AssetRepository().convertStagedAsset(
      projectPath: projectDir.path,
      stagedFilePath: staged.path,
      detectedType: AssetType.filamesh,
    );

    final materials = converted['materials'] as List;
    expect(materials, hasLength(1), reason: 'the fixture declares one material');
    return (materials.single as Map)['rawMatSource'] as String;
  }

  test('generated material declares and samples the textures the importer found', () async {
    final source = await importAndReadMaterialSource();

    expect(source, contains('sampler2d'), reason: 'the material must declare samplers');
    expect(source, contains('baseColorMap'));
    expect(source, contains('normalMap'));
    expect(source, contains('metallicRoughnessMap'));

    // Declaring is not enough — the fragment has to read them.
    expect(source, contains('materialParams_baseColorMap'));
    expect(source, contains('materialParams_normalMap'));
    expect(source, contains('materialParams_metallicRoughnessMap'));

    // Sampling needs UVs interpolated through to the fragment stage.
    expect(source, contains('requires'));
    expect(source, contains('uv0'));
  });

  test('normal is written before prepareMaterial, as Filament requires', () async {
    final source = await importAndReadMaterialSource();

    final normalAt = source.indexOf('material.normal');
    final prepareAt = source.indexOf('prepareMaterial(material)');

    expect(normalAt, greaterThan(-1), reason: 'the normal map must reach material.normal');
    expect(prepareAt, greaterThan(-1));
    expect(
      normalAt,
      lessThan(prepareAt),
      reason: 'Filament ignores material.normal written after prepareMaterial, so a normal '
          'map assigned afterwards is silently dropped',
    );
  });

  test('the glTF base colour factor survives into the shader', () async {
    final source = await importAndReadMaterialSource();

    // The fixture's baseColorFactor is [0.25, 0.5, 0.75, 1.0]. Baking it in means
    // an imported material is correct without anyone setting parameters at runtime.
    expect(source, contains('0.25'));
    expect(source, contains('0.5'));
    expect(source, contains('0.75'));
  });

  test('a material with no textures still gets a valid, non-black shader', () async {
    final staged = File('${projectDir.path}/SM_Plain.glb');
    staged.writeAsBytesSync(_texturedGlb(withTextures: false));

    final converted = await AssetRepository().convertStagedAsset(
      projectPath: projectDir.path,
      stagedFilePath: staged.path,
      detectedType: AssetType.filamesh,
    );

    final source = ((converted['materials'] as List).single as Map)['rawMatSource'] as String;

    expect(source, isNot(contains('sampler2d')));
    expect(source, contains('prepareMaterial(material)'));
    expect(source, contains('material.baseColor'));
    expect(source, contains('0.25'), reason: 'the base colour factor is still baked in');
  });
}

Uint8List _solidPng(int width, int height) {
  final rgba = Uint8List(width * height * 4);
  for (int i = 0; i < rgba.length; i += 4) {
    rgba[i] = 120;
    rgba[i + 1] = 140;
    rgba[i + 2] = 160;
    rgba[i + 3] = 255;
  }
  return TgaDecoderService.encodePng(rgba, width, height);
}

/// A GLB with one material carrying base-colour, metallic-roughness and normal
/// textures (or none, when [withTextures] is false).
Uint8List _texturedGlb({bool withTextures = true}) {
  final png = _solidPng(8, 8);
  final positions = Float32List.fromList([0, 0, 0, 1, 0, 0, 0, 1, 0]);
  final uvs = Float32List.fromList([0, 0, 1, 0, 0, 1]);
  final geometry = positions.buffer.asUint8List();
  final uvBytes = uvs.buffer.asUint8List();

  final bin = BytesBuilder();
  final imageOffsets = <int>[];
  var cursor = 0;
  if (withTextures) {
    for (var i = 0; i < 3; i++) {
      imageOffsets.add(cursor);
      bin.add(png);
      final pad = (4 - (png.length % 4)) % 4;
      bin.add(Uint8List(pad));
      cursor += png.length + pad;
    }
  }
  final geometryOffset = cursor;
  bin.add(geometry);
  cursor += geometry.length;
  final uvOffset = cursor;
  bin.add(uvBytes);
  cursor += uvBytes.length;
  final binBytes = bin.toBytes();

  final bufferViews = <Map<String, dynamic>>[
    if (withTextures)
      for (var i = 0; i < 3; i++)
        {'buffer': 0, 'byteOffset': imageOffsets[i], 'byteLength': png.length},
    {'buffer': 0, 'byteOffset': geometryOffset, 'byteLength': geometry.length},
    {'buffer': 0, 'byteOffset': uvOffset, 'byteLength': uvBytes.length},
  ];
  final positionBv = withTextures ? 3 : 0;
  final uvBv = positionBv + 1;

  final material = <String, dynamic>{
    'name': 'M_Fixture',
    'pbrMetallicRoughness': <String, dynamic>{
      'baseColorFactor': [0.25, 0.5, 0.75, 1.0],
      if (withTextures) 'baseColorTexture': {'index': 0},
      if (withTextures) 'metallicRoughnessTexture': {'index': 1},
    },
    if (withTextures) 'normalTexture': {'index': 2},
  };

  final json = <String, dynamic>{
    'asset': {'version': '2.0'},
    'buffers': [
      {'byteLength': binBytes.length},
    ],
    'bufferViews': bufferViews,
    if (withTextures)
      'images': [
        for (var i = 0; i < 3; i++) {'bufferView': i, 'mimeType': 'image/png'},
      ],
    if (withTextures)
      'textures': [
        for (var i = 0; i < 3; i++) {'source': i},
      ],
    'materials': [material],
    'accessors': [
      {
        'bufferView': positionBv,
        'componentType': 5126,
        'count': 3,
        'type': 'VEC3',
        'min': [0.0, 0.0, 0.0],
        'max': [1.0, 1.0, 0.0],
      },
      {
        'bufferView': uvBv,
        'componentType': 5126,
        'count': 3,
        'type': 'VEC2',
      },
    ],
    'meshes': [
      {
        'name': 'Mesh0',
        'primitives': [
          {
            'attributes': {'POSITION': 0, 'TEXCOORD_0': 1},
            'material': 0,
          },
        ],
      }
    ],
    'nodes': [
      {'name': 'MeshNode', 'mesh': 0},
    ],
    'scenes': [
      {
        'nodes': [0],
      }
    ],
    'scene': 0,
  };

  final jsonBytes = utf8.encode(jsonEncode(json));
  final jsonPadded = (jsonBytes.length + 3) & ~3;
  final jsonChunk = Uint8List(jsonPadded)
    ..fillRange(0, jsonPadded, 0x20)
    ..setRange(0, jsonBytes.length, jsonBytes);

  final binPadded = (binBytes.length + 3) & ~3;
  final binChunk = Uint8List(binPadded)..setRange(0, binBytes.length, binBytes);

  final total = 12 + 8 + jsonPadded + 8 + binPadded;
  final glb = Uint8List(total);
  final bd = ByteData.sublistView(glb);

  bd.setUint32(0, 0x46546C67, Endian.little);
  bd.setUint32(4, 2, Endian.little);
  bd.setUint32(8, total, Endian.little);
  bd.setUint32(12, jsonPadded, Endian.little);
  bd.setUint32(16, 0x4E4F534A, Endian.little);
  glb.setRange(20, 20 + jsonPadded, jsonChunk);

  final binHeader = 20 + jsonPadded;
  bd.setUint32(binHeader, binPadded, Endian.little);
  bd.setUint32(binHeader + 4, 0x004E4942, Endian.little);
  glb.setRange(binHeader + 8, binHeader + 8 + binPadded, binChunk);

  return glb;
}

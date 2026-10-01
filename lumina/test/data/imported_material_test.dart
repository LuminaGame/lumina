import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

/// The shared test-assets checkout (`LUMINA_TEST_ASSETS`, else next to the repo).
String testAssetsPath() =>
    Platform.environment['LUMINA_TEST_ASSETS'] ?? '${Directory.current.parent.path}/test-assets';

void main() {
  test('a glTF import writes the material source the public builder produces', () async {
    final barrel = File('${testAssetsPath()}/Props/Barrels/fuel_barrel_red.glb');
    if (!barrel.existsSync()) {
      markTestSkipped('test-assets missing');
      return;
    }
    final root = Directory.systemTemp.createTempSync('imported_material_');
    addTearDown(() => root.deleteSync(recursive: true));
    File('${root.path}/P.lmproject').writeAsStringSync(jsonEncode(const LuminaProject(projectName: 'P').toMap()));
    await AssetRepository().importExternalFile(projectPath: root.path, sourceFilePath: barrel.path);
    final material = Directory('${root.path}/contents')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.lmas'))
        .map((f) => LuminaAsset.fromBytes(f.readAsBytesSync()))
        .firstWhere((a) => a.type == AssetType.filamat);
    List<double> numbers(String key) => material.metadata[key]!.split(',').map(double.parse).toList();
    final source = buildImportedMaterialSource(
      name: material.name,
      baseColor: numbers('baseColor'),
      metallic: double.parse(material.metadata['metallic']!),
      roughness: double.parse(material.metadata['roughness']!),
      emissive: numbers('emissive'),
      textureSlots: [for (final r in material.references) r.slotName],
      doubleSided: material.metadata['doubleSided'] == 'true',
      alphaMode: material.metadata['alphaMode'] ?? 'OPAQUE',
      alphaCutoff: double.tryParse(material.metadata['alphaCutoff'] ?? '') ?? 0.5,
    );
    expect(material.rawMatSource, source);
  });

  test('an imported material becomes a filamat asset in the glTF import format', () {
    const texture = AssetReference(slotName: 'baseColorMap', assetId: 'tex-1', assetPath: 'contents/T_Barrel.lmas');
    const normal = AssetReference(slotName: 'normalMap', assetId: 'tex-2', assetPath: 'contents/T_Barrel_N.lmas');
    final asset = const ImportedMaterial(
      name: 'M_Barrel',
      baseColor: [0.5, 0.25, 1, 1],
      metallic: 0.2,
      roughness: 0.7,
      emissive: [0, 0, 0],
      textures: [texture, normal],
      metadata: {'unreal_source': '/Game/M_Barrel'},
    ).toAsset(assetId: 'mat-1');
    expect(asset.type, AssetType.filamat);
    expect(asset.assetId, 'mat-1');
    expect(asset.metadata['baseColor'], '0.5,0.25,1.0,1.0');
    expect(asset.metadata['metallic'], '0.2');
    expect(asset.metadata['roughness'], '0.7');
    expect(asset.metadata['emissive'], '0.0,0.0,0.0');
    expect(asset.metadata['unreal_source'], '/Game/M_Barrel');
    expect(asset.references.map((r) => r.slotName), ['baseColorMap', 'normalMap']);
    expect(asset.rawMatSource, contains('materialParams_normalMap'));
    expect(asset.rawMatSource, contains('materialParams_baseColorMap'));
    // glTF UVs are sampled unchanged, as gltfio's own materials do.
    expect(asset.rawMatSource, contains('flipUV : false'));
  });

  test('an imported material keeps its sides and alpha mode in its source and metadata', () {
    final asset = const ImportedMaterial(
      name: 'M_Leaf',
      baseColor: [0.3, 0.7, 0.2, 1],
      doubleSided: true,
      alphaMode: 'MASK',
      alphaCutoff: 0.4,
    ).toAsset(assetId: 'mat-2');
    expect(asset.rawMatSource, contains('doubleSided : true'));
    expect(asset.rawMatSource, contains('blending : masked'));
    expect(asset.rawMatSource, contains('maskThreshold : 0.4'));
    expect(asset.metadata['doubleSided'], 'true');
    expect(asset.metadata['alphaMode'], 'MASK');
    expect(asset.metadata['alphaCutoff'], '0.4');
  });

  group('glTF double-sided and alpha modes', () {
    late FilamentEngine engine;
    setUpAll(() => engine = FilamentEngine.create(backend: FilamentBackend.noop)!);
    tearDownAll(() => engine.dispose());

    FilamentMaterial compile(String source) {
      final result = FilamentMatc.compile(source);
      expect(result.ok, isTrue, reason: result.log);
      return FilamentMaterial.fromBuffer(engine: engine, filamatBuffer: result.package!);
    }

    String source({bool doubleSided = false, String alphaMode = 'OPAQUE', double alphaCutoff = 0.5, List<String> slots = const []}) =>
        buildImportedMaterialSource(
          name: 'M_Case',
          baseColor: const [0.2, 0.4, 1, 0.4],
          textureSlots: slots,
          doubleSided: doubleSided,
          alphaMode: alphaMode,
          alphaCutoff: alphaCutoff,
        );

    test('an opaque single-sided material keeps the compiler defaults', () {
      final text = source();
      expect(text, isNot(contains('doubleSided')));
      expect(text, isNot(contains('blending')));
      final m = compile(text);
      expect(m.blendingMode, BlendingMode.opaque);
      expect(m.cullingMode, CullingMode.back);
      expect(m.isDoubleSided, isFalse);
      m.dispose();
    });

    test('a double-sided material draws its back faces', () {
      final text = source(doubleSided: true);
      expect(text, contains('doubleSided : true'));
      final m = compile(text);
      expect(m.isDoubleSided, isTrue);
      expect(m.blendingMode, BlendingMode.opaque);
      // Filament turns culling off on every instance of a double-sided material.
      final instance = m.createInstance();
      expect(instance.cullingMode, CullingMode.none);
      instance.dispose();
      m.dispose();
    });

    test('a MASK material is masked at the glTF alphaCutoff (0.5 by default)', () {
      final given = source(alphaMode: 'MASK', alphaCutoff: 0.3, slots: const ['baseColorMap']);
      expect(given, contains('blending : masked'));
      expect(given, contains('maskThreshold : 0.3'));
      final m = compile(given);
      expect(m.blendingMode, BlendingMode.masked);
      expect(m.maskThreshold, closeTo(0.3, 1e-6));
      m.dispose();
      final byDefault = compile(source(alphaMode: 'MASK'));
      expect(byDefault.maskThreshold, closeTo(0.5, 1e-6));
      byDefault.dispose();
    });

    test('a BLEND material fades by its straight alpha, premultiplied in the fragment as gltfio does', () {
      final text = source(alphaMode: 'BLEND', slots: const ['baseColorMap']);
      expect(text, contains('blending : fade'));
      final premultiply = text.indexOf('material.baseColor.rgb *= material.baseColor.a;');
      expect(premultiply, greaterThan(text.indexOf('texture(materialParams_baseColorMap')),
          reason: 'alpha is the factor times the texture alpha before the colour is premultiplied');
      final m = compile(text);
      expect(m.blendingMode, BlendingMode.fade);
      expect(m.cullingMode, CullingMode.back);
      m.dispose();
    });

    test('a double-sided BLEND material draws both sides in two passes', () {
      final m = compile(source(alphaMode: 'BLEND', doubleSided: true));
      expect(m.blendingMode, BlendingMode.fade);
      expect(m.isDoubleSided, isTrue);
      expect(m.transparencyMode, TransparencyMode.twoPassesTwoSides);
      m.dispose();
    });

    test('a glTF import carries doubleSided, alphaMode and alphaCutoff into the material assets', () async {
      final root = Directory.systemTemp.createTempSync('imported_material_alpha_');
      addTearDown(() => root.deleteSync(recursive: true));
      File('${root.path}/P.lmproject').writeAsStringSync(jsonEncode(const LuminaProject(projectName: 'P').toMap()));
      final glb = File('${root.path}/cards.glb')
        ..writeAsBytesSync(quadsGlb([
          {'name': 'Leaf', 'doubleSided': true},
          {'name': 'Cutout', 'alphaMode': 'MASK', 'alphaCutoff': 0.3},
          {
            'name': 'Glass',
            'alphaMode': 'BLEND',
            'pbrMetallicRoughness': {'baseColorFactor': [0.2, 0.4, 1.0, 0.4], 'metallicFactor': 0.0},
          },
          {'name': 'Solid'},
        ]));
      await AssetRepository().importExternalFile(projectPath: root.path, sourceFilePath: glb.path);
      final materials = {for (final m in _materials(root)) m.name.split('_').last: m};
      expect(materials.keys, containsAll(['Leaf', 'Cutout', 'Glass', 'Solid']));

      final leaf = compile(materials['Leaf']!.rawMatSource);
      expect(leaf.isDoubleSided, isTrue);
      final leafInstance = leaf.createInstance();
      expect(leafInstance.cullingMode, CullingMode.none);
      leafInstance.dispose();
      leaf.dispose();
      expect(materials['Leaf']!.metadata['doubleSided'], 'true');

      final cutout = compile(materials['Cutout']!.rawMatSource);
      expect(cutout.blendingMode, BlendingMode.masked);
      expect(cutout.maskThreshold, closeTo(0.3, 1e-6));
      cutout.dispose();
      expect(materials['Cutout']!.metadata['alphaMode'], 'MASK');
      expect(materials['Cutout']!.metadata['alphaCutoff'], '0.3');

      final glass = compile(materials['Glass']!.rawMatSource);
      expect(glass.blendingMode, BlendingMode.fade);
      glass.dispose();
      expect(materials['Glass']!.metadata['alphaMode'], 'BLEND');
      expect(materials['Glass']!.metadata['baseColor'], '0.2,0.4,1.0,0.4');

      final solid = compile(materials['Solid']!.rawMatSource);
      expect(solid.blendingMode, BlendingMode.opaque);
      expect(solid.cullingMode, CullingMode.back);
      solid.dispose();
    });

    test('an MTL dissolve reaches the imported material as a transparent one through the Assimp conversion', () async {
      final root = Directory.systemTemp.createTempSync('imported_material_obj_');
      addTearDown(() => root.deleteSync(recursive: true));
      File('${root.path}/P.lmproject').writeAsStringSync(jsonEncode(const LuminaProject(projectName: 'P').toMap()));
      final src = Directory('${root.path}/src')..createSync();
      File('${src.path}/pane.mtl').writeAsStringSync('newmtl Pane\nKd 0.8 0.1 0.1\nd 0.5\n\nnewmtl Frame\nKd 0.1 0.6 0.2\n');
      final obj = File('${src.path}/pane.obj')
        ..writeAsStringSync('mtllib pane.mtl\n'
            'v -1 0 0\nv 1 0 0\nv 1 2 0\nv -1 2 0\nv -1 0 -1\nv 1 0 -1\nv 1 2 -1\nv -1 2 -1\n'
            'vn 0 0 1\n'
            'usemtl Pane\nf 1//1 2//1 3//1\nf 1//1 3//1 4//1\n'
            'usemtl Frame\nf 5//1 6//1 7//1\nf 5//1 7//1 8//1\n');
      // Assimp reads the .mtl beside the OBJ: Kd → baseColorFactor,
      // d < 1 → alphaMode BLEND with the dissolve as alpha.
      final glb = '${src.path}/pane.glb';
      expect(await FlutterAssimp.convertFileToGlb(obj.path, glb), isTrue);
      await AssetRepository().importExternalFile(projectPath: root.path, sourceFilePath: glb);
      final materials = {for (final m in _materials(root)) m.name.split('_').last: m};
      expect(materials.keys, containsAll(['Pane', 'Frame']));
      List<double> color(LuminaAsset m) => m.metadata['baseColor']!.split(',').map(double.parse).toList();
      expect(color(materials['Pane']!)[0], closeTo(0.8, 1e-3));
      expect(color(materials['Pane']!)[3], closeTo(0.5, 1e-3));
      expect(color(materials['Frame']!)[1], closeTo(0.6, 1e-3));
      final pane = compile(materials['Pane']!.rawMatSource);
      expect(pane.blendingMode, BlendingMode.fade);
      pane.dispose();
      final frame = compile(materials['Frame']!.rawMatSource);
      expect(frame.blendingMode, BlendingMode.opaque);
      frame.dispose();
    });
  });
}

/// The material assets an import wrote under [root].
List<LuminaAsset> _materials(Directory root) => Directory('${root.path}/contents')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.lmas'))
    .map((f) => LuminaAsset.fromBytes(f.readAsBytesSync()))
    .where((a) => a.type == AssetType.filamat)
    .toList();

/// A real GLB: one 1 m quad (positions, normals, indices) facing +Z per
/// material in [materials], each its own mesh node, 1.2 m apart along X.
Uint8List quadsGlb(List<Map<String, Object?>> materials) {
  final bin = BytesBuilder()
    ..add(Float32List.fromList([-0.5, 0, 0, 0.5, 0, 0, 0.5, 1, 0, -0.5, 1, 0]).buffer.asUint8List())
    ..add(Float32List.fromList([0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1]).buffer.asUint8List())
    ..add(Uint16List.fromList([0, 1, 2, 0, 2, 3]).buffer.asUint8List());
  while (bin.length % 4 != 0) {
    bin.addByte(0);
  }
  final json = {
    'asset': {'version': '2.0'},
    'scene': 0,
    'scenes': [
      {'nodes': [for (var i = 0; i < materials.length; i++) i]},
    ],
    'nodes': [
      for (var i = 0; i < materials.length; i++) {'mesh': i, 'translation': [i * 1.2, 0, 0]},
    ],
    'meshes': [
      for (var i = 0; i < materials.length; i++)
        {
          'primitives': [
            {'attributes': {'POSITION': 0, 'NORMAL': 1}, 'indices': 2, 'material': i},
          ],
        },
    ],
    'materials': materials,
    'buffers': [
      {'byteLength': bin.length},
    ],
    'bufferViews': [
      {'buffer': 0, 'byteOffset': 0, 'byteLength': 48, 'target': 34962},
      {'buffer': 0, 'byteOffset': 48, 'byteLength': 48, 'target': 34962},
      {'buffer': 0, 'byteOffset': 96, 'byteLength': 12, 'target': 34963},
    ],
    'accessors': [
      {'bufferView': 0, 'componentType': 5126, 'count': 4, 'type': 'VEC3', 'min': [-0.5, 0, 0], 'max': [0.5, 1, 0]},
      {'bufferView': 1, 'componentType': 5126, 'count': 4, 'type': 'VEC3'},
      {'bufferView': 2, 'componentType': 5123, 'count': 6, 'type': 'SCALAR'},
    ],
  };
  final jsonChunk = BytesBuilder()..add(utf8.encode(jsonEncode(json)));
  while (jsonChunk.length % 4 != 0) {
    jsonChunk.addByte(0x20);
  }
  final jsonBytes = jsonChunk.toBytes();
  final binBytes = bin.toBytes();
  final header = ByteData(12)
    ..setUint32(0, 0x46546C67, Endian.little)
    ..setUint32(4, 2, Endian.little)
    ..setUint32(8, 12 + 8 + jsonBytes.length + 8 + binBytes.length, Endian.little);
  ByteData chunk(int length, int type) => ByteData(8)
    ..setUint32(0, length, Endian.little)
    ..setUint32(4, type, Endian.little);
  return (BytesBuilder()
        ..add(header.buffer.asUint8List())
        ..add(chunk(jsonBytes.length, 0x4E4F534A).buffer.asUint8List())
        ..add(jsonBytes)
        ..add(chunk(binBytes.length, 0x004E4942).buffer.asUint8List())
        ..add(binBytes))
      .toBytes();
}

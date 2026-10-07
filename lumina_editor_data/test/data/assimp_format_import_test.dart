import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumina_editor_data/lumina_editor.dart';

/// Importing a Collada, 3DS, PLY or DirectX file converts it from its own
/// folder and embeds the textures it references, found like an FBX's.
void main() {
  late Directory root;
  late Directory src;

  setUp(() {
    root = Directory.systemTemp.createTempSync('assimp_format_import_');
    File('${root.path}/P.lmproject').writeAsStringSync(jsonEncode(const LuminaProject(projectName: 'P').toMap()));
    src = Directory('${root.path}/source files')..createSync();
  });
  tearDown(() => root.deleteSync(recursive: true));

  List<LuminaAsset> assets(AssetType type) {
    final contents = Directory('${root.path}/contents');
    if (!contents.existsSync()) return const [];
    return contents
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.lmas'))
        .map((f) => LuminaAsset.fromBytes(f.readAsBytesSync()))
        .where((a) => a.type == type)
        .toList();
  }

  List<String> warningsSince(int start) =>
      EngineLoggerService().logs.skip(start).where((e) => e.level == 'warning').map((e) => e.message).toList();

  void writePng(String path, img.ColorRgb8 colour) {
    File(path)
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(img.encodePng(img.Image(width: 8, height: 8)..clear(colour)));
  }

  /// The imported mesh's GLB: its triangle count and position bounds.
  ({int triangles, List<double> min, List<double> max}) geometry() {
    final mesh = assets(AssetType.filamesh).single;
    final glb = mesh.rawPayload!;
    final length = ByteData.sublistView(glb).getUint32(12, Endian.little);
    final json = jsonDecode(utf8.decode(glb.sublist(20, 20 + length))) as Map<String, dynamic>;
    final accessors = json['accessors'] as List;
    var triangles = 0;
    final lo = [double.infinity, double.infinity, double.infinity];
    final hi = [-double.infinity, -double.infinity, -double.infinity];
    for (final m in json['meshes'] as List) {
      for (final p in (m as Map)['primitives'] as List) {
        triangles += (accessors[(p as Map)['indices'] as int] as Map)['count'] as int;
        final pos = accessors[(p['attributes'] as Map)['POSITION'] as int] as Map;
        for (var i = 0; i < 3; i++) {
          lo[i] = lo[i] < (pos['min'][i] as num) ? lo[i] : (pos['min'][i] as num).toDouble();
          hi[i] = hi[i] > (pos['max'][i] as num) ? hi[i] : (pos['max'][i] as num).toDouble();
        }
      }
    }
    return (triangles: triangles ~/ 3, min: lo, max: hi);
  }

  /// The base colour texture of the one imported material, decoded.
  img.Image? baseColorImage() {
    final material = assets(AssetType.filamat).single;
    final ref = material.references.where((r) => r.slotName == 'baseColorMap').firstOrNull;
    if (ref == null) return null;
    final texture = assets(AssetType.texture).singleWhere((t) => t.assetId == ref.assetId);
    return img.decodeImage(texture.rawPayload!);
  }

  bool skipWithoutImporters() {
    if (!FlutterAssimp.isAvailable || !FlutterAssimp.isSupportedFormat('dae')) {
      markTestSkipped('Assimp bridge (with its Collada / 3DS / PLY / X importers) not loaded');
      return true;
    }
    return false;
  }

  test('a Collada file embeds the texture it references by relative path', () async {
    if (skipWithoutImporters()) return;
    writePng('${src.path}/Maps/crate.png', img.ColorRgb8(200, 120, 40));
    final dae = File('${src.path}/crate.dae')..writeAsStringSync(colladaQuad('Maps/crate.png'));

    await AssetRepository().importExternalFile(projectPath: root.path, sourceFilePath: dae.path);

    final image = baseColorImage();
    expect(image, isNotNull, reason: 'the material samples the Collada image');
    final p = image!.getPixel(0, 0);
    expect([p.r, p.g, p.b], [200, 120, 40]);
    final g = geometry();
    expect(g.triangles, 2, reason: 'geometry unchanged');
    expect(g.min[0], closeTo(-1, 1e-4));
    expect(g.max[0], closeTo(1, 1e-4));
    expect(g.max[1], closeTo(2, 1e-4));
    final temp = Directory('${root.path}/temp');
    expect(temp.existsSync() ? temp.listSync(recursive: true).whereType<File>() : const <File>[], isEmpty);
  });

  test('a 3DS file finds its 8.3 upper-case texture name in a textures folder', () async {
    if (skipWithoutImporters()) return;
    writePng('${src.path}/textures/crate.png', img.ColorRgb8(30, 90, 220));
    final file = File('${src.path}/crate.3ds')..writeAsBytesSync(threeDsQuad('CRATE.PNG'));

    await AssetRepository().importExternalFile(projectPath: root.path, sourceFilePath: file.path);

    final p = baseColorImage()!.getPixel(0, 0);
    expect([p.r, p.g, p.b], [30, 90, 220]);
    expect(geometry().triangles, 2);
  });

  test('a DirectX file finds its texture in the chosen Textures Folder', () async {
    if (skipWithoutImporters()) return;
    final chosen = Directory('${root.path}/elsewhere/pics')..createSync(recursive: true);
    writePng('${chosen.path}/crate.png', img.ColorRgb8(10, 200, 90));
    final file = File('${src.path}/crate.x')..writeAsStringSync(directXQuad('C:/art/old machine/crate.png'));

    await AssetRepository().importExternalFile(
      projectPath: root.path,
      sourceFilePath: file.path,
      textureSearchDirs: [chosen.path],
    );

    final p = baseColorImage()!.getPixel(0, 0);
    expect([p.r, p.g, p.b], [10, 200, 90]);
    expect(geometry().triangles, 2);
  });

  test('a PLY whose texture is missing imports and warns once', () async {
    if (skipWithoutImporters()) return;
    final file = File('${src.path}/tile.ply')..writeAsStringSync(plyQuad('tile_missing.png'));
    final start = EngineLoggerService().logs.length;

    await AssetRepository().importExternalFile(projectPath: root.path, sourceFilePath: file.path);

    final warnings = warningsSince(start);
    expect(warnings.where((w) => w.contains('tile_missing.png')), hasLength(1), reason: '$warnings');
    expect(geometry().triangles, 2);
    expect(assets(AssetType.texture), isEmpty);
  });

  test('a Collada file Assimp cannot read is refused without writing an asset', () async {
    if (skipWithoutImporters()) return;
    final file = File('${src.path}/broken.dae')..writeAsStringSync('<?xml version="1.0"?><COLLADA><library_');

    await expectLater(
      AssetRepository().importExternalFile(projectPath: root.path, sourceFilePath: file.path),
      throwsA(anything),
    );
    expect(assets(AssetType.filamesh), isEmpty);
  });

  test('the import dialog offers the formats Assimp reads', () {
    for (final ext in ['dae', '3ds', 'ply', 'x', 'stl']) {
      expect(ImportFormats.kindOf('model.$ext'), ImportFormatKind.mesh, reason: ext);
      expect(ImportFormats.extensions, contains(ext));
    }
  });
}

String colladaQuad(String texture) => '''<?xml version="1.0" encoding="utf-8"?>
<COLLADA xmlns="http://www.collada.org/2005/11/COLLADASchema" version="1.4.1">
  <asset><unit name="meter" meter="1"/><up_axis>Y_UP</up_axis></asset>
  <library_images><image id="crate_png" name="crate_png"><init_from>$texture</init_from></image></library_images>
  <library_effects><effect id="crate-fx"><profile_COMMON>
    <newparam sid="crate-surface"><surface type="2D"><init_from>crate_png</init_from></surface></newparam>
    <newparam sid="crate-sampler"><sampler2D><source>crate-surface</source></sampler2D></newparam>
    <technique sid="common"><lambert><diffuse><texture texture="crate-sampler" texcoord="UVMap"/></diffuse></lambert></technique>
  </profile_COMMON></effect></library_effects>
  <library_materials><material id="Crate-mat" name="Crate"><instance_effect url="#crate-fx"/></material></library_materials>
  <library_geometries><geometry id="quad" name="Quad"><mesh>
    <source id="pos"><float_array id="pos-a" count="12">-1 0 0 1 0 0 1 2 0 -1 2 0</float_array>
      <technique_common><accessor source="#pos-a" count="4" stride="3"><param name="X" type="float"/><param name="Y" type="float"/><param name="Z" type="float"/></accessor></technique_common></source>
    <source id="uv"><float_array id="uv-a" count="8">0 0 1 0 1 1 0 1</float_array>
      <technique_common><accessor source="#uv-a" count="4" stride="2"><param name="S" type="float"/><param name="T" type="float"/></accessor></technique_common></source>
    <vertices id="verts"><input semantic="POSITION" source="#pos"/></vertices>
    <triangles material="Crate" count="2"><input semantic="VERTEX" source="#verts" offset="0"/><input semantic="TEXCOORD" source="#uv" offset="1" set="0"/>
      <p>0 0 1 1 2 2 0 0 2 2 3 3</p></triangles>
  </mesh></geometry></library_geometries>
  <library_visual_scenes><visual_scene id="scene"><node id="QuadNode" name="Quad">
    <instance_geometry url="#quad"><bind_material><technique_common>
      <instance_material symbol="Crate" target="#Crate-mat"><bind_vertex_input semantic="UVMap" input_semantic="TEXCOORD" input_set="0"/></instance_material>
    </technique_common></bind_material></instance_geometry>
  </node></visual_scene></library_visual_scenes>
  <scene><instance_visual_scene url="#scene"/></scene>
</COLLADA>
''';

String directXQuad(String texture) => 'xof 0303txt 0032\n'
    'Frame Quad {\n FrameTransformMatrix { 1.0,0.0,0.0,0.0, 0.0,1.0,0.0,0.0, 0.0,0.0,1.0,0.0, 0.0,0.0,0.0,1.0;; }\n'
    ' Mesh {\n  4;\n  -1.0;0.0;0.0;, 1.0;0.0;0.0;, 1.0;2.0;0.0;, -1.0;2.0;0.0;;\n'
    '  2;\n  3;0,2,1;, 3;0,3,2;;\n'
    '  MeshTextureCoords { 4; 0.0;1.0;, 1.0;1.0;, 1.0;0.0;, 0.0;0.0;; }\n'
    '  MeshMaterialList { 1; 2; 0, 0;;\n'
    '   Material Crate { 1.0;1.0;1.0;1.0;; 0.0; 0.0;0.0;0.0;; 0.0;0.0;0.0;; TextureFilename { "$texture"; } }\n'
    '  }\n }\n}\n';

String plyQuad(String texture) => 'ply\nformat ascii 1.0\ncomment TextureFile $texture\n'
    'element vertex 4\nproperty float x\nproperty float y\nproperty float z\nproperty float s\nproperty float t\n'
    'element face 2\nproperty list uchar int vertex_indices\nend_header\n'
    '-1 0 0 0 0\n1 0 0 1 0\n1 2 0 1 1\n-1 2 0 0 1\n3 0 1 2\n3 0 2 3\n';

/// A binary 3DS file: one mesh object with UVs and one material whose
/// diffuse map is [texture].
Uint8List threeDsQuad(String texture) {
  Uint8List chunk(int id, List<Uint8List> body) {
    final length = 6 + body.fold<int>(0, (n, b) => n + b.length);
    final head = ByteData(6)
      ..setUint16(0, id, Endian.little)
      ..setUint32(2, length, Endian.little);
    return Uint8List.fromList([...head.buffer.asUint8List(), for (final b in body) ...b]);
  }

  Uint8List cstr(String s) => Uint8List.fromList([...latin1.encode(s), 0]);
  Uint8List u16(List<int> v) {
    final d = ByteData(v.length * 2);
    for (var i = 0; i < v.length; i++) {
      d.setUint16(i * 2, v[i], Endian.little);
    }
    return d.buffer.asUint8List();
  }

  Uint8List u32(int v) => (ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List();
  Uint8List f32(List<double> v) {
    final d = ByteData(v.length * 4);
    for (var i = 0; i < v.length; i++) {
      d.setFloat32(i * 4, v[i], Endian.little);
    }
    return d.buffer.asUint8List();
  }

  return chunk(0x4D4D, [
    chunk(0x0002, [u32(3)]),
    chunk(0x3D3D, [
      chunk(0x3D3E, [u32(3)]),
      chunk(0xAFFF, [
        chunk(0xA000, [cstr('Crate')]),
        chunk(0xA020, [chunk(0x0011, [Uint8List.fromList([255, 255, 255])])]),
        chunk(0xA200, [chunk(0x0030, [u16([100])]), chunk(0xA300, [cstr(texture)])]),
      ]),
      chunk(0x4000, [
        cstr('Quad'),
        chunk(0x4100, [
          chunk(0x4110, [u16([4]), f32([-1, 0, 0, 1, 0, 0, 1, 0, 2, -1, 0, 2])]),
          chunk(0x4140, [u16([4]), f32([0, 0, 1, 0, 1, 1, 0, 1])]),
          chunk(0x4120, [u16([2, 0, 1, 2, 0, 0, 2, 3, 0]), chunk(0x4130, [cstr('Crate'), u16([2, 0, 1])])]),
          chunk(0x4160, [f32([1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0])]),
        ]),
      ]),
    ]),
  ]);
}

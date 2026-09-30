import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumina/lumina.dart';

/// Importing an `.obj` reads the `.mtl` its `mtllib` names and the texture
/// maps that MTL references, from next to the source file.
void main() {
  late Directory root;
  late Directory src;

  setUp(() {
    root = Directory.systemTemp.createTempSync('obj_mtl_import_');
    File('${root.path}/P.lmproject').writeAsStringSync(jsonEncode(const LuminaProject(projectName: 'P').toMap()));
    src = Directory('${root.path}/source files')..createSync();
  });
  tearDown(() => root.deleteSync(recursive: true));

  const quads = 'v -1 0 0\nv 1 0 0\nv 1 2 0\nv -1 2 0\nv -1 0 -1\nv 1 0 -1\nv 1 2 -1\nv -1 2 -1\n'
      'vt 0 0\nvt 1 0\nvt 1 1\nvt 0 1\n'
      'vn 0 0 1\n';

  List<LuminaAsset> assets(AssetType type) => Directory('${root.path}/contents')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.lmas'))
      .map((f) => LuminaAsset.fromBytes(f.readAsBytesSync()))
      .where((a) => a.type == type)
      .toList();
  Map<String, LuminaAsset> materials() => {for (final m in assets(AssetType.filamat)) m.name: m};
  List<double> color(LuminaAsset m) => m.metadata['baseColor']!.split(',').map(double.parse).toList();
  List<String> warningsSince(int start) =>
      EngineLoggerService().logs.skip(start).where((e) => e.level == 'warning').map((e) => e.message).toList();

  void writePng(String path, img.ColorRgb8 colour) {
    final image = img.Image(width: 8, height: 8)..clear(colour);
    File(path)
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(img.encodePng(image));
  }

  test('an imported OBJ takes its colours and dissolve from the MTL beside it', () async {
    if (!FlutterAssimp.isAvailable) {
      markTestSkipped('Assimp bridge not loaded');
      return;
    }
    File('${src.path}/pane.mtl').writeAsStringSync('newmtl Pane\nKd 0.8 0.1 0.1\nd 0.5\n\nnewmtl Frame\nKd 0.1 0.6 0.2\n');
    final obj = File('${src.path}/pane.obj')
      ..writeAsStringSync('mtllib pane.mtl\n$quads'
          'usemtl Pane\nf 1//1 2//1 3//1\nf 1//1 3//1 4//1\n'
          'usemtl Frame\nf 5//1 6//1 7//1\nf 5//1 7//1 8//1\n');

    await AssetRepository().importExternalFile(projectPath: root.path, sourceFilePath: obj.path);

    final m = materials();
    expect(m.keys, containsAll(['M_Pane', 'M_pane_Frame']), reason: '${m.keys}');
    expect(m.keys.where((k) => k.contains('DefaultMaterial')), isEmpty, reason: 'no Assimp default material: ${m.keys}');
    final pane = color(m['M_Pane']!);
    expect(pane[0], closeTo(0.8, 1e-3));
    expect(pane[1], closeTo(0.1, 1e-3));
    expect(pane[3], closeTo(0.5, 1e-3));
    expect(m['M_Pane']!.metadata['alphaMode'], 'BLEND');
    expect(m['M_Pane']!.rawMatSource, contains('blending : fade'));
    final frame = color(m['M_pane_Frame']!);
    expect(frame[0], closeTo(0.1, 1e-3));
    expect(frame[1], closeTo(0.6, 1e-3));
    expect(frame[3], closeTo(1.0, 1e-3));
    expect(m['M_pane_Frame']!.rawMatSource, isNot(contains('blending')));
    // Nothing is left behind in temp/.
    final temp = Directory('${root.path}/temp');
    expect(temp.existsSync() ? temp.listSync(recursive: true).whereType<File>() : const <File>[], isEmpty);
  });

  test('an imported OBJ embeds the texture maps its MTL names (subfolders, spaces, case)', () async {
    if (!FlutterAssimp.isAvailable) {
      markTestSkipped('Assimp bridge not loaded');
      return;
    }
    writePng('${src.path}/maps/crate diffuse.png', img.ColorRgb8(200, 120, 40));
    writePng('${src.path}/maps/crate_normal.png', img.ColorRgb8(128, 128, 255));
    // The MTL spells the file names with other capitals: they resolve on a
    // case-insensitive file system and by name elsewhere.
    File('${src.path}/Wooden Crate.mtl').writeAsStringSync('newmtl Wood\nKd 1 1 1\n'
        'map_Kd maps/Crate Diffuse.PNG\n'
        'map_Bump -bm 1 maps/Crate_Normal.png\n');
    final obj = File('${src.path}/Wooden Crate.obj')
      ..writeAsStringSync('mtllib Wooden Crate.mtl\n$quads'
          'usemtl Wood\nf 1/1/1 2/2/1 3/3/1\nf 1/1/1 3/3/1 4/4/1\n');

    await AssetRepository().importExternalFile(projectPath: root.path, sourceFilePath: obj.path);

    final wood = materials().values.singleWhere((m) => m.name.endsWith('Wood'));
    final slots = {for (final r in wood.references) r.slotName: r};
    expect(slots.keys, containsAll(['baseColorMap', 'normalMap']), reason: '${wood.references.map((r) => r.slotName)}');
    final textures = assets(AssetType.texture);
    expect(textures, hasLength(2), reason: '${textures.map((t) => t.name)}');
    for (final t in textures) {
      final decoded = img.decodeImage(t.rawPayload!);
      expect(decoded, isNotNull, reason: '${t.name} holds a real image');
      expect(decoded!.width, 8);
    }
    final diffuse = textures.singleWhere((t) => t.name.toLowerCase().contains('diffuse'));
    final pixel = img.decodeImage(diffuse.rawPayload!)!.getPixel(0, 0);
    expect([pixel.r, pixel.g, pixel.b], [200, 120, 40]);
  });

  test('Tr, map_d and map_Ks reach the imported materials', () async {
    if (!FlutterAssimp.isAvailable) {
      markTestSkipped('Assimp bridge not loaded');
      return;
    }
    writePng('${src.path}/leaf.png', img.ColorRgb8(40, 160, 30));
    // A cut-out alpha map: left half clear, right half opaque.
    final cut = img.Image(width: 8, height: 8);
    for (final p in cut) {
      final v = p.x < 4 ? 0 : 255;
      p
        ..r = v
        ..g = v
        ..b = v;
    }
    File('${src.path}/leaf_alpha.png').writeAsBytesSync(img.encodePng(cut));
    writePng('${src.path}/metal spec.png', img.ColorRgb8(90, 90, 90));
    File('${src.path}/mixed.mtl').writeAsStringSync('newmtl Glass\nKd 0.3 0.5 0.9\nTr 0.75\n\n'
        'newmtl Leaf\nKd 1 1 1\nmap_Kd leaf.png\nmap_d -clamp on leaf_alpha.png\n\n'
        'newmtl Metal\nKd 0.7 0.7 0.7\nmap_Ks -o 0 0 0 metal spec.png\n');
    final obj = File('${src.path}/mixed.obj')
      ..writeAsStringSync('mtllib mixed.mtl\n$quads'
          'usemtl Glass\nf 1/1/1 2/2/1 3/3/1\n'
          'usemtl Leaf\nf 1/1/1 3/3/1 4/4/1\n'
          'usemtl Metal\nf 5/1/1 6/2/1 7/3/1\n');

    await AssetRepository().importExternalFile(projectPath: root.path, sourceFilePath: obj.path);

    final m = {for (final e in materials().entries) e.key.split('_').last: e.value};
    expect(color(m['Glass']!)[3], closeTo(0.25, 1e-3), reason: 'Tr is the transparency: alpha = 1 - Tr');
    expect(m['Glass']!.metadata['alphaMode'], 'BLEND');

    final leaf = m['Leaf']!;
    expect(leaf.metadata['alphaMode'], 'MASK', reason: 'a cut-out map_d masks');
    expect(leaf.rawMatSource, contains('blending : masked'));
    final leafMap = leaf.references.singleWhere((r) => r.slotName == 'baseColorMap');
    final leafTexture = assets(AssetType.texture).singleWhere((t) => t.assetId == leafMap.assetId || t.name.contains('leaf'));
    final baked = img.decodeImage(leafTexture.rawPayload!)!;
    expect(baked.getPixel(0, 0).a, 0, reason: 'map_d is the base colour alpha');
    expect(baked.getPixel(7, 0).a, 255);
    expect([baked.getPixel(7, 0).r, baked.getPixel(7, 0).g], [40, 160], reason: 'the colour stays map_Kd');

    expect(m['Metal']!.references.map((r) => r.slotName), contains('specularMap'));
    expect(m['Metal']!.rawMatSource, contains('specularMap'));
  });

  test("Filament's Cornell box keeps its MTL wall colours and light", () async {
    final cornell = File('${Directory.current.parent.path}/filament/assets/models/cornell_box/cornell_box.obj');
    if (!cornell.existsSync() || !FlutterAssimp.isAvailable) {
      markTestSkipped('cornell_box.obj or the Assimp bridge missing');
      return;
    }
    await AssetRepository().importExternalFile(projectPath: root.path, sourceFilePath: cornell.path);
    final m = materials();
    expect(m.keys, unorderedEquals(['M_cornell_box_white', 'M_cornell_box_red', 'M_cornell_box_green', 'M_cornell_box_light']));
    expect(color(m['M_cornell_box_red']!).take(3), [closeTo(0.63, 1e-3), closeTo(0.065, 1e-3), closeTo(0.05, 1e-3)]);
    expect(color(m['M_cornell_box_green']!).take(3), [closeTo(0.14, 1e-3), closeTo(0.45, 1e-3), closeTo(0.091, 1e-3)]);
    expect(m['M_cornell_box_light']!.metadata['emissive'], isNot(startsWith('0.0,0.0,0.0')));
  });

  test('an OBJ whose MTL or texture is missing still imports and says what is missing', () async {
    if (!FlutterAssimp.isAvailable) {
      markTestSkipped('Assimp bridge not loaded');
      return;
    }
    final noMtl = File('${src.path}/lost.obj')
      ..writeAsStringSync('mtllib lost.mtl\n$quads' 'usemtl Lost\nf 1//1 2//1 3//1\n');
    var start = EngineLoggerService().logs.length;
    await AssetRepository().importExternalFile(projectPath: root.path, sourceFilePath: noMtl.path);
    var warnings = warningsSince(start);
    expect(warnings.where((w) => w.contains('lost.mtl')), hasLength(1), reason: '$warnings');
    expect(assets(AssetType.filamesh), hasLength(1));

    File('${src.path}/tile.mtl').writeAsStringSync('newmtl Tile\nKd 0.2 0.3 0.9\nmap_Kd tile_missing.png\n');
    final noTexture = File('${src.path}/tile.obj')
      ..writeAsStringSync('mtllib tile.mtl\n$quads' 'usemtl Tile\nf 1/1/1 2/2/1 3/3/1\n');
    start = EngineLoggerService().logs.length;
    await AssetRepository().importExternalFile(projectPath: root.path, sourceFilePath: noTexture.path);
    warnings = warningsSince(start);
    expect(warnings.where((w) => w.contains('tile_missing.png')), hasLength(1), reason: '$warnings');
    final tile = materials().values.singleWhere((m) => m.name.endsWith('Tile'));
    expect(color(tile)[2], closeTo(0.9, 1e-3), reason: 'the MTL colour is kept without its texture');
    expect(tile.references.where((r) => r.slotName == 'baseColorMap'), isEmpty);
  });
}

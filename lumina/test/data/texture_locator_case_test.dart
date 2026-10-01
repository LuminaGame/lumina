import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumina/lumina.dart';

/// A texture path whose folders are spelled with other capitals than on disk
/// still resolves on a case-sensitive file system. The folders here are made
/// case-sensitive for real: Linux folders are; on Windows the test turns the
/// temp folder's case sensitivity on (`fsutil file setCaseSensitiveInfo`,
/// inherited by its subfolders); where neither works (macOS by default) the
/// tests skip.
void main() {
  late Directory root;
  late bool caseSensitive;

  setUp(() {
    root = Directory.systemTemp.createTempSync('texture_case_');
    if (Platform.isWindows) {
      Process.runSync('fsutil', ['file', 'setCaseSensitiveInfo', root.path, 'enable']);
    }
    final probe = Directory('${root.path}/probe')..createSync();
    caseSensitive = !Directory('${root.path}/PROBE').existsSync();
    probe.deleteSync();
  });
  tearDown(() => root.deleteSync(recursive: true));

  bool skipUnlessCaseSensitive() {
    if (!caseSensitive) markTestSkipped('no case-sensitive folder available here');
    return !caseSensitive;
  }

  void writePng(String path, img.ColorRgb8 colour) {
    File(path)
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(img.encodePng(img.Image(width: 8, height: 8)..clear(colour)));
  }

  String rel(File? f) => f == null ? 'null' : f.path.replaceAll('\\', '/').substring(root.path.replaceAll('\\', '/').length + 1);

  test('a folder spelled with other capitals is found segment by segment', () {
    if (skipUnlessCaseSensitive()) return;
    writePng('${root.path}/src/maps/Wood/oak.png', img.ColorRgb8(1, 2, 3));
    final model = File('${root.path}/src/crate.obj')..writeAsStringSync('');
    final locator = FbxTextureLocator(fbxFile: model);

    expect(File('${root.path}/src/Maps/wood/oak.png').existsSync(), isFalse, reason: 'the folder is case-sensitive');
    expect(rel(locator.locateReference('Maps/wood/oak.png')), 'src/maps/Wood/oak.png');
    expect(rel(locator.locateReference(r'MAPS\WOOD\OAK.PNG')), 'src/maps/Wood/oak.png');
    expect(rel(locator.locateReference('./Maps/../maps/wood/oak.png')), 'src/maps/Wood/oak.png');
    expect(locator.locateReference('Maps/pine/oak.png'), isNull, reason: 'a folder that is not there is not guessed');
  });

  test('the exactly spelled folder wins, otherwise the first by name', () {
    if (skipUnlessCaseSensitive()) return;
    writePng('${root.path}/src/Maps/wood.png', img.ColorRgb8(1, 1, 1));
    writePng('${root.path}/src/maps/wood.png', img.ColorRgb8(2, 2, 2));
    writePng('${root.path}/src/MAPS/wood.png', img.ColorRgb8(3, 3, 3));
    final model = File('${root.path}/src/crate.obj')..writeAsStringSync('');
    final locator = FbxTextureLocator(fbxFile: model);

    expect(rel(locator.locateReference('maps/wood.png')), 'src/maps/wood.png');
    expect(rel(locator.locateReference('Maps/wood.png')), 'src/Maps/wood.png');
    // No exact spelling: 'MAPS' < 'Maps' < 'maps' (by code unit), every time.
    for (var i = 0; i < 3; i++) {
      expect(rel(locator.locateReference('mAPS/WOOD.png')), 'src/MAPS/wood.png');
    }
  });

  test('an OBJ whose MTL names Maps/ embeds the texture kept in maps/', () async {
    if (skipUnlessCaseSensitive()) return;
    if (!FlutterAssimp.isAvailable) {
      markTestSkipped('Assimp bridge not loaded');
      return;
    }
    File('${root.path}/P.lmproject').writeAsStringSync(jsonEncode(const LuminaProject(projectName: 'P').toMap()));
    final src = Directory('${root.path}/src')..createSync();
    writePng('${src.path}/maps/wood.png', img.ColorRgb8(200, 120, 40));
    File('${src.path}/Materials/crate.mtl')
      ..parent.createSync()
      ..writeAsStringSync('newmtl Wood\nKd 1 1 1\nmap_Kd Maps/wood.png\n');
    final obj = File('${src.path}/crate.obj')
      ..writeAsStringSync('mtllib materials/crate.mtl\n'
          'v -1 0 0\nv 1 0 0\nv 1 2 0\nv -1 2 0\nvt 0 0\nvt 1 0\nvt 1 1\nvt 0 1\nvn 0 0 1\n'
          'usemtl Wood\nf 1/1/1 2/2/1 3/3/1\nf 1/1/1 3/3/1 4/4/1\n');

    await AssetRepository().importExternalFile(projectPath: root.path, sourceFilePath: obj.path);

    final lmas = Directory('${root.path}/contents')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.lmas'))
        .map((f) => LuminaAsset.fromBytes(f.readAsBytesSync()))
        .toList();
    final wood = lmas.singleWhere((a) => a.type == AssetType.filamat);
    final ref = wood.references.singleWhere((r) => r.slotName == 'baseColorMap');
    final texture = lmas.singleWhere((a) => a.assetId == ref.assetId);
    final p = img.decodeImage(texture.rawPayload!)!.getPixel(0, 0);
    expect([p.r, p.g, p.b], [200, 120, 40]);
  });
}

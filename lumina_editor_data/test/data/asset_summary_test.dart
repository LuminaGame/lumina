import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina/testing.dart';

import 'project_template_test.dart' show createTemplateProject;

/// [LuminaAsset.readSummary] learns what a `.lmas` is — id,
/// name, type, metadata, references, thumbnail and payload byte ranges —
/// without base64-decoding `thumbnail_png` / `raw_payload`, and new files put
/// those two last so the summary comes from a small prefix.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void expectSameAsFullDecode(File file) {
    final full = LuminaAsset.fromBytes(file.readAsBytesSync());
    final summary = LuminaAsset.readSummary(file);
    final name = file.uri.pathSegments.last;
    expect(summary.assetId, full.assetId, reason: name);
    expect(summary.name, full.name, reason: name);
    expect(summary.type, full.type, reason: name);
    expect(summary.hasThumbnail, full.hasThumbnail, reason: name);
    expect(summary.metadata, full.metadata, reason: name);
    expect([for (final r in summary.references) r.toMap()], [for (final r in full.references) r.toMap()], reason: name);
    expect(summary.hasThumbnailBytes, full.thumbnailPng?.isNotEmpty ?? false, reason: name);
    if (summary.thumbnailRange != null) {
      expect(LuminaAssetSummary.readRange(file, summary.thumbnailRange!), orderedEquals(full.thumbnailPng!), reason: name);
    }
  }

  late Directory temp;
  setUp(() => temp = Directory.systemTemp.createTempSync('lumina_asset_summary_'));
  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  test('readSummary equals the full decode on every .lmas of the Third Person template', () async {
    final config = Directory('${temp.path}/config')..createSync();
    final project = await createTemplateProject(root: temp, configDir: config, name: 'tp_summary', template: kThirdPersonTemplateId);
    final files = Directory('$project/contents')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.lmas'))
        .toList();
    expect(files.length, greaterThan(5));
    for (final f in files) {
      expectSameAsFullDecode(f);
    }
    // The template character is a Blueprint class the summary recognises.
    final character = files.firstWhere((f) => f.path.contains('/blueprints/'));
    final summary = LuminaAsset.readSummary(character);
    expect(summary.blueprintKind, 'class');
    expect(summary.parentClass, isNotNull);
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('a 20 MB mesh .lmas summarises from its prefix (new order) and by scanning past the payload (old order)', () {
    final glb = File('${SmokeArtifacts.testAssetsDir.path}/fixtures/YVO3D_44368.glb');
    if (!glb.existsSync()) return markTestSkipped('test-assets missing: fixtures/YVO3D_44368.glb');
    final asset = LuminaAsset(
      assetId: 'mesh-big',
      name: 'SM_Big',
      type: AssetType.filamesh,
      hasThumbnail: true,
      thumbnailPng: AssetProjectFixture.png(7),
      rawPayload: glb.readAsBytesSync(),
      references: const [AssetReference(slotName: 'material_0', assetId: 'm', assetPath: 'contents/materials/M.lmas')],
      metadata: const {'source': 'fixtures/YVO3D_44368.glb', 'thumbnail_source': 'filament'},
    );
    final modern = File('${temp.path}/SM_Big.lmas')..writeAsBytesSync(asset.toProtoBufferBytes());
    final legacy = File('${temp.path}/SM_Big_legacy.lmas')..writeAsBytesSync(AssetProjectFixture.legacyBytes(asset));
    expect(modern.lengthSync(), greaterThan(20 * 1000 * 1000));
    expectSameAsFullDecode(modern);
    expectSameAsFullDecode(legacy);
    final summary = LuminaAsset.readSummary(modern);
    expect(summary.payloadRange, isNotNull);
    expect(summary.payloadRange!.length, isNull, reason: 'the payload (last field) is never scanned');
    expect(summary.thumbnailRange!.offset, lessThan(summary.payloadRange!.offset));
  });

  test('the payload is never decoded: a fixture whose payload is invalid base64 still summarises', () {
    // Old key order, payload first: the reader has to skip it to reach metadata.
    final json = '{"asset_id":"x1","name":"SM_Broken","type":"filamesh","has_thumbnail":false,'
        '"thumbnail_png":null,"raw_payload":"!!!not base64 at all \\u0000 ###",'
        '"raw_mat_source":"","references":[{"slot_name":"s","asset_id":"a","asset_path":"contents/a.lmas"}],'
        '"metadata":{"source":"broken.glb","k":"v \\"quoted\\""}}';
    final file = File('${temp.path}/SM_Broken.lmas')..writeAsBytesSync([0x4C, 0x4D, 0x41, 0x53, ...utf8.encode(json)]);
    expect(() => LuminaAsset.fromBytes(file.readAsBytesSync()), throwsFormatException,
        reason: 'a full decode chokes on the payload');
    final summary = LuminaAsset.readSummary(file);
    expect(summary.assetId, 'x1');
    expect(summary.type, AssetType.filamesh);
    expect(summary.metadata, {'source': 'broken.glb', 'k': 'v "quoted"'});
    expect(summary.references.single.assetPath, 'contents/a.lmas');
    expect(summary.payloadRange, isNotNull);
  });

  test('a new .lmas has metadata before raw_payload; an old one still loads', () {
    final asset = LuminaAsset(
      assetId: 'a',
      name: 'T_A',
      type: AssetType.texture,
      thumbnailPng: AssetProjectFixture.png(1),
      rawPayload: AssetProjectFixture.png(2),
      metadata: const {'format': 'png'},
    );
    final text = utf8.decode(asset.toProtoBufferBytes().sublist(4));
    expect(text.indexOf('"metadata"'), lessThan(text.indexOf('"raw_payload"')));
    expect(text.indexOf('"references"'), lessThan(text.indexOf('"thumbnail_png"')));
    expect(text.indexOf('"thumbnail_png"'), lessThan(text.indexOf('"raw_payload"')));

    final old = LuminaAsset.fromBytes(AssetProjectFixture.legacyBytes(asset));
    expect(old.metadata, {'format': 'png'});
    expect(old.rawPayload, orderedEquals(asset.rawPayload!));
    expect(old.thumbnailPng, orderedEquals(asset.thumbnailPng!));

    // A raw-JSON patch (ThumbnailService) keeps unknown keys and moves the
    // base64 fields last.
    final patched = LuminaAsset.withTrailingPayload({'raw_payload': 'x', 'thumbnail_png': 'y', 'metadata': {}, 'extra': 1});
    expect(patched.keys.toList(), ['metadata', 'extra', 'thumbnail_png', 'raw_payload']);
  });

  test('a level document (plain JSON, other keys) and a Blueprint document summarise like their full decode', () {
    final level = File('${temp.path}/L_Main.lmas')
      ..writeAsStringSync(jsonEncode({
        'assetId': 'level_L_Main',
        'name': 'L_Main',
        'type': 'level',
        'relativePath': 'contents/levels/L_Main.lmas',
        'rawPayload': null,
        'metadata': {
          'actors': [
            {'id': 'a', 'type': 'PlayerStart'},
          ],
        },
      }));
    expectSameAsFullDecode(level);
    final enumDoc = LuminaAsset(
      assetId: 'e',
      name: 'E_Mode',
      type: AssetType.actor,
      rawPayload: Uint8List.fromList(utf8.encode(jsonEncode(const LuminaBlueprintEnumDocument(name: 'E_Mode', values: ['A']).toJson()))),
    );
    final f = File('${temp.path}/E_Mode.lmas')..writeAsBytesSync(enumDoc.toProtoBufferBytes());
    expectSameAsFullDecode(f);
    expect(LuminaAsset.readSummary(f).blueprintKind, 'enum');
  });
}

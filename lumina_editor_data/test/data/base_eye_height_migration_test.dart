import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';

/// Projects created before the fix store the feet-based 160 cm Base
/// Eye Height in BP_ThirdPersonCharacter's class defaults; opening the
/// project migrates exactly those to the capsule-centre value, once.
void main() {
  late Directory temp;
  late String project;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('eye_migration_');
    project = '${temp.path}/eye_proj';
    Directory(project).createSync(recursive: true);
    File('$project/eye_proj.lmproject').writeAsStringSync(jsonEncode({'project_name': 'eye_proj'}));
  });
  tearDown(() => temp.deleteSync(recursive: true));

  String writeBlueprint(String relative, Map<String, dynamic> document, {AssetType type = AssetType.actor}) {
    final name = relative.split('/').last.replaceAll('.lmas', '');
    File('$project/$relative')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(LuminaAsset(
        assetId: 'id-$name',
        name: name,
        type: type,
        rawPayload: Uint8List.fromList(utf8.encode(jsonEncode(document))),
        metadata: const {'source': 'template:third_person'},
      ).toProtoBufferBytes());
    return relative;
  }

  Map<String, dynamic> payload(String relative) =>
      jsonDecode(utf8.decode(LuminaAsset.fromBytes(File('$project/$relative').readAsBytesSync()).rawPayload!)) as Map<String, dynamic>;

  /// The Third Person template character as an older project stored it.
  Map<String, dynamic> legacyTemplate() =>
      LuminaThirdPersonContent.characterBlueprint()
          .toJson()
        ..['classDefaults'] = {'bUseControllerRotationYaw': true, 'baseEyeHeight': 160.0};

  Map<String, dynamic> withCapsule(Map<String, dynamic> doc, double halfHeight) {
    for (final c in doc['components'] as List) {
      if ((c as Map)['type'] == 'LuminaCapsuleComponent') (c['properties'] as Map)['capsuleHalfHeight'] = halfHeight;
    }
    return doc;
  }

  test('opening a project rewrites the template value on template characters only', () async {
    const tp = 'contents/blueprints/BP_ThirdPersonCharacter.lmas';
    writeBlueprint(tp, legacyTemplate());
    // Its compiled class, as the Blueprint compiler writes it (with a user-code region).
    File('$project/lib/actors/bp_third_person_character.dart')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('class BpThirdPersonCharacter extends LuminaCharacter {\n'
          '  BpThirdPersonCharacter() {\n    bUseControllerRotationYaw = true;\n    baseEyeHeight = 160.0;\n  }\n'
          '  // BEGIN USER CODE\n  // END USER CODE\n}\n');
    // A bigger capsule: the user's own character, left alone.
    const giant = 'contents/blueprints/BP_Giant.lmas';
    writeBlueprint(giant, withCapsule(legacyTemplate(), 120.0));
    // A value the user chose.
    const tuned = 'contents/blueprints/characters/BP_Tuned.lmas';
    writeBlueprint(tuned, legacyTemplate()..['classDefaults'] = {'baseEyeHeight': 150.0});
    // Not a LuminaCharacter.
    const pawn = 'contents/blueprints/BP_Pawn.lmas';
    writeBlueprint(pawn, withCapsule(legacyTemplate()..['parentClass'] = 'LuminaPawn', 90.0));
    final untouched = {for (final p in [giant, tuned, pawn]) p: File('$project/$p').readAsBytesSync()};

    final repo = ProjectRepository(configDir: Directory('${temp.path}/config')..createSync());
    final loaded = await repo.loadProject('$project/eye_proj.lmproject');
    expect(loaded, isNotNull);

    expect((payload(tp)['classDefaults'] as Map)['baseEyeHeight'], LuminaTemplateCharacterTuning.baseEyeHeight);
    expect(LuminaTemplateCharacterTuning.baseEyeHeight, 70.0);
    // Everything else in the document is kept: it is now the current template.
    expect(jsonEncode(payload(tp)), jsonEncode(LuminaThirdPersonContent.characterBlueprint().toJson()));
    final asset = LuminaAsset.fromBytes(File('$project/$tp').readAsBytesSync());
    expect(asset.assetId, 'id-BP_ThirdPersonCharacter');
    expect(asset.metadata['source'], 'template:third_person');
    expect(File('$project/lib/actors/bp_third_person_character.dart').readAsStringSync(), contains('    baseEyeHeight = 70.0;\n'));
    expect(File('$project/lib/actors/bp_third_person_character.dart').readAsStringSync(), isNot(contains('160')));
    for (final e in untouched.entries) {
      expect(File('$project/${e.key}').readAsBytesSync(), e.value, reason: '${e.key} is not the template character');
    }

    final marker = File('$project/${BaseEyeHeightMigration.markerPath}');
    expect(marker.existsSync(), isTrue);
    expect(marker.path, contains('/.lumina/'));
    final record = jsonDecode(marker.readAsStringSync()) as Map;
    expect(record['blueprints'], [tp]);
    expect(record['generated'], ['lib/actors/bp_third_person_character.dart']);

    // Idempotent: a value set back to 160 afterwards is the user's choice.
    writeBlueprint(tp, legacyTemplate());
    final again = repo.migrateBaseEyeHeight(project);
    expect(again.alreadyMigrated, isTrue);
    expect(again.didAnything, isFalse);
    expect((payload(tp)['classDefaults'] as Map)['baseEyeHeight'], 160.0);
  });

  test('migrated Blueprints are recorded as /-separated project-relative paths on every platform', () {
    const nested = 'contents/blueprints/characters/BP_ThirdPersonCharacter.lmas';
    writeBlueprint(nested, legacyTemplate());
    // A native-separator project root, as a Windows directory picker hands it over.
    final nativeRoot = Directory(project).absolute.path.replaceAll('/', Platform.pathSeparator);

    final report = BaseEyeHeightMigration.run(nativeRoot);
    expect(report.migratedBlueprints, [nested]);
    final record = jsonDecode(File('$project/${BaseEyeHeightMigration.markerPath}').readAsStringSync()) as Map;
    expect(record['blueprints'], [nested]);
  });

  test('a project without Blueprints is marked migrated and nothing else changes', () {
    final report = BaseEyeHeightMigration.run(project);
    expect(report.didAnything, isFalse);
    expect(report.alreadyMigrated, isFalse);
    expect(BaseEyeHeightMigration.isMigrated(project), isTrue);
    expect(BaseEyeHeightMigration.run(project).alreadyMigrated, isTrue);
  });

  test('a freshly created Third Person character already carries the new value', () {
    const tp = 'contents/blueprints/BP_ThirdPersonCharacter.lmas';
    writeBlueprint(tp, LuminaThirdPersonContent.characterBlueprint().toJson());
    final before = File('$project/$tp').readAsBytesSync();
    expect(BaseEyeHeightMigration.run(project).didAnything, isFalse);
    expect(File('$project/$tp').readAsBytesSync(), before);
  });
}

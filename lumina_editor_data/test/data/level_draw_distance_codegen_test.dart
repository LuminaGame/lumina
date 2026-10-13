// A placed mesh's Min / Max Draw Distance (Mesh Component Details, metres)
// reaches the generated level in cm through LuminaDrawDistance.apply, for
// static and skeletal meshes alike; meshes without limits are unchanged.
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';

void main() {
  Map<String, dynamic> mesh(String id, String type, String componentType, Map<String, dynamic> properties,
          {bool visible = true}) =>
      {
        'id': id,
        'name': id,
        'type': type,
        'location': [0.0, 0.0, 0.0],
        'meshAssetPath': 'contents/meshes/$id.lmas',
        'isVisible': visible,
        'components': [
          {'id': '${id}_mesh', 'type': componentType, 'name': 'Mesh Component', 'properties': properties},
        ],
      };

  String line(String code, String id) => code.split('\n').firstWhere((l) => l.contains("LuminaObjectKey('$id')"));

  test('static and skeletal meshes take their draw distances in cm; none leaves the actor as it was', () {
    final code = DartCodeGeneratorService().generateLevelDart(levelName: 'L_Far', actors: const [], actorMaps: [
      mesh('rock', 'StaticMesh', 'LuminaMeshComponent', {'maxDrawDistance': 50.0}),
      mesh('crowd', 'SkeletalMesh', 'LuminaSkeletalMeshComponent', {'minDrawDistance': 2.5, 'maxDrawDistance': 300.0}),
      mesh('plain', 'StaticMesh', 'LuminaMeshComponent', {'minDrawDistance': 0.0, 'maxDrawDistance': 0.0}),
      mesh('hidden', 'StaticMesh', 'LuminaMeshComponent', {'maxDrawDistance': 10.0}, visible: false),
    ]);
    expect(line(code, 'rock').trimLeft(), startsWith('LuminaDrawDistance.apply(LuminaActor('));
    expect(line(code, 'rock'), endsWith(', min: 0.0, max: 5000.0),'));
    expect(line(code, 'crowd').trimLeft(), startsWith('LuminaDrawDistance.apply(LuminaLevelSkeletalMesh.build('));
    expect(line(code, 'crowd'), endsWith(', min: 250.0, max: 30000.0),'));
    expect(line(code, 'plain'), isNot(contains('LuminaDrawDistance')));
    expect(line(code, 'hidden'), endsWith(', min: 0.0, max: 1000.0)..hiddenInGame = true,'));
    // The generated level is valid Dart.
    expect(parseString(content: code, throwIfDiagnostics: false).errors, isEmpty);
  });
}

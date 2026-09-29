import 'dart:io';
import 'package:test/test.dart';
import 'package:lumina/data/services/code_generator_service.dart';

void main() {
  late Directory tempProject;
  late DartCodeGeneratorService service;

  setUp(() {
    tempProject = Directory.systemTemp.createTempSync('actor_codegen_test_');
    Directory('${tempProject.path}/lib/actors').createSync(recursive: true);
    service = DartCodeGeneratorService();
  });

  tearDown(() {
    if (tempProject.existsSync()) {
      tempProject.deleteSync(recursive: true);
    }
  });

  group('DartCodeGeneratorService Actor Class Generation Tests', () {
    test('generateActorClassDart generates real Dart class with components and BeginPlay', () {
      final docMap = {
        'parentClass': 'LuminaCharacter',
        'components': [
          {
            'id': 'capsule_root',
            'name': 'CapsuleComponent',
            'type': 'LuminaCapsuleComponent',
            'parentId': null,
            'properties': {'capsuleRadius': 0.5, 'capsuleHalfHeight': 0.88},
          },
        ],
        'eventGraph': {
          'nodes': [
            {
              'id': 'n_begin',
              'registryId': 'event_beginplay',
              'title': 'Event BeginPlay',
              'category': 'Events',
              'position': {'x': 50, 'y': 50},
              'inputs': [],
              'outputs': [
                {'id': 'exec_out', 'name': 'Exec Out', 'type': 'exec', 'isOutput': true},
              ],
              'literals': {},
            },
            {
              'id': 'n_move',
              'registryId': 'add_movement_input',
              'title': 'Add Movement Input',
              'category': 'Pawn Movement',
              'position': {'x': 250, 'y': 50},
              'inputs': [
                {'id': 'exec_move_in', 'name': 'Exec In', 'type': 'exec'},
                {'id': 'world_dir', 'name': 'World Direction', 'type': 'vector3'},
                {'id': 'scale_val', 'name': 'Scale Value', 'type': 'number'},
              ],
              'outputs': [],
              'literals': {
                'world_dir': [0.0, 0.0, 1.0],
                'scale_val': 1.0,
              },
            },
          ],
          'connections': [
            {
              'id': 'w1',
              'fromNodeId': 'n_begin',
              'fromPinId': 'exec_out',
              'toNodeId': 'n_move',
              'toPinId': 'exec_move_in',
            },
          ],
        },
        'variables': [
          {'name': 'health', 'type': 'Float', 'default': '100.0'},
        ],
        'classDefaults': {},
      };

      final code = service.generateActorClassDart('BP_PlayerCharacter', docMap);

      expect(code, contains('class BpPlayerCharacter extends LuminaCharacter with LuminaBlueprintRuntime'));
      expect(code, contains('double health = 100.0;'));
      // The capsule is the Character's own field, configured through the
      // shared component table, never re-declared.
      expect(code, isNot(contains('late final LuminaCapsuleComponent')));
      expect(code, contains("type: 'LuminaCapsuleComponent',"));
      expect(code, contains('blueprintComponents = LuminaBlueprintComponents.construct(this, _components);'));
      expect(code, contains('void onBeginPlay()'));
      expect(code, contains('LuminaBlueprintFunctionLibrary.addMovementInput(this, Vector3(0.0, 0.0, 1.0), 1.0, false);'));
    });

    test('generateActorClassDart preserves user code regions between generations', () {
      const existingCode = '''// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: file_names, unused_import
import 'package:lumina/lumina.dart';

class BpPlayerCharacter extends LuminaCharacter {
  // BEGIN USER CODE: class_body
  void myCustomHelper() {
    print("Custom user code preserved!");
  }
  // END USER CODE

  @override
  void onBeginPlay() {
    super.onBeginPlay();
  }
}
''';

      final docMap = {
        'parentClass': 'LuminaCharacter',
        'components': [],
        'eventGraph': {'nodes': [], 'connections': []},
        'variables': [],
      };

      final regenerated = service.generateActorClassDart('BP_PlayerCharacter', docMap, existingContent: existingCode);
      expect(regenerated, contains('void myCustomHelper()'));
      expect(regenerated, contains('Custom user code preserved!'));
    });

    test('generateActorRegistryDart produces deterministic factory map', () {
      final registryCode = service.generateActorRegistryDart(['BP_PlayerCharacter', 'BP_EnemyPawn']);
      expect(registryCode, contains('final Map<String, LuminaActor Function()> blueprintActorFactories = {'));
      expect(registryCode, contains("'BpPlayerCharacter': () => BpPlayerCharacter(),"));
      expect(registryCode, contains("'BpEnemyPawn': () => BpEnemyPawn(),"));
    });
  });
}

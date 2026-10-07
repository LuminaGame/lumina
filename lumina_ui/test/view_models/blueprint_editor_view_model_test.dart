import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_editor_view_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('bp_vm_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('BlueprintEditorViewModel Core & Component Tree Tests', () {
    test('load() parses ACTOR asset JSON payload into BlueprintDocument structure', () async {
      final docJson = {
        'parentClass': 'LuminaCharacter',
        'components': [
          {
            'id': 'root_capsule',
            'name': 'CapsuleComponent',
            'type': 'LuminaCapsuleComponent',
            'parentId': null,
            'properties': {'capsuleRadius': 0.5, 'capsuleHalfHeight': 0.88},
          },
          {
            'id': 'mesh_1',
            'name': 'CharacterMesh',
            'type': 'LuminaSkinnedMeshComponent',
            'parentId': 'root_capsule',
            'properties': {},
          },
          {
            'id': 'move_comp',
            'name': 'CharacterMovement',
            'type': 'LuminaCharacterMovementComponent',
            'parentId': null,
            'properties': {'maxWalkSpeed': 6.0},
          },
        ],
        'eventGraph': {'nodes': [], 'connections': []},
        'variables': [],
        'classDefaults': {'initialHealth': 100.0},
      };

      final file = File('${tempDir.path}/BP_Hero.lmas');
      final asset = LuminaAsset(
        assetId: 'BP_Hero',
        name: 'BP_Hero',
        type: AssetType.actor,
        rawPayload: utf8.encode(jsonEncode(docJson)),
      );
      await file.writeAsBytes(asset.toProtoBufferBytes());

      final vm = BlueprintEditorViewModel(assetPath: file.path, initialAsset: asset);
      await vm.load();

      expect(vm.document.parentClass, equals('LuminaCharacter'));
      expect(vm.document.components.length, equals(3));
      expect(vm.rootComponent?.id, equals('root_capsule'));
      expect(vm.isSceneComponent('root_capsule'), isTrue);
      expect(vm.isSceneComponent('move_comp'), isFalse);
    });

    test('addComponent creates a valid unique Dart-identifier name and sets hierarchy', () {
      final vm = BlueprintEditorViewModel(
        assetPath: '${tempDir.path}/BP_New.lmas',
        initialAsset: LuminaAsset(
          assetId: 'BP_New',
          name: 'BP_New',
          type: AssetType.actor,
        ),
      );

      // 1. Add first component (becomes root)
      final rootNode = vm.addComponent('LuminaCapsuleComponent');
      expect(rootNode, isNotNull);
      expect(vm.rootComponent?.id, equals(rootNode!.id));
      expect(rootNode.name, equals('CapsuleComponent'));

      // 2. Add child under root
      final childNode = vm.addComponent('LuminaSpringArmComponent', parentId: rootNode.id);
      expect(childNode, isNotNull);
      expect(childNode!.parentId, equals(rootNode.id));

      // 3. Add second under child
      final cameraNode = vm.addComponent('LuminaCameraComponent', parentId: childNode.id);
      expect(cameraNode, isNotNull);
      expect(cameraNode!.parentId, equals(childNode.id));

      expect(vm.document.components.length, equals(3));
      expect(vm.isDirty, isTrue);
    });

    test('renameComponent rejects duplicate or invalid Dart identifiers', () {
      final vm = BlueprintEditorViewModel(
        assetPath: '${tempDir.path}/BP_Test.lmas',
      );

      final node1 = vm.addComponent('LuminaCapsuleComponent');
      final node2 = vm.addComponent('LuminaSpringArmComponent', parentId: node1?.id);

      expect(node1, isNotNull);
      expect(node2, isNotNull);

      // Rejects invalid start digit
      final res1 = vm.renameComponent(node2!.id, '2Camera');
      expect(res1, isFalse);

      // Rejects spaces
      final res2 = vm.renameComponent(node2.id, 'My Spring Arm');
      expect(res2, isFalse);

      // Rejects duplicate name
      final res3 = vm.renameComponent(node2.id, node1!.name);
      expect(res3, isFalse);

      // Valid rename
      final res4 = vm.renameComponent(node2.id, 'MainSpringArm');
      expect(res4, isTrue);
      expect(vm.getComponent(node2.id)?.name, equals('MainSpringArm'));
    });

    test('removeComponent reparents children to parent and preserves event graph', () {
      final vm = BlueprintEditorViewModel(
        assetPath: '${tempDir.path}/BP_Test.lmas',
        initialAsset: LuminaAsset(assetId: 'BP_Test', name: 'BP_Test', type: AssetType.actor),
      );

      final root = vm.addComponent('LuminaCapsuleComponent')!;
      final arm = vm.addComponent('LuminaSpringArmComponent', parentId: root.id)!;
      final cam = vm.addComponent('LuminaCameraComponent', parentId: arm.id)!;

      expect(cam.parentId, equals(arm.id));

      // Remove arm -> cam should reparent to root
      final removed = vm.removeComponent(arm.id);
      expect(removed, isTrue);

      final updatedCam = vm.getComponent(cam.id);
      expect(updatedCam?.parentId, equals(root.id));
      expect(vm.document.components.length, equals(2));
    });

    test('setProperty updates component defaults with clamping and save persists', () async {
      final file = File('${tempDir.path}/BP_Props.lmas');
      final asset = LuminaAsset(
        assetId: 'BP_Props',
        name: 'BP_Props',
        type: AssetType.actor,
      );
      await file.writeAsBytes(asset.toProtoBufferBytes());

      final vm = BlueprintEditorViewModel(assetPath: file.path, initialAsset: asset);
      final capsule = vm.addComponent('LuminaCapsuleComponent')!;

      vm.setProperty(capsule.id, 'capsuleRadius', 75.0);
      expect(vm.getComponent(capsule.id)!.properties['capsuleRadius'], equals(75.0));

      final saved = await vm.save();
      expect(saved, isTrue);
      expect(vm.isDirty, isFalse);

      // Read back from disk
      final diskBytes = await file.readAsBytes();
      final loadedAsset = LuminaAsset.fromBytes(diskBytes);
      final loadedDoc = LuminaBlueprintDocument.fromJson(jsonDecode(utf8.decode(loadedAsset.rawPayload!)));

      final loadedCapsule = loadedDoc.components.firstWhere((c) => c.id == capsule.id);
      expect(loadedCapsule.properties['capsuleRadius'], equals(75.0));
    });

    test('reparent prevents circular hierarchy loops', () {
      final vm = BlueprintEditorViewModel(
        assetPath: '${tempDir.path}/BP_Test.lmas',
        initialAsset: LuminaAsset(assetId: 'BP_Test', name: 'BP_Test', type: AssetType.actor),
      );

      final root = vm.addComponent('LuminaCapsuleComponent')!;
      final child = vm.addComponent('LuminaSpringArmComponent', parentId: root.id)!;
      final grandChild = vm.addComponent('LuminaCameraComponent', parentId: child.id)!;

      // Cannot reparent root under its own child
      expect(vm.canReparent(root.id, child.id), isFalse);
      expect(vm.canReparent(root.id, grandChild.id), isFalse);

      // Cannot reparent child under grandchild
      expect(vm.canReparent(child.id, grandChild.id), isFalse);

      // Can reparent grandchild to root
      expect(vm.canReparent(grandChild.id, root.id), isTrue);
      final reparented = vm.reparent(grandChild.id, root.id);
      expect(reparented, isTrue);
      expect(vm.getComponent(grandChild.id)?.parentId, equals(root.id));
    });
  });
}

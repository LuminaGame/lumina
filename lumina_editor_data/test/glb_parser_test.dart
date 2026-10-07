import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';

void main() {
  group('GlbParserService Tests', () {
    test('Should parse real non-indexed GLB file YVO3D_44368.glb', () async {
      final file = File('${Directory.current.parent.path}/test-assets/fixtures/YVO3D_44368.glb');
      expect(file.existsSync(), isTrue);

      final bytes = file.readAsBytesSync();
      final meshData = await GlbParserService.parseGlb(bytes);

      expect(meshData, isNotNull);
      expect(meshData!.positions.length, greaterThan(0));
      expect(meshData.indices.length, greaterThan(0));
      expect(meshData.indices.length % 3, equals(0));
    });

    test('Should parse Draco compressed GLB file attackhelicopter.entity.glb', () async {
      final file = File('${Directory.current.parent.path}/test-assets/fixtures/attackhelicopter.entity.glb');
      expect(file.existsSync(), isTrue);

      final bytes = file.readAsBytesSync();
      final meshData = await GlbParserService.parseGlb(bytes);

      expect(meshData, isNotNull);
      expect(meshData!.positions.length, greaterThan(0));
      expect(meshData.indices.length, greaterThan(0));
      expect(meshData.indices.length % 3, equals(0));

      // Test real scene graph hierarchy extraction
      expect(meshData.allNodes.length, equals(50));
      expect(meshData.rootNodes.isNotEmpty, isTrue);

      final root = meshData.rootNodes.first;
      expect(root.name, equals('AttackHelicopter.entity'));
      expect(root.children.length, equals(2)); // ClientOnly & ServerOnly
      expect(root.totalDescendantCount, greaterThan(20));

      final clientOnly = root.children.firstWhere((c) => c.name == 'ClientOnly');
      expect(clientOnly.children.any((c) => c.name == 'AHMissilePod_Left'), isTrue);
      expect(clientOnly.children.any((c) => c.name == 'AttackHeli_skinned'), isTrue);

      final skinned = clientOnly.children.firstWhere((c) => c.name == 'AttackHeli_skinned');
      expect(skinned.children.any((c) => c.name == 'AttackHelicopter_LOD0'), isTrue);
      expect(skinned.children.any((c) => c.name == 'RearRotor_LOD0'), isTrue);
      expect(skinned.children.any((c) => c.name == 'RotorBlades_LOD0'), isTrue);
    });

    test('Should unpack and parse .lmas JSON container asset file', () async {
      final path = Platform.environment['LUMINA_HELICOPTER_LMAS'];
      final lmasFile = File(path ?? '');
      if (path != null && lmasFile.existsSync()) {
        final bytes = lmasFile.readAsBytesSync();
        final meshData = await GlbParserService.parseGlb(bytes);

        expect(meshData, isNotNull);
        expect(meshData!.positions.length, greaterThan(0));
        expect(meshData.indices.length, greaterThan(0));
      }
    });

    test('Should parse converted blackjack_blender2.glb', () async {
      final file = File('${Directory.current.parent.path}/test-assets/fixtures/blackjack_blender2.glb');
      if (file.existsSync()) {
        final bytes = file.readAsBytesSync();
        final meshData = await GlbParserService.parseGlb(bytes);

        expect(meshData, isNotNull);
        expect(meshData!.positions.length, greaterThan(0));
        expect(meshData.indices.length, greaterThan(0));
      }
    });
  });
}

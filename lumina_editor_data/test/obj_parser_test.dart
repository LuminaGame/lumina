import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';

void main() {
  group('ObjParserService Tests', () {
    test('Should parse real material_sphere.obj 3D model file', () {
      final file = File('${Directory.current.parent.path}/filament/assets/models/material_sphere/material_sphere.obj');
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      final meshData = ObjParserService.parseObj(content);

      expect(meshData, isNotNull);
      expect(meshData!.positions.length, greaterThan(0));
      expect(meshData.indices.length, greaterThan(0));
      expect(meshData.indices.length % 3, equals(0));
      expect(meshData.minBounds.length, equals(3));
      expect(meshData.maxBounds.length, equals(3));
    });
  });
}

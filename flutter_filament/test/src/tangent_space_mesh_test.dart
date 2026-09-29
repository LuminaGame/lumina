import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:flutter_filament/src/tangent_space_mesh.dart';
import 'package:flutter_filament/src/engine.dart';

void main() {
  group('TangentSpaceMesh', () {
    test('Normals only (FRISVAD/DEFAULT)', () {
      final builder = TangentSpaceMeshBuilder()
        ..vertexCount(3)
        ..normals(Float32List.fromList([
          0, 0, 1,
          0, 0, 1,
          0, 0, 1
        ]));
        
      final mesh = builder.build();
      
      expect(mesh.vertexCount, 3);
      expect(mesh.triangleCount, 0); // No triangles provided
      
      final quats = mesh.getQuatsFloat();
      expect(quats.length, 12);
      
      // With Frisvad generating tangents for (0,0,1), 
      // the resulting quaternion should be well-formed (length ≈ 1).
      // Exact quaternion depends on Filament's math.
      final lengthSq = quats[0]*quats[0] + quats[1]*quats[1] + quats[2]*quats[2] + quats[3]*quats[3];
      expect(lengthSq, closeTo(1.0, 0.0001));

      mesh.destroy();
    });

    test('Full MIKKTSPACE path', () {
      final builder = TangentSpaceMeshBuilder()
        ..vertexCount(3)
        ..positions(Float32List.fromList([
          0, 0, 0,
          1, 0, 0,
          0, 1, 0
        ]))
        ..uvs(Float32List.fromList([
          0, 0,
          1, 0,
          0, 1
        ]))
        ..normals(Float32List.fromList([
          0, 0, 1,
          0, 0, 1,
          0, 0, 1
        ]))
        ..triangleCount(1)
        ..trianglesUshort(Uint16List.fromList([0, 1, 2]))
        ..algorithm(TsmAlgorithm.mikktspace);
        
      final mesh = builder.build();
      
      expect(mesh.vertexCount, 3);
      expect(mesh.triangleCount, 1);
      
      final quats = mesh.getQuatsFloat();
      expect(quats.length, 12);
      
      // Mikktspace should successfully orient tangent along U and bitangent along V
      // For this triangle, tangent should be (1, 0, 0), bitangent (0, 1, 0)
      
      mesh.destroy();
    });

    test('getQuatsShort4() output equals getQuatsFloat() quantized', () {
      final builder = TangentSpaceMeshBuilder()
        ..vertexCount(3)
        ..normals(Float32List.fromList([
          0, 1, 0,
          1, 0, 0,
          0, 0, 1
        ]));
        
      final mesh = builder.build();
      final quatsFloat = mesh.getQuatsFloat();
      final quatsShort = mesh.getQuatsShort4();
      
      expect(quatsShort.length, quatsFloat.length);
      
      for (int i = 0; i < quatsFloat.length; i++) {
        final floatVal = quatsFloat[i];
        final shortVal = quatsShort[i];
        final expected = (floatVal * 32767).round();
        expect((shortVal - expected).abs(), lessThanOrEqualTo(1));
      }

      mesh.destroy();
    });

    test('Strided input', () {
      final interleaved = Float32List.fromList([
        0, 0, 0, 0, 0, 0, 0, 1,
        1, 0, 0, 1, 0, 0, 0, 1,
        0, 1, 0, 0, 1, 0, 0, 1,
      ]);
      // stride = 8 * 4 = 32 bytes
      
      final builderStrided = TangentSpaceMeshBuilder()
        ..vertexCount(3)
        ..positions(Float32List.view(interleaved.buffer, 0, 24), strideBytes: 32)
        ..uvs(Float32List.view(interleaved.buffer, 12, 21), strideBytes: 32)
        ..normals(Float32List.view(interleaved.buffer, 20, 19), strideBytes: 32)
        ..triangleCount(1)
        ..trianglesUshort(Uint16List.fromList([0, 1, 2]))
        ..algorithm(TsmAlgorithm.mikktspace);
        
      final meshStrided = builderStrided.build();
      
      final builderPacked = TangentSpaceMeshBuilder()
        ..vertexCount(3)
        ..positions(Float32List.fromList([0, 0, 0, 1, 0, 0, 0, 1, 0]))
        ..uvs(Float32List.fromList([0, 0, 1, 0, 0, 1]))
        ..normals(Float32List.fromList([0, 0, 1, 0, 0, 1, 0, 0, 1]))
        ..triangleCount(1)
        ..trianglesUshort(Uint16List.fromList([0, 1, 2]))
        ..algorithm(TsmAlgorithm.mikktspace);
        
      final meshPacked = builderPacked.build();
      
      final quatsStrided = meshStrided.getQuatsFloat();
      final quatsPacked = meshPacked.getQuatsFloat();
      
      expect(quatsStrided, equals(quatsPacked));

      meshStrided.destroy();
      meshPacked.destroy();
    });

    test('aux(COLORS, float4)', () {
      final builder = TangentSpaceMeshBuilder()
        ..vertexCount(3)
        ..positions(Float32List.fromList([0, 0, 0, 1, 0, 0, 0, 1, 0]))
        ..uvs(Float32List.fromList([0, 0, 1, 0, 0, 1]))
        ..normals(Float32List.fromList([0, 0, 1, 0, 0, 1, 0, 0, 1]))
        ..triangleCount(1)
        ..trianglesUshort(Uint16List.fromList([0, 1, 2]))
        ..algorithm(TsmAlgorithm.mikktspace)
        ..aux(TsmAuxAttribute.colors, Float32List.fromList([
          1, 0, 0, 1,
          0, 1, 0, 1,
          0, 0, 1, 1,
        ]));
        
      final mesh = builder.build();
      
      if (mesh.remeshed) {
        final outColors = mesh.getAuxFloat(TsmAuxAttribute.colors);
        expect(outColors.length, mesh.vertexCount * 4);
        expect(outColors.sublist(0, 4), equals([1.0, 0.0, 0.0, 1.0]));
      }

      mesh.destroy();
    });

    test('Double destroy protection', () {
      final builder = TangentSpaceMeshBuilder()
        ..vertexCount(3)
        ..normals(Float32List.fromList([0, 0, 1, 0, 0, 1, 0, 0, 1]));
      final mesh = builder.build();
      mesh.destroy();
      
      expect(() => mesh.destroy(), throwsStateError);
      expect(() => mesh.getQuatsFloat(), throwsStateError);
    });
  });
}

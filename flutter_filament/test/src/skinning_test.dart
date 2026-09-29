import 'dart:ffi' as ffi;
import 'dart:typed_data';

import 'package:ffi/ffi.dart' as pkg_ffi;
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/src/third_party/filament_c.g.dart' as c;
import 'package:test/test.dart';

void main() {
  group('Skinning tests', () {
    late FilamentEngine engine;
    late FilamentVertexBuffer vb;
    late FilamentIndexBuffer ib;

    setUp(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;

      // 4-vertex mesh with JOINTS/WEIGHTS attributes for skinning
      vb = FilamentVertexBuffer.create(
        engine: engine,
        vertexCount: 4,
        bufferCount: 1,
        attributes: [
          VertexAttributeDesc(attribute: VertexAttribute.position, byteOffset: 0, type: AttributeType.float3, bufferIndex: 0),
          VertexAttributeDesc(attribute: VertexAttribute.boneIndices, byteOffset: 12, type: AttributeType.ushort4, bufferIndex: 0),
          VertexAttributeDesc(attribute: VertexAttribute.boneWeights, byteOffset: 20, type: AttributeType.float4, bufferIndex: 0),
        ],

      );

      ib = FilamentIndexBuffer.create(
        engine: engine,
        indexCount: 6,
        type: IndexType.ushort,
      );
    });

    tearDown(() {
      if (!vb.isDisposed) vb.dispose();
      if (!ib.isDisposed) ib.dispose();
      if (!engine.isDisposed) engine.dispose();
    });

    test('ABI: ffi.sizeOf<Bone>() == 32', () {
      expect(ffi.sizeOf<c.FilamentBone>(), equals(32));
    });

    test('Simple 4-vertex mesh with JOINTS/WEIGHTS attributes + skinning(2) -> build Success', () {
      final entity = engine.createEntity();
      RenderableBuilder(1)
        ..boundingBox(-1, -1, -1, 1, 1, 1)
        ..geometry(0, PrimitiveType.triangles, vb, ib: ib)
        ..skinning(2)
        ..build(engine, entity);

      engine.flushAndWait();
      
      final rm = FilamentRenderableManager(engine);
      expect(rm.hasComponent(entity), isTrue);
      
      rm.destroy(entity);
      engine.destroyEntity(entity);
    });

    test('skinning(2, bones) builds successfully', () {
      final entity = engine.createEntity();
      
      pkg_ffi.using((pkg_ffi.Arena arena) {
        final bone0 = BoneExt.allocate(
          arena,
          Float32List.fromList([0, 0, 0, 1]), // x,y,z,w
          Float32List.fromList([1, 0, 0]), // translation
        );
        final bone1 = BoneExt.allocate(
          arena,
          Float32List.fromList([0, 0, 0, 1]),
          Float32List.fromList([0, 1, 0]),
        );

        RenderableBuilder(1)
          ..boundingBox(-1, -1, -1, 1, 1, 1)
          ..geometry(0, PrimitiveType.triangles, vb, ib: ib)
          ..skinningBones(2, bones: [bone0, bone1])
          ..build(engine, entity);
      });

      engine.flushAndWait();
      
      final rm = FilamentRenderableManager(engine);
      expect(rm.hasComponent(entity), isTrue);
      
      rm.destroy(entity);
      engine.destroyEntity(entity);
    });

    test('skinning(2, matrices) builds successfully', () {
      final entity = engine.createEntity();
      final matrices = Float32List(32); // 2 identity matrices
      matrices[0] = 1.0; matrices[5] = 1.0; matrices[10] = 1.0; matrices[15] = 1.0;
      matrices[16] = 1.0; matrices[21] = 1.0; matrices[26] = 1.0; matrices[31] = 1.0;

      RenderableBuilder(1)
        ..boundingBox(-1, -1, -1, 1, 1, 1)
        ..geometry(0, PrimitiveType.triangles, vb, ib: ib)
        ..skinningMatrices(2, matrices: matrices)
        ..build(engine, entity);

      engine.flushAndWait();
      
      final rm = FilamentRenderableManager(engine);
      expect(rm.hasComponent(entity), isTrue);
      
      rm.destroy(entity);
      engine.destroyEntity(entity);
    });

    test('Runtime: after build, setBones and setBonesMatrices works', () {
      final entity = engine.createEntity();
      RenderableBuilder(1)
        ..boundingBox(-1, -1, -1, 1, 1, 1)
        ..geometry(0, PrimitiveType.triangles, vb, ib: ib)
        ..skinning(2)
        ..build(engine, entity);

      final rm = FilamentRenderableManager(engine);
      
      pkg_ffi.using((pkg_ffi.Arena arena) {
        final bone0 = BoneExt.allocate(
          arena,
          Float32List.fromList([0, 0, 0, 1]),
          Float32List.fromList([1, 0, 0]),
        );
        final bone1 = BoneExt.allocate(
          arena,
          Float32List.fromList([0, 0, 0, 1]),
          Float32List.fromList([0, 1, 0]),
        );

        expect(() => rm.setBones(entity, [bone0, bone1]), returnsNormally);
      });
      
      engine.flushAndWait();

      final matrices = Float32List(16);
      matrices[0] = 1.0; matrices[5] = 1.0; matrices[10] = 1.0; matrices[15] = 1.0;
      expect(() => rm.setBonesMatrices(entity, matrices, offset: 1), returnsNormally);

      rm.destroy(entity);
      engine.destroyEntity(entity);
    });

    test('boneIndicesAndWeights builds successfully given flat float2 array', () {
      final entity = engine.createEntity();
      final weights = Float32List(4 * 2 * 2); // 4 vertices * 2 bones * (index, weight)
      // Set weights so sum > 0
      for (int i = 0; i < 4; i++) {
        weights[i * 4 + 1] = 1.0; // vertex i, bone 0, weight (offset 1 in float2)
      }
      
      final vbAdvanced = FilamentVertexBuffer.create(
        engine: engine,
        vertexCount: 4,
        bufferCount: 1,
        advancedSkinning: true,
        attributes: [
          VertexAttributeDesc(attribute: VertexAttribute.position, byteOffset: 0, type: AttributeType.float3, bufferIndex: 0),
        ],
      );
      final pData = Float32List.fromList([
        -1.0, -1.0, 0.0,
         1.0, -1.0, 0.0,
        -1.0,  1.0, 0.0,
         1.0,  1.0, 0.0,
      ]);
      vbAdvanced.setData(pData);

      RenderableBuilder(1)
        ..boundingBox(-1, -1, -1, 1, 1, 1)
        ..geometry(0, PrimitiveType.triangles, vbAdvanced, ib: ib)
        ..enableSkinningBuffers(true)
        ..boneIndicesAndWeights(0, weights, bonesPerVertex: 2)
        ..skinning(2)
        ..build(engine, entity);

      engine.flushAndWait();
      
      final rm = FilamentRenderableManager(engine);
      expect(rm.hasComponent(entity), isTrue);
      
      rm.destroy(entity);
      engine.destroyEntity(entity);
    });
  });

  group('SkinningBuffer tests', () {
    late FilamentEngine engine;
    
    setUp(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
    });

    tearDown(() {
      if (!engine.isDisposed) engine.dispose();
    });

    test('boneCount rounding to next multiple of 256', () {
      final sb1 = SkinningBuffer.create(engine, boneCount: 100);
      expect(sb1.boneCount, equals(256));
      sb1.destroy();

      final sb2 = SkinningBuffer.create(engine, boneCount: 256);
      expect(sb2.boneCount, equals(256));
      sb2.destroy();

      final sb3 = SkinningBuffer.create(engine, boneCount: 257);
      expect(sb3.boneCount, equals(512));
      sb3.destroy();
    });

    test('initialize: true is usable immediately in RenderableBuilder', () {
      final entity = engine.createEntity();
      final sb = SkinningBuffer.create(engine, boneCount: 256, initialize: true);
      
      final vb = FilamentVertexBuffer.create(
        engine: engine, vertexCount: 1, bufferCount: 1,
        attributes: [VertexAttributeDesc(attribute: VertexAttribute.position, byteOffset: 0, type: AttributeType.float3, bufferIndex: 0)]
      );
      final ib = FilamentIndexBuffer.create(engine: engine, indexCount: 3, type: IndexType.ushort);
      
      RenderableBuilder(1)
        ..boundingBox(-1, -1, -1, 1, 1, 1)
        ..geometry(0, PrimitiveType.triangles, vb, ib: ib)
        ..enableSkinningBuffers(true)
        ..skinningBuffer(sb, count: 2, offset: 0)
        ..build(engine, entity);

      engine.flushAndWait();
      
      sb.destroy();
      vb.dispose();
      ib.dispose();
      engine.destroyEntity(entity);
    });

    test('setBones and setBonesFromMatrices work', () {
      final sb = SkinningBuffer.create(engine, boneCount: 256);
      
      pkg_ffi.using((pkg_ffi.Arena arena) {
        final bone0 = BoneExt.allocate(arena, Float32List.fromList([0, 0, 0, 1]), Float32List.fromList([0, 0, 0]));
        final bone1 = BoneExt.allocate(arena, Float32List.fromList([0, 0, 0, 1]), Float32List.fromList([0, 0, 0]));
        final bones = [bone0, bone1];
        
        sb.setBones(bones, offset: 0);
      });
      
      final matrices = Float32List.fromList([
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1,
      ]);
      sb.setBonesFromMatrices(matrices, count: 1, offset: 2);
      
      engine.flushAndWait();
      sb.destroy();
    });

    test('Offset window validation', () {
      final sb = SkinningBuffer.create(engine, boneCount: 256);
      
      pkg_ffi.using((pkg_ffi.Arena arena) {
        final bone0 = BoneExt.allocate(arena, Float32List.fromList([0, 0, 0, 1]), Float32List.fromList([0, 0, 0]));
        final bone1 = BoneExt.allocate(arena, Float32List.fromList([0, 0, 0, 1]), Float32List.fromList([0, 0, 0]));
        final bones2 = [bone0, bone1];
        
        // Should work: 254 + 2 = 256 <= 256
        sb.setBones(bones2, offset: 254);
        
        // Should throw: 255 + 2 = 257 > 256
        expect(() => sb.setBones(bones2, offset: 255), throwsA(isA<RangeError>()));
      });
      
      final matrices = Float32List(16 * 2);
      // Should work
      sb.setBonesFromMatrices(matrices, count: 2, offset: 254);
      
      // Should throw
      expect(() => sb.setBonesFromMatrices(matrices, count: 2, offset: 255), throwsA(isA<RangeError>()));
      
      sb.destroy();
    });

    test('Two renderables sharing one SkinningBuffer', () {
      final entity1 = engine.createEntity();
      final entity2 = engine.createEntity();
      final sb = SkinningBuffer.create(engine, boneCount: 256);
      
      final vb = FilamentVertexBuffer.create(
        engine: engine, vertexCount: 1, bufferCount: 1,
        attributes: [VertexAttributeDesc(attribute: VertexAttribute.position, byteOffset: 0, type: AttributeType.float3, bufferIndex: 0)]
      );
      final ib = FilamentIndexBuffer.create(engine: engine, indexCount: 3, type: IndexType.ushort);
      
      RenderableBuilder(1)
        ..boundingBox(-1, -1, -1, 1, 1, 1)
        ..geometry(0, PrimitiveType.triangles, vb, ib: ib)
        ..enableSkinningBuffers(true)
        ..skinningBuffer(sb, count: 2, offset: 0)
        ..build(engine, entity1);

      RenderableBuilder(1)
        ..boundingBox(-1, -1, -1, 1, 1, 1)
        ..geometry(0, PrimitiveType.triangles, vb, ib: ib)
        ..enableSkinningBuffers(true)
        ..skinningBuffer(sb, count: 2, offset: 8)
        ..build(engine, entity2);

      engine.flushAndWait();
      
      sb.destroy();
      vb.dispose();
      ib.dispose();
      engine.destroyEntity(entity1);
      engine.destroyEntity(entity2);
    });

    test('destroy() twice is safe', () {
      final sb = SkinningBuffer.create(engine, boneCount: 100);
      sb.destroy();
      expect(() => sb.destroy(), returnsNormally);
    });
  });
}

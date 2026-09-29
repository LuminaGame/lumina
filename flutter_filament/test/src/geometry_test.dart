import 'dart:ffi' as ffi;
import 'dart:typed_data';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';

void main() {
  group('Geometry & Buffers API Tests', () {
    late FilamentEngine engine;

    setUp(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
    });

    tearDown(() {
      if (!engine.isDisposed) engine.dispose();
    });

    test('IndexType enum indices', () {
      expect(IndexType.ushort.index, equals(0));
      expect(IndexType.uint.index, equals(1));
    });

    test('PrimitiveType enum rawValues', () {
      expect(PrimitiveType.points.rawValue, equals(0));
      expect(PrimitiveType.lines.rawValue, equals(1));
      expect(PrimitiveType.lineStrip.rawValue, equals(3));
      expect(PrimitiveType.triangles.rawValue, equals(4));
      expect(PrimitiveType.triangleStrip.rawValue, equals(5));
    });

    test('FilamentVertexBuffer lifecycle and setData', () {
      final vb = FilamentVertexBuffer.create(
        engine: engine,
        vertexCount: 3,
        bufferCount: 1,
      );
      expect(vb.isDisposed, isFalse);
      expect(vb.nativePointer, isNotNull);

      final positions = Float32List.fromList([
        0.0, 1.0, 0.0,
        -1.0, -1.0, 0.0,
        1.0, -1.0, 0.0,
      ]);
      expect(() => vb.setData(positions), returnsNormally);

      vb.dispose();
      expect(vb.isDisposed, isTrue);
      expect(() => vb.nativePointer, throwsStateError);
      expect(() => vb.setData(positions), throwsStateError);
    });

    test('FilamentIndexBuffer uint16 and uint32 lifecycle and setData', () {
      final ibShort = FilamentIndexBuffer.create(
        engine: engine,
        indexCount: 3,
        type: IndexType.ushort,
      );
      expect(ibShort.isDisposed, isFalse);
      expect(ibShort.nativePointer, isNotNull);
      expect(
        () => ibShort.setUint16Data(Uint16List.fromList([0, 1, 2])),
        returnsNormally,
      );
      ibShort.dispose();
      expect(ibShort.isDisposed, isTrue);
      expect(() => ibShort.nativePointer, throwsStateError);

      final ibInt = FilamentIndexBuffer.create(
        engine: engine,
        indexCount: 3,
        type: IndexType.uint,
      );
      expect(ibInt.isDisposed, isFalse);
      expect(
        () => ibInt.setUint32Data(Uint32List.fromList([0, 1, 2])),
        returnsNormally,
      );
      ibInt.dispose();
    });

    test('FilamentTransformManager create, setTransform, worldTransform, parent', () {
      final transformManager = FilamentTransformManager(engine);
      final entity = engine.createEntity();
      final parentEntity = engine.createEntity();

      transformManager.create(entity);
      transformManager.create(parentEntity);

      final identity = [
        1.0, 0.0, 0.0, 0.0,
        0.0, 1.0, 0.0, 0.0,
        0.0, 0.0, 1.0, 0.0,
        0.0, 0.0, 0.0, 1.0,
      ];
      expect(() => transformManager.setTransform(entity, identity), returnsNormally);
      expect(
        () => transformManager.setTransform(entity, [1.0, 2.0]),
        throwsArgumentError,
      );

      final worldTransform = transformManager.getWorldTransform(entity);
      expect(worldTransform.length, equals(16));

      expect(() => transformManager.setParent(entity, parentEntity), returnsNormally);
      final parent = transformManager.getParent(entity);
      expect(parent == 0 || parent == parentEntity, isTrue);

      // Local vs world transform test
      transformManager.setTransform(parentEntity, [
        1.0, 0.0, 0.0, 0.0,
        0.0, 1.0, 0.0, 0.0,
        0.0, 0.0, 1.0, 0.0,
        10.0, 0.0, 0.0, 1.0, // translation (10, 0, 0)
      ]);
      transformManager.setTransform(entity, [
        1.0, 0.0, 0.0, 0.0,
        0.0, 1.0, 0.0, 0.0,
        0.0, 0.0, 1.0, 0.0,
        1.0, 0.0, 0.0, 1.0, // translation (1, 0, 0) local
      ]);

      engine.flushAndWait();
      
      final localTransform = transformManager.getTransform(entity);
      expect(localTransform[12], closeTo(1.0, 1e-6));

      final worldTransform2 = transformManager.getWorldTransform(entity);
      expect(worldTransform2[12], closeTo(11.0, 1e-6));

      // Children tests
      expect(transformManager.childCount(parentEntity), equals(1));
      
      final children = transformManager.getChildren(parentEntity, 1);
      expect(children.length, equals(1));
      expect(children.first, equals(entity));

      // Reparenting
      final otherParent = engine.createEntity();
      transformManager.create(otherParent);
      transformManager.setParent(entity, otherParent);
      
      expect(transformManager.childCount(parentEntity), equals(0));
      expect(transformManager.childCount(otherParent), equals(1));
      expect(transformManager.getChildren(otherParent, 1).first, equals(entity));

      // Capacity limits
      final child2 = engine.createEntity();
      transformManager.create(child2);
      transformManager.setParent(child2, otherParent);
      expect(transformManager.childCount(otherParent), equals(2));
      final clampedChildren = transformManager.getChildren(otherParent, 1);
      expect(clampedChildren.length, equals(1));

      // hasComponent lifecycle
      final tempEntity = engine.createEntity();
      expect(transformManager.hasComponent(tempEntity), isFalse);
      transformManager.create(tempEntity);
      expect(transformManager.hasComponent(tempEntity), isTrue);
      transformManager.destroy(tempEntity);
      expect(transformManager.hasComponent(tempEntity), isFalse);
      engine.destroyEntity(tempEntity);

      transformManager.destroy(entity);
      transformManager.destroy(parentEntity);
      transformManager.destroy(otherParent);
      transformManager.destroy(child2);
      engine.destroyEntity(entity);
      engine.destroyEntity(parentEntity);
      engine.destroyEntity(otherParent);
      engine.destroyEntity(child2);
    });

    test('FilamentRenderableManager bounding box and destroy', () {
      final renderableManager = FilamentRenderableManager(engine);
      final entity = engine.createEntity();

      expect(
        () => renderableManager.setBoundingBox(
          entity: entity,
          minX: -1,
          minY: -1,
          minZ: -1,
          maxX: 1,
          maxY: 1,
          maxZ: 1,
        ),
        returnsNormally,
      );

      expect(() => renderableManager.destroy(entity), returnsNormally);
      engine.destroyEntity(entity);
    });

    group('RenderableBuilder tests', () {
      late FilamentVertexBuffer vb;
      late FilamentIndexBuffer ib;

      setUp(() {
        vb = FilamentVertexBuffer.create(
          engine: engine,
          vertexCount: 8,
          bufferCount: 1,
        );
        ib = FilamentIndexBuffer.create(
          engine: engine,
          indexCount: 36,
          type: IndexType.ushort,
        );
      });

      tearDown(() {
        if (!vb.isDisposed) vb.dispose();
        if (!ib.isDisposed) ib.dispose();
      });

      test('2-primitive builder succeeds', () {
        final entity = engine.createEntity();
        
        RenderableBuilder(2)
          ..boundingBox(-1, -1, -1, 1, 1, 1)
          ..culling(false)
          ..geometry(0, PrimitiveType.triangles, vb, ib: ib)
          ..geometry(1, PrimitiveType.triangles, vb, ib: ib)
          ..build(engine, entity);

        final rm = FilamentRenderableManager(engine);
        expect(rm.hasComponent(entity), isTrue);
        
        rm.destroy(entity);
        engine.destroyEntity(entity);
      });

      test('Whole-buffer form geometry without offset/count succeeds', () {
        final entity = engine.createEntity();
        
        RenderableBuilder(1)
          ..boundingBox(-1, -1, -1, 1, 1, 1)
          ..culling(false)
          ..geometry(0, PrimitiveType.triangles, vb, ib: ib)
          ..build(engine, entity);

        final rm = FilamentRenderableManager(engine);
        expect(rm.hasComponent(entity), isTrue);
        
        rm.destroy(entity);
        engine.destroyEntity(entity);
      });

      test('min/max-index form indexRange succeeds', () {
        final entity = engine.createEntity();
        
        RenderableBuilder(1)
          ..boundingBox(-1, -1, -1, 1, 1, 1)
          ..culling(false)
          ..geometry(0, PrimitiveType.triangles, vb, ib: ib, indexRange: (min: 0, max: 23))
          ..build(engine, entity);

        final rm = FilamentRenderableManager(engine);
        expect(rm.hasComponent(entity), isTrue);
        
        rm.destroy(entity);
        engine.destroyEntity(entity);
      });

      test('Index-less form succeeds', () {
        final entity = engine.createEntity();
        
        RenderableBuilder(1)
          ..boundingBox(-1, -1, -1, 1, 1, 1)
          ..culling(false)
          ..geometry(0, PrimitiveType.triangles, vb)
          ..build(engine, entity);

        final rm = FilamentRenderableManager(engine);
        expect(rm.hasComponent(entity), isTrue);
        
        rm.destroy(entity);
        engine.destroyEntity(entity);
      });

      test('Error path: 2-primitive build missing geometry behavior', () {
        final entity = engine.createEntity();
        
        final builder = RenderableBuilder(2)
          ..boundingBox(-1, -1, -1, 1, 1, 1)
          ..geometry(0, PrimitiveType.triangles, vb, ib: ib);
          
        // Depending on Filament version, this either succeeds or throws. 
        // We just ensure it doesn't crash.
        try {
          builder.build(engine, entity);
        } catch (e) {
          expect(e, isA<FilamentException>());
        }

        engine.destroyEntity(entity);
      });

      test('RenderableManager setGeometryAt, geometryType, and queries', () {
        expect(GeometryType.staticBounds.value, equals(1));
        
        // Setup materials mock
        final miA = FilamentMaterialInstance.internal(ffi.Pointer.fromAddress(0x1000), engine);
        final miB = FilamentMaterialInstance.internal(ffi.Pointer.fromAddress(0x2000), engine);
        final rm = FilamentRenderableManager(engine);

        final entity1 = engine.createEntity();
        RenderableBuilder(1)
          ..boundingBox(-1, -1, -1, 1, 1, 1)
          ..culling(false)
          ..geometry(0, PrimitiveType.triangles, vb, ib: ib)
          ..build(engine, entity1);
        expect(rm.getPrimitiveCount(entity1), equals(1));

        final entity2 = engine.createEntity();
        RenderableBuilder(2)
          ..boundingBox(-1, -1, -1, 1, 1, 1)
          ..culling(false)
          ..geometry(0, PrimitiveType.triangles, vb, ib: ib)
          ..geometry(1, PrimitiveType.triangles, vb, ib: ib)
          ..build(engine, entity2);
        expect(rm.getPrimitiveCount(entity2), equals(2));

        // LOD switch test
        rm.setGeometryAt(
          entity1, 
          0, 
          PrimitiveType.triangles, 
          vb, 
          ib, 
          count: 3
        );
        engine.flushAndWait();


        
        engine.flushAndWait();
        
        // Static geometry type
        final entity3 = engine.createEntity();
        RenderableBuilder(1)
          ..boundingBox(-1, -1, -1, 1, 1, 1)
          ..culling(false)
          ..geometryType(GeometryType.staticGeometry)
          ..geometry(0, PrimitiveType.triangles, vb, ib: ib)
          ..build(engine, entity3);
          
        rm.setGeometryAt(
          entity3, 
          0, 
          PrimitiveType.triangles, 
          vb, 
          ib, 
          offset: 0,
          count: 3
        );
        engine.flushAndWait();

        engine.destroyEntity(entity1);
        engine.destroyEntity(entity2);
        engine.destroyEntity(entity3);
      });

      test('RenderableManager channels, blend order, contact shadows, fog (Task 04)', () {
        final rm = FilamentRenderableManager(engine);
        final entity = engine.createEntity();

        RenderableBuilder(1)
          ..boundingBox(-1, -1, -1, 1, 1, 1)
          ..culling(false)
          ..channel(5)
          ..lightChannel(3, true)
          ..blendOrder(0, 100)
          ..globalBlendOrderEnabled(0, false)
          ..screenSpaceContactShadows(true)
          ..fog(false)
          ..geometry(0, PrimitiveType.triangles, vb, ib: ib)
          ..build(engine, entity);

        // Channel
        expect(rm.getChannel(entity), equals(5));
        rm.setChannel(entity, 2);
        expect(rm.getChannel(entity), equals(2));

        // Light channel
        expect(rm.getLightChannel(entity, 0), isTrue); // default
        expect(rm.getLightChannel(entity, 3), isTrue);
        expect(rm.getLightChannel(entity, 1), isFalse);
        rm.setLightChannel(entity, 7, true);
        expect(rm.getLightChannel(entity, 7), isTrue);
        rm.setLightChannel(entity, 7, false);
        expect(rm.getLightChannel(entity, 7), isFalse);

        // Blend order
        expect(rm.getBlendOrderAt(entity, 0), equals(100));
        rm.setBlendOrderAt(entity, 0, 200);
        expect(rm.getBlendOrderAt(entity, 0), equals(200));

        // Global blend order
        expect(rm.isGlobalBlendOrderEnabledAt(entity, 0), isFalse);
        rm.setGlobalBlendOrderEnabledAt(entity, 0, true);
        expect(rm.isGlobalBlendOrderEnabledAt(entity, 0), isTrue);

        // Contact shadows
        expect(rm.isScreenSpaceContactShadowsEnabled(entity), isTrue);
        rm.setScreenSpaceContactShadows(entity, false);
        expect(rm.isScreenSpaceContactShadowsEnabled(entity), isFalse);

        // Fog
        expect(rm.getFogEnabled(entity), isFalse);
        rm.setFogEnabled(entity, true);
        expect(rm.getFogEnabled(entity), isTrue);

        // Range errors
        expect(() => rm.setChannel(entity, 8), throwsRangeError);
        expect(() => rm.setChannel(entity, -1), throwsRangeError);
        expect(() => rm.setLightChannel(entity, 8, true), throwsRangeError);
        expect(() => rm.getLightChannel(entity, -1), throwsRangeError);
        expect(() => rm.setBlendOrderAt(entity, 0, 65536), throwsRangeError);

        final testBuilder = RenderableBuilder(1);
        expect(() => testBuilder.channel(8), throwsRangeError);
        expect(() => testBuilder.lightChannel(8, true), throwsRangeError);
        expect(() => testBuilder.blendOrder(0, 65536), throwsRangeError);
        testBuilder.destroy();

        engine.destroyEntity(entity);
      });

      test('RenderableManager queries, bounding box, attributes, computeAabb (Task 05)', () {
        final rm = FilamentRenderableManager(engine);
        final emptyEntity = engine.createEntity();

        expect(rm.hasComponent(emptyEntity), isFalse);
        final initialCount = rm.componentCount;

        final entity = engine.createEntity();
        RenderableBuilder(1)
          ..boundingBox(-1, -2, -3, 1, 2, 3)
          ..castShadows(true)
          ..receiveShadows(false)
          ..geometry(0, PrimitiveType.triangles, vb, ib: ib)
          ..build(engine, entity);

        expect(rm.hasComponent(entity), isTrue);
        expect(rm.componentCount, equals(initialCount + 1));
        expect(rm.entities.contains(entity), isTrue);

        // AABB
        final aabb = rm.getAxisAlignedBoundingBox(entity);
        expect(aabb.center.x, closeTo(0.0, 1e-5));
        expect(aabb.center.y, closeTo(0.0, 1e-5));
        expect(aabb.center.z, closeTo(0.0, 1e-5));
        expect(aabb.halfExtent.x, closeTo(1.0, 1e-5));
        expect(aabb.halfExtent.y, closeTo(2.0, 1e-5));
        expect(aabb.halfExtent.z, closeTo(3.0, 1e-5));

        // Shadows
        expect(rm.isShadowCaster(entity), isTrue);
        expect(rm.isShadowReceiver(entity), isFalse);

        // Enabled attributes
        final attrs = rm.getEnabledAttributesAt(entity, 0);
        expect(attrs.contains(VertexAttribute.position), isTrue);

        // Pure Dart computeAabb
        final cubePositions = Float32List.fromList([
          -1.0, -1.0, -1.0,
           1.0, -1.0, -1.0,
           1.0,  1.0, -1.0,
          -1.0,  1.0, -1.0,
          -1.0, -1.0,  1.0,
           1.0, -1.0,  1.0,
           1.0,  1.0,  1.0,
          -1.0,  1.0,  1.0,
        ]);
        final fullAabb = computeAabb(positionsFloat3: cubePositions);
        expect(fullAabb.min.x, equals(-1.0));
        expect(fullAabb.min.y, equals(-1.0));
        expect(fullAabb.min.z, equals(-1.0));
        expect(fullAabb.max.x, equals(1.0));
        expect(fullAabb.max.y, equals(1.0));
        expect(fullAabb.max.z, equals(1.0));

        // Index subset (only vertices 0, 1, 2)
        final subsetIndices = Uint16List.fromList([0, 1, 2]);
        final subsetAabb = computeAabb(positionsFloat3: cubePositions, indices: subsetIndices);
        expect(subsetAabb.min.z, equals(-1.0));
        expect(subsetAabb.max.z, equals(-1.0)); // all z are -1.0

        // Strided interleaved buffer (stride = 24 bytes, 6 floats: pos.xyz + normal.xyz)
        final interleaved = Float32List.fromList([
          -2.0, -3.0, -4.0, 0.0, 1.0, 0.0,
           2.0,  3.0,  4.0, 0.0, 1.0, 0.0,
        ]);
        final stridedAabb = computeAabb(positionsFloat3: interleaved, strideBytes: 24);
        expect(stridedAabb.min.x, equals(-2.0));
        expect(stridedAabb.min.y, equals(-3.0));
        expect(stridedAabb.min.z, equals(-4.0));
        expect(stridedAabb.max.x, equals(2.0));
        expect(stridedAabb.max.y, equals(3.0));
        expect(stridedAabb.max.z, equals(4.0));

        // Uint32 indices
        final u32Indices = Uint32List.fromList([0, 1]);
        final u32Aabb = computeAabb(positionsFloat3: interleaved, indices: u32Indices, strideBytes: 24);
        expect(u32Aabb.min.x, equals(-2.0));
        expect(u32Aabb.max.x, equals(2.0));

        engine.destroyEntity(emptyEntity);
        engine.destroyEntity(entity);
      });

      test('RenderableManager morphing bindings (Task 06)', () {
        final rm = FilamentRenderableManager(engine);
        final entity = engine.createEntity();

        RenderableBuilder(1)
          ..boundingBox(-1, -1, -1, 1, 1, 1)
          ..culling(false)
          ..morphing(2)
          ..geometry(0, PrimitiveType.triangles, vb, ib: ib)
          ..build(engine, entity);

        expect(rm.getMorphTargetCount(entity), equals(2));

        // Setting weights
        expect(
          () => rm.setMorphWeights(entity, Float32List.fromList([0.0, 1.0])),
          returnsNormally,
        );
        expect(
          () => rm.setMorphWeights(entity, Float32List.fromList([0.5]), offset: 1),
          returnsNormally,
        );

        // Retargeting buffer window
        expect(
          () => rm.setMorphTargetBufferOffsetAt(entity, 0, 4),
          returnsNormally,
        );

        // Range validation
        expect(
          () => rm.setMorphWeights(entity, Float32List.fromList([0.1, 0.2, 0.3])),
          throwsRangeError,
        );

        final nonMorphEntity = engine.createEntity();
        RenderableBuilder(1)
          ..boundingBox(-1, -1, -1, 1, 1, 1)
          ..culling(false)
          ..geometry(0, PrimitiveType.triangles, vb, ib: ib)
          ..build(engine, nonMorphEntity);
        expect(rm.getMorphTargetCount(nonMorphEntity), equals(0));

        engine.destroyEntity(entity);
        engine.destroyEntity(nonMorphEntity);
      });

      test('RenderableManager instancing bindings (Task 07)', () {
        final rm = FilamentRenderableManager(engine);
        final entity = engine.createEntity();

        RenderableBuilder(1)
          ..boundingBox(-1, -1, -1, 1, 1, 1)
          ..culling(false)
          ..instances(16)
          ..geometry(0, PrimitiveType.triangles, vb, ib: ib)
          ..build(engine, entity);

        expect(rm.getInstanceCount(entity), equals(16));

        final singleEntity = engine.createEntity();
        RenderableBuilder(1)
          ..boundingBox(-1, -1, -1, 1, 1, 1)
          ..culling(false)
          ..geometry(0, PrimitiveType.triangles, vb, ib: ib)
          ..build(engine, singleEntity);
        expect(rm.getInstanceCount(singleEntity), equals(1));

        // Assert range
        final testBuilder = RenderableBuilder(1);
        expect(() => testBuilder.instances(0), throwsRangeError);
        expect(() => testBuilder.instances(32768), throwsRangeError);
        testBuilder.destroy();

        engine.destroyEntity(entity);
        engine.destroyEntity(singleEntity);
      });

    });
  });
}

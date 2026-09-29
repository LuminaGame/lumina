import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:lumina/lumina.dart';

void main() {
  group('LuminaProceduralMeshComponent', () {
    test('Quad section (4 verts, 6 indices, normals + uv0): creates section, computes AABB bounds exactly', () {
      final comp = LuminaProceduralMeshComponent();

      final positions = Float32List.fromList([
        0.0, 0.0, 0.0,
        1.0, 0.0, 0.0,
        1.0, 1.0, 0.0,
        0.0, 1.0, 0.0,
      ]);
      final normals = Float32List.fromList([
        0.0, 0.0, 1.0,
        0.0, 0.0, 1.0,
        0.0, 0.0, 1.0,
        0.0, 0.0, 1.0,
      ]);
      final uv0 = Float32List.fromList([
        0.0, 0.0,
        1.0, 0.0,
        1.0, 1.0,
        0.0, 1.0,
      ]);
      final indices = Uint32List.fromList([
        0, 1, 2,
        0, 2, 3,
      ]);

      comp.createMeshSection(
        0,
        positions: positions,
        normals: normals,
        uv0: uv0,
        indices: indices,
        generateTangents: false,
      );

      expect(comp.sectionCount, equals(1));
      expect(comp.hasSection(0), isTrue);
      expect(comp.sectionVertexCount(0), equals(4));

      final bounds = comp.sectionBounds(0);
      expect(bounds, isNotNull);
      expect(bounds!.min, equals(Vector3(0.0, 0.0, 0.0)));
      expect(bounds.max, equals(Vector3(1.0, 1.0, 0.0)));
    });

    test('Layout configuration: stride calculation and attribute descriptors', () {
      final comp = LuminaProceduralMeshComponent();

      final positions = Float32List.fromList([0, 0, 0, 1, 0, 0, 0, 1, 0]);
      final normals = Float32List.fromList([0, 0, 1, 0, 0, 1, 0, 0, 1]);
      final uv0 = Float32List.fromList([0, 0, 1, 0, 0, 1]);
      final colors = Uint8List.fromList([255, 255, 255, 255, 255, 0, 0, 255, 0, 255, 0, 255]);
      final indices = Uint32List.fromList([0, 1, 2]);

      // All attributes present: pos(12) + tangents(8) + uv0(8) + colors(4) = 32 stride
      comp.createMeshSection(
        0,
        positions: positions,
        normals: normals,
        uv0: uv0,
        colors: colors,
        indices: indices,
        generateTangents: true,
      );
      expect(comp.getSectionStride(0), equals(32));

      // Without colors: pos(12) + tangents(8) + uv0(8) = 28 stride
      comp.createMeshSection(
        1,
        positions: positions,
        normals: normals,
        uv0: uv0,
        indices: indices,
        generateTangents: true,
      );
      expect(comp.getSectionStride(1), equals(28));
    });

    test('Index type selection: <= 65535 vertices uses ushort, > 65535 vertices uses uint', () {
      final comp = LuminaProceduralMeshComponent();

      final positionsSmall = Float32List(12); // 4 verts
      final indicesSmall = Uint32List(6);

      comp.createMeshSection(
        0,
        positions: positionsSmall,
        indices: indicesSmall,
        generateTangents: false,
      );
      expect(comp.getSectionIndexType(0), equals(IndexType.ushort));
    });

    test('Partial vertex update and deform loop reuses staging buffer memory', () {
      final comp = LuminaProceduralMeshComponent();

      final positions = Float32List.fromList([
        0.0, 0.0, 0.0,
        1.0, 0.0, 0.0,
        1.0, 1.0, 0.0,
        0.0, 1.0, 0.0,
      ]);
      final indices = Uint32List.fromList([0, 1, 2, 0, 2, 3]);

      comp.createMeshSection(
        0,
        positions: positions,
        indices: indices,
        generateTangents: false,
      );

      final initialPointer = comp.getSectionStagingPointerAddress(0);

      // Perform 60 update frames
      for (int i = 0; i < 60; i++) {
        final updatePositions = Float32List.fromList([
          1.0 + i * 0.01, 1.0, 0.0,
          0.0, 1.0 + i * 0.01, 0.0,
        ]);
        comp.updateMeshSection(
          0,
          positions: updatePositions,
          vertexOffset: 2,
        );
        expect(comp.getSectionStagingPointerAddress(0), equals(initialPointer));
      }
    });

    test('Validation: input errors throw typed ArgumentError and RangeError before processing', () {
      final comp = LuminaProceduralMeshComponent();

      final badPositions = Float32List(10); // Not divisible by 3
      final indices = Uint32List.fromList([0, 1, 2]);

      expect(
        () => comp.createMeshSection(0, positions: badPositions, indices: indices),
        throwsArgumentError,
      );

      final goodPositions = Float32List(12); // 4 verts
      final badIndices = Uint32List.fromList([0, 1, 5]); // Index 5 out of range (vertexCount: 4)

      expect(
        () => comp.createMeshSection(0, positions: goodPositions, indices: badIndices),
        throwsRangeError,
      );

      comp.createMeshSection(0, positions: goodPositions, indices: Uint32List.fromList([0, 1, 2]));

      // Update window out of bounds: offset 3 with 2 verts (needs 5 verts, has 4)
      expect(
        () => comp.updateMeshSection(0, positions: Float32List(6), vertexOffset: 3),
        throwsRangeError,
      );
    });

    test('Section visibility and clearing lifecycle', () {
      final comp = LuminaProceduralMeshComponent();

      final positions = Float32List.fromList([0, 0, 0, 1, 0, 0, 0, 1, 0]);
      final indices = Uint32List.fromList([0, 1, 2]);

      comp.createMeshSection(0, positions: positions, indices: indices, generateTangents: false);
      comp.createMeshSection(1, positions: positions, indices: indices, generateTangents: false);

      expect(comp.sectionCount, equals(2));

      comp.setSectionVisible(0, false);
      expect(comp.isSectionVisible(0), isFalse);

      comp.clearMeshSection(0);
      expect(comp.hasSection(0), isFalse);
      expect(comp.sectionCount, equals(1));

      // Second clear is a safe no-op
      comp.clearMeshSection(0);

      // Update on cleared section throws StateError
      expect(
        () => comp.updateMeshSection(0, positions: Float32List(3)),
        throwsStateError,
      );

      comp.clearAllMeshSections();
      expect(comp.sectionCount, equals(0));
    });
  });

  // Sections used to be drawn with the identity matrix, wherever
  // the component was.
  group('LuminaProceduralMeshComponent section transforms', () {
    late FilamentEngine engine;
    late FilamentScene scene;
    late LuminaWorld world;

    setUp(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
      scene = engine.createScene();
      world = LuminaWorld(worldType: LuminaWorldType.game);
      world.initializeNativeContext(engine, scene);
    });

    tearDown(() {
      world.cleanup();
      scene.dispose();
      engine.dispose();
    });

    /// A 1 m box section on its own actor at [location].
    LuminaProceduralMeshComponent boxAt(Vector3 location) {
      final mesh = LuminaProceduralMeshComponent();
      final actor = LuminaActor(location: location)..addComponent(mesh);
      world.persistentLevel.registerActor(actor);
      return mesh;
    }

    void addBox(LuminaProceduralMeshComponent mesh) {
      final geometry = LuminaPrimitiveGeometry.build(LuminaPrimitiveShape.box, Vector3.all(1.0));
      mesh.createMeshSection(
        0,
        positions: geometry.positions,
        normals: geometry.normals,
        uv0: geometry.uvs,
        indices: geometry.indices,
      );
    }

    List<double> drawnTranslation(LuminaProceduralMeshComponent mesh) {
      final entity = mesh.sectionEntity(0);
      expect(entity, isNot(0));
      final m = FilamentTransformManager(engine).getWorldTransform(entity);
      return [m[12], m[13], m[14]];
    }

    test('a section is drawn where its component is, and follows it', () {
      final mesh = boxAt(Vector3(-30.0, 1.25, 0.0));
      world.beginPlay();
      addBox(mesh);
      world.tick(1 / 60);

      final t = drawnTranslation(mesh);
      expect(t[0], closeTo(-30.0, 1e-5));
      expect(t[1], closeTo(1.25, 1e-5));
      expect(t[2], closeTo(0.0, 1e-5));

      mesh.owner!.actorLocation = Vector3(5.0, 1.0, -3.0);
      world.tick(1 / 60);
      final moved = drawnTranslation(mesh);
      expect(moved[0], closeTo(5.0, 1e-5));
      expect(moved[1], closeTo(1.0, 1e-5));
      expect(moved[2], closeTo(-3.0, 1e-5));
    });

    test('a component at the origin is still drawn at the origin', () {
      final mesh = boxAt(Vector3.zero());
      world.beginPlay();
      addBox(mesh);
      world.tick(1 / 60);
      expect(drawnTranslation(mesh), [0.0, 0.0, 0.0]);
    });
  });
}
